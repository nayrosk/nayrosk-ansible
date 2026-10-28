# operator_user

Creates the operator account used for every connection after the first run.

## What it does

- Creates the group and the user with fixed ids (10000 by default), home directory, `/bin/bash` and a locked
  password: login is by SSH key only.
- Writes `/etc/sudoers.d/90-<name>` (mode 0440, validated with `visudo -cf`) granting `NOPASSWD:ALL`. A locked
  password does not affect sudo `NOPASSWD`.
- Installs `operator_public_key` as the only authorized key (`exclusive: true`).
- Runs `loginctl enable-linger <name>` once (guarded by `/var/lib/systemd/linger/<name>`) so user services
  survive logout.

`bootstrap_connection` probes this account with the key and switches the play to it with `become`.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `operator_user_name` | str | `operator` | no | Name of the operator account. |
| `operator_user_uid` | int | `10000` | no | Numeric user id. |
| `operator_user_gid` | int | `10000` | no | Numeric id of the primary group, which has the same name as the user. |
| `operator_user_home` | str | `/home/operator` | no | Home directory. |
| `operator_user_shell` | str | `/bin/bash` | no | Login shell. |
| `operator_user_public_key` | str | `{{ operator_public_key }}` | no | SSH public key installed as the only authorized key. Defaults to the inventory variable `operator_public_key`, which must then be set. |
<!-- END VARIABLES -->
