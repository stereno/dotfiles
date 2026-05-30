{ config, pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withRuby = false;
    withPython3 = false;

    extraPackages = with pkgs; [
      ripgrep
      nil
      lua-language-server
      typescript-language-server
      pyright
      gopls
      rust-analyzer
    ];

    initLua = ''
      require("config.options")
      require("config.keymaps")
      require("config.autocmds")
      require("config.tools")
      require("config.lsp")
    '';
  };

  xdg.configFile."nvim/lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home/nvim/lua";
}
