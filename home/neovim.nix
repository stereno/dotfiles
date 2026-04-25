{ pkgs, ... }: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withRuby = false;
    withPython3 = false;

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
      yazi-nvim
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      lualine-nvim
      nvim-web-devicons
      gitsigns-nvim
      nvim-autopairs
      comment-nvim
      conform-nvim
      which-key-nvim
    ];

    extraPackages = with pkgs; [
      ripgrep
      nil # Nix LSP
      typescript-language-server # TypeScript/JS LSP
      pyright # Python LSP
      gopls # Go LSP
      rust-analyzer # Rust LSP
      nixfmt # Nix formatter
      prettierd # JS/TS/JSON/YAML/Markdown formatter
      black # Python formatter
      go # gofmt
      rustfmt # Rust formatter
    ];

    initLua = ''
      -- Leader / Colorscheme / Options
      vim.g.mapleader = " "

      vim.cmd.colorscheme("tokyonight-night")

      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.signcolumn = "yes"
      vim.opt.termguicolors = true

      vim.opt.ignorecase = true
      vim.opt.smartcase = true

      -- Diagnostics
      vim.diagnostic.config({
        virtual_text = { spacing = 4, prefix = "●" },
        signs = true,
        underline = true,
        update_in_insert = false,
        float = { border = "rounded", source = true },
      })
      vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
      vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
      vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Diagnostic float" })

      -- which-key
      local wk = require("which-key")
      wk.setup({})
      wk.add({
        { "<leader>f", group = "Find" },
        { "<leader>g", group = "Git" },
        { "<leader>c", group = "Code" },
        { "<leader>r", group = "Refactor" },
      })

      -- Telescope
      vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
      vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Buffers" })

      -- LSP
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      vim.lsp.config("nil_ls", {
        cmd = { "nil" },
        filetypes = { "nix" },
        root_markers = { "flake.nix", "shell.nix", "default.nix" },
        capabilities = capabilities,
      })
      vim.lsp.config("ts_ls", {
        cmd = { "typescript-language-server", "--stdio" },
        filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
        root_markers = { "tsconfig.json", "jsconfig.json", "package.json" },
        capabilities = capabilities,
      })

      vim.lsp.config("pyright", {
        cmd = { "pyright-langserver", "--stdio" },
        filetypes = { "python" },
        root_markers = { "pyrightconfig.json", "pyproject.toml", "setup.py" },
        capabilities = capabilities,
      })

      vim.lsp.config("gopls", {
        cmd = { "gopls" },
        filetypes = { "go", "gomod", "gowork", "gotmpl" },
        root_markers = { "go.mod" },
        capabilities = capabilities,
      })

      vim.lsp.config("rust_analyzer", {
        cmd = { "rust-analyzer" },
        filetypes = { "rust" },
        root_markers = { "Cargo.toml", "rust-project.json" },
        capabilities = capabilities,
      })

      vim.lsp.enable({ "nil_ls", "ts_ls", "pyright", "gopls", "rust_analyzer" })

      -- LspAttach autocmd
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local opts = function(desc)
            return { buffer = ev.buf, desc = desc }
          end
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts("Go to definition"))
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts("References"))
          vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts("Go to implementation"))
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts("Hover"))
          vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts("Signature help"))
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts("Code action"))
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts("Rename"))
        end,
      })

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

      -- Autopairs
      local autopairs = require("nvim-autopairs")
      autopairs.setup({})
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())

      -- Comment
      require("Comment").setup()

      -- conform.nvim
      require("conform").setup({
        formatters_by_ft = {
          nix = { "nixfmt" },
          typescript = { "prettierd" },
          typescriptreact = { "prettierd" },
          javascript = { "prettierd" },
          javascriptreact = { "prettierd" },
          json = { "prettierd" },
          yaml = { "prettierd" },
          markdown = { "prettierd" },
          python = { "black" },
          go = { "gofmt" },
          rust = { "rustfmt" },
        },
        format_on_save = {
          timeout_ms = 2000,
          lsp_format = "fallback",
        },
      })
      vim.keymap.set({ "n", "v" }, "<leader>cf", function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end, { desc = "Format" })

      -- gitsigns
      require("gitsigns").setup({
        on_attach = function(bufnr)
          local gs = require("gitsigns")
          local function map(mode, l, r, desc)
            vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
          end
          map("n", "]c", function()
            if vim.wo.diff then return "]c" end
            vim.schedule(function() gs.next_hunk() end)
            return "<Ignore>"
          end, "Next hunk")
          map("n", "[c", function()
            if vim.wo.diff then return "[c" end
            vim.schedule(function() gs.prev_hunk() end)
            return "<Ignore>"
          end, "Prev hunk")
          map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
          map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
          map("n", "<leader>gb", gs.blame_line, "Blame line")
          map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
        end,
      })

      -- lualine
      require("lualine").setup({
        options = {
          theme = "tokyonight",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diagnostics" },
          lualine_c = { "filename" },
          lualine_x = {
            {
              function()
                local clients = vim.lsp.get_clients({ bufnr = 0 })
                if #clients == 0 then return "" end
                local names = {}
                for _, client in ipairs(clients) do
                  table.insert(names, client.name)
                end
                return table.concat(names, ", ")
              end,
            },
            "filetype",
          },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      })

      -- TUI tools
      vim.keymap.set("n", "<leader>gg", function()
        vim.cmd("tabnew | terminal lazygit")
        vim.cmd("startinsert")
      end, { desc = "Lazygit" })

      require("yazi").setup({})
      vim.keymap.set("n", "<leader>e", "<cmd>Yazi<cr>", { desc = "Yazi" })
    '';
  };
}
