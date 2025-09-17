# Building Packages

This document describes how packages are built in the MMDVM_APK repository.

## Build System Overview

The repository uses:
- **GitHub Actions** for CI/CD
- **Alpine Linux Docker containers** for build environments
- **abuild** for package creation
- **QEMU** for cross-architecture builds
- **Automatic upstream monitoring** for rebuild triggers

## Available Packages

The repository currently builds the following packages:

### Core MMDVM Software

| Package | Description | Components | Dependencies |
|---------|-------------|------------|--------------|
| **mmdvmhost** | MMDVM Host Software & Calibration | MMDVMHost, MMDVMCal, RemoteCommand | `build-base`, `git`, `linux-headers`, `i2c-tools-dev`, ARM: `wiringpi-dev` |

### Repeater Controllers

| Package | Description | Components | Dependencies |
|---------|-------------|------------|--------------|
| **dstarrepeater** | D-Star Repeater Controller | dstarrepeaterd, dstarrepeaterconfig, | `wxwidgets-dev`, `linux-headers`, `libusb-dev`, `alsa-lib-dev`, ARM: `wiringpi-dev` |

### Gateway & Client Packages

| Package | Description | Components | Dependencies |
|---------|-------------|------------|--------------|
| **dmrclients** | DMR Gateway and Cross-Mode | DMRGateway, DMR2YSF, DMR2NXDN | `build-base`, `git` |
| **dstarclients** | D-Star Gateways and tools | ircDDBGateway, DStarGateway, remotecontrold, starnetserverd, and more | `wxwidgets-dev`, `linux-headers`, `curl-dev`, `boost-dev` |
| **ysfclients** | YSF Gateway, Parrot and Cross-Mode | YSFGateway, YSFParrot, DGIdGateway, YSF2DMR, YSF2NXDN, YSF2P25 | `build-base`, `git` |
| **nxdnclients** | NXDN Gateway, Parrot and Cross-Mode | NXDNGateway, NXDNParrot, NXDN2DMR | `build-base`, `git` |
| **p25clients** | P25 Gateway and Parrot | P25Gateway, P25Parrot | `build-base`, `git` |
| **aprsclients** | APRS Gateway | APRSGateway | `build-base`, `git` |
| **pocsagclients** | POCSAG/DAPNET Gateway | DAPNETGateway | `build-base`, `git` |
| **fmclients** | FM Gateway | FMGateway | `build-base`, `git`, `libmd-dev` |

## Build Process

### 1. Version Generation

Packages use date-based versioning:
```
Version: YYYY.MM.DD-r{release}
Example: 2025.01.01-r0
```

The git commit hash from upstream is captured for reference.

### 2. Source Code

All packages are built from git repositories (not tarballs) to ensure:
- Proper version tracking
- Git commit information embedded in binaries
- Reproducible builds
- Automatic rebuild on upstream changes

### 3. Multi-Repository Builds

Several packages build from multiple upstream repositories:

- **dmrclients**: 
  - DMRGateway from `g4klx/DMRGateway`
  - DMR2YSF, DMR2NXDN from `nostar/MMDVM_CM`

- **dstarclients**:
  - ircDDBGateway and tools from `g4klx/ircDDBGateway`
  - DStarGateway and tools from `F4FXL/DStarGateway`

- **ysfclients**:
  - YSFGateway, YSFParrot, DGIdGateway from `g4klx/YSFClients`
  - YSF2DMR, YSF2NXDN, YSF2P25 from `nostar/MMDVM_CM`

- **nxdnclients**:
  - NXDNGateway, NXDNParrot from `g4klx/NXDNClients`
  - NXDN2DMR from `nostar/MMDVM_CM`

### 4. Architecture Support

Builds run for three architectures:
- `x86_64` - Using native runners or linux/amd64
- `armhf` - Using QEMU with linux/arm/v6 (includes GPIO support)
- `aarch64` - Using QEMU with linux/arm64 (includes GPIO support)

### 5. Build Environment

Each build runs in an Alpine Linux container matching the target version:
- Alpine 3.22
- Alpine 3.21

