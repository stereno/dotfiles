{ config, pkgs, ... }:

{
  # Development-specific packages
  home.packages = [
    pkgs.nix-direnv
    pkgs.gh
  ];

  # Development environment programs
  programs = {
    direnv = {
        enable = true;
        enableBashIntegration = true;
        nix-direnv.enable = true;
    };
    git = {
        enable = true;
        package = pkgs.git;
        userName = "stereno";
        extraConfig = {
            credential."https://github.com".helper = "!gh auth git-credential";
        };
    };
  };

  # Development-specific session variables
  home.sessionVariables = {
    # Direnv configuration
    DIRENV_LOG_FORMAT = "";
  };
} 