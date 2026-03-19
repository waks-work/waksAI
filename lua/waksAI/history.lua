---@mod waksAI.history Help to load the history
local api = require("waksAI.api")
local bridge = require("waksAI.bridge")

local M = {}

function M.load()
    local ok, history = pcall(api.get_history)
    if not ok or not history then
        bridge.notify("Failed to load history", bridge.get_log_level("info"))
        return {}
    end
    return history
end

return M
