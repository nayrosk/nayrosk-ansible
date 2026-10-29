#!/bin/sh
# Create or update the repository rulesets from .github/rulesets/*.json.
# A ruleset is matched by its name: PUT when it exists, POST otherwise.
# Usage: scripts/github-rulesets.sh   (REPO=owner/name overrides the repository)
set -eu

repo=${REPO:-nayrosk/nayrosk-ansible}
cd "$(dirname "$0")/.."

command -v gh >/dev/null 2>&1 || { echo "gh not found: install the GitHub CLI and run gh auth login" >&2; exit 1; }

for file in .github/rulesets/*.json; do
  name=$(sed -n 's/^  "name": "\(.*\)",$/\1/p' "$file")
  [ -n "$name" ] || { echo "no name found in $file" >&2; exit 1; }
  id=$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$name\") | .id")
  if [ -n "$id" ]; then
    echo "update ruleset '$name' ($id)"
    gh api --method PUT "repos/$repo/rulesets/$id" --input "$file" >/dev/null
  else
    echo "create ruleset '$name'"
    gh api --method POST "repos/$repo/rulesets" --input "$file" >/dev/null
  fi
done
