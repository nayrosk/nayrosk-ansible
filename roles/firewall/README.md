# firewall

Enables UFW with a default deny policy and the SSH and Caddy rules.

## What it does

- Sets the defaults: deny incoming, allow outgoing (routed policy left at the UFW default).
- Applies `firewall_rules` in order (`OpenSSH`, `80/tcp`, `443/tcp`, `443/udp`, each with a comment).
- Sets `log_martians=1` in `/etc/ufw/sysctl.conf`: UFW applies that file at every start and ships `0`, which
  would undo the `system` role sysctl value.
- Enables UFW last, after the SSH rule exists, so the current SSH session is never cut. IPv6 stays enabled.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `firewall_rules` | list of dict | `[{rule: allow, name: OpenSSH, comment: OpenSSH}, {rule: a...` (4 entries, truncated, see `defaults/main.yml`) | no | UFW rules, applied in order. Each item takes the options of `community.general.ufw` (`rule`, `name` or `port`, `proto`, `comment`). |
<!-- END VARIABLES -->
