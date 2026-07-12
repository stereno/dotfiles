{ pkgs, inputs, ... }:
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
    inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default
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
