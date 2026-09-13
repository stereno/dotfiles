#!/usr/bin/env bash
set -euo pipefail

PIJ_BIN=${PIJ_BIN:?set PIJ_BIN to the generated pij launcher}
VM_RUNNER=${VM_RUNNER:?set VM_RUNNER to run-pi-sandbox-vm}
SOCAT_BIN=${SOCAT_BIN:?set SOCAT_BIN to socat}
PYTHON=${PYTHON:?set PYTHON to python3}
RELAY=${RELAY:?set RELAY to model-relay.py}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

tmp=$(mktemp -d /tmp/pij-service-live.XXXXXXXXXX)
unit="pij-r5-service-${tmp##*.}"
started=0
cleanup() {
  if [[ $started -eq 1 ]]; then
    systemctl --user stop "$unit" >/dev/null 2>&1 || true
  fi
  systemctl --user reset-failed "$unit" >/dev/null 2>&1 || true
  rm -rf -- "$tmp"
}
trap cleanup EXIT

repo="$tmp/repo"
worktree="$tmp/worktree"
runtime="$tmp/runtime"
session="$tmp/session"
auth_store="$tmp/openai-agent"
mkdir -p "$repo" "$runtime/vm" "$session" "$auth_store"
chmod 0700 "$runtime" "$session" "$auth_store"

git -C "$repo" init -q
git -C "$repo" config user.name "PIJ Service Test"
git -C "$repo" config user.email "pij-service@example.invalid"
git -C "$repo" commit --allow-empty -qm baseline
git -C "$repo" worktree add -q -b pij-service "$worktree"
git -C "$worktree" rev-parse HEAD >"$session/base-commit"
git -C "$worktree" rev-parse --show-object-format >"$session/object-format"

placeholder_payload=$(printf '%s' '{"https://api.openai.com/auth":{"chatgpt_account_id":"service-placeholder"}}' \
  | base64 -w0 | tr '+/' '-_' | tr -d '=')
guest_token="e30.$placeholder_payload.e30"
printf '{"openai-codex":{"type":"oauth","access":"%s","refresh":"placeholder","expires":4102444800000}}\n' \
  "$guest_token" >"$session/auth.json"
