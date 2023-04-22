local M = {}

-- TODO expose options and settings
local default_options = {
  recursive = false,
  all_on_line = true,
  preview = true,
  patterns_width = 30,
  patterns_height = 10,
  options_width = 15,
  preview_height = 12,
}
M.order = {
  'buffer',
  'recursive',
  'all_on_line',
  'preview',
}
M.hl = {
  options = {
    on = '@string',
    off = '@variable.builtin',
  },
}

M.values = {}

M.populate = function(opts)
  for name, value in pairs(default_options) do
    if M.values[name] == nil or opts.fresh then
      M.values[name] = value
    end
  end
  M.values.buffer = vim.api.nvim_get_current_buf()
  M.values.total_width = 2 * M.values.patterns_width + M.values.options_width + 4
  M.values.total_height = M.values.patterns_height + M.values.preview_height + 4
end

return M
