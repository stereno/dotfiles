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
      telescope-nvim
      plenary-nvim
    ];

    extraPackages = with pkgs; [
      ripgrep
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

      -- Telescope
      vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>")
      vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>")
      vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>")
    '';
  };
}
