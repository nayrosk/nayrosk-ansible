# libvirt

Installs QEMU/KVM and libvirt so the operator account manages virtual machines on the host, locally or from a
workstation over SSH. Used by `playbooks/install_libvirt.yml` on hosts of the `libvirt` group.

## What it does

1. Fails before any change when `/dev/kvm` is missing (unless `libvirt_require_kvm` is false) or when the
   operator account does not exist.
2. Installs `libvirt_packages`: QEMU, libvirt and its clients, OVMF and swtpm for Windows guests,
   virt-install, the libguestfs tools and the cloud image tools for Linux guests, `nc` for the remote
   console.
3. Enables `libvirtd.socket` and `libvirtd.service`, the monolithic daemon Ubuntu 26.04 ships.
4. Adds `libvirt_operator_user` to the `libvirt` and `kvm` groups, then reconnects so the session sees them.

## Remote access

No libvirt port is opened. Connect over the operator SSH login:

```sh
virsh -c qemu+ssh://operator@<host>/system list --all
virt-manager -c qemu+ssh://operator@<host>/system
```

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `libvirt_operator_user` | str | `{{ operator_user_name \| default('operator') }}` | no | Account given access to `qemu:///system` through the libvirt and kvm groups. |
| `libvirt_require_kvm` | bool | `true` | no | Fail before any change when `/dev/kvm` is missing. |
| `libvirt_packages` | list of str | `[qemu-system-x86, qemu-utils, libvirt-daemon-system, libv...` (15 entries, truncated, see `defaults/main.yml`) | no | Host packages for the hypervisor, Windows guests (OVMF, swtpm) and Linux guests. |
<!-- END VARIABLES -->
