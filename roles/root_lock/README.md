# root_lock

Locks the root password once the operator has passwordless sudo.

## What it does

- Checks that the operator can run `sudo -n` without a password, and fails otherwise.
- Locks the root password (`passwd -l root`). The hash is kept behind a `!` prefix, so `passwd -u root`
  restores it.
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
<!-- END VARIABLES -->
