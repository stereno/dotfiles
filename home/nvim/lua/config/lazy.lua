require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "lazyvim.plugins.extras.editor.telescope" },
    { import = "lazyvim.plugins.extras.coding.blink" },
    { "nvim-telescope/telescope-fzf-native.nvim", enabled = true },
    { "mason-org/mason.nvim", enabled = false },
    { "mason-org/mason-lspconfig.nvim", enabled = false },
    { import = "plugins" },
    { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = {} } },
  },
  defaults = {
    lazy = true,
    version = false,
  },
  dev = {
    path = vim.g.lazyvim_nix_lazy_path,
    patterns = { "." },
    fallback = true,
  },
  checker = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
