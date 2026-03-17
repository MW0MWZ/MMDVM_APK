#!/bin/bash
# Generate and sign APKINDEX for the repository
# Usage: ./generate-index.sh <alpine_version>
# This script generates indexes for ALL packages present in the repository,
# including both newly built packages and existing packages from gh-pages
# Built for the Amateur Radio community by Andy Taylor (MW0MWZ)

set -e

ALPINE_VERSION="${1:-3.23}"
REPO_BASE="repo/v${ALPINE_VERSION}/community"

echo "Generating repository index for Alpine ${ALPINE_VERSION}"
echo "This will index ALL packages present in the repository directories"

# Check if repo directory exists
if [ ! -d "$REPO_BASE" ]; then
    echo "Error: Repository directory $REPO_BASE does not exist"
    exit 1
fi

# Check for QEMU support if needed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    exit 1
fi

# Extract private key from environment or file
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

if [ -n "$APK_PRIVATE_KEY" ]; then
    echo "$APK_PRIVATE_KEY" > "$TEMP_DIR/hamradio.rsa"
elif [ -f "keys/hamradio.rsa" ]; then
    cp "keys/hamradio.rsa" "$TEMP_DIR/hamradio.rsa"
else
    echo "Error: No private key found. Set APK_PRIVATE_KEY environment variable"
    exit 1
fi

# Copy public key
cp "keys/hamradio.rsa.pub" "$TEMP_DIR/hamradio.rsa.pub"

# Process each architecture
for ARCH in x86_64 armhf aarch64; do
    ARCH_DIR="$REPO_BASE/$ARCH"
    
    if [ ! -d "$ARCH_DIR" ]; then
        echo "Creating directory: $ARCH_DIR"
        mkdir -p "$ARCH_DIR"
    fi
    
    # Count packages
    PACKAGE_COUNT=$(find "$ARCH_DIR" -maxdepth 1 -name "*.apk" -type f 2>/dev/null | wc -l)
    
    # Skip if no packages
    if [ "$PACKAGE_COUNT" -eq 0 ]; then
        echo "No packages found in $ARCH_DIR, skipping..."
        continue
    fi
    
    echo "Generating index for $ARCH (found $PACKAGE_COUNT packages)..."
    
    # List packages that will be indexed
    echo "Packages to be indexed:"
    ls -1 "$ARCH_DIR"/*.apk 2>/dev/null | xargs -n1 basename | sort
    
    # Create Docker script for index generation
    cat > "$TEMP_DIR/generate-index-docker.sh" << 'EOSCRIPT'
#!/bin/sh
set -e

# Install required tools
apk add --no-cache alpine-sdk

# Setup signing
mkdir -p /root/.abuild
echo "PACKAGER_PRIVKEY=\"/keys/hamradio.rsa\"" > /root/.abuild/abuild.conf
cp /keys/hamradio.rsa.pub /etc/apk/keys/

# Change to repo directory
cd /repo

# Remove any existing index files to ensure a fresh index
rm -f APKINDEX.tar.gz APKINDEX.unsigned.tar.gz

# List all APK files that will be indexed
echo "Indexing the following packages:"
ls -1 *.apk 2>/dev/null | sort || echo "No packages found!"

# Generate index for ALL packages in the directory
# The apk index command will include all *.apk files it finds
apk index -o APKINDEX.unsigned.tar.gz *.apk

# Sign the index
abuild-sign -k /keys/hamradio.rsa APKINDEX.unsigned.tar.gz
mv APKINDEX.unsigned.tar.gz APKINDEX.tar.gz

# Verify the index was created and show its size
if [ -f APKINDEX.tar.gz ]; then
    echo "Index generated and signed successfully"
    echo "Index size: $(ls -lh APKINDEX.tar.gz | awk '{print $5}')"
    
    # Extract and show package count in index for verification
    tar -xzOf APKINDEX.tar.gz APKINDEX 2>/dev/null | grep -c "^P:" || true
    echo " packages included in index"
else
    echo "Error: Failed to generate index!"
    exit 1
fi
EOSCRIPT
    
    chmod +x "$TEMP_DIR/generate-index-docker.sh"
    
    # Determine Docker platform
    case "$ARCH" in
        x86_64)
            DOCKER_PLATFORM="linux/amd64"
            ;;
        armhf)
            DOCKER_PLATFORM="linux/arm/v7"
            ;;
        aarch64)
            DOCKER_PLATFORM="linux/arm64"
            ;;
    esac
    
    echo "Using Docker platform: $DOCKER_PLATFORM for $ARCH"
    
    # Run in Docker with explicit platform
    docker run --rm \
        --platform "$DOCKER_PLATFORM" \
        -v "$TEMP_DIR:/keys:ro" \
        -v "$(pwd)/$ARCH_DIR:/repo" \
        "alpine:${ALPINE_VERSION}" \
        sh /keys/generate-index-docker.sh
    
    echo "✅ Index for $ARCH complete"
done

# Clean up
rm -f "$TEMP_DIR/hamradio.rsa"

echo ""
echo "========================================="
echo "Repository index generation complete!"
echo "========================================="
echo "Indexes have been created for all packages in each architecture directory."
echo ""
echo "Summary:"
for ARCH in x86_64 armhf aarch64; do
    ARCH_DIR="$REPO_BASE/$ARCH"
    if [ -f "$ARCH_DIR/APKINDEX.tar.gz" ]; then
        PACKAGE_COUNT=$(find "$ARCH_DIR" -maxdepth 1 -name "*.apk" -type f 2>/dev/null | wc -l)
        echo "  $ARCH: $PACKAGE_COUNT packages indexed"
    else
        echo "  $ARCH: No index (no packages found)"
    fi
done