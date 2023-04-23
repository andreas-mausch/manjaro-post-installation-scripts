return {
  "jose-elias-alvarez/null-ls.nvim",
  opts = function(_, opts)
    local null_ls = require "null-ls"

    opts.sources = {
      null_ls.builtins.diagnostics.eslint,
      null_ls.builtins.diagnostics.ktlint,
      null_ls.builtins.formatting.eslint,
      null_ls.builtins.formatting.ktlint
    }
    return opts
  end
}
