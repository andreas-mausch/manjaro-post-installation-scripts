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
        primary = "#e8d7a5",
        secondary = "#c4d5e8",
        background = "#151515",
        nb_background = "#151515",
        noir_8 = "#181818",
        noir_9 = "#1C1C1C",
        diagnostic_error = "#ec0034",
        diagnostic_warning = "#eeff00",
        diagnostic_info = "#d5d5d5"
      }
    }

    local colors = require("colorbuddy").colors
    local Group = require("colorbuddy").Group
    -- local styles = require("colorbuddy").styles

    Group.new("Normal", colors.noir_4, colors.nb_background)
    Group.new("NormalNC", colors.primary, colors.noir_9)
    Group.new("CursorLine", nil, colors.black)
    Group.new("NonText", colors.noir_4, nil)

    Group.new("NeoTreeDirectoryIcon", colors.noir_6)
    Group.new("NeoTreeDirectoryName", colors.noir_2)
    Group.new("NeoTreeFileName", colors.noir_3)
    Group.new("NeoTreeRootName", colors.noir_6)
    Group.new("NeoTreeNormal", colors.noir_4, colors.nb_background)
    Group.new("NeoTreeNormalNC", colors.primary, colors.noir_9)
    Group.new("NeoTreeGitModified", colors.primary)

    Group.new("GitSignsChange", colors.primary)

    Group.new("IndentBlanklineContextChar", colors.primary)
    -- Group.new("IndentBlanklineChar", colors.noir_8, nil, styles.nocombine)

    Group.new('TelescopePromptNormal', colors.noir_4, colors.nb_background)
    Group.new('TelescopeResultsNormal', colors.noir_4, colors.nb_background)
    Group.new('TelescopePreviewNormal', colors.noir_4, colors.nb_background)
    Group.new('TelescopeSelection', nil, colors.black)
    Group.new('TelescopeSelectionCaret', colors.primary)
    Group.new('TelescopePromptTitle', colors.primary)
    Group.new('TelescopeResultsTitle', colors.primary)
    Group.new('TelescopePreviewTitle', colors.primary)
  end
}
