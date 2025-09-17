#!/bin/sh
# Get version string for package
# Usage: ./get-version.sh <git_url>
# Built for the Amateur Radio community by Andy Taylor (MW0MWZ)

set -e

GIT_URL="$1"
if [ -z "$GIT_URL" ]; then
    echo "Usage: $0 <git_url>"
    exit 1
fi

# Clone to temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

git clone --depth 1 "$GIT_URL" "$TEMP_DIR/repo" 2>/dev/null

cd "$TEMP_DIR/repo"

# Get the latest tag or commit
GIT_TAG=$(git describe --tags --always 2>/dev/null || git rev-parse --short HEAD)

# Generate version string
DATE=$(date +%Y%m%d)
VERSION="v${DATE}-${GIT_TAG}"

echo "$VERSION"
