require("neo-tree").setup({
  close_if_last_window = true,
  popup_border_style = "rounded",
  enable_diagnostics = true,
  default_component_configs = {
    indent = { padding = 0 },
  },
  filesystem = {
    follow_current_file = {
      enabled = true,
    },
    use_libuv_file_watcher = true,
  },
})
