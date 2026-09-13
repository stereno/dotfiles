#!/usr/bin/env bash
set -euo pipefail

PIJ_BIN=${PIJ_BIN:-"$PWD/result/bin/pij"}
PIJ_HERDR_TEST_BIN=${PIJ_HERDR_TEST_BIN:-}
PI_AGENT=${PI_AGENT:-}
PI_SESSION_SHELL=${PI_SESSION_SHELL:-}
VM_RUNNER=${VM_RUNNER:-}
GUEST_CONFIG=${GUEST_CONFIG:-system/pi-sandbox/guest.nix}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack=$1 needle=$2
  [[ $haystack == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack=$1 needle=$2
  [[ $haystack != *"$needle"* ]] || fail "expected output not to contain: $needle"
}

[[ -x $PI_SESSION_SHELL ]] || fail "PI session shell is unavailable"
pi_session_command=$(tr -d '\\' <"$PI_SESSION_SHELL" | tr '\n' ' ' | tr -s '[:space:]' ' ')
assert_contains "$pi_session_command" \
  '--provider openai-codex --model gpt-5.6-terra --thinking medium --no-extensions --no-approve'
model_catalog=$(find "$PI_AGENT" -path '*/providers/data/openai-codex.json' -print -quit)
[[ -f $model_catalog ]] || fail "pinned Pi OpenAI Codex model catalog is unavailable"
grep -Fq -- '"gpt-5.6-terra"' "$model_catalog" \
  || fail "reviewed main model is absent from the pinned Pi catalog"

help_output=$($PIJ_BIN --help)
assert_contains "$help_output" "pij run [WORKTREE]"
assert_contains "$help_output" "read-write"
assert_contains "$help_output" "Pi Coding Agent 0.85.1"
assert_not_contains "$help_output" "__run-child"
for removed in snapshot --revision --disk-size --output --relay-config pi-submit synthetic; do
  assert_not_contains "$help_output" "$removed"
done

for removed_command in snapshot; do
  if $PIJ_BIN "$removed_command" >/dev/null 2>"$(mktemp)"; then
    fail "accepted removed command: $removed_command"
  fi
done

non_repo=$(mktemp -d)
repo=$(mktemp -d)
capture=$(mktemp -d)
trap 'rm -rf -- "$non_repo" "$repo" "$capture"' EXIT

if $PIJ_BIN run "$non_repo" >/dev/null 2>"$capture/non-repo.err"; then
  fail "accepted a non-Git directory"
fi
assert_contains "$(<"$capture/non-repo.err")" "not a Git worktree"

if $PIJ_BIN run . "$non_repo" >/dev/null 2>"$capture/too-many.err"; then
  fail "accepted more than one worktree argument"
fi
assert_contains "$(<"$capture/too-many.err")" "too many worktree arguments"

git -C "$repo" init -q
if $PIJ_BIN run "$repo" >/dev/null 2>"$capture/standalone.err"; then
  fail "accepted a standalone checkout instead of a Herdr-style linked worktree"
fi
assert_contains "$(<"$capture/standalone.err")" "linked Git worktree"

git -C "$repo" config user.name "PIJ Contract Test"
git -C "$repo" config user.email "pij-contract@example.invalid"
git -C "$repo" commit --allow-empty -qm baseline
linked_worktree="$capture/linked-worktree"
git -C "$repo" worktree add -q -b pij-contract "$linked_worktree"

mkdir -p "$linked_worktree/home"
if HOME="$linked_worktree/home" $PIJ_BIN run "$linked_worktree" \
  >/dev/null 2>"$capture/auth-inside-worktree.err"; then
  fail "accepted an auth store inside the guest-visible worktree"
fi
assert_contains "$(<"$capture/auth-inside-worktree.err")" \
  "dedicated OpenAI auth store overlaps a guest-visible Git path"

symlink_home="$capture/symlink-home"
mkdir -p "$symlink_home"
ln -s "$linked_worktree" "$symlink_home/.local"
if HOME="$symlink_home" $PIJ_BIN run "$linked_worktree" \
  >/dev/null 2>"$capture/auth-parent-symlink.err"; then
  fail "accepted an auth store redirected into the worktree by a parent symlink"
fi
assert_contains "$(<"$capture/auth-parent-symlink.err")" \
  "dedicated OpenAI auth store overlaps a guest-visible Git path"

for required in \
  'local,path=$worktree,security_model=none,mount_tag=pij-worktree,multidevs=forbid' \
  'local,path=$git_objects_dir,security_model=none,mount_tag=pij-git-objects,readonly=on,multidevs=forbid' \
  'mount_tag=pij-session,readonly=on,multidevs=forbid' \
  'guestfwd=tcp:10.0.2.100:8645-cmd:' \
  'socat STDIO UNIX-CONNECT:$bridge_socket' \
  'restrict=on' \
  'model-relay.py' \
  'pij-session-runner' \
  '{"https://api.openai.com/auth": {"chatgpt_account_id": $account}}' \
  'path cannot be represented safely in QEMU -virtfs' \
  'systemd-run' \
  '--service-type=exec' \
  'KillMode=control-group' \
  'MemoryMax=6G' \
  'MemorySwapMax=0' \
  'CPUQuota=400%' \
  'TasksMax=512' \
  'RuntimeMaxSec=2h' \
  'HERDR_AGENT=pi systemd-run'; do
  grep -Fq -- "$required" "$PIJ_BIN" || fail "generated launcher lacks: $required"
done

if grep -Fq -- 'path=$git_common_dir,security_model=none,mount_tag=pij-git-common' "$PIJ_BIN"; then
  fail "generated launcher exposes the shared Git common directory"
fi

session_runner=$(grep -oE '/nix/store/[^[:space:]'"'"']+-pij-session-runner/bin/pij-session-runner' "$PIJ_BIN" | head -n 1)
[[ -x $session_runner ]] || fail "generated launcher lacks its systemd-owned session runner"
handoff_helper=$(grep -oE '/nix/store/[^[:space:]'"'"']+-pij-herdr-handoff/bin/pij-herdr-handoff' "$PIJ_BIN" | head -n 1)
[[ -x $handoff_helper ]] || fail "generated launcher lacks its Herdr handoff helper"
assert_not_contains "$(<"$handoff_helper")" "pij-handoff-fault-injector"
for required_session in \
  '"$vm_runner" "$@" <&0 &' \
  'wait -n -p completed "$bridge_pid" "$vm_pid"' \
  '--upstream-url "$upstream_url"' \
  'kill "$bridge_pid"' \
  'kill "$vm_pid"'; do
  grep -Fq -- "$required_session" "$session_runner" \
    || fail "session runner lacks lifecycle contract: $required_session"
done

cat >"$capture/fake-herdr" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >>"$PIJ_FAKE_HERDR_LOG"
if [ "$1 $2" = 'pane split' ]; then
  : >"$PIJ_FAKE_HERDR_STATE"
fi
case "$1 $2:${PIJ_FAKE_HERDR_MODE}" in
  'pane split:split-fail') exit 1 ;;
  'pane split:split-malformed') printf '%s\n' '{"result":{"pane":{}}}' ;;
  'pane split:split-invalid') printf '%s\n' '{"result":{"pane":{"pane_id":"invalid"}}}' ;;
  'pane split:split-existing') printf '%s\n' '{"result":{"pane":{"pane_id":"w1:pA"}}}' ;;
  'pane split:split-wrong') printf '%s\n' '{"result":{"pane":{"pane_id":"w1:pY"}}}' ;;
  'pane split:opaque-workspace') printf '%s\n' '{"result":{"pane":{"pane_id":"wE:pX"}}}' ;;
  'pane split:'*) printf '%s\n' '{"result":{"pane":{"pane_id":"w1:pX"}}}' ;;
  'pane list:'*)
    if [ ! -e "$PIJ_FAKE_HERDR_STATE" ] && [ "$PIJ_FAKE_HERDR_MODE" = before-list-fail ]; then
      exit 1
    elif [ ! -e "$PIJ_FAKE_HERDR_STATE" ] && [ "$PIJ_FAKE_HERDR_MODE" = before-list-malformed ]; then
      printf '%s\n' '{"result":{}}'
    elif [ -e "$PIJ_FAKE_HERDR_STATE" ] && [ "$PIJ_FAKE_HERDR_MODE" = after-list-fail ]; then
      exit 1
    elif [ -e "$PIJ_FAKE_HERDR_STATE" ] && [ "$PIJ_FAKE_HERDR_MODE" = after-list-malformed ]; then
      printf '%s\n' '{"result":{}}'
    elif [ ! -e "$PIJ_FAKE_HERDR_STATE" ] && [ "$PIJ_FAKE_HERDR_MODE" = opaque-workspace ]; then
      printf '%s\n' '{"result":{"panes":[{"workspace_id":"wE","pane_id":"wE:pA","focused":true}]}}'
    elif [ "$PIJ_FAKE_HERDR_MODE" = opaque-workspace ]; then
      printf '%s\n' '{"result":{"panes":[{"workspace_id":"wE","pane_id":"wE:pA","focused":false},{"workspace_id":"wE","pane_id":"wE:pX","focused":true}]}}'
    elif [ ! -e "$PIJ_FAKE_HERDR_STATE" ]; then
      printf '%s\n' '{"result":{"panes":[{"workspace_id":"w1","pane_id":"w1:pA","focused":true}]}}'
    elif [ "$PIJ_FAKE_HERDR_MODE" = split-ambiguous ]; then
      printf '%s\n' '{"result":{"panes":[{"workspace_id":"w1","pane_id":"w1:pA","focused":false},{"workspace_id":"w1","pane_id":"w1:pX","focused":true},{"workspace_id":"w1","pane_id":"w1:pZ","focused":false}]}}'
    else
      printf '%s\n' '{"result":{"panes":[{"workspace_id":"w1","pane_id":"w1:pA","focused":false},{"workspace_id":"w1","pane_id":"w1:pX","focused":true}]}}'
    fi
    ;;
  'pane run:run-fail') exit 1 ;;
  'pane run:async-stalled') exit 0 ;;
  'pane run:async-invalid')
    (
      while [ ! -e "$PIJ_FAKE_ASYNC_GATE" ]; do sleep 0.02; done
      PIJ_FAKE_CHILD_PANE=w1:pY sh -c "$4" || true
      : >"$PIJ_FAKE_ASYNC_DONE"
    ) </dev/null >/dev/null 2>&1 &
    ;;
  'pane run:opaque-workspace') HERDR_PANE_ID=wE:pX sh -c "$4" || true ;;
  'pane run:main-success') HERDR_PANE_ID=w1:pX sh -c "$4" || true ;;
  'pane run:'*) sh -c "$4" ;;
  'pane close:'*) exit 0 ;;
  *) exit 1 ;;
