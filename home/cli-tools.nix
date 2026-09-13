{ lib, pkgs, inputs, ... }:
let
  # Upstream Hermes still uses deprecated stdenv platform aliases. Build its
  # minimal package with equivalent current attributes and the full feature set.
  compatStdenv = pkgs.stdenv // {
    isLinux = pkgs.stdenv.hostPlatform.isLinux;
    isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  };
  hermesAgent = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.minimal.override {
    stdenv = compatStdenv;
    extraDependencyGroups = [
      "anthropic"
      "azure-identity"
      "bedrock"
      "daytona"
      "dingtalk"
      "edge-tts"
      "exa"
      "fal"
      "feishu"
      "firecrawl"
      "hindsight"
      "honcho"
      "messaging"
      "modal"
      "parallel-web"
      "tts-premium"
      "voice"
    ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ "matrix" ];
  };
in
{
  home.packages = with pkgs; [
    btop
    bat
    fd
    jq
    eza
    claude-code
    codex
    codex-acp
    herdr # agent-aware terminal multiplexer
    hermesAgent
    nodejs_22
    tree
    ghq
  ];

  xdg.configFile."herdr/config.toml".text = ''
    [keys]
    next_agent = "alt+j"
    previous_agent = "alt+k"
    navigate_workspace_up = "k"
    navigate_workspace_down = "j"
  '';

  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "y";
    extraPackages = with pkgs; [
      fd
      ripgrep
      fzf
      zoxide
    ];
  };

  programs.lazygit = {
    enable = true;
    enableFishIntegration = true;
    settings.git.pagers = [
      {
        colorArg = "always";
        pager = "delta --dark --paging=never";
      }
    ];
  };
}
