# opencode_route

Publishes the opencode server of the operator behind the rootless Caddy, at `https://<host>/opencode/`. Used by
`playbooks/install_opencode_route.yml` on hosts of the `opencode` group. opencode itself is installed and run
by hand: this role only adds the route.

## What it does

1. Fails when `opencode_route_path` does not match `^/[a-z0-9_-]+$` or `opencode_route_port` is not a TCP port.
2. Fails when `<opencode_route_path>/*` is missing from `podman_monitoring_caddy_basic_auth_skip_paths`.
   opencode checks its own HTTP basic auth (user `opencode`) on every API request, and a request carries one
   `Authorization` header, so the Caddy basic auth must skip the route.
3. Fails with "Run playbooks/install_base.yml first." when the operator `~/.caddy/routes.d` directory is
   missing, and when the installed Caddyfile does not skip the basic auth for the route yet.
4. Installs the Caddy route `opencode` through the `route` entry point of `podman_monitoring`. Caddy strips the
   prefix and proxies to `host.containers.internal:<opencode_route_port>`, which pasta maps to the host
   loopback.

Caddy still logs the 401 answers of opencode, so the fail2ban `caddy-auth` jail bans password guesses on the
route too. See [operations](../../docs/operations.md#opencode) for the opencode side and the clients.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `opencode_route_path` | str | `/opencode` | no | Path prefix of the route. Must match `^/[a-z0-9_-]+$`. |
| `opencode_route_port` | int | `4096` | no | Loopback port opencode listens on (`opencode serve --hostname 127.0.0.1 --port <port>`). |
| `opencode_route_caddy_user_home` | str | `{{ operator_user_home \| default('/home/' ~ (operator_user...` (truncated, see `defaults/main.yml`) | no | Home directory of the operator account that runs Caddy. It is passed to the `podman_monitoring` route entry point as `podman_monitoring_user_home`. When the inventory overrides `podman_monitoring_user_home`, set this variable to the same value. |
<!-- END VARIABLES -->
