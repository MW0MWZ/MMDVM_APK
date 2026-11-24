#!/usr/bin/env bash
# Build Pi-Star APK's change to the repository, run by publish-repo.sh
# on gh-pages as it is at each attempt.
#
#   update-pi-star-repo.sh ARTIFACTS DEST

set -euo pipefail

ARTIFACTS=${1:?artifacts directory}
DEST=${2:?repository}

scripts/merge-artifacts.sh "$DEST" "$ARTIFACTS"/pi-star-*/

result=$(mktemp)
PRUNE_ENV=$result scripts/prune-packages.sh 5 "$DEST"/v*/community/*
DELETED=$(sed -n 's/^CLEANUP_TOTAL_DELETED=//p' "$result")
FREED=$(sed -n 's/^CLEANUP_SPACE_FREED=//p' "$result")
rm -f "$result"
if [ "$DELETED" != "0" ]; then
	echo "Cleaned up $DELETED old packages, freed $FREED" >>"${PUBLISH_NOTES:-/dev/null}"
fi
