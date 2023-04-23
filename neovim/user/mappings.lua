local utils = require "astronvim.utils"

return {
  n = {
    ["<leader>tt"] = { function() utils.toggle_term_cmd "zenith" end, desc = "ToggleTerm zenith" },
    ["<leader>tu"] = { function() utils.toggle_term_cmd "ncdu" end, desc = "ToggleTerm ncdu" },
    ["?"] = { function() require("telescope.builtin").keymaps() end, desc = "Find keymaps" }
  },
  t = {
  }
}
