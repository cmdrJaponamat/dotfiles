local mason = require("mason")
local mason_lspconfig = require("mason-lspconfig")
local cmp_nvim_lsp = require("cmp_nvim_lsp")

local function setup_client(client, bufnr)
  local bufopts = { noremap = true, silent = true, buffer = bufnr }
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts)
  vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
  vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)
  vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
  vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, bufopts)
  vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, bufopts)
  vim.keymap.set("n", "]d", vim.diagnostic.goto_next, bufopts)

  if
    vim.bo.filetype ~= "cpp"
    and vim.bo.filetype ~= "c"
    and client.server_capabilities.documentFormattingProvider
  then
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      callback = function()
        vim.lsp.buf.format({ bufnr = bufnr })
      end,
    })
  end
end

local capabilities = cmp_nvim_lsp.default_capabilities()
local servers = {
  clangd = {
    capabilities = vim.tbl_extend("force", capabilities, {
      offsetEncoding = { "utf-16" },
    }),
  },
  lua_ls = {
    settings = {
      Lua = {
        diagnostics = { globals = { "vim" } },
        workspace = { checkThirdParty = false },
        telemetry = { enable = false },
      },
    },
  },
  pyright = {},
}

local install_list = vim.tbl_keys(servers)

mason.setup()
mason_lspconfig.setup({
  ensure_installed = install_list,
  automatic_enable = false,
})

for name, server_opts in pairs(servers) do
  local opts = vim.tbl_deep_extend("force", {
    capabilities = capabilities,
    on_attach = setup_client,
  }, server_opts)
  vim.lsp.config(name, opts)
  vim.lsp.enable(name)
end

vim.diagnostic.config({
  virtual_text = true,
  underline = true,
  signs = true,
  update_in_insert = false,
})
