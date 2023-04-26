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
        diagnostic_error = "#ff4b2b",
        diagnostic_warning = "#eeff00",
        diagnostic_info = "#84a5ff",
        diagnostic_hint = "#84a5ff",
        diff_add = "#4bdc2b",
        diff_change = "#e8d7a5",
        diff_delete = "#ff4b2b"
      }
    }

    local colors = require("colorbuddy").colors
    local Group = require("colorbuddy").Group

    Group.new("Normal", colors.noir_4, colors.nb_background)
    Group.new("NormalNC", colors.noir_4, colors.noir_9)
    Group.new("LineNr", colors.noir_4)
    Group.new("CursorLine", nil, colors.black)
    Group.new("CursorLineNr", colors.noir_9, colors.noir_6)
    Group.new("Visual", colors.nb_background, colors.noir_4)
    Group.new("Search", colors.noir_9, colors.noir_3)
    Group.new("IncSearch", colors.noir_9, colors.primary)
    Group.new("Error", colors.diagnostic_error)
    Group.new("ErrorMsg", colors.noir_1, colors.diagnostic_error)
    Group.new("FloatBorder", colors.noir_6)

    -- Reset SignColumn
    -- It was set here: https://github.com/jesseleite/nvim-noirbuddy/blob/7d92fc64ae4c23213fd06f0464a72de45887b0ba/lua/noirbuddy/theme.lua#L39
    vim.api.nvim_set_hl(0, 'SignColumn', {})

    Group.new("NeoTreeDirectoryIcon", colors.noir_6)
    Group.new("NeoTreeDirectoryName", colors.noir_2)
    Group.new("NeoTreeFileName", colors.noir_3)
    Group.new("NeoTreeRootName", colors.noir_6)
    Group.new("NeoTreeGitModified", colors.diff_change)
    Group.new("NeoTreeGitAdded", colors.diff_add)
    Group.new("NeoTreeGitUntracked", colors.diff_delete)

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
