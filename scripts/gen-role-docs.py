#!/usr/bin/env python3
"""Render the variable tables of every role from its meta/argument_specs.yml.

The tables are written between the BEGIN VARIABLES and END VARIABLES markers of each
roles/<role>/README.md and of docs/roles.md. Everything outside the markers is hand-written.

  scripts/gen-role-docs.py            rewrite the files
  scripts/gen-role-docs.py --check    change nothing, exit 1 and list the stale files
"""
import argparse
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
BEGIN = "<!-- BEGIN VARIABLES -->"
END = "<!-- END VARIABLES -->"
MAX_DEFAULT = 60
HEADER = "| Variable | Type | Default | Required | Description |\n| --- | --- | --- | --- | --- |"


def load_yaml(path):
    if not path.is_file():
        return {}
    return yaml.safe_load(path.read_text()) or {}


def playbook_roles():
    plays = load_yaml(ROOT / "playbooks" / "install_base.yml")
    names = []
    for play in plays:
        for item in play.get("roles", []):
            names.append(item["role"] if isinstance(item, dict) else item)
    return names


def markup(text):
    """Turn the Ansible documentation markup of a description into Markdown."""
    text = re.sub(r"[CVOE]\(([^)]*)\)", lambda m: f"`{m.group(1)}`", text)
    text = re.sub(r"I\(([^)]*)\)", r"*\1*", text)
    return text


def describe(value):
    if isinstance(value, list):
        value = " ".join(str(v) for v in value)
    return cell(markup(" ".join(str(value).split())))


def cell(text):
    return text.replace("|", "\\|")


def code(text):
    """Inline code safe inside a table cell."""
    return "`" + cell(text) + "`"


def flow(value):
    """Compact one-line rendering of a YAML value."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return f'"{value}"' if value == "" or value != value.strip() else value
    if isinstance(value, list):
        return "[" + ", ".join(flow(v) for v in value) + "]"
    if isinstance(value, dict):
        return "{" + ", ".join(f"{k}: {flow(v)}" for k, v in value.items()) + "}"
    return str(value)


def render_default(value):
    if isinstance(value, str) and "\n" in value.strip("\n"):
        return "multi-line value, see `defaults/main.yml`"
    text = flow(value.strip("\n") if isinstance(value, str) else value)
    if len(text) > MAX_DEFAULT:
        size = f"{len(value)} entries, " if isinstance(value, (list, dict)) else ""
        return code(text[: MAX_DEFAULT - 3].rstrip(", ") + "...") + f" ({size}truncated, see `defaults/main.yml`)"
    return code(text)


def options_rows(options, defaults, prefix=""):
    rows = []
    for name, spec in options.items():
        full = f"{prefix}{name}"
        secret = bool(spec.get("no_log"))
        if secret:
            default = "secret"
        elif "default" in spec:
            default = render_default(spec["default"])
        elif not prefix and name in defaults:
            default = render_default(defaults[name])
        else:
            default = "none"
        required = "yes" if spec.get("required") else "no"
        kind = spec.get("type", "str")
        if spec.get("elements"):
            kind += f" of {spec['elements']}"
        rows.append(
            f"| `{full}` | {kind} | {default} | {required} | {describe(spec.get('description', ''))} |"
        )
        rows.extend(options_rows(spec.get("options") or {}, {}, prefix=f"{full}[]."))
    return rows


def role_table(role):
    """Return (purpose, table markdown, problems) for a role."""
    base = ROOT / "roles" / role
    spec = load_yaml(base / "meta" / "argument_specs.yml").get("argument_specs", {}).get("main")
    problems = []
    if spec is None:
        return "", "", [f"{role}: meta/argument_specs.yml has no main entry point"]
    defaults = load_yaml(base / "defaults" / "main.yml")
    options = spec.get("options") or {}
    for name in defaults:
        if name not in options:
            problems.append(f"{role}: {name} is in defaults/main.yml but not in argument_specs.yml")
    for name, opt in options.items():
        if "default" in opt and name in defaults and not opt.get("no_log"):
            a, b = opt["default"], defaults[name]
            if a != b and not (isinstance(a, str) and "{{" in a):
                problems.append(f"{role}: {name} default differs between argument_specs.yml and defaults/main.yml")
    galaxy = load_yaml(base / "meta" / "main.yml").get("galaxy_info", {})
    purpose = galaxy.get("description") or spec.get("short_description", "")
    if not options:
        return purpose, "This role takes no variables.", problems
    return purpose, "\n".join([HEADER, *options_rows(options, defaults)]), problems


def replace_region(text, body, label):
    if BEGIN not in text or END not in text:
        raise SystemExit(f"{label}: missing {BEGIN} / {END} markers")
    head, rest = text.split(BEGIN, 1)
    _, tail = rest.split(END, 1)
    return f"{head}{BEGIN}\n{body}\n{END}{tail}"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="exit 1 when a file is stale, write nothing")
    args = parser.parse_args()

    targets = {}
    sections = []
    problems = []
    for role in playbook_roles():
        purpose, table, issues = role_table(role)
        problems += issues
        readme = ROOT / "roles" / role / "README.md"
        targets[readme] = table
        sections.append(f"## {role}\n\n{purpose}\n\n{table}" if purpose else f"## {role}\n\n{table}")
    targets[ROOT / "docs" / "roles.md"] = "\n\n".join(sections)

    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 1

    stale = []
    for path, body in targets.items():
        old = path.read_text()
        new = replace_region(old, body, str(path.relative_to(ROOT)))
        if new != old:
            stale.append(path.relative_to(ROOT))
            if not args.check:
                path.write_text(new)
    if args.check:
        if stale:
            print("stale, run make docs:", *map(str, stale), sep="\n  ", file=sys.stderr)
            return 1
        print("docs are up to date")
        return 0
    print(f"updated {len(stale)} file(s)" if stale else "docs are up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main())
