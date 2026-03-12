local ts = require("nvim-treesitter")

ts.setup({})

local languages = {
  "bash",
  "c",
  "cpp",
  "cmake",
  "lua",
  "python",
  "json",
  "markdown",
}

vim.api.nvim_create_autocmd("FileType", {
  pattern = languages,
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
    vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})
