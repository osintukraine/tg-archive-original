# Upgrading Existing TG-Archive Sites

This guide helps you upgrade existing tg-archive sites to use the latest templates, static files, and features from this fork.

## What's New

This fork includes several improvements:

1. **Lazy Loading** - Images and videos load on-demand using lozad.js for better performance
2. **Cache Busting** - Build timestamps prevent browser caching issues
3. **Incremental Builds** - Only rebuild changed pages instead of entire site (much faster)
4. **Media Date Subdirectories** - Organize media files by date to avoid filesystem issues
5. **New on Top** - Option to display newest messages first (blog-style)
6. **Rich Logging** - Better terminal output with rich library
7. **Docker Support** - Complete Docker setup with resource limits

## Prerequisites

- Python 3.12+ with tgarchive dependencies installed (see requirements.txt)
- Existing site directories with config.yaml, data.sqlite, template.html
- For Docker-based syncing: Docker image built as `tg-archive:latest` (optional)

## Quick Migration

### Batch Migration (Recommended)

Migrate all sites in a directory at once with optional rebuild:

```bash
# From the tg-archive-fork directory

# Text/image archives
./migrate-all-sites.sh /home/tg-archive/sites --rebuild

# Video archives
./migrate-all-sites.sh /home/tg-archive-video/sites --rebuild
```

The script will:
- 🔍 Auto-detect all sites (any directory with config.yaml)
- 📦 Backup existing files to `backup-YYYYMMDD-HHMMSS/` in each site
- ✅ Update template.html with lazy loading and cache busting
- ✅ Add lozad.min.js to static directory
- ✅ Update main.js and styles.css
- 🏗️ Perform full rebuild using local Python (if --rebuild flag used)
- 📊 Show build statistics and where generated files are
- 📝 Create detailed migration log

**Note**: The rebuild uses local Python 3 (`python3 -c "from tgarchive import main; main()"`), not Docker. Ensure you have tgarchive dependencies installed.

### Single Site Migration

For migrating just one site:

```bash
./migrate-site.sh /path/to/your/site

# Example:
./migrate-site.sh /home/tg-archive/sites/amplifyukraine
```

Note: This only updates templates/static files - you'll need to rebuild manually.

## Manual Migration

If you prefer to update manually:

### 1. Backup Your Site

```bash
cd /path/to/your/site
tar -czf backup-$(date +%Y%m%d).tar.gz config.yaml template.html static/
```

### 2. Update Template

Copy the new template from this fork:

```bash
cp /path/to/tg-archive-fork/tgarchive/example/template.html ./template.html
```

Or manually update your existing template.html with these changes:

- Add lozad.js script tag before closing `</body>`:
  ```html
  <script src="static/lozad.min.js"></script>
  ```

- Update cache busting on main.js:
  ```html
  <script src="static/main.js?{{ config.build_timestamp }}"></script>
  ```

- Update image/video tags for lazy loading:
  ```html
  <!-- Images -->
  <img class="lozad"
       data-src="{{ config.media_dir }}/{{ m.media.url }}"
       alt="{{ m.media.title }}">

  <!-- Videos -->
  <video class="lozad"
         data-src="{{ config.media_dir }}/{{ m.media.url }}"
         {% if m.media.thumb %}poster="{{ config.media_dir }}/{{ m.media.thumb }}"{% endif %}
         controls>
  </video>
  ```

### 3. Update Static Files

```bash
# Copy lozad.js (new file)
cp /path/to/tg-archive-fork/tgarchive/example/static/lozad.min.js ./static/

# Update main.js
cp /path/to/tg-archive-fork/tgarchive/example/static/main.js ./static/

# Optionally update styles.css
cp /path/to/tg-archive-fork/tgarchive/example/static/styles.css ./static/
```

### 4. Update config.yaml

Add these new configuration options to your `config.yaml`:

