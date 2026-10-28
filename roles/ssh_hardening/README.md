# ssh_hardening

Restricts SSH to key-based logins of the operator account.

## What it does

- Writes `/etc/ssh/sshd_config.d/00-hardening.conf` (mode 0600): `PermitRootLogin no`,
  `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PubkeyAuthentication yes`,
  `AllowUsers <ssh_hardening_allow_users>`, `AllowAgentForwarding yes`, `X11Forwarding no`, `MaxAuthTries 3`.
- Comments out `PermitRootLogin` and `PasswordAuthentication` lines in the other drop-ins of
  `/etc/ssh/sshd_config.d/` (backup kept), so `sshd -T` shows the hardening whatever the file order.
- Runs `sshd -t`, then the lockout guard: the controller opens a real SSH connection as the operator with the
  key (`BatchMode=yes`, reusing the inventory `ansible_ssh_common_args`). On any failure the drop-in is removed,
  the commented lines are restored from their backups, sshd is not reloaded and the role fails.
- Reloads `ssh.service` through a handler, only when the daemon is running (Ubuntu uses socket activation, a
  stopped daemon reads the new configuration at the next connection).
- When the play connected as root with a password (`bootstrap_connection_mode=root`, first run), switches the
  rest of the play to the operator with `become` and resets the connection, because new root logins are refused
  after the reload. Roles placed after this one therefore run as the operator.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `ssh_hardening_allow_users` | list of str | `["{{ operator_user_name }}"]` | Accounts allowed to log in over SSH (`AllowUsers`). Defaults to the operator account only. |
<!-- END VARIABLES -->
