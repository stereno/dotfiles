#!/usr/bin/env bash
set -euo pipefail

VM_RUNNER=${VM_RUNNER:?set VM_RUNNER to run-pi-sandbox-vm}
SOCAT_BIN=${SOCAT_BIN:?set SOCAT_BIN to socat}
PIJ_BIN=${PIJ_BIN:?set PIJ_BIN to the generated pij launcher}
RELAY=${RELAY:?set RELAY to model-relay.py}
PYTHON=${PYTHON:?set PYTHON to python3}

tmp=$(mktemp -d /tmp/pij-live.XXXXXXXXXX)
host_listener_pid=
upstream_pid=
cleanup() {
  if [[ -n $host_listener_pid ]]; then
    kill "$host_listener_pid" >/dev/null 2>&1 || true
    wait "$host_listener_pid" 2>/dev/null || true
  fi
  if [[ -n $upstream_pid ]]; then
    kill "$upstream_pid" >/dev/null 2>&1 || true
    wait "$upstream_pid" 2>/dev/null || true
  fi
  rm -rf -- "$tmp"
}
trap cleanup EXIT

repo="$tmp/repo"
worktree="$tmp/worktree"
vm_tmp="$tmp/vm"
session="$tmp/session"
bridge_socket="$tmp/openai-bridge.sock"
console="$tmp/console.log"
listener_log="$tmp/host-listener.log"
host_auth="$tmp/host-auth"
helper_record="$tmp/helper-record"
upstream_ready="$tmp/upstream-ready"
upstream_record="$tmp/upstream-record.json"
mkdir -p "$repo" "$vm_tmp" "$session"
placeholder_payload=$(printf '%s' '{"https://api.openai.com/auth":{"chatgpt_account_id":"live-test"}}' \
  | base64 -w0 | tr '+/' '-_' | tr -d '=')
guest_token="e30.$placeholder_payload.e30"
printf '{"openai-codex":{"type":"oauth","access":"%s","refresh":"placeholder","expires":4102444800000}}\n' \
  "$guest_token" >"$session/auth.json"
printf '{"providers":{"openai-codex":{"baseUrl":"http://10.0.2.100:8645"}}}\n' >"$session/models.json"
printf '{"transport":"sse"}\n' >"$session/settings.json"
printf 'host secret\n' > "$tmp/host-secret"
mkdir -m 0700 "$host_auth"
real_payload=$(printf '%s' '{"https://api.openai.com/auth":{"chatgpt_account_id":"real-live-account"}}' \
  | base64 -w0 | tr '+/' '-_' | tr -d '=')
real_token="pij-host-credential-marker-access.$real_payload.signature"
refresh_marker='pij-host-credential-marker-refresh'
printf '{"openai-codex":{"type":"oauth","access":"%s","refresh":"%s","expires":4102444800000}}\n' \
  "$real_token" "$refresh_marker" >"$host_auth/auth.json"
chmod 0600 "$host_auth/auth.json"

fake_pi="$tmp/pi"
cat >"$fake_pi" <<EOF
#!/bin/sh
printf '%s\n' "\$PWD|\$PI_CODING_AGENT_DIR|\$*" >>"$helper_record"
printf '{"openai-codex":{"type":"oauth","access":"%s","refresh":"%s","expires":4102444800000}}\\n' \
  "$real_token" "$refresh_marker" >"\$PI_CODING_AGENT_DIR/auth.json"
printf '%s\n' "$real_token"
EOF
chmod 0700 "$fake_pi"

session_runner=$(grep -oE '/nix/store/[^[:space:]'"'"']+-pij-session-runner/bin/pij-session-runner' "$PIJ_BIN" | head -n 1)
[[ -x $session_runner ]] || { echo "cannot locate pij-session-runner" >&2; exit 1; }

"$PYTHON" "$PWD/tests/pij-live-upstream.py" \
  --ready "$upstream_ready" --record "$upstream_record" &
upstream_pid=$!
for _ in $(seq 1 100); do
  [[ ! -s $upstream_ready ]] || break
  kill -0 "$upstream_pid" 2>/dev/null || { echo "fake upstream exited early" >&2; exit 1; }
  sleep 0.02
done
upstream_port=$(<"$upstream_ready")
[[ $upstream_port =~ ^[0-9]+$ ]] || { echo "fake upstream did not become ready" >&2; exit 1; }

git -C "$repo" init -q
git -C "$repo" config user.name "PIJ Live Test"
git -C "$repo" config user.email "pij-live@example.invalid"
printf 'host baseline\n' > "$repo/baseline.txt"
printf 'delete me\n' > "$repo/deletion-target.txt"
git -C "$repo" add baseline.txt deletion-target.txt
git -C "$repo" commit -qm baseline
git -C "$repo" worktree add -q -b pij-live "$worktree"
base_commit=$(git -C "$worktree" rev-parse HEAD)
printf '%s\n' "$base_commit" >"$session/base-commit"
git -C "$worktree" rev-parse --show-object-format >"$session/object-format"

"$SOCAT_BIN" -d -d TCP-LISTEN:0,bind=127.0.0.1,reuseaddr,fork EXEC:/bin/cat \
  2>"$listener_log" &
