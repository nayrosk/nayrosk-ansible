#!/bin/sh
# Boot the e2e VM. Runs inside the e2e VM image with:
#   /cache  read-only, holds the pristine cloud image ($CLOUD_IMAGE)
#   /e2e    read-only, tests/e2e (cloud-init seed files)
#   /vm     writable, receives the qcow2 overlay and the seed ISO
# The overlay keeps the cached image pristine; a fresh overlay is created on every boot.
set -eu

: "${CLOUD_IMAGE:?CLOUD_IMAGE is required}"
: "${CLOUD_IMAGE_SHA256:?CLOUD_IMAGE_SHA256 is required}"
image="/cache/$CLOUD_IMAGE"

echo "${CLOUD_IMAGE_SHA256}  ${image}" | sha256sum -c -

rm -f /vm/disk.qcow2 /vm/seed.iso
qemu-img create -q -f qcow2 -F qcow2 -b "$image" /vm/disk.qcow2 20G

seed=$(mktemp -d)
cp /e2e/cloud-init/user-data /e2e/cloud-init/meta-data "$seed/"
genisoimage -quiet -output /vm/seed.iso -volid cidata -joliet -rock "$seed/user-data" "$seed/meta-data"
rm -rf "$seed"

exec qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 4096 -nographic \
  -drive file=/vm/disk.qcow2,if=virtio -drive file=/vm/seed.iso,if=virtio,media=cdrom \
  -netdev user,id=n0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80,hostfwd=tcp::8443-:443,hostfwd=udp::8443-:443 \
  -device virtio-net-pci,netdev=n0
