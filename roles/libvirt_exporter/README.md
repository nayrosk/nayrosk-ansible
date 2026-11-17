# libvirt_exporter

Runs the [inovex Prometheus libvirt exporter](https://github.com/inovex/prometheus-libvirt-exporter) as a rootful
Podman quadlet and publishes its metrics through Caddy. Used by `playbooks/install_libvirt.yml` on hosts of the
`libvirt` group, after the `libvirt` role.

## What it does

1. Fails with a message naming `playbooks/install_base.yml` and the `libvirt` role when
   `/etc/containers/systemd`, the operator `~/.caddy/routes.d` directory or the read-only libvirt socket is
   missing.
2. Pulls `ghcr.io/inovex/prometheus-libvirt-exporter:v<libvirt_exporter_version>`.
3. Installs the quadlet `/etc/containers/systemd/libvirt-exporter.container`: not privileged, with only the
   read-only libvirt socket mounted, published on `127.0.0.1:<libvirt_exporter_listen_port>`. The unit
   requires `libvirtd.socket`. The image has no shell, so the quadlet has no health check; `Restart=always`
   covers a crash.
4. Restarts the unit when the quadlet changed, then starts it.
5. Installs the Caddy route `libvirt_metrics` through the `route` entry point of `podman_monitoring`. Metrics are
   then served at `https://<host>/libvirt_metrics`, behind the same basic auth as the other routes.

The metrics cover the exporter itself (`libvirt_up`), each domain (state, vCPU, memory, block and network
devices) and the storage pools.

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `libvirt_exporter_version` | str | pinned in `defaults/main.yml` | no | Image tag of `ghcr.io/inovex/prometheus-libvirt-exporter`, without the leading `v`. |
| `libvirt_exporter_listen_port` | int | `9177` | no | Loopback port the exporter is published on. The container always listens on 9177. |
| `libvirt_exporter_operator_home` | str | `{{ operator_user_home \| default('/home/' ~ (operator_user...` (truncated, see `defaults/main.yml`) | no | Home directory of the operator account that runs Caddy, where the route snippet goes. |
<!-- END VARIABLES -->
