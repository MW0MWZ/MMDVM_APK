#!/usr/bin/env bash
# Keep the newest KEEP versions of each package in each repository
# directory and delete the rest.
#
#   prune-packages.sh [--dry-run] KEEP DIR...
#
# A file is <name>-<version>-r<release>.apk, where the version has no
# hyphen (Alpine's rule), so the name is everything before the last two
# hyphen-separated fields: wiringpi-dev-3.20-r6.apk is wiringpi-dev,
# version 3.20, release 6.
#
# Versions are ordered numerically (3.20 after 3.18, r10 after r9),
# never by file time or by name: the files are fresh copies in every
# run, so their times say nothing about which build is newer.
#
# Nothing is deleted on doubt: a file whose name does not parse, or a
# package with any version that is not plain dotted numbers (such as
# 1.0_rc1, which numeric ordering would get wrong), is left alone with
# a warning.
#
# With GITHUB_ENV set, CLEANUP_TOTAL_DELETED and CLEANUP_SPACE_FREED are
# written for the deploy commit message.

set -euo pipefail
export LC_ALL=C

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
	DRY_RUN=1
	shift
fi

KEEP="${1:-}"
if ! [[ "$KEEP" =~ ^[0-9]+$ ]] || [ "$KEEP" -lt 1 ]; then
	echo "Error: KEEP must be a whole number of at least 1 (got '$KEEP')" >&2
	exit 1
fi
shift

warn() {
	if [ -n "${GITHUB_ACTIONS:-}" ]; then
		echo "::warning::$*"
	else
		echo "WARNING: $*"
	fi
}

TOTAL_DELETED=0
TOTAL_BYTES=0

for DIR in "$@"; do
	if [ ! -d "$DIR" ]; then
		echo "$DIR: no such directory, skipped"
		continue
	fi

	declare -A ROWS=()   # name -> "version<TAB>release<TAB>file" lines
	declare -A UNSAFE=() # name -> 1 when a version can't be ordered safely

	shopt -s nullglob
	for path in "$DIR"/*.apk; do
		f=${path##*/}
		if [[ "$f" =~ ^(.+)-([0-9][^-]*)-r([0-9]+)\.apk$ ]]; then
			name=${BASH_REMATCH[1]}
			ver=${BASH_REMATCH[2]}
			rel=${BASH_REMATCH[3]}
			if ! [[ "$ver" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
				UNSAFE[$name]=1
			fi
			ROWS[$name]+="$ver"$'\t'"$rel"$'\t'"$f"$'\n'
		else
			warn "$DIR/$f: name not understood, left alone"
		fi
	done
	shopt -u nullglob

	deleted=0
	for name in $(printf '%s\n' "${!ROWS[@]}" | sort); do
		# newest first: version numerically, then release numerically
		mapfile -t sorted < <(printf '%s' "${ROWS[$name]}" | sort -t $'\t' -k1,1Vr -k2,2nr)
		count=${#sorted[@]}
		if [ -n "${UNSAFE[$name]:-}" ]; then
			warn "$DIR: $name has a version that is not plain numbers, its $count files left alone"
			continue
		fi
		if [ "$count" -le "$KEEP" ]; then
			continue
		fi
		kept=()
		for ((i = 0; i < KEEP; i++)); do
			kept+=("$(cut -f3 <<<"${sorted[$i]}")")
		done
		echo "$DIR: $name has $count versions, keeping ${kept[*]}"
		for ((i = KEEP; i < count; i++)); do
			f=$(cut -f3 <<<"${sorted[$i]}")
			bytes=$(stat -c %s "$DIR/$f")
			echo "  delete $f"
			if [ "$DRY_RUN" -eq 0 ]; then
				rm -f -- "$DIR/$f"
			fi
			deleted=$((deleted + 1))
			TOTAL_BYTES=$((TOTAL_BYTES + bytes))
		done
	done
	TOTAL_DELETED=$((TOTAL_DELETED + deleted))
	echo "$DIR: $deleted deleted"

	unset ROWS UNSAFE
done

FREED="$((TOTAL_BYTES / 1024 / 1024))MB"
echo "Deleted $TOTAL_DELETED old package files, freed $FREED$([ "$DRY_RUN" -eq 1 ] && echo ' (dry run: nothing removed)')"

if [ -n "${GITHUB_ENV:-}" ] && [ "$DRY_RUN" -eq 0 ]; then
	echo "CLEANUP_TOTAL_DELETED=$TOTAL_DELETED" >>"$GITHUB_ENV"
	echo "CLEANUP_SPACE_FREED=$FREED" >>"$GITHUB_ENV"
fi
