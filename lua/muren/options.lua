local M = {}

M.default = {
  -- general
  create_commands = true,
  filetype_in_preview = true,
  -- default togglable options
  two_step = false,
  all_on_line = true,
  preview = true,
  cwd = false,
  files = '**/*',
  -- keymaps
  keys = {
    close = 'q',
    toggle_side = '<Tab>',
    toggle_options_focus = '<C-s>',
    toggle_option_under_cursor = '<CR>',
    scroll_preview_up = '<Up>',
    scroll_preview_down = '<Down>',
    do_replace = '<CR>',
    do_undo = '<localleader>u',
    do_redo = '<localleader>r',
  },
  -- ui sizes
  patterns_width = 30,
  patterns_height = 10,
  options_width = 20,
  preview_height = 12,
  -- ui position
  anchor = 'center',
  vertical_offset = 0,
  horizontal_offset = 0,
  -- options order in ui
  order = {
    'buffer',
    'dir',
    'files',
    'two_step',
    'all_on_line',
    'preview',
  },
  -- highlights used for options ui
  hl = {
    options = {
      on = '@string',
      off = '@variable.builtin',
    },
    preview = {
      cwd = {
        path = 'Comment',
        lnum = 'Number',
      },
    },
  },
}

M.update = function(opts)
  M.default = vim.tbl_deep_extend('force', M.default, opts)
end

M.values = {}

local check_anchor_value = function(anchor)
  local anchor_positions = require('muren').anchor_positions
  if anchor == 'center' or vim.tbl_contains(anchor_positions, anchor) then
    return anchor
  end
  vim.notify('Invalid anchor value: \'' .. anchor .. '\'', 3, {title = 'Muren'})
  return 'center'
end

local match_anchor_pattern = function(anchor, low, high, row_or_col)
  local low_value, high_value = string.match(anchor, low), string.match(anchor, high)
  return low_value or high_value or 'center_' .. row_or_col
end

M.populate = function(opts)
  for name, value in pairs(M.default) do
    if M.values[name] == nil or opts.fresh then
      M.values[name] = value
    end
  end
  local anchor = check_anchor_value(opts.anchor or M.default.anchor)
  M.values.range = opts.range
  M.values.buffer = vim.api.nvim_get_current_buf()
  M.values.dir = vim.fn.getcwd()
  M.values.ft = vim.api.nvim_get_current_buf()
  M.values.total_width = 2 * M.values.patterns_width + M.values.options_width + 4
  M.values.total_height = M.values.patterns_height + M.values.preview_height + 4
  M.values.vertical_anchor = match_anchor_pattern(anchor, 'top', 'bottom', 'row')
  M.values.horizontal_anchor = match_anchor_pattern(anchor, 'left', 'right', 'col')
  M.values.vertical_offset = opts.vertical_offset or M.default.vertical_offset
  M.values.horizontal_offset = opts.horizontal_offset or M.default.horizontal_offset
end

return M
