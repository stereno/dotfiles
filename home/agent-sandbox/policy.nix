# What every sandboxed agent gets, whichever directory it starts in. The
# home-manager module builds the wrappers from this as is; devshell.nix adds a
# repository's devShell. Self-contained, since devshell.nix imports it from the
# store.
{
  pkgs,
  mkSandbox,
  commonTools,
  # Working-tree files that ~/.pi/agent links to and pi writes.
  piWritableFiles,
}:
let
  inherit (pkgs) lib;

  common = {
    allowedPackages = commonTools ++ [ pkgs.gh ];
    # Nix stays out: the agent cannot reach the daemon or read the store beyond
    # allowedPackages. Work on this repository runs outside the sandbox.
    allowUnixSockets = true;
    # Writes reach only the listed hosts. Every other host is read-only, so
    # documentation and package registries need no entry. Blocked requests are
    # logged to proxy.log under ~/.local/state/agent-sandbox/<session>.
    allowedDomains = {
      "anthropic.com" = "*";
      "claude.com" = "*";
      "github.com" = "*";
      "githubusercontent.com" = [
        "GET"
        "HEAD"
      ];
      "*" = [
        "GET"
        "HEAD"
      ];
    };
    rwDirs = [ "$HOME/.claude" ];
    roFiles = [
      "$HOME/.config/git/config"
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
      # pi installs npm packages with `npm`.
      allowedPackages = [ pkgs.nodejs ];
      # The OpenCode and xAI subscriptions are pi providers. pi-web-access
      # searches through Exa's MCP endpoint, which takes POST.
      allowedDomains = {
        "opencode.ai" = "*";
        "x.ai" = "*";
        "exa.ai" = "*";
      };
      # The key lives outside the repository. Without it pi-web-access falls
      # back to the rate-limited keyless MCP.
      env.EXA_API_KEY = "$(cat \"$HOME/.config/exa/api-key\" 2>/dev/null || true)";
      # Declared directly so the launcher follows its symlinks. The
      # working-tree files they land on need their own binds.
      rwDirs = [ "$HOME/.pi/agent" ];
      rwFiles = piWritableFiles;
    };
  };

  # Lists concatenate and attrsets merge, so an agent or a devShell names only
  # what it adds.
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
  inherit agents;

  mkAgentSandbox =
    name: extras:
    mkSandbox (
      merge (
        [
          common
          agents.${name}
        ]
        ++ extras
      )
    );
}
