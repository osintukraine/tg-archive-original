#!/bin/bash
# Migration script to update existing tg-archive sites with new templates and static files
# Usage: ./migrate-site.sh /path/to/site

set -e

SITE_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$SCRIPT_DIR/tgarchive/example"

if [ -z "$SITE_DIR" ]; then
    echo "Usage: $0 /path/to/site"
    echo "Example: $0 /home/tg-archive/sites/amplifyukraine"
    exit 1
fi

if [ ! -d "$SITE_DIR" ]; then
    echo "Error: Site directory '$SITE_DIR' does not exist"
    exit 1
fi

echo "=== TG-Archive Site Migration Tool ==="
echo "Site directory: $SITE_DIR"
echo "Example directory: $EXAMPLE_DIR"
echo ""

# Backup existing files
BACKUP_DIR="$SITE_DIR/backup-$(date +%Y%m%d-%H%M%S)"
echo "Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Backup template if exists
if [ -f "$SITE_DIR/template.html" ]; then
    cp "$SITE_DIR/template.html" "$BACKUP_DIR/template.html"
    echo "✓ Backed up template.html"
fi

# Backup config if exists
if [ -f "$SITE_DIR/config.yaml" ]; then
    cp "$SITE_DIR/config.yaml" "$BACKUP_DIR/config.yaml"
    echo "✓ Backed up config.yaml"
fi

# Backup static directory if exists
if [ -d "$SITE_DIR/static" ]; then
    cp -r "$SITE_DIR/static" "$BACKUP_DIR/static"
    echo "✓ Backed up static directory"
fi

echo ""
echo "=== Updating Files ==="

# Copy new template
if [ -f "$EXAMPLE_DIR/template.html" ]; then
    cp "$EXAMPLE_DIR/template.html" "$SITE_DIR/template.html"
    echo "✓ Updated template.html"
else
    echo "✗ Warning: Could not find new template.html"
fi

# Copy new static files
if [ -d "$EXAMPLE_DIR/static" ]; then
    mkdir -p "$SITE_DIR/static"

    # Copy lozad.min.js (new file)
    if [ -f "$EXAMPLE_DIR/static/lozad.min.js" ]; then
        cp "$EXAMPLE_DIR/static/lozad.min.js" "$SITE_DIR/static/lozad.min.js"
        echo "✓ Added lozad.min.js"
    fi

    # Update main.js
    if [ -f "$EXAMPLE_DIR/static/main.js" ]; then
        cp "$EXAMPLE_DIR/static/main.js" "$SITE_DIR/static/main.js"
        echo "✓ Updated main.js"
    fi

    # Update styles.css
    if [ -f "$EXAMPLE_DIR/static/styles.css" ]; then
        cp "$EXAMPLE_DIR/static/styles.css" "$SITE_DIR/static/styles.css"
        echo "✓ Updated styles.css"
    fi
else
    echo "✗ Warning: Could not find new static directory"
fi

echo ""
echo "=== Configuration Update ==="
echo "Your config.yaml has been backed up to: $BACKUP_DIR/config.yaml"
echo ""
echo "Please review the following new configuration options and add them manually if needed:"
echo ""
echo "# Organize media into date-based subdirectories. Uses Python's strftime format."
echo "# Examples: \"%Y-%m-%d\" (2024-10-19), \"%Y/%m\" (2024/10), \"\" (disabled)"
echo "media_datetime_subdir: \"\""
echo ""
echo "# Incremental builds - only rebuild changed pages instead of entire site."
echo "incremental_builds: True"
echo ""
echo "# Display order - show newest messages first (like a blog) or oldest first (like a forum)."
echo "# True: Newest messages appear on page 1 (blog-style)"
echo "# False: Oldest messages appear on page 1 (forum-style, default)"
echo "new_on_top: False"
echo ""

# Check if config.yaml needs updates
if [ -f "$SITE_DIR/config.yaml" ]; then
    NEEDS_UPDATE=0

    if ! grep -q "media_datetime_subdir" "$SITE_DIR/config.yaml"; then
        echo "⚠ Missing: media_datetime_subdir"
        NEEDS_UPDATE=1
    fi

    if ! grep -q "incremental_builds" "$SITE_DIR/config.yaml"; then
        echo "⚠ Missing: incremental_builds"
        NEEDS_UPDATE=1
    fi

    if ! grep -q "new_on_top" "$SITE_DIR/config.yaml"; then
        echo "⚠ Missing: new_on_top"
        NEEDS_UPDATE=1
    fi

    if [ $NEEDS_UPDATE -eq 1 ]; then
        echo ""
        echo "You can add these options to $SITE_DIR/config.yaml manually,"
        echo "or compare with $EXAMPLE_DIR/config.yaml for reference."
    else
        echo "✓ All new config options are already present"
    fi
fi

echo ""
echo "=== Migration Complete ==="
echo "Backup location: $BACKUP_DIR"
echo ""
echo "Next steps:"
echo "1. Review and update your config.yaml with new options (see above)"
echo "2. Rebuild your site:"
echo "   docker run --rm --user=\"\$(id -u):\$(id -g)\" \\"
echo "     -v /path/to/sites:/sites \\"
echo "     tg-archive:latest \\"
echo "     --config=/sites/yoursite/config.yaml \\"
echo "     --data=/sites/yoursite/data.sqlite \\"
echo "     --template=/sites/yoursite/template.html \\"
echo "     --build"
echo ""
echo "3. Test the updated site in your publish directory"
echo ""
