{
  description = "Development shell with sandboxed coding agents";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    agent-sandbox = {
      url = "github:archie-judd/agent-sandbox.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, agent-sandbox, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "claude-code";
      };
      inherit (pkgs) lib;
      inherit (agent-sandbox.lib.${system}) mkSandbox commonTools;

      # Tools for developing this repository. The shell and the agents both get
      # them, so an agent builds and tests with what you do.
      devTools = [ ];

      common = {
        allowedPackages = commonTools ++ devTools ++ [ pkgs.gh ];
        # The agent cannot reach the nix daemon or read the store beyond
        # allowedPackages. Add a tool to devTools rather than running nix.
        allowUnixSockets = true;
        # Writes reach only the listed hosts. Every other host is read-only, so
        # documentation and package registries need no entry. Blocked requests
        # are logged to proxy.log under ~/.local/state/agent-sandbox/<session>.
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
        # Values are shell expressions expanded at launch under `set -u`, so
        # secrets stay out of the store. The `-` defaults keep a launch outside
        # herdr from failing, and `|| true` one with gh logged out.
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
          # The pi-claude-code backend spawns `claude`. pi installs npm packages
          # with `npm`.
          allowedPackages = [
            pkgs.claude-code
            pkgs.nodejs
          ];
          # The OpenCode and xAI subscriptions are pi providers. pi-web-access
          # searches through Exa's MCP endpoint, which takes POST.
          allowedDomains = {
            "opencode.ai" = "*";
            "x.ai" = "*";
            "exa.ai" = "*";
          };
          # Without the key pi-web-access falls back to the rate-limited
          # keyless MCP.
          env.EXA_API_KEY = "$(cat \"$HOME/.config/exa/api-key\" 2>/dev/null || true)";
          # ~/.pi/agent links these into the dotfiles checkout, and the
          # launcher binds only what is declared, so each target needs its own
          # bind.
          rwDirs = [ "$HOME/.pi/agent" ];
          rwFiles = map (name: "$HOME/dotfiles/home/pi/${name}") [
            "settings.json"
            "mcp.json"
            "pstack-models.md"
            "web-search.json"
          ];
        };
      };

      # Lists concatenate and attrsets merge, so an agent names only what it
      # adds.
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
      devShells.${system}.default = pkgs.mkShell {
        packages =
          devTools
          ++ lib.mapAttrsToList (
            _: agent:
            mkSandbox (merge [
              common
              agent
            ])
          ) agents;
      };
    };
}
