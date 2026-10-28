# nayrosk-ansible

Instructions for coding agents on this repo. `AGENTS.md` points here.

nayrosk-ansible = Ansible playbooks. Turn fresh Ubuntu 26.04 LTS host into hardened host: identity, DNS over TLS, time, updates, UFW, fail2ban, key-only operator account, rootless Caddy in front of rootful node_exporter (Podman quadlets). One command for first run + later runs. User docs in `README.md` and `docs/`.

## Layout

- `playbooks/install_base.yml`: entry playbook, 15 roles in order.
- `roles/<name>/`: `defaults/`, `tasks/`, `handlers/`, `templates/`, `meta/argument_specs.yml`, `README.md`. Tag = role name.
- `inventories/example/`: sample inventory + `group_vars/all/vault.yml` (Ansible Vault). `inventories/e2e/`: throwaway inventory for the VM test.
- `tests/e2e/`: `run.sh` harness, `verify.yml`, `check-idempotence.sh`, `controller/provision.sh` (controller image), `vm/` (qemu/KVM host image), `cloud-init/`.
- `scripts/`: `build-image.sh` (podman run + commit, no `podman build`), `gen-role-docs.py` (renders variable tables from argument specs), `github-rulesets.sh`.
- `docs/`: `architecture.md`, `roles.md` (variable tables generated), `testing.md`, `operations.md`. `docs/design/`: specs + plans. Gitignored, never committed.
- `.github/`: workflows (`ci`, `pr-policy`, `labels`, `release`), `rulesets/*.json`, `scripts/` (policy checks), templates, `CODEOWNERS`, `dependabot.yml` (Actions only). `renovate.json`: everything else.

## Build and test

Host needs only `podman`, `make`, `/dev/kvm`. Every tool runs in controller image (`make controller` builds it).

```sh
make lint            # yamllint --strict, ansible-lint (production), shellcheck, actionlint, zizmor
make docs            # render role docs from argument specs; CHECK=1 only verifies (CI)
make e2e             # boot Ubuntu cloud image in VM, run 1 (first_install) + run 2 (idempotent) + verify, ~5 min
make e2e KEEP=1      # keep VM: ssh -p 2222 root@127.0.0.1; remove with make e2e-clean
E2E_ZOMBIE_CHECK=1 make e2e   # adds 5 min wait + zombie assertion; CI always sets it
```

- Logs in `artifacts/e2e/` (gitignored). Cloud image cached in `.cache/images/`.
- Run `make lint`, `make docs CHECK=1`, `make e2e` before every push. Touched only docs: first two enough.
- Change role variable → edit `defaults/main.yml` AND `meta/argument_specs.yml`, run `make docs`, commit generated tables.
- `make run INVENTORY=... LIMIT=... TAGS=...` hits real hosts. Never run against hosts maintainer didn't name.

## Code rules

Source of truth: `path_instructions` in `.coderabbit.yaml`; CodeRabbit reviews every PR against it. Short:

- FQCN modules only. Every task named. `changed_when` on every `command`/`shell`.
- `no_log: true` on secret-bearing tasks.
- Variables prefixed by role name. Secrets are `vault_*`, aliased in role defaults.
- Every input declared in `meta/argument_specs.yml`.
- No hardcoded `become` in roles. Flags tested with `| bool`.
- Non-idempotent steps gated by `first_install`. Steps VM cannot run gated by `not e2e`.
- yamllint `--strict`, line length 120, `document-start` required. ansible-lint profile `production`, no `skip_list`, no `# noqa` without written reason.
- Shell: `set -eu` (`-o pipefail` in bash), pass shellcheck.
- Workflow files: actions pinned by full commit SHA + version comment, minimal permissions, `persist-credentials: false`, untrusted values via `env`. Validate with `make lint` (actionlint + zizmor).
- Code, comments, docs in English. No emoji, no em dashes.

## Secrets

