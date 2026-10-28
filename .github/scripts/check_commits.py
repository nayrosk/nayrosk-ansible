#!/usr/bin/env python3
"""Check the commits of a pull request against the project policy.

Reads the JSON of `gh api repos/<repo>/pulls/<n>/commits --paginate` on stdin (one array per
page) and exits 1 when a commit has no verified signature, has a subject that is not a
Conventional Commit, or carries AI attribution in its message.
"""

import json
import re
import sys

SUBJECT = re.compile(r"^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9_-]+\))?!?: .+")
FORBIDDEN = (
    ("Co-Authored-By trailer", re.compile(r"^co-authored-by:", re.IGNORECASE | re.MULTILINE)),
    ("claude.ai link", re.compile(r"claude\.ai", re.IGNORECASE)),
    ("noreply@anthropic.com address", re.compile(r"noreply@anthropic\.com", re.IGNORECASE)),
    ("Generated with line", re.compile(r"generated with", re.IGNORECASE)),
)


def read_pages(text):
    """Return the commits from concatenated JSON arrays."""
    decoder = json.JSONDecoder()
    commits = []
    position = 0
    while True:
        while position < len(text) and text[position].isspace():
            position += 1
        if position >= len(text):
            return commits
        page, position = decoder.raw_decode(text, position)
        commits.extend(page)


def problems(commit):
    """Return the policy violations of one commit as a list of messages."""
    found = []
    detail = commit["commit"]
    message = detail["message"]
    subject = message.split("\n", 1)[0]
    if not detail.get("verification", {}).get("verified", False):
        found.append("signature is not verified")
    # Merge commits from "Update branch" vanish in the squash; skip the subject check.
    if len(commit.get("parents", [])) <= 1 and not SUBJECT.match(subject):
        found.append("subject is not a Conventional Commit")
    for label, pattern in FORBIDDEN:
        if pattern.search(message):
            found.append("message contains a " + label)
    return found


def main():
    """Check every commit and return the process exit status."""
    commits = read_pages(sys.stdin.read())
    if not commits:
        print("::error::No commits found for the pull request")
        return 1
    status = 0
    for commit in commits:
        subject = commit["commit"]["message"].split("\n", 1)[0]
        short = commit["sha"][:7]
        for problem in problems(commit):
            print(f"::error::{short} {problem}: {subject}")
            status = 1
    if status == 0:
        print(f"{len(commits)} commit(s) ok")
    return status


if __name__ == "__main__":
    sys.exit(main())
