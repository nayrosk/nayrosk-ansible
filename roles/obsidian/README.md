# obsidian

Runs a headless Obsidian as a rootless Podman quadlet of the operator account, publishes its web interface
through Caddy and exposes the Local REST API of the vault on the host loopback. Used by
`playbooks/install_obsidian.yml` on hosts of the `obsidian` group.

## What it does

1. Fails with "Run playbooks/install_base.yml first." when the operator quadlet directory or the operator
   `~/.caddy/routes.d` directory is missing.
2. Fails before any change when `obsidian_api_key` is missing, not a string or shorter than 32 characters. The
   message names `vault_obsidian_api_key` and never shows the key.
3. As the operator: creates `~/.obsidian-app/config` (application state) and
   `~/.obsidian-app/vaults/<obsidian_vault_name>` (the vault), pulls
   `lscr.io/linuxserver/obsidian:v<obsidian_version>`, and downloads the Local REST API plugin release into the
   vault, verified by SHA256.
4. Merges its keys into three JSON files and leaves every other key alone, because Obsidian and the plugin write
   these files too:
   - the plugin `data.json`: the API key, HTTP server on port 27123, HTTPS server off;
   - `community-plugins.json` of the vault: the plugin id;
   - `obsidian.json` of the application: the vault opened at start, the command line client enabled,
     self-update disabled so the pinned image decides the version.
5. Installs the quadlet `~/.config/containers/systemd/obsidian.container`: web interface on
   `127.0.0.1:<obsidian_web_port>`, REST API on `127.0.0.1:<obsidian_rest_api_port>`, `SUBFOLDER=/obsidian/`,
   `PUID=0` and `PGID=0` so the files belong to the operator on the host.
6. Restarts the unit when a managed file changed, then starts it and waits for the web interface.
7. Disables the restricted mode of the vault with the Obsidian command line client when it reads `on`, so the
   plugin loads. Then waits for the REST API and checks it accepts the key, restarting Obsidian once if the
   plugin still holds an old key.
8. Installs the Caddy route `obsidian` through the `route` entry point of `podman_monitoring`. The interface is
   then served at `https://<host>/obsidian/`, behind the same basic auth as the other routes. The REST API has
   no route.

See [operations](../../docs/operations.md#obsidian) for the key, upgrades and the known limits.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `obsidian_version` | str | `1.15.0-ls152` | no | Image tag of `lscr.io/linuxserver/obsidian`, without the leading `v`. |
| `obsidian_rest_api_version` | str | `5.5.2` | no | Release of the Local REST API plugin (`coddingtonbear/obsidian-local-rest-api`). |
| `obsidian_rest_api_checksums` | dict | `{main.js: sha256:90494b6444c5fede5d12f97346aab839265b5c7a...` (3 entries, truncated, see `defaults/main.yml`) | no | Checksums of the plugin release assets `main.js`, `manifest.json` and `styles.css`, in the `sha256:<hex>` form. Update them together with `obsidian_rest_api_version`. |
| `obsidian_web_port` | int | `3000` | no | Loopback port the web interface is published on. The container always listens on 3000. |
| `obsidian_rest_api_port` | int | `27123` | no | Loopback port the Local REST API is published on. The plugin always listens on 27123. |
| `obsidian_vault_name` | str | `vault` | no | Directory name of the vault, under `~/.obsidian-app/vaults` of `obsidian_user`. |
| `obsidian_api_key` | str | secret | yes | API key of the Local REST API, sent by clients as `Authorization` bearer token. At least 32 characters. The role default aliases the vault variable `vault_obsidian_api_key`. The spec holds no default, so an inventory that sets `obsidian_api_key` itself does not need the vault variable. |
| `obsidian_timezone` | str | `Etc/UTC` | no | Time zone of the container. |
| `obsidian_user` | str | `{{ operator_user_name \| default('operator') }}` | no | Rootless account running Obsidian. Defaults to the operator_user role account. Falls back to `operator` when the operator_user role did not run in the play. |
| `obsidian_user_uid` | int | `{{ operator_user_uid \| default(10000) }}` | no | Numeric id of `obsidian_user`, used to build `XDG_RUNTIME_DIR`. |
| `obsidian_user_home` | str | `{{ operator_user_home \| default('/home/' ~ obsidian_user) }}` | no | Home directory of `obsidian_user`. It is passed to the `podman_monitoring` route entry point as `podman_monitoring_user_home`. |
<!-- END VARIABLES -->
