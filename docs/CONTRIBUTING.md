# Contributing to MMDVM_APK

Thank you for your interest in contributing to the Ham Radio APK Repository! This guide will help you add new packages or improve existing ones.

## 📋 Prerequisites

Before contributing, ensure you have:
- GitHub account
- Basic knowledge of Alpine Linux packaging
- Docker Desktop (for testing)
- Git command line tools

## 🎯 Contribution Scope

We accept packages that are:
- ✅ **Ham Radio / Amateur Radio related**
- ✅ **Open source with clear licensing**
- ✅ **Buildable from source code**
- ✅ **Actively maintained upstream**

We do NOT accept:
- ❌ Proprietary/closed-source software
- ❌ Packages unrelated to amateur radio
- ❌ Binary-only distributions
- ❌ Abandoned projects (>2 years without updates)

## 📦 Current Package Portfolio

The repository currently maintains these packages:

### Core MMDVM Software
- **mmdvmhost** - MMDVM Host Software with MMDVMCal calibration tool and RemoteCommand
  - Supports: DMR, D-Star, YSF, P25, NXDN, POCSAG, FM
  - Hardware: GPIO, I2C displays, OLED support on ARM

### Repeater Controllers
- **dstarrepeater** - Complete D-Star Repeater Controller System
  - Main repeater daemon with multiple hardware interfaces
  - Configuration tool (GUI-based)
  - Hardware support: Analogue, DVAP, DVRPTR, GMSK, SoundCard, Split configurations
  - GPIO support on ARM platforms for hardware PTT control
  - Includes data files for voice announcements and AMBE processing

### Digital Mode Gateway & Client Packages

All gateway packages follow the "*clients" naming convention and include gateways, test tools (parrots), and cross-mode converters where applicable.

#### DMR Ecosystem (`dmrclients`)
- **DMRGateway** - Routes between multiple DMR networks (Brandmeister, DMR+, TGIF, etc.)
- **DMR2YSF** - Cross-mode: DMR to YSF converter
- **DMR2NXDN** - Cross-mode: DMR to NXDN converter

#### D-Star Ecosystem (`dstarclients`)
- **DStarGateway** - D-Star Gateway
- **dgwremotecontrol** - Remote control tool
- **dgwtexttransmit** - Text transmit tool
- **dgwtimeserver** - Time server
- **dgwvoicetransmit** - Voice transmit tool

#### YSF/Fusion Ecosystem (`ysfclients`)
- **YSFGateway** - Yaesu System Fusion gateway
- **YSFParrot** - YSF test/echo server
- **DGIdGateway** - DG-ID routing gateway
- **YSF2DMR** - Cross-mode: YSF to DMR converter
- **YSF2NXDN** - Cross-mode: YSF to NXDN converter
- **YSF2P25** - Cross-mode: YSF to P25 converter

#### NXDN Ecosystem (`nxdnclients`)
- **NXDNGateway** - NXDN gateway for reflector connections
- **NXDNParrot** - NXDN test/echo server
- **NXDN2DMR** - Cross-mode: NXDN to DMR converter

#### P25 Ecosystem (`p25clients`)
- **P25Gateway** - P25 gateway for reflector connections
- **P25Parrot** - P25 test/echo server

#### Other Protocol Clients
- **aprsclients** - APRS Gateway between APRS-IS and RF networks
- **pocsagclients** - DAPNET Gateway for POCSAG paging network
- **fmclients** - FM Gateway for analog-to-digital bridging

Each package includes full OpenRC integration for Alpine Linux.

## 📦 Adding a New Package

### Step 1: Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR-USERNAME/MMDVM_APK.git
cd MMDVM_APK

# Add upstream remote
git remote add upstream https://github.com/MW0MWZ/MMDVM_APK.git
```

### Step 2: Determine Package Type

Follow the naming convention:
- **Gateway packages must end in "clients"**: `protocolclients` or `purposeclients`
- **Repeater controllers** can use descriptive names: `dstarrepeater`, `dmrrepeater`
- Group related tools together (gateway + parrot + cross-mode converters)
- Single-purpose gateways still use the "clients" suffix

### Step 3: Create Package Structure

```bash
# Create package directory
mkdir -p packages/community/PACKAGENAME

