{ pkgs, ... }: {
  programs.bash = {
    enable = true;
    shellAliases = {
      rebuild-dev = "sudo nixos-rebuild switch --flake ~/dotfiles#dev";
    };
  };
}
