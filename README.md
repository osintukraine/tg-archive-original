
![favicon](https://user-images.githubusercontent.com/547147/111869334-eb48f100-89a4-11eb-9c0c-bc74cdee197a.png)


**tg-archive** is a tool for exporting Telegram group chats into static websites, preserving chat history like mailing list archives.

**IMPORTANT:** I'm no longer actively maintaining or developing this tool. Can review and merge PRs (as long as they're not massive and are clearly documented).

## Preview
The [@fossunited](https://tg.fossunited.org) Telegram group archive.

![image](https://user-images.githubusercontent.com/547147/111869398-44188980-89a5-11eb-936f-01d98276ba6a.png)


## How it works
tg-archive uses the [Telethon](https://github.com/LonamiWebs/Telethon) Telegram API client to periodically sync messages from a group to a local SQLite database (file), downloading only new messages since the last sync. It then generates a static archive website of messages to be published anywhere.

## Features
- Periodically sync Telegram group messages to a local DB.
- Download user avatars locally.
- Download and embed media (files, documents, photos).
- **Organize media into datetime subdirectories** for better file management.
- **Incremental builds** - only rebuild changed pages for faster publishing.
- **Lazy loading** with lozad.js for improved page performance.
- **Reverse message order** (new_on_top) for blog-style archives.
- Renders poll results.
- Use emoji alternatives in place of stickers.
- Single file Jinja HTML template for generating the static site.
- Year / Month / Day indexes with deep linking across pages.
- "In reply to" on replies with links to parent messages across pages.
- RSS / Atom feed of recent messages.

## Requirements
- **Python 3.12+** (tested with Python 3.12)
- Get [Telegram API credentials](https://my.telegram.org/auth?to=apps). Normal user account API and not the Bot API.
  - If this page produces an alert stating only "ERROR", disconnect from any proxy/vpn and try again in a different browser.

## Install

### From PyPI
```bash
pip install tg-archive
```

### With Docker
```bash
# Build the image
docker build -t tg-archive .

# Run commands (example)
docker run --rm -v /path/to/sites:/sites tg-archive --config=/sites/mysite/config.yaml --sync
```

The Docker image is based on `python:3.12-slim` and includes all necessary dependencies.

### Usage

1. `tg-archive --new --path=mysite` (creates a new site. `cd` into mysite and edit `config.yaml`).
1. `tg-archive --sync` (syncs data into `data.sqlite`).
  Note: First time connection will prompt for your phone number + a Telegram auth code sent to the app. On successful auth, a `session.session` file is created. DO NOT SHARE this session file publicly as it contains the API autorization for your account.
1. `tg-archive --build` (builds the static site into the `site` directory, which can be published)

### Configuration Options

The following options can be added to `config.yaml`:

#### Media Organization
```yaml
media_datetime_subdir: "%Y-%m-%d"
```
Organizes downloaded media files into date-based subdirectories instead of a flat structure. This is especially useful for archives with large amounts of media, making file management easier and avoiding issues with too many files in a single directory.

- Format uses Python's strftime format (e.g., `"%Y-%m-%d"` creates `2025-10-20/` subdirectories)
- Leave empty (`""`) to disable and use flat directory structure (default)
- Applies to newly downloaded media; existing media is not reorganized

#### Incremental Builds
```yaml
incremental_builds: true
```
Only rebuilds pages that have changed since the last build, dramatically speeding up the build process for large archives. When enabled:
- Skips rendering pages that already exist and haven't changed
- Always rebuilds the most recent pages to ensure accuracy
- Recommended for production use with frequent updates
- Default: `true`

Set to `false` to force a complete rebuild of all pages (useful after template changes).

#### Message Ordering
```yaml
new_on_top: false
```
Reverses the message display order to show newest messages first (blog-style) instead of oldest first (forum-style).
- `false` (default): Traditional archive style - oldest messages first, newest at the end
- `true`: Blog style - newest messages first, useful for news channels or announcement groups
- Affects both page rendering and pagination order

#### Lazy Loading
Lazy loading is automatically enabled in the default template using [lozad.js](https://github.com/ApoorvSaxena/lozad.js). Images and videos are only loaded when they become visible in the viewport, which:
- Significantly improves initial page load time
- Reduces bandwidth usage for users who don't scroll through the entire page
- Improves performance on mobile devices

No configuration required - it's built into the template. To disable, edit `template.html` and remove the lozad.js references.

### Customization
Edit the generated `template.html` and static assets in the `./static` directory to customize the site.

### Note
- The sync can be stopped (Ctrl+C) any time to be resumed later.
- Setup a cron job to periodically sync messages and re-publish the archive.
- Downloading large media files and long message history from large groups continuously may run into Telegram API's rate limits. Watch the debug output.

Licensed under the MIT license.
