local utils = require "astronvim.utils"
local telescope = require "telescope.builtin"

return {
  n = {
    ["<leader>tt"] = { function() utils.toggle_term_cmd "zenith" end, desc = "ToggleTerm zenith" },
    ["<leader>tu"] = { function() utils.toggle_term_cmd "ncdu" end, desc = "ToggleTerm ncdu" },
    ["<leader>ff"] = { function() require("telescope.builtin").find_files { hidden = true } end, desc = "Find files" },
    ["?"] = { function() telescope.keymaps({ modes = { "n" } }) end, desc = "Find keymaps" }
  },
  t = {
  }
}
