{
  lib,
  writeShellApplication,
  coreutils,
  git,
  herdr,
  jq,
  piAgent,
  python3,
  socat,
  systemd,
  piAgentVersion,
  vmRunner,
  handoffFaultInjector ? null,
}:
let
  herdrHandoff = writeShellApplication {
    name = "pij-herdr-handoff";
    runtimeInputs = [
      coreutils
      jq
    ];
    text = ''
      action=''${1:-}
      shift || true
      case "$action" in
        handoff)
          [[ $# -eq 5 ]] || {
            printf 'pij-herdr-handoff: invalid handoff arguments\n' >&2
            exit 2
          }
          herdr_bin=$1
          pane_id=$2
          launcher=$3
          home=$4
          worktree=$5
          workspace_id=''${pane_id%%:*}
          panes_before=$("$herdr_bin" pane list 2>/dev/null) || {
            printf 'pij-herdr-handoff: failed to snapshot panes before splitting\n' >&2
            exit 1
          }
          pane_ids_before=$(jq -cer \
            --arg workspace_id "$workspace_id" --arg pane_id "$pane_id" '
              [.result.panes[] | select(.workspace_id == $workspace_id) | .pane_id] as $ids |
              if ($ids | index($pane_id)) != null then $ids else error("caller pane missing") end
            ' <<<"$panes_before") || {
            printf 'pij-herdr-handoff: Herdr returned an invalid pane snapshot\n' >&2
            exit 1
          }
          split=$(
            "$herdr_bin" pane split "$pane_id" --direction right --focus
          ) || {
            printf 'pij-herdr-handoff: failed to create a dedicated pane\n' >&2
            exit 1
          }
          handoff_pane=$(jq -er '.result.pane.pane_id | select(type == "string")' <<<"$split") || {
            printf 'pij-herdr-handoff: Herdr returned an invalid split pane\n' >&2
            exit 1
          }
          [[ $handoff_pane =~ ^w[0-9A-HJKMNP-TV-Z]+:p[0-9A-HJKMNP-TV-Z]+$ ]] || {
            printf 'pij-herdr-handoff: Herdr returned an unsupported split pane ID\n' >&2
            exit 1
          }
          if [ "''${handoff_pane%%:*}" != "$workspace_id" ] \
            || jq -e --arg pane_id "$handoff_pane" 'index($pane_id) != null' \
              <<<"$pane_ids_before" >/dev/null; then
            printf 'pij-herdr-handoff: Herdr did not return the newly created pane\n' >&2
            exit 1
          fi
          panes_after=$("$herdr_bin" pane list 2>/dev/null) || {
            printf 'pij-herdr-handoff: failed to verify the split pane\n' >&2
            exit 1
          }
          created_pane=$(jq -er \
            --arg workspace_id "$workspace_id" --argjson before "$pane_ids_before" '
              [.result.panes[] |
                .pane_id as $id |
                select(.workspace_id == $workspace_id and ($before | index($id)) == null) |
                $id] |
              if length == 1 then .[0] else error("ambiguous split delta") end
            ' <<<"$panes_after") || {
            printf 'pij-herdr-handoff: could not identify a unique split pane\n' >&2
            exit 1
          }
          [ "$created_pane" = "$handoff_pane" ] || {
            printf 'pij-herdr-handoff: split response did not match the created pane\n' >&2
            exit 1
          }
          handoff_state=
          cleanup_handoff() {
            "$herdr_bin" pane close "$handoff_pane" >/dev/null 2>&1 || true
            [ -z "$handoff_state" ] || rm -rf -- "$handoff_state"
          }
          trap cleanup_handoff EXIT
          ${lib.optionalString (handoffFaultInjector != null) ''
            ${lib.escapeShellArg "${handoffFaultInjector}/bin/pij-handoff-fault-injector"} mktemp
          ''}
          handoff_state=$(mktemp -d /tmp/pij-herdr-handoff.XXXXXXXXXX)
          ${lib.optionalString (handoffFaultInjector != null) ''
            ${lib.escapeShellArg "${handoffFaultInjector}/bin/pij-handoff-fault-injector"} chmod
          ''}
          chmod 0700 "$handoff_state"
          ${lib.optionalString (handoffFaultInjector != null) ''
            ${lib.escapeShellArg "${handoffFaultInjector}/bin/pij-handoff-fault-injector"} token
          ''}
          handoff_token=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
          ${lib.optionalString (handoffFaultInjector != null) ''
            ${lib.escapeShellArg "${handoffFaultInjector}/bin/pij-handoff-fault-injector"} claim
          ''}
          printf '%s\n%s\n' "$handoff_pane" "$handoff_token" >"$handoff_state/claim"
          chmod 0600 "$handoff_state/claim"
          ${lib.optionalString (handoffFaultInjector != null) ''
            ${lib.escapeShellArg "${handoffFaultInjector}/bin/pij-handoff-fault-injector"} command
          ''}
          printf -v command 'HOME=%q HERDR_AGENT=pi %q __run-child %q %q %q' \
            "$home" "$launcher" "$handoff_state" "$handoff_token" "$worktree"
          if ! "$herdr_bin" pane run "$handoff_pane" "$command"; then
            printf 'pij-herdr-handoff: failed to start PIJ in its dedicated pane\n' >&2
            exit 1
          fi
          trap - EXIT
          printf '%s\n' "$handoff_pane"
          ;;
        consume-child)
          [[ $# -eq 3 ]] || {
            printf 'pij-herdr-handoff: invalid child claim arguments\n' >&2
            exit 2
          }
          handoff_state=$1
          handoff_token=$2
          pane_id=$3
          [[ $handoff_state =~ ^/tmp/pij-herdr-handoff\.[A-Za-z0-9]{10}$ ]] \
            && [[ $handoff_token =~ ^[a-f0-9]{64}$ ]] \
            && [[ $pane_id =~ ^w[0-9A-HJKMNP-TV-Z]+:p[0-9A-HJKMNP-TV-Z]+$ ]] \
            && [ -d "$handoff_state" ] \
            && [ ! -L "$handoff_state" ] \
            && [ -O "$handoff_state" ] \
            && [ "$(stat -c '%a' -- "$handoff_state")" = 700 ] || {
            printf 'pij-herdr-handoff: invalid child handoff state\n' >&2
            exit 1
          }
          claimed_state="$handoff_state.claimed"
          mv -T -- "$handoff_state" "$claimed_state" || {
            printf 'pij-herdr-handoff: child handoff state was already consumed\n' >&2
            exit 1
          }
          trap 'rm -rf -- "$claimed_state"' EXIT
          [ -f "$claimed_state/claim" ] \
            && [ ! -L "$claimed_state/claim" ] \
            && [ -O "$claimed_state/claim" ] \
            && [ "$(stat -c '%a' -- "$claimed_state/claim")" = 600 ] \
            && [ "$(stat -c '%h' -- "$claimed_state/claim")" = 1 ] \
            && mapfile -t claim <"$claimed_state/claim" \
            && [ "''${#claim[@]}" -eq 2 ] \
            && [ "''${claim[0]}" = "$pane_id" ] \
            && [ "''${claim[1]}" = "$handoff_token" ] || {
            printf 'pij-herdr-handoff: child handoff claim did not match this pane\n' >&2
            exit 1
          }
          ;;
        *)
          printf 'pij-herdr-handoff: unknown action\n' >&2
          exit 2
          ;;
      esac
    '';
  };
  sessionRunner = writeShellApplication {
    name = "pij-session-runner";
    runtimeInputs = [ coreutils ];
    text = ''
      [[ $# -ge 9 ]] || {
        printf 'pij-session-runner: invalid arguments\n' >&2
        exit 2
      }

      python=$1
      bridge=$2
      pi_bin=$3
      auth_store=$4
      guest_token=$5
      upstream_url=$6
      bridge_socket=$7
      bridge_ready=$8
      vm_runner=$9
      shift 9

      bridge_pid=
      vm_pid=
      # Invoked through the traps below.
      # shellcheck disable=SC2329
      cleanup_session() {
        local status=$?
        trap - EXIT HUP INT TERM
        if [[ -n $vm_pid ]]; then
          kill "$vm_pid" >/dev/null 2>&1 || true
          wait "$vm_pid" 2>/dev/null || true
        fi
        if [[ -n $bridge_pid ]]; then
          kill "$bridge_pid" >/dev/null 2>&1 || true
          wait "$bridge_pid" 2>/dev/null || true
        fi
        rm -f -- "$bridge_socket" "$bridge_ready"
        exit "$status"
      }
      trap cleanup_session EXIT
      trap 'exit 129' HUP
      trap 'exit 130' INT
      trap 'exit 143' TERM

      env -i \
        "$python" "$bridge" serve \
          --pi-bin "$pi_bin" \
          --agent-dir "$auth_store" \
          --guest-token "$guest_token" \
          --upstream-url "$upstream_url" \
          --socket "$bridge_socket" \
          --ready "$bridge_ready" &
      bridge_pid=$!
      for _ in $(seq 1 100); do
        [[ ! -e $bridge_ready ]] || break
        kill -0 "$bridge_pid" 2>/dev/null || {
          printf 'pij-session-runner: OpenAI credential bridge exited before becoming ready\n' >&2
          exit 1
        }
        sleep 0.05
      done
      [[ -e $bridge_ready ]] || {
        printf 'pij-session-runner: OpenAI credential bridge did not become ready\n' >&2
        exit 1
      }

      # In a non-interactive shell Bash otherwise gives an asynchronous
      # command /dev/null as stdin. QEMU needs the service PTY so it can put
      # the terminal in raw mode and forward Ctrl-key sequences to the guest.
      "$vm_runner" "$@" <&0 &
      vm_pid=$!
      completed=
      set +e
      wait -n -p completed "$bridge_pid" "$vm_pid"
      status=$?
      set -e
      if [[ $completed == "$bridge_pid" ]]; then
        bridge_pid=
        printf 'pij-session-runner: OpenAI credential bridge exited while the VM was running\n' >&2
        exit 1
      fi
      vm_pid=
      exit "$status"
    '';
  };
in
writeShellApplication {
  name = "pij";
  runtimeInputs = [
    coreutils
    git
    herdr
    jq
    piAgent
    python3
    socat
    systemd
  ];
  text = ''
    usage() {
      cat <<'USAGE'
Usage:
  pij run [WORKTREE]
  pij login
  pij logout

Starts Pi Coding Agent in a disposable NixOS QEMU/KVM guest with the selected
Herdr-managed linked Git worktree mounted read-write. Worktree damage is accepted,
while Git writes remain in disposable session-private metadata.
Reusable credentials and unrelated host files and sockets are not mounted.
Pi Coding Agent ${piAgentVersion} is pinned in the Nix flake.

Commands:
  run       Start Pi in the selected linked Git worktree.
  login     Open pinned Pi for OpenAI Codex login in a dedicated host store.
  logout    Remove the locally stored OpenAI Codex credential.

Options:
  -h, --help  Show this help.
USAGE
    }

    die() {
      printf 'pij: %s\n' "$*" >&2
      exit 1
    }

    reject_control_characters() {
      [[ ! $1 =~ [[:cntrl:]] ]] || die "arguments and resolved paths must not contain control characters"
    }

    auth_store=
    auth_file=
    ensure_auth_store() {
      validate_content=''${1:-1}
      [ -n "''${HOME:-}" ] || die "HOME is required for the dedicated OpenAI auth store"
      reject_control_characters "$HOME"
      auth_store="$HOME/.local/state/pij/openai-agent"
      auth_file="$auth_store/auth.json"

      if [ -L "$auth_store" ]; then
        die "dedicated OpenAI auth directory must not be a symlink"
      fi
      if [ -e "$auth_store" ]; then
        [ -d "$auth_store" ] || die "dedicated OpenAI auth path must be a directory"
        [ -O "$auth_store" ] || die "dedicated OpenAI auth directory must be owned by the invoking user"
        auth_mode=$(stat -c '%a' -- "$auth_store")
        [ "$((8#$auth_mode & 077))" -eq 0 ] || die "dedicated OpenAI auth directory must be private (mode 0700)"
      else
        old_umask=$(umask)
        umask 077
        mkdir -p -- "$auth_store"
        umask "$old_umask"
        chmod 0700 -- "$auth_store"
      fi

      if [ -L "$auth_file" ]; then
        die "dedicated OpenAI auth file must not be a symlink"
      fi
      if [ -e "$auth_file" ]; then
        [ -f "$auth_file" ] || die "dedicated OpenAI auth file must be a regular file"
        [ -O "$auth_file" ] || die "dedicated OpenAI auth file must be owned by the invoking user"
        auth_file_mode=$(stat -c '%a' -- "$auth_file")
        [ "$((8#$auth_file_mode & 077))" -eq 0 ] || die "dedicated OpenAI auth file must be private (mode 0600)"
        if [ "$validate_content" -eq 1 ]; then
          jq -e '
          type == "object" and
          (keys | all(. == "openai-codex")) and
          (."openai-codex"? // {type: "oauth", access: "", refresh: "", expires: 0} |
            type == "object" and .type == "oauth" and
            (.access | type == "string") and
            (.refresh | type == "string") and
            (.expires | type == "number"))
          ' "$auth_file" >/dev/null \
            || die "dedicated auth file must contain only a valid openai-codex OAuth credential"
        fi
      fi
    }

    login_openai() {
      ensure_auth_store
      printf 'pij: in Pi, run /login and select OpenAI (ChatGPT Plus/Pro); exit with Ctrl-D when login succeeds\n' >&2
      pi_bin=${lib.escapeShellArg "${piAgent}/bin/pi"}
      (
        cd "$auth_store"
        env -i \
          HOME="$HOME" \
          TERM="''${TERM:-xterm-256color}" \
          PI_CODING_AGENT_DIR="$auth_store" \
          PI_TELEMETRY=0 \
          PI_SKIP_VERSION_CHECK=1 \
          "$pi_bin" \
            --provider openai-codex \
            --no-tools \
            --no-extensions \
            --no-skills \
            --no-prompt-templates \
            --no-themes \
            --no-context-files \
            --no-session \
            --no-approve
      )
      ensure_auth_store
      [ -f "$auth_file" ] || die "OpenAI Codex login did not create auth.json"
      printf 'pij: OpenAI Codex credential stored in the dedicated host-only auth store\n' >&2
    }

    logout_openai() {
      ensure_auth_store 0
      auth_tmp=$(mktemp "$auth_store/.auth.json.XXXXXXXXXX")
      chmod 0600 "$auth_tmp"
      printf '{}\n' >"$auth_tmp"
      mv -f -- "$auth_tmp" "$auth_file"
      printf 'pij: local OpenAI Codex credential removed\n' >&2
    }

    for argument in "$@"; do
      reject_control_characters "$argument"
    done

    run_mode=public
    handoff_state=
    handoff_token=
    case ''${1:-} in
      -h|--help)
        usage
        exit 0
        ;;
      run)
        shift
        ;;
      __run-child)
        shift
        [ "$#" -ge 2 ] || die "invalid internal Herdr handoff"
        run_mode=child
        handoff_state=$1
        handoff_token=$2
        shift 2
        ;;
      login)
        shift
        [ "$#" -eq 0 ] || die "login does not accept arguments"
        login_openai
        exit 0
        ;;
      logout)
        shift
        [ "$#" -eq 0 ] || die "logout does not accept arguments"
        logout_openai
        exit 0
        ;;
      "")
        usage >&2
        exit 2
        ;;
      *)
        die "unknown command: $1"
        ;;
    esac

    handoff_helper=${lib.escapeShellArg "${herdrHandoff}/bin/pij-herdr-handoff"}
    if [ "$run_mode" = child ]; then
      [[ -t 0 ]] && [ "''${HERDR_ENV:-}" = 1 ] \
        || die "internal Herdr child must run in an interactive Herdr pane"
      [[ ''${HERDR_PANE_ID:-} =~ ^w[0-9A-HJKMNP-TV-Z]+:p[0-9A-HJKMNP-TV-Z]+$ ]] \
        || die "Herdr did not provide a valid current pane ID"
      "$handoff_helper" consume-child \
        "$handoff_state" "$handoff_token" "$HERDR_PANE_ID" \
        || die "invalid or already consumed internal Herdr handoff"
    fi

    requested_worktree=.
    worktree_argument_seen=0
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -h|--help)
          usage
          exit 0
          ;;
        -*)
          die "unknown option: $1"
          ;;
        *)
          [ "$worktree_argument_seen" -eq 0 ] || die "too many worktree arguments"
          requested_worktree=$1
          worktree_argument_seen=1
          ;;
      esac
      shift
    done

    requested_worktree=$(realpath -e -- "$requested_worktree" 2>/dev/null) \
      || die "worktree path does not exist"
    reject_control_characters "$requested_worktree"
    [ -d "$requested_worktree" ] || die "worktree path is not a directory"

    git_bin=${lib.escapeShellArg "${git}/bin/git"}
    herdr_bin=${lib.escapeShellArg "${herdr}/bin/herdr"}
    safe_git() {
      env -i \
        HOME=/homeless-shelter \
        GIT_CONFIG_NOSYSTEM=1 \
        GIT_CONFIG_GLOBAL=/dev/null \
        GIT_NO_LAZY_FETCH=1 \
        GIT_NO_REPLACE_OBJECTS=1 \
        GIT_OPTIONAL_LOCKS=0 \
        GIT_TERMINAL_PROMPT=0 \
        "$git_bin" \
          -c core.fsmonitor=false \
          -c core.hooksPath=/dev/null \
          -c credential.helper= \
          -c diff.external= \
          -c protocol.allow=never \
          "$@"
    }

    worktree=$(safe_git -C "$requested_worktree" rev-parse --show-toplevel 2>/dev/null) \
      || die "not a Git worktree: $requested_worktree"
    worktree=$(realpath -e -- "$worktree" 2>/dev/null) \
      || die "failed to canonicalize Git worktree"
    reject_control_characters "$worktree"
    [ -f "$worktree/.git" ] && [ ! -L "$worktree/.git" ] \
      || die "pij requires a Herdr-style linked Git worktree with a regular .git file"

    git_dir=$(safe_git -C "$worktree" rev-parse --absolute-git-dir 2>/dev/null) \
      || die "failed to resolve linked worktree Git directory"
    git_common_dir=$(safe_git -C "$worktree" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
      || die "failed to resolve Git common directory"
    git_dir=$(realpath -e -- "$git_dir" 2>/dev/null) \
      || die "failed to canonicalize linked worktree Git directory"
    git_common_dir=$(realpath -e -- "$git_common_dir" 2>/dev/null) \
      || die "failed to canonicalize Git common directory"
    git_objects_dir=$(realpath -e -- "$git_common_dir/objects" 2>/dev/null) \
      || die "failed to canonicalize Git object directory"
    reject_control_characters "$git_dir"
    reject_control_characters "$git_common_dir"
    reject_control_characters "$git_objects_dir"
    [ -d "$git_common_dir" ] && [ ! -L "$git_common_dir" ] \
      || die "Git common directory must be a real directory"
    [ -d "$git_objects_dir" ] && [ ! -L "$git_common_dir/objects" ] \
      || die "Git object directory must be a real directory"
    [ "$git_objects_dir" = "$git_common_dir/objects" ] \
      || die "Git object directory escapes the Git common directory"
    case "$worktree$git_objects_dir" in
      *,*) die "path cannot be represented safely in QEMU -virtfs" ;;
    esac
    case "$git_dir" in
      "$git_common_dir"/worktrees/*) ;;
      *) die "linked worktree metadata is outside the Git common directory" ;;
    esac
    git_dir_name=''${git_dir#"$git_common_dir/worktrees/"}
    [[ "$git_dir_name" =~ ^[A-Za-z0-9._-]+$ ]] \
      || die "linked worktree metadata name is unsupported"
    [ "$git_dir" = "$git_common_dir/worktrees/$git_dir_name" ] \
      || die "nested linked worktree metadata is unsupported"
    base_commit=$(safe_git -C "$worktree" rev-parse --verify 'HEAD^{commit}' 2>/dev/null) \
      || die "linked worktree HEAD is not a local commit"
    [[ $base_commit =~ ^[0-9a-f]{40}$|^[0-9a-f]{64}$ ]] \
      || die "linked worktree HEAD has an unsupported object ID"
    safe_git -C "$worktree" cat-file -e "$base_commit^{commit}" 2>/dev/null \
      || die "linked worktree HEAD commit is unavailable locally"
    object_format=$(safe_git -C "$worktree" rev-parse --show-object-format 2>/dev/null) \
      || die "failed to resolve Git object format"
    [[ $object_format == sha1 || $object_format == sha256 ]] \
      || die "Git object format is unsupported"

    if [ "$run_mode" = public ] && [[ -t 0 ]] && [ "''${HERDR_ENV:-}" = 1 ]; then
      [[ ''${HERDR_PANE_ID:-} =~ ^w[0-9A-HJKMNP-TV-Z]+:p[0-9A-HJKMNP-TV-Z]+$ ]] \
        || die "Herdr did not provide a valid current pane ID"
      handoff_pane=$(
        "$handoff_helper" handoff \
          "$herdr_bin" "$HERDR_PANE_ID" "$0" "$HOME" "$worktree"
      ) || die "could not create a dedicated Herdr pane for PIJ"
      printf 'pij: opened dedicated Herdr agent pane %s\n' "$handoff_pane" >&2
      exit 0
    fi

    ensure_auth_store
    auth_store_real=$(realpath -e -- "$auth_store" 2>/dev/null) \
      || die "failed to canonicalize the dedicated OpenAI auth store"
    reject_control_characters "$auth_store_real"
    for guest_visible_path in "$worktree" "$git_objects_dir"; do
      case "$auth_store_real/" in
        "$guest_visible_path/"*)
          die "dedicated OpenAI auth store overlaps a guest-visible Git path"
          ;;
      esac
      case "$guest_visible_path/" in
        "$auth_store_real/"*)
          die "dedicated OpenAI auth store overlaps a guest-visible Git path"
          ;;
      esac
    done
    [ -f "$auth_file" ] || die "OpenAI Codex credential is missing; run pij login first"
    auth_file_real=$(realpath -e -- "$auth_file" 2>/dev/null) \
      || die "failed to canonicalize the dedicated OpenAI auth file"
    reject_control_characters "$auth_file_real"
    [ "$(dirname -- "$auth_file_real")" = "$auth_store_real" ] \
      || die "dedicated OpenAI auth file must remain inside its private store"
    jq -e '."openai-codex".access | type == "string" and length > 0' "$auth_file" >/dev/null \
      || die "OpenAI Codex credential is missing; run pij login first"

    runner=${lib.escapeShellArg "${vmRunner}/bin/run-pi-sandbox-vm"}
    [ -x "$runner" ] || die "VM runner is not executable: $runner"

    workdir=$(mktemp -d /tmp/pij.XXXXXXXXXX)
    service_started=0

    unit="pij-''${workdir##*.}"
    cleanup() {
      local status=$?
      if [ "$service_started" -eq 1 ]; then
        systemctl --user stop "$unit" >/dev/null 2>&1 || true
      fi

      rm -rf -- "$workdir"
      return "$status"
    }
    trap cleanup EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    vm_tmp="$workdir/vm"
    session_dir="$workdir/session"
    mkdir -p "$vm_tmp" "$session_dir"
    chmod 0700 "$session_dir"

    placeholder_account="pij-$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
    placeholder_payload=$(jq -cn --arg account "$placeholder_account" \
      '{"https://api.openai.com/auth": {"chatgpt_account_id": $account}}' \
      | base64 -w0 | tr '+/' '-_' | tr -d '=')
    guest_token="e30.$placeholder_payload.e30"
    jq -cn --arg token "$guest_token" '{
      "openai-codex": {
        "type": "oauth",
        "access": $token,
        "refresh": "pij-non-secret-placeholder",
        "expires": 4102444800000
      }
    }' >"$session_dir/auth.json"
    jq -cn '{
      "providers": {
        "openai-codex": {
          "baseUrl": "http://10.0.2.100:8645"
        }
      }
    }' >"$session_dir/models.json"
    printf '{"transport":"sse"}\n' >"$session_dir/settings.json"
    printf '%s\n' "$base_commit" >"$session_dir/base-commit"
    printf '%s\n' "$object_format" >"$session_dir/object-format"
    chmod 0600 \
      "$session_dir/auth.json" \
      "$session_dir/models.json" \
      "$session_dir/settings.json" \
      "$session_dir/base-commit" \
      "$session_dir/object-format"

    bridge_socket="$workdir/openai-bridge.sock"
    bridge_ready="$workdir/openai-bridge.ready"
    pi_bin=${lib.escapeShellArg "${piAgent}/bin/pi"}
    bridge=${lib.escapeShellArg ./model-relay.py}
    python=${lib.escapeShellArg "${python3}/bin/python3"}
    session_runner=${lib.escapeShellArg "${sessionRunner}/bin/pij-session-runner"}

    printf 'pij: mounting linked worktree read-write: %s\n' "$worktree" >&2
    printf 'pij: host Git metadata is read-only; guest Git writes are disposable; exit with Ctrl-D\n' >&2


    cleanup_exec=${lib.escapeShellArg "${coreutils}/bin/rm"}
    service_started=1
    if HERDR_AGENT=pi systemd-run \
      --user \
      --unit="$unit" \
      --service-type=exec \
      --wait \
      --pty \
      --quiet \
      --collect \
      --property="ExecStopPost=$cleanup_exec -rf -- $workdir" \
      --property=KillMode=control-group \
      --property=TimeoutStopSec=30s \
      --property=MemoryMax=6G \
      --property=MemorySwapMax=0 \
      --property=CPUQuota=400% \
      --property=TasksMax=512 \
      --property=RuntimeMaxSec=2h \
      -- \
      env -i \
        TERM=xterm-256color \
        TMPDIR="$vm_tmp" \
        USE_TMPDIR=1 \
        "$session_runner" \
          "$python" \
          "$bridge" \
          "$pi_bin" \
          "$auth_store" \
          "$guest_token" \
          https://chatgpt.com/backend-api/codex/responses \
          "$bridge_socket" \
          "$bridge_ready" \
          "$runner" \
          -virtfs "local,path=$worktree,security_model=none,mount_tag=pij-worktree,multidevs=forbid" \
          -virtfs "local,path=$git_objects_dir,security_model=none,mount_tag=pij-git-objects,readonly=on,multidevs=forbid" \
          -virtfs "local,path=$session_dir,security_model=none,mount_tag=pij-session,readonly=on,multidevs=forbid" \
          -netdev "user,id=pij-net,restrict=on,guestfwd=tcp:10.0.2.100:8645-cmd:${socat}/bin/socat STDIO UNIX-CONNECT:$bridge_socket" \
          -device virtio-net-pci,netdev=pij-net; then
      vm_status=0
    else
      vm_status=$?
    fi
    service_started=0
    [ "$vm_status" -eq 0 ] || die "isolated VM exited unsuccessfully (status $vm_status)"
    printf 'pij: VM exited; changes remain in %s\n' "$worktree" >&2
  '';
}
