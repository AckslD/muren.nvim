local M = {}

local ui = require('muren.ui')

M.toggle_ui = function()
  ui.toggle()
end

M.close_ui = function()
  ui.close()
end

return M
