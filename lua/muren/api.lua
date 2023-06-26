local M = {}

local get_range = function(opts)
  local range
  if opts.range == 2 then
    range = {start = opts.line1, _end = opts.line2}
  end
  return range
end

local get_opts = function(opts)
  opts = opts or {}
  opts.range = get_range(opts)
  return opts
end

M.open_ui = function(opts)
  require('muren.ui').open(get_opts(opts))
end

M.close_ui = function()
  require('muren.ui').close()
end

M.toggle_ui = function(opts)
  require('muren.ui').toggle(get_opts(opts))
end

M.open_fresh_ui = function(opts)
  opts = get_opts(opts)
  opts.fresh = true
  require('muren.ui').open(opts)
end

M.open_unique_ui = function(opts)
  require('muren.ui').open_unique(get_opts(opts))
end

return M
