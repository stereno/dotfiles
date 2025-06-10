{ config, pkgs, ... }:

{
  # Development-specific packages
  home.packages = [
    pkgs.nix-direnv
  ];

  # Development environment programs
  programs = {
    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };
  };

  # Development-specific session variables
  home.sessionVariables = {
    # Direnv configuration
    DIRENV_LOG_FORMAT = "";
  };
} 