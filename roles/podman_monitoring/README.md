# podman_monitoring

Runs Prometheus node_exporter as a rootful podman quadlet and Caddy as a rootless quadlet of the operator
account. Caddy serves the node_exporter metrics over HTTPS with basic auth.

## What it does

- Installs `catatonit` (init for `RunInit=true`) and `passt` (pasta, rootless networking). Both are only
  recommended by Ubuntu's podman package.
- Pulls both images before the units start, so a slow pull never hits the systemd start timeout.
- node_exporter: `/etc/containers/systemd/node-exporter.container` (unit `node-exporter.service`, container
  `systemd-node-exporter`), host network and host PID namespace, listening on `127.0.0.1:9100` only,
  root filesystem mounted read-only, systemd collector over the system D-Bus socket. No init process:
  `--pid=host` forbids one and the host systemd reaps orphans.
- Caddy, as the operator: `~/.config/containers/systemd/{monitoring.network,caddy.container}` (unit
  `caddy.service` in the user manager, container `systemd-caddy`), publishing 80/tcp, 443/tcp and 443/udp
  through pasta. Files live in `~/.caddy/{config,data,certs,logs}` (0750, certs 0700). The server
  certificate and key are copied from `/etc/ssl/local-ca/` (0600).
- Caddyfile:
  - every `http://` request is redirected to `https://{host}{uri}` with 308;
  - the site answers on the hostname, the local IP, the public IP and
    `podman_monitoring_caddy_extra_site_addresses` (IPv6 addresses are bracketed), with the local_ca
    server certificate (no ACME: Caddy logs "skipping automatic certificate management" for each name);
  - basic auth on every route, `/node_exporter` proxied to node_exporter `/metrics`, every other path 404;
  - HSTS, `X-Content-Type-Options nosniff`, `Referrer-Policy no-referrer`;
  - JSON access log in `~/.caddy/logs/access.log` (read by the fail2ban `caddy-auth` jail);
  - health endpoint `http://127.0.0.1:8081/healthz`, bound to the container loopback, not published.
- The rendered Caddyfile is validated with `caddy validate` in the pinned Caddy image (no network) before it
  replaces the installed file: a broken template fails the task and the running configuration stays.
- Both containers have a healthcheck every 30s with `HealthOnFailure=kill` and `Restart=always`.
- A change to a quadlet, the Caddyfile, the certificates or `containers.conf` reloads systemd and restarts
  the matching unit. Quadlet units cannot be enabled: they start at boot through their `[Install]` section
  (`multi-user.target`, and `default.target` of the lingering user manager).

Operator-scoped tasks (`tasks/caddy.yml`, `tasks/caddy_start.yml`, `tasks/caddy_restart.yml`) are
included with the include vars `ansible_become: true` and `ansible_become_user: <operator>`, and set
`XDG_RUNTIME_DIR=/run/user/<uid>` and the matching `DBUS_SESSION_BUS_ADDRESS`. The `become` keyword is
not enough: `bootstrap_connection` sets `ansible_become` as a host fact (false when it connects as root),
and a fact outranks keywords and task vars, while include vars outrank facts. Without this, the first run
silently ran podman as root and `systemctl --user` failed with `Operation not permitted`. No
world-readable temporary files are needed: in operator mode the connection user is the become user, and
in root mode root hands the temporary files over with `chown`.

The role needs the facts of `local_ca` from the same play; run it with `--tags local_ca,podman_monitoring`
when filtering by tag.

## Decisions taken during implementation

### Reaching node_exporter on the host loopback (pasta)

Podman 5.7 on Ubuntu 26.04 starts pasta with `--map-guest-addr 169.254.1.2` and resolves
`host.containers.internal` to that address. pasta translates it to the host's routable address, not to
the loopback: from a rootless container on a bridge network, `host.containers.internal:9100` is refused
while node_exporter listens on `127.0.0.1:9100` (probed in the e2e VM).

The role writes `~/.config/containers/containers.conf` for the operator:

```toml
[containers]
host_containers_internal_ip = "169.254.1.3"

[network]
pasta_options = ["--map-host-loopback", "169.254.1.3"]
```

pasta then delivers connections to `169.254.1.3` on the host loopback, and `host.containers.internal`
resolves to it, so the Caddyfile keeps `reverse_proxy host.containers.internal:9100` and node_exporter
stays on the loopback, out of reach of the network whatever the firewall state.

Trade-off: every rootless container of the operator can reach every service listening on the host
loopback. The operator already has full sudo, so this grants nothing to the account; it widens what a
compromised Caddy process can reach.

The fallback of the design (a dummy interface `nexp0` with `169.254.200.1/32` for node_exporter and an
`AddHost` entry in Caddy) was not needed. It would have moved node_exporter off the loopback, relying on
UFW to filter it.

### AppArmor and the systemd collector

Podman's default AppArmor profile (`containers-default`) denies D-Bus method calls, so the systemd
collector fails with `An AppArmor policy prevents this sender from sending this message` and
`node_systemd_unit_state` is missing. node_exporter runs with `--security-opt=apparmor=unconfined`. It
already shares the host PID and network namespaces and only gets a read-only view of the root
filesystem.

### Caddy access log

The site uses its own `log` block writing JSON to `/logs/access.log`. Global options set `admin off` and
`skip_install_trust` (the container has no use for Caddy's internal CA in its trust store).

### Known noise

On Ubuntu 26.04 the `pasta` AppArmor profile refuses `SIGTERM` from the `podman` profile, so stopping the
Caddy container logs `rootless netns: kill network process: permission denied`. pasta exits on its own
when the rootless network namespace goes away: restarts do not leave pasta processes behind and the
ports come back.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `podman_monitoring_caddy_version` | str | `2.11.7` | Caddy image tag (`docker.io/library/caddy:<version>-alpine`). |
| `podman_monitoring_node_exporter_version` | str | `1.12.1` | node_exporter image tag (`quay.io/prometheus/node-exporter:v<version>`). |
| `podman_monitoring_node_exporter_listen` | str | `127.0.0.1:9100` | Address and port node_exporter listens on. |
| `podman_monitoring_caddy_basic_auth_user` | str | `admin` | Basic auth user protecting every Caddy route. |
| `podman_monitoring_caddy_basic_auth_hash` | str | `{{ vault_caddy_basic_auth_hash }}` | Bcrypt hash of the basic auth password, as printed by `caddy hash-password`. Defaults to the vault variable `vault_caddy_basic_auth_hash`, which must then be set. |
| `podman_monitoring_caddy_extra_site_addresses` | list of str | `[]` | Site addresses served by Caddy in addition to the hostname, the local IP and the public IP. |
| `podman_monitoring_host_loopback_ip` | str | `169.254.1.3` | Link-local address that pasta maps to the host loopback in the operator's rootless containers. `host.containers.internal` resolves to it. It must differ from podman's own `169.254.1.2`. |
| `podman_monitoring_user` | str | `{{ operator_user_name }}` | Rootless account running Caddy. Defaults to the operator_user role account. |
| `podman_monitoring_user_uid` | int | `{{ operator_user_uid }}` | Numeric id of `podman_monitoring_user`. |
| `podman_monitoring_user_home` | str | `{{ operator_user_home }}` | Home directory of `podman_monitoring_user`. |
| `podman_monitoring_cert_source_directory` | path | `{{ local_ca_directory }}` | Directory holding `server.crt` and `server.key`. Defaults to the local_ca role directory. |
| `hostname` | str | none (required) | Hostname served by Caddy, also the first name of the server certificate. |
<!-- END VARIABLES -->
