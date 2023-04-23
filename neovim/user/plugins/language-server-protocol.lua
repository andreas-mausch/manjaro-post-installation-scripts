return {
  "williamboman/mason-lspconfig.nvim",
  opts = {
    automatic_installation = true,
    -- See valid strings here: https://github.com/williamboman/mason-lspconfig.nvim
    ensure_installed = {
      "eslint",
      "jdtls",
      "kotlin_language_server",
      "lua_ls",
      "tsserver",
      "volar"
    }
  }
}
