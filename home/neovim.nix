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
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
    ];

    extraPackages = with pkgs; [
      ripgrep
      nil # Nix LSP
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

      -- LSP
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      vim.lsp.config("nil_ls", {
        cmd = { "nil" },
        capabilities = capabilities,
      })
      vim.lsp.enable("nil_ls")

      -- nvim-cmp
      local cmp = require("cmp")
      cmp.setup({
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "buffer" },
        }),
        mapping = cmp.mapping.preset.insert({
          ["<C-n>"] = cmp.mapping.select_next_item(),
          ["<C-p>"] = cmp.mapping.select_prev_item(),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
        }),
      })
    '';
  };
}
