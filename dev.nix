{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "stereno";
  home.homeDirectory = "/home/stereno";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

  nixpkgs.config.allowUnfree = true;

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