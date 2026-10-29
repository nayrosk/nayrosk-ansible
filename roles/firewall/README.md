# firewall

Enables UFW with a default deny policy and the SSH and Caddy rules.

## What it does

- Sets the defaults: deny incoming, allow outgoing (routed policy left at the UFW default).
- Applies the fixed rules, always: `OpenSSH` (comment `OpenSSH`), `80/tcp` (`Caddy HTTP`), `443/tcp`
  (`Caddy HTTPS`) and `443/udp` (`Caddy HTTP/3`). They are `firewall_fixed_rules` in `vars/main.yml`, so an
  inventory cannot remove the SSH rule by mistake. Removing one needs a change to the role.
- Applies `firewall_rules_extra` after them, in order (empty by default).
- Sets `log_martians=1` in `/etc/ufw/sysctl.conf`: UFW applies that file at every start and ships `0`, which
  would undo the `system` role sysctl value.
- Checks with `ufw show added` that the OpenSSH rule exists, then enables UFW last, so the current SSH session
  is never cut. IPv6 stays enabled.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `firewall_rules_extra` | list of dict | `[]` | no | Additional UFW rules, applied in order after the fixed rules. Each item takes the options of `community.general.ufw` (`rule`, `name` or `port`, `proto`, `from_ip`, `to_ip`, `direction`, `comment`). |
<!-- END VARIABLES -->
