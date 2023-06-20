local M = {}

M.anchor_positions = {
  'top',
  'bottom',
  'left',
  'right',
  'top_left',
  'top_right',
  'bottom_left',
  'bottom_right',
}
local api = require('muren.api')
local muren_commands = {
  MurenOpen = api.open_ui,
  MurenClose = api.close_ui,
  MurenToggle = api.toggle_ui,
  MurenFresh = api.open_fresh_ui,
  MurenUnique = api.open_unique_ui,
}

local create_muren_commands = function()
  for name, muren_api in pairs(muren_commands) do
    vim.api.nvim_create_user_command(name, function(args)
      local anchor, vertical_offset, horizontal_offset = unpack(args.fargs)
      muren_api({
        range = args.range,
        line1 = args.line1,
        line2 = args.line2,
        anchor = anchor,
        vertical_offset = vertical_offset,
        horizontal_offset = horizontal_offset,
      })
    end, {
        nargs = '*',
        range = true,
        complete = function()
          local cmdline = vim.fn.getcmdline()
          local _, space_count = string.gsub(cmdline, ' ', '')
          return space_count == 1 and M.anchor_positions or {}
        end,
      })
  end
end

M.setup = function(opts)
  local options = require('muren.options')
  options.update(opts or {})
  if options.default.create_commands then
    create_muren_commands()
  end
end

return M
