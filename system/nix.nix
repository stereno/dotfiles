{ lib, ... }: {
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    sandbox = true;
    sandbox-fallback = false;
    trusted-users = lib.mkForce [ "root" ];
  };
  nixpkgs.config.allowUnfree = true;
}
