#!/bin/sh
# Provision the controller image. Runs inside python:3.13-slim with /provision mounted read-only
# (requirements.txt, requirements.yml). Driven by scripts/build-image.sh.
set -eu

ACTIONLINT_VERSION=1.7.12
ACTIONLINT_SHA256=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
GIT_CLIFF_VERSION=2.14.2
GIT_CLIFF_SHA256=fa21e2fc70046fcfd0e43e5e4613873ab799aff3d9dc8559c00d31b270e417d0

export PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1 DEBIAN_FRONTEND=noninteractive

apt-get -o APT::Sandbox::User=root update
apt-get -o APT::Sandbox::User=root install -y --no-install-recommends \
  openssh-client sshpass curl git make ca-certificates shellcheck

pip install -r /provision/requirements.txt
ansible-galaxy collection install -r /provision/requirements.yml -p /usr/share/ansible/collections

curl -fsSLo /tmp/actionlint.tar.gz \
  "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz"
echo "${ACTIONLINT_SHA256}  /tmp/actionlint.tar.gz" | sha256sum -c -
tar -xzf /tmp/actionlint.tar.gz -C /usr/local/bin actionlint
rm -f /tmp/actionlint.tar.gz

curl -fsSLo /tmp/git-cliff.tar.gz \
  "https://github.com/orhun/git-cliff/releases/download/v${GIT_CLIFF_VERSION}/git-cliff-${GIT_CLIFF_VERSION}-x86_64-unknown-linux-musl.tar.gz"
echo "${GIT_CLIFF_SHA256}  /tmp/git-cliff.tar.gz" | sha256sum -c -
tar -xzf /tmp/git-cliff.tar.gz -C /usr/local/bin --strip-components=1 "git-cliff-${GIT_CLIFF_VERSION}/git-cliff"
rm -f /tmp/git-cliff.tar.gz

rm -rf /var/lib/apt/lists/* /root/.cache /root/.ansible
