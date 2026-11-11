#!/usr/bin/env bash
# Prints the next semantic version tag (vMAJOR.MINOR.PATCH) for a commit, based
# on the Conventional Commits since the last version tag reachable from it.
#
#   usage: next-version.sh <commit-sha>
#
#   - no version tag yet          -> v1.0.0
#   - breaking change since last  -> major  ("type!:" header or "BREAKING CHANGE:" footer)
#   - any "feat" since last       -> minor
#   - anything else               -> patch
#   - the commit already has a version tag -> prints nothing
#
# Only tags shaped exactly vX.Y.Z count; date tags such as v2026.11.11-3 are ignored.
# Tests: .github/scripts/next-version.test.sh
set -euo pipefail

commit="${1:?usage: next-version.sh <commit-sha>}"
version_tag='^v[0-9]+\.[0-9]+\.[0-9]+$'

if git tag --points-at "$commit" | grep -Eq "$version_tag"; then
  exit 0
fi

last=$(git tag --merged "$commit" | grep -E "$version_tag" | sed 's/^v//' |
  sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1 || true)

if [ -z "$last" ]; then
  echo "v1.0.0"
  exit 0
fi

IFS=. read -r major minor patch <<< "$last"

subjects=$(git log --format=%s "v${last}..${commit}")
bodies=$(git log --format=%b "v${last}..${commit}")

if grep -Eq '^[a-z]+(\([^)]*\))?!:' <<< "$subjects" ||
  grep -Eq '^BREAKING[ -]CHANGE:' <<< "$bodies"; then
  echo "v$((major + 1)).0.0"
elif grep -Eq '^feat(\([^)]*\))?:' <<< "$subjects"; then
  echo "v${major}.$((minor + 1)).0"
else
  echo "v${major}.${minor}.$((patch + 1))"
fi
