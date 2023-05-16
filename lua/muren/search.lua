local M = {}

local nvim_exec2 = vim.api.nvim_exec2 or vim.api.nvim_exec

local find_all_line_matches_in_current_buf = function(pattern, opts)
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
  pcall(nvim_exec2, src, {output = true})
end

local get_grep_matches = function(pattern, opts)
  local current_cwd = vim.fn.getcwd()
  vim.cmd.cd(opts.dir)
  local success = pcall(vim.cmd.vim, string.format(
    '/%s/j%s %s',
    pattern,
    opts.replace_opt_chars or '',
    opts.files or '**/*'
  ))
  vim.cmd.cd(current_cwd)
  if not success then
    return {}
  end
  return vim.fn.getqflist()
end

local get_affected_bufs = function(pattern, opts)
  local unique_bufs = {}
  for _, qitem in ipairs(get_grep_matches(pattern, opts)) do
    unique_bufs[qitem.bufnr] = true
  end
  return unique_bufs
end

local function search_replace(pattern, replacement, opts)
  local affected_bufs
  if opts.cwd then
    affected_bufs = get_affected_bufs(pattern, opts)
    for buf, _ in pairs(affected_bufs) do
      search_replace(pattern, replacement, {
        buf = buf,
        replace_opt_chars = opts.replace_opt_chars,
      })
    end
  else
    affected_bufs = {[opts.buf] = true}
    vim.api.nvim_buf_call(opts.buf, function()
      cmd_silent(string.format(
        '%ss/%s/%s/%s',
        opts.range or '%',
        pattern,
        replacement,
        opts.replace_opt_chars or ''
      ))
    end)
  end
  vim.opt.hlsearch = false
  return affected_bufs
end

local multi_replace_recursive = function(patterns, replacements, opts)
  local affected_bufs = {}
  for i, pattern in ipairs(patterns) do
    local replacement = replacements[i] or ''
    affected_bufs = vim.tbl_extend('keep', affected_bufs, search_replace(
      pattern,
      replacement,
      opts
    ))
  end
  return affected_bufs
end

local multi_replace_non_recursive = function(patterns, replacements, opts)
  local affected_bufs = {}
  local replacement_per_placeholder = {}
  for i, pattern in ipairs(patterns) do
    local placeholder = string.format('___MUREN___%d___', i)
    local replacement = replacements[i] or ''
    replacement_per_placeholder[placeholder] = replacement
    affected_bufs = vim.tbl_extend('keep', affected_bufs, search_replace(
      pattern,
      placeholder,
      opts
    ))
  end
  -- TODO if we would have eg 'c' replace_opt_chars I guess we don't want it here?
  for placeholder, replacement in pairs(replacement_per_placeholder) do
    search_replace(
      placeholder,
      replacement,
      opts
    )
  end
  return affected_bufs
end

M.find_all_line_matches = function(pattern, opts)
  local lines_per_buf = {}
  if opts.cwd then
    for _, qitem in ipairs(get_grep_matches(pattern, opts)) do
      if not lines_per_buf[qitem.bufnr] then
        lines_per_buf[qitem.bufnr] = {}
      end
      table.insert(lines_per_buf[qitem.bufnr], qitem.lnum)
    end
  else
    vim.api.nvim_buf_call(opts.buffer, function()
      lines_per_buf[opts.buffer] = find_all_line_matches_in_current_buf(pattern, opts)
    end)
  end
  return lines_per_buf
end

M.do_replace_with_patterns = function(patterns, replacements, opts)
  local replace_opts = {
    buf = opts.buffer,
    cwd = opts.cwd,
    dir = opts.dir,
    files = opts.files,
  }
  if opts.all_on_line then
    replace_opts.replace_opt_chars = 'g'
  end
  if opts.range then
    replace_opts.range = string.format('%d,%d', opts.range.start, opts.range._end)
  else
    replace_opts.range = '%'
  end
  if opts.two_step then
    return multi_replace_non_recursive(patterns, replacements, replace_opts)
  else
    return multi_replace_recursive(patterns, replacements, replace_opts)
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
