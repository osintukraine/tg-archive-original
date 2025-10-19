# Docker Guide for tg-archive

This guide shows how to use tg-archive with Docker for easy deployment and isolation.

## Prerequisites

- Docker installed
- Docker Compose installed (optional, but recommended)
- Telegram API credentials (get them from https://my.telegram.org/auth?to=apps)

## Quick Start

### 1. Build the Docker Image

```bash
docker-compose build
```

Or build directly:

```bash
docker build -t tg-archive:latest .
```

### 2. Create a New Site

```bash
docker run --rm \
  --user="$(id -u):$(id -g)" \
  -v $(pwd)/sites:/sites \
  tg-archive:latest --new --path=/sites/mysite
```

### 3. Configure Your Site

Edit `sites/mysite/config.yaml` and set:
- `api_id`: Your Telegram API ID
- `api_hash`: Your Telegram API hash
- `group`: The Telegram group/channel to archive

### 4. Create Session (First Time Only)

This step requires interactive input for phone number and verification code:

```bash
docker run --rm -it \
  --user="$(id -u):$(id -g)" \
  -v $(pwd)/sites:/sites \
  tg-archive:latest \
  --config=/sites/mysite/config.yaml \
  --session=/sites/session.session
```

### 5. Sync Messages

Download messages from Telegram:

```bash
docker run --rm \
  --user="$(id -u):$(id -g)" \
  -v $(pwd)/sites:/sites \
  tg-archive:latest \
  --config=/sites/mysite/config.yaml \
  --session=/sites/session.session \
  --sync
```

### 6. Build Static Site

Generate the HTML archive:

```bash
docker run --rm \
  --user="$(id -u):$(id -g)" \
  -v $(pwd)/sites:/sites \
  tg-archive:latest \
  --config=/sites/mysite/config.yaml \
  --build
```

## Using Docker Compose

Create a `.env` file in your project root:

```env
CURRENT_UID=1000:1000
API_ID=your_api_id
API_HASH=your_api_hash
```

Then you can use shorter commands:

```bash
# Build image
docker-compose build

# Create new site
docker-compose run --rm tg-archive --new --path=/sites/mysite

# Sync messages
docker-compose run --rm tg-archive --config=/sites/mysite/config.yaml --session=/sites/session.session --sync

# Build site
docker-compose run --rm tg-archive --config=/sites/mysite/config.yaml --build
```

## Advanced Usage

### Mounting Media Directory Separately

To avoid duplicating media files, mount the media directory directly to your web server:

```bash
# Create media directory
mkdir -p /var/www/html/mysite/media

# Sync with media directory mounted
docker run --rm \
  --user="$(id -u):$(id -g)" \
  -v $(pwd)/sites:/sites \
  -v /var/www/html/mysite/media:/sites/mysite/media \
  tg-archive:latest \
  --config=/sites/mysite/config.yaml \
  --session=/sites/session.session \
  --sync

# Build with media directory mounted
docker run --rm \
  --user="$(id -u):$(id -g)" \
  -v $(pwd)/sites:/sites \
  -v /var/www/html/mysite:/sites/mysite/site \
  -v /var/www/html/mysite/media:/sites/mysite/media \
  tg-archive:latest \
  --config=/sites/mysite/config.yaml \
  --build
```

### Using Environment Variables

You can pass API credentials via environment variables instead of config file:

```bash
docker run --rm \
  --user="$(id -u):$(id -g)" \
  -v $(pwd)/sites:/sites \
  -e API_ID=your_api_id \
  -e API_HASH=your_api_hash \
  tg-archive:latest \
  --config=/sites/mysite/config.yaml \
  --session=/sites/session.session \
  --sync
```

### Automated Sync with Cron

Create a script `sync.sh`:

```bash
#!/bin/bash
docker run --rm \
  --user="$(id -u):$(id -g)" \
  -v /path/to/sites:/sites \
  tg-archive:latest \
  --config=/sites/mysite/config.yaml \
  --session=/sites/session.session \
  --sync

docker run --rm \
  --user="$(id -u):$(id -g)" \
  -v /path/to/sites:/sites \
  tg-archive:latest \
  --config=/sites/mysite/config.yaml \
  --build
```

Add to crontab to run every hour:

```cron
0 * * * * /path/to/sync.sh >> /var/log/tg-archive-sync.log 2>&1
```

## Troubleshooting

### Permission Issues

If you get permission errors, ensure you're using the correct user ID:

```bash
# Find your UID and GID
id -u  # Your user ID
id -g  # Your group ID

# Use them explicitly
docker run --user="1000:1000" ...
```

### Session Expired

If your session expires, delete the session file and recreate it:

```bash
rm sites/session.session
# Then run the create session command again
```

### Out of Memory

For large archives, increase Docker's memory limit:

```yaml
# In docker-compose.yaml
services:
  tg-archive:
    mem_limit: 2g
    memswap_limit: 2g
```

## Directory Structure

```
.
├── sites/
│   ├── session.session          # Telegram session (shared)
│   └── mysite/
│       ├── config.yaml          # Site configuration
│       ├── data.db              # SQLite database
│       ├── media/               # Downloaded media
│       └── site/                # Generated HTML
├── Dockerfile
├── docker-compose.yaml
└── entrypoint.sh
```

## Security Notes

1. **Never commit** `session.session` or `config.yaml` with real credentials
2. **Use `.gitignore`** to exclude sensitive files
3. **Use environment variables** for credentials in CI/CD pipelines
4. **Restrict file permissions** on session files (600 or 400)
5. **Rotate API keys** regularly if they're exposed

## Performance Tips

1. **Enable incremental builds** in config.yaml:
   ```yaml
   incremental_builds: True
   ```

2. **Use date-based media subdirectories** for better filesystem performance:
   ```yaml
   media_datetime_subdir: "%Y-%m-%d"
   ```

3. **Mount volumes** instead of copying for faster builds

4. **Use multi-core systems** - Telegram API is rate-limited per connection, not per core

## See Also

- Main README: `/README.md`
- Example configuration: `tgarchive/example/config.yaml`
- Official Telegram API docs: https://core.telegram.org/api
