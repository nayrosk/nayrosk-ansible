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
- Caddy, as the operator: `~/.config/containers/systemd/caddy.container` (unit `caddy.service` in the
  user manager, container `systemd-caddy`) on its own pasta network, publishing 80/tcp, 443/tcp and
  443/udp through pasta, which keeps client source addresses (see "Networking" below). Files live in `~/.caddy/{config,data,certs,logs}` (0750, certs 0700). The server
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
- The rootless network `monitoring` (`~/.config/containers/systemd/monitoring.network`, unit
  `monitoring-network.service`) is created and started, for future rootless services. Caddy is not on it
  yet (see "Networking").
- A change to a quadlet, the Caddyfile or the certificates reloads systemd and restarts the matching
  unit. Quadlet units cannot be enabled: they start at boot through their `[Install]` section
  (`multi-user.target`, and `default.target` of the lingering user manager).

Operator-scoped tasks (`tasks/caddy.yml`, `tasks/caddy_start.yml`, `tasks/user_unit_restart.yml`) are
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

### Networking: pasta for Caddy, monitoring network kept for later

Caddy runs with `Network=pasta:--map-host-loopback,<podman_monitoring_host_loopback_ip>`, not on the
`monitoring` bridge network of the design:

- Client source addresses. On a rootless bridge network, podman 5.7 publishes ports with `rootlessport`,
  a user-space proxy: Caddy logged `remote_ip` `10.89.0.2` (its own container address) for every client,
  which would make the fail2ban `caddy-auth` jail useless. pasta forwards the ports itself and keeps the
  client address. In e2e that is the controller host's own LAN address (for example `192.168.1.41`): the
  rootless port forward of the VM container and qemu user networking both keep non-loopback sources, so
  it is not the slirp gateway `10.0.2.2`. Podman 5.7 has no `rootless_port_forwarder = "pasta"` setting for bridge networks.
- The `monitoring` network is still created for future rootless services. Caddy rejoins it once
  Podman >= 6 with `rootless_port_forwarder = "pasta"` is available on the target.
- UFW and fail2ban apply to the published ports: pasta listens on the host like any process.

Reaching node_exporter on the host loopback: by default podman starts pasta with `--map-guest-addr
169.254.1.2` and resolves `host.containers.internal` to that address, which pasta translates to the
host's routable address, not to the loopback, so `host.containers.internal:9100` is refused while
node_exporter listens on `127.0.0.1:9100` (probed in the e2e VM). The Caddy quadlet adds
`--map-host-loopback 169.254.1.3` to its own pasta instance and
`AddHost=host.containers.internal:169.254.1.3`. Connections from Caddy to `169.254.1.3` land on the host
loopback, the Caddyfile keeps `reverse_proxy host.containers.internal:9100`, and node_exporter stays on
the loopback, out of reach of the network whatever the firewall state. The mapping is scoped to the
Caddy container: other rootless containers of the operator do not get it. An earlier version set it
operator-wide in `~/.config/containers/containers.conf`; the role removes that file.

`podman_monitoring_node_exporter_listen` must therefore stay a loopback address.

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

On Ubuntu 26.04 the `pasta` AppArmor profile refuses `SIGTERM` from the `podman` profile. While Caddy sat
on the `monitoring` bridge, stopping it logged `rootless netns: kill network process: permission denied`
(the shared rootless network namespace). With its own pasta instance a Caddy restart logs no such error
and leaves a single pasta process. Containers that later join the `monitoring` network may log it again;
it is harmless.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `podman_monitoring_caddy_version` | str | `2.11.7` | no | Caddy image tag (`docker.io/library/caddy:<version>-alpine`). |
| `podman_monitoring_node_exporter_version` | str | `1.12.1` | no | node_exporter image tag (`quay.io/prometheus/node-exporter:v<version>`). |
| `podman_monitoring_node_exporter_listen` | str | `127.0.0.1:9100` | no | Address and port node_exporter listens on. Must stay a loopback address. Caddy proxies to `host.containers.internal`, which pasta maps to the host loopback only. |
| `podman_monitoring_caddy_basic_auth_user` | str | `admin` | no | Basic auth user protecting every Caddy route. |
| `podman_monitoring_caddy_basic_auth_hash` | str | secret | no | Bcrypt hash of the basic auth password, as printed by `caddy hash-password`. Defaults to the vault variable `vault_caddy_basic_auth_hash`, which must then be set. |
| `podman_monitoring_caddy_extra_site_addresses` | list of str | `[]` | no | Site addresses served by Caddy in addition to the hostname, the local IP and the public IP. |
| `podman_monitoring_host_loopback_ip` | str | `169.254.1.3` | no | Link-local address that the pasta instance of the Caddy container maps to the host loopback. `host.containers.internal` resolves to it inside Caddy. It must differ from podman's own `169.254.1.2`. |
| `podman_monitoring_user` | str | `{{ operator_user_name }}` | no | Rootless account running Caddy. Defaults to the operator_user role account. |
| `podman_monitoring_user_uid` | int | `{{ operator_user_uid }}` | no | Numeric id of `podman_monitoring_user`. |
| `podman_monitoring_user_home` | str | `{{ operator_user_home }}` | no | Home directory of `podman_monitoring_user`. |
| `podman_monitoring_cert_source_directory` | path | `{{ local_ca_directory }}` | no | Directory holding `server.crt` and `server.key`. Defaults to the local_ca role directory. |
| `hostname` | str | none | yes | Hostname served by Caddy, also the first name of the server certificate. |
<!-- END VARIABLES -->
