local M = {}


M.setup = function(opts)
  local options = require('muren.options')
  options.update(opts or {})

  if options.default.create_commands then
    local api = require('muren.api')
    vim.api.nvim_create_user_command('MurenOpen', api.open_ui, {})
    vim.api.nvim_create_user_command('MurenClose', api.close_ui, {})
    vim.api.nvim_create_user_command('MurenToggle', api.toggle_ui, {})
    vim.api.nvim_create_user_command('MurenFresh', api.open_fresh_ui, {})
    vim.api.nvim_create_user_command('MurenUnique', api.open_unique_ui, {})
  end
end

return M
