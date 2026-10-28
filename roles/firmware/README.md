# firmware

Applies firmware updates with fwupd.

## What it does

- Runs only when `first_install` is true and `e2e` is not true (a virtual machine has no updatable firmware).
- `fwupdmgr refresh --force`, `fwupdmgr get-devices --json` and `fwupdmgr get-updates --json`. Exit code 2 means
  there is nothing to do; a host without supported devices is not a failure.
- When updates are listed, runs `fwupdmgr update -y --no-reboot-check`.
- Prints a message when a reboot is needed. The role never reboots.

## Variables

<!-- BEGIN VARIABLES -->
This role takes no variables.
<!-- END VARIABLES -->
