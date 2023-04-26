local M = {}

local find_all_line_matches = function(pattern, opts)
  local current_cursor = vim.api.nvim_win_get_cursor(0)
  -- TODO take range into account
  local range = opts.range
  if range then
    vim.cmd(string.format('%d', range.start))
  else
    vim.cmd('normal G$')
  end
  local flags = 'w'
  local lines = {}
  while true do
    local success, line
    if range then
      success, line = pcall(vim.fn.search, pattern, flags, range._end)
    else
      success, line = pcall(vim.fn.search, pattern, flags)
    end
    vim.opt.hlsearch = false
    if not success or line == 0 then
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

local search_replace = function(pattern, replacement, opts)
  cmd_silent(string.format(
    '%ss/%s/%s/%s',
    opts.range or '%',
    pattern,
    replacement,
    opts.replace_opt_chars or ''
  ))
  vim.opt.hlsearch = false
end

local multi_replace_recursive = function(buf, patterns, replacements, opts)
  for i, pattern in ipairs(patterns) do
    local replacement = replacements[i] or ''
    vim.api.nvim_buf_call(buf, function()
      search_replace(
        pattern,
        replacement,
        opts
      )
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
      search_replace(
        pattern,
        placeholder,
        opts
      )
    end)
  end
  -- TODO if we would have eg 'c' replace_opt_chars I guess we don't want it here?
  for placeholder, replacement in pairs(replacement_per_placeholder) do
    vim.api.nvim_buf_call(buf, function()
      search_replace(
        placeholder,
        replacement,
        opts
      )
    end)
  end
end

M.find_all_line_matches_in_buf = function(buf, pattern, opts)
  local lines
  vim.api.nvim_buf_call(buf, function()
    lines = find_all_line_matches(pattern, opts)
  end)
  return lines
end

M.do_replace_with_patterns = function(buf, patterns, replacements, opts)
  local replace_opts = {}
  if opts.all_on_line then
    replace_opts.replace_opt_chars = 'g'
  end
  if opts.range then
    replace_opts.range = string.format('%d,%d', opts.range.start, opts.range._end)
  else
    replace_opts.range = '%'
  end
  if opts.two_step then
    multi_replace_non_recursive(buf, patterns, replacements, replace_opts)
  else
    multi_replace_recursive(buf, patterns, replacements, replace_opts)
  end
end

local within_range = function(loc_item, range)
  if not range then
    return true
  end
  return range.start <= loc_item.lnum and loc_item.lnum <= range._end
end

M.get_unique_last_search_matches = function(opts)
  opts = opts or {}
  cmd_silent(string.format('lvim %s %%', opts.pattern or '//'))
  vim.opt.hlsearch = false
  local loc_items = vim.fn.getloclist(0)
  local unique_matches = {}
  for _, loc_item in ipairs(loc_items) do
    if within_range(loc_item, opts.range) then
      local match_text = loc_item.text:sub(loc_item.col, loc_item.end_col - 1)
      unique_matches[match_text] = true
    end
  end
  unique_matches = vim.tbl_keys(unique_matches)
  table.sort(unique_matches)
  return unique_matches
end

return M
