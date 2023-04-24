return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      commands = {
        -- Override delete to use trash instead of rm
        -- Taken from here: https://github.com/nvim-neo-tree/neo-tree.nvim/issues/202#issuecomment-1079531421
        delete = function(state)
          local path = state.tree:get_node().path
          vim.fn.system({ "trash", vim.fn.fnameescape(path) })
          require("neo-tree.sources.manager").refresh(state.name)
        end
      },
      filtered_items = {
        hide_dotfiles = false,
        hide_by_name = {
          ".git",
          "package-lock.json"
        }
      }
    }
  }
}
