return {
  "nvim-telescope/telescope.nvim",
  opts = {
    defaults = {
      file_ignore_patterns = {
        -- These are lua patterns
        -- See here: https://www.lua.org/manual/5.1/manual.html#5.4.1
        ".git/",
        "package%-lock%.json",
        "%.a",
        "%.class",
        "%.jpeg",
        "%.jpg",
        "%.mkv",
        "%.mp4",
        "%.o",
        "%.out",
        "%.pdf",
        "%.png",
        "%.zip"
      }
    }
  }
}
