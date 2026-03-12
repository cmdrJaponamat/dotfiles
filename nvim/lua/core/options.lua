local o = vim.opt

o.termguicolors = true
vim.g.gruvbox_contrast_dark = "hard"
o.background = "dark"
o.lazyredraw = true

o.updatetime = 300

o.synmaxcol = 200

-- Tabs and indentation

o.tabstop = 4
o.shiftwidth = 4
o.softtabstop = 4
o.expandtab = true

o.autoindent = true

o.smartindent = true

o.cindent = true

-- Numbers and search

o.relativenumber = true

o.number = true

o.hlsearch = true

o.incsearch = true

o.inccommand = "nosplit"

o.clipboard = "unnamedplus"

-- Folding

o.foldmethod = "indent"
o.foldnestmax = 10

o.foldlevel = 1

o.foldenable = false

-- Filetype behavior
vim.cmd("syntax on")
vim.cmd("filetype plugin indent on")

-- Misc options

o.modeline = false

o.scrolloff = 5

o.signcolumn = "yes"

o.splitright = true

o.mouse = "a"
