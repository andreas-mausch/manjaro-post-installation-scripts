return {
  settings = {
    diagnostics = {
      -- https://github.com/microsoft/TypeScript/blob/main/src/compiler/diagnosticMessages.json
      ignoredCodes = {
        -- "Could not find a declaration file for module"
        7016,
        -- "File is a CommonJS module; it may be converted to an ES module"
        80001
      }
    }
  }
}
