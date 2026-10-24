# dotfiles

NixOS and home-manager configuration for one machine. This repository is public on GitHub. Treat every committed byte as published.

## Secrets

- Never commit credentials, tokens, private keys, or machine-private values such as hostnames of private peers or device IDs you were not asked to add.
- The pre-commit hook runs gitleaks, private-key detection, nixfmt, statix, and deadnix. It is installed by `direnv allow` or `nix develop -c true` in the repo root.
- Do not bypass the hook (`--no-verify`, `-n`, `SKIP=`, `core.hooksPath`). When it fails, fix the finding. When gitleaks reports a false positive, stop and ask the operator.

## Verify

- `nix flake check` runs the hooks over the whole tree and a full gitleaks scan.
- `nix fmt` formats every Nix file.
- Build without activating: `nixos-rebuild build --flake .#dev`.
- Do not run `nixos-rebuild switch`, `home-manager switch`, or `sudo`. The operator activates.

## Conventions

- Conventional Commits (`feat(shell): ...`, `fix(nix): ...`).
- The Nix files in this repository are the single source of truth. Do not hand-edit generated files under `~/.config` or `~/.pi/agent`. Change the Nix module instead.
