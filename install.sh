#!/bin/bash

# Install second-brain-sync hooks into a git repository

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_SRC="$SCRIPT_DIR/hooks"

# Determine target repo
TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

if [ ! -d "$TARGET_DIR/.git" ]; then
    echo -e "${RED}Error: $TARGET_DIR is not a git repository.${NC}"
    exit 1
fi

HOOKS_DST="$TARGET_DIR/.git/hooks"

# Check for existing hooks
for hook in pre-commit post-commit; do
    if [ -f "$HOOKS_DST/$hook" ] && [ ! -L "$HOOKS_DST/$hook" ]; then
        echo -e "${YELLOW}Warning: $HOOKS_DST/$hook already exists.${NC}"
        read -p "Overwrite? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
    fi
done

# Copy hooks
cp "$HOOKS_SRC/pre-commit" "$HOOKS_DST/pre-commit"
cp "$HOOKS_SRC/post-commit" "$HOOKS_DST/post-commit"
chmod +x "$HOOKS_DST/pre-commit" "$HOOKS_DST/post-commit"

echo -e "${GREEN}✔ Hooks installed to $HOOKS_DST${NC}"
echo ""
echo "Next step: set the SECOND_BRAIN_DIR environment variable."
echo "Add this to your shell profile (~/.zshrc or ~/.bashrc):"
echo ""
echo "  export SECOND_BRAIN_DIR=\"/path/to/your/external/folder\""
echo ""
echo "Or set it directly in the hook files under .git/hooks/"
