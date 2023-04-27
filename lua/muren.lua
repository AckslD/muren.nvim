local M = {}


M.setup = function(opts)
  local options = require('muren.options')
  options.update(opts or {})

  if options.default.create_commands then
    local api = require('muren.api')
    vim.api.nvim_create_user_command('MurenOpen', api.open_ui, {range = true})
    vim.api.nvim_create_user_command('MurenClose', api.close_ui, {})
    vim.api.nvim_create_user_command('MurenToggle', api.toggle_ui, {range = true})
    vim.api.nvim_create_user_command('MurenFresh', api.open_fresh_ui, {range = true})
    vim.api.nvim_create_user_command('MurenUnique', api.open_unique_ui, {range = true})
  end
end

return M
