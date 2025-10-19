#!/bin/sh

set -e

# Extract config path to determine working directory (without modifying $@)
CONFIG_PATH=""
for arg in "$@"; do
    case "$arg" in
        --config=*)
            CONFIG_PATH="${arg#*=}"
            break
            ;;
    esac
done

# If --config not found with =, check for -c or --config with space
if [ -z "$CONFIG_PATH" ]; then
    prev=""
    for arg in "$@"; do
        if [ "$prev" = "--config" ] || [ "$prev" = "-c" ]; then
            CONFIG_PATH="$arg"
            break
        fi
        prev="$arg"
    done
fi

# Change to config directory if config path is provided
# This allows relative paths for --data and --session to work
if [ -n "$CONFIG_PATH" ]; then
    CONFIG_DIR=$(dirname "$CONFIG_PATH")
    echo "Changing to directory: $CONFIG_DIR" >&2
    cd "$CONFIG_DIR" || { echo "Failed to cd to $CONFIG_DIR" >&2; exit 1; }
    echo "Current directory: $(pwd)" >&2
fi

# Run tgarchive (installed as package, works from any directory)
exec python3 -m tgarchive "$@"
