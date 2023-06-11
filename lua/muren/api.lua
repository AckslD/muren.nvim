local M = {}

M.open_ui = function(opts)
  require('muren.ui').open(opts)
end

M.close_ui = function()
  require('muren.ui').close()
end

M.toggle_ui = function(opts)
  require('muren.ui').toggle(opts)
end

M.open_fresh_ui = function(opts)
  opts = opts or {}
  opts.fresh = true
  require('muren.ui').open(opts)
end

M.open_unique_ui = function(opts)
  require('muren.ui').open_unique(opts)
end

return M
