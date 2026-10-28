#!/bin/sh
# Build an image without `podman build` (blocked on hardened kernels): run a provision script in a
# throwaway container, then commit it.
# Usage: scripts/build-image.sh <base-image> <provision-dir> <tag> [extra-mount-dir]
# <provision-dir> must contain provision.sh; it is mounted read-only at /provision. An optional extra
# directory is mounted read-only at /extra.
set -eu

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <base-image> <provision-dir> <tag> [extra-mount-dir]" >&2
  exit 2
fi
base=$1
dir=$2
tag=$3
extra=${4:-}

name="build-image-$$"
trap 'podman rm -f "$name" >/dev/null 2>&1 || true' EXIT INT TERM

set -- --name "$name" -v "$dir:/provision:ro,Z"
if [ -n "$extra" ]; then
  set -- "$@" -v "$extra:/extra:ro,Z"
fi
podman run "$@" "$base" sh /provision/provision.sh
podman commit --change 'WORKDIR /work' "$name" "$tag"