printf '{"providers":{"openai-codex":{"baseUrl":"http://10.0.2.100:8645"}}}\n' >"$session/models.json"
printf '{"transport":"sse"}\n' >"$session/settings.json"
chmod 0600 "$session"/*.json

real_payload=$(printf '%s' '{"https://api.openai.com/auth":{"chatgpt_account_id":"service-real"}}' \
  | base64 -w0 | tr '+/' '-_' | tr -d '=')
access_marker="pij-host-credential-marker-service.$real_payload.signature"
refresh_marker='pij-host-credential-marker-service-refresh'
printf '{"openai-codex":{"type":"oauth","access":"%s","refresh":"%s","expires":4102444800000}}\n' \
  "$access_marker" "$refresh_marker" >"$auth_store/auth.json"
chmod 0600 "$auth_store/auth.json"

fake_pi="$tmp/pi"
printf '#!/bin/sh\nexit 1\n' >"$fake_pi"
chmod 0700 "$fake_pi"
session_runner=$(grep -oE '/nix/store/[^[:space:]'"'"']+-pij-session-runner/bin/pij-session-runner' "$PIJ_BIN" | head -n 1)
[[ -x $session_runner ]] || fail "cannot locate pij-session-runner"

rm_bin=$(command -v rm)
systemd-run \
  --user \
  --unit="$unit" \
  --service-type=exec \
  --quiet \
  --collect \
  --property="ExecStopPost=$rm_bin -rf -- $runtime" \
  --property=KillMode=control-group \
  --property=TimeoutStopSec=30s \
  --property=MemoryMax=6G \
  --property=MemorySwapMax=0 \
  --property=CPUQuota=400% \
  --property=TasksMax=512 \
  --property=RuntimeMaxSec=2h \
  -- \
  env -i \
    QEMU_KERNEL_PARAMS=systemd.mask=serial-getty@ttyS0.service \
    TERM=xterm-256color \
    TMPDIR="$runtime/vm" \
    USE_TMPDIR=1 \
    "$session_runner" \
      "$PYTHON" "$RELAY" "$fake_pi" "$auth_store" "$guest_token" \
      http://127.0.0.1:1/backend-api/codex/responses \
      "$runtime/openai-bridge.sock" "$runtime/openai-bridge.ready" "$VM_RUNNER" \
      -virtfs "local,path=$worktree,security_model=none,mount_tag=pij-worktree,multidevs=forbid" \
      -virtfs "local,path=$repo/.git/objects,security_model=none,mount_tag=pij-git-objects,readonly=on,multidevs=forbid" \
      -virtfs "local,path=$session,security_model=none,mount_tag=pij-session,readonly=on,multidevs=forbid" \
      -netdev "user,id=pij-net,restrict=on,guestfwd=tcp:10.0.2.100:8645-cmd:$SOCAT_BIN STDIO UNIX-CONNECT:$runtime/openai-bridge.sock" \
      -device virtio-net-pci,netdev=pij-net
started=1

bridge_pid=
vm_pid=
control_group=
for _ in $(seq 1 300); do
  control_group=$(systemctl --user show "$unit" -p ControlGroup --value 2>/dev/null || true)
  if [[ -n $control_group && -r /sys/fs/cgroup$control_group/cgroup.procs ]]; then
    while IFS= read -r pid; do
      [[ -r /proc/$pid/cmdline ]] || continue
      command_line=$(tr '\0' ' ' <"/proc/$pid/cmdline")
      [[ $command_line != *model-relay.py* ]] || bridge_pid=$pid
      [[ $command_line != *qemu-system-* ]] || vm_pid=$pid
    done <"/sys/fs/cgroup$control_group/cgroup.procs"
  fi
  [[ -z $bridge_pid || -z $vm_pid ]] || break
  sleep 0.05
done
[[ -n $bridge_pid ]] || fail "credential bridge did not join the transient unit cgroup"
[[ -n $vm_pid ]] || fail "QEMU did not join the transient unit cgroup"

[[ $(systemctl --user show "$unit" -p MemoryMax --value) == 6442450944 ]] || fail "MemoryMax is not 6G"
[[ $(systemctl --user show "$unit" -p MemorySwapMax --value) == 0 ]] || fail "MemorySwapMax is not zero"
[[ $(systemctl --user show "$unit" -p CPUQuotaPerSecUSec --value) == 4s ]] || fail "CPUQuota is not 400%"
[[ $(systemctl --user show "$unit" -p TasksMax --value) == 512 ]] || fail "TasksMax is not 512"
[[ $(systemctl --user show "$unit" -p RuntimeMaxUSec --value) == 2h ]] || fail "RuntimeMaxSec is not two hours"
[[ $(systemctl --user show "$unit" -p KillMode --value) == control-group ]] || fail "KillMode is not control-group"

qemu_command=$(tr '\0' ' ' <"/proc/$vm_pid/cmdline")
[[ $qemu_command == *'user,id=pij-net,restrict=on,guestfwd=tcp:10.0.2.100:8645-cmd:'* ]] \
  || fail "QEMU lacks the restricted bridge-only netdev"
[[ $qemu_command == *"local,path=$repo/.git/objects,security_model=none,mount_tag=pij-git-objects,readonly=on,multidevs=forbid"* ]] \
  || fail "QEMU lacks the read-only host Git object export"
[[ $qemu_command != *'mount_tag=pij-git-common'* ]] \
  || fail "QEMU exposes the shared Git common directory"
[[ $qemu_command != *hostfwd* && $qemu_command != *tftp=* && $qemu_command != *smb=* ]] \
  || fail "QEMU exposes an unintended network service"
[[ $(grep -o -- 'user,id=pij-net' <<<"$qemu_command" | wc -l) -eq 1 ]] \
  || fail "QEMU has more than one PIJ user netdev"

for pid in "$bridge_pid" "$vm_pid"; do
  for proc_file in "/proc/$pid/cmdline" "/proc/$pid/environ"; do
    proc_value=$(tr '\0' '\n' <"$proc_file")
    [[ $proc_value != *"$access_marker"* ]] || fail "access marker leaked into process state"
    [[ $proc_value != *"$refresh_marker"* ]] || fail "refresh marker leaked into process state"
  done
done
for exposed in "$session" "$worktree"; do
  ! grep -R -a -Fq -- "$access_marker" "$exposed" || fail "access marker leaked into guest-visible state"
  ! grep -R -a -Fq -- "$refresh_marker" "$exposed" || fail "refresh marker leaked into guest-visible state"
done

systemctl --user stop "$unit"
started=0
for _ in $(seq 1 100); do
  if ! kill -0 "$bridge_pid" 2>/dev/null && ! kill -0 "$vm_pid" 2>/dev/null && [[ ! -e $runtime ]]; then
    break
  fi
  sleep 0.05
done
kill -0 "$bridge_pid" 2>/dev/null && fail "credential bridge survived unit stop"
kill -0 "$vm_pid" 2>/dev/null && fail "QEMU survived unit stop"
[[ ! -e $runtime ]] || fail "ExecStopPost left per-run state behind"

journal=$(journalctl --user -u "$unit" --no-pager 2>/dev/null || true)
[[ $journal != *"$access_marker"* ]] || fail "access marker leaked into the unit journal"
[[ $journal != *"$refresh_marker"* ]] || fail "refresh marker leaked into the unit journal"

printf 'pij transient service boundary test passed\n'
