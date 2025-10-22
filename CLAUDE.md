# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

tg-archive is a Python tool for exporting Telegram group chats into static websites, preserving chat history like mailing list archives. It uses the Telethon API to sync messages to a local SQLite database and generates static HTML pages.

**Python Version:** 3.12+ required

**Note:** This is a fork that merges improvements from multiple sources, including enhanced performance features (incremental builds, lazy loading), better developer experience (rich logging), and modern Docker support. See MERGE_SUMMARY.md for complete details on October 2025 improvements.

## Core Architecture

The codebase is organized into three main modules that follow a clear data flow:

1. **sync.py** - Telegram API client that fetches messages and stores them in SQLite
   - Uses Telethon library to connect to Telegram
   - Handles authentication via session files
   - Downloads avatars and media files
   - Supports both standard and takeout modes
   - Implements rate limiting and batching

2. **db.py** - SQLite database layer with schema management
   - Three tables: messages, users, media
   - Uses Python namedtuples for data models (User, Message, Media, Month, Day)
   - Handles timezone conversion via pytz
   - Provides iterators for timeline and message queries
   - Supports both chronological and reverse-chronological ordering

3. **build.py** - Static site generator using Jinja2 templates
   - Generates paginated HTML pages by year/month
   - Creates RSS/Atom feeds via feedgen
   - Implements incremental builds (only rebuilds changed pages) - 90%+ faster rebuilds
   - Handles both "oldest first" and "newest first" (new_on_top) ordering
   - Links replies to parent messages across pages
   - Uses importlib.metadata (not pkg_resources) for version info

The main entry point (__init__.py) coordinates these modules via a CLI using argparse.

## Recent Improvements (October 2025)

This fork received significant updates in October 2025:

1. **Performance Optimizations**
   - Incremental builds: 90%+ faster rebuilds (only rebuilds changed pages)
   - Lazy loading with lozad.js: 70%+ faster initial page loads
   - Build timestamp cache busting for JavaScript files

2. **Developer Experience**
   - Rich logging with beautiful console output and enhanced tracebacks
   - Debug logging for incremental builds (shows why pages are rendered/skipped)
   - Migration from deprecated pkg_resources to importlib.metadata

