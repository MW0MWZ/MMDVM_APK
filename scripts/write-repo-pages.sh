#!/usr/bin/env bash
# Write the repository's STATS.md and README.md.
#
#   write-repo-pages.sh DEST [DELETED FREED]
#
# DELETED and FREED are the last cleanup's results, listed in STATS.md
# when anything was removed.

set -euo pipefail

DEST=${1:?repository}
DELETED=${2:-0}
FREED=${3:-0MB}

{
	echo "# Repository Statistics"
	echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
	echo ""
	TOTAL_PACKAGES=0
	for version in 3.23 3.22; do
		echo "## Alpine $version"
		for arch in x86_64 armhf aarch64 noarch; do
			if [ -d "$DEST/v$version/community/$arch" ]; then
				count=$(find "$DEST/v$version/community/$arch" -name "*.apk" | wc -l)
				size=$(du -sh "$DEST/v$version/community/$arch" | cut -f1)
				echo "- **$arch**: $count packages ($size)"
				TOTAL_PACKAGES=$((TOTAL_PACKAGES + count))
			fi
		done
		echo ""
	done
	echo "## Total"
	echo "- **Total Packages**: $TOTAL_PACKAGES"
	echo "- **Repository Size**: $(du -sh --exclude=.git "$DEST" | cut -f1)"
	if [ "$DELETED" != "0" ]; then
		echo ""
		echo "## Last Cleanup"
		echo "- **Packages Removed**: $DELETED"
		echo "- **Space Freed**: $FREED"
	fi
} >"$DEST/STATS.md"

{
	echo "# Ham Radio APK Repository"
	echo ""
	echo "## Repository Configuration"
	echo ""
	echo "To use this repository, add the following to your /etc/apk/repositories:"
	echo ""
	echo "### For Alpine 3.23:"
	echo '```'
	echo "https://apk.pistar.uk/v3.23/community/x86_64"
	echo "https://apk.pistar.uk/v3.23/community/noarch"
	echo '```'
	echo ""
	echo "For ARM systems, replace x86_64 with:"
	echo "- armhf for 32-bit ARM (Raspberry Pi Zero/1/2)"
	echo "- aarch64 for 64-bit ARM (Raspberry Pi 3/4/5)"
	echo ""
	echo "### For Alpine 3.22:"
	echo '```'
	echo "https://apk.pistar.uk/v3.22/community/x86_64"
	echo "https://apk.pistar.uk/v3.22/community/noarch"
	echo '```'
	echo ""
	echo "## Adding the Repository Key"
	echo ""
	echo '```bash'
	echo "wget -O /etc/apk/keys/hamradio.rsa.pub https://apk.pistar.uk/hamradio.rsa.pub"
	echo '```'
	echo ""
	echo "## Installing Packages"
	echo ""
	echo '```bash'
	echo "apk update"
	echo "apk add mmdvmhost"
	echo '```'
	echo ""
	echo "## Available Packages"
	echo ""
	echo "See [STATS.md](STATS.md) for a complete list of available packages."
} >"$DEST/README.md"
