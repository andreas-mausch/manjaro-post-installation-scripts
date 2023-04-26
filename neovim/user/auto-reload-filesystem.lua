-- auto-reload files when modified externally
-- https://neovim.discourse.group/t/a-lua-based-auto-refresh-buffers-when-they-change-on-disk-function/2482/3
vim.o.autoread = true
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
  command = "if mode() != 'c' | checktime | endif",
  pattern = { "*" }
})
