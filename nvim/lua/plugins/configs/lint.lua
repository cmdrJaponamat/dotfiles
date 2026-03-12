local lint = require("lint")

local function resolve_executable(name)
  local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/" .. name
  if vim.fn.executable(mason_bin) == 1 then
    return mason_bin
  end

  local system_path = vim.fn.exepath(name)
  if system_path ~= "" then
    return system_path
  end

  return nil
end

local ruff_cmd = resolve_executable("ruff")

lint.linters_by_ft = {
  c = { "clangtidy" },
  cpp = { "clangtidy" },
  python = ruff_cmd and { "ruff" } or {},
}

if ruff_cmd then
  lint.linters.ruff.cmd = ruff_cmd
end

local lint_group = vim.api.nvim_create_augroup("UserNvimLint", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
  group = lint_group,
  callback = function()
    local filetype = vim.bo.filetype
    if filetype == "python" and not ruff_cmd then
      return
    end

    local ok, err = pcall(lint.try_lint)
    if not ok then
      vim.schedule(function()
        vim.notify("nvim-lint: " .. err, vim.log.levels.WARN)
      end)
    end
  end,
})
