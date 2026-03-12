local conform = require("conform")

conform.setup({
  formatters_by_ft = {
    c = { "clang_format" },
    cpp = { "clang_format" },
    python = { "isort", "black" },
  },
  format_on_save = function(bufnr)
    local ft = vim.bo[bufnr].filetype
    if ft == "c" or ft == "cpp" or ft == "python" then
      return {
        timeout_ms = 1000,
        lsp_fallback = true,
      }
    end
    return nil
  end,
})
