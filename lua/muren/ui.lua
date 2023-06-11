local M = {}

local Path = require('plenary.path')

local utils = require('muren.utils')
local options = require('muren.options')
local search = require('muren.search')

local last_lines = {}
local last_edited_bufs
local last_undoed_bufs

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
  for _, name in ipairs(options.values.order) do
    local value = options.values[name]
    local is_on
    -- if (name == 'buffer' and not options.values['cwd']) or (name ~= 'buffer' and value) then
    if name == 'buffer' then
      is_on = not options.values.cwd
    elseif name == 'dir' then
      is_on = options.values.cwd
    elseif name == 'files' then
      is_on = options.values.cwd
    else
      is_on = value
    end
    local prefix
    if is_on then
      prefix = ''
      table.insert(highlights, options.values.hl.options.on)
    else
      prefix = ''
      table.insert(highlights, options.values.hl.options.off)
    end
    if type(value) == 'boolean' then
      table.insert(lines, string.format('%s %s', prefix, name))
    elseif name == 'dir' then
      table.insert(lines, string.format('%s %s: %s', prefix, name, Path.new(value):shorten()))
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

local buf_normal = function(buf, keys)
  vim.api.nvim_buf_call(buf, function()
    vim.cmd.normal{vim.api.nvim_replace_termcodes(keys, true, false, true), bang = true}
  end)
end

local scroll_preview_up = function()
  buf_normal(bufs.preview, 'Hzz')
end

local scroll_preview_down = function()
  buf_normal(bufs.preview, 'Lzz')
end

local format_cwd_preview_line = function(line, buf_info)
  local path = Path.new(buf_info.name):make_relative(vim.fn.getcwd())
    -- NOTE a pity that make_relative does not return a new Path
  path = Path.new(path):shorten()
  return {
    highlights = {
      {
        col_start = 0,
        col_end = #path,
        hl_group = options.values.hl.preview.cwd.path,
      },
      {
        col_start = #path + 2,
        col_end = #path + 2 + #string.format('%d', buf_info.lnum),
        hl_group = options.values.hl.preview.cwd.lnum,
      },
    },
    text = string.format(
      '%s (%d): %s',
      path,
      buf_info.lnum,
      line
    )
  }
end

local update_preview = function()
  if not preview_open then
    return
  end
  if options.values.filetype_in_preview and not options.values.cwd then
    vim.api.nvim_buf_set_option(
      bufs.preview,
      'filetype',
      vim.api.nvim_buf_get_option(options.values.buffer, 'filetype')
    )
  end
  local ui_lines = get_ui_lines()
  local relevant_line_nums = {}
  for _, pattern in ipairs(ui_lines.patterns) do
    for buf, lines in pairs(search.find_all_line_matches(pattern, options.values)) do
      for _, line in ipairs(lines) do
        if not relevant_line_nums[buf] then
          relevant_line_nums[buf] = {}
        end
        relevant_line_nums[buf][line - 1] = true
      end
    end
  end

  local relevant_lines = {}
  local buf_info_per_idx = {}
  local current_buf = vim.api.nvim_get_current_buf()
  for buf, line_nums in pairs(relevant_line_nums) do
    for line_num, _ in pairs(line_nums) do
      -- NOTE we need to do this to make sure the buffer is loaded since it's not done by :vim
      vim.api.nvim_set_current_buf(buf)
      local lines = vim.api.nvim_buf_get_lines(buf, line_num, line_num + 1, false)
      if #lines > 0 then
        table.insert(relevant_lines, lines[1])
        table.insert(buf_info_per_idx, {
          buf = buf,
          name = vim.api.nvim_buf_get_name(buf),
          lnum = line_num,
        })
      end
    end
  end
  vim.api.nvim_set_current_buf(current_buf)

  vim.api.nvim_buf_set_lines(bufs.preview, 0, -1, true, relevant_lines)
  search.do_replace_with_patterns(
    ui_lines.patterns,
    ui_lines.replacements,
    {
      buffer = bufs.preview,
      two_step = options.values.two_step,
      all_on_line = options.values.all_on_line,
      range = nil,
    }
  )
  if options.values.cwd then
    local prefixed_lines = {}
    local highlights = {}
    for i, buf_info in ipairs(buf_info_per_idx) do
      local format_spec = format_cwd_preview_line(
        vim.api.nvim_buf_get_lines(bufs.preview, i - 1, i, true)[1],
        buf_info
      )
      table.insert(prefixed_lines, format_spec.text)
      table.insert(highlights, format_spec.highlights)
    end
    vim.api.nvim_buf_set_lines(bufs.preview, 0, -1, true, prefixed_lines)
    for line, hls in ipairs(highlights) do
      for _, hl_spec in ipairs(hls) do
        vim.api.nvim_buf_add_highlight(bufs.preview, -1, hl_spec.hl_group, line - 1, hl_spec.col_start, hl_spec.col_end)
      end
    end
  end
  buf_normal(bufs.preview, 'gg')
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