esac
EOF
cat >"$capture/fake-launcher" <<'EOF'
#!/bin/sh
printf 'HOME=%s\n' "$HOME" >"$PIJ_FAKE_CHILD_RECORD"
printf 'HERDR_AGENT=%s\n' "$HERDR_AGENT" >>"$PIJ_FAKE_CHILD_RECORD"
printf 'argc=%s\n' "$#" >>"$PIJ_FAKE_CHILD_RECORD"
printf 'arg=%s\n' "$@" >>"$PIJ_FAKE_CHILD_RECORD"
"$PIJ_HANDOFF_HELPER" consume-child "$2" "$3" "${PIJ_FAKE_CHILD_PANE:-w1:pX}"
EOF
chmod +x "$capture/fake-herdr" "$capture/fake-launcher"
export PIJ_FAKE_HERDR_LOG="$capture/herdr.log"
export PIJ_FAKE_CHILD_RECORD="$capture/child.record"
export PIJ_FAKE_HERDR_STATE="$capture/herdr.state"
export PIJ_FAKE_ASYNC_DONE="$capture/async.done"
export PIJ_FAKE_ASYNC_GATE="$capture/async.gate"
export PIJ_HANDOFF_HELPER="$handoff_helper"

for failed_mode in \
  before-list-fail before-list-malformed after-list-fail after-list-malformed \
  split-fail split-malformed split-invalid split-existing split-wrong split-ambiguous; do
  rm -f "$PIJ_FAKE_HERDR_STATE"
  : >"$capture/herdr.log"
  if PIJ_FAKE_HERDR_MODE=$failed_mode "$handoff_helper" handoff \
    "$capture/fake-herdr" w1:pA "$capture/fake-launcher" "$capture/home" "$linked_worktree" \
    2>"$capture/$failed_mode.err"; then
    fail "Herdr handoff accepted split mode: $failed_mode"
  fi
  if grep -Fq 'pane close ' "$capture/herdr.log"; then
    fail "Herdr handoff guessed which pane to close after $failed_mode"
  fi
