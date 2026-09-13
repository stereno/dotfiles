# Pi agent isolation roadmap

## Project definition

`pij` is a small whole-process launcher that runs Pi Coding Agent in a disposable
NixOS microVM over one Herdr-managed task worktree mounted read-write. Pi has broad
freedom inside that repository scope. Reusable credentials, unrelated host files and
sockets, and external write authority remain outside the guest.

Pi is the runtime actor. Herdr creates or selects the task worktree. Hermes may help
with planning, observation, scheduling, and reporting, but is not part of the runtime
security boundary.

## Implementation status

- R0: complete; README and roadmap now define the reduced contract.
- R1: complete and hardened; the linked worktree is exposed read-write, while only the
  host common object store is exposed read-only. Guest index, refs, and new objects live
  in disposable private metadata; `multidevs=forbid` constrains both dynamic exports.
- R2: complete; immutable ingress, workspace/export images, `pi-submit`, quarantine
  validation, and artifact publication have been removed.
- R3: complete; dedicated private OpenAI Codex auth-store login/logout is implemented.
- R4: complete; the fixed-route, SSE-only credential bridge refreshes and injects host
  identity without exposing reusable credentials to the guest.
- R5: complete; fake-upstream, real-KVM, process/filesystem marker, resource, network,
  and lifecycle checks cover the irreversible boundary.
- R6: complete; QEMU inherits the service PTY, and interactive Herdr launches always
  hand off to a dedicated focused Pi pane. Canonical, mutation, real-KVM, and independent
  review checks pass.
- N0: complete; the guest has only one restricted QEMU user-net path to the fixed
  OpenAI bridge and no general Internet access.

## Operating loop

1. Herdr creates or selects a dedicated worktree for one task.
2. The operator runs `pij run` for that worktree.
3. `pij` starts a disposable VM, mounts the worktree read-write, and starts Pi.
   The root session starts on `openai-codex` `gpt-5.6-terra` with `medium` thinking;
   this is an explicit startup preference, not bridge-level model enforcement.
4. Pi may edit, delete, build, test, run child processes, and use session-private Git
   freely. Its commits and staging state are disposable.
5. `Ctrl-D` stops the VM and removes its temporary state.
6. The host reviews the edits already present in the worktree.
7. Main-branch integration occurs only through a separate human-approved path.

`pij` does not create, select, delete, merge, or publish worktrees or branches.

## Security contract

### Recoverable damage that is accepted

- Corruption or deletion of the selected agent worktree.
- Loss of guest-local commits and staging state when the session ends.
- The need to recreate the worktree or clone the repository again.

Repository integrity is protected operationally by review and inexpensive recovery,
not by a trusted import/export pipeline. Host refs, config, indexes, linked-worktree
metadata, and writable object storage are outside guest authority. The host object store
is available read-only as the base for session-private Git history.

### Effects that remain protected

- OpenAI access and refresh credentials never enter Pi's filesystem, environment,
  process arguments, generated configuration, console output, or mounted worktree.
- Future GitHub credentials remain host-only, and no GitHub write is available until
  a separately approved operation-level broker exists.
- Host `$HOME`, credential stores, SSH agent, Nix daemon, container-engine sockets,
  D-Bus, and unrelated host files are not exposed.
- General network access is absent initially, so arbitrary guest processes cannot
  disclose private source to unapproved destinations.
- Host systemd limits VM CPU, memory, process count, and lifetime, and owns cleanup.

The VM remains the process, kernel, device, socket, credential, network, and resource
boundary. It is intentionally not an integrity boundary for the mounted repository.

## Reduced implementation phases

### R0 — Record the revised contract

Rewrite the README and this roadmap before deleting code. The writable-worktree risk,
credential boundary, offline network posture, and reduced completion criterion are the
authoritative project contract.

Exit criterion: documentation consistently describes the reduced product and the
flake evaluates with `nix flake check --no-build`.

### R1 — Prove a read-write Herdr worktree mount

Inspect the generated NixOS VM runner and test dynamic 9p/virtfs, virtiofs, and any
runner-supported share. Select the smallest mechanism that exposes only the intended
repository scope while supporting the actual linked-worktree layout.

Executable checks must prove:

- guest writes become visible in the host worktree;
- guest-local Git operations work without changing host refs, indexes, or object storage;
- unrelated host files, `$HOME`, SSH agent, Nix daemon, container sockets, D-Bus, and
  runtime sockets are absent;
- `Ctrl-D` stops the VM and transient service cleanup completes.

Use a session-private Git directory whose branch starts at the selected worktree HEAD.
Expose only the host object store read-only as an alternate; never expose the Git common
directory read-write. Do not reintroduce immutable artifact ingestion implicitly.

### R2 — Delete immutable ingress and artifact export

Remove `snapshot`, `--revision`, `--disk-size`, `--output`, synthetic baselines, input
bundles, ext4 workspace images, raw export devices, `pi-submit`, quarantine validation,
and canonical bundle publication. Keep only path validation needed to mount the
operator-selected worktree and lifecycle/resource controls needed to run the VM.

