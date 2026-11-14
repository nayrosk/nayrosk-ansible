# rocm

Installs the ROCm stack and the amdgpu DKMS driver with AMD's `amdgpu-install` tool. Used by
`playbooks/install_rocm.yml` on hosts of the `gpu` group.

## What it does

1. Reads the host state, read-only: PCI display devices from sysfs, the Secure Boot EFI variable,
   `/etc/os-release`, the running kernel, `dkms status amdgpu` and the loaded `amdgpu` module.
2. Fails before any change when no AMD GPU of the host is in `rocm_supported_pci_ids`, when Secure Boot
   is enabled (the unsigned DKMS module would not load) or when the OS is not Ubuntu 26.04. An unsupported
   integrated GPU next to a supported one is fine.
3. Installs `rocm_prerequisite_packages` and adds `rocm_user` to the `render` and `video` groups. The
   account must exist.
4. Installs the `amdgpu-install` package from `rocm_amdgpu_install_url`.
5. Runs `amdgpu-install -y --usecase=<rocm_usecases> --gfxversion=<rocm_gfxversion>` when the `rocm` or
   `amdgpu-dkms` package is missing, or when a new `amdgpu-install` release was just installed. Otherwise
   it does nothing, so a second run reports no change.
6. Checks the driver state:
   - No `amdgpu` DKMS build for the running kernel, for example after a kernel update whose DKMS build
     failed: the role fails and names the kernel. The host still boots on the inbox driver.
   - DKMS build present but the inbox module still loaded: the role prints that a reboot is needed.
   - DKMS module loaded: the role runs `rocminfo` (it must list a `gfx` agent) and `amd-smi version`.

## Reboot

The role never reboots. After the first install, reboot the host by hand, then run the playbook again to
verify the stack.

## Recovery when amdgpu-install fails

The role stops and never uninstalls. Clean up by hand, then rerun:

```sh
sudo amdgpu-install --uninstall
sudo reboot
```

## Variables

<!-- BEGIN VARIABLES -->
| Variable | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `rocm_amdgpu_install_version` | str | `31.60` | no | amdgpu-install release, the directory under `repo.radeon.com/amdgpu-install/`. |
| `rocm_amdgpu_install_package_version` | str | `31.60.316000-1` | no | Exact version of the amdgpu-install `.deb` in that release. |
| `rocm_amdgpu_install_url` | str | `https://repo.radeon.com/amdgpu-install/{{ rocm_amdgpu_ins...` (truncated, see `defaults/main.yml`) | no | URL of the amdgpu-install `.deb`, built from the two version variables. |
| `rocm_usecases` | list of str | `[rocm, graphics]` | no | Usecases passed to `amdgpu-install --usecase`. |
| `rocm_gfxversion` | str | `auto` | no | Value passed to `amdgpu-install --gfxversion`. |
| `rocm_prerequisite_packages` | list of str | `[libatomic1, libquadmath0, python3.14, python3.14-venv]` | no | Packages installed before amdgpu-install. |
| `rocm_supported_pci_ids` | list of str | `[75a3, 75a0, 74a5, 74a1, 74a0, 7408, 740c, 740f, 738c, 73...` (24 entries, truncated, see `defaults/main.yml`) | no | PCI device ids (vendor 1002, lowercase hex, no `0x`) of the GPUs the ROCm system requirements list. The role fails before any change when no AMD display device of the host is in this list. |
| `rocm_user` | str | `{{ operator_user_name \| default('operator') }}` | no | Existing account added to the render and video groups. Defaults to the operator_user role account. Falls back to `operator` when the operator_user role did not run in the play. |
<!-- END VARIABLES -->
