local M = {}

-- TODO should these be global to the module?
local orig_buf
local bufs = {}
local wins = {}
local other_win = {}

local cleanup = function()
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

local align_cursor = function(master_win)
  local current_pos = vim.api.nvim_win_get_cursor(master_win)
  local other_w = other_win[master_win]
  vim.api.nvim_win_set_cursor(other_w, current_pos)
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

local do_replace = function(opts)
  opts = opts or {}
  local left_lines = vim.api.nvim_buf_get_lines(bufs.left, 0, -1, true)
  local right_lines = vim.api.nvim_buf_get_lines(bufs.right, 0, -1, true)
  if opts.recursive then
    multi_replace_recursive(orig_buf, left_lines, right_lines, opts)
  else
    multi_replace_non_recursive(orig_buf, left_lines, right_lines, opts)
  end
end


M.open_ui = function()
  orig_buf = vim.api.nvim_get_current_buf()
  bufs.left = vim.api.nvim_create_buf(false, true)
  bufs.right = vim.api.nvim_create_buf(false, true)

  local gheight = vim.api.nvim_list_uis()[1].height
  local gwidth = vim.api.nvim_list_uis()[1].width

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
    vim.keymap.set('n', 'q', M.close_ui, {buffer = buf})
    vim.keymap.set('n', '<Tab>', toggle_side, {buffer = buf})
    vim.keymap.set('n', '<CR>', do_replace, {buffer = buf})
    vim.api.nvim_create_autocmd('WinClosed', {
      callback = cleanup,
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

M.close_ui = function()
  for _, win in pairs(wins) do
    vim.api.nvim_win_close(win, true)
  end
end

M.toggle = function()
  if orig_buf then
    M.close_ui()
  else
    M.open_ui()
  end
end

return M
