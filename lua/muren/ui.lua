local M = {}

local utils = require('muren.utils')
local options = require('muren.options')
local search = require('muren.search')

local last_lines = {}

-- TODO should these be global to the module?
local is_open = false
local preview_open = false
local bufs = {}
local wins = {}
local other_win = {}
local last_input_win

local teardown = function()
  preview_open = false
  bufs = {}
  wins = {}
  other_win = {}
  last_input_win = nil
end

local set_cursor_row = function(win, row)
  local buf = vim.api.nvim_win_get_buf(win)
  row = utils.clip_val(1, row, vim.api.nvim_buf_line_count(buf))
  vim.api.nvim_win_set_cursor(win, {row, 0})
end

local toggle_side = function()
  local current_win = vim.api.nvim_get_current_win()
  local current_pos = vim.api.nvim_win_get_cursor(current_win)
  local other_w = other_win[current_win]
  vim.api.nvim_set_current_win(other_w)
  set_cursor_row(other_w, current_pos[1])
end

local toggle_options_focus = function()
  local current_win = vim.api.nvim_get_current_win()
  if current_win == wins.options then
    vim.api.nvim_set_current_win(last_input_win)
  else
    last_input_win = current_win
    vim.api.nvim_set_current_win(wins.options)
  end
end

local list_loaded_bufs = function()
  local loaded_bufs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) ~= '' then
      table.insert(loaded_bufs, buf)
    end
  end
  return loaded_bufs
end

local populate_options_buf = function()
  local lines = {}
  local highlights = {}
  for _, name in ipairs(options.order) do
    local value = options.values[name]
    local prefix
    if value then
      prefix = ''
      table.insert(highlights, options.hl.options.on)
    else
      prefix = ''
      table.insert(highlights, options.hl.options.off)
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

local is_empty_buf = function(lines)
  if #lines == 0 then
    return true
  elseif #lines == 1 and lines[1] == '' then
    return true
  else
    return false
  end
end

local get_ui_lines = function()
  local lines = {
    patterns = vim.api.nvim_buf_get_lines(bufs.patterns, 0, -1, true),
    replacements = vim.api.nvim_buf_get_lines(bufs.replacements, 0, -1, true),
  }
  if is_empty_buf(lines.patterns) and is_empty_buf(lines.replacements) then
    return {
      patterns = {},
      replacements = {},
    }
  else
    return lines
  end
end

local update_preview = function()
  if not preview_open then
    return
  end
  local ui_lines = get_ui_lines()
  local relevant_line_nums = {}
  for _, pattern in ipairs(ui_lines.patterns) do
    for _, line in ipairs(search.find_all_line_matches_in_buf(options.values.buffer, pattern)) do
      relevant_line_nums[line - 1] = true
    end
  end
  local relevant_lines = {}
  for line_num, _ in pairs(relevant_line_nums) do
    local lines = vim.api.nvim_buf_get_lines(options.values.buffer, line_num, line_num + 1, false)
    if #lines > 0 then
      table.insert(relevant_lines, lines[1])
    end
  end
  vim.api.nvim_buf_set_lines(bufs.preview, 0, -1, true, relevant_lines)
  search.do_replace_with_patterns(bufs.preview, ui_lines.patterns, ui_lines.replacements)
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

local open_preview = function()
  if preview_open then
    return
  end
  local gheight, gwidth = get_nvim_ui_size()
  wins.preview = vim.api.nvim_open_win(bufs.preview, false, {
    relative = 'editor',
    width = options.values.total_width - 2,
    height = options.values.preview_height,
    row = (gheight - options.values.total_height) / 2 + options.values.patterns_height + 2,
    col = (gwidth - options.values.total_width) / 2,
    style = 'minimal',
    border = {"┏", "━" ,"┓", "┃", "┛", "━", "└", "┃"},
    title = {{'preview', 'Comment'}},
    title_pos = 'center',
  })
  preview_open = true
end

local close_preview = function()
  if not preview_open then
    return
  end
  vim.api.nvim_win_close(wins.preview, true)
  preview_open = false
end

local toggle_option_under_cursor = function()
  local option_idx = vim.api.nvim_win_get_cursor(0)[1]
  local option_name = options.order[option_idx]
  local current_value = options.values[option_name]
  if type(current_value) == 'boolean' then
    options.values[option_name] = not current_value
    populate_options_buf()
    if option_name == 'preview' then
      if not current_value then
        open_preview()
      else
        close_preview()
      end
    else
      update_preview()
    end
  else
    if option_name == 'buffer' then
      vim.ui.select(list_loaded_bufs(), {
        prompt = 'Pick buffer to apply substitutions:',
        format_item = function(buf)
          return string.format('%d: %s', buf, vim.api.nvim_buf_get_name(buf))
        end,
      }, function(buf)
          if buf then
            options.values.buffer = buf
            populate_options_buf()
            update_preview()
          end
      end)
    end
  end
