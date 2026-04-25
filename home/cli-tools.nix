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
    codex
    codex-acp
    tree
    ghq
  ];
}
