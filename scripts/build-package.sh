#!/bin/bash
# Build APK package with proper versioning from git
# Usage: ./build-package.sh <package_name> <arch> <alpine_version>
# Built for the Amateur Radio community by Andy Taylor (MW0MWZ)

set -e

PACKAGE_NAME="${1:-mmdvmhost}"
ARCH="${2:-x86_64}"
ALPINE_VERSION="${3:-3.23}"

echo "Building package: $PACKAGE_NAME"
echo "Architecture: $ARCH"
echo "Alpine version: $ALPINE_VERSION"

# Get the package directory
PACKAGE_DIR="packages/community/$PACKAGE_NAME"
if [ ! -d "$PACKAGE_DIR" ]; then
    echo "Error: Package directory $PACKAGE_DIR does not exist"
    exit 1
fi

# Read git URL from APKBUILD
GITURL=$(grep "^giturl=" "$PACKAGE_DIR/APKBUILD" | cut -d'"' -f2)
if [ -z "$GITURL" ]; then
    echo "Error: No giturl found in APKBUILD"
    exit 1
fi

echo "Git URL: $GITURL"

# Generate version number
echo "Generating version number..."
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

git clone --depth 50 "$GITURL" "$TEMP_DIR/repo" 2>/dev/null
cd "$TEMP_DIR/repo"

# Get the latest tag or commit
GIT_COMMIT=$(git rev-parse --short HEAD)

# Generate version as YYYY.MM.DD
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)
PKG_VERSION="${YEAR}.${MONTH}.${DAY}"
PKG_RELEASE="0"

cd - > /dev/null

echo "Package version: ${PKG_VERSION}-r${PKG_RELEASE}"
echo "Git commit: ${GIT_COMMIT}"

# Create temporary APKBUILD with version
TEMP_APKBUILD="$TEMP_DIR/APKBUILD"
cp "$PACKAGE_DIR/APKBUILD" "$TEMP_APKBUILD"

# Update version in APKBUILD
sed -i "s/^pkgver=.*/pkgver=${PKG_VERSION}/" "$TEMP_APKBUILD"
sed -i "s/^pkgrel=.*/pkgrel=${PKG_RELEASE}/" "$TEMP_APKBUILD"
sed -i "s/^_gitcommit=.*/_gitcommit=\"${GIT_COMMIT}\"/" "$TEMP_APKBUILD"

# Copy OpenRC files if they exist
if [ -f "$PACKAGE_DIR/mmdvmhost.initd" ]; then
    cp "$PACKAGE_DIR/mmdvmhost.initd" "$TEMP_DIR/"
fi
if [ -f "$PACKAGE_DIR/mmdvmhost.confd" ]; then
    cp "$PACKAGE_DIR/mmdvmhost.confd" "$TEMP_DIR/"
fi

# Create build script for Docker
cat > "$TEMP_DIR/docker-build.sh" << 'EOSCRIPT'
#!/bin/sh
set -e

# Install dependencies
apk update
apk add alpine-sdk sudo

# Setup abuild
adduser -D builder
addgroup builder abuild
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Copy files to builder home
cp -r /build/* /home/builder/
chown -R builder:builder /home/builder/

# Setup package signing
mkdir -p /home/builder/.abuild
echo "PACKAGER_PRIVKEY=\"/keys/hamradio.rsa\"" > /home/builder/.abuild/abuild.conf
cp /keys/hamradio.rsa.pub /etc/apk/keys/

# Build as builder user
cd /home/builder
su builder -c "abuild -r"

# Copy built packages to output
cp -r /home/builder/packages/* /output/
EOSCRIPT

chmod +x "$TEMP_DIR/docker-build.sh"

# Prepare output directory
OUTPUT_DIR="repo/v${ALPINE_VERSION}/community/${ARCH}"
mkdir -p "$OUTPUT_DIR"

# Determine Docker image based on architecture
case "$ARCH" in
    x86_64)
        DOCKER_PLATFORM="linux/amd64"
        ;;
    armhf)
        DOCKER_PLATFORM="linux/arm/v6"
        ;;
    aarch64)
        DOCKER_PLATFORM="linux/arm64"
        ;;
    *)
        echo "Error: Unsupported architecture $ARCH"
        exit 1
        ;;
esac

echo "Using Docker platform: $DOCKER_PLATFORM"

# Extract private key from environment or file
if [ -n "$APK_PRIVATE_KEY" ]; then
    echo "$APK_PRIVATE_KEY" > "$TEMP_DIR/hamradio.rsa"
elif [ -f "keys/hamradio.rsa" ]; then
    cp "keys/hamradio.rsa" "$TEMP_DIR/hamradio.rsa"
else
    echo "Error: No private key found. Set APK_PRIVATE_KEY environment variable or place key in keys/hamradio.rsa"
    exit 1
fi

# Copy public key
cp "keys/hamradio.rsa.pub" "$TEMP_DIR/hamradio.rsa.pub"

# Build in Docker
echo "Starting Docker build..."
docker run --rm \
    --platform "$DOCKER_PLATFORM" \
    -v "$TEMP_DIR:/build:ro" \
    -v "$TEMP_DIR:/keys:ro" \
    -v "$(pwd)/$OUTPUT_DIR:/output" \
    "alpine:${ALPINE_VERSION}" \
    sh -c '
set -e
apk update
apk add alpine-sdk sudo
adduser -D builder
addgroup builder abuild
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
cp -r /build/* /home/builder/
chown -R builder:builder /home/builder/
mkdir -p /home/builder/.abuild
echo "PACKAGER_PRIVKEY=\"/keys/hamradio.rsa\"" > /home/builder/.abuild/abuild.conf
cp /keys/hamradio.rsa.pub /etc/apk/keys/
cd /home/builder
su builder -c "abuild -r"
find /home/builder/packages -name "*.apk" -type f -exec cp {} /output/ \;
'

echo "Build complete! Package should be in $OUTPUT_DIR"

# Clean up sensitive files
rm -f "$TEMP_DIR/hamradio.rsa"