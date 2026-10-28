# local_ca

Creates a local certificate authority and a server certificate, installs the CA in the system trust
store and fetches it to the controller.

## What it does

- Key material lives in `/etc/ssl/local-ca/`: `ca.key` and `server.key` (mode 0600), `ca.crt`,
  `server.crt` and the CSRs (mode 0644).
- The CA is an EC P-384 key with a self-signed certificate valid for 10 years. It is created only when
  absent, or when `local_ca_force_regenerate` is true.
- The server certificate is valid for 1 year. Its subject alternative names are the hostname, the
  local IP and the public IP. The local IP is `ansible_default_ipv4.address`, or
  `ansible_default_ipv6.address` on a host without IPv4. The public IP is chosen in this order:
  1. `local_ca_public_ip_override` when set (nothing is probed).
  2. The answer of `local_ca_public_ip_probe_url` (`https://ipv4.icanhazip.com`), asked from the target,
     when it is an IPv4 address. The probe is IPv4 only.
  3. The public IP already in the server certificate (its first IP address other than the local IP). A
     failed probe then keeps the certificate as it is instead of issuing it again.
  4. `ansible_host` when it is an IP address.
  5. None: the certificate only holds the hostname and the local IP.
- The certificate is issued again when the names change, when the CA changes or when less than 30 days
  remain. When the public IP really changes, the next run picks it up from the probe; set
  `local_ca_public_ip_override` when the probe cannot reach the internet.
- The CA certificate is copied to `/usr/local/share/ca-certificates/local-ca.crt` and
  `update-ca-certificates` runs when it changes.
- The CA certificate is fetched to `artifacts/<inventory_hostname>/ca.crt` on the controller.
- Facts set for later roles: `local_ca_local_ip` and `local_ca_public_ip` (empty when no public IP is known).

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `local_ca_force_regenerate` | bool | `false` | no | Regenerate the CA key and certificate, and therefore the server certificate. |
| `local_ca_directory` | path | `/etc/ssl/local-ca` | no | Directory holding the CA and server key material. |
| `local_ca_public_ip_override` | str | `""` | no | Public IP added to the server certificate. When set, the public IP is not probed. When empty, the target asks `local_ca_public_ip_probe_url` for its public IPv4 address. If the probe fails or does not answer an IPv4 address, the public IP already in the server certificate is kept, else `ansible_host` is used when it is an IP address, else no public IP is added. |
| `local_ca_public_ip_probe_url` | str | `https://ipv4.icanhazip.com` | no | URL answering the public IPv4 address of the target as plain text. |
| `hostname` | str | none | yes | Hostname added to the server certificate as a DNS name. |
<!-- END VARIABLES -->
