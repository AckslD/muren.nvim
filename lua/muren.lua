local M = {}

local api = require('muren.api')

M.setup = function()
  vim.api.nvim_create_user_command('MurenToggle', api.toggle_ui, {})
  vim.api.nvim_create_user_command('MurenClose', api.close_ui, {})
end

return M
