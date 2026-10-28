# unattended_upgrades

Configures unattended security upgrades.

## What it does

- Fails with a clear message when the `unattended-upgrades` package is missing (the `base_packages` role installs
  it on first install; this role never installs it).
- Writes `/etc/apt/apt.conf.d/52install-base`: clears the stock origins, then allows only the security, ESM apps and ESM infra origins,
  `Automatic-Reboot` and `Automatic-Reboot-Time` from the variables, `Remove-Unused-Dependencies "true"`.
- Writes `/etc/apt/apt.conf.d/20auto-upgrades` (daily package list update and unattended upgrade).
- Enables and starts `apt-daily.timer` and `apt-daily-upgrade.timer`.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `unattended_upgrades_automatic_reboot` | bool | `false` | Let unattended-upgrades reboot the host when an update requires it. |
| `unattended_upgrades_automatic_reboot_time` | str | `04:00` | Time of the automatic reboot (HH:MM). |
<!-- END VARIABLES -->