done

: >"$capture/herdr.log"
rm -f "$PIJ_FAKE_HERDR_STATE"
special_home="$capture/home with ' quote"
special_worktree="$capture/worktree with ' quote"
PIJ_FAKE_HERDR_MODE=success "$handoff_helper" handoff \
  "$capture/fake-herdr" w1:pA "$capture/fake-launcher" "$special_home" "$special_worktree" \
  >"$capture/handoff.out"
assert_contains "$(<"$capture/herdr.log")" "pane split w1:pA --direction right --focus"
assert_contains "$(<"$capture/child.record")" "HOME=$special_home"
assert_contains "$(<"$capture/child.record")" "HERDR_AGENT=pi"
assert_contains "$(<"$capture/child.record")" "argc=4"
assert_contains "$(<"$capture/child.record")" "arg=__run-child"
assert_contains "$(<"$capture/child.record")" "arg=$special_worktree"

mapfile -t child_args < <(grep '^arg=' "$capture/child.record" | cut -d= -f2-)
[[ ${#child_args[@]} -eq 4 ]] || fail "Herdr child invocation has an unexpected shape"
if "$handoff_helper" consume-child "${child_args[1]}" "${child_args[2]}" w1:pX \
  2>"$capture/replayed-claim.err"; then
  fail "Herdr handoff accepted a replayed one-time child claim"
fi

for async_mode in async-stalled async-invalid; do
  : >"$capture/herdr.log"
  rm -f "$PIJ_FAKE_HERDR_STATE" "$PIJ_FAKE_ASYNC_DONE" \
    "$PIJ_FAKE_ASYNC_GATE" "$capture/helper-returned"
  (
    PIJ_FAKE_HERDR_MODE=$async_mode "$handoff_helper" handoff \
      "$capture/fake-herdr" w1:pA "$capture/fake-launcher" "$capture/home" "$linked_worktree" \
      >"$capture/$async_mode.out"
    : >"$capture/helper-returned"
  ) &
  helper_pid=$!
  for _ in {1..100}; do
    [ ! -e "$capture/helper-returned" ] || break
    sleep 0.01
  done
  if [ ! -e "$capture/helper-returned" ]; then
    : >"$PIJ_FAKE_ASYNC_GATE"
    kill "$helper_pid" 2>/dev/null || true
    wait "$helper_pid" 2>/dev/null || true
    fail "Herdr handoff waited for asynchronous child acknowledgement: $async_mode"
  fi
  wait "$helper_pid"
  if grep -Fq 'pane close ' "$capture/herdr.log"; then
    fail "Herdr handoff closed a pane after asynchronous run acceptance: $async_mode"
  fi
  async_state=$(grep -oE '/tmp/pij-herdr-handoff\.[A-Za-z0-9]{10}' \
    "$capture/herdr.log" | tail -n 1)
  if [ "$async_mode" = async-invalid ]; then
    : >"$PIJ_FAKE_ASYNC_GATE"
    for _ in {1..60}; do
      [ ! -e "$PIJ_FAKE_ASYNC_DONE" ] || break
      sleep 0.05
    done
    [ -e "$PIJ_FAKE_ASYNC_DONE" ] \
      || fail "delayed invalid child did not complete"
    [ ! -e "$async_state" ] && [ ! -e "$async_state.claimed" ] \
      || fail "invalid delayed child left claim state"
  else
    rm -rf -- "$async_state" "$async_state.claimed"
  fi
done

: >"$capture/herdr.log"
rm -f "$PIJ_FAKE_HERDR_STATE"
if PIJ_FAKE_HERDR_MODE=run-fail "$handoff_helper" handoff \
  "$capture/fake-herdr" w1:pA "$capture/fake-launcher" "$capture/home" "$linked_worktree" \
  2>"$capture/run-fail.err"; then
  fail "Herdr handoff accepted pane run failure"
fi
grep -Fq 'pane close w1:pX' "$capture/herdr.log" \
  || fail "Herdr handoff did not close a split pane after run failure"
if compgen -G '/tmp/pij-herdr-handoff.*' >/dev/null; then
  fail "Herdr handoff left one-time state after pane run failure"
fi

if [ -n "$PIJ_HERDR_TEST_BIN" ]; then
  early_claim=$(mktemp -d /tmp/pij-herdr-handoff.XXXXXXXXXX)
  early_token=$(printf 'a%.0s' {1..64})
  printf '%s\n%s\n' w1:pX "$early_token" >"$early_claim/claim"
  chmod 0700 "$early_claim"
  chmod 0600 "$early_claim/claim"
  printf -v early_child_command \
    'env HERDR_ENV=1 HERDR_PANE_ID=w1:pX HOME=%q %q __run-child %q %q %q' \
    "$capture/early-home" "$PIJ_HERDR_TEST_BIN" "$early_claim" "$early_token" \
    "$capture/nonexistent-worktree"
  if script -qefc "$early_child_command" /dev/null \
    >"$capture/early-child.log" 2>&1; then
    fail "internal Herdr child accepted a nonexistent worktree"
  fi
  [ ! -e "$early_claim" ] && [ ! -e "$early_claim.claimed" ] \
    || fail "internal Herdr child did not consume its claim before Git validation"
  assert_contains "$(<"$capture/early-child.log")" "worktree path does not exist"

  for setup_fault in mktemp chmod token claim command; do
    : >"$capture/herdr.log"
    rm -f "$PIJ_FAKE_HERDR_STATE"
    printf -v setup_failure_command \
      'env HERDR_ENV=1 HERDR_PANE_ID=w1:pA PIJ_FAKE_HERDR_MODE=main-success PIJ_FAKE_HANDOFF_FAULT=%q PIJ_FAKE_HERDR_DRIVER=%q PIJ_FAKE_HERDR_LOG=%q HOME=%q %q run %q' \
      "$setup_fault" "$capture/fake-herdr" "$capture/herdr.log" "$capture/setup-home" \
      "$PIJ_HERDR_TEST_BIN" "$linked_worktree"
    if script -qefc "$setup_failure_command" /dev/null \
      >"$capture/setup-$setup_fault.log" 2>&1; then
      fail "generated PIJ launcher accepted handoff setup failure: $setup_fault"
    fi
    grep -Fq 'pane close w1:pX' "$capture/herdr.log" \
      || fail "handoff setup failure did not close its known pane: $setup_fault"
    if compgen -G '/tmp/pij-herdr-handoff.*' >/dev/null; then
      fail "handoff setup failure left one-time state: $setup_fault"
    fi
  done

  : >"$capture/herdr.log"
  rm -f "$PIJ_FAKE_HERDR_STATE"
  printf -v main_command \
    'env HERDR_ENV=1 HERDR_PANE_ID=w1:pA PIJ_HERDR_CHILD_PANE=w1:pA PIJ_FAKE_HERDR_MODE=main-success PIJ_FAKE_HERDR_DRIVER=%q PIJ_FAKE_HERDR_LOG=%q HOME=%q %q run %q' \
    "$capture/fake-herdr" "$capture/herdr.log" "$capture/main-home" \
    "$PIJ_HERDR_TEST_BIN" "$linked_worktree"
  script -qefc "$main_command" /dev/null >"$capture/main-handoff.log" 2>&1 \
    || fail "generated PIJ launcher failed its Herdr handoff path"
  assert_contains "$(<"$capture/main-handoff.log")" "opened dedicated Herdr agent pane w1:pX"
  grep -Fq 'pane split w1:pA --direction right --focus' "$capture/herdr.log" \
    || fail "generated PIJ launcher did not always split from an interactive Herdr pane"
  grep -Fq 'pane run w1:pX' "$capture/herdr.log" \
    || fail "generated PIJ launcher did not run its dedicated child"

  : >"$capture/herdr.log"
  rm -f "$PIJ_FAKE_HERDR_STATE"
  printf -v opaque_workspace_command \
    'env HERDR_ENV=1 HERDR_PANE_ID=wE:pA PIJ_FAKE_HERDR_MODE=opaque-workspace PIJ_FAKE_HERDR_DRIVER=%q PIJ_FAKE_HERDR_LOG=%q HOME=%q %q run %q' \
    "$capture/fake-herdr" "$capture/herdr.log" "$capture/main-home" \
    "$PIJ_HERDR_TEST_BIN" "$linked_worktree"
  script -qefc "$opaque_workspace_command" /dev/null \
    >"$capture/opaque-workspace.log" 2>&1 \
    || fail "generated PIJ launcher rejected an opaque Herdr workspace ID"
  assert_contains "$(<"$capture/opaque-workspace.log")" \
    "opened dedicated Herdr agent pane wE:pX"

  for invalid_pane_id in wa:p1 wI:p1 wL:p1 wO:p1 wU:p1; do
    : >"$capture/herdr.log"
    rm -f "$PIJ_FAKE_HERDR_STATE"
    printf -v invalid_pane_command \
      'env HERDR_ENV=1 HERDR_PANE_ID=%q PIJ_FAKE_HERDR_MODE=main-success PIJ_FAKE_HERDR_DRIVER=%q PIJ_FAKE_HERDR_LOG=%q HOME=%q %q run %q' \
      "$invalid_pane_id" "$capture/fake-herdr" "$capture/herdr.log" "$capture/main-home" \
      "$PIJ_HERDR_TEST_BIN" "$linked_worktree"
    if script -qefc "$invalid_pane_command" /dev/null \
      >"$capture/invalid-pane.log" 2>&1; then
      fail "generated PIJ launcher accepted unsupported Herdr pane ID: $invalid_pane_id"
    fi
    assert_contains "$(<"$capture/invalid-pane.log")" \
      "Herdr did not provide a valid current pane ID"
    [[ ! -s $capture/herdr.log ]] \
      || fail "generated PIJ launcher invoked Herdr for unsupported pane ID: $invalid_pane_id"
  done

  : >"$capture/herdr.log"
  rm -f "$PIJ_FAKE_HERDR_STATE"
  printf -v main_failure_command \
    'env HERDR_ENV=1 HERDR_PANE_ID=w1:pA PIJ_FAKE_HERDR_MODE=split-fail PIJ_FAKE_HERDR_DRIVER=%q PIJ_FAKE_HERDR_LOG=%q HOME=%q %q run %q' \
    "$capture/fake-herdr" "$capture/herdr.log" "$capture/main-home" \
    "$PIJ_HERDR_TEST_BIN" "$linked_worktree"
  if script -qefc "$main_failure_command" /dev/null \
    >"$capture/main-handoff-failure.log" 2>&1; then
    fail "generated PIJ launcher accepted a failed Herdr split"
  fi
  assert_contains "$(<"$capture/main-handoff-failure.log")" \
    "could not create a dedicated Herdr pane for PIJ"
fi

sleep_bin=$(command -v sleep)
cat >"$capture/fake-python" <<EOF
#!/bin/sh
ready=
socket=
while [ "\$#" -gt 0 ]; do
  case \$1 in
    --ready) ready=\$2; shift 2 ;;
    --socket) socket=\$2; shift 2 ;;
    *) shift ;;
  esac