- Secrets live in Ansible Vault (`vault.yml`), referenced as `vault_*`. Vault password in `.vault-pass` (gitignored) or prompt.
- Tasks handling secrets: `no_log: true`. Never print secret, or value derived from one, in debug, assert message, log.
- Never read or print `.vault-pass`, `vault.yml` contents, `.env`, keys. Test presence only. Edit vault via `make vault-edit`.
- e2e values (`tests/e2e/vault-pass`, root password) are throwaway. Never reuse for real hosts.

## Workflow

Every change follows these steps.

1. **Issue.** Search dupes (`gh issue list --search`). Open issue with right labels, assign self. Beyond small fix: need maintainer-approved design before code. Write spec + plan in `docs/design/`, wait for explicit yes.
2. **Branch.** From up-to-date `main`: `gh issue develop <n> --name <type>/<n>-slug --base main`, `<type>` one of `feat`, `fix`, `chore`. Slug lowercase, digits, hyphens. CI `branch` check rejects other names. Work in git worktree for that branch. Pick prefix right away: renaming PR head branch closes PR.
3. **Develop**, in English, strictly what issue asks: roles per code rules; docs (`README.md`, `docs/`, role README via `make docs`) when behaviour changes. Don't edit `CHANGELOG.md`: git-cliff writes it.
4. **Test**: `make lint`, `make docs CHECK=1`, `make e2e` (roles or harness touched). No warning, no skipped lint.
5. **Commit.** Conventional Commits, GPG-signed (`git commit -S`) only. No AI attribution, no `Co-Authored-By` trailers, no session links: check `git log --format=%B origin/main..HEAD` before each push. CI `commits` check enforces signature, subject, no attribution.
6. **Pull request.**
   - Sync from `main` by rebase (linear history), never merge.
   - Batch: push once per review round; each push costs rate-limited CodeRabbit review.
   - Title in Conventional Commits form (becomes squash commit subject), `Closes #<n>` in body, issue labels. Fill `.github/pull_request_template.md`.
   - English, no transcript, state which checks ran.
   - Diff in scope: no unrelated edits.
7. **Review and CI.** Wait for CodeRabbit + CI, then fix:
   - `main` ruleset requires 7 checks: `lint`, `docs`, `e2e`, `title`, `issue`, `branch`, `commits`. Missing check ≠ pass. Rulesets not enforced while repo private on Free plan: CI is the gate.
   - Gather all findings of round, verify each, fix all, rerun checks, push once, reply in each thread + resolve.
   - During rate limit, don't repeat `@coderabbitai review`: wait for window it names.
8. **Hand over.** All green + CodeRabbit approved → tag maintainer (`@nayrosk`) on PR. Agents never merge, tag, release, or publish unless maintainer asks. After merge: remove worktree, pull `main`.

## Release

Maintainer does it, or on their explicit request.

1. Branch `chore/release-vX.Y.Z`, PR labelled `release`, no issue needed.
2. `git cliff --tag vX.Y.Z -o CHANGELOG.md` (format in `cliff.toml`; or `make changelog`).
3. After squash merge, tag merge commit: `git tag -s vX.Y.Z -m vX.Y.Z && git push origin vX.Y.Z`.
4. Tag runs `release.yml`: GitHub release with git-cliff notes.

## Recommended plugins

`.claude/settings.json` registers marketplaces + enables plugins; Claude Code offers install when repo trusted.

- `superpowers` (`claude-plugins-official`): brainstorming, writing-plans, subagent-driven-development, TDD, systematic-debugging, verification. Use for every non-trivial change.
- `caveman`: terse output + `caveman-compress` for agent `.md` files. Keep agent files compressed.
- VoltAgent subagents (`voltagent-subagents`): `voltagent-qa-sec` (code, security review), `voltagent-dev-exp` (docs, build), `voltagent-infra` (CI, Docker).

## Writing

Docs, comments, commit messages, PR text: plain English, short sentences, imperative where fits. No em dashes, no marketing words, no filler openers or closing summaries.
