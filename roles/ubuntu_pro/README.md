# ubuntu_pro

Attaches the host to Ubuntu Pro and enables Livepatch.

## What it does

- Reads `pro status --format json`.
- When `first_install` is true, `ubuntu_pro_token` is not empty and the host is not attached, runs
  `pro attach --no-auto-enable <token>` with `no_log`. An empty token (as in the e2e inventory) skips it.
- When `ubuntu_pro_livepatch` is true and the host is attached, runs `pro enable livepatch --assume-yes`
  unless the Livepatch service is already enabled. ESM services are left untouched.
- The token comes from the vault variable `vault_ubuntu_pro_token`.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `ubuntu_pro_token` | str | secret | no | Ubuntu Pro token, read from the vault. An empty token skips attaching. |
| `ubuntu_pro_livepatch` | bool | `true` | no | Enable Livepatch once the machine is attached. |
| `first_install` | bool | `false` | no | Attach only on the first install run. |
<!-- END VARIABLES -->
