local M = {}

local ui = require('muren.ui')

M.open_ui = function()
  ui.open()
end

M.close_ui = function()
  ui.close()
end

M.toggle_ui = function()
  ui.toggle()
end

M.open_fresh_ui = function()
  ui.open({fresh = true})
end

return M
