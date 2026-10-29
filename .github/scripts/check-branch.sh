#!/bin/sh
# Check that a pull request branch name follows the project convention.
# Usage: check-branch.sh <branch> <author> <owner>
# Bot branches (dependabot/, renovate/) are accepted only from the matching bot, and release branches
# only from the repository owner.
set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <branch> <author> <owner>" >&2
  exit 2
fi
branch=$1
author=$2
owner=$3

fail() {
  echo "::error::$1: $branch (author $author)"
  exit 1
}

case $branch in
  dependabot/*)
    [ "$author" = "dependabot[bot]" ] || fail "Only dependabot[bot] may use a dependabot/ branch"
    ;;
  renovate/*)
    [ "$author" = "renovate[bot]" ] || fail "Only renovate[bot] may use a renovate/ branch"
    ;;
  *)
    if printf '%s\n' "$branch" | grep -Eq '^chore/release-v[0-9]+\.[0-9]+\.[0-9]+$'; then
      [ "$author" = "$owner" ] || fail "Only $owner may open a release branch"
    elif ! printf '%s\n' "$branch" | grep -Eq '^(feat|fix|chore)/[0-9]+-[a-z0-9]+(-[a-z0-9]+)*$'; then
      fail "Branch name must be <feat|fix|chore>/<issue>-<slug>, chore/release-vX.Y.Z, dependabot/* or renovate/*"
    fi
    ;;
esac
echo "Branch name ok: $branch"
