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

      # AI CLI
      cx = "codex";
      cxa = "codex-acp";

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

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      auto_sync = false;
      update_check = false;
      search_mode = "fuzzy";
      filter_mode = "directory";
      filter_mode_shell_up_key_binding = "directory";
      workspaces = true;
      style = "compact";
      inline_height = 20;
      show_preview = true;
      enter_accept = false;
      search.filters = [ "directory" "workspace" "session" "global" ];
    };
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
