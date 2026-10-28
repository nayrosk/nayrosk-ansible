# fail2ban

Bans repeated SSH and Caddy authentication failures through UFW.

## What it does

- Makes sure the Caddy access log exists (owned by the operator, mode 0640, timestamps preserved), because
  fail2ban refuses a jail whose log file is missing.
- Installs `/etc/fail2ban/filter.d/caddy-auth.conf`: matches HTTP 401 lines of the Caddy JSON log, client
  address from `remote_ip`, in either field order.
- Installs `/etc/fail2ban/jail.d/10-install-base.local`: ban action `ufw`, jails `sshd` (systemd backend)
  and `caddy-auth`.
- `ignoreip`: loopback, the detected LAN IPv4 network, the LAN IPv6 prefix when the host has one,
  `fe80::/10` and `fail2ban_ignoreip_extra`.
- Restarts fail2ban on configuration changes; keeps the service enabled and running.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `fail2ban_bantime` | str | `1h` | no | Ban duration. |
| `fail2ban_findtime` | str | `10m` | no | Window in which `fail2ban_maxretry` failures trigger a ban. |
| `fail2ban_maxretry` | int | `3` | no | Failures allowed inside the find window before a ban. |
| `fail2ban_ignoreip_extra` | list of str | `[]` | no | Extra addresses or networks never banned, added to the detected ones. |
| `fail2ban_caddy_log` | str | `/home/{{ operator_user_name }}/.caddy/logs/access.log` | no | Caddy JSON access log watched by the `caddy-auth` jail. |
<!-- END VARIABLES -->
