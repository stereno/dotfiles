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

  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      format = "$directory$git_branch$git_status$nix_shell$fill$time\n$character";

      character = {
        success_symbol = "[❯](bold #7aa2f7)";
        error_symbol = "[❯](bold #f7768e)";
      };

      directory = {
        style = "bold #7dcfff";
        truncation_length = 3;
        truncate_to_repo = true;
      };

      git_branch = {
        symbol = " ";
        style = "bold #bb9af7";
      };

      git_status = {
        style = "bold #e0af68";
      };

      nix_shell = {
        symbol = " ";
        style = "bold #7aa2f7";
        format = "via [$symbol$state( \\($name\\))]($style) ";
      };

      fill.symbol = " ";

      time = {
        disabled = false;
        style = "#565f89";
        format = "[$time]($style)";
        time_format = "%H:%M";
      };
    };
  };
}
