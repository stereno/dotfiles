{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;

  sandbox = import ./agent-sandbox/policy.nix {
    inherit pkgs;
    inherit (inputs.agent-sandbox.lib.${system}) mkSandbox commonTools;
    piWritableFiles = config.dotfiles.pi.writableFiles;
  };

  # Evaluated at launch against the repository the agent starts in. The
  # interpolated store paths keep this generation's nixpkgs and policy alive.
  devShellExpr = pkgs.writeText "agent-sandbox-devshell.nix" ''
    { agent, root }:
    import ${./agent-sandbox/devshell.nix} {
      inherit agent root;
      pkgs = import ${inputs.nixpkgs} {
        system = "${system}";
        config.allowUnfree = true;
      };
      agent-sandbox = import ${inputs.agent-sandbox};
      policy = import ${./agent-sandbox/policy.nix};
      piWritableFiles = [ ${
        lib.concatMapStringsSep " " builtins.toJSON config.dotfiles.pi.writableFiles
      } ];
    }
  '';

  # Inside a repository with a flake, the agent runs over the tools of its
  # devShell. Elsewhere, and when that build fails, it runs without them.
  mkLauncher =
    name: agent:
    let
      static = sandbox.mkAgentSandbox name [ ];
    in
    pkgs.writeShellApplication {
      name = agent.outName;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.git
      ];
      text = ''
        root=$(git rev-parse --show-toplevel 2>/dev/null) || root=$PWD
        if [[ ! -f $root/flake.nix ]]; then
          exec ${static}/bin/${agent.outName} "$@"
        fi

        # The same expression and Nix sources reuse the last build.
        key=$(
          {
            echo ${devShellExpr}
            cd "$root"
            cat flake.nix flake.lock 2>/dev/null || true
            git ls-files -z -- '*.nix' 2>/dev/null | xargs -0r cat
          } | sha256sum | cut -c1-32
        )
        out=''${XDG_CACHE_HOME:-$HOME/.cache}/agent-sandbox/${name}-$key

        if [[ ! -e $out ]]; then
          mkdir -p "$(dirname "$out")"
          echo "${agent.outName}: building the sandbox from $root's devShell" >&2
          if ! nix build --impure --out-link "$out" --file ${devShellExpr} \
            --argstr agent ${name} --argstr root "$root"; then
            echo "${agent.outName}: build failed, starting without the devShell" >&2
            exec ${static}/bin/${agent.outName} "$@"
          fi
        fi
        exec "$out/bin/${agent.outName}" "$@"
      '';
    };
in
{
  home.packages = lib.mapAttrsToList mkLauncher sandbox.agents;
}