# Navigate to package directory
cd packages/community/PACKAGENAME
```

### Step 4: Create APKBUILD

Choose the appropriate template based on your package type:

#### Standard Single-Repository Package

```sh
# Contributor: Your Name <your.email@example.com>
# Maintainer: Your Name <your.email@example.com>
pkgname=yourprotocol-clients
pkgver=2025.01.01  # Will be set by build script
pkgrel=0
pkgdesc="Brief description of the package"
url="https://github.com/upstream/repo"
arch="x86_64 armhf aarch64"
license="GPL-2.0-or-later"
makedepends="
    build-base
    git
    "
depends="
    libgcc
    libstdc++
    "
subpackages="$pkgname-doc $pkgname-openrc"
source=""
options="!check"
giturl="https://github.com/upstream/repo.git"

prepare() {
    rm -rf "$srcdir/$pkgname"
    git clone "$giturl" "$srcdir/$pkgname"
    cd "$srcdir/$pkgname"
    
    local git_version=$(git describe --tags --always)
    msg "$pkgname git version: $git_version"
    
    cd "$srcdir"
    default_prepare || true
}

build() {
    cd "$srcdir/$pkgname"
    make clean || true
    make \
        CFLAGS="$CFLAGS" \
        CXXFLAGS="$CXXFLAGS" \
        LDFLAGS="$LDFLAGS" \
        -j $(nproc) \
        all
}

package() {
    cd "$srcdir/$pkgname"
    
    # Install binary
    install -Dm755 PackageBinary "$pkgdir"/usr/bin/PackageBinary
    
    # Install configuration - note the directory naming convention
    install -dm755 "$pkgdir"/etc/$pkgname
    install -Dm644 config.ini "$pkgdir"/usr/share/$pkgname/config.ini.sample
    install -Dm644 config.ini "$pkgdir"/etc/$pkgname/config.ini.example
    
    # Create directories following naming convention
    install -dm755 "$pkgdir"/var/log/$pkgname
    install -dm755 "$pkgdir"/usr/share/$pkgname
    
    # Install OpenRC scripts
    install -Dm755 "$startdir"/$pkgname.initd "$pkgdir"/etc/init.d/$pkgname
    install -Dm644 "$startdir"/$pkgname.confd "$pkgdir"/etc/conf.d/$pkgname
}
```

#### Complex Build with Makefile Patching (e.g., DStarRepeater)

```sh
pkgname=dstarrepeater
giturl="https://github.com/g4klx/DStarRepeater.git"

# Architecture-specific dependencies
case "$CARCH" in
    armhf|aarch64)
        makedepends="$makedepends linux-rpi-dev wiringpi wiringpi-dev"
        depends="$depends wiringpi"
        ;;
    x86_64)
        makedepends="$makedepends linux-lts-dev"
        ;;
esac

prepare() {
    rm -rf "$srcdir/DStarRepeater"
    git clone "$giturl" "$srcdir/DStarRepeater"
    cd "$srcdir/DStarRepeater"
    
    # Fix build issues - example: add CXXFLAGS for C++ builds
    if [ -f Makefile ]; then
        sed -i '/^export CFLAGS.*=/a export CXXFLAGS := $(CFLAGS)' Makefile
    fi
    
    # For ARM, add release flags to suppress debug output
    if [ -f MakefilePi ]; then
        sed -i 's/export CFLAGS.*:=.*/& -DNDEBUG -DwxDEBUG_LEVEL=0/' MakefilePi
        sed -i '/^export CFLAGS.*=/a export CXXFLAGS := $(CFLAGS)' MakefilePi
    fi
    
    cd "$srcdir"
    default_prepare || true
}

build() {
    cd "$srcdir/DStarRepeater"
    
    case "$CARCH" in
        armhf|aarch64)
            if [ -f MakefilePi ]; then
                make -f MakefilePi clean || true
                make -f MakefilePi -j $(nproc) all
            else
                make clean || true
                make BUILD=release -j $(nproc) all
            fi
            ;;
        x86_64)
            make clean || true
            make BUILD=release -j $(nproc) all
            ;;
    esac
}
```

#### Multi-Repository Package (Cross-Mode Converters)

```sh
pkgname=modeclients
giturl="https://github.com/g4klx/ModeClients.git"
mmdvm_cm_giturl="https://github.com/nostar/MMDVM_CM.git"

