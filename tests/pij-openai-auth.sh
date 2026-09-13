#!/usr/bin/env bash
set -euo pipefail

PIJ_BIN=${PIJ_BIN:-"$PWD/result/bin/pij"}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack=$1 needle=$2
  [[ $haystack == *"$needle"* ]] || fail "expected output to contain: $needle"
}

mode() {
  stat -c '%a' -- "$1"
}

root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT

help_output=$($PIJ_BIN --help)
assert_contains "$help_output" "pij login"
assert_contains "$help_output" "pij logout"
assert_contains "$help_output" "OpenAI Codex"

home="$root/home"
mkdir -p "$home"
HOME="$home" $PIJ_BIN logout
auth_dir="$home/.local/state/pij/openai-agent"
auth_file="$auth_dir/auth.json"
[[ -d $auth_dir && ! -L $auth_dir ]] || fail "logout did not create a real dedicated auth directory"
[[ $(mode "$auth_dir") == 700 ]] || fail "auth directory is not mode 0700"
[[ -f $auth_file && ! -L $auth_file ]] || fail "logout did not create a regular auth file"
[[ $(mode "$auth_file") == 600 ]] || fail "auth file is not mode 0600"
[[ $(<"$auth_file") == '{}' ]] || fail "logout did not clear the dedicated auth file"

credential_marker='pij-test-access-token-must-not-be-printed'
printf '{"openai-codex":{"type":"oauth","access":"%s","refresh":"refresh-marker","expires":4102444800000}}\n' \
  "$credential_marker" >"$auth_file"
chmod 0600 "$auth_file"
logout_output=$(HOME="$home" $PIJ_BIN logout 2>&1)
[[ $logout_output != *"$credential_marker"* ]] || fail "logout printed credential material"
[[ $(<"$auth_file") == '{}' ]] || fail "logout did not replace an existing credential"

printf '{"openai-codex":{"type":"oauth","access":"a","refresh":"r","expires":4102444800000},"github":{"type":"api_key","key":"secret"}}\n' \
  >"$auth_file"
chmod 0600 "$auth_file"
logout_output=$(HOME="$home" $PIJ_BIN logout 2>&1)
[[ $logout_output != *"secret"* ]] || fail "logout printed an unexpected credential"
[[ $(<"$auth_file") == '{}' ]] || fail "logout did not clear an unexpected provider credential"

rm "$auth_file"
ln -s "$root" "$auth_file"
if HOME="$home" $PIJ_BIN logout >"$root/file-symlink.out" 2>"$root/file-symlink.err"; then
  fail "accepted a symlinked auth file"
fi
assert_contains "$(<"$root/file-symlink.err")" "auth file must not be a symlink"

rm -rf -- "$auth_dir"
ln -s "$root" "$auth_dir"
if HOME="$home" $PIJ_BIN logout >"$root/symlink.out" 2>"$root/symlink.err"; then
  fail "accepted a symlinked auth directory"
fi
assert_contains "$(<"$root/symlink.err")" "must not be a symlink"

rm "$auth_dir"
mkdir "$auth_dir"
chmod 0755 "$auth_dir"
if HOME="$home" $PIJ_BIN logout >"$root/public.out" 2>"$root/public.err"; then
  fail "accepted an auth directory accessible by group or other users"
fi
assert_contains "$(<"$root/public.err")" "must be private"

for required in \
  'PI_CODING_AGENT_DIR="$auth_store"' \
  '--provider openai-codex' \
  'auth.json' \
  'openai-codex'; do
  grep -Fq -- "$required" "$PIJ_BIN" || fail "generated launcher lacks auth-store contract: $required"
done

printf 'pij dedicated OpenAI auth-store tests passed\n'