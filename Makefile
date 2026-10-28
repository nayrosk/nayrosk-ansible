# Every tool runs inside the controller image: the host needs only podman and make.
CONTROLLER_IMAGE ?= localhost/nayrosk-ansible-controller:dev
CONTROLLER_BASE  := docker.io/library/python:3.13-slim@sha256:aaf08c5490d52cd92bc27142a5215b1e47355a5eaf9adfad2a0fbc022d0b5490
CONTROLLER_RUN   := podman run --rm --userns=keep-id -v "$(CURDIR):/work:Z" -w /work $(CONTROLLER_IMAGE)
CONTROLLER_STAMP := .cache/controller.stamp

E2E_VM_IMAGE ?= localhost/nayrosk-ansible-e2e-vm:dev
E2E_VM_BASE  := docker.io/library/ubuntu:26.04@sha256:0e73b71479e7bc5f006bca872e25c3cd680dc052a0116f90d63ae363537db0dd
E2E_VM_STAMP := .cache/e2e-vm-image.stamp
KEEP         ?= 0

INVENTORY ?= inventories/example
LIMIT     ?=
TAGS      ?=
ARGS      ?=
VAULT_FILE ?= inventories/example/group_vars/all/vault.yml
CHECK     ?=

.DEFAULT_GOAL := help
.PHONY: help controller e2e-vm-image lint yamllint ansible-lint shellcheck actionlint zizmor run unit vault-edit e2e e2e-clean \
	docs changelog github-rulesets pre-commit-install

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

$(CONTROLLER_STAMP): tests/e2e/controller/provision.sh scripts/build-image.sh requirements.txt requirements.yml
	rm -rf .cache/controller-provision && mkdir -p .cache/controller-provision
	cp tests/e2e/controller/provision.sh requirements.txt requirements.yml .cache/controller-provision/
	scripts/build-image.sh $(CONTROLLER_BASE) "$(CURDIR)/.cache/controller-provision" $(CONTROLLER_IMAGE)
	@mkdir -p $(dir $@)
	@touch $@

controller: $(CONTROLLER_STAMP) ## Build the controller image (rebuilt when its inputs change)

$(E2E_VM_STAMP): tests/e2e/vm/provision.sh scripts/build-image.sh
	scripts/build-image.sh $(E2E_VM_BASE) "$(CURDIR)/tests/e2e/vm" $(E2E_VM_IMAGE)
	@mkdir -p $(dir $@)
	@touch $@

e2e-vm-image: $(E2E_VM_STAMP) ## Build the e2e VM host image (qemu/KVM)

lint: yamllint ansible-lint shellcheck actionlint zizmor ## Run all linters

yamllint: controller ## Run yamllint in strict mode
	$(CONTROLLER_RUN) yamllint --strict .

ansible-lint: controller ## Run ansible-lint (production profile)
	$(CONTROLLER_RUN) ansible-lint

shellcheck: controller ## Lint shell scripts
	$(CONTROLLER_RUN) shellcheck scripts/*.sh .github/scripts/*.sh tests/e2e/*.sh tests/e2e/*/*.sh

actionlint: controller ## Lint GitHub workflows (no-op without .github/workflows)
	@if [ -d .github/workflows ]; then $(CONTROLLER_RUN) actionlint; else echo "actionlint: no .github/workflows, skipped"; fi

zizmor: controller ## Audit GitHub workflows (no-op without .github/workflows)
	@if [ -d .github/workflows ]; then $(CONTROLLER_RUN) zizmor --offline .github; else echo "zizmor: no .github/workflows, skipped"; fi

# ~/.ssh is mounted read-only and never relabeled: a :Z or :z option would change the SELinux label of the
# real ~/.ssh. label=disable lets the container read it, and connect to the SSH agent socket, on SELinux
# hosts instead. The agent is forwarded when SSH_AUTH_SOCK points at a socket (needed for passphrase keys).
run: controller ## Run the playbook (INVENTORY=, LIMIT=, TAGS=)
	@if [ -f .vault-pass ]; then vault_opt="--vault-password-file .vault-pass"; else vault_opt="--ask-vault-pass"; fi; \
	if [ -n "$${SSH_AUTH_SOCK:-}" ] && [ -S "$${SSH_AUTH_SOCK}" ]; then \
		set -- -v "$${SSH_AUTH_SOCK}:/tmp/ssh-agent.sock" -e SSH_AUTH_SOCK=/tmp/ssh-agent.sock; else set --; fi; \
	podman run --rm -it --userns=keep-id --network host --security-opt label=disable -e HOME=/tmp "$$@" \
		-v "$(CURDIR):/work" -v "$$HOME/.ssh:/tmp/.ssh:ro" -w /work $(CONTROLLER_IMAGE) \
		ansible-playbook -i "$(INVENTORY)" $$vault_opt \
		$(if $(LIMIT),--limit "$(LIMIT)") $(if $(TAGS),--tags "$(TAGS)") playbooks/install_base.yml $(ARGS)

unit: controller ## Run the unit checks on the controller (no VM)
	$(CONTROLLER_RUN) ansible-playbook -i localhost, tests/unit/fail2ban_ignoreip.yml

vault-edit: controller ## Edit the inventory vault, creating it when missing (VAULT_FILE=)
	@if [ -f .vault-pass ]; then vault_opt="--vault-password-file .vault-pass"; else vault_opt="--ask-vault-pass"; fi; \
	if [ -f "$(VAULT_FILE)" ]; then action=edit; else action=create; fi; \
	podman run --rm -it --userns=keep-id -e HOME=/tmp -e EDITOR="$${EDITOR:-vi}" \
		-v "$(CURDIR):/work:Z" -w /work $(CONTROLLER_IMAGE) \
		ansible-vault $$action $$vault_opt "$(VAULT_FILE)"

e2e: controller e2e-vm-image ## Run the end-to-end test in a VM (KEEP=1 keeps the VM)
	CONTROLLER_IMAGE=$(CONTROLLER_IMAGE) VM_IMAGE=$(E2E_VM_IMAGE) KEEP=$(KEEP) tests/e2e/run.sh

e2e-clean: ## Remove the end-to-end VM container and its overlay disk
	tests/e2e/run.sh clean

docs: controller ## Render role documentation from argument specs (CHECK=1 only verifies)
	$(CONTROLLER_RUN) python3 scripts/gen-role-docs.py $(if $(CHECK),--check)

changelog: controller ## Generate CHANGELOG.md with git-cliff
	$(CONTROLLER_RUN) git-cliff --output CHANGELOG.md

github-rulesets: ## Apply .github/rulesets/*.json to the repository
	scripts/github-rulesets.sh

pre-commit-install: ## Install the git hooks (pre-commit, commit-msg)
	@command -v pre-commit >/dev/null 2>&1 || { echo "pre-commit not found: install it (pipx install pre-commit)"; exit 1; }
	pre-commit install --install-hooks --hook-type pre-commit --hook-type commit-msg
