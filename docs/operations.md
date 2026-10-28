# Operations

How to run the playbook, keep it healthy and recover from mistakes.

## First install and later runs

The same command covers both. The `first_install` variable gates the steps that must not repeat: the
APT dist-upgrade and package install, the Ubuntu Pro attach and the firmware update.

```bash
# First run on a fresh machine: root with the vault password, then the operator with the key.
make run INVENTORY=inventories/prod ARGS="-e first_install=true"

# Every later run: idempotent, runs as the operator.
make run INVENTORY=inventories/prod
```

Useful filters:

```bash
make run INVENTORY=inventories/prod LIMIT=server1        # one host
make run INVENTORY=inventories/prod TAGS=dns,firewall    # some roles
```

Each role has a tag equal to its name. `bootstrap_connection` always runs. The `podman_monitoring` role needs
the facts of `local_ca`, so select both: `TAGS=local_ca,podman_monitoring`.

`make run` reads `.vault-pass` when the file exists and asks for the vault password otherwise. `.vault-pass`
is ignored by git.

## Vault

Secrets live in `group_vars/all/vault.yml` of the inventory, encrypted with Ansible Vault. The names are
`vault_root_password`, `vault_ubuntu_pro_token` and `vault_caddy_basic_auth_hash`. The example is in
`inventories/example/group_vars/all/vault.yml.example`.

```bash
make vault-edit VAULT_FILE=inventories/prod/group_vars/all/vault.yml
```

The target creates the file when it is missing and edits it otherwise.

Produce the Caddy password hash with the pinned Caddy image:

```bash
podman run --rm docker.io/library/caddy:2.11.7-alpine caddy hash-password --plaintext '<password>'
```

## Certificate authority

`local_ca` creates one CA per host, valid for 10 years, and a server certificate valid for 1 year. The
server certificate is issued again when its names change, when the CA changes or when less than 30 days
remain, so a regular run renews it.

Fetch the CA certificate. Every run copies it to the controller:

```
artifacts/<host>/ca.crt
```

Import it in your browser or system to trust the HTTPS endpoint:

- Firefox: Settings, Privacy and Security, Certificates, View Certificates, Authorities, Import.
- Chrome and Chromium: Settings, Privacy and security, Security, Manage certificates, Authorities, Import.
- curl: `curl --cacert artifacts/<host>/ca.crt https://<host>/node_exporter`.

Rotate the CA, for example after a key leak:

```bash
make run INVENTORY=inventories/prod ARGS="-e local_ca_force_regenerate=true"
```

This replaces the CA and the server certificate and restarts Caddy. Import the new `ca.crt` again on every
client. Run it once, then drop the flag.

## SSH keys

The operator account has exactly one authorized key set from `operator_public_key`. The role replaces the
file on every run, so a key added by hand disappears. To add or replace a key, change the variable and run
the playbook again. Several keys go in the same string, one per line:

```yaml
operator_public_key: |
  ssh-ed25519 AAAA... laptop
  ssh-ed25519 AAAA... backup
```

## Troubleshooting a lockout

`ssh_hardening` is the only role that can cut your access, so it protects itself:

1. It fails before any change when the operator is not in `ssh_hardening_allow_users`.
2. It runs `sshd -t` on the new configuration.
3. The controller opens a real SSH connection as the operator with the key. On failure the role removes the
   drop-in and stops.
4. After the reload it probes the operator login again. On failure it restores the previous files, reloads
   sshd over the connection that is still open and stops.

If you are locked out anyway (wrong key in `operator_public_key`, for example), use the console of your
provider or hypervisor. As root on the console:

```bash
rm /etc/ssh/sshd_config.d/00-hardening.conf
systemctl reload ssh
```

Root with a password works again until the next run. Fix `operator_public_key`, then run the playbook.

Other quick checks on the host:

```bash
sudo ufw status verbose            # firewall rules
sudo fail2ban-client status        # jails sshd and caddy-auth
sudo fail2ban-client status caddy-auth
sudo fail2ban-client unban <ip>    # unban a client
```

fail2ban never bans loopback, the detected LAN networks, `fe80::/10` and `fail2ban_ignoreip_extra`.

## Unattended upgrades

`unattended_upgrades` installs security updates only and enables the apt-daily timers. It does not reboot
unless `unattended_upgrades_automatic_reboot` is true; then the host reboots at
`unattended_upgrades_automatic_reboot_time` when an update needs it. Without automatic reboot, check
`/var/run/reboot-required` now and then.

## Ubuntu Pro

Set `vault_ubuntu_pro_token` to attach the host on the first install. The role runs
`pro attach --no-auto-enable`, skips hosts that are already attached and enables Livepatch when
`ubuntu_pro_livepatch` is true. An empty token skips the whole step. To attach later, run once with
`-e first_install=true` and the token set.

## Decisions and known limits

- Caddy runs on pasta, not on the `monitoring` network. A rootless bridge network publishes ports through
  `rootlessport`, which hides the client address: every request would look like it came from the
  container, and the fail2ban `caddy-auth` jail could not ban anybody. pasta keeps the client address. The
  `monitoring` network is created and waits for future rootless services. Caddy can join it once Podman 6
  or later, with the pasta port forwarder for bridge networks, is available on the target.
- Caddy reaches node_exporter through `host.containers.internal`, mapped by pasta to the host loopback. The
  mapping is scoped to the Caddy container, and node_exporter stays on `127.0.0.1:9100`.
  `podman_monitoring_node_exporter_listen` must remain a loopback address.
- node_exporter runs with `apparmor=unconfined`. The default Podman AppArmor profile denies D-Bus calls, and
  the systemd collector needs them. The container already shares the host PID and network namespaces and
  sees the root filesystem read-only.
- node_exporter has no init process, because the host PID namespace forbids one. The host systemd reaps
  orphans. The end-to-end test checks for zombies.
- UFW applies `/etc/ufw/sysctl.conf` at every start and ships `log_martians=0`. The `firewall` role sets it
  to `1` in that file so UFW does not undo the `system` role.
- Stopping a container on a rootless network can log `rootless netns: kill network process: permission
  denied` because of the `pasta` AppArmor profile of Ubuntu 26.04. It is harmless.
- One CA per host. There is no shared CA across hosts.
- Not covered: a Prometheus server, Grafana and alerting.
