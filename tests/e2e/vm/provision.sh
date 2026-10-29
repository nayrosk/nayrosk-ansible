#!/bin/sh
# Provision the e2e VM host image: qemu/KVM and the tools run-vm.sh needs. Runs inside ubuntu:26.04
# with /provision mounted read-only. Driven by scripts/build-image.sh.
set -eu

export DEBIAN_FRONTEND=noninteractive

apt-get -o APT::Sandbox::User=root update
apt-get -o APT::Sandbox::User=root install -y --no-install-recommends \
  qemu-system-x86 qemu-utils genisoimage

rm -rf /var/lib/apt/lists/*
