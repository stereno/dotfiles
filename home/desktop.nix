{ pkgs, ... }: {
  imports = [
    ./core.nix
    ./terminal.nix
    ./browser.nix
    ./theme.nix
    ./obsidian.nix
    ./dev.nix
  ];
}