done
printf '%s\n' "\$\$" >"$capture/bridge.pid"
: >"\$socket"
: >"\$ready"
trap 'exit 0' TERM INT HUP
while :; do "$sleep_bin" 1; done
EOF
cat >"$capture/fake-vm" <<EOF
#!/bin/sh
printf '%s\n' "\$\$" >"$capture/vm.pid"
"$sleep_bin" 0.1
EOF
chmod +x "$capture/fake-python" "$capture/fake-vm"
"$session_runner" \
  "$capture/fake-python" ignored ignored ignored ignored \
  http://127.0.0.1:1/backend-api/codex/responses \
  "$capture/bridge.sock" "$capture/bridge.ready" "$capture/fake-vm"
bridge_pid=$(<"$capture/bridge.pid")
kill -0 "$bridge_pid" 2>/dev/null && fail "session runner left bridge alive after VM exit"
[[ ! -e $capture/bridge.sock ]] || fail "session runner left the bridge socket after VM exit"
[[ ! -e $capture/bridge.ready ]] || fail "session runner left the bridge readiness marker after VM exit"

cat >"$capture/tty-vm" <<EOF
#!/bin/sh
[ -t 0 ] || exit 41
stty raw -echo
stty -a >"$capture/service-tty.state"
EOF
chmod +x "$capture/tty-vm"
if ! script -qefc \
  "$session_runner $capture/fake-python ignored ignored ignored ignored http://127.0.0.1:1/backend-api/codex/responses $capture/tty-bridge.sock $capture/tty-bridge.ready $capture/tty-vm" \
  /dev/null >"$capture/tty-session.log" 2>&1; then
  sed -n '1,80p' "$capture/tty-session.log" >&2
  fail "session runner failed under a PTY"
