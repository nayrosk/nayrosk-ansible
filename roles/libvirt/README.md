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
5. Keeps the NAT network `libvirt_nat_network_name` (192.168.122.0/24 on `virbr0`) active and started at
   boot, and adds UFW rules for it: DHCP and DNS from the NAT guests to libvirt's dnsmasq, and routing from
   `virbr0` out through `libvirt_nat_uplink`. The rules only match traffic entering on `virbr0`; the LAN
   cannot reach the NAT guests. On Ubuntu 26.04 libvirt also inserts its own iptables rules in the same
   tables; the UFW rules keep the network working if libvirt moves to its nftables backend.
6. Downloads the virtio-win driver ISO to `libvirt_virtio_win_dir` and checks it against
   `libvirt_virtio_win_sha256`, unless `libvirt_virtio_win_enabled` is false. Attach it as a CD-ROM to a
   Windows guest to install the storage and network drivers.
7. With `libvirt_bridge_enabled`: finds the uplink and its netplan entry (by id, `set-name`, MAC or
   `match.name`, merging the files as netplan does), writes `/etc/netplan/60-libvirt-bridge.yaml`, which moves
   the uplink address settings (DHCP or static) to `libvirt_bridge_name` and gives the bridge the uplink MAC,
   removes static addresses, routes and name servers from the uplink entry with `netplan set`, and applies it
   all under a rollback timer: the host restores its backed-up `/etc/netplan` after
   `libvirt_bridge_rollback_timeout` seconds unless the controller reconnects, finds the host address on the
   bridge and the gateway reachable, and confirms under a lock the rollback script also takes. It then keeps bridged
   frames out of iptables when `br_netfilter` loads, defines the libvirt network `libvirt_bridge_network_name`
   on the bridge, and moves the NAT route rule to the bridge. Fails before any change when netplan does not
   configure the uplink or gives it no address.
8. With `libvirt_passthrough_enabled`: adds the IOMMU kernel arguments to GRUB, loads the VFIO modules, binds
   `libvirt_passthrough_vfio_ids` to `vfio-pci` at boot (none by default: libvirt then detaches devices when a
   VM using them starts), warns when a listed device shares its IOMMU group with unlisted ones (PCI bridges
   excepted), and reports a reboot until the host boots after the last change to these boot settings. Never
   reboots.

See "Virtual machines" in `docs/operations.md` for the bridge, Windows guests and passthrough.

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
| `libvirt_packages` | list of str | `[qemu-system-x86, qemu-utils, libvirt-daemon-system, libv...` (16 entries, truncated, see `defaults/main.yml`) | no | Host packages for the hypervisor, Windows guests (OVMF, swtpm) and Linux guests. |
| `libvirt_nat_network_name` | str | `default` | no | libvirt NAT network kept active and started at boot. |
| `libvirt_nat_bridge` | str | `virbr0` | no | Bridge of the NAT network. The UFW rules of the role only match traffic entering on it. |
| `libvirt_nat_uplink` | str | `{{ libvirt_bridge_name if libvirt_bridge_enabled \| bool e...` (truncated, see `defaults/main.yml`) | no | Interface NAT guests leave through, used in the UFW route rule. |
| `libvirt_bridge_enabled` | bool | `false` | no | Bridge the uplink so VMs get their own LAN address. Rewrites the host network config. |
| `libvirt_bridge_name` | str | `br0` | no | Name of the LAN bridge. |
| `libvirt_bridge_interface` | str | `""` | no | Interface to bridge. Empty picks the bridge member when the bridge exists, else the interface of the default route. |
| `libvirt_bridge_network_name` | str | `host-bridge` | no | libvirt network that attaches VMs to the bridge. |
| `libvirt_bridge_rollback_timeout` | int | `120` | no | Seconds before the host restores its previous netplan config when the controller has not confirmed the bridge. |
| `libvirt_bridge_state_dir` | str | `/var/lib/libvirt-bridge` | no | Directory where the rollback keeps the previous bridge file. |
| `libvirt_virtio_win_enabled` | bool | `true` | no | Download the virtio-win driver ISO. Set to false on a host without Windows guests. |
| `libvirt_virtio_win_version` | str | pinned in `defaults/main.yml` | no | virtio-win release, the directory name under `archive-virtio/` on fedorapeople.org, for example `0.1.302-1`. |
| `libvirt_virtio_win_sha256` | str | `303f7ae40dad495d6ae474fdc571df58958a4dbc5c37a522d80f9a203...` (truncated, see `defaults/main.yml`) | no | SHA256 of the ISO of that release. |
| `libvirt_virtio_win_dir` | str | `/var/lib/libvirt/images` | no | Directory the ISO is saved to, as `virtio-win-<version without the build>.iso`. |
| `libvirt_passthrough_enabled` | bool | `false` | no | Prepare the host for PCI passthrough. |
| `libvirt_passthrough_vfio_ids` | list of str | `[]` | no | `vendor:device` ids bound to vfio-pci at boot. Empty leaves every device to its driver; libvirt detaches a device when a VM that uses it with `managed="yes"` starts. |
| `libvirt_passthrough_kernel_args` | list of str | `[]` | no | Kernel arguments added to GRUB. Empty picks by CPU vendor, `iommu=pt` on AMD and `intel_iommu=on iommu=pt` on Intel. |
| `libvirt_passthrough_softdep_drivers` | list of str | `[amdgpu, radeon, nvidia, nouveau, snd_hda_intel, xhci_hcd...` (7 entries, truncated, see `defaults/main.yml`) | no | Drivers that wait for vfio-pci at boot, so it claims the listed devices first. |
| `libvirt_passthrough_marker` | str | `/var/lib/libvirt-passthrough-boot-changed` | no | File touched when a boot setting of the role changes. Newer than the last boot means a reboot is still needed. |
<!-- END VARIABLES -->
