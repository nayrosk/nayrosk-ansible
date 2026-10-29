# system

Applies sysctl hardening, UTC time with chrony, journald limits and the APT mirror selection.

## What it does

- Writes `/etc/sysctl.d/60-install-base.conf` through `ansible.posix.sysctl` for every entry of `system_sysctl`
  combined with `system_sysctl_extra` (`net.ipv4.ip_unprivileged_port_start` from
  `system_unprivileged_port_start`, redirects and source routing disabled, strict `rp_filter`, `log_martians`,
  `kernel.kptr_restrict=2`, `kernel.dmesg_restrict=1`). Settings are also applied to the running kernel.
  Strict `rp_filter=1` can break rootless pasta networking; override it with `system_sysctl_extra` if needed.
- Sets the time zone to `Etc/UTC`, installs and enables `chrony`, and fails unless `chronyc tracking`
  reports `Leap status : Normal` within 12 tries 10 seconds apart.
- Writes `/etc/systemd/journald.conf.d/10-install-base.conf` with `Storage=persistent` and
  `SystemMaxUse=<system_journal_max_use>`, then restarts `systemd-journald` in a handler.
- Writes the deb822 `/etc/apt/sources.list.d/ubuntu.sources`: the chosen mirror for the release,
  `-updates` and `-backports`, and `http://security.ubuntu.com/ubuntu/` for `-security`. A handler runs
  `apt update`. When `/etc/cloud` exists, `/etc/cloud/cloud.cfg.d/99-install-base-apt.cfg` sets
  `preserve_sources_list` so cloud-init does not rewrite the sources.

## Mirror selection

1. `system_apt_mirror_url` set: used as is, nothing is measured.
2. Else on the first install (`first_install: true`) outside e2e: the country comes from
   `system_apt_mirror_country` or `https://ifconfig.co/country-iso`, the list from
   `http://mirrors.ubuntu.com/<CC>.txt`, each mirror is timed with `curl --max-time 5` on
   `dists/<codename>/Release` and the fastest wins. If none answers, `system_apt_mirror_default` is used.
3. Else (every later run, and e2e): the mirror already in `/etc/apt/sources.list.d/ubuntu.sources` is kept.
   It is the `URIs:` value of the stanza whose `Suites:` holds the release codename itself (not `-security`).
   When the file or that stanza is missing, `system_apt_mirror_default` is used.

Measuring is not repeatable, so it only happens on the first install: later runs keep the mirror chosen
then and leave the sources file unchanged. To pick a new mirror, set `system_apt_mirror_url`, or run again
with `-e first_install=true`.

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `system_unprivileged_port_start` | int | `80` | no | First unprivileged port (net.ipv4.ip_unprivileged_port_start). |
| `system_journal_max_use` | str | `500M` | no | Maximum disk space used by the persistent journal (journald SystemMaxUse). |
| `system_sysctl` | dict | `{net.ipv4.ip_unprivileged_port_start: {{ system_unprivile...` (15 entries, truncated, see `defaults/main.yml`) | no | Sysctl settings written to /etc/sysctl.d/60-install-base.conf. The default holds the hardening set. |
| `system_sysctl_extra` | dict | `{}` | no | Additional sysctl settings merged over system_sysctl. |
| `system_apt_mirror_url` | str | `""` | no | Mirror to use as is. When empty the fastest mirror of the country is measured on the first install (never in e2e) and later runs keep the mirror already in the sources file. |
| `system_apt_mirror_country` | str | `""` | no | Two-letter country code used to pick the mirror list. When empty it is detected from the public IP. |
| `system_apt_mirror_default` | str | `http://archive.ubuntu.com/ubuntu/` | no | Mirror used when no measured mirror answers and when the sources file holds no mirror for the release. |
| `first_install` | bool | `false` | no | Measure the APT mirrors only on the first install run. |
| `e2e` | bool | `false` | no | Never measure the APT mirrors in the end-to-end test VM. |
<!-- END VARIABLES -->
