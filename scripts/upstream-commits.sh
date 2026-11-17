#!/bin/sh
# upstream-commits.sh <APKBUILD>
#
# Lists every upstream git repository a package builds from, so that an
# update to any of them (not just the first) triggers a rebuild. Each
# *giturl* variable in the APKBUILD is one repository; the commit last
# built from it is recorded in its own variable:
#
#   giturl=...              -> _gitcommit
#   giturl_cal=...          -> _cal_gitcommit
#   dmrgateway_giturl=...   -> _dmrgateway_gitcommit
#
# Prints one line per repository:
#
#   <commit variable> <recorded commit> <latest commit> <url> <url variable>
#
# "-" stands for no recorded commit, or a repository that could not be
# reached. The latest commit is that of the repository's default branch
# (git ls-remote HEAD), which is what the APKBUILD's git clone builds.
set -eu

apkbuild=$1

grep -E '^[A-Za-z0-9_]*giturl[A-Za-z0-9_]*="' "$apkbuild" | while IFS= read -r line; do
	var=${line%%=*}
	url=$(printf '%s' "$line" | cut -d'"' -f2)
	name=$(printf '%s' "$var" | sed -e 's/giturl//' -e 's/^_*//' -e 's/_*$//')
	if [ -z "$name" ]; then
		cvar=_gitcommit
	else
		cvar="_${name}_gitcommit"
	fi
	recorded=$(grep -E "^${cvar}=" "$apkbuild" | head -1 | cut -d'"' -f2)
	latest=$(git ls-remote "$url" HEAD 2>/dev/null | head -1 | cut -c1-7)
	echo "$cvar ${recorded:--} ${latest:--} $url $var"
done