fi
tty_state=$(<"$capture/service-tty.state")
assert_contains "$tty_state" "-icanon"
assert_contains "$tty_state" "-isig"
assert_contains "$tty_state" "-echo"

cat >"$capture/failing-python" <<EOF
#!/bin/sh
ready=
while [ "\$#" -gt 0 ]; do
  if [ "\$1" = --ready ]; then ready=\$2; shift 2; else shift; fi
done
: >"\$ready"
"$sleep_bin" 0.1
exit 1
EOF
cat >"$capture/slow-vm" <<EOF
#!/bin/sh
printf '%s\n' "\$\$" >"$capture/slow-vm.pid"
trap 'exit 0' TERM INT HUP
while :; do "$sleep_bin" 1; done
EOF
chmod +x "$capture/failing-python" "$capture/slow-vm"
if "$session_runner" \
  "$capture/failing-python" ignored ignored ignored ignored \
  http://127.0.0.1:1/backend-api/codex/responses \
  "$capture/failing.sock" "$capture/failing.ready" "$capture/slow-vm" \
  >/dev/null 2>"$capture/failing.err"; then
  fail "session runner accepted bridge exit while VM was running"
fi
assert_contains "$(<"$capture/failing.err")" "bridge exited while the VM was running"
slow_vm_pid=$(<"$capture/slow-vm.pid")
kill -0 "$slow_vm_pid" 2>/dev/null && fail "session runner left VM alive after bridge exit"

