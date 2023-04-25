return {
  "jesseleite/nvim-noirbuddy",
  as = "noirbuddy",
  dependencies = {
    {
      "tjdevries/colorbuddy.nvim",
      branch = "dev"
    }
  },
  config = function()
    require("noirbuddy").setup {
      colors = {
        primary = "#ffb35f",
        secondary = "#95bdf1",
        diagnostic_error = "#ec0034",
        diagnostic_warning = "#eeff00",
        diagnostic_info = "#d5d5d5"
      }
    }

    local Group = require('colorbuddy').Group
    local colors = require('colorbuddy').colors

    Group.new("NeoTreeDirectoryIcon", colors.noir_6)
    Group.new("NeoTreeDirectoryName", colors.noir_2)
    Group.new("NeoTreeRootName", colors.noir_6)
  end
}
