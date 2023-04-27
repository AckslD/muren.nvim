local M = {}

local get_range = function(opts)
  local range
  if opts.range == 2 then
    range = {start = opts.line1, _end = opts.line2}
  end
  return range
end

M.open_ui = function(opts)
  require('muren.ui').open({range = get_range(opts)})
end

M.close_ui = function()
  require('muren.ui').close()
end

M.toggle_ui = function(opts)
  require('muren.ui').toggle({range = get_range(opts)})
end

M.open_fresh_ui = function(opts)
  require('muren.ui').open({fresh = true, range = get_range(opts)})
end

M.open_unique_ui = function(opts)
  require('muren.ui').open_unique({range = get_range(opts)})
end

return M
