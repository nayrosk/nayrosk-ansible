# obsidian

Runs a headless Obsidian as a rootless Podman quadlet of the operator account and publishes its web interface
through Caddy. Used by `playbooks/install_obsidian.yml` on hosts of the `obsidian` group.

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
