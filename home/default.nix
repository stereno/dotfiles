{ pkgs, ... }: {
  imports = [
    ./shell.nix
    ./git.nix
    ./dev.nix
    ./browser.nix
    ./theme.nix
    ./terminal.nix
  ];

  home.stateVersion = "25.11";
}
