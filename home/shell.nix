{ pkgs, ... }: {
  programs.fish = {
    enable = true;
    shellAbbrs = {
      # NixOS rebuild
      nrs = "sudo nixos-rebuild switch --flake ~/dotfiles#$(hostname)";
      nrt = "sudo nixos-rebuild test --flake ~/dotfiles#$(hostname)";

      # Git
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline";
      gd = "git diff";

      # eza
      ls = "eza";
      ll = "eza -la";
      lt = "eza --tree";
    };
  };

  programs.bash.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
