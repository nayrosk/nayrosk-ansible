# dns

Enforces DNS over TLS with systemd-resolved.

## What it does

- Writes `/etc/systemd/resolved.conf.d/10-dns.conf` (directory 0755, file 0644) with `DNS=` built from
  `dns_servers`, each suffixed with `#<dns_tls_server_name>`, an empty `FallbackDNS=`, `DNSOverTLS=yes`
  and `Domains=~.`.
- The catch-all routing domain `~.` makes the global servers win over DHCP-provided servers for every
  name. Netplan and cloud-init are not modified.
- Restarts `systemd-resolved` in a handler, flushes handlers, then fails unless `resolvectl status`
  shows `+DNSOverTLS` and every configured server, and `getent hosts ubuntu.com` resolves.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `dns_servers` | list of str | `[1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::...` (4 entries, truncated, see `defaults/main.yml`) | no | Resolvers used for every domain, queried over TLS. |
| `dns_tls_server_name` | str | `cloudflare-dns.com` | no | TLS server name presented by the resolvers. |
<!-- END VARIABLES -->
