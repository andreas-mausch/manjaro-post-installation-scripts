-- Inspired by https://github.com/samodostal/image.nvim
vim.api.nvim_create_autocmd("BufEnter", {
  desc = "Image Preview with timg",
  pattern = "*.jpg,*.jpeg,*.png",
  callback = function(event)
    local bufferId = event.buf
    if not vim.api.nvim_buf_get_option(bufferId, "modifiable") then
      return
    end

    vim.api.nvim_buf_set_lines(bufferId, 0, -1, false, { "Loading image.." })
    vim.cmd [[ setlocal nofoldenable ]]
    vim.cmd [[ setlocal nonumber ]]
    vim.cmd [[ setlocal colorcolumn=0 ]]
    vim.cmd [[ setlocal signcolumn=no ]]
    vim.cmd [[ setlocal nocursorline ]]
    vim.cmd [[ setlocal nolist ]]

    vim.fn.jobstart(
      { "timg", "-g80x40", "-E", event.file }, {
        stdout_buffered = true,
        on_stdout = function(_, data)
          if data then
            local baleia = require("baleia").setup()
            baleia.buf_set_lines(bufferId, 0, -1, false, data)
          end
        end,
        on_exit = function(_, exitCode, _)
          if exitCode ~= 0 then
            vim.notify(string.format("Couldn't load image '%s'\nExit Code %d", event.file, exitCode), "error", {
              title = "Image Preview with timg"
            })
          end
          vim.api.nvim_buf_set_option(bufferId, "modifiable", false)
          vim.api.nvim_buf_set_option(bufferId, "buftype", "nowrite")
        end
      })
  end
})
