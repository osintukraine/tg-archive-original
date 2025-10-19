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
if [ -n "$CONFIG_PATH" ]; then
    CONFIG_DIR=$(dirname "$CONFIG_PATH")
    cd "$CONFIG_DIR"
fi

# Keep /usr/src/app in PYTHONPATH so tgarchive module can be found
export PYTHONPATH=/usr/src/app:$PYTHONPATH

sh -c "python3 -m tgarchive $*"
