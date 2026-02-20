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
        p.typescript
        p.javascript
        p.python
        p.go
        p.rust
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
      nodePackages.typescript-language-server # TypeScript/JS LSP
      pyright # Python LSP
      gopls # Go LSP
      rust-analyzer # Rust LSP
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
      vim.lsp.config("ts_ls", {
        cmd = { "typescript-language-server", "--stdio" },
        capabilities = capabilities,
      })

      vim.lsp.config("pyright", {
        cmd = { "pyright-langserver", "--stdio" },
        capabilities = capabilities,
      })

      vim.lsp.config("gopls", {
        cmd = { "gopls" },
        capabilities = capabilities,
      })

      vim.lsp.config("rust_analyzer", {
        cmd = { "rust-analyzer" },
        capabilities = capabilities,
      })

      vim.lsp.enable({ "nil_ls", "ts_ls", "pyright", "gopls", "rust_analyzer" })

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

      -- TUI tools
      vim.keymap.set("n", "<leader>gg", function()
        vim.cmd("tabnew | terminal lazygit")
        vim.cmd("startinsert")
      end, { desc = "lazygit" })

      vim.keymap.set("n", "<leader>e", function()
        vim.cmd("tabnew | terminal yazi " .. vim.fn.expand("%:p:h"))
        vim.cmd("startinsert")
      end, { desc = "yazi" })
    '';
  };
}
