local M = {}

local clip_val = require('messages.utils').clip_val

local bufs = {}
local wins = {}

M.open_ui = function()
  local lines_left = {
    "foo_0",
    "foo_1",
    "foo_2",
    "foo_3",
    "foo_4",
    "foo_5",
    "foo_6",
    "foo_7",
    "foo_8",
    "foo_9",
    "foo_10",
    "foo_11",
  }
  local lines_right = {
    "bar_0",
    "bar_1",
    "bar_2",
    "bar_3",
    "bar_4",
    "bar_5",
    "bar_6",
    "bar_7",
    "bar_8",
    "bar_9",
    "bar_10",
    "bar_11",
  }
  bufs.left = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufs.left, 0, -1, true, lines_left)
  bufs.right = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufs.right, 0, -1, true, lines_right)


  local gheight = vim.api.nvim_list_uis()[1].height
  local gwidth = vim.api.nvim_list_uis()[1].width

  local width = 60
  -- local height = math.floor(clip_val(1, math.max(#lines_left, #lines_right), gheight * 0.5))
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
    -- border = 'single',
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
    -- border = 'single',
  })

  for _, buf in pairs(bufs) do
    vim.keymap.set('n', 'q', M.close_ui, {buffer = buf})
    vim.keymap.set('n', '<Tab>', M.toggle_side, {buffer = buf})
  end
  vim.api.nvim_create_autocmd('CursorMoved', {
    callback = function() M.align_cursor(wins.left) end,
    buffer = bufs.left,
  })
  vim.api.nvim_create_autocmd('CursorMoved', {
    callback = function() M.align_cursor(wins.right) end,
    buffer = bufs.right,
  })

  -- optional: change highlight, otherwise Pmenu is used
  -- vim.api.nvim_win_set_option(win, 'winhl', 'Normal:@variable.builtin')
end

M.close_ui = function()
  for _, win in pairs(wins) do
    vim.api.nvim_win_close(win, true)
  end
end

local get_other_win = function(win)
  -- local wins = set({wins.left, wins.right})
  -- if wins[win] == nil then
  --   error(string.format("%d not one of the windows", win))
  -- end
  local valid
  local other
  for _, w in pairs(wins) do
    if win == w then
      valid = true
    else
      other = w
    end
  end
  if not valid then
    error(string.format("%d not one of the windows", win))
  end
  return other
end

M.toggle_side = function()
  local current_win = vim.api.nvim_get_current_win()
  local current_pos = vim.api.nvim_win_get_cursor(current_win)
  local other_win = get_other_win(current_win)
  vim.api.nvim_set_current_win(other_win)
  vim.api.nvim_win_set_cursor(other_win, current_pos)
end

M.align_cursor = function(master_win)
  local current_pos = vim.api.nvim_win_get_cursor(master_win)
  local other_win = get_other_win(master_win)
  vim.api.nvim_win_set_cursor(other_win, current_pos)
end

-- TODO
M.open_ui()
