-- Inspired by https://github.com/samodostal/image.nvim
vim.api.nvim_create_autocmd("BufEnter", {
  desc = "Image Preview with timg",
  pattern = "*.jpg,*.jpeg,*.png",
  callback = function(event)
    -- require("notify")(string.format('event fired: %s', vim.inspect(event)))
    local bufferId = 0
    local content = { "Loading.." }
    vim.api.nvim_buf_set_lines(bufferId, 0, -1, false, content)
    vim.cmd [[ setlocal nofoldenable ]]
    vim.cmd [[ setlocal nonumber ]]
    vim.cmd [[ setlocal colorcolumn=0 ]]
    vim.cmd [[ setlocal signcolumn=no ]]
    vim.cmd [[ setlocal nocursorline ]]
    vim.cmd [[ setlocal nolist ]]

    local filename = vim.api.nvim_buf_get_name(bufferId)
    vim.fn.jobstart(
      { "timg", "-g80x40", "-E", filename }, {
        stdout_buffered = true,
        on_stdout = function(_, data)
          if data then
            local baleia = require("baleia").setup()
            baleia.buf_set_lines(bufferId, 0, -1, false, data)
          end
        end,
        on_exit = function(_, _, _)
          vim.api.nvim_buf_set_option(bufferId, "modifiable", false)
          vim.api.nvim_buf_set_option(bufferId, "buftype", "nowrite")
        end
      })
  end
})
