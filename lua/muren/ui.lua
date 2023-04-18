local M = {}

local utils = require('muren.utils')

-- TODO should these be global to the module?
local orig_buf
local bufs = {}
local wins = {}
local other_win = {}
local last_lines = {}

local teardown = function()
  orig_buf = nil
  bufs = {}
  wins = {}
  other_win = {}
end

local toggle_side = function()
  local current_win = vim.api.nvim_get_current_win()
  local current_pos = vim.api.nvim_win_get_cursor(current_win)
  local other_w = other_win[current_win]
  vim.api.nvim_set_current_win(other_w)
  vim.api.nvim_win_set_cursor(other_w, current_pos)
end

local set_cursor_row = function(win, row)
  local buf = vim.api.nvim_win_get_buf(win)
  row = utils.clip_val(1, row, vim.api.nvim_buf_line_count(buf))
  vim.api.nvim_win_set_cursor(win, {row, 0})
end

local align_cursor = function(master_win)
  local current_pos = vim.api.nvim_win_get_cursor(master_win)
  local other_w = other_win[master_win]
  set_cursor_row(other_w, current_pos[1])
end

local multi_replace_recursive = function(buf, patterns, replacements, opts)
  for i, pattern in ipairs(patterns) do
    local replacement = replacements[i] or ''
    vim.api.nvim_buf_call(buf, function()
      vim.cmd(string.format(
        '%%s/%s/%s/%s',
        pattern,
        replacement,
        opts.replace_opt_chars or ''
      ))
    end)
  end
end

local multi_replace_non_recursive = function(buf, patterns, replacements, opts)
  local replacement_per_placeholder = {}
  for i, pattern in ipairs(patterns) do
    local placeholder = string.format('___MUREN___%d___', i)
    local replacement = replacements[i] or ''
    replacement_per_placeholder[placeholder] = replacement
    vim.api.nvim_buf_call(buf, function()
      vim.cmd(string.format(
        '%%s/%s/%s/%s',
        pattern,
        placeholder,
        opts.replace_opt_chars or ''
      ))
    end)
  end
  -- TODO if we have eg 'c' replace_opt_chars I guess we don't want it here?
  for placeholder, replacement in pairs(replacement_per_placeholder) do
    vim.api.nvim_buf_call(buf, function()
      vim.cmd(string.format(
        '%%s/%s/%s/%s',
        placeholder,
        replacement,
        opts.replace_opt_chars or ''
      ))
    end)
  end
end

local get_ui_lines = function()
  return {
    left = vim.api.nvim_buf_get_lines(bufs.left, 0, -1, true),
    right = vim.api.nvim_buf_get_lines(bufs.right, 0, -1, true),
  }
end

-- TODO move these to other module, not UI?
local do_replace = function(opts)
  opts = opts or {}
  local lines = get_ui_lines()
  if opts.recursive then
    multi_replace_recursive(orig_buf, lines.left, lines.right, opts)
  else
    multi_replace_non_recursive(orig_buf, lines.left, lines.right, opts)
  end
end

local get_nvim_ui_size = function()
  local first_ui = vim.api.nvim_list_uis()[1]
  if first_ui then
    return first_ui.height, first_ui.width
  else
    -- NOTE mostly when testing to have a default size
    return 30, 150
  end
end


M.open = function()
  orig_buf = vim.api.nvim_get_current_buf()
  bufs.left = vim.api.nvim_create_buf(false, true)
  bufs.right = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(bufs.left, 0, -1, true, last_lines.left or {})
  vim.api.nvim_buf_set_lines(bufs.right, 0, -1, true, last_lines.right or {})

  local gheight, gwidth = get_nvim_ui_size()

  local width = 60
  local height = 10

  wins.left = vim.api.nvim_open_win(bufs.left, true, {
    relative = 'editor',
    width = width / 2 - 1,
    height = height,
    anchor = 'SW',
    row = (gheight + height) / 2,
    col = (gwidth - width) / 2,
    style = 'minimal',
    border = {"┏", "━" ,"┳", "┃", "┻", "━", "┗", "┃"},
  })
  wins.right = vim.api.nvim_open_win(bufs.right, false, {
    relative = 'editor',
    width = width / 2 - 1,
    height = height,
    anchor = 'SW',
    row = (gheight + height) / 2,
    col = gwidth / 2,
    style = 'minimal',
    border = {"┳", "━" ,"┓", "┃", "┛", "━", "┻", "┃"},
  })
  other_win[wins.left] = wins.right
  other_win[wins.right] = wins.left

  for _, buf in pairs(bufs) do
    vim.keymap.set('n', 'q', M.close, {buffer = buf})
    vim.keymap.set('n', '<Tab>', toggle_side, {buffer = buf})
    vim.keymap.set('n', '<CR>', do_replace, {buffer = buf})
    vim.api.nvim_create_autocmd('WinClosed', {
      callback = function() M.close() end,
      buffer = buf,
    })
  end
  vim.api.nvim_create_autocmd('CursorMoved', {
    callback = function() align_cursor(wins.left) end,
    buffer = bufs.left,
  })
  vim.api.nvim_create_autocmd('CursorMoved', {
    callback = function() align_cursor(wins.right) end,
    buffer = bufs.right,
  })
end

local save_lines = function()
  last_lines = get_ui_lines()
end

local noautocmd = function(ignore, callback)
  local current_eventignore = vim.o.eventignore
  vim.o.eventignore = ignore
  callback()
  vim.o.eventignore = current_eventignore
end

M.close = function()
  if not orig_buf then
    return
  end
  save_lines()
  for _, win in pairs(wins) do
    noautocmd('WinClosed,CursorMoved', function()
      vim.api.nvim_win_close(win, true)
    end)
  end
  teardown()
end

M.toggle = function()
  if orig_buf then
    M.close()
  else
    M.open()
  end
end

M.reset = function()
  last_lines = {}
end

return M
