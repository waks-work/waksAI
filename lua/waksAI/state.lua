local M = {}

M.config = {
  endpoint = "http://localhost:11434/api/generate",
  model = "deepseek-coder:1.3b",
  models = { "deepseek-coder:1.3b", "stable-code:3b-code-q4_0" },
  max_context_turns = 12,   -- keep last N turns for prompt context
  comment_trim = true,      -- reduce long comments in code
}

M.messages = {}  -- { {role="user"|"ai"|"system", content=""}, ... }

function M.setup(opts)
  if opts then
    for k,v in pairs(opts) do
      M.config[k] = v
    end
  end
end

function M.add(role, content)
  table.insert(M.messages, { role = role, content = content })
  -- cap size
  local max = M.config.max_context_turns * 2
  if #M.messages > max then
    -- keep last "max" messages
    local start = #M.messages - max + 1
    local new = {}
    for i = start, #M.messages do table.insert(new, M.messages[i]) end
    M.messages = new
  end
end

function M.get_context_text()
  local buf = {}
  -- lightweight chat history for /generate
  for _, m in ipairs(M.messages) do
    local who = (m.role == "user") and "User" or (m.role == "ai" and "Assistant" or "System")
    table.insert(buf, who .. ": " .. m.content)
  end
  return table.concat(buf, "\n")
end

function M.current_model()
  return M.config.model
end

function M.cycle_model()
  local idx = 1
  for i, v in ipairs(M.config.models) do
    if v == M.config.model then idx = i break end
  end
  local next_i = (idx % #M.config.models) + 1
  M.config.model = M.config.models[next_i]
  return M.config.model
end

return M