## Automatic Build Triggers

The repository monitors upstream repositories and automatically rebuilds when:
- New commits are pushed to upstream master/main branches
- New releases are tagged
- Dependencies are updated

Monitored repositories:
- https://github.com/g4klx/MMDVMHost
- https://github.com/g4klx/MMDVMCal
- https://github.com/g4klx/DStarRepeater
- https://github.com/g4klx/DMRGateway
- https://github.com/g4klx/ircDDBGateway
- https://github.com/F4FXL/DStarGateway
- https://github.com/g4klx/YSFClients
- https://github.com/g4klx/NXDNClients
- https://github.com/g4klx/P25Clients
- https://github.com/g4klx/DAPNETGateway
- https://github.com/g4klx/FMGateway
- https://github.com/g4klx/APRSGateway
- https://github.com/nostar/MMDVM_CM

## Manual Build Trigger

### Using GitHub Actions

1. Navigate to [Actions](https://github.com/MW0MWZ/MMDVM_APK/actions)
2. Select "Build APK Packages"
3. Click "Run workflow"
4. Choose options:
   - **Package**: Select specific package or "all"
   - **Alpine Version**: Select specific version or "all"
5. Click green "Run workflow" button

### Build Matrix

With "all" options selected, the build matrix includes:
- 2 Alpine versions (3.22, 3.21)
- 3 architectures (x86_64, armhf, aarch64)
- 11 packages
= **66 total build jobs**

## Local Testing

### Prerequisites

- Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- Repository private key (for testing only)

### Test Build Script

```bash
# Basic usage
./scripts/build-package.sh <package> <arch> <alpine_version>

# Examples
./scripts/build-package.sh mmdvmhost x86_64 3.22
./scripts/build-package.sh dstarrepeater x86_64 3.22
./scripts/build-package.sh dmrclients aarch64 3.22
./scripts/build-package.sh dstarclients x86_64 3.22
./scripts/build-package.sh ysfclients armhf 3.21
./scripts/build-package.sh nxdnclients x86_64 3.22
./scripts/build-package.sh p25clients aarch64 3.22
./scripts/build-package.sh aprsclients x86_64 3.22
./scripts/build-package.sh pocsagclients armhf 3.22
./scripts/build-package.sh fmclients x86_64 3.22
```

### Docker Build Process

The build script:
1. Clones upstream git repository/repositories
2. Generates version number
3. Creates Alpine container
4. Installs build dependencies
5. Runs abuild as non-root user
6. Signs packages
7. Copies output to repo directory

## APKBUILD Structure

### Basic Template

```sh
# Contributor: Name <email>
# Maintainer: Name <email>
pkgname=package-name
pkgver=2025.01.01  # Set by build script
pkgrel=0
pkgdesc="Package description"
url="https://upstream-url"
arch="x86_64 armhf aarch64"
license="GPL-2.0-or-later"
makedepends="build-base git"
depends="runtime-deps"
source=""
giturl="https://github.com/user/repo.git"

prepare() {
    git clone "$giturl" "$srcdir/$pkgname"
    # Prepare source
}

build() {
    cd "$srcdir/$pkgname"
    make
}

package() {
    cd "$srcdir/$pkgname"
    install -Dm755 binary "$pkgdir"/usr/bin/binary
    # Install to /etc/{packagename}/ for configs
    # Install to /var/log/{packagename}/ for logs
    # Install to /usr/share/{packagename}/ for data
}
```

### Complex Build with Makefile Patching (DStarRepeater)

```sh
giturl="https://github.com/g4klx/DStarRepeater.git"

prepare() {
    git clone "$giturl" "$srcdir/DStarRepeater"
    cd "$srcdir/DStarRepeater"
    
    # Fix CFLAGS/CXXFLAGS issue in Makefile
    if [ -f Makefile ]; then
        sed -i '/^export CFLAGS.*=/a export CXXFLAGS := $(CFLAGS)' Makefile
    fi
    
    # For ARM, add release flags to suppress debug output
    if [ -f MakefilePi ]; then
        sed -i 's/export CFLAGS.*:=.*/& -DNDEBUG -DwxDEBUG_LEVEL=0/' MakefilePi
        sed -i '/^export CFLAGS.*=/a export CXXFLAGS := $(CFLAGS)' MakefilePi
    fi
}

build() {
    cd "$srcdir/DStarRepeater"
    
    case "$CARCH" in
        armhf|aarch64)
            # Use MakefilePi for ARM with GPIO support
            if [ -f MakefilePi ]; then
                make -f MakefilePi -j $(nproc) all
            else
                make BUILD=release -j $(nproc) all
            fi
            ;;
        x86_64)
            # Use standard Makefile with release build
            make BUILD=release -j $(nproc) all
            ;;
    esac
}
```

### Multi-Repository Template (Cross-Mode Packages)

```sh
giturl="https://github.com/g4klx/YSFClients.git"
mmdvm_cm_giturl="https://github.com/nostar/MMDVM_CM.git"

prepare() {
    # Clone both repositories
    git clone "$giturl" "$srcdir/YSFClients"
    git clone "$mmdvm_cm_giturl" "$srcdir/MMDVM_CM"
}

build() {
    # Build from first repository
    cd "$srcdir/YSFClients"
    for dir in YSFGateway YSFParrot DGIdGateway; do
        cd $dir && make && cd ..
    done
    
    # Build from second repository
    cd "$srcdir/MMDVM_CM"
    for dir in YSF2DMR YSF2NXDN YSF2P25; do
        cd $dir && make && cd ..
    done
}
```

### Architecture-Specific Dependencies

```sh
case "$CARCH" in
    armhf|aarch64)
        makedepends="$makedepends wiringpi-dev linux-rpi-dev"
        depends="$depends wiringpi"
        ;;
    x86_64)
        makedepends="$makedepends linux-lts-dev"
        ;;
esac
```

## Package-Specific Build Notes

### mmdvmhost
```bash
# ARM build includes OLED support
make -f Makefile.Pi.OLED -DHD44780 -DPCF8574_DISPLAY

# x86_64 uses standard Makefile
make
```

### dstarrepeater
```bash
# Complex build with multiple components
# Requires wxWidgets and hardware-specific builds

# x86_64: Standard Makefile with release build
make BUILD=release

# ARM: MakefilePi with GPIO support
make -f MakefilePi

# Builds multiple binaries:
# - dstarrepeaterd (main controller)
# - dstarrepeaterconfig (GUI config tool)

# Requires Makefile patching for CXXFLAGS support
sed -i '/^export CFLAGS.*=/a export CXXFLAGS := $(CFLAGS)' Makefile
```

### dstarclients
```bash
# Requires wxWidgets and multiple components
# Builds from two repositories:
git clone g4klx/ircDDBGateway
git clone F4FXL/DStarGateway

# Build with wxWidgets support
export WX_CONFIG="/usr/bin/wx-config"
make CXXFLAGS="$(wx-config --cppflags) -DDATA_DIR=..."
```

### Cross-Mode Packages (dmrclients, ysfclients, nxdnclients)
```bash
# Clone multiple repositories
git clone g4klx/repository
git clone nostar/MMDVM_CM

# Build components from each
cd Repository && make
cd ../MMDVM_CM/Component && make
```

### fmclients
```bash
# Simple make build with MD library
make LDFLAGS="-lmd"
```

## OpenRC Integration

All packages include comprehensive OpenRC init scripts:

### Service Structure
Each package provides:
- Init scripts for each component
- Configuration file templates
- Automatic user creation
- Log management
- Service dependencies
- Pre/post-install scripts (where needed)

### Example Services by Package

**dstarrepeater**:
- `dstarrepeater` - Main repeater service (configurable hardware type)
  - Hardware type selected in `/etc/conf.d/dstarrepeater`

**dmrclients**:
- `dmrgateway` - Main DMR gateway service
- `dmr2ysf` - DMR to YSF converter
- `dmr2nxdn` - DMR to NXDN converter

**dstarclients**:
- `ircddbgateway` - IRC DDB Gateway
- `dstargateway` - D-Star Gateway
- `starnetserver` - STARnet server

**ysfclients**:
- `ysfgateway` - YSF Gateway and Parrot
- `dgidgateway` - DGId Gateway (separate service)
- `ysf2dmr` - YSF to DMR converter
- `ysf2nxdn` - YSF to NXDN converter
- `ysf2p25` - YSF to P25 converter

**nxdnclients**:
- `nxdngateway` - NXDN Gateway and Parrot
- `nxdn2dmr` - NXDN to DMR converter

### Service Management
```bash
# Start individual components
rc-service dstarrepeater start
rc-service dmrgateway start
rc-service ircddbgateway start
rc-service ysfgateway start
rc-service dgidgateway start
rc-service ysf2dmr start

# Enable at boot
rc-update add dstarrepeater default
rc-update add dmrgateway default
rc-update add ircddbgateway default
```

## Directory Structure Convention

Packages follow a consistent directory structure:

### Gateway/Client Packages
- `/etc/{package}clients/` - Configuration files
- `/var/log/{package}clients/` - Log files
- `/usr/share/{package}clients/` - Data files, samples, audio

### Repeater Packages
- `/etc/{package}/` - Configuration files
- `/var/log/{package}/` - Log files
- `/usr/share/{package}/` - Data files, voice prompts, AMBE data

Examples:
- `/etc/dstarrepeater/dstarrepeater.conf`
- `/etc/dmrclients/DMRGateway.ini`
- `/var/log/ysfclients/ysfgateway.log`
- `/usr/share/dstarrepeater/DCS_Hosts.txt`
- `/usr/share/dstarclients/DStarGateway.cfg.example`

## Troubleshooting

### Build Failures

Common issues and solutions:

**Missing dependencies**:
- Ensure community repository is enabled
- Check APKBUILD makedepends

**wxWidgets issues (dstarrepeater, dstarclients)**:
- Verify wx-config is available
- Check wxwidgets-dev package is installed
- Ensure CXXFLAGS includes wx-config output
- May need Makefile patching for CXXFLAGS support

**Multi-repository builds**:
- Verify both git URLs are accessible
- Check that all subdirectories exist
- Ensure makefiles are present in each component

**Cross-mode converter issues**:
- MMDVM_CM repository structure may change
- Verify component directories exist
- Check for makefile variations

**GPIO support on ARM**:
- Ensure wiringpi-dev is installed
- Check for MakefilePi existence
- Verify linux-rpi-dev is available

**Debug output suppression**:
- Add -DNDEBUG -DwxDEBUG_LEVEL=0 flags
- Use BUILD=release where supported

## Performance Tips

- Use `-j$(nproc)` for parallel compilation
- Build locally for native architecture first
- Use GitHub Actions for full matrix builds
- Cache Docker images when possible
- MMDVMHost OLED library requires `-j1` (serial build)
- DStarRepeater benefits from parallel builds

## Security

- All packages are signed with repository RSA key
- Private key stored in GitHub Secrets
- Public key distributed via HTTPS
- Indexes are signed to prevent tampering
- Pre/post-install scripts create dedicated users

## Hardware-Specific Features

### ARM Platforms (Raspberry Pi)

For armhf and aarch64 builds:
- GPIO support enabled for hardware PTT
- WiringPi library integration
- I2C display support (MMDVMHost)
- OLED display drivers
- Hardware timer support

### x86_64 Platforms

Standard PC builds include:
- USB device support
- Sound card interfaces
- Network-only operation
- Virtual PTT via serial

## Adding Multiple Alpine Versions

To add support for a new Alpine version:

1. Update `.github/workflows/build-packages.yml`:
```yaml
options:
  - all
  - '3.22'
  - '3.21'
  - '3.20'  # Add new version
```

2. Update prepare job:
```yaml
echo 'versions=["3.22","3.21","3.20"]' >> $GITHUB_OUTPUT
```

3. Test build with new version
4. Update documentation

---

Built with ❤️ for the Amateur Radio community by Andy Taylor (MW0MWZ)