# hostname

Sets the system hostname with systemd and keeps exactly one `127.0.1.1 <hostname>` line in
`/etc/hosts`. When `/etc/cloud` exists it also writes `/etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg`
with `preserve_hostname: true`, so cloud-init does not reset the name on reboot.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `hostname` | str | none (required) | Hostname to set. Also used as a DNS name in the server certificate. |
<!-- END VARIABLES -->
