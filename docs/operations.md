# Operations

How to run the playbook, keep it healthy and recover from mistakes.

## First install and later runs

The same command covers both. The `first_install` variable gates the steps that must not repeat: the
APT dist-upgrade and package install, the APT mirror measurement, the Ubuntu Pro attach and the firmware
update.

Before the first run, record the host key on your workstation. `make run` mounts `~/.ssh` read-only in the
controller container, so SSH cannot add a new host key there:

```bash
ssh-keyscan -H 203.0.113.10 >> ~/.ssh/known_hosts   # or connect once: ssh root@203.0.113.10
```

When your key has a passphrase, load it in your SSH agent (`ssh-add ~/.ssh/id_ed25519`). `make run` forwards
the agent socket into the container when `SSH_AUTH_SOCK` is set. Without an agent, only a key without a
passphrase works.

```bash
# First run on a fresh machine: root with the vault password, then the operator with the key.
make run INVENTORY=inventories/prod ARGS="-e first_install=true"

# Every later run: idempotent (the APT mirror chosen on the first run is kept), runs as the operator.
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

The certificate names the hostname, the local IP and the public IP. The target asks
`https://ipv4.icanhazip.com` for its public IPv4 address. When that fails, the public IP already in the
certificate is kept, so a run without internet access does not reissue it. Set `local_ca_public_ip_override`
in the inventory to choose the public IP yourself, for example behind NAT or on an IPv6-only host:

```yaml
local_ca_public_ip_override: 203.0.113.10
```

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
provider or hypervisor and log in as root there. Two ways out:

1. Fix the operator key. This is the simplest and keeps the hardening:

   ```bash
   echo 'ssh-ed25519 AAAA... you@laptop' > /home/operator/.ssh/authorized_keys
   ```

   Then put the same key in `operator_public_key` and run the playbook again.

2. Restore the SSH configuration from before the hardening. Removing `00-hardening.conf` alone is not
   enough: the role also commented out `PermitRootLogin` and `PasswordAuthentication` in the other files of
   `/etc/ssh/sshd_config.d/`, so sshd falls back to its own defaults, which refuse a root password. The role
   kept a copy of every file it changed, named `<file>.<number>.<date>~` next to it. Put the copies back,
   then reload:

   ```bash
   cd /etc/ssh/sshd_config.d
   ls -l                                   # find the backups, for example 50-cloud-init.conf.1234.2026-10-28@10:00:00~
   cp -p 50-cloud-init.conf.1234.2026-10-28@10:00:00~ 50-cloud-init.conf
   rm 00-hardening.conf                    # or restore its own backup if it had one
   sshd -t && systemctl reload ssh
   ```

   Root can log in with its password again until the next run. Fix `operator_public_key`, then run the
   playbook.

Other quick checks on the host:

```bash
sudo ufw status verbose            # firewall rules
sudo fail2ban-client status        # jails sshd and caddy-auth
sudo fail2ban-client status caddy-auth
sudo fail2ban-client unban <ip>    # unban a client
```

fail2ban never bans loopback, `fe80::/10`, `fail2ban_ignoreip_extra` and the detected LAN networks. A
detected network counts only when it is private (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`,
`100.64.0.0/10`, `fc00::/7`): a public subnet of a hosting provider is not whitelisted. Add your own
addresses to `fail2ban_ignoreip_extra` when you need them. The `caddy-auth` jail counts only 401 answers to
requests that carried a user and password, so the first anonymous request of a browser never counts.

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
