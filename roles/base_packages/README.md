# base_packages

Upgrades the system and installs the base packages on first install.

## What it does

- Runs only when `first_install` is true; otherwise every task is skipped.
- `apt update` and `dist-upgrade`, waiting up to 600 seconds for the APT lock (cloud-init or `apt-daily` may hold it).
- Installs `base_packages_list`. `ufw` is installed but not enabled here.
- When `/var/run/reboot-required` exists and `base_packages_reboot` is true, reboots and waits up to 600 seconds
  for the host to come back.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `base_packages_list` | list | ca-certificates, tree, vim, curl, fwupd, ufw, fail2ban, podman, unattended-upgrades | Packages installed on first install. |
| `base_packages_reboot` | bool | `true` | Reboot when /var/run/reboot-required exists after the upgrade. |
<!-- END VARIABLES -->