Exit criterion: the reduced command surface and R1 live tests pass, and obsolete
packages and tests are absent from the flake.

### R3 — Add a dedicated host OpenAI login store

Use a dedicated `PI_CODING_AGENT_DIR` containing only `openai-codex` OAuth state.
Provide an interactive host login command using the pinned Pi implementation. Reject a
store that is a symlink, is not private, or is not owned by the invoking user. Document
logout, revocation, and replacement.

The ordinary `~/.pi/agent` directory and future GitHub credentials must never be
combined with this store or mounted into the VM.

### R4 — Add a thin OpenAI credential bridge

Let guest Pi use its native OpenAI Codex Responses transport through a per-run private
connection. The bridge reads and refreshes only the dedicated credential, strips
guest-supplied authorization, account-routing, forwarding, and hop-by-hop headers,
then injects the current host access token and account ID immediately before forwarding.
It does not route providers, convert Chat Completions, enforce model/cost policy, or act
as a general HTTP proxy.

Before implementation, verify the pinned Pi source for SSE forcing, placeholder JWT and
account-ID assumptions, request paths, compression, streaming, and refresh writes.
Prefer SSE-only; add WebSocket proxying only if native Pi cannot operate without it.

### R5 — Verify the irreversible boundary

Fake-upstream and live-VM checks must prove worktree writability and accepted damage,
host isolation, credential non-disclosure, replacement of guest-supplied auth/account
headers, auth-store-confined refresh mutation, bridge shutdown, per-run cleanup, and VM
resource limits.

Run:

```bash
nix flake check --no-build
nix build .#checks.x86_64-linux.pij --no-link --print-build-logs
```

A real OpenAI smoke test requires explicit operator approval after fake-upstream tests
pass, and must not print credential material.

### R6 — Harden interactive TTY and Herdr ownership

Explicitly preserve the transient service PTY when QEMU is launched asynchronously so
Ctrl-key input reaches Pi. In Herdr, always create a dedicated pane and run the same
launcher there with shell-safe arguments, a private one-time child claim, and Herdr's
standard `HERDR_AGENT=pi` process hint. PIJ does not write shared lifecycle authority.
The one-time claim prevents accidental recursion and replay in the public launcher; it is
not a security boundary against an operator deliberately invoking internals as the same
host UID.

Executable checks cover PTY inheritance, failed or malformed splits, quoted paths,
early one-time child claim consumption, pane-run cleanup, and rejection of pre-existing pane
IDs. A valid response must also match the unique post-split pane-set delta. Malformed split
output fails without guessing which unrelated pane to close. A test-only derivation injects
failures at each known-pane setup stage and proves its pane/state cleanup. Asynchronous
fake children also prove the parent neither waits for claim acknowledgement nor closes on
startup delay; two- and five-second-wait mutations make the canonical check fail. A real
Herdr/KVM run must focus and show Pi independently, then power down on `Ctrl-D`.

## Network roadmap

### N0 — Model transport only

The first reduced version has no general Internet access. Only the fixed private OpenAI
credential bridge is reachable. It is not an arbitrary destination or method proxy.

### N1 — Centralized uncredentialed WebFetch

If research access becomes necessary, add a host-side read-only fetch capability with
no cookies, credentials, browser profile, or ambient proxy authority. Restrict it to
`GET`/`HEAD`; deny local, private, link-local, metadata, and host/LAN destinations before
and after DNS and redirects; bound redirects, time, compressed and expanded size, MIME
type, and output. Return provenance and treat all content as untrusted data.

Prompt injection is not solved by sanitization. Safety comes from ensuring fetched
content has no credentials or direct side-effect authority.

### N2 — Curated direct read access

Consider narrow official documentation and GitHub read access only after N1 is used.
A hostname allowlist is insufficient on shared hosts. Define host/path grammar, methods,
redirects, query policy, and request-size limits.

### N3 — Dependency acquisition

Package registries, releases, Git clones, and build downloads are a separate decision.
Use reviewed per-task grants, a mirror/cache, or explicit unrestricted access only for
public repositories. Do not turn WebFetch into generic upload or package egress.

## Optional future capabilities

These are not completion requirements for reduced `pij`:

- A GitHub operation broker with fixed repository ID and generated agent branch,
  narrow fetch/publish/PR/check operations, and no generic token or `gh api` access.
- Small per-worktree Pi state after disposable use demonstrates a need.
- Parent/worker orchestration, beginning with same-VM processes rather than sibling VMs.
- Resident or unattended operation, which requires a separate project decision.
- pstack integration.

## Completion criterion

Reduced `pij` is complete when a Herdr-managed worktree runs read-write inside a
disposable Pi VM; edits and local Git work; unrelated host authority and reusable
OpenAI/GitHub credentials remain outside Pi; native OpenAI Codex login works through the
host-only bridge; `Ctrl-D` stops and cleans up the VM and bridge; and the implementation
contains no artifact publisher, model-governance platform, orchestration service,
persistent cell manager, or resident scheduler.
