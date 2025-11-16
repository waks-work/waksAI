local state = require("waksAI.state")

local M = {}

local function json_encode(tbl) return vim.fn.json_encode(tbl) end
local function json_decode(str)
  local ok, val = pcall(vim.fn.json_decode, str)
  if ok then return val else return nil end
end

-- Non-streaming call
function M.send(payload, callback)
  local body = json_encode(payload)
  local resp = vim.fn.system({
    "curl", "-s",
    "-X", "POST",
    "-H", "Content-Type: application/json",
    "-d", body,
    state.config.endpoint .. "/generate",
  })
  local decoded = json_decode(resp)
  if callback then callback(decoded or resp) end
end

-- Streaming call
function M.stream(payload, on_chunk)
  local handle
  handle = vim.fn.jobstart({
    "curl", "-N", "-X", "POST",
    "-H", "Content-Type: application/json",
    "-d", json_encode(payload),
    state.config.endpoint .. "/stream",
  }, {
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          on_chunk(line)
        end
      end
    end,
    stdout_buffered = false,
    on_exit = function()
      on_chunk("[END]")
    end,
  })
end

return M

