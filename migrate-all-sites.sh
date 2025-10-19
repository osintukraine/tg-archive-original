#!/bin/bash
# Batch migration script to update all tg-archive sites with new templates and rebuild
# Usage: ./migrate-all-sites.sh /path/to/sites [--rebuild]
#
# Examples:
#   ./migrate-all-sites.sh /home/tg-archive/sites --rebuild
#   ./migrate-all-sites.sh /home/tg-archive-video/sites --rebuild

set -e

SITES_ROOT="$1"
DO_REBUILD="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$SCRIPT_DIR/tgarchive/example"

# Auto-detect sites in the given directory
# Will migrate any subdirectory that contains config.yaml
detect_sites() {
    local root_dir="$1"
    local sites=()

    if [ ! -d "$root_dir" ]; then
        return
    fi

    for dir in "$root_dir"/*/ ; do
        if [ -d "$dir" ]; then
            local site_name=$(basename "$dir")
            # Skip if it's a hidden directory or backup
            if [[ ! "$site_name" =~ ^\. ]] && [[ ! "$site_name" =~ ^backup- ]]; then
                # Check if it has config.yaml (valid tg-archive site)
                if [ -f "$dir/config.yaml" ]; then
                    sites+=("$site_name")
                fi
            fi
        fi
    done

    echo "${sites[@]}"
}

# Detect sites or use empty array if none found
SITES=($(detect_sites "$SITES_ROOT"))

if [ -z "$SITES_ROOT" ]; then
    echo "Usage: $0 /path/to/sites/root [--rebuild]"
    echo ""
    echo "Examples:"
    echo "  $0 /home/tg-archive/sites --rebuild"
    echo "  $0 /home/tg-archive-video/sites --rebuild"
    echo ""
    echo "Options:"
    echo "  --rebuild    Perform full rebuild after migration (generates fresh HTML)"
    exit 1
fi

if [ ! -d "$SITES_ROOT" ]; then
    echo "Error: Sites root directory '$SITES_ROOT' does not exist"
    exit 1
fi

if [ ${#SITES[@]} -eq 0 ]; then
    echo "Error: No valid tg-archive sites found in '$SITES_ROOT'"
    echo "Looking for directories with config.yaml files."
    exit 1
fi

# Check dependencies if --rebuild is specified
if [ "$DO_REBUILD" = "--rebuild" ]; then
    echo "Checking Python dependencies..."
    if ! python3 -c "import magic, feedgen, jinja2, PIL, pytz, yaml, telethon, rich" 2>/dev/null; then
        echo ""
        echo "❌ ERROR: Required Python dependencies are not installed!"
        echo ""
        echo "Install dependencies with:"
        echo "  cd $SCRIPT_DIR"
        echo "  pip3 install -r requirements.txt"
        echo ""
        echo "Or install individually:"
        echo "  pip3 install python-magic feedgen jinja2 Pillow pytz PyYAML telethon rich cryptg"
        echo ""
        echo "Then re-run this script."
        exit 1
    fi
    echo "✓ Python dependencies OK"
    echo ""
fi

echo "=========================================="
echo "  TG-Archive Batch Migration Tool"
echo "=========================================="
echo "Sites root: $SITES_ROOT"
echo "Example dir: $EXAMPLE_DIR"
echo "Rebuild: $([ "$DO_REBUILD" = "--rebuild" ] && echo "YES" || echo "NO")"
echo ""
echo "Sites to migrate:"
for site in "${SITES[@]}"; do
    echo "  - $site"
done
echo ""
read -p "Continue with migration? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 0
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
MIGRATION_LOG="$SITES_ROOT/migration-$TIMESTAMP.log"

echo "" | tee -a "$MIGRATION_LOG"
echo "=== Migration started at $(date) ===" | tee -a "$MIGRATION_LOG"
echo "" | tee -a "$MIGRATION_LOG"

# Function to migrate a single site
migrate_site() {
    local site_name="$1"
    local site_dir="$SITES_ROOT/$site_name"

    echo "----------------------------------------" | tee -a "$MIGRATION_LOG"
    echo "Migrating: $site_name" | tee -a "$MIGRATION_LOG"
    echo "----------------------------------------" | tee -a "$MIGRATION_LOG"

    if [ ! -d "$site_dir" ]; then
        echo "⚠ SKIP: Directory not found: $site_dir" | tee -a "$MIGRATION_LOG"
        echo "" | tee -a "$MIGRATION_LOG"
        return 1
    fi

    # Create backup directory
    local backup_dir="$site_dir/backup-$TIMESTAMP"
    mkdir -p "$backup_dir"
    echo "Backup: $backup_dir" | tee -a "$MIGRATION_LOG"

    # Backup template if exists
    if [ -f "$site_dir/template.html" ]; then
        cp "$site_dir/template.html" "$backup_dir/template.html"
        echo "✓ Backed up template.html" | tee -a "$MIGRATION_LOG"
    else
        echo "⚠ No template.html found" | tee -a "$MIGRATION_LOG"
    fi

    # Backup config if exists
    if [ -f "$site_dir/config.yaml" ]; then
        cp "$site_dir/config.yaml" "$backup_dir/config.yaml"
        echo "✓ Backed up config.yaml" | tee -a "$MIGRATION_LOG"
    else
        echo "⚠ No config.yaml found" | tee -a "$MIGRATION_LOG"
    fi

    # Backup static directory if exists
    if [ -d "$site_dir/static" ]; then
        cp -r "$site_dir/static" "$backup_dir/static"
        echo "✓ Backed up static directory" | tee -a "$MIGRATION_LOG"
    else
        echo "⚠ No static directory found" | tee -a "$MIGRATION_LOG"
    fi

    echo "" | tee -a "$MIGRATION_LOG"
    echo "Updating files..." | tee -a "$MIGRATION_LOG"

    # Copy new template
    if [ -f "$EXAMPLE_DIR/template.html" ]; then
        cp "$EXAMPLE_DIR/template.html" "$site_dir/template.html"
        echo "✓ Updated template.html" | tee -a "$MIGRATION_LOG"
    else
        echo "✗ ERROR: Could not find new template.html" | tee -a "$MIGRATION_LOG"
        return 1
    fi

    # Create static directory if it doesn't exist
    mkdir -p "$site_dir/static"

    # Copy new static files
    if [ -d "$EXAMPLE_DIR/static" ]; then
        # Copy lozad.min.js (new file)
        if [ -f "$EXAMPLE_DIR/static/lozad.min.js" ]; then
            cp "$EXAMPLE_DIR/static/lozad.min.js" "$site_dir/static/lozad.min.js"
            echo "✓ Added lozad.min.js" | tee -a "$MIGRATION_LOG"
        fi

        # Update main.js
        if [ -f "$EXAMPLE_DIR/static/main.js" ]; then
            cp "$EXAMPLE_DIR/static/main.js" "$site_dir/static/main.js"
            echo "✓ Updated main.js" | tee -a "$MIGRATION_LOG"
        fi

        # Update styles.css
        if [ -f "$EXAMPLE_DIR/static/styles.css" ]; then
            cp "$EXAMPLE_DIR/static/styles.css" "$site_dir/static/styles.css"
            echo "✓ Updated styles.css" | tee -a "$MIGRATION_LOG"
        fi
    else
        echo "✗ ERROR: Could not find new static directory" | tee -a "$MIGRATION_LOG"
        return 1
    fi

    echo "" | tee -a "$MIGRATION_LOG"
    echo "✅ Migration completed for $site_name" | tee -a "$MIGRATION_LOG"
    echo "" | tee -a "$MIGRATION_LOG"

    return 0
}

# Function to rebuild a site
rebuild_site() {
    local site_name="$1"
    local site_dir="$SITES_ROOT/$site_name"

    echo "----------------------------------------" | tee -a "$MIGRATION_LOG"
    echo "Rebuilding: $site_name" | tee -a "$MIGRATION_LOG"
    echo "----------------------------------------" | tee -a "$MIGRATION_LOG"

    if [ ! -f "$site_dir/config.yaml" ]; then
        echo "✗ SKIP: No config.yaml found" | tee -a "$MIGRATION_LOG"
        echo "" | tee -a "$MIGRATION_LOG"
        return 1
    fi

    if [ ! -f "$site_dir/data.sqlite" ]; then
        echo "✗ SKIP: No data.sqlite found" | tee -a "$MIGRATION_LOG"
        echo "" | tee -a "$MIGRATION_LOG"
        return 1
    fi

    # Detect publish_dir from config.yaml
    local publish_dir=$(grep "^publish_dir:" "$site_dir/config.yaml" | awk '{print $2}' | tr -d '"' | tr -d "'")
    if [ -z "$publish_dir" ]; then
        publish_dir="site"
    fi

    local full_publish_dir="$site_dir/$publish_dir"

    # Remove old published files for full rebuild
    if [ -d "$full_publish_dir" ]; then
        echo "Removing old published files: $full_publish_dir" | tee -a "$MIGRATION_LOG"
        rm -rf "$full_publish_dir"
    fi

    echo "Building site..." | tee -a "$MIGRATION_LOG"
    echo "Command: python3 -c \"from tgarchive import main; main()\" \\" | tee -a "$MIGRATION_LOG"
    echo "  --config=\"$site_dir/config.yaml\" \\" | tee -a "$MIGRATION_LOG"
    echo "  --data=\"$site_dir/data.sqlite\" \\" | tee -a "$MIGRATION_LOG"
    echo "  --template=\"$site_dir/template.html\" \\" | tee -a "$MIGRATION_LOG"
    echo "  --build" | tee -a "$MIGRATION_LOG"
    echo "" | tee -a "$MIGRATION_LOG"

    # Run the build locally (change to tg-archive-fork directory)
    cd "$SCRIPT_DIR"
    python3 -c "from tgarchive import main; main()" \
        --config="$site_dir/config.yaml" \
        --data="$site_dir/data.sqlite" \
        --template="$site_dir/template.html" \
        --build 2>&1 | tee -a "$MIGRATION_LOG"

    local build_status=$?

    if [ $build_status -eq 0 ]; then
        echo "" | tee -a "$MIGRATION_LOG"
        echo "✅ Build completed successfully" | tee -a "$MIGRATION_LOG"

        # Count generated files
        if [ -d "$full_publish_dir" ]; then
            local html_count=$(find "$full_publish_dir" -name "*.html" -type f | wc -l)
            echo "" | tee -a "$MIGRATION_LOG"
            echo "📊 Build Statistics:" | tee -a "$MIGRATION_LOG"
            echo "   HTML files generated: $html_count" | tee -a "$MIGRATION_LOG"
            echo "   Published to: $full_publish_dir" | tee -a "$MIGRATION_LOG"
            echo "" | tee -a "$MIGRATION_LOG"
            echo "🚀 Ready to move to your web server!" | tee -a "$MIGRATION_LOG"
        fi
    else
        echo "" | tee -a "$MIGRATION_LOG"
        echo "✗ Build failed with exit code: $build_status" | tee -a "$MIGRATION_LOG"
    fi

    echo "" | tee -a "$MIGRATION_LOG"
    return $build_status
}

# Migrate all sites
echo "=== Phase 1: Migrating Templates and Static Files ===" | tee -a "$MIGRATION_LOG"
echo "" | tee -a "$MIGRATION_LOG"

MIGRATED_SITES=()
FAILED_SITES=()

for site in "${SITES[@]}"; do
    if migrate_site "$site"; then
        MIGRATED_SITES+=("$site")
    else
        FAILED_SITES+=("$site")
    fi
done

# Rebuild if requested
if [ "$DO_REBUILD" = "--rebuild" ]; then
    echo "" | tee -a "$MIGRATION_LOG"
    echo "=== Phase 2: Rebuilding Sites ===" | tee -a "$MIGRATION_LOG"
    echo "" | tee -a "$MIGRATION_LOG"

    REBUILT_SITES=()
    REBUILD_FAILED=()

    for site in "${MIGRATED_SITES[@]}"; do
        if rebuild_site "$site"; then
            REBUILT_SITES+=("$site")
        else
            REBUILD_FAILED+=("$site")
        fi
    done
fi

# Summary
echo "" | tee -a "$MIGRATION_LOG"
echo "=========================================="  | tee -a "$MIGRATION_LOG"
echo "  Migration Summary"  | tee -a "$MIGRATION_LOG"
echo "=========================================="  | tee -a "$MIGRATION_LOG"
echo "" | tee -a "$MIGRATION_LOG"

echo "Migration Results:" | tee -a "$MIGRATION_LOG"
echo "  ✅ Migrated: ${#MIGRATED_SITES[@]} sites" | tee -a "$MIGRATION_LOG"
if [ ${#MIGRATED_SITES[@]} -gt 0 ]; then
    for site in "${MIGRATED_SITES[@]}"; do
        echo "     - $site" | tee -a "$MIGRATION_LOG"
    done
fi

if [ ${#FAILED_SITES[@]} -gt 0 ]; then
    echo "  ✗ Failed: ${#FAILED_SITES[@]} sites" | tee -a "$MIGRATION_LOG"
    for site in "${FAILED_SITES[@]}"; do
        echo "     - $site" | tee -a "$MIGRATION_LOG"
    done
fi

if [ "$DO_REBUILD" = "--rebuild" ]; then
    echo "" | tee -a "$MIGRATION_LOG"
    echo "Rebuild Results:" | tee -a "$MIGRATION_LOG"
    echo "  ✅ Built: ${#REBUILT_SITES[@]} sites" | tee -a "$MIGRATION_LOG"
    if [ ${#REBUILT_SITES[@]} -gt 0 ]; then
        for site in "${REBUILT_SITES[@]}"; do
            echo "     - $site" | tee -a "$MIGRATION_LOG"
        done
    fi

    if [ ${#REBUILD_FAILED[@]} -gt 0 ]; then
        echo "  ✗ Failed: ${#REBUILD_FAILED[@]} sites" | tee -a "$MIGRATION_LOG"
        for site in "${REBUILD_FAILED[@]}"; do
            echo "     - $site" | tee -a "$MIGRATION_LOG"
        done
    fi
fi

echo "" | tee -a "$MIGRATION_LOG"
echo "Backups created in each site's backup-$TIMESTAMP directory" | tee -a "$MIGRATION_LOG"
echo "Full log saved to: $MIGRATION_LOG" | tee -a "$MIGRATION_LOG"
echo "" | tee -a "$MIGRATION_LOG"

if [ "$DO_REBUILD" = "--rebuild" ] && [ ${#REBUILT_SITES[@]} -gt 0 ]; then
    echo "=== Next Steps ===" | tee -a "$MIGRATION_LOG"
    echo "" | tee -a "$MIGRATION_LOG"
    echo "Move the generated files to your web server:" | tee -a "$MIGRATION_LOG"
    for site in "${REBUILT_SITES[@]}"; do
        site_dir="$SITES_ROOT/$site"
        publish_dir=$(grep "^publish_dir:" "$site_dir/config.yaml" 2>/dev/null | awk '{print $2}' | tr -d '"' | tr -d "'" || echo "site")
        echo "  $site: $SITES_ROOT/$site/$publish_dir/" | tee -a "$MIGRATION_LOG"
    done
    echo "" | tee -a "$MIGRATION_LOG"
fi

echo "=== Configuration Updates Required ===" | tee -a "$MIGRATION_LOG"
echo "" | tee -a "$MIGRATION_LOG"
echo "Add these options to each site's config.yaml if not present:" | tee -a "$MIGRATION_LOG"
echo "" | tee -a "$MIGRATION_LOG"
cat << 'CONFIGEOF' | tee -a "$MIGRATION_LOG"
# Organize media into date-based subdirectories
media_datetime_subdir: ""

# Incremental builds - only rebuild changed pages
incremental_builds: True

# Display order - newest first (True) or oldest first (False)
new_on_top: False
CONFIGEOF

echo "" | tee -a "$MIGRATION_LOG"
echo "Migration completed at $(date)" | tee -a "$MIGRATION_LOG"
echo "==========================================" | tee -a "$MIGRATION_LOG"
