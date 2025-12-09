-- waksAI/api.lua
local M = {}
local base_url = "http://127.0.0.1:11500"

local function async_request(method, path, body, callback)
  local cmd = {
    "curl", "-s", "-X", method,
    "-H", "Content-Type: application/json",
    base_url .. path
  }

  if body then
    table.insert(cmd, "-d")
    table.insert(cmd, vim.fn.json_encode(body))
  end

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data or #data == 0 then
        if callback then callback(nil) end
        return
      end
      local ok, res = pcall(vim.fn.json_decode, table.concat(data, "\n"))
      if ok and callback then
        callback(res)
      elseif callback then
        callback(nil)
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 then
        vim.notify("API Error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
      end
    end
  })
end

-- Generate with session tracking for database
function M.generate_with_session(prompt, session_id, provider, model, callback)
  local req = {
    provider = provider or "ollama",
    model = model or "llama2",
    messages = {
      {
        role = "user",
        content = prompt
      }
    },
    stream = false,
    session_id = session_id,
    agent_mode = false
  }

  async_request("POST", "/generate", req, function(res)
    if res and res.response then
      -- This will automatically be stored in your database via:
      -- - AiSessionStatus (via session_initializer)
      -- - AiResponse (via ResponsePersister)
      callback(res.response)
    else
      vim.notify("No response from AI", vim.log.levels.ERROR)
      callback("")
    end
  end)
end

-- Simple generate without session (for quick suggestions)
function M.generate(prompt, callback)
  -- Create a unique session ID for this quick request
  local session_id = "quick_" .. tostring(os.time()) .. "_" .. math.random(1000, 9999)

  M.generate_with_session(prompt, session_id, "ollama", "codellama", function(response)
    if callback then callback(response, {}) end
  end)
end

-- Stream generate (for real-time streaming)
function M.stream_generate(prompt, session_id, provider, model, callback)
  local req = {
    provider = provider or "ollama",
    model = model or "llama2",
    messages = {
      {
        role = "user",
        content = prompt
      }
    },
    stream = true,
    session_id = session_id,
    agent_mode = false
  }

  async_request("POST", "/stream", req, callback)
end

-- For code changes tracking (uses your CodeChange table)
function M.record_code_change(session_id, file_name, previous_code, changed_code, description)
  -- This would need a new endpoint in your Rust backend
  -- For now, we'll just log it
  print(string.format(
    "Code Change - Session: %s, File: %s, Description: %s",
    session_id, file_name, description or "No description"
  ))
end

-- For frontend activity tracking (uses your FrontendActivity table)
function M.record_activity(session_id, action, payload)
  -- This would need a new endpoint in your Rust backend
  -- For now, we'll just log it
  print(string.format(
    "Activity - Session: %s, Action: %s",
    session_id, action
  ))
end

-- Maintain compatibility with existing code
function M.send(prompt, callback)
  M.generate(prompt, function(response)
    if callback then callback(response, {}) end
  end)
end

return M
