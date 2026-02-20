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
  ];
}