if grep -Fq -- 'guestfwd=tcp:10.0.2.100:8645-unix:' "$PIJ_BIN"; then
  fail "generated launcher reuses one Unix chardev instead of spawning a connector per guest connection"
fi

for obsolete in \
  'workspace.img' \
  'PI_WORKSPACE' \
  'PI_EXPORT' \
  'validate-export.py' \
  'input.bundle' \
  'mkfs.ext4' \
  'commit-tree' \
  'bundle create'; do
  if grep -Fq -- "$obsolete" "$PIJ_BIN"; then
    fail "generated launcher retains obsolete artifact path: $obsolete"
  fi
done

for required_guest in \
  'device = "pij-worktree";' \
  'device = "pij-git-objects";' \
  'device = "pij-session";' \
  'fsType = "9p";' \
  '"trans=virtio"' \
  '"version=9p2000.L"' \
  '"msize=1048576"' \
  '"cache=none"' \
  '"rw"' \
  '"ro"' \
  '"nodev"' \
  '"nosuid"' \
  'mount --bind /run/pij/gitdir /workspace/repo/.git' \
  'git init --bare --quiet' \
  'printf "/workspace/git-objects\n" > /workspace/home/git/objects/info/alternates' \
  'refs/heads/pij-session' \
  'cp /run/pij/session/auth.json /workspace/home/.pi/agent/auth.json' \
  'cp /run/pij/session/models.json /workspace/home/.pi/agent/models.json' \
  'cp /run/pij/session/settings.json /workspace/home/.pi/agent/settings.json' \
  'corrupted by pij guest' \
  'rm deletion-target.txt' \
  'credential_marker_prefix="pij-host-credential-"' \
  'find "$guest_root" -xdev -type f -readable -print0' \
  '/dev/shm' \
  '/run /run/pij/session' \
  'scan_guest_root "$guest_root"' \
  'ip route replace default via 10.0.2.2 dev eth0' \
  'GH_TOKEN' \
  'GITHUB_TOKEN' \
  '/workspace/home/.config/gh/hosts.yml' \
  '/dev/tcp/10.0.2.2/$blocked_host_port' \
  '/dev/tcp/10.0.2.100/8645' \
  'for request_number in 1 2' \
  '/dev/tcp/1.1.1.1/80' \
  'address = "10.0.2.15";' \
  'cd /workspace/repo' \
  'mountHostNixStore = false;' \
  'writableStore = false;' \
  'sharedDirectories = lib.mkForce { };'; do
  grep -Fq -- "$required_guest" "$GUEST_CONFIG" || fail "guest config lacks: $required_guest"
