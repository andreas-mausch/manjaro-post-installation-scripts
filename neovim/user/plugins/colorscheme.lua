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
        secondary = "#8ba8cd",
        diagnostic_error = "#ec0034",
        diagnostic_warning = "#eeff00",
        diagnostic_info = "#d5d5d5"
      }
    }

    local Group = require('colorbuddy').Group
    local colors = require('colorbuddy').colors

    Group.new("Normal", colors.noir_4, colors.nb_background)
    Group.new("NormalNC", colors.primary, colors.noir_9)

    Group.new("NeoTreeDirectoryIcon", colors.noir_6)
    Group.new("NeoTreeDirectoryName", colors.noir_2)
    Group.new("NeoTreeRootName", colors.noir_6)
    Group.new("NeoTreeNormal", colors.noir_4, colors.nb_background)
    Group.new("NeoTreeNormalNC", colors.primary, colors.noir_9)
  end
}
