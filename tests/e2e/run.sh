#!/usr/bin/env bash
# End-to-end test: boot a fresh Ubuntu cloud image in a qemu/KVM VM hosted by a podman container,
# then drive it from the controller container over SSH.
#
#   tests/e2e/run.sh          run 1 (first_install), run 2 (must be idempotent), verify, teardown
#   tests/e2e/run.sh clean    remove the VM container and its overlay disk
#
# Environment: CONTROLLER_IMAGE, VM_IMAGE (built by make), KEEP=1 keeps the VM running afterwards,
# E2E_ZOMBIE_CHECK=1 makes verify wait five minutes and assert no zombie process (always set in CI).
set -euo pipefail

cd "$(dirname "$0")/../.."

CONTROLLER_IMAGE=${CONTROLLER_IMAGE:-localhost/nayrosk-ansible-controller:dev}
VM_IMAGE=${VM_IMAGE:-localhost/nayrosk-ansible-e2e-vm:dev}
KEEP=${KEEP:-0}

CLOUD_IMAGE_URL=https://cloud-images.ubuntu.com/releases/resolute/release-20261016/ubuntu-26.04-server-cloudimg-amd64.img
CLOUD_IMAGE_SHA256=5645d0318ad21f643ebb1ac4567514620e9893380b07b0201fda163baa5b7eb5
CLOUD_IMAGE=${CLOUD_IMAGE_URL##*/}

VM_NAME=nayrosk-e2e-vm
VM_DIR=.cache/e2e-vm
IMAGE_DIR=.cache/images
LOG_DIR=artifacts/e2e
INVENTORY=inventories/e2e
VAULT_PASS_FILE=tests/e2e/vault-pass
ROOT_PASSWORD=e2e-root-password
SSH_TIMEOUT=300

START=$(date +%s)

log() {
  printf '==> [%4ss] %s\n' "$(($(date +%s) - START))" "$*"
}

controller() {
  podman run --rm --userns=keep-id --network host -e HOME=/tmp -e E2E_ZOMBIE_CHECK="${E2E_ZOMBIE_CHECK:-0}" \
    -v "$PWD:/work:Z" -w /work "$CONTROLLER_IMAGE" "$@"
}

playbook() {
  controller ansible-playbook -i "$INVENTORY" --vault-password-file "$VAULT_PASS_FILE" "$@"
}

clean() {
  podman rm -f --ignore "$VM_NAME" >/dev/null
  rm -rf "$VM_DIR"
}

teardown() {
  local status=$?
  if podman container exists "$VM_NAME"; then
    mkdir -p "$LOG_DIR"
    podman logs "$VM_NAME" >"$LOG_DIR/vm-console.log" 2>&1 || true
  fi
  if [ "$KEEP" = 1 ]; then
    log "KEEP=1: VM left running, ssh -p 2222 root@127.0.0.1; remove it with make e2e-clean"
  else
    log "teardown"
    clean
  fi
  if [ "$status" -eq 0 ]; then
    log "e2e PASSED"
  else
    log "e2e FAILED (exit $status), VM console in $LOG_DIR/vm-console.log"
  fi
  exit "$status"
}

ensure_cloud_image() {
  log "cloud image: $CLOUD_IMAGE"
  mkdir -p "$IMAGE_DIR"
  # shellcheck disable=SC2016 # the script is expanded by the inner shell
  controller sh -eu -c '
    dir=$1 url=$2 sha=$3 file=$1/${2##*/}
    if [ -f "$file" ] && echo "$sha  $file" | sha256sum -c --status -; then
      echo "cached and verified"
      exit 0
    fi
    curl -fsSL --retry 3 -o "$file.part" "$url"
    echo "$sha  $file.part" | sha256sum -c -
    mv "$file.part" "$file"
  ' sh "$IMAGE_DIR" "$CLOUD_IMAGE_URL" "$CLOUD_IMAGE_SHA256"
}

ensure_ssh_key() {
  # shellcheck disable=SC2016 # the script is expanded by the inner shell
  controller sh -eu -c '
    key=$1/.ssh/id_ed25519
    [ -f "$key" ] && exit 0
    mkdir -p "${key%/*}" && chmod 700 "${key%/*}"
    ssh-keygen -q -t ed25519 -N "" -C nayrosk-e2e -f "$key"
  ' sh "$INVENTORY"
}

start_vm() {
  log "start VM container $VM_NAME"
  clean
  mkdir -p "$VM_DIR"
  # keep-id: the VM must write its overlay into a host directory owned by the invoking user.
  podman run -d --name "$VM_NAME" --userns=keep-id --device /dev/kvm \
    -p 127.0.0.1:2222:2222 -p 127.0.0.1:8080:8080 \
    -p 127.0.0.1:8443:8443/tcp -p 127.0.0.1:8443:8443/udp \
    -e CLOUD_IMAGE="$CLOUD_IMAGE" -e CLOUD_IMAGE_SHA256="$CLOUD_IMAGE_SHA256" \
    -v "$PWD/$IMAGE_DIR:/cache:ro,z" -v "$PWD/tests/e2e:/e2e:ro,z" -v "$PWD/$VM_DIR:/vm:z" \
    "$VM_IMAGE" sh /e2e/vm/run-vm.sh >/dev/null
}

vm_running() {
  [ "$(podman container inspect -f '{{.State.Running}}' "$VM_NAME" 2>/dev/null)" = true ]
}

# One SSH probe from the controller: $1 is "keyscan" (host key served) or "login" (root password
# login accepted). sshd answers before cloud-init has set the root password and allowed root login.
ssh_probe() {
  # shellcheck disable=SC2016 # the script is expanded by the inner shell
  controller env SSHPASS="$ROOT_PASSWORD" sh -eu -c '
    case $1 in
      keyscan) ssh-keyscan -T 5 -p 2222 127.0.0.1 2>/dev/null | grep -q ssh-ed25519 ;;
      login) sshpass -e ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
               -o PubkeyAuthentication=no -o ConnectTimeout=5 -o LogLevel=ERROR root@127.0.0.1 "${2:-true}" ;;
    esac
  ' sh "$@"
}

