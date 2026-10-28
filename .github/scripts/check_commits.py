#!/usr/bin/env python3
"""Check the commits of a pull request against the project policy.

Usage:
  check_commits.py [--total N]   commits JSON on stdin
  check_commits.py --body        pull request description on stdin

Commit mode reads the JSON of `gh api repos/<repo>/pulls/<n>/commits --paginate` (one array per
page) and exits 1 when a commit has no verified signature, has a subject that is not a
Conventional Commit, or carries AI attribution in its message or author email. --total is the
commit count of the pull request; the API returns at most 250 commits, so more is refused.
Body mode applies the attribution patterns to the description, which can end up in the squash message.
"""

import json
import re
import sys

SUBJECT = re.compile(r"^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9_-]+\))?!?: .+")
FORBIDDEN = (
    ("Co-Authored-By trailer", re.compile(r"^co-authored-by:", re.IGNORECASE | re.MULTILINE)),
    ("claude.ai link", re.compile(r"claude\.ai", re.IGNORECASE)),
    ("noreply@anthropic.com address", re.compile(r"noreply@anthropic\.com", re.IGNORECASE)),
    ("Generated with line", re.compile(r"^\W*generated with\s+\[?claude", re.IGNORECASE | re.MULTILINE)),
)
MAX_COMMITS = 250
BOT_EMAIL = "noreply@anthropic.com"


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
    found.extend(text_problems(message))
    for role in ("author", "committer"):
        if ((detail.get(role) or {}).get("email") or "").lower() == BOT_EMAIL:
            found.append(f"{role} email is {BOT_EMAIL}")
    return found


def text_problems(text):
    """Return the attribution violations of a text as a list of messages."""
    return ["message contains a " + label for label, pattern in FORBIDDEN if pattern.search(text)]


def check_body(text):
    """Check a pull request description and return the process exit status."""
    found = text_problems(text)
    for problem in found:
        print(f"::error::Pull request description: {problem.replace('message', 'text', 1)}")
    if not found:
        print("description ok")
    return 1 if found else 0


def main(argv):
    """Check every commit and return the process exit status."""
    if argv[:1] == ["--body"]:
        return check_body(sys.stdin.read())
    total = int(argv[1]) if argv[:1] == ["--total"] and len(argv) > 1 else None
    commits = read_pages(sys.stdin.read())
    if not commits:
        print("::error::No commits found for the pull request")
        return 1
    if (total or len(commits)) > MAX_COMMITS or len(commits) >= MAX_COMMITS:
        print(f"::error::The pull request has more than {MAX_COMMITS} commits, which the API cannot list; split it")
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
    sys.exit(main(sys.argv[1:]))
