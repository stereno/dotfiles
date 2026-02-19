{ pkgs, ... }: {
  imports = [
    ./shell.nix
    ./git.nix
    ./dev.nix
    ./browser.nix
    ./theme.nix
    ./terminal.nix
    ./tmux.nix
    ./obsidian.nix
  ];

  home.stateVersion = "25.11";
}
