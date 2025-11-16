-- waksAI/api.lua
local M = {}
local base_url = "http://127.0.0.1:11500" -- Rust backend port

local function async_request(method, path, body, callback)
  local cmd = {
    "curl", "-s", "-X", method,
    "-H", "Content-Type: application/json",
    base_url .. path
  }
  if body then
    table.insert(cmd, "-d")
    table.insert(cmd, body)
  end

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data or #data == 0 then return end
      local ok, res = pcall(vim.fn.json_decode, table.concat(data, "\n"))
      if ok and callback then callback(res) end
    end,
  })
end

function M.send(prompt, callback)
  async_request("POST", "/generate", vim.fn.json_encode({ text = prompt }), function(res)
    if callback then callback(res.response or "", res.code_blocks or {}) end
  end)
end

function M.get_models(callback)
  async_request("GET", "/models", nil, callback)
end

function M.get_history(callback)
  async_request("GET", "/history", nil, callback)
end

return M