local make_ui_positions = function(opts)
  -- NOTE assumes that options will be populated by options.populate() before this is called,
  -- as the open_preview function does
  local gheight, gwidth = get_nvim_ui_size()
  local anchors = {
    center_row = (gheight - opts.total_height) / 2,
    center_col = (gwidth - opts.total_width) / 2,
    top = 0,
    bottom = (gheight - opts.total_height),
    left = 0,
    right = (gwidth - opts.total_width),
  }

  local v_anchor, h_anchor = anchors[opts.vertical_anchor], anchors[opts.horizontal_anchor]
  local v_offset = opts.vertical_offset * (v_anchor == anchors.bottom and -1 or 1)
  local h_offset = opts.horizontal_offset * (h_anchor == anchors.right and -1 or 1)
  local adjusted_row = math.max(anchors.top, math.min(v_anchor + v_offset, anchors.bottom))
  local adjusted_col = math.max(anchors.left, math.min(h_anchor + h_offset, anchors.right))
  return {
    patterns = { row = adjusted_row, col = adjusted_col },
    preview = { row = adjusted_row + opts.patterns_height + 2, col = adjusted_col },
    replacements = { row = adjusted_row, col = adjusted_col + opts.patterns_width + 1 },
    options = { row = adjusted_row, col = adjusted_col + 2 * (opts.patterns_width + 1) },
  }
end

local open_preview = function()
  if preview_open then
    return
  end
  local ui_positions = make_ui_positions(options.values)
  wins.preview = vim.api.nvim_open_win(bufs.preview, false, {
    relative = 'editor',
    width = options.values.total_width - 2,
    height = options.values.preview_height,
    row = ui_positions.preview.row,
    col = ui_positions.preview.col,
    style = 'minimal',
    border = {"┏", "━" ,"┓", "┃", "┛", "━", "└", "┃"},
    title = {{'preview', 'Comment'}},
    title_pos = 'center',
    zindex = 10,
  })
  vim.api.nvim_win_set_option(wins.preview, 'wrap', false)
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
  local option_name = options.values.order[option_idx]
  local current_value = options.values[option_name]
  if type(current_value) == 'boolean' then
    options.values[option_name] = not current_value
    if option_name == 'preview' then
      if not current_value then
        open_preview()
      else
        close_preview()
      end
    end
  else
    if option_name == 'buffer' then
      if options.values.cwd then
        options.values.cwd = false
      else
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
        return
      end
    elseif option_name == 'dir' then
      if not options.values.cwd then
        options.values.cwd = true
      else
        vim.ui.input({prompt = 'Pick dir', default = options.values.dir}, function(dir)
          if dir then
            options.values.dir = dir
              populate_options_buf()
              update_preview()
          end
        end)
        return
      end
    elseif option_name == 'files' then
      if not options.values.cwd then
        options.values.cwd = true
      else
        vim.ui.input({prompt = 'Pick pattern for files', default = options.values.files}, function(pattern)
          if pattern then
            options.values.files = pattern
              populate_options_buf()
              update_preview()
          end
        end)
        return
      end
    end
  end
  populate_options_buf()
  update_preview()
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
  last_edited_bufs = search.do_replace_with_patterns(
    lines.patterns,
    lines.replacements,
    options.values
  )
  last_undoed_bufs = nil
end

local do_undo = function()
  if not last_edited_bufs then
    vim.notify('nothing to undo')
    return
  end
  for buf in pairs(last_edited_bufs) do
    buf_normal(buf, 'u')
  end
  last_undoed_bufs = last_edited_bufs
  last_edited_bufs = nil
end

local do_redo = function()
  if not last_undoed_bufs then
    vim.notify('nothing to redo')
    return
  end
  for buf in pairs(last_undoed_bufs) do
    buf_normal(buf, '<C-r>')
  end
  last_edited_bufs = last_undoed_bufs
  last_undoed_bufs = nil
