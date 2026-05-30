{ pkgs, ... }:
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
    nodejs_22
    tree
    ghq
  ];

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
