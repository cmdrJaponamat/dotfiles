# Neovim Keymaps

`<leader>` = `Space`

## Assigned keymaps (your config)

### Core / navigation

- `<Esc><Esc>`: clear search highlight
- `<C-s>`: save all files
- `<C-t>`: new tab
- `<C-h>`: previous tab
- `<C-l>`: next tab
- `<C-c>`: close tab

### Build / terminal

- `<F5>`: `:make`
- `<F6>`: `:AsyncRun cmake --build build`
- `<F7>`: ToggleTerm (horizontal)

### File tree (neo-tree)

- `<C-b>`: Neo-tree toggle
- `<leader>b`: Neo-tree toggle
- `<leader>e`: Neo-tree toggle
- `<C-f>`: reveal current file in Neo-tree

### Search (telescope)

- `<leader>ff`: find files
- `<leader>fg`: live grep
- `<leader>fb`: buffers
- `<leader>fh`: help tags
- `Telescope insert mode` `<Esc>`: close picker

### Editing

- `Normal` `<leader>/`: comment/uncomment current line
- `Visual` `<leader>/`: comment/uncomment selection

### Git (gitsigns)

- `<leader>gb`: toggle current line blame

### LSP

- `gd`: go to definition
- `gD`: go to declaration
- `gr`: references
- `gi`: implementations
- `K`: hover docs
- `<leader>rn`: rename symbol
- `<leader>d`: diagnostics float
- `[d`: previous diagnostic
- `]d`: next diagnostic

### Format / diagnostics

- `<leader>lf`: format current buffer (`conform.nvim`)
- `<leader>xx`: Trouble diagnostics (workspace)
- `<leader>xd`: Trouble diagnostics (current buffer)
- `<leader>xq`: Trouble quickfix list
- `<leader>xl`: Trouble location list

### Completion (nvim-cmp, Insert mode)

- `<C-Space>`: open completion menu
- `<Tab>`: next completion item / snippet jump forward
- `<S-Tab>`: previous completion item / snippet jump backward
- `<CR>`: confirm completion

## Neovim built-in hotkeys (quick reference)

### Modes

- `i`: enter Insert mode
- `v`: enter Visual mode
- `V`: enter Visual Line mode
- `<C-v>`: enter Visual Block mode
- `:`: command-line mode
- `<Esc>`: back to Normal mode

### Movement

- `h j k l`: left/down/up/right
- `w / b`: next/previous word
- `0 / ^ / $`: line start / first non-blank / line end
- `gg / G`: file start / file end
- `%`: matching bracket

### Edit / copy-paste

- `dd`: delete line
- `yy`: copy line
- `p / P`: paste after / before
- `u`: undo
- `<C-r>`: redo
- `x`: delete character under cursor
- `>> / <<`: indent right / left

### Search

- `/text`: search forward
- `?text`: search backward
- `n / N`: next / previous search result
- `* / #`: search word under cursor forward / backward

### Windows / splits

- `<C-w>s`: horizontal split
- `<C-w>v`: vertical split
- `<C-w>w`: move to next window
- `<C-w>h/j/k/l`: move between windows
- `<C-w>c`: close window

### Buffers

- `:ls`: list buffers
- `:bnext`: next buffer
- `:bprev`: previous buffer
- `:b <num>`: switch to buffer by number

## Plugins without assigned hotkeys (commands)

### lazy.nvim

- `:Lazy`: plugin manager UI

### mason.nvim / mason-lspconfig.nvim

- `:Mason`
- `:MasonInstall <name>`
- `:MasonUninstall <name>`
- `:MasonUpdate`
- `:MasonLog`

### conform.nvim

- `:ConformInfo`

### nvim-lint

- No custom command in your config; lint runs on autocmd events.

### render-markdown.nvim

- `:RenderMarkdown` (default `enable`)
- `:RenderMarkdown toggle`
- `:RenderMarkdown buf_toggle`
- `:RenderMarkdown disable`
- `:RenderMarkdown preview`
- `:RenderMarkdown log`

### vim-clang-format

- `:ClangFormat`

### asyncrun.vim

- `:AsyncRun <command>`

### trouble.nvim

- `:Trouble`

### window-picker

- Used internally by Neo-tree for target window selection.
- No separate keymap assigned in your config.

### lualine.nvim / gruvbox / nvim-web-devicons / treesitter / indent-blankline

- UI/behavior plugins, no explicit keymaps in your config.
