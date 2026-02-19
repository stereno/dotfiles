{ ... }: {
  imports = [
    ./nix.nix
    ./locale.nix
    ./desktop.nix
    ./remote-desktop.nix
    ./tailscale.nix
  ];
}
