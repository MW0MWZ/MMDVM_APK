#!/usr/bin/env bash
# Copy the packages from downloaded build artifacts into a repository
# tree, each to v<alpine>/community/<arch>/ as found in its path.
#
#   merge-artifacts.sh ARTIFACT_DIR... DEST
#
# Only .apk files are copied: indexes are signed afresh at publish.

set -euo pipefail

[ "$#" -ge 2 ] || { echo "Usage: merge-artifacts.sh ARTIFACT_DIR... DEST" >&2; exit 1; }
DEST=${!#}
set -- "${@:1:$#-1}"

copied=0
for src in "$@"; do
	[ -d "$src" ] || continue
	while IFS= read -r -d '' pkg; do
		if [[ "$pkg" =~ (v[0-9.]+/community/[^/]+)/[^/]+\.apk$ ]]; then
			mkdir -p "$DEST/${BASH_REMATCH[1]}"
			cp "$pkg" "$DEST/${BASH_REMATCH[1]}/"
			echo "  ${BASH_REMATCH[0]}"
			copied=$((copied + 1))
		else
			echo "Error: $pkg is not under v<alpine>/community/<arch>/" >&2
			exit 1
		fi
	done < <(find "$src" -name '*.apk' -type f -print0)
done

if [ "$copied" -eq 0 ]; then
	echo "Error: no packages found in the build artifacts" >&2
	exit 1
fi
echo "Merged $copied packages"
