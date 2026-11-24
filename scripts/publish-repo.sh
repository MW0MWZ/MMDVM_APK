#!/usr/bin/env bash
# Publish to the gh-pages branch, leaving the repository clean and ready
# for use, without undoing anyone else's release.
#
#   publish-repo.sh DIR MESSAGE COMMAND [ARGS...]
#
# DIR is a git checkout of gh-pages. Each attempt:
#   1. resets DIR to gh-pages as it is now on the remote
#   2. runs COMMAND ARGS... DIR, which adds this run's packages
#   3. tidies the whole repository, whatever this run changed:
#      - keeps the newest VERSIONS_TO_KEEP versions of every package
#      - removes leftover unsigned indexes, and the index of a folder
#        with no packages left
#      - signs a fresh APKINDEX for every folder with packages
#      - restores the public key, CNAME, index.html, _config.yml and
#        .nojekyll, and rewrites STATS.md and README.md
#   4. commits and pushes, never forced
# Each index must verify against KEY_PUB, the key published as
# hamradio.rsa.pub for clients, or nothing is pushed: a wrong signing
# key fails here, not on every client.
# Every workflow that changes gh-pages publishes this way. When the push
# is refused because another workflow pushed first, the next attempt
# starts again from that newer branch, so both releases end up
# published: a deploy never replaces the branch with an older copy.
#
# COMMAND may append lines for the commit message to "$PUBLISH_NOTES".
#
# Environment:
#   APK_PRIVATE_KEY   signing key (required)
#   KEY_PUB           public key, default keys/hamradio.rsa.pub
#   VERSIONS_TO_KEEP  default 5
#   SKIP_CLEANUP      "true" keeps every version (a manual run's choice)
#   ATTEMPTS          default 5

set -euo pipefail

DIR=${1:?gh-pages checkout}
MESSAGE=${2:?commit message}
shift 2
[ "$#" -gt 0 ] || { echo "Error: no update command" >&2; exit 1; }
: "${APK_PRIVATE_KEY:?}"
KEY_PUB=${KEY_PUB:-keys/hamradio.rsa.pub}
ATTEMPTS=${ATTEMPTS:-5}
KEEP=${VERSIONS_TO_KEEP:-5}

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
			chown '"$(id -u):$(id -g)"' APKINDEX.tar.gz
			# Clients trust hamradio.rsa.pub: the index must be signed
			# under that name and verify against the key published
			if ! tar -tzf APKINDEX.tar.gz | grep -qx ".SIGN.RSA.hamradio.rsa.pub"; then
				echo "Error: APKINDEX.tar.gz is not signed as hamradio.rsa.pub" >&2
				exit 1
			fi
			if ! apk verify APKINDEX.tar.gz; then
				echo "Error: APKINDEX.tar.gz does not verify against the published public key" >&2
				exit 1
			fi
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

	DELETED=0
	FREED=0MB
	if [ "${SKIP_CLEANUP:-false}" = "true" ]; then
		echo "Cleanup skipped: every version kept"
	else
		: >"$WORK/prune"
		PRUNE_ENV="$WORK/prune" scripts/prune-packages.sh "$KEEP" "$DIR"/v*/community/*
		DELETED=$(sed -n 's/^CLEANUP_TOTAL_DELETED=//p' "$WORK/prune")
		FREED=$(sed -n 's/^CLEANUP_SPACE_FREED=//p' "$WORK/prune")
		if [ "$DELETED" != "0" ]; then
			echo "Cleaned up $DELETED old packages, freed $FREED" >>"$PUBLISH_NOTES"
		fi
	fi

	for repo in "$DIR"/v*/community/*/; do
		repo=${repo%/}
		rm -fv "$repo/APKINDEX.unsigned.tar.gz"
		if compgen -G "$repo/*.apk" >/dev/null; then
			index "$repo"
		elif [ -f "$repo/APKINDEX.tar.gz" ]; then
			echo "${repo#"$DIR"/}: no packages, index removed"
			rm -f "$repo/APKINDEX.tar.gz"
		fi
	done

	cp "$KEY_PUB" "$DIR/hamradio.rsa.pub"
	cp CNAME index.html _config.yml "$DIR/"
	touch "$DIR/.nojekyll"
	scripts/write-repo-pages.sh "$DIR" "$DELETED" "$FREED"

	git -C "$DIR" add -A
	if git -C "$DIR" diff --cached --quiet; then
		echo "Nothing to publish: gh-pages is already up to date"
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
