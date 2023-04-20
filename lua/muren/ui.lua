local M = {}

local utils = require('muren.utils')

local default_options = {
  recursive = false,
  all_on_line = true,
}
local options_order = {
  'buffer',
  'recursive',
  'all_on_line',
}
local hl = {
  options = {
    on = '@string',
    off = '@variable.builtin',
  },
}

-- TODO should these be global to the module?
local orig_buf
local bufs = {}
local wins = {}
local other_win = {}
local last_lines = {}
local options = {
  buffer = nil,
}

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
    patterns = vim.api.nvim_buf_get_lines(bufs.patterns, 0, -1, true),
    replacements = vim.api.nvim_buf_get_lines(bufs.replacements, 0, -1, true),
  }
end

-- TODO move these to other module, not UI?
local do_replace = function(opts)
  opts = opts or {}
  local lines = get_ui_lines()
  if opts.recursive then
    multi_replace_recursive(orig_buf, lines.patterns, lines.replacements, opts)
  else
    multi_replace_non_recursive(orig_buf, lines.patterns, lines.replacements, opts)
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

local populate_options_buf = function()
  local lines = {}
  local highlights = {}
  for _, name in ipairs(options_order) do
    local value = options[name]
    local prefix
    if value then
      prefix = ''
      table.insert(highlights, hl.options.on)
    else
      prefix = ''
      table.insert(highlights, hl.options.off)
    end
    if type(value) == 'boolean' then
      table.insert(lines, string.format('%s %s', prefix, name))
    else
      table.insert(lines, string.format('%s %s: %s', prefix, name, value))
    end
  end
  vim.api.nvim_buf_set_lines(bufs.options, 0, -1, true, lines)
  for i, highlight in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufs.options, -1, highlight, i - 1, 0, -1)
  end
end

M.open = function()
  orig_buf = vim.api.nvim_get_current_buf()
  options = {}
  for name, value in pairs(default_options) do
    options[name] = value
  end
  options.buffer = orig_buf

  bufs.patterns = vim.api.nvim_create_buf(false, true)
  bufs.replacements = vim.api.nvim_create_buf(false, true)
  bufs.options = vim.api.nvim_create_buf(false, true)
  bufs.preview = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(bufs.patterns, 0, -1, true, last_lines.patterns or {})
  vim.api.nvim_buf_set_lines(bufs.replacements, 0, -1, true, last_lines.replacements or {})
  populate_options_buf()

  local gheight, gwidth = get_nvim_ui_size()

  local patterns_width = 30
  local patterns_height = 10
  local options_width = 15
  local preview_height = 12

  local total_width = 2 * patterns_width + options_width + 4
  local total_height = patterns_height + preview_height + 4

  wins.patterns = vim.api.nvim_open_win(bufs.patterns, true, {
    relative = 'editor',
    width = patterns_width,
    height = patterns_height,
    row = (gheight - total_height) / 2,
    col = (gwidth - total_width) / 2,
    style = 'minimal',
    border = {"┏", "━" ,"┳", "┃", "┻", "━", "┗", "┃"},
    title = {{'patterns', 'Number'}},
    title_pos = 'center',
  })
  wins.replacements = vim.api.nvim_open_win(bufs.replacements, false, {
    relative = 'editor',
    width = patterns_width,
    height = patterns_height,
    row = (gheight - total_height) / 2,
    col = (gwidth - total_width) / 2 + patterns_width + 1,
    style = 'minimal',
    border = {"┳", "━" ,"┳", "┃", "┻", "━", "┻", "┃"},
    title = {{'replacements', 'Number'}},
    title_pos = 'center',
  })
  other_win[wins.patterns] = wins.replacements
  other_win[wins.replacements] = wins.patterns
  wins.options = vim.api.nvim_open_win(bufs.options, false, {
    relative = 'editor',
    width = options_width,
    height = patterns_height,
    row = (gheight - total_height) / 2,
    col = (gwidth - total_width) / 2 + 2 * (patterns_width + 1),
    style = 'minimal',
    border = {"┳", "━" ,"┓", "┃", "┛", "━", "┻", "┃"},
    title = {{'options', 'Comment'}},
    title_pos = 'center',
  })
  wins.preview = vim.api.nvim_open_win(bufs.preview, false, {
    relative = 'editor',
    width = total_width - 2,
    height = preview_height,
    row = (gheight - total_height) / 2 + patterns_height + 2,
    col = (gwidth - total_width) / 2,
    style = 'minimal',
    border = {"┏", "━" ,"┓", "┃", "┛", "━", "└", "┃"},
    title = {{'preview', 'Comment'}},
    title_pos = 'center',
  })

  for _, buf in pairs(bufs) do
    vim.keymap.set('n', 'q', M.close, {buffer = buf})
    vim.keymap.set('n', '<CR>', do_replace, {buffer = buf})
    vim.api.nvim_create_autocmd('WinClosed', {
      callback = function() M.close() end,
      buffer = buf,
    })
  end
  for _, buf in ipairs({bufs.patterns, bufs.replacements}) do
    vim.keymap.set('n', '<Tab>', toggle_side, {buffer = buf})
  end
  vim.api.nvim_create_autocmd('CursorMoved', {
    callback = function() align_cursor(wins.patterns) end,
    buffer = bufs.patterns,
  })
  vim.api.nvim_create_autocmd('CursorMoved', {
    callback = function() align_cursor(wins.replacements) end,
    buffer = bufs.replacements,
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
