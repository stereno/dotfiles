{ ... }: {
  imports = [
    ./nix.nix
    ./locale.nix
    ./desktop.nix
    ./remote-desktop.nix
    ./tailscale.nix
    ./syncthing.nix
    ./pi-sandbox/host.nix
  ];
}
