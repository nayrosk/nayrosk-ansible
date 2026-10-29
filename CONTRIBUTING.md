# Contributing

Thanks for helping. This guide covers how work flows from an idea to `main`.

Using a coding agent? Point it at [CLAUDE.md](CLAUDE.md), which holds the project rules and workflow for agents.

Report vulnerabilities privately as described in the [security policy](SECURITY.md).

## Setup

The host needs only `podman`, `make` and `/dev/kvm`. Every tool runs inside a controller container that `make controller` builds on first use.

```sh
make lint            # yamllint, ansible-lint, shellcheck, actionlint, zizmor
make unit            # unit checks on the controller, no VM
make docs CHECK=1    # fails when the generated role documentation is stale
make e2e             # boots an Ubuntu 26.04 VM and runs the playbook twice, about 5 minutes
```

Optional: `make pre-commit-install` installs hooks that check commit messages and run the linters.

## Workflow

Every change goes issue, branch, pull request. Nobody pushes to `main` directly, the maintainer included.

1. **Issue.** Open one with the [issue forms](https://github.com/nayrosk/nayrosk-ansible/issues/new/choose), or comment on an existing one to say you are taking it. Wait for agreement on the approach before large changes.
2. **Branch.** Create the branch from the issue so GitHub links them:

   ```sh
   gh issue develop 42 --name feat/42-short-description --base main --checkout
   ```

   Branch names are `feat/`, `fix/` or `chore/`, then the issue number, then lowercase words joined by hyphens. CI rejects other names.
3. **Pull request.** Open it against `main` with the template. The description must close the issue (`Closes #42`), and the title must be a Conventional Commit because it becomes the commit subject on `main`.
4. **Review.** CI and CodeRabbit run on the pull request. Every check must pass and every review conversation must be resolved before merging.
5. **Merge.** Pull requests are squash merged, which closes the issue and deletes the branch.

Dependency update pull requests and release pull requests (`chore/release-vX.Y.Z`) do not need an issue.

The repository is private on the GitHub Free plan, so the rulesets in `.github/rulesets/` are stored but not enforced. The CI checks `lint`, `docs`, `e2e`, `title`, `issue`, `branch` and `commits` are the gate. The maintainer applies the rulesets with `make github-rulesets`.

## Commits

- Commits follow [Conventional Commits](https://www.conventionalcommits.org): `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore` or `revert`, with an optional scope, for example `fix(dns): keep the fallback resolver`. CI checks every commit subject.
- Every commit must be signed. Set up [GPG, SSH or S/MIME signing](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification) and turn it on with `git config commit.gpgsign true`. CI rejects unverified commits.
- `main` moves on while a pull request is open: rebase the branch on it. The commit check ignores merge commits, and the squash drops them.

## Code

- Use fully qualified module names and give every task a name.
- Give every `command` and `shell` task an explicit `changed_when`, and `no_log: true` on tasks that handle secrets.
- Prefix variables with the role name. Keep secrets in the Ansible Vault as `vault_*` variables.
- Declare every role input in `meta/argument_specs.yml`, then run `make docs` and commit the regenerated tables.
- Gate non-idempotent steps with `first_install` and steps the test VM cannot run with `not e2e`.
- Code, comments and documentation are in English, without emoji or em dashes.
- Do not edit `CHANGELOG.md`; git-cliff writes it.

## Dependencies

Dependabot updates GitHub Actions. Renovate updates the Python and Galaxy requirements, the Caddy and node_exporter versions and the base image digests, and waits 7 days after a release. Install the Renovate GitHub App on the repository to enable it.

Three pins are updated by hand because they come with a checksum:

- the cloud image: change `CLOUD_IMAGE_URL` and `CLOUD_IMAGE_SHA256` in `tests/e2e/run.sh` together;
- `GIT_CLIFF_VERSION` and `ACTIONLINT_VERSION` with their SHA256 in `tests/e2e/controller/provision.sh`.

## Labels

Issues get a type label (`bug`, `enhancement`, `documentation`, ...) and, when relevant, an `area:` label. New issues start with `triage`. Labels are defined in [.github/labels.yml](.github/labels.yml) and synced when that file changes on `main`.

## Releases

Releases are cut by the maintainer: a `chore/release-vX.Y.Z` pull request with the changelog from `git cliff --tag vX.Y.Z -o CHANGELOG.md`, then a signed tag `vX.Y.Z` on the merge commit. The tag runs the release workflow, which creates the GitHub release.
