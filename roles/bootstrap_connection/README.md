# bootstrap_connection

Chooses how Ansible connects to the host and gathers facts. It runs first in every play and carries
the tag `always`, so it also runs with `--tags` of another role.

## How the mode is chosen

1. The role probes an SSH login as the operator account with the controller key. The probe forces
   public key authentication in batch mode, never uses a password and never prompts.
2. If the probe succeeds, `bootstrap_connection_mode` is `operator`: the play continues as the
   operator with `become`.
3. If the host is unreachable for the operator, `bootstrap_connection_mode` is `bootstrap`: the play
   continues as `bootstrap_connection_user` with `bootstrap_connection_password`. This is the state of a
   fresh install.

## Bootstrap user

`bootstrap_connection_user` is `root` by default. Set it to another account when the fresh host has no
root password login, for example the `ubuntu` user of a stock install:

```yaml
bootstrap_connection_user: ubuntu
```

That user logs in with its password and reaches root through `sudo` with the same password. The password
comes from `vault_bootstrap_password`. `vault_root_password` is the older name and is used when
`vault_bootstrap_password` is not defined.

The `bootstrap_user_cleanup` role removes a bootstrap user other than root once the operator key login works.

The mode is printed as `bootstrap_connection_mode=<mode>`.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `bootstrap_connection_operator` | str | `{{ operator_user_name \| default('operator') }}` | no | Account probed with the SSH key. Follows `operator_user_name` when it is set. |
| `bootstrap_connection_probe_timeout` | int | `10` | no | Seconds before the operator probe gives up. |
| `bootstrap_connection_user` | str | `root` | no | Account used with a password while the operator key login does not work yet. `root`, or a user with sudo rights such as the `ubuntu` account of a stock install. The `bootstrap_user_cleanup` role removes a user other than root once the operator works. |
| `bootstrap_connection_password` | str | secret | no | Password of the bootstrap user, also used for sudo when that user is not root. Required only when the operator probe fails. |
| `vault_bootstrap_password` | str | secret | no | Vault secret behind `bootstrap_connection_password`. |
| `vault_root_password` | str | secret | no | Older name of `vault_bootstrap_password`, used when that one is not defined. |
<!-- END VARIABLES -->
