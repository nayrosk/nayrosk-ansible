# bootstrap_connection

Chooses how Ansible connects to the host and gathers facts. It runs first in every play and carries
the tag `always`, so it also runs with `--tags` of another role.

## How the mode is chosen

1. The role probes an SSH login as the operator account with the controller key. The probe forces
   public key authentication in batch mode, never uses a password and never prompts.
2. If the probe succeeds, `bootstrap_connection_mode` is `operator`: the play continues as the
   operator with `become`.
3. If the host is unreachable for the operator, `bootstrap_connection_mode` is `root`: the play
   continues as root with `vault_root_password`. This is the state of a fresh install.

The mode is printed as `bootstrap_connection_mode=<mode>`.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `bootstrap_connection_operator` | str | `{{ operator_user_name \| default('operator') }}` | Account probed with the SSH key. |
| `bootstrap_connection_probe_timeout` | int | `10` | Seconds before the operator probe gives up. |
| `vault_root_password` | str | none | Root password for the fallback. Required only when the probe fails. |
<!-- END VARIABLES -->
