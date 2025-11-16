-- waksAI/history.lua
local api = require("waksAI.api")

local M = {}

function M.load()
  local ok, history = pcall(api.get_history)
  if not ok or not history then
    vim.notify("Failed to load history", vim.log.levels.ERROR)
    return {}
  end
  return history
end

return M

