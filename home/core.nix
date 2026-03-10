{ pkgs, ... }: {
  imports = [
    ./shell.nix
    ./git.nix
    ./neovim.nix
    ./tmux.nix
    ./cli-tools.nix
    ./claude.nix
  ];

  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "25.11";
}
