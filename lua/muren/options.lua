local M = {}

M.default = {
  -- general
  create_commands = true,
  -- default togglable options
  recursive = false,
  all_on_line = true,
  preview = true,
  -- ui sizes
  patterns_width = 30,
  patterns_height = 10,
  options_width = 15,
  preview_height = 12,
  -- options order in ui
  order = {
    'buffer',
    'recursive',
    'all_on_line',
    'preview',
  },
  -- highlights used for options ui
  hl = {
    options = {
      on = '@string',
      off = '@variable.builtin',
    },
  },
}

M.update = function(opts)
  M.default = vim.tbl_deep_extend('force', M.default, opts)
end

M.values = {}

M.populate = function(opts)
  for name, value in pairs(M.default) do
    if M.values[name] == nil or opts.fresh then
      M.values[name] = value
    end
  end
  M.values.buffer = vim.api.nvim_get_current_buf()
  M.values.total_width = 2 * M.values.patterns_width + M.values.options_width + 4
  M.values.total_height = M.values.patterns_height + M.values.preview_height + 4
end

return M