# The sandbox for one repository: the shared policy plus what the repository's
# default devShell puts on PATH and in the environment. A devShell can add
# sandbox arguments of its own through `passthru.agentSandbox`, for example
# `{ rwDirs = [ "$HOME/.cargo/registry" ]; }`.
{
  pkgs,
  agent-sandbox,
  policy,
  piWritableFiles,
  agent,
  root,
}:
let
  inherit (pkgs) lib;

  sandbox = policy {
    inherit pkgs piWritableFiles;
    inherit (agent-sandbox { inherit pkgs; }) mkSandbox commonTools;
  };

  shell = (builtins.getFlake root).devShells.${pkgs.stdenv.hostPlatform.system}.default;

  # mkShell flattens `env` into the derivation's attributes, so the attributes
  # an empty shell lacks are the repository's. The launcher expands each value
  # inside double quotes, so values a shell would rewrite are left out.
  env = lib.filterAttrs (
    _: value: lib.isString value && !lib.hasInfix "$" value && !lib.hasInfix "`" value
  ) (removeAttrs shell.drvAttrs (lib.attrNames (pkgs.mkShell { }).drvAttrs));
in
sandbox.mkAgentSandbox agent [
  {
    allowedPackages =
      shell.nativeBuildInputs
      ++ shell.buildInputs
      ++ shell.propagatedNativeBuildInputs
      ++ shell.propagatedBuildInputs
      # mkShell puts the C compiler on PATH implicitly, and linkers need it.
      ++ [ shell.stdenv.cc ]
      # A store path in an env value is readable only inside the closure.
      ++ lib.filter builtins.hasContext (lib.attrValues env);
    inherit env;
  }
  (shell.agentSandbox or { })
]