prepare() {
    # Clone both repositories
    rm -rf "$srcdir/ModeClients" "$srcdir/MMDVM_CM"
    
    git clone "$giturl" "$srcdir/ModeClients"
    cd "$srcdir/ModeClients"
    local git_version=$(git describe --tags --always)
    msg "ModeClients git version: $git_version"
    
    cd "$srcdir"
    git clone "$mmdvm_cm_giturl" "$srcdir/MMDVM_CM"
    cd "$srcdir/MMDVM_CM"
    local mmdvm_cm_version=$(git describe --tags --always)
    msg "MMDVM_CM git version: $mmdvm_cm_version"
    
    cd "$srcdir"
    default_prepare || true
}

build() {
    # Build from first repository
    cd "$srcdir/ModeClients"
    for component in Gateway Parrot; do
        if [ -d "$component" ]; then
            cd "$component"
            make clean || true
            make CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" -j $(nproc)
            cd ..
        fi
    done
    
    # Build from second repository
    cd "$srcdir/MMDVM_CM"
    for converter in Mode2DMR Mode2YSF; do
        if [ -d "$converter" ]; then
            cd "$converter"
            make clean || true
            make CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" -j $(nproc)
            cd ..
        fi
    done
}
```

### Step 5: Add OpenRC Scripts

Create init scripts for each component:

**packagename.initd**:
```sh
#!/sbin/openrc-run
# OpenRC init script for Package

name="Package Name"
description="Package description for Amateur Radio"

# Configuration - note the directory naming convention
: ${PACKAGE_CONFIG:="/etc/packagename/config.ini"}
: ${PACKAGE_USER:="package"}
: ${PACKAGE_GROUP:="package"}
: ${PACKAGE_LOGFILE:="/var/log/packagename/package.log"}

command="/usr/bin/Package"
command_args="${PACKAGE_CONFIG}"
command_user="${PACKAGE_USER}:${PACKAGE_GROUP}"
command_background=true
pidfile="/run/${RC_SVCNAME}.pid"
start_stop_daemon_args="--stdout ${PACKAGE_LOGFILE} --stderr ${PACKAGE_LOGFILE}"

depend() {
    need net
    after firewall
    use logger dns
}

start_pre() {
    # Check configuration
    if [ ! -f "${PACKAGE_CONFIG}" ]; then
        eerror "Configuration file ${PACKAGE_CONFIG} does not exist"
        eerror "Please create it from: cp /etc/packagename/config.ini.example ${PACKAGE_CONFIG}"
        return 1
    fi
    
    # Create directories and user
    checkpath -d -o "${PACKAGE_USER}:${PACKAGE_GROUP}" -m 0755 /var/log/packagename
    checkpath -f -o "${PACKAGE_USER}:${PACKAGE_GROUP}" -m 0644 "${PACKAGE_LOGFILE}"
    
    # Create user if needed
    if ! id -u "${PACKAGE_USER}" >/dev/null 2>&1; then
        einfo "Creating user ${PACKAGE_USER}"
        adduser -D -H -s /sbin/nologin "${PACKAGE_USER}"
    fi
}

stop_post() {
    sleep 1
}

reload() {
    ebegin "Reloading ${name} configuration"
    start-stop-daemon --signal HUP --pidfile "${pidfile}"
    eend $?
}
```

**packagename.confd**:
```sh
# Configuration for Package service

# Configuration file location
# PACKAGE_CONFIG="/etc/packagename/config.ini"

# User and group to run as
# PACKAGE_USER="package"
# PACKAGE_GROUP="package"

# Log file location
# PACKAGE_LOGFILE="/var/log/packagename/package.log"
```

### Step 6: Test Locally

```bash
# From repository root
./scripts/build-package.sh PACKAGENAME x86_64 3.22

