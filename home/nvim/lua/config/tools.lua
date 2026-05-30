local M = {}

local function floating_terminal(command, opts)
  opts = opts or {}

  local buffer = vim.api.nvim_create_buf(false, true)
  local width = math.max(1, math.floor(vim.o.columns * 0.9))
  local height = math.max(1, math.floor(vim.o.lines * 0.85))
  local window = vim.api.nvim_open_win(buffer, true, {
    relative = "editor",
    border = "rounded",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
  })

  vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { buffer = buffer, desc = "Leave Terminal Mode" })

  local job = vim.fn.jobstart(command, {
    cwd = opts.cwd,
    term = true,
    on_exit = function(_, code)
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(window) then
          vim.api.nvim_win_close(window, true)
        end
        if vim.api.nvim_buf_is_valid(buffer) then
          vim.api.nvim_buf_delete(buffer, { force = true })
        end
        if opts.on_exit then
          opts.on_exit(code)
        end
      end)
    end,
  })

  if job <= 0 then
    vim.api.nvim_win_close(window, true)
    vim.notify("Unable to start: " .. command[1], vim.log.levels.ERROR)
    return
  end

  vim.cmd.startinsert()
end

local function open_selected_files(path)
  if vim.fn.filereadable(path) == 0 then
    return
  end

  local files = vim.fn.readfile(path)
  vim.fn.delete(path)
  for index, file in ipairs(files) do
    if file ~= "" then
      local command = index == 1 and "edit" or "badd"
      vim.cmd[command]({ args = { file } })
    end
  end
end

function M.yazi()
  local selection = vim.fn.tempname()
  local entry = vim.api.nvim_buf_get_name(0)
  if entry == "" or not vim.uv.fs_stat(entry) then
    entry = vim.fn.getcwd()
  end

  floating_terminal({ "yazi", entry, "--chooser-file", selection }, {
    on_exit = function()
      open_selected_files(selection)
    end,
  })
end

function M.files()
  local selection = vim.fn.tempname()
  local output = vim.fn.shellescape(selection)
  local command = "fd --type f --hidden --exclude .git --color never | fzf --layout=reverse > " .. output

  floating_terminal({ vim.o.shell, vim.o.shellcmdflag, command }, {
    cwd = vim.fn.getcwd(),
    on_exit = function(code)
      if code == 0 then
        open_selected_files(selection)
      else
        vim.fn.delete(selection)
      end
    end,
  })
end

function M.lazygit()
  floating_terminal({ "lazygit" }, { cwd = vim.fn.getcwd() })
end

vim.api.nvim_create_user_command("Yazi", M.yazi, {})
vim.api.nvim_create_user_command("Files", M.files, {})
vim.api.nvim_create_user_command("LazyGit", M.lazygit, {})

vim.keymap.set("n", "<leader>e", M.yazi, { desc = "Yazi" })
vim.keymap.set("n", "<leader>ff", M.files, { desc = "Find Files" })
vim.keymap.set("n", "<leader>gg", M.lazygit, { desc = "LazyGit" })

return M
