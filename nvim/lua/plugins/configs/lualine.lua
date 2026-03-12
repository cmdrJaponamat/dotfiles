require("lualine").setup({
  options = {
    theme = "gruvbox",
    section_separators = "",
    component_separators = "",
    globalstatus = true,
  },
  sections = {
    lualine_b = { "branch" },
    lualine_c = { "filename" },
    lualine_x = { "encoding", "fileformat", "filetype" },
  },
  extensions = { "neo-tree" },
})
