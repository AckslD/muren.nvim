local M = {}

M.open_ui = function()
  require('muren.ui').open()
end

M.close_ui = function()
  require('muren.ui').close()
end

M.toggle_ui = function()
  require('muren.ui').toggle()
end

M.open_fresh_ui = function()
  require('muren.ui').open({fresh = true})
end

M.open_unique_ui = function()
  require('muren.ui').open_unique()
end

return M
