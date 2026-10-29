# fail2ban

Bans repeated SSH and Caddy authentication failures through UFW.

## What it does

- Makes sure the Caddy access log exists (owned by `fail2ban_caddy_log_owner`, the `podman_monitoring_user`,
  mode 0640, timestamps preserved), because fail2ban refuses a jail whose log file is missing. The path
  follows `podman_monitoring_user_home`.
- Installs `/etc/fail2ban/filter.d/caddy-auth.conf`: matches HTTP 401 lines of the Caddy JSON log only when
  the request carried credentials (Caddy logs the `Authorization` header as `["REDACTED"]`), client address
  from `remote_ip`. The credential-less 401 that every browser gets first (the basic auth challenge) does
  not count, so a user who types the right password is never banned for it. A client that never sends
  credentials is not banned by this jail.
- Installs `/etc/fail2ban/jail.d/10-install-base.local`: ban action `ufw`, jails `sshd` (systemd backend)
  and `caddy-auth`.
- `ignoreip`: `127.0.0.1/8`, `::1`, `fe80::/10`, the detected LAN networks and `fail2ban_ignoreip_extra`.
  The detected networks are the network of the default IPv4 route and the network (not the host address)
  of the default IPv6 route, each only when the host has one. They are added only when they are private:
  `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `100.64.0.0/10` or `fc00::/7`. A public subnet of a
  hosting provider is not a LAN: add it to `fail2ban_ignoreip_extra` if you really want it. The check is
  plain Jinja arithmetic in `tasks/ignoreip.yml` (no `ansible.utils` dependency), covered by
  `tests/unit/fail2ban_ignoreip.yml` (`make unit`).
- Restarts fail2ban on configuration changes; keeps the service enabled and running.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `fail2ban_bantime` | str | `1h` | no | Ban duration. |
| `fail2ban_findtime` | str | `10m` | no | Window in which `fail2ban_maxretry` failures trigger a ban. |
| `fail2ban_maxretry` | int | `3` | no | Failures allowed inside the find window before a ban. |
| `fail2ban_ignoreip_extra` | list of str | `[]` | no | Extra addresses or networks never banned, public ones included. |
| `fail2ban_caddy_log_owner` | str | `{{ podman_monitoring_user \| default(operator_user_name \|...` (truncated, see `defaults/main.yml`) | no | Account running Caddy, owner and group of the access log created when missing. |
| `fail2ban_caddy_log` | str | `{{ podman_monitoring_user_home \| default(operator_user_ho...` (truncated, see `defaults/main.yml`) | no | Caddy JSON access log watched by the `caddy-auth` jail. |
<!-- END VARIABLES -->
