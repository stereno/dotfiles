{ pkgs, ... }: {
  programs.bash = {
    enable = true;
    shellAliases = {
      rebuild-dev = "sudo nixos-rebuild switch --flake ~/dotfiles#dev";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