```yaml
# Organize media into date-based subdirectories. Uses Python's strftime format.
# Examples: "%Y-%m-%d" (2024-10-19), "%Y/%m" (2024/10), "" (disabled)
# Helps prevent filesystem performance issues with thousands of files in one directory.
media_datetime_subdir: ""

# Incremental builds - only rebuild changed pages instead of entire site.
# Significantly faster for incremental updates. Set to False to always rebuild everything.
incremental_builds: True

# Display order - show newest messages first (like a blog) or oldest first (like a forum).
# True: Newest messages appear on page 1 (blog-style, recommended for news/updates)
# False: Oldest messages appear on page 1 (forum-style, chronological order)
# Default: False (maintains backward compatibility)
new_on_top: False
```

## Rebuild Your Site

After updating files, rebuild your site using local Python:

```bash
# From the tg-archive-fork directory
cd /path/to/tg-archive-fork

python3 -c "from tgarchive import main; main()" \
  --config=/home/tg-archive/sites/amplifyukraine/config.yaml \
  --data=/home/tg-archive/sites/amplifyukraine/data.sqlite \
  --template=/home/tg-archive/sites/amplifyukraine/template.html \
  --build
```

**Alternative**: Use Docker if you prefer (requires __main__.py to be added):
```bash
docker run --rm --user="$(id -u):$(id -g)" \
  -v /home/tg-archive/sites:/sites \
  tg-archive:latest \
  --config=/sites/amplifyukraine/config.yaml \
  --data=/sites/amplifyukraine/data.sqlite \
  --template=/sites/amplifyukraine/template.html \
  --build
```

## Testing

1. Check the rebuild completed successfully:
   ```bash
   ls -la /sites/amplifyukraine/public/
   ```

2. Verify lazy loading is working:
   - Open site in browser
   - Open Developer Tools → Network tab
   - Scroll down the page
   - Images/videos should load only when scrolled into view

3. Check cache busting:
   - View page source
   - Find `<script src="static/main.js?TIMESTAMP">`
   - Timestamp should match your latest build

## Using New Features

### Incremental Builds

By default, incremental builds are enabled. This makes subsequent builds much faster:

```bash
# First build (full): ~60 seconds for 10,000 messages
# Subsequent builds: ~5-10 seconds (only new/changed pages)
```

To force a full rebuild:
```yaml
incremental_builds: False
```

### Media Date Subdirectories

Organize media files by date to avoid filesystem performance issues:

```yaml
# Daily folders: media/2024-10-19/12345.jpg
media_datetime_subdir: "%Y-%m-%d"

# Monthly folders: media/2024/10/12345.jpg
media_datetime_subdir: "%Y/%m"

# Disabled (all files in media/)
media_datetime_subdir: ""
```

**Note**: This only affects newly downloaded media. Existing media files are not moved.

### New on Top (Blog Style)

Show newest messages first instead of chronological order:

```yaml
new_on_top: True
```

This is useful for:
- News channels where latest updates are most important
- Announcement groups
- Any feed where recency matters more than chronology

## Updating Your Docker Commands

Your existing docker run commands should work with the new image. Just update the image tag:

**Before:**
```bash
docker run ... old-image-name ...
```

**After:**
```bash
docker run ... tg-archive:latest ...
```

All volume mounts, user settings, and resource limits remain the same.

## Rollback

If something goes wrong, restore from backup:

```bash
cd /path/to/your/site
tar -xzf backup-20241019.tar.gz
```

Or use the automatic backup created by migrate-site.sh:

```bash
cp backup-YYYYMMDD-HHMMSS/template.html ./
cp backup-YYYYMMDD-HHMMSS/config.yaml ./
cp -r backup-YYYYMMDD-HHMMSS/static/* ./static/
```

## Troubleshooting

### Lazy loading not working

Check browser console for errors. Ensure lozad.min.js is loaded:
```bash
ls -la static/lozad.min.js
```

### Build is slow

Enable incremental builds if not already:
```yaml
incremental_builds: True
```

### Media files not found

If you enabled `media_datetime_subdir`, newly downloaded media will be in subdirectories.
Old media files remain in the root media directory. Both locations work fine.

### Docker permission issues

Ensure you're running with correct user:
```bash
docker run --user="$(id -u):$(id -g)" ...
```

## Support

- See MERGE_SUMMARY.md for detailed list of all changes
- Check Dockerfile for Docker-specific setup
- Review tgarchive/example/ for reference implementation
