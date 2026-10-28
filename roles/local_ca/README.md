# local_ca

Creates a local certificate authority and a server certificate, installs the CA in the system trust
store and fetches it to the controller.

## What it does

- Key material lives in `/etc/ssl/local-ca/`: `ca.key` and `server.key` (mode 0600), `ca.crt`,
  `server.crt` and the CSRs (mode 0644).
- The CA is an EC P-384 key with a self-signed certificate valid for 10 years. It is created only when
  absent, or when `local_ca_force_regenerate` is true.
- The server certificate is valid for 1 year. Its subject alternative names are the hostname, the
  local IP (`ansible_default_ipv4.address`) and the public IP. The public IP is read from
  `https://ifconfig.co/ip` on the target and falls back to `ansible_host`. The certificate is issued
  again when the names change, when the CA changes or when less than 30 days remain.
- The CA certificate is copied to `/usr/local/share/ca-certificates/local-ca.crt` and
  `update-ca-certificates` runs when it changes.
- The CA certificate is fetched to `artifacts/<inventory_hostname>/ca.crt` on the controller.
- Facts set for later roles: `local_ca_local_ip` and `local_ca_public_ip`.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `local_ca_force_regenerate` | bool | `false` | Regenerate the CA key and certificate, and therefore the server certificate. |
| `local_ca_directory` | path | `/etc/ssl/local-ca` | Directory holding the CA and server key material. |
| `hostname` | str | none (required) | Hostname added to the server certificate as a DNS name. |
<!-- END VARIABLES -->
