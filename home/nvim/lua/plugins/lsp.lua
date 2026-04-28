return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        virtual_text = {
          spacing = 4,
          prefix = "●",
          source = "if_many",
        },
        float = {
          border = "rounded",
          source = true,
        },
      },
      servers = {
        nil_ls = { mason = false },
        lua_ls = { mason = false },
        ts_ls = { mason = false },
        pyright = { mason = false },
        gopls = { mason = false },
        rust_analyzer = { mason = false },
      },
    },
  },
}
