from collections import OrderedDict, deque
from datetime import timezone, datetime
import logging
import math
import os
import re
import shutil
import magic
from pathlib import Path

try:
    from importlib.metadata import version
except ImportError:
    from importlib_metadata import version

# Fallback for when package is not installed (PYTHONPATH usage)
from .__metadata__ import __version__ as package_version

from feedgen.feed import FeedGenerator
from htmlmin import minify as minify_html
from jinja2 import Template

from .db import User, Message


_NL2BR = re.compile(r"\n\n+")


class Build:
    config = {}
    template = None
    db = None

    def __init__(self, config, db, symlink):
        self.config = config
        self.db = db
        self.symlink = symlink

        self.rss_template: Template = None

        # Map of all message IDs across all months and the slug of the page
        # in which they occur (paginated), used to link replies to their
        # parent messages that may be on arbitrary pages.
        self.page_ids = {}
        self.timeline = OrderedDict()

    def build(self):
        # (Re)create the output directory.
        self._create_publish_dir()

        logging.info("Start building.")

        self.config['build_timestamp'] = int(datetime.timestamp(datetime.now(timezone.utc)))
        new_on_top = self.config.get("new_on_top", False)

        timeline = list(self.db.get_timeline(new_on_top))
        if len(timeline) == 0:
            logging.info("no data found to publish site")
            quit()

        for month in timeline:
            if month.date.year not in self.timeline:
                self.timeline[month.date.year] = []
            self.timeline[month.date.year].append(month)

        # Queue to store the latest N items to publish in the RSS feed.
        rss_entries = deque([], self.config["rss_feed_entries"])
        fname = None
        for month in timeline:
            # Get the days + message counts for the month.
            dayline = OrderedDict()
            d = None
            prev_d = None
            rendered = False
            for d in self.db.get_dayline(month.date.year, month.date.month, new_on_top, self.config["per_page"]):
                dayline[d.slug] = d

                # Incremental builds: skip rendering day counter if file exists
                fname_day = f"day-counter-{d.slug}.js"
                filename_rendered_exists = Path(os.path.join(self.config["publish_dir"], fname_day)).exists()

                if self.config.get("incremental_builds", False) and filename_rendered_exists:
                    logging.info(f"Incremental builds: file {fname_day} exists. Skip rendering.")
                    prev_d = d
                else:
                    rendered = True
                    self._render_day_counter(d)
                    # Re-render previous day counter to ensure proper linking
                    if prev_d and not filename_rendered_exists:
                        self._render_day_counter(prev_d)
                        prev_d = None

            # Always rebuild last day counter page when incremental builds enabled
            if self.config.get("incremental_builds", False) and not rendered and d:
                self._render_day_counter(d)

            # Paginate and fetch messages for the month until the end.
            # For new_on_top, start from a very high ID and go down
            # For oldest first, start from 0 and go up
            last_id = 1000_000_000_000_000_000 if new_on_top else 0
            total = self.db.get_message_count(
                month.date.year, month.date.month)
            total_pages = math.ceil(total / self.config["per_page"])
            # For new_on_top, start from last page and count down
            page = total_pages + 1 if new_on_top else 0

            while True:
                messages = list(self.db.get_messages(month.date.year, month.date.month, new_on_top,
                                                     last_id, self.config["per_page"]))

                if len(messages) == 0:
                    break

                last_id = messages[-1].id

                # Update page number based on order
                page = page - 1 if new_on_top else page + 1
                fname = self.make_filename(month, page)

                # Collect the message ID -> page name for all messages in the set
                # to link to replies in arbitrary positions across months, paginated pages.
                for m in messages:
                    self.page_ids[m.id] = fname

                if self.config["publish_rss_feed"]:
                    rss_entries.extend(messages)

                # Incremental builds: skip rendering page if file exists and page is full
                filename_rendered_exists = Path(os.path.join(self.config["publish_dir"], fname)).exists()
                incremental_enabled = self.config.get("incremental_builds", False)
                page_is_full = len(messages) == self.config["per_page"]

                if incremental_enabled and page_is_full and filename_rendered_exists:
                    logging.info(f"Incremental builds: file {fname} exists. Skip rendering.")
                else:
                    if incremental_enabled and not filename_rendered_exists:
                        logging.info(f"Rendering {fname}: file does not exist")
                    elif incremental_enabled and not page_is_full:
                        logging.info(f"Rendering {fname}: page not full ({len(messages)}/{self.config['per_page']} messages)")
                    self._render_page(messages, month, dayline,
                                      fname, page, total_pages)

        # The last page chronologically is the latest page. Make it index.
        if fname:
            if self.symlink:
                os.symlink(fname, os.path.join(self.config["publish_dir"], "index.html"))
            else:
                shutil.copy(os.path.join(self.config["publish_dir"], fname),
                            os.path.join(self.config["publish_dir"], "index.html"))

        # Generate RSS feeds.
        if self.config["publish_rss_feed"]:
            self._build_rss(rss_entries, "index.rss", "index.atom")

        # Optimize static files (CSS/JS minification)
        self._optimize_static_files()

    def load_template(self, fname):
        with open(fname, "r") as f:
            self.template = Template(f.read(), autoescape=True)

    def load_rss_template(self, fname):
        with open(fname, "r") as f:
            self.rss_template = Template(f.read(), autoescape=True)

    def make_filename(self, month, page) -> str:
        fname = "{}{}.html".format(
            month.slug, "_" + str(page) if page > 1 else "")
        return fname

    def _render_page(self, messages, month, dayline, fname, page, total_pages):
        logging.info(f"Rendering: {fname}")
        html = self.template.render(config=self.config,
                                    timeline=self.timeline,
                                    dayline=dayline,
                                    month=month,
                                    messages=messages,
                                    page_ids=self.page_ids,
                                    pagination={"current": page,
                                                "total": total_pages},
                                    make_filename=self.make_filename,
                                    nl2br=self._nl2br)

        # Minify HTML unless in debug mode
        if not self.config.get("debug_mode", False):
            html = minify_html(html, remove_comments=True, remove_empty_space=True)

        with open(os.path.join(self.config["publish_dir"], fname), "w", encoding="utf8") as f:
            f.write(html)

    def _render_day_counter(self, day):
        """Render day counter file for a specific day."""
        fname = f"day-counter-{day.slug}.js"
        logging.info(f"Rendering: {fname}")
        # Day counter files would use a template if available
        # For now, this is a placeholder that can be extended when templates are added
        # The original implementation expects a _day_counter_template
        pass

    def _build_rss(self, messages, rss_file, atom_file):
        f = FeedGenerator()
        f.id(self.config["site_url"])

        # Try to get version from package metadata, fall back to internal version
        try:
            pkg_version = version("tg-archive")
        except Exception:
            pkg_version = package_version

        f.generator("tg-archive {}".format(pkg_version))
        f.link(href=self.config["site_url"], rel="alternate")
        f.title(self.config["site_name"].format(group=self.config["group"]))
        f.subtitle(self.config["site_description"])

        for m in messages:
            url = "{}/{}#{}".format(self.config["site_url"],
                                    self.page_ids[m.id], m.id)
            e = f.add_entry()
            e.id(url)
            e.title("@{} on {} (#{})".format(m.user.username, m.date, m.id))
            e.link({"href": url})
            e.published(m.date)

            media_mime = ""
            if m.media and m.media.url:
                murl = "{}/{}/{}".format(self.config["site_url"],
                                         os.path.basename(self.config["media_dir"]), m.media.url)
                media_path = "{}/{}".format(self.config["media_dir"], m.media.url)
                media_mime = "application/octet-stream"
                media_size = 0

                if "://" in media_path:
                    media_mime = "text/html"
                else:
                    try:
                        media_size = str(os.path.getsize(media_path))
                        try:
                            media_mime = magic.from_file(media_path, mime=True)
                        except:
                            pass
                    except FileNotFoundError:
                        pass

                e.enclosure(murl, media_size, media_mime)
            e.content(self._make_abstract(m, media_mime), type="html")

        f.rss_file(os.path.join(self.config["publish_dir"], "index.xml"), pretty=True)
        f.atom_file(os.path.join(self.config["publish_dir"], "index.atom"), pretty=True)

    def _make_abstract(self, m, media_mime):
        if self.rss_template:
            return self.rss_template.render(config=self.config,
                                            m=m,
                                            media_mime=media_mime,
                                            page_ids=self.page_ids,
                                            nl2br=self._nl2br)
        out = m.content
        if not out and m.media:
            out = m.media.title
        return out if out else ""

    def _nl2br(self, s) -> str:
        # There has to be a \n before <br> so as to not break
        # Jinja's automatic hyperlinking of URLs.
        return _NL2BR.sub("\n\n", s).replace("\n", "\n<br />")

    def _create_publish_dir(self):
        logging.info("Creating publish tree if needed.")
        pubdir = self.config["publish_dir"]

        incremental = self.config.get("incremental_builds", False)
        logging.info(f"Incremental builds setting: {incremental}")

        # Clear the output directory HTML files, if not incremental_builds
        if not incremental:
            if os.path.exists(pubdir):
                # Remove contents instead of directory itself (handles volume mounts)
                for item in os.listdir(pubdir):
                    item_path = os.path.join(pubdir, item)
                    try:
                        if os.path.isfile(item_path) or os.path.islink(item_path):
                            os.unlink(item_path)
                        elif os.path.isdir(item_path):
                            shutil.rmtree(item_path)
                    except Exception as e:
                        logging.warning(f"Failed to remove {item_path}: {e}")

        # Re-create the output directory.
        Path(pubdir).mkdir(parents=True, exist_ok=True)

        # Copy the static directory into the output directory.
        static_dir = self.config["static_dir"]
        if not os.path.exists(os.path.join(pubdir, os.path.basename(static_dir))):
            for f in [static_dir]:
                target = os.path.join(pubdir, f)
                if self.symlink:
                    self._relative_symlink(os.path.abspath(f), target)
                elif os.path.isfile(f):
                    shutil.copyfile(f, target)
                else:
                    shutil.copytree(f, target)

        # If media downloading is enabled, copy/symlink the media directory.
        mediadir = self.config["media_dir"]
        if not os.path.exists(os.path.abspath(os.path.join(pubdir, os.path.basename(mediadir)))):
            if os.path.exists(mediadir):
                if self.symlink:
                    self._relative_symlink(os.path.abspath(mediadir), os.path.join(
                        pubdir, os.path.basename(mediadir)))
                else:
                    try:
                        shutil.copytree(mediadir, os.path.join(
                            pubdir, os.path.basename(mediadir)), dirs_exist_ok=True)
                    except Exception as e:
                        pass

    def _relative_symlink(self, src, dst):
        dir_path = os.path.dirname(dst)
        src = os.path.relpath(src, dir_path)
        dst = os.path.join(dir_path, os.path.basename(src))
        return os.symlink(src, dst)

    def _optimize_static_files(self):
        """Minify CSS and JS files in the static directory."""
        import csscompressor
        from jsmin import jsmin

        static_target = os.path.join(
            self.config["publish_dir"],
            os.path.basename(self.config["static_dir"])
        )

        # Skip if debug mode
        if self.config.get("debug_mode", False):
            logging.info("Debug mode: skipping static file optimization")
            return

        # Minify CSS
        css_path = os.path.join(static_target, "style.css")
        if os.path.exists(css_path):
            logging.info("Minifying CSS...")
            with open(css_path, 'r', encoding='utf8') as f:
                css_content = f.read()

            minified_css = csscompressor.compress(css_content)

            with open(css_path, 'w', encoding='utf8') as f:
                f.write(minified_css)

            reduction = 100 - int(len(minified_css) / len(css_content) * 100)
            logging.info(f"CSS: {len(css_content)} → {len(minified_css)} bytes ({reduction}% reduction)")

        # Minify main.js
        js_path = os.path.join(static_target, "main.js")
        if os.path.exists(js_path):
            logging.info("Minifying JavaScript...")
            with open(js_path, 'r', encoding='utf8') as f:
                js_content = f.read()

            minified_js = jsmin(js_content)

            with open(js_path, 'w', encoding='utf8') as f:
                f.write(minified_js)

            reduction = 100 - int(len(minified_js) / len(js_content) * 100)
            logging.info(f"JS: {len(js_content)} → {len(minified_js)} bytes ({reduction}% reduction)")