done

if grep -Fq -- '/workspace/git-common' "$GUEST_CONFIG"; then
  fail "guest config retains the shared Git common-directory mount"
fi

[[ $(grep -Fc 'scan_guest_state' "$GUEST_CONFIG") -eq 3 ]] \
  || fail "guest credential state scan must run before and after relay requests"
mapfile -t scan_call_lines < <(grep -nE '^      scan_guest_state$' "$GUEST_CONFIG")
request_loop_line=$(grep -nF 'for request_number in 1 2' "$GUEST_CONFIG")
request_loop_line=${request_loop_line%%:*}
[[ ${#scan_call_lines[@]} -eq 2 ]] \
  || fail "guest credential state scan must have exactly two call sites"
first_scan_line=${scan_call_lines[0]%%:*}
second_scan_line=${scan_call_lines[1]%%:*}
(( first_scan_line < request_loop_line && request_loop_line < second_scan_line )) \
  || fail "guest credential state scans must bracket relay requests"

if grep -Fq -- '[[ -r $proc_file ]] || continue' "$GUEST_CONFIG"; then
  fail "guest process scan may not skip unreadable userspace process state"
fi

for obsolete_guest in PI_WORKSPACE PI_EXPORT pi-submit input.bundle; do
  if grep -Fq -- "$obsolete_guest" "$GUEST_CONFIG"; then
    fail "guest config retains obsolete artifact path: $obsolete_guest"
  fi
done

if [[ -n $VM_RUNNER ]]; then
  grep -Fq -- '-nic none' "$VM_RUNNER" || fail "rendered VM runner does not disable the QEMU NIC"
  if grep -Fq -- 'mount_tag=pij-worktree' "$VM_RUNNER"; then
    fail "base VM runner unexpectedly hard-codes the dynamic worktree export"
  fi
  if grep -Fq -- 'mount_tag=pij-git-objects' "$VM_RUNNER"; then
    fail "base VM runner unexpectedly hard-codes the dynamic Git object export"
  fi
  if grep -Fq -- 'path=/nix/store,security_model=none,mount_tag=nix-store' "$VM_RUNNER"; then
    fail "rendered VM runner exposes the host Nix store"
  fi
fi

printf 'pij reduced writable-worktree contract tests passed\n'
