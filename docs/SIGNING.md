# APK Signing

This document describes the package signing process for the MMDVM_APK repository.

## Overview

All packages and repository indexes are cryptographically signed to ensure:
- **Authenticity** - Packages come from this repository
- **Integrity** - Packages haven't been tampered with
- **Trust** - Users can verify package origin

## Key Management

### Key Generation

Repository uses 4096-bit RSA keys:

```bash
# Generate private key
openssl genrsa -out hamradio.rsa 4096

# Extract public key
openssl rsa -in hamradio.rsa -pubout -out hamradio.rsa.pub

# View key fingerprint
openssl rsa -in hamradio.rsa -pubout -outform DER | openssl dgst -sha256
```

### Key Storage

**Private Key** (`hamradio.rsa`):
- **NEVER** committed to repository
- Stored in GitHub Secrets as `APK_PRIVATE_KEY`
- Used only during CI/CD builds
- Should be backed up securely offline

**Public Key** (`hamradio.rsa.pub`):
- Stored in repository at `/keys/hamradio.rsa.pub`
- Distributed via https://apk.pistar.uk/hamradio.rsa.pub
- Installed to `/etc/apk/keys/` on Alpine systems

### GitHub Secrets Setup

1. Go to repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `APK_PRIVATE_KEY`
4. Value: Complete contents of `hamradio.rsa` including:
   ```
   -----BEGIN RSA PRIVATE KEY-----
   [key content]
   -----END RSA PRIVATE KEY-----
   ```
5. Click "Add secret"

## Signing Process

### Package Signing

Packages are signed during the build process by abuild:

```bash
# Configure abuild with signing key
echo 'PACKAGER_PRIVKEY="/path/to/hamradio.rsa"' > ~/.abuild/abuild.conf

# Install public key for verification
cp hamradio.rsa.pub /etc/apk/keys/

# Build and sign package
abuild -r  # Automatically signs with configured key
```

### Index Signing

Repository indexes are signed after generation:

```bash
# Generate unsigned index
apk index -o APKINDEX.unsigned.tar.gz *.apk

# Sign the index
abuild-sign -k /path/to/hamradio.rsa APKINDEX.unsigned.tar.gz

# Result: APKINDEX.tar.gz (signed)
```

### Signature Verification

Alpine Linux automatically verifies signatures when:
- Installing packages
- Updating repository indexes

Manual verification:
```bash
# Verify package signature
apk verify package-name.apk

# Verify index signature
tar -xOf APKINDEX.tar.gz .SIGN.RSA.hamradio.rsa.pub | \
  openssl dgst -sha1 -verify /etc/apk/keys/hamradio.rsa.pub -signature /dev/stdin
```

## Build Process Integration

### GitHub Actions Workflow

The signing process in CI/CD:

1. **Extract private key from secrets**:
   ```yaml
   env:
     APK_PRIVATE_KEY: ${{ secrets.APK_PRIVATE_KEY }}
   ```

2. **Write key to temporary file**:
   ```bash
   echo "$APK_PRIVATE_KEY" > /tmp/hamradio.rsa
   ```

3. **Configure abuild**:
   ```bash
   echo 'PACKAGER_PRIVKEY="/tmp/hamradio.rsa"' > ~/.abuild/abuild.conf
   ```

4. **Build and sign packages**:
   ```bash
   abuild -r
   ```

5. **Clean up sensitive data**:
   ```bash
   rm -f /tmp/hamradio.rsa
   ```

### Local Testing

For local testing, temporarily use a test key:

```bash
# Generate test key pair
openssl genrsa -out test.rsa 4096
openssl rsa -in test.rsa -pubout -out test.rsa.pub

# Use test key for build
export APK_PRIVATE_KEY=$(cat test.rsa)
./scripts/build-package.sh mmdvmhost x86_64 3.22

# Clean up test keys
shred -u test.rsa  # Linux
rm -P test.rsa      # macOS
```

**IMPORTANT**: Never use test keys for production builds!

## Security Best Practices

### Key Protection

1. **Private key security**:
   - Generate on secure, offline system
   - Use strong passphrase (if applicable)
   - Store backup in secure location
   - Rotate keys periodically (yearly)

2. **Access control**:
   - Limit GitHub Secret access to necessary workflows
   - Review repository access permissions
   - Monitor for unauthorized access

3. **Key rotation**:
   - Generate new key pair
   - Update GitHub Secret
   - Keep old public key for transition period
   - Update documentation

### Incident Response

If private key is compromised:

1. **Immediate actions**:
   - Revoke compromised key
   - Generate new key pair
   - Update GitHub Secret
   - Rebuild all packages

2. **Notification**:
   - Notify users via repository README
   - Update landing page with notice
   - Provide new public key

3. **Recovery**:
   - Users remove old key: `rm /etc/apk/keys/hamradio.rsa.pub`
   - Users add new key: `wget -O /etc/apk/keys/hamradio-new.rsa.pub https://...`
   - Force repository update: `apk update --force-refresh`

## User Instructions

### Adding Repository Key

Users must add the public key before using the repository:

```bash
# Download and install public key
wget -O /etc/apk/keys/hamradio.rsa.pub \
  https://apk.pistar.uk/hamradio.rsa.pub

# Verify key fingerprint (optional)
openssl rsa -in /etc/apk/keys/hamradio.rsa.pub -pubin -outform DER | \
  openssl dgst -sha256
```

### Troubleshooting

**"UNTRUSTED signature" error**:
- Public key not installed
- Wrong public key version
- Corrupted key file

Solution:
```bash
# Re-download public key
wget -O /etc/apk/keys/hamradio.rsa.pub \
  https://apk.pistar.uk/hamradio.rsa.pub

# Force refresh
apk update --force-refresh
```

**"BAD signature" error**:
- Package corrupted during download
- Index corrupted
- Man-in-the-middle attack (rare)

Solution:
```bash
# Clear cache and retry
apk cache clean
apk update --force-refresh
apk add package-name
```

## Key Specifications

Current repository key:
- **Algorithm**: RSA
- **Key Size**: 4096 bits
- **Signature Hash**: SHA-256
- **Key Name**: hamradio.rsa
- **Public Key URL**: https://apk.pistar.uk/hamradio.rsa.pub

## Compliance

The signing process follows:
- Alpine Linux package signing standards
- OpenSSL best practices
- GitHub security recommendations

## References

- [Alpine Linux: Creating an Alpine package](https://wiki.alpinelinux.org/wiki/Creating_an_Alpine_package)
- [Alpine Linux: Abuild and Helpers](https://wiki.alpinelinux.org/wiki/Abuild_and_Helpers)
- [OpenSSL RSA Key Management](https://www.openssl.org/docs/man1.1.1/man1/rsa.html)

---

Built with ❤️ for the Amateur Radio community by Andy Taylor (MW0MWZ)