local M = {}

local options = require('muren.options')

local find_all_line_matches = function(pattern)
  local current_cursor = vim.api.nvim_win_get_cursor(0)
  vim.cmd('normal G$')
  local flags = 'w'
  local lines = {}
  while true do
    local line = vim.fn.search(pattern, flags)
    if line == 0 then
      break
    end
    table.insert(lines, line)
    flags = 'W'
  end
  vim.api.nvim_win_set_cursor(0, current_cursor)
  return lines
end

local cmd_silent = function(src)
  pcall(vim.api.nvim_exec2, src, {output = true})
end

local multi_replace_recursive = function(buf, patterns, replacements, opts)
  for i, pattern in ipairs(patterns) do
    local replacement = replacements[i] or ''
    vim.api.nvim_buf_call(buf, function()
      cmd_silent(string.format(
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
      cmd_silent(string.format(
        '%%s/%s/%s/%s',
        pattern,
        placeholder,
        opts.replace_opt_chars or ''
      ))
    end)
  end
  -- TODO if we would have eg 'c' replace_opt_chars I guess we don't want it here?
  for placeholder, replacement in pairs(replacement_per_placeholder) do
    vim.api.nvim_buf_call(buf, function()
      cmd_silent(string.format(
        '%%s/%s/%s/%s',
        placeholder,
        replacement,
        opts.replace_opt_chars or ''
      ))
    end)
  end
end

M.find_all_line_matches_in_buf = function(buf, pattern)
  local lines
  vim.api.nvim_buf_call(buf, function()
    lines = find_all_line_matches(pattern)
  end)
  return lines
end

M.do_replace_with_patterns = function(buf, patterns, replacements)
  local opts = {}
  if options.values.all_on_line then
    opts.replace_opt_chars = 'g'
  end
  if options.values.recursive then
    multi_replace_recursive(buf, patterns, replacements, opts)
  else
    multi_replace_non_recursive(buf, patterns, replacements, opts)
  end
end

M.get_unique_last_search_matches = function(opts)
  opts = opts or {}
  cmd_silent(string.format('lvim %s %%', opts.pattern or '//'))
  local loc_items = vim.fn.getloclist(0)
  local unique_matches = {}
  for _, loc_item in ipairs(loc_items) do
    local match_text = loc_item.text:sub(loc_item.col, loc_item.end_col - 1)
    unique_matches[match_text] = true
  end
  unique_matches = vim.tbl_keys(unique_matches)
  table.sort(unique_matches)
  return unique_matches
end

return M
