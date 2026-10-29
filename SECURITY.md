# Security policy

## Supported versions

Only the latest release receives security fixes.

## Reporting a vulnerability

Report vulnerabilities privately through the [private reporting form](https://github.com/nayrosk/nayrosk-ansible/security/advisories/new). Do not open a public issue, pull request or discussion for them.

Include what you can of:

- the affected version or commit
- the role, task or variable involved
- the steps that reproduce the problem
- the impact you observed or expect

Leave real passwords, vault contents, keys and hostnames out of the report.

## What to expect

- An acknowledgement within 7 days.
- A first assessment within 14 days, saying whether the report is accepted.
- For an accepted report, a fix in a new release, then a published GitHub security advisory that credits you unless you ask otherwise.

## Scope

In scope:

- leaks of secrets (vault values, the Caddy basic auth hash, private keys) to output, logs, files with loose permissions or commits
- a role that leaves a host less hardened than documented: SSH, firewall, fail2ban, DNS over TLS, sysctl, user accounts
- command injection through variables, templates or inventory content
- unsafe defaults in the Podman quadlets (Caddy, node_exporter)

Out of scope:

- vulnerabilities in Ubuntu, Podman, Caddy, node_exporter or other upstream software
- behavior that requires an attacker to already control the controller or the target host
- the throwaway credentials in `tests/e2e/`, which only protect a disposable test VM
