#!/usr/bin/env bash
# Build APK Packages' change to the repository, run by publish-repo.sh
# on gh-pages as it is at each attempt.
#
#   update-packages-repo.sh ARTIFACTS DEST
#
# Environment:
#   VERSIONS_TO_KEEP  versions of each package to keep (default 5)
#   SKIP_CLEANUP      "true" keeps every version

set -euo pipefail

ARTIFACTS=${1:?artifacts directory}
DEST=${2:?repository}
KEEP=${VERSIONS_TO_KEEP:-5}

scripts/merge-artifacts.sh "$DEST" "$ARTIFACTS"/packages-*/

cp keys/hamradio.rsa.pub "$DEST/hamradio.rsa.pub"
cp CNAME index.html _config.yml "$DEST/"
touch "$DEST/.nojekyll"

DELETED=0
FREED=0MB
if [ "${SKIP_CLEANUP:-false}" != "true" ]; then
	result=$(mktemp)
	PRUNE_ENV=$result scripts/prune-packages.sh "$KEEP" "$DEST"/v*/community/*
	DELETED=$(sed -n 's/^CLEANUP_TOTAL_DELETED=//p' "$result")
	FREED=$(sed -n 's/^CLEANUP_SPACE_FREED=//p' "$result")
	rm -f "$result"
	if [ "$DELETED" != "0" ]; then
		echo "Cleaned up $DELETED old packages, freed $FREED" >>"${PUBLISH_NOTES:-/dev/null}"
	fi
fi

# STATS.md
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

# README.md
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