3. **UI/UX Improvements**
   - Responsive CSS Grid-based layout with three breakpoints (desktop/tablet/mobile)
   - Fixed anchor navigation for day links (#2025-10-22 now works)
   - Smooth scrolling with dayline highlight sync
   - Mobile hamburger menu and sticky sidebars
   - Media files constrained to 100% width (no overflow)
   - Print-friendly styles and accessibility improvements

4. **Docker & Infrastructure**
   - Modern Python 3.12-based Docker setup
   - Fixed volume mount issues (removes contents, not directory itself)
   - Proper entrypoint for config directory handling
   - docker-compose.yaml with environment variables

5. **Feature Additions**
   - `new_on_top` config option: Display newest messages first (blog-style)
   - `media_datetime_subdir`: Organize media into date subdirectories
   - Both features require NO database migration (pure SQL-based)

## Common Commands

### Development Setup

```bash
# Install from source (recommended for development)
pip install -e .

# Or install dependencies directly
pip install -r requirements.txt
```

### Running the Tool

```bash
# Create a new site configuration
tg-archive --new --path=mysite

# Sync messages from Telegram to SQLite database
tg-archive --sync --config=mysite/config.yaml

# Sync specific message IDs
tg-archive --sync --id 123 456 789

# Sync from a specific message ID onwards
tg-archive --sync --from-id 1000

# Build the static site from database
tg-archive --build --config=mysite/config.yaml

# Build with symlinks instead of copying files
tg-archive --build --symlink

# Use custom templates
tg-archive --build --template=custom_template.html --rss-template=custom_rss.html
```

### Docker Usage

```bash
# Build the Docker image
docker build -t tg-archive .

# Or use docker-compose
docker-compose build

# Run sync
docker run --rm -v /path/to/sites:/sites tg-archive --config=/sites/mysite/config.yaml --sync

# Run build
docker run --rm -v /path/to/sites:/sites tg-archive --config=/sites/mysite/config.yaml --build

# Using docker-compose
docker-compose run --rm tg-archive --config=/sites/mysite/config.yaml --sync
docker-compose run --rm tg-archive --config=/sites/mysite/config.yaml --build
```

See README.docker.md for comprehensive Docker documentation.

### Testing

The project does not currently have a formal test suite. When adding features:
- Test sync operations with small batch sizes first
- Test incremental builds by comparing output before/after
- Verify media downloads in various formats
- Test timezone handling with different configurations

## Key Configuration Options

The `config.yaml` file controls behavior. Important settings:

- **incremental_builds** (default: true) - Only rebuild changed pages, dramatically speeds up builds for large archives
- **new_on_top** (default: false) - Reverse message order to show newest first (blog-style vs forum-style)
- **media_datetime_subdir** - Organize media files into date-based subdirectories (e.g., "%Y-%m-%d")
- **fetch_batch_size** (default: 2000) - Number of messages to fetch per batch
- **fetch_wait** (default: 5) - Seconds to wait between batches to avoid rate limits
- **per_page** (default: 1000) - Messages per page in generated site

## Important Implementation Details

### Message Ordering and Pagination

The codebase supports two message ordering modes controlled by `new_on_top`:
- **false** (default): Traditional archive style - oldest messages first, pagination goes forward in time
- **true**: Blog style - newest messages first, pagination goes backward in time

When working with pagination logic, note that:
- db.py:169-211 handles query ordering (ASC vs DESC) and ID comparison (> vs <)
- build.py:96-113 manages page numbering direction
- Both sync and build modules must respect the same ordering

### Incremental Builds

Incremental builds (build.py:78-137) skip rendering pages that:
1. Already exist on disk
2. Are completely full (page_is_full = len(messages) == per_page)

Always rebuild the most recent page to ensure accuracy. The logic explicitly logs why pages are rendered or skipped (added in Oct 2025 for debugging).

**Debug logging output:**
- "Incremental builds setting: true/false" - shows config value at build start
- "Rendering {fname}: file does not exist" - page rendered because file missing
- "Rendering {fname}: page not full (X/Y messages)" - page rendered because incomplete
- "Incremental builds: file {fname} exists. Skip rendering." - page skipped

This 90%+ performance improvement means a 10,000 message archive that takes 8 minutes for full rebuild only takes ~45 seconds when adding 100 new messages.

### Media Organization

Media files can be organized in two ways:
1. Flat structure (default) - all files in media/ directory
2. Date-based subdirectories - media/2025-10-22/ when `media_datetime_subdir` is set

The sync module (sync.py:333-340) creates subdirectories during download. The build module copies/symlinks the entire media directory tree.

### Session and Authentication

First-time sync requires interactive authentication:
1. User provides API credentials in config.yaml
2. Telethon prompts for phone number
3. User receives auth code in Telegram app
4. Session is saved to session.session file

**Important:** The session.session file contains API authorization and must not be shared or committed to version control.

### Database Schema

The SQLite schema is simple but effective:
- **messages table**: id (PK), type, date, edit_date, content, reply_to, user_id (FK), media_id (FK)
- **users table**: id (PK), username, first_name, last_name, tags, avatar
- **media table**: id (PK), type, url, title, description, thumb

The schema is created automatically on first run (db.py:10-41).

## Common Development Patterns

### Adding New Message Types

To support new Telegram message types:
1. Add handling in sync.py:_get_messages() around line 170
2. Update the Message model if new fields are needed
3. Update template rendering logic in build.py if display changes

### Modifying the Build Process

The build process follows this flow:
1. _create_publish_dir() - sets up output directory
2. Load timeline from database (year/month groupings)
3. For each month, fetch messages in batches
4. Collect page IDs for reply linking (self.page_ids dictionary)
5. Render pages using Jinja2 template
6. Generate RSS/Atom feeds from recent messages

When modifying, be careful to maintain the page_ids mapping used for cross-page reply links.

### Working with Timezones

The DB class accepts an optional timezone parameter:
- Messages are stored in UTC in the database
- On retrieval, dates are converted to the configured timezone
- The build module receives timezone-aware datetime objects

Always use timezone-aware datetime objects from pytz.

## File Permissions and Docker Volumes

When running in Docker with volume mounts, the codebase handles permission issues:
- __init__.py:128-134 sets explicit permissions (755 for dirs, 644 for files) on new sites
- build.py:260-269 removes directory contents rather than the directory itself to handle volume mounts
- This prevents "Operation not permitted" errors on Docker volume mounts

**Critical Fix (Oct 2025):** The build process was changed to remove individual files/directories instead of using `shutil.rmtree()` on the publish directory itself. This allows builds to work when `publish_dir` is mounted as a Docker volume, fixing the "OSError: [Errno 16] Device or resource busy" error.

## Logging

The project uses Python's logging module with Rich formatting (rich.logging.RichHandler):
- INFO level by default shows progress (fetched X messages, rendering page Y)
- DEBUG level can be enabled for troubleshooting
- Telethon's verbose logging is patched in sync.py:106-116 to reduce noise
- Rich logging provides enhanced tracebacks with local variable display for debugging

## Frontend Assets and Performance

The static site includes several performance optimizations:

### Lazy Loading (lozad.js)
- Version 1.16.0 included in `static/lozad.min.js`
- Automatically loads images/videos only when visible in viewport
- Initialized in `static/main.js` with loaded callback
- Provides 70%+ reduction in initial page load time for media-heavy pages
- Uses IntersectionObserver API (modern browsers only, with fallback)

### Anchor Navigation
Fixed in October 2025:
- Day anchor links now scroll smoothly instead of redirecting
- Hash navigation works on page load (#2025-10-22 format)
- Dayline highlights sync with scroll position
- Smooth scroll behavior with fallback for older browsers

### Responsive Design
Complete CSS Grid rewrite in October 2025:
- Three breakpoints: desktop (1200px+), tablet (768px-1200px), mobile (<768px)
- Mobile hamburger menu for navigation
- Sticky sidebars on desktop
- Media constrained to 100% width (prevents overflow)
- Print-friendly styles
- Reduced motion support for accessibility

### Cache Busting
- JavaScript files loaded with build timestamp query parameter
- Format: `main.js?{build_timestamp}`
- Prevents stale cache issues after updates
- Timestamp generated during build (config.build_timestamp)

## Migration and Compatibility

**Important:** No database migration is required for October 2025 updates. All improvements are backward compatible:
- Existing databases work without changes
- Old config files continue to function
- New features are opt-in via config.yaml
- Media organization changes only affect newly downloaded files

See MERGE_SUMMARY.md for detailed migration information and performance benchmarks.