# Read the SSH banner on 127.0.0.1:2222 from the current network namespace (prints it or "closed").
# shellcheck disable=SC2016 # the script is expanded by the inner shell
BANNER_PROBE='exec 3<>/dev/tcp/127.0.0.1/2222 && timeout 5 head -c 40 <&3 || echo closed'

# Network diagnostics printed when the VM never answers on SSH. No secrets.
ssh_diagnostics() {
  set +e
  echo "---- diagnostics: podman version" >&2
  podman version >&2
  echo "---- podman ps -a" >&2
  podman ps -a >&2
  echo "---- podman port $VM_NAME" >&2
  podman port "$VM_NAME" >&2
  echo "---- podman inspect network settings" >&2
  podman container inspect -f '{{json .HostConfig.NetworkMode}} {{json .NetworkSettings.Ports}}' "$VM_NAME" >&2
  echo "---- host listeners" >&2
  ss -ltnup >&2
  echo "---- banner from host" >&2
  timeout 10 bash -c "$BANNER_PROBE" >&2
  echo "---- banner from the controller (--network host)" >&2
  timeout 20 podman run --rm --userns=keep-id --network host --entrypoint bash "$CONTROLLER_IMAGE" -c "$BANNER_PROBE" >&2
  echo "---- banner from inside the VM container (qemu hostfwd)" >&2
  timeout 10 podman exec "$VM_NAME" bash -c "$BANNER_PROBE" >&2
  echo "---- processes in the VM container" >&2
  podman top "$VM_NAME" >&2
  echo "---- last console lines" >&2
  podman logs --tail 30 "$VM_NAME" >&2
  set -e
}

wait_for_vm() {
  log "wait for SSH (timeout ${SSH_TIMEOUT}s)"
  local deadline=$(($(date +%s) + SSH_TIMEOUT)) step
  for step in keyscan login; do
    until ssh_probe "$step" >/dev/null 2>&1; do
      vm_running || { echo "VM container stopped:" >&2; podman logs --tail 20 "$VM_NAME" >&2; return 1; }
      [ "$(date +%s)" -lt "$deadline" ] || { echo "timed out waiting for SSH ($step)" >&2; ssh_diagnostics; return 1; }
      sleep 3
    done
    log "ssh $step ok"
  done
  log "wait for cloud-init"
  ssh_probe login "cloud-init status --wait"
}

# Expected bootstrap_connection_mode per run. Run 1 finds no operator account yet and connects as root;
# the operator_user role creates it, so run 2 connects as the operator.
RUN_1_MODE=root
RUN_2_MODE=operator

# Assertions on a playbook run log ($1: run number, $2: log file, $3: expected bootstrap_connection_mode).
assert_run_log() {
  local run=$1 file=$2 mode=$3
  [ -s "$file" ] || { echo "run $run: empty log $file" >&2; return 1; }
  grep -q "bootstrap_connection_mode=$mode" "$file" \
    || { echo "run $run: expected bootstrap_connection_mode=$mode in $file" >&2; return 1; }
}

run_1() {
  log "run 1 (first_install=true)"
  playbook playbooks/install_base.yml -e first_install=true 2>&1 | tee "$LOG_DIR/run1.log"
  assert_run_log 1 "$LOG_DIR/run1.log" "$RUN_1_MODE"
}

run_2() {
  log "run 2 (idempotence)"
  playbook playbooks/install_base.yml 2>&1 | tee "$LOG_DIR/run2.log" | tests/e2e/check-idempotence.sh
  assert_run_log 2 "$LOG_DIR/run2.log" "$RUN_2_MODE"
}

verify() {
  log "verify"
  playbook tests/e2e/verify.yml 2>&1 | tee "$LOG_DIR/verify.log"
}

main() {
  if [ "${1:-}" = clean ]; then
    clean
    exit 0
  fi
  [ -e /dev/kvm ] || { echo "/dev/kvm is missing: the e2e VM needs KVM" >&2; exit 1; }
  mkdir -p "$LOG_DIR"
  ensure_cloud_image
  ensure_ssh_key
  trap teardown EXIT
  trap 'exit 130' INT TERM
  start_vm
  wait_for_vm
  run_1
  run_2
  verify
}

main "$@"
