{ pkgs, ... }: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;

    plugins = with pkgs.vimPlugins; [
      tokyonight-nvim
      (nvim-treesitter.withPlugins (p: [
        p.nix
        p.lua
        p.bash
        p.json
        p.yaml
        p.markdown
      ]))
    ];

    extraLuaConfig = ''
      vim.g.mapleader = " "

      vim.cmd.colorscheme("tokyonight-night")

      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.signcolumn = "yes"
      vim.opt.termguicolors = true

      vim.opt.ignorecase = true
      vim.opt.smartcase = true
    '';
  };
}