end

M.open = function(opts)
  if is_open then
    return
  end
  is_open = true
  opts = opts or {}
  options.populate(opts)

  bufs.patterns = vim.api.nvim_create_buf(false, true)
  bufs.replacements = vim.api.nvim_create_buf(false, true)
  bufs.options = vim.api.nvim_create_buf(false, true)
  bufs.preview = vim.api.nvim_create_buf(false, true)

  if opts.patterns then
    vim.api.nvim_buf_set_lines(bufs.patterns, 0, -1, true, opts.patterns)
  elseif not opts.fresh then
    vim.api.nvim_buf_set_lines(bufs.patterns, 0, -1, true, last_lines.patterns or {})
    vim.api.nvim_buf_set_lines(bufs.replacements, 0, -1, true, last_lines.replacements or {})
  end
  populate_options_buf()

  local ui_positions = make_ui_positions(options.values)
  wins.patterns = vim.api.nvim_open_win(bufs.patterns, true, {
    relative = 'editor',
    width = options.values.patterns_width,
    height = options.values.patterns_height,
    row = ui_positions.patterns.row,
    col = ui_positions.patterns.col,
    style = 'minimal',
    border = {"┏", "━" ,"┳", "┃", "┻", "━", "┗", "┃"},
    title = {{'patterns', 'Number'}},
    title_pos = 'center',
    zindex = 10,
  })
  wins.replacements = vim.api.nvim_open_win(bufs.replacements, false, {
    relative = 'editor',
    width = options.values.patterns_width,
    height = options.values.patterns_height,
    row = ui_positions.replacements.row,
    col = ui_positions.replacements.col,
    style = 'minimal',
    border = {"┳", "━" ,"┳", "┃", "┻", "━", "┻", "┃"},
    title = {{'replacements', 'Number'}},
    title_pos = 'center',
    zindex = 10,
  })
  other_win[wins.patterns] = wins.replacements
  other_win[wins.replacements] = wins.patterns
  wins.options = vim.api.nvim_open_win(bufs.options, false, {
    relative = 'editor',
    width = options.values.options_width,
    height = options.values.patterns_height,
    row = ui_positions.options.row,
    col = ui_positions.options.col,
    style = 'minimal',
    border = {"┳", "━" ,"┓", "┃", "┛", "━", "┻", "┃"},
    title = {{'options', 'Comment'}},
    title_pos = 'center',
    zindex = 10,
  })
  vim.api.nvim_win_set_option(wins.options, 'wrap', false)
  if options.values.preview then
    open_preview()
  end

  local keys = options.values.keys
  for _, buf in ipairs({bufs.patterns, bufs.replacements, bufs.options}) do
    vim.keymap.set('n', keys.close, M.close, {buffer = buf})
    vim.keymap.set('n', keys.toggle_options_focus, toggle_options_focus, {buffer = buf})
    vim.keymap.set('n', keys.do_undo, do_undo, {buffer = buf})
    vim.keymap.set('n', keys.do_redo, do_redo, {buffer = buf})
    vim.keymap.set('n', keys.scroll_preview_up, scroll_preview_up, {buffer = buf})
    vim.keymap.set('n', keys.scroll_preview_down, scroll_preview_down, {buffer = buf})
    vim.api.nvim_create_autocmd('WinClosed', {
      callback = function() M.close() end,
      buffer = buf,
    })
  end
  for _, buf in ipairs({bufs.patterns, bufs.replacements}) do
    vim.keymap.set('n', keys.do_replace, do_replace, {buffer = buf})
    vim.keymap.set('n', keys.toggle_side, toggle_side, {buffer = buf})
    vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
      callback = update_preview,
      buffer = buf,
    })
  end
  vim.keymap.set('n', keys.toggle_option_under_cursor, toggle_option_under_cursor, {buffer = bufs.options})
  vim.api.nvim_create_autocmd('CursorMoved', {
    callback = function() align_cursor(wins.patterns) end,
    buffer = bufs.patterns,
  })
  vim.api.nvim_create_autocmd('CursorMoved', {
    callback = function() align_cursor(wins.replacements) end,
    buffer = bufs.replacements,
  })
end

M.open_unique = function(opts)
  opts.patterns = search.get_unique_last_search_matches(opts)
  M.open(opts)
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

M.toggle = function(opts)
  if is_open then
    M.close()
  else
    M.open(opts)
  end
end

M.reset = function()
  last_lines = {}
end

return M
