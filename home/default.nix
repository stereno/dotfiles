{ pkgs, ... }: {
  imports = [
    ./shell.nix
    ./git.nix
    ./dev.nix
    ./browser.nix
    ./hyprland.nix
    ./waybar.nix
    ./kitty.nix
    ./theme.nix
    ./dunst.nix
    ./wofi.nix
    ./hyprlock.nix
    ./wlogout.nix
  ];

  home.stateVersion = "25.11";
}
