# Ham Radio APK Repository

Alpine Linux package repository for Ham Radio software, hosted on GitHub Pages.

[![Build Status](https://github.com/MW0MWZ/MMDVM_APK/actions/workflows/build-packages.yml/badge.svg)](https://github.com/MW0MWZ/MMDVM_APK/actions)

## 🌐 Repository URL

- **Web**: https://apk.pistar.uk
- **Repository**: https://apk.pistar.uk/v{version}/community

## 📦 Available Packages

### Core MMDVM Software

| Package | Description | Components | Upstream |
|---------|-------------|------------|----------|
| **mmdvmhost** | MMDVM Host Software & Calibration Tool | MMDVMHost, MMDVMCal, RemoteCommand | [MMDVMHost](https://github.com/g4klx/MMDVMHost) & [MMDVMCal](https://github.com/g4klx/MMDVMCal) |

### Repeater Software

| Package | Description | Components | Upstream |
|---------|-------------|------------|----------|
| **dstarrepeater** | D-Star Repeater Controller | dstarrepeaterd, dstarrepeaterconfig | [DStarRepeater](https://github.com/g4klx/DStarRepeater) |

### Gateway & Client Packages

| Package | Description | Components | Upstream |
|---------|-------------|------------|----------|
| **dmrclients** | DMR Gateway and Cross-Mode converters | DMRGateway, DMR2YSF, DMR2NXDN | [DMRGateway](https://github.com/g4klx/DMRGateway) & [MMDVM_CM](https://github.com/nostar/MMDVM_CM) |
| **dstarclients** | D-Star Gateway and tools | DStarGateway, dgwremotecontrol, dgwtexttransmit, dgwtimeserver, dgwvoicetransmit | [DStarGateway](https://github.com/g4klx/DStarGateway) |
| **ysfclients** | YSF Gateway, Parrot, DGId Gateway and Cross-Mode converters | YSFGateway, YSFParrot, DGIdGateway, YSF2DMR, YSF2NXDN, YSF2P25 | [YSFClients](https://github.com/g4klx/YSFClients) & [MMDVM_CM](https://github.com/nostar/MMDVM_CM) |
| **nxdnclients** | NXDN Gateway, Parrot and Cross-Mode converter | NXDNGateway, NXDNParrot, NXDN2DMR | [NXDNClients](https://github.com/g4klx/NXDNClients) & [MMDVM_CM](https://github.com/nostar/MMDVM_CM) |
| **p25clients** | P25 Gateway and Parrot | P25Gateway, P25Parrot | [P25Clients](https://github.com/g4klx/P25Clients) |
| **pocsagclients** | POCSAG/DAPNET Gateway for paging | DAPNETGateway | [DAPNETGateway](https://github.com/g4klx/DAPNETGateway) |
| **fmclients** | FM Gateway for analog-to-digital bridging | FMGateway | [FMGateway](https://github.com/g4klx/FMGateway) |
| **aprsclients** | APRS Gateway between APRS-IS and RF | APRSGateway | [APRSGateway](https://github.com/g4klx/APRSGateway) |

## 🏔️ Supported Alpine Linux Versions

- Alpine 3.23 (latest)
- Alpine 3.22

## 🖥️ Supported Architectures

- `x86_64` - 64-bit Intel/AMD
- `armhf` - 32-bit ARM (armv6, includes Raspberry Pi GPIO support)
- `aarch64` - 64-bit ARM (includes Raspberry Pi GPIO support)

## 🚀 Quick Start

### Installation

Add the repository and install packages on your Alpine Linux system:

```bash
# Add repository (replace 3.23 with your Alpine version)
echo "https://apk.pistar.uk/v3.23/community" >> /etc/apk/repositories

# Add public key
wget -O /etc/apk/keys/hamradio.rsa.pub https://apk.pistar.uk/hamradio.rsa.pub

# Update and install
apk update

# Install all packages
apk add mmdvmhost aprsclients dmrclients dstarclients dstarrepeater \
        fmclients nxdnclients p25clients pocsagclients ysfclients

# Or install specific packages
apk add mmdvmhost          # MMDVM Host only
apk add dstarrepeater      # D-Star Repeater Controller
apk add dstarclients       # D-Star Gateway clients
```

### Starting Services

All packages include OpenRC init scripts with logical service names:

```bash
# Configure services (configs stored under package directories)
cp /etc/mmdvmhost/MMDVM.ini.example /etc/mmdvmhost/MMDVM.ini
cp /etc/dmrclients/DMRGateway.ini.example /etc/dmrclients/DMRGateway.ini
cp /etc/ysfclients/YSFGateway.ini.example /etc/ysfclients/YSFGateway.ini
cp /etc/dstarrepeater/dstarrepeater.conf.example /etc/dstarrepeater/dstarrepeater.conf

# Start services
rc-service mmdvmhost start      # MMDVM Host
rc-service dmrgateway start     # DMR Gateway
rc-service ysfgateway start     # YSF Gateway + Parrot
rc-service dgidgateway start    # DGId Gateway
rc-service nxdngateway start    # NXDN Gateway + Parrot
rc-service p25gateway start     # P25 Gateway + Parrot
rc-service dstargateway start   # D-Star Gateway
rc-service dstarrepeater start  # D-Star Repeater Controller

# Cross-mode converters
rc-service ysf2dmr start        # YSF to DMR
rc-service ysf2nxdn start       # YSF to NXDN
rc-service ysf2p25 start        # YSF to P25
rc-service dmr2ysf start        # DMR to YSF
rc-service dmr2nxdn start       # DMR to NXDN
rc-service nxdn2dmr start       # NXDN to DMR

# Enable at boot
rc-update add mmdvmhost default
rc-update add dmrgateway default
rc-update add dstarrepeater default
```

## 🔧 Building Packages

Packages are built using GitHub Actions. To trigger a build:

1. Go to [Actions](https://github.com/MW0MWZ/MMDVM_APK/actions)
2. Select "Build APK Packages" workflow
3. Click "Run workflow"
4. Select options:
   - **Package**: Choose specific package or "all"
   - **Alpine Version**: Choose specific version or "all"
5. Click "Run workflow"

The build process:
- Clones source from upstream git repositories
- Builds for all architectures using QEMU emulation
- Signs packages with repository private key
- Generates repository indexes
- Deploys to GitHub Pages

### Automatic Builds

The repository monitors upstream repositories for changes and automatically rebuilds packages when updates are detected.

## 📝 Package Versioning

Packages use date-based versioning with git commit tracking:
- Format: `YYYY.MM.DD-r0`
- Example: `2025.01.01-r0`
- Git commit hash is embedded in the package metadata

## 🔑 Repository Signing

All packages and indexes are signed with RSA keys:
- **Public Key**: https://apk.pistar.uk/hamradio.rsa.pub
- **Private Key**: Stored securely in GitHub Secrets

## 🛠️ Development

### Repository Structure

```
MMDVM_APK/
├── .github/workflows/   # GitHub Actions workflows
│   └── build-packages.yml
├── packages/community/  # Package definitions
│   ├── mmdvmhost/
│   ├── dstarrepeater/   # D-Star Repeater Controller
│   ├── dmrclients/      # DMRGateway, DMR2YSF, DMR2NXDN
│   ├── dstarclients/    # DStarGateway and tools
│   ├── ysfclients/      # YSFGateway, YSFParrot, DGIdGateway, YSF2*
│   ├── nxdnclients/     # NXDNGateway, NXDNParrot, NXDN2DMR
│   ├── p25clients/      # P25Gateway, P25Parrot
│   ├── pocsagclients/   # DAPNETGateway
│   ├── fmclients/       # FMGateway
│   └── aprsclients/     # APRSGateway
│       ├── APKBUILD     # Build recipe
│       ├── *.initd      # OpenRC init scripts
│       └── *.confd      # Configuration defaults
├── keys/                # Public keys (private keys in GitHub Secrets)
├── scripts/             # Build and maintenance scripts
├── docs/                # Documentation
└── index.html           # Repository landing page
```

### Package Organization

The repository follows a logical grouping structure:

- **Protocol-specific clients**: `dmrclients`, `dstarclients`, `ysfclients`, `nxdnclients`, `p25clients`
  - Each contains the main gateway, parrot/test tools, and cross-mode converters where applicable
- **Repeater controllers**: `dstarrepeater` - Complete D-Star repeater system
- **Core software**: `mmdvmhost` - The main MMDVM host software
- **Single-purpose clients**: `aprsclients`, `pocsagclients`, `fmclients`

### Adding New Packages

1. Create package directory: `packages/community/{package_name}/`
2. Add APKBUILD file with build instructions
3. Add OpenRC init scripts and configuration files
4. Test locally with Docker (optional)
5. Commit and run workflow

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for detailed instructions.

### Local Testing

Test builds locally using Docker:

```bash
# Clone repository
git clone https://github.com/MW0MWZ/MMDVM_APK.git
cd MMDVM_APK

# Test build (requires Docker)
./scripts/build-package.sh mmdvmhost x86_64 3.23
./scripts/build-package.sh dmrclients x86_64 3.23
./scripts/build-package.sh dstarrepeater x86_64 3.23
```

## 📚 Documentation

- [Building Packages](docs/BUILDING.md) - Detailed build process
- [APK Signing](docs/SIGNING.md) - Package signing details
- [Contributing](docs/CONTRIBUTING.md) - How to contribute

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add your package following the guidelines
4. Submit a pull request

All packages must be Ham Radio related and build from source.

## 📜 License

- Repository infrastructure: MIT License
- Individual packages maintain their upstream licenses
- All packages: GPL-2.0-or-later

## 👤 Maintainer

**MW0MWZ** - andy@mw0mwz.co.uk

## 🔗 Links

- **Repository**: https://github.com/MW0MWZ/MMDVM_APK
- **Issues**: https://github.com/MW0MWZ/MMDVM_APK/issues
- **Web Interface**: https://apk.pistar.uk
- **Sister DEB Repository**: https://deb.pistar.uk

---

Built with ❤️ for the Amateur Radio community by Andy Taylor (MW0MWZ)