host_listener_pid=$!
blocked_host_port=
for _ in $(seq 1 100); do
  while IFS= read -r line; do
    if [[ $line =~ listening\ on\ AF=2\ 127\.0\.0\.1:([0-9]+)$ ]]; then
      blocked_host_port=${BASH_REMATCH[1]}
    fi
  done <"$listener_log"
  [[ -z $blocked_host_port ]] || break
  kill -0 "$host_listener_pid" 2>/dev/null \
    || { sed -n '1,80p' "$listener_log" >&2; exit 1; }
  sleep 0.02
done
[[ $blocked_host_port =~ ^[0-9]+$ ]] \
  || { echo "failed to discover the host isolation probe port" >&2; exit 1; }

if ! env \
  QEMU_KERNEL_PARAMS="pij.selftest pij.blocked_host_port=$blocked_host_port" \
  TMPDIR="$vm_tmp" \
  USE_TMPDIR=1 \
  timeout 120 "$session_runner" \
  "$PYTHON" "$RELAY" "$fake_pi" "$host_auth" "$guest_token" \
  "http://127.0.0.1:$upstream_port/backend-api/codex/responses" \
  "$bridge_socket" "$tmp/openai-bridge.ready" "$VM_RUNNER" \
  -virtfs "local,path=$worktree,security_model=none,mount_tag=pij-worktree,multidevs=forbid" \
  -virtfs "local,path=$repo/.git/objects,security_model=none,mount_tag=pij-git-objects,readonly=on,multidevs=forbid" \
  -virtfs "local,path=$session,security_model=none,mount_tag=pij-session,readonly=on,multidevs=forbid" \
  -netdev "user,id=pij-net,restrict=on,guestfwd=tcp:10.0.2.100:8645-cmd:$SOCAT_BIN STDIO UNIX-CONNECT:$bridge_socket" \
  -device virtio-net-pci,netdev=pij-net >"$console" 2>&1; then
  sed -n '1,1000p' "$console" >&2
  exit 1
fi

wait "$upstream_pid"
upstream_pid=
[[ ! -e $bridge_socket ]] || { echo "session runner left its bridge socket" >&2; exit 1; }
[[ ! -e $tmp/openai-bridge.ready ]] || { echo "session runner left its ready marker" >&2; exit 1; }
expected_helper="$host_auth|$host_auth|auth print-bearer-token --provider openai-codex --min-expiry 30m"
[[ $(wc -l <"$helper_record") -eq 2 ]] \
  || { echo "bridge did not refresh once per guest connection" >&2; exit 1; }
while IFS= read -r helper_call; do
  [[ $helper_call == "$expected_helper" ]] \
    || { echo "bridge refresh helper escaped the dedicated auth store" >&2; exit 1; }
done <"$helper_record"
jq -s -e --arg token "$real_token" '
  length == 2 and
  (map(.path) == ["/backend-api/codex/responses", "/backend-api/codex/responses"]) and
  (map(.body) == [
    "{\"model\":\"fake-codex\",\"input\":\"pij-live-bridge-1\"}",
    "{\"model\":\"fake-codex\",\"input\":\"pij-live-bridge-2\"}"
  ]) and
  (map(.headers.authorization) == [("Bearer " + $token), ("Bearer " + $token)]) and
  (map(.headers."chatgpt-account-id") == ["real-live-account", "real-live-account"]) and
  all(.[]; ([.headers[] | select(contains($token))] | length) == 1)
' "$upstream_record" >/dev/null || {
  sed -n '1,20p' "$upstream_record" >&2
  echo "fake upstream observed an invalid bridge request" >&2
  exit 1
}

[[ $(<"$worktree/pij-live-test.txt") == "written by pij guest" ]] \
  || { echo "guest write did not reach host worktree" >&2; exit 1; }
guest_commit=$(<"$worktree/pij-live-commit.txt")
[[ $guest_commit =~ ^[0-9a-f]{40}$|^[0-9a-f]{64}$ ]] \
  || { echo "guest did not record its private Git commit" >&2; exit 1; }
[[ $(git -C "$worktree" rev-parse HEAD) == "$base_commit" ]] \
  || { echo "guest Git commit changed the host linked-worktree ref" >&2; exit 1; }
if git -C "$repo" cat-file -e "$guest_commit^{commit}" 2>/dev/null; then
  echo "guest private Git object escaped into the host common object store" >&2
  exit 1
fi
[[ $(<"$worktree/baseline.txt") == "corrupted by pij guest" ]] \
  || { echo "guest did not demonstrate accepted worktree corruption" >&2; exit 1; }
[[ ! -e "$worktree/deletion-target.txt" ]] \
  || { echo "guest did not demonstrate accepted worktree deletion" >&2; exit 1; }
[[ $(<"$tmp/host-secret") == "host secret" ]] \
  || { echo "unrelated host file changed" >&2; exit 1; }
for marker in "$real_token" "$refresh_marker" pij-host-credential-marker-; do
  for exposed in "$console" "$session" "$worktree"; do
    if grep -R -a -Fq -- "$marker" "$exposed"; then
      echo "host credential marker escaped into guest-visible state or console: $exposed" >&2
      exit 1
    fi
  done
done

printf 'pij live irreversible-boundary integration test passed\n'
