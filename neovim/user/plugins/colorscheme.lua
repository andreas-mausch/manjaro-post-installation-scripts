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
    vim.api.nvim_command("highlight clear")

    require("noirbuddy").setup {
      colors = {
        primary = "#e8d7a5",
        secondary = "#c4d5e8",
        background = "#151515",
        nb_background = "#151515",
        noir_8 = "#181818",
        noir_9 = "#1c1c1c",
        diagnostic_error = "#e03040",
        diagnostic_warning = "#eeff00",
        diagnostic_info = "#84a5ff",
        diagnostic_hint = "#84a5ff",
        diff_add = "#406040",
        diff_change = "#405060",
        diff_delete = "#e03040"
      }
    }

    local colors = require("colorbuddy").colors
    local groups = require("colorbuddy").groups
    local Group = require("colorbuddy").Group

    Group.new("Normal", colors.noir_4, colors.nb_background)
    Group.new("NormalNC", colors.primary, colors.noir_9)
    Group.link("LineNr", groups.Normal)
    Group.new("CursorLine", nil, colors.black)
    Group.new("CursorLineNr", colors.noir_9, colors.noir_6)

    Group.new("NeoTreeDirectoryIcon", colors.noir_6)
    Group.new("NeoTreeDirectoryName", colors.noir_2)
    Group.new("NeoTreeFileName", colors.noir_3)
    Group.new("NeoTreeRootName", colors.noir_6)
    Group.new("NeoTreeGitModified", colors.primary)
    Group.new("NeoTreeGitAdded", colors.secondary)
    Group.new("NeoTreeGitUntracked", colors.noir_1)

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
