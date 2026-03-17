# Ham Radio APK Repository

## Repository Configuration

To use this repository, add the following to your /etc/apk/repositories:

### For Alpine 3.23:
```
https://apk.pistar.uk/v3.23/community/x86_64
https://apk.pistar.uk/v3.23/community/noarch
```

For ARM systems, replace x86_64 with:
- armhf for 32-bit ARM (Raspberry Pi Zero/1/2)
- aarch64 for 64-bit ARM (Raspberry Pi 3/4/5)

### For Alpine 3.22:
```
https://apk.pistar.uk/v3.22/community/x86_64
https://apk.pistar.uk/v3.22/community/noarch
```

## Adding the Repository Key

```bash
wget -O /etc/apk/keys/hamradio.rsa.pub https://apk.pistar.uk/hamradio.rsa.pub
```

## Installing Packages

```bash
apk update
apk add mmdvmhost
```

## Available Packages

See [STATS.md](STATS.md) for a complete list of available packages.
