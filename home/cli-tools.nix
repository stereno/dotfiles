{ pkgs, ... }:
{
  home.packages = with pkgs; [
    lazygit
    yazi
    btop
    bat
    fd
    jq
    eza
    claude-code
    opencode
    codex
    codex-acp
    tree
    ghq
  ];
}
