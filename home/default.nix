{ pkg, ... }: {
  imports = [
    ./shell.nix
    ./git.nix
    ./dev.nix
    ./browser.nix
  ];

  home.stateVersion = "25.11";
}