# Check output
ls -la repo/v3.22/community/x86_64/
```

### Step 7: Update Documentation

Add your package to the README.md in the appropriate section:

```markdown
| **packagename** | Description including all components | ComponentA, ComponentB | [Upstream](https://github.com/...) |
```

### Step 8: Submit Pull Request

```bash
# Create feature branch
git checkout -b add-packagename

# Add your changes
git add packages/community/PACKAGENAME/
git add README.md

# Commit with descriptive message
git commit -m "Add packagename: Brief description

- Add APKBUILD for packagename
- Includes components: X, Y, Z
- Builds from upstream git repository
- Supports x86_64, armhf, aarch64
- Includes OpenRC init scripts for each component"

# Push to your fork
git push origin add-packagename
```

## 🔧 Package Organization Examples

### Repeater Controller Example (dstarrepeater)

Complete repeater system with multiple hardware interfaces:
```
dstarrepeater/
├── APKBUILD                    # Handles complex build with Makefile patching
├── dstarrepeater.initd         # Main repeater service
├── dstarrepeater.confd         # Config with hardware selection
├── dstarrepeater.pre-install   # User/group creation
└── dstarrepeater.post-install  # Post-installation setup
```

The config file allows selecting different hardware types:
- Main repeater daemon
- Analogue repeater interface
- DVAP node controller
- DVRPTR repeater controller
- GMSK modem repeater
- Sound card repeater
- Split repeater controller

### Protocol Suite Example (ysfclients)

Combines multiple related tools:
```
ysfclients/
├── APKBUILD              # Builds from 2 repositories
├── ysfgateway.initd      # YSFGateway + YSFParrot service
├── ysfgateway.confd
├── dgidgateway.initd     # DGIdGateway service
├── dgidgateway.confd
├── ysf2dmr.initd         # Cross-mode converter
├── ysf2dmr.confd
├── ysf2nxdn.initd        # Cross-mode converter
├── ysf2nxdn.confd
├── ysf2p25.initd         # Cross-mode converter
└── ysf2p25.confd
```

### Complex Multi-Source Example (dstarclients)

Multiple binaries from multiple sources:
```
dstarclients/
├── APKBUILD              # Builds from DStarGateway repository
├── dstargateway.initd    # D-Star Gateway
├── dstargateway.confd
├── starnetserver.initd   # STARnet server
└── starnetserver.confd
```

### Simple Package Example (pocsagclients)

Single binary, single purpose, still uses "clients" naming:
```
pocsagclients/
├── APKBUILD
├── dapnetgateway.initd
└── dapnetgateway.confd
```

## 📝 Best Practices

1. **Naming conventions**: 
   - Gateway packages: Always use "*clients" suffix
   - Repeater controllers: Can use descriptive names without "clients"
2. **Group related functionality**: Combine gateways, parrots, and cross-mode converters
3. **Separate services logically**: Each component gets its own init script
4. **Use consistent directory naming**: 
   - Package directories: lowercase
   - Config paths: `/etc/{packagename}/`
   - Log paths: `/var/log/{packagename}/`
   - Data paths: `/usr/share/{packagename}/`
5. **Document components**: List all included binaries in descriptions
6. **Handle multi-repo builds**: Clone all needed repositories in prepare()
7. **Test each service**: Ensure all init scripts work independently
8. **Handle architecture differences**: Use case statements for ARM vs x86_64
9. **Patch build systems when needed**: Fix upstream Makefile issues in prepare()

## 🧪 Testing Guidelines

Before submitting:

1. **Build test**: Package builds on all architectures
2. **Install test**: Package installs without conflicts
3. **Service test**: All init scripts start/stop correctly
4. **Config test**: Example configs are valid
5. **Cross-mode test**: Converters work with both protocols
6. **Directory test**: All paths follow the naming convention
7. **ARM test**: GPIO features work on Raspberry Pi (if applicable)

## 🚫 Common Mistakes to Avoid

- Don't forget the "*clients" suffix for gateway packages
- Don't hardcode versions in APKBUILD
- Don't forget OpenRC scripts for each component
- Don't mix unrelated packages
- Don't use upstream's systemd files directly
- Don't forget to handle all architectures
- Don't include binary files in the repository
- Don't use inconsistent directory naming
- Don't forget to test Makefile patches
- Don't ignore architecture-specific requirements (GPIO, etc.)

## 📞 Getting Help

- Open an issue for questions
- Check existing packages for examples
- Review the build logs in GitHub Actions
- Contact the maintainer: andy@mw0mwz.co.uk

## 🎉 Thank You!

Your contributions help the Amateur Radio community access modern digital voice software on Alpine Linux!

---

Built with ❤️ for the Amateur Radio community by Andy Taylor (MW0MWZ)