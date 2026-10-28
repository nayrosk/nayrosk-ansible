#!/bin/sh
# Check that a pull request branch name follows the project convention.
# Usage: check-branch.sh <branch>
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <branch>" >&2
  exit 2
fi
branch=$1

# <type>/<issue number>-<slug>, a release branch, or a dependency bot branch.
pattern='^((feat|fix|chore)/[0-9]+-[a-z0-9]+(-[a-z0-9]+)*|chore/release-v[0-9]+\.[0-9]+\.[0-9]+|dependabot/.+|renovate/.+)$'

if ! printf '%s\n' "$branch" | grep -Eq "$pattern"; then
  echo "::error::Branch name does not match <feat|fix|chore>/<issue>-<slug>, chore/release-vX.Y.Z, dependabot/* or renovate/*: $branch"
  exit 1
fi
echo "Branch name ok: $branch"
