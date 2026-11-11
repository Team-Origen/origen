#!/usr/bin/env bash
# Tests for next-version.sh. Run: bash .github/scripts/next-version.test.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/next-version.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAILURES=0

repo() {
  rm -rf "$WORK/repo" && mkdir "$WORK/repo" && cd "$WORK/repo"
  git init -q -b main
  git config user.email test@example.test
  git config user.name test
  git config tag.gpgSign false
  git config commit.gpgSign false
}

commit() { git commit -q --allow-empty -m "$1" ${2:+-m "$2"}; }

expect() {
  local name="$1" expected="$2" actual
  actual="$(bash "$SCRIPT" "$(git rev-parse HEAD)")"
  if [ "$actual" = "$expected" ]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name: expected '$expected', got '$actual'"
    FAILURES=$((FAILURES + 1))
  fi
}

repo; commit "chore: init"
expect "first deploy without semver tags starts at v1.0.0" "v1.0.0"

repo; commit "chore: init"; git tag v1.0.0; commit "fix(auth): handle expiry"; commit "docs: readme"
expect "fix and docs bump the patch" "v1.0.1"

repo; commit "chore: init"; git tag v1.2.3; commit "fix: a"; commit "feat(booking): add slots"
expect "feat bumps the minor and resets the patch" "v1.3.0"

repo; commit "chore: init"; git tag v1.2.3; commit "feat(api)!: drop v1 endpoints"
expect "! in the header bumps the major" "v2.0.0"

repo; commit "chore: init"; git tag v1.2.3; commit "refactor: rename" "BREAKING CHANGE: config key renamed"
expect "BREAKING CHANGE footer bumps the major" "v2.0.0"

repo; commit "chore: init"; git tag v1.2.3; commit "Merge pull request #9 from org/feat/x"; commit "chore(deps): bump"
expect "merge commits and chores bump the patch" "v1.2.4"

repo; commit "chore: init"; git tag v1.2.3
expect "a commit that already has a semver tag gets none" ""

repo; commit "chore: init"; git tag v1.2.3; git tag v2026.11.11-3; commit "fix: a"
expect "date tags are ignored when finding the last version" "v1.2.4"

repo; commit "chore: init"; git tag v1.2.3; commit "fix: a"; git tag v2026.11.12-4
expect "a commit with only a date tag still gets a version" "v1.2.4"

repo; commit "chore: init"; git tag v1.9.0; git tag v1.10.0; commit "fix: a"
expect "versions are compared numerically, not as text" "v1.10.1"

repo; commit "chore: init"; git tag v1.0.0; git checkout -q -b side; commit "feat: side"; git tag v1.1.0
git checkout -q main; commit "fix: main"
expect "only tags reachable from the commit count" "v1.0.1"

repo; commit "chore: init"; git tag v1.0.0; commit "feature: not a conventional feat"; commit "feat-x: nope"
expect "only the exact feat type bumps the minor" "v1.0.1"

if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES test(s) failed"
  exit 1
fi
echo "all tests passed"
