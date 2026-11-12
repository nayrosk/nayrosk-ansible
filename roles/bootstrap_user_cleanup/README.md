# bootstrap_user_cleanup

Removes the bootstrap user once the operator key login works.

## What it does

- Does nothing when `bootstrap_user_cleanup_user` (by default `bootstrap_connection_user`) is `root` or the
  operator. Root is locked by `root_lock` instead.
- Fails unless the play connects as the operator. A tagged run (`TAGS=bootstrap_user_cleanup`) skips
  `ssh_hardening` and its switch to the operator: if the operator probe failed, the play still connects as the
  bootstrap user, and removing it would cut that connection.
- Stops the sessions of the user (`loginctl terminate-user`), kills its remaining processes, then removes the
  account, its home directory and its mail spool (`userdel -r`).
- Removes the lines naming the user from `/etc/sudoers.d`, for example the rule cloud-init writes to
  `90-cloud-init-users`. Each file is checked with `visudo -c` before it is written.
- Runs after `ssh_hardening` and `root_lock`. Later runs connect as the operator and find nothing to remove.

Set `bootstrap_user_cleanup_enabled: false` to keep the account.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `bootstrap_user_cleanup_enabled` | bool | `true` | no | Remove the bootstrap user. Setting it to `false` skips the role. |
| `bootstrap_user_cleanup_user` | str | `{{ bootstrap_connection_user \| default('root') }}` | no | Account removed. Follows `bootstrap_connection_user`. |
| `bootstrap_user_cleanup_operator` | str | `{{ operator_user_name \| default('operator') }}` | no | Account the play must connect as before anything is removed. Follows `operator_user_name` when it is set. |
<!-- END VARIABLES -->
