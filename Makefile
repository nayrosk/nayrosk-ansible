# Every tool runs inside the controller image: the host needs only podman and make.
CONTROLLER_IMAGE ?= localhost/nayrosk-ansible-controller:dev
CONTROLLER_BASE  := docker.io/library/python:3.13-slim@sha256:aaf08c5490d52cd92bc27142a5215b1e47355a5eaf9adfad2a0fbc022d0b5490
CONTROLLER_RUN   := podman run --rm --userns=keep-id -v "$(CURDIR):/work:Z" -w /work $(CONTROLLER_IMAGE)
CONTROLLER_STAMP := .cache/controller.stamp

INVENTORY ?= inventories/example
LIMIT     ?=
TAGS      ?=

.DEFAULT_GOAL := help
.PHONY: help controller lint yamllint ansible-lint actionlint zizmor run vault-edit e2e e2e-clean docs \
	changelog github-rulesets pre-commit-install

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

$(CONTROLLER_STAMP): tests/e2e/controller/provision.sh scripts/build-image.sh requirements.txt requirements.yml
	rm -rf .cache/controller-provision && mkdir -p .cache/controller-provision
	cp tests/e2e/controller/provision.sh requirements.txt requirements.yml .cache/controller-provision/
	scripts/build-image.sh $(CONTROLLER_BASE) "$(CURDIR)/.cache/controller-provision" $(CONTROLLER_IMAGE)
	@mkdir -p $(dir $@)
	@touch $@

controller: $(CONTROLLER_STAMP) ## Build the controller image (rebuilt when its inputs change)

lint: yamllint ansible-lint actionlint zizmor ## Run all linters

yamllint: controller ## Run yamllint in strict mode
	$(CONTROLLER_RUN) yamllint --strict .

ansible-lint: controller ## Run ansible-lint (production profile)
	$(CONTROLLER_RUN) ansible-lint

actionlint: controller ## Lint GitHub workflows (no-op without .github/workflows)
	@if [ -d .github/workflows ]; then $(CONTROLLER_RUN) actionlint; else echo "actionlint: no .github/workflows, skipped"; fi

zizmor: controller ## Audit GitHub workflows (no-op without .github/workflows)
	@if [ -d .github/workflows ]; then $(CONTROLLER_RUN) zizmor --offline .github; else echo "zizmor: no .github/workflows, skipped"; fi

run: ## Run the playbook (INVENTORY=, LIMIT=, TAGS=)
	@echo "run: not implemented yet"; exit 1

vault-edit: ## Edit the inventory vault
	@echo "vault-edit: not implemented yet"; exit 1

e2e: ## Run the end-to-end test in a VM
	@echo "e2e: not implemented yet"; exit 1

e2e-clean: ## Remove end-to-end test artifacts
	@echo "e2e-clean: not implemented yet"; exit 1

docs: ## Render role documentation from argument specs
	@echo "docs: not implemented yet"; exit 1

changelog: ## Generate CHANGELOG.md with git-cliff
	@echo "changelog: not implemented yet"; exit 1

github-rulesets: ## Apply .github/rulesets/*.json to the repository
	@echo "github-rulesets: not implemented yet"; exit 1

pre-commit-install: ## Install the git hooks (pre-commit, commit-msg)
	@command -v pre-commit >/dev/null 2>&1 || { echo "pre-commit not found: install it (pipx install pre-commit)"; exit 1; }
	pre-commit install --install-hooks --hook-type pre-commit --hook-type commit-msg
