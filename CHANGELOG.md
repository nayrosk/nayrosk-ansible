# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0](https://github.com/nayrosk/nayrosk-ansible/compare/v0.1.0...v0.2.0) - 2026-11-16

### Added

- install a headless Obsidian behind Caddy ([#33](https://github.com/nayrosk/nayrosk-ansible/pull/33))
- *(podman_monitoring)* [**breaking**] default the Caddy basic auth user to operator ([#31](https://github.com/nayrosk/nayrosk-ansible/pull/31))
- install ROCm and the AMD GPU metrics exporter ([#28](https://github.com/nayrosk/nayrosk-ansible/pull/28))
- *(bootstrap_connection)* choose the bootstrap user and remove it after ([#22](https://github.com/nayrosk/nayrosk-ansible/pull/22))
- *(root_lock)* lock the root password after the operator gets sudo ([#11](https://github.com/nayrosk/nayrosk-ansible/pull/11))

### Fixed

- *(renovate)* scan tests/ again for the Galaxy collections ([#26](https://github.com/nayrosk/nayrosk-ansible/pull/26))
- controller ssh home and ubuntu_pro retries ([#21](https://github.com/nayrosk/nayrosk-ansible/pull/21))
- *(ci)* wait for udev before checking /dev/kvm ([#15](https://github.com/nayrosk/nayrosk-ansible/pull/15))

## [0.1.0](https://github.com/nayrosk/nayrosk-ansible/releases/tag/v0.1.0) - 2026-10-29

### Added

- bootstrap repository and install_base playbook ([#2](https://github.com/nayrosk/nayrosk-ansible/pull/2))

### Documentation

- state that the rulesets are enforced ([#7](https://github.com/nayrosk/nayrosk-ansible/pull/7))
