vim.keymap.set("n", "<leader>sg", ":grep ", { desc = "Grep" })
vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Line Diagnostics" })
vim.keymap.set("n", "[q", "<Cmd>cprevious<CR>", { desc = "Previous Quickfix" })
vim.keymap.set("n", "]q", "<Cmd>cnext<CR>", { desc = "Next Quickfix" })
