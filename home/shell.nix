{ pkgs, ... }: {
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      ignoreAllDups = true;
      share = true;
    };

    shellAliases = {
      rebuild-dev = "sudo nixos-rebuild switch --flake ~/dotfiles#dev";
      ll = "ls -la";
      la = "ls -a";
      gs = "git status";
      gd = "git diff";
      gp = "git push";
    };

    initContent = ''
      bindkey -e
      bindkey '^[[A' history-search-backward
      bindkey '^[[B' history-search-forward
    '';
  };

  programs.starship = {
    enable = true;

    settings = {
      format = "$directory$git_branch$git_status$nix_shell$character";

      palette = "nord";

      palettes.nord = {
        frost0 = "#8fbcbb";
        frost1 = "#88c0d0";
        frost2 = "#81a1c1";
        frost3 = "#5e81ac";
        snow0 = "#d8dee9";
        aurora_green = "#a3be8c";
        aurora_red = "#bf616a";
        aurora_purple = "#b48ead";
      };

      character = {
        success_symbol = "[>](bold aurora_green)";
        error_symbol = "[>](bold aurora_red)";
      };

      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
        style = "bold frost1";
      };

      git_branch = {
        format = "[$branch]($style) ";
        style = "bold frost2";
      };

      git_status = {
        format = "[$all_status$ahead_behind]($style) ";
        style = "bold aurora_red";
      };

      nix_shell = {
        format = "[$symbol]($style) ";
        symbol = "";
        style = "bold frost3";
      };
    };
  };

  programs.bash.enable = true;
}
