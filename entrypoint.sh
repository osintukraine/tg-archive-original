#!/bin/sh

set -e

# Extract config path to determine working directory
CONFIG_PATH=""
for arg in "$@"; do
    case "$arg" in
        --config=*)
            CONFIG_PATH="${arg#*=}"
            ;;
        -c)
            shift
            CONFIG_PATH="$1"
            ;;
    esac
done

# Change to config directory if config path is provided
# This allows relative paths for --data and --session to work
if [ -n "$CONFIG_PATH" ]; then
    CONFIG_DIR=$(dirname "$CONFIG_PATH")
    cd "$CONFIG_DIR"
fi

# Run tgarchive (installed as package, works from any directory)
exec python3 -m tgarchive "$@"
