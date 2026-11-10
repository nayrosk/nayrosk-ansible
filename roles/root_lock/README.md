# root_lock

Locks the root password once the operator has passwordless sudo.

## What it does

- Fails unless the play connects as the operator. A tagged run (`TAGS=root_lock`) skips `ssh_hardening`
  and its switch to the operator: if the operator probe failed, the play is still on the root password, and
  locking root would cut it.
- Fails unless the last rule in `sudo -l` for the operator is `NOPASSWD: ALL` (the one `operator_user`
  writes; sudo applies the last matching rule) and `sudo -k -n id -u` returns 0. `-k` ignores cached
  credentials, so a rule that needs a password cannot pass.
- Locks the root password with `ansible.builtin.user` and `password_lock: true` (`usermod -L` on Linux). The
  hash is kept behind a `!` prefix, so `passwd -u root` restores it.
- Runs after `ssh_hardening`. The first run connects as root with the password until that role switches the
  play to the operator, so locking root earlier would break any reconnection.

With the root password locked, nobody can log in on the console: the operator password is locked too. To
recover, boot the host in rescue or single-user mode. See `docs/operations.md`.

Set `root_lock_enabled: false` to skip the role. It does not unlock a password locked by an earlier run.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `root_lock_enabled` | bool | `true` | no | Lock the root password. Setting it to `false` skips the role. It does not unlock a password locked by an earlier run. |
| `root_lock_operator` | str | `{{ operator_user_name \| default('operator') }}` | no | Account whose passwordless sudo is checked before root is locked. Follows `operator_user_name` when it is set. |
<!-- END VARIABLES -->
