local utils = require "astronvim.utils"

return {
  n = {
    ["<leader>tt"] = { function() utils.toggle_term_cmd "zenith" end, desc = "ToggleTerm zenith" }
  },
  t = {
  },
}
