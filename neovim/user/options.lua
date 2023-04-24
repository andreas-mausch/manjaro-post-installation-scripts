return {
  opt = {
    -- Bug in gitsigns. Remove the line when it is fixed.
    -- nvim crashes when opening a jpeg file.
    -- https://github.com/lewis6991/gitsigns.nvim/issues/758
    diffopt = vim.opt.diffopt - "linematch:60",
    relativenumber = false
  },
  g = {
    autoformat_enabled = false
  }
}
