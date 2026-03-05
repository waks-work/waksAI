-- lua/waksAI/controls/keymaps.lua
local state = require("waksAI.state.session")
local render = require("waksAI.ui.render")
local edit = require("waksAI.edit") -- We will move accept_suggestion here
local M = {}

function M.setup()
  -- Accept
  vim.keymap.set('n', '<Tab>', function()
    if state.current_response ~= "" then
      edit.accept_suggestion()
    end
  end, { desc = "WaksAI: Accept" })

  -- Dismiss
  vim.keymap.set('n', '<Esc>', function()
    render.clear()
    state.reset()
  end, { desc = "WaksAI: Clear" })
end

return M
