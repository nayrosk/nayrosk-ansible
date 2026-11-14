# gpu_metrics_exporter

Runs the AMD Device Metrics Exporter (DME) as a rootful Podman quadlet and publishes its metrics through
Caddy. Used by `playbooks/install_rocm.yml` on hosts of the `gpu` group. It works on the inbox amdgpu driver
and does not need the `rocm` role.

## What it does

1. Fails with "Run playbooks/install_base.yml first." when `/etc/containers/systemd` or the operator
   `~/.caddy/routes.d` directory is missing.
2. Pulls `docker.io/rocm/device-metrics-exporter:v<gpu_metrics_exporter_version>`.
3. Writes `/etc/device-metrics-exporter/config.json`, mounted read-only at `/etc/metrics/config.json`, the
   path DME reads.
4. Installs the quadlet `/etc/containers/systemd/device-metrics-exporter.container`: privileged, with
   `/dev/dri`, `/dev/kfd` and `/sys` (read-only), published on `127.0.0.1:<gpu_metrics_exporter_listen_port>`.
   `HostName=` is set to the `hostname` inventory variable so the `hostname` label is the host name, not the
   container id.
5. Restarts the unit when the config or the quadlet changed, then starts it.
6. Installs the Caddy route `gpu_metrics` through the `route` entry point of `podman_monitoring`. Metrics are
   then served at `https://<host>/gpu_metrics`, behind the same basic auth as the other routes.

## Disabled fields

DME only accepts an allow-list in `GPUConfig.Fields` (see `docs/configuration/configmap.md` upstream). The
role renders every field of the pinned DME release minus `gpu_metrics_exporter_disabled_fields`. The default
drops the ECC and XGMI series, which read zero on Radeon. Set the list to `[]` to export everything. The
field list lives in `vars/main.yml`: review it when you change `gpu_metrics_exporter_version`, or fields
added by the new release stay off.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `gpu_metrics_exporter_version` | str | `1.5.3` | no | Image tag of `docker.io/rocm/device-metrics-exporter`, without the leading `v`. |
| `gpu_metrics_exporter_listen_port` | int | `5000` | no | Loopback port the exporter is published on. The container always listens on 5000. |
| `gpu_metrics_exporter_disabled_fields` | list of str | `[GPU_ECC_CORRECT_TOTAL, GPU_ECC_UNCORRECT_TOTAL, GPU_ECC_...` (76 entries, truncated, see `defaults/main.yml`) | no | GPUConfig fields excluded from the export, by their upstream names (for example `GPU_ECC_CORRECT_GFX`). The exporter only takes an allow-list, so the config file lists every known field except these. An empty list omits `Fields` and exports everything. |
| `gpu_metrics_exporter_operator_home` | str | `{{ operator_user_home \| default('/home/' ~ (operator_user...` (truncated, see `defaults/main.yml`) | no | Home directory of the operator account that runs Caddy. Follows the `operator_user` role variables. It is passed to the `podman_monitoring` route entry point as `podman_monitoring_user_home`. |
| `hostname` | str | none | yes | Hostname served by Caddy, also used as the `hostname` label of the GPU metrics. |
<!-- END VARIABLES -->
