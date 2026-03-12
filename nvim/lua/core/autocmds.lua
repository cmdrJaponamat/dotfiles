local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

local lsp_group = augroup("UserLspConfig", { clear = true })

autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc() == 0 then
      vim.cmd("Neotree toggle")
    end
  end,
})

autocmd("FileType", {
  pattern = "cpp",
  callback = function()
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.bo.softtabstop = 4
    vim.bo.expandtab = true
    vim.bo.autoindent = true
    vim.bo.smartindent = true
    vim.bo.cindent = true
    vim.bo.cinoptions = "(0,:0,l1,g0,N-s,t0"
  end,
})

-- Highlight symbols under cursor (LSP)
autocmd({ "CursorHold", "CursorHoldI" }, {
  group = lsp_group,
  callback = function()
    if not next(vim.lsp.get_clients({ bufnr = 0 })) then
      return
    end
    vim.lsp.buf.document_highlight()
  end,
})

autocmd("CursorMoved", {
  group = lsp_group,
  callback = function()
    if not next(vim.lsp.get_clients({ bufnr = 0 })) then
      return
    end
    vim.lsp.buf.clear_references()
  end,
})
