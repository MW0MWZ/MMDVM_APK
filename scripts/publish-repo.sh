#!/usr/bin/env bash
# Publish to the gh-pages branch without undoing anyone else's release.
#
#   publish-repo.sh DIR MESSAGE COMMAND [ARGS...]
#
# DIR is a git checkout of gh-pages. Each attempt:
#   1. resets DIR to gh-pages as it is now on the remote
#   2. runs COMMAND ARGS... DIR, which puts this run's packages in
#   3. signs a fresh APKINDEX for every repository folder whose packages
#      changed (or that has none yet)
#   4. commits and pushes, never forced
# Both package workflows publish this way. When the push is refused
# because another workflow pushed first, the next attempt starts again
# from that newer branch, so both releases end up published. A deploy
# never replaces the branch with an older copy of it.
#
# COMMAND may append lines for the commit message to "$PUBLISH_NOTES".
#
# Environment:
#   APK_PRIVATE_KEY  signing key (required)
#   KEY_PUB          public key, default keys/hamradio.rsa.pub
#   ATTEMPTS         default 5

set -euo pipefail

DIR=${1:?gh-pages checkout}
MESSAGE=${2:?commit message}
shift 2
[ "$#" -gt 0 ] || { echo "Error: no update command" >&2; exit 1; }
: "${APK_PRIVATE_KEY:?}"
KEY_PUB=${KEY_PUB:-keys/hamradio.rsa.pub}
ATTEMPTS=${ATTEMPTS:-5}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/keys"
printf '%s\n' "$APK_PRIVATE_KEY" >"$WORK/keys/hamradio.rsa"
cp "$KEY_PUB" "$WORK/keys/hamradio.rsa.pub"
export PUBLISH_NOTES="$WORK/notes"

# index REPO_DIR: sign a fresh APKINDEX for one v<alpine>/community/<arch>
index() {
	local repo=$1 arch alpine platform
	arch=$(basename "$repo")
	alpine=$(basename "$(dirname "$(dirname "$repo")")")
	alpine=${alpine#v}
	case "$arch" in
	x86_64 | noarch) platform=linux/amd64 ;;
	armhf) platform=linux/arm/v6 ;;
	aarch64) platform=linux/arm64 ;;
	*)
		echo "Error: $repo: unknown architecture $arch" >&2
		return 1
		;;
	esac
	echo "::group::Index $repo"
	docker run --rm \
		--platform "$platform" \
		-v "$WORK/keys:/keys:ro" \
		-v "$(realpath "$repo"):/repo" \
		"alpine:${alpine}" \
		sh -c '
			set -e
			echo "https://dl-cdn.alpinelinux.org/alpine/v'"$alpine"'/community" >> /etc/apk/repositories
			apk update
			apk add --no-cache alpine-sdk
			mkdir -p /root/.abuild
			echo "PACKAGER_PRIVKEY=\"/keys/hamradio.rsa\"" > /root/.abuild/abuild.conf
			cp /keys/hamradio.rsa.pub /etc/apk/keys/
			cd /repo
			rm -f APKINDEX.tar.gz APKINDEX.unsigned.tar.gz
			apk index -o APKINDEX.unsigned.tar.gz *.apk
			abuild-sign -k /keys/hamradio.rsa APKINDEX.unsigned.tar.gz
			mv APKINDEX.unsigned.tar.gz APKINDEX.tar.gz
			echo "$(tar -xzOf APKINDEX.tar.gz APKINDEX | grep -c "^P:") packages in index"
		'
	echo "::endgroup::"
}

git -C "$DIR" config user.name "github-actions[bot]"
git -C "$DIR" config user.email "github-actions[bot]@users.noreply.github.com"

for ((attempt = 1; attempt <= ATTEMPTS; attempt++)); do
	echo "=== Publish attempt $attempt of $ATTEMPTS"

	git -C "$DIR" fetch --depth=1 origin gh-pages
	git -C "$DIR" reset --hard FETCH_HEAD
	git -C "$DIR" clean -ffdx
	: >"$PUBLISH_NOTES"

	"$@" "$DIR"

	# Folders to index: packages added or removed, or no index yet
	mapfile -t changed < <(
		{
			git -C "$DIR" status --porcelain --untracked-files=all -- 'v*/community/*/*.apk' |
				sed -E 's/^.{3}//; s/.* -> //' | xargs -r -n1 dirname
			for d in "$DIR"/v*/community/*/; do
				d=${d%/}
				[ -f "$d/APKINDEX.tar.gz" ] || echo "${d#"$DIR"/}"
			done
		} | sort -u
	)
	for rel in "${changed[@]}"; do
		repo="$DIR/$rel"
		if compgen -G "$repo/*.apk" >/dev/null; then
			index "$repo"
		else
			echo "$rel: no packages left, index removed"
			rm -f "$repo/APKINDEX.tar.gz"
		fi
	done

	git -C "$DIR" add -A
	if git -C "$DIR" diff --cached --quiet; then
		echo "Nothing to publish: gh-pages already has these packages"
		exit 0
	fi
	git -C "$DIR" commit -q -F - <<-EOF
		$MESSAGE
		$(cat "$PUBLISH_NOTES")
	EOF
	if git -C "$DIR" push origin HEAD:refs/heads/gh-pages; then
		echo "Published $(git -C "$DIR" rev-parse --short HEAD)"
		exit 0
	fi
	echo "gh-pages moved on while this run was publishing; starting again from it"
	sleep $((attempt * 15))
done

echo "Error: could not publish after $ATTEMPTS attempts" >&2
exit 1
