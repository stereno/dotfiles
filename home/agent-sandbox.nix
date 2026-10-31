{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (inputs.agent-sandbox.lib.${pkgs.stdenv.hostPlatform.system}) mkSandbox commonTools;

  common = {
    allowedPackages = commonTools ++ [ pkgs.gh ];
    allowNix = true;
    allowUnixSockets = true;
    rwDirs = [ "$HOME/.claude" ];
    roFiles = [
      "$HOME/.config/git/config"
      "/etc/nix/nix.conf"
      "$HOME/.config/herdr/herdr.sock"
    ];
    # Values are shell expressions expanded at launch under `set -u`. The `-`
    # defaults keep a launch outside herdr from failing, and `|| true` one with
    # gh logged out.
    env = {
      CLAUDE_CONFIG_DIR = "$HOME/.claude";
      GITHUB_TOKEN = "$(${lib.getExe pkgs.gh} auth token 2>/dev/null || true)";
    }
    // lib.genAttrs [
      "HERDR_ENV"
      "HERDR_SOCKET_PATH"
      "HERDR_PANE_ID"
      "HERDR_TAB_ID"
      "HERDR_WORKSPACE_ID"
    ] (name: "\${${name}-}");
  };

  agents = {
    claude = {
      pkg = pkgs.claude-code;
      binName = "claude";
      outName = "claude-sandboxed";
    };
    pi = {
      pkg = pkgs.pi-coding-agent;
      binName = "pi";
      outName = "pi-sandboxed";
      # The pi-claude-code backend spawns `claude`.
      allowedPackages = [ pkgs.claude-code ];
      # Declared directly so the launcher follows its symlinks. The
      # working-tree files they land on need their own binds.
      rwDirs = [ "$HOME/.pi/agent" ];
      rwFiles = config.dotfiles.pi.writableFiles;
    };
  };

  # Lists concatenate and attrsets merge, so an agent names only what it adds.
  merge = lib.zipAttrsWith (
    _: values:
    if lib.length values == 1 then
      lib.head values
    else if lib.isList (lib.head values) then
      lib.concatLists values
    else
      lib.mergeAttrsList values
  );
in
{
  home.packages = lib.mapAttrsToList (
    _: agent:
    mkSandbox (merge [
      common
      agent
    ])
  ) agents;
}
