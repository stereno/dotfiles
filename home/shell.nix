{ pkgs, ... }: {
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      function __tmux_auto_rename --on-variable PWD
          if not set -q TMUX; return; end

          set -l git_toplevel (git rev-parse --show-toplevel 2>/dev/null)

          if test -n "$git_toplevel"
              set -l branch (git branch --show-current 2>/dev/null)
              if test -n "$branch"
                  tmux rename-window $branch
              else
                  tmux rename-window (basename $git_toplevel)
              end
              tmux rename-session (basename $git_toplevel)
          else
              tmux rename-window (basename $PWD)
          end
      end
      __tmux_auto_rename
    '';

    functions = {
      tp = ''
        set -l selected (ghq list --full-path | fzf --tmux)
        or return

        set -l name (basename $selected)

        if set -q TMUX
            if not tmux has-session -t=$name 2>/dev/null
                tmux new-session -d -s $name -c $selected
            end
            tmux switch-client -t $name
        else
            if tmux has-session -t=$name 2>/dev/null
                tmux attach-session -t $name
            else
                tmux new-session -s $name -c $selected
            end
        end
      '';
    };

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