end

local noautocmd = function(ignore, callback)
  local current_eventignore = vim.o.eventignore
  vim.o.eventignore = ignore
  callback()
  vim.o.eventignore = current_eventignore
end

local align_cursor = function(master_win)
  local current_pos = vim.api.nvim_win_get_cursor(master_win)
  local other_w = other_win[master_win]
  noautocmd('CursorMoved', function()
    set_cursor_row(other_w, current_pos[1])
  end)
end

local do_replace = function()
  local lines = get_ui_lines()
  search.do_replace_with_patterns(options.values.buffer, lines.patterns, lines.replacements)
end

M.open = function(opts)
  if is_open then
    return
  end
  is_open = true
  opts = opts or {}
  options.populate()

  bufs.patterns = vim.api.nvim_create_buf(false, true)
  bufs.replacements = vim.api.nvim_create_buf(false, true)
  bufs.options = vim.api.nvim_create_buf(false, true)
  bufs.preview = vim.api.nvim_create_buf(false, true)

  if not opts.fresh then
    vim.api.nvim_buf_set_lines(bufs.patterns, 0, -1, true, last_lines.patterns or {})
    vim.api.nvim_buf_set_lines(bufs.replacements, 0, -1, true, last_lines.replacements or {})
  end
  populate_options_buf()

  local gheight, gwidth = get_nvim_ui_size()

  wins.patterns = vim.api.nvim_open_win(bufs.patterns, true, {
    relative = 'editor',
    width = options.values.patterns_width,
    height = options.values.patterns_height,
    row = (gheight - options.values.total_height) / 2,
    col = (gwidth - options.values.total_width) / 2,
    style = 'minimal',
    border = {"┏", "━" ,"┳", "┃", "┻", "━", "┗", "┃"},
    title = {{'patterns', 'Number'}},
    title_pos = 'center',
  })
  wins.replacements = vim.api.nvim_open_win(bufs.replacements, false, {
    relative = 'editor',
    width = options.values.patterns_width,
    height = options.values.patterns_height,
    row = (gheight - options.values.total_height) / 2,
    col = (gwidth - options.values.total_width) / 2 + options.values.patterns_width + 1,
    style = 'minimal',
    border = {"┳", "━" ,"┳", "┃", "┻", "━", "┻", "┃"},
    title = {{'replacements', 'Number'}},
    title_pos = 'center',
  })
  other_win[wins.patterns] = wins.replacements
  other_win[wins.replacements] = wins.patterns
  wins.options = vim.api.nvim_open_win(bufs.options, false, {
    relative = 'editor',
    width = options.values.options_width,
    height = options.values.patterns_height,
    row = (gheight - options.values.total_height) / 2,
    col = (gwidth - options.values.total_width) / 2 + 2 * (options.values.patterns_width + 1),
    style = 'minimal',
    border = {"┳", "━" ,"┓", "┃", "┛", "━", "┻", "┃"},
    title = {{'options', 'Comment'}},
    title_pos = 'center',
  })
  if options.values.preview then
    open_preview()
  end

  for _, buf in ipairs({bufs.patterns, bufs.replacements, bufs.options}) do
    vim.keymap.set('n', 'q', M.close, {buffer = buf})
    vim.keymap.set('n', '<C-s>', toggle_options_focus, {buffer = buf})
    vim.api.nvim_create_autocmd('WinClosed', {
      callback = function() M.close() end,
      buffer = buf,
    })
  end
  for _, buf in ipairs({bufs.patterns, bufs.replacements}) do
    vim.keymap.set('n', '<CR>', do_replace, {buffer = buf})
    vim.keymap.set('n', '<Tab>', toggle_side, {buffer = buf})
    vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
      callback = update_preview,
      buffer = buf,
    })
  end
  vim.keymap.set('n', '<CR>', toggle_option_under_cursor, {buffer = bufs.options})
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

M.close = function()
  if not is_open then
    return
  end
  is_open = false
  save_lines()
  for _, win in pairs(wins) do
    if vim.api.nvim_win_is_valid(win) then
      noautocmd('WinClosed,CursorMoved', function()
        vim.api.nvim_win_close(win, true)
      end)
    end
  end
  teardown()
end

M.toggle = function()
  if is_open then
    M.close()
  else
    M.open()
  end
end

M.reset = function()
  last_lines = {}
end

return M
