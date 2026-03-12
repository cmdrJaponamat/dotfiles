local telescope = require("telescope")
local actions = require("telescope.actions")

telescope.setup({
  defaults = {
    mappings = {
      i = {
        ["<ESC>"] = actions.close,
      },
    },
    prompt_prefix = " ",
    selection_caret = " ",
    layout_config = { width = 0.75, prompt_position = "top" },
  },
  pickers = {
    find_files = {
      hidden = true,
    },
  },
})

telescope.load_extension("fzf")
