{ ... }:
{
  imports = [
    ./shell.nix
    ./git.nix
    ./dev.nix
    ./browser.nix
    ./theme.nix
    ./terminal.nix
    ./tmux.nix
    ./obsidian.nix
    ./neovim.nix
    ./cli-tools.nix
    ./pi.nix
    ./agent-sandbox.nix
  ];

  home.stateVersion = "25.11";
}
