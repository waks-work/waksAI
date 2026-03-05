-- state.lua - Centralized State and Configuration Management
local M = {}

---@class WaksMessage
---@field role "user" | "assistant" | "system"
---@field content string
---@field timestamp number
---@field opts table?

---@class WaksConfig
---@field endpoint string Api endpoint for the backend
---@field providers table<string, string[]> Available providers and their model
---@field ui {auto_save_history: boolean, max_history_size: number}

---@class WaksSession
---@field id string Unique session identifier
---@field providers string Current active  provider
---@field model string Current active model
---@field history WaksMessage[] Conversation history
---@field context_files string[] List of files added to context_files
---@field settings table<string, boolean> UI behaviour and settings

---@type WaksConfig
M.config = {
  endpoint = "http://127.0.0.1:11500",
  providers = {
    ollama = { "llama2", "mistral", "phi3" },
    openai = { "gpt-4o", "gpt-3.5-turbo" },
    anthropic = { "claude-3-opus", "claude-3-haiku" },
  },
  ui = {
    auto_save_history = true,
    max_history_size = 100,
  }
}

---@type WaksSession
M.session = {
  id = "default",
  provider = "ollama",
  model = "llama2",
  history = {},
  context_files = {},
  settings = {
    agent_mode = false,
    auto_scroll = true,
    show_timestamps = true,
    wrap_lines = true,
  }
}

-- Buffer reference for active chat UI
M.buf = nil

--- API methods

---Initialize plugin with user options
---@param opts tables?
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.load_history()
end

---Gets a list of all the available models across all the providers.
---@return string[] # The table of all model
function M.get_all_models()
  local models = {}

  for _, list in pairs(M.config.providers) do
    vim.list_extend(models, list)
  end

  return models
end

---Register a new model to a specific provider.
---@param provider string
---@param model string
---@return boolean
function M.register_model(provider, model)
  M.config.providers[provider] = M.config.providers[provider] or {}

  -- Check if model already exists
  for _, existing_model in ipairs(M.config.providers[provider]) do
    if existing_model == model then
      vim.notify("Model '" .. model .. "' already exists in provider '" .. provider .. "'",
        vim.log.levels.WARN)
      return false
    end
  end

  table.insert(M.config.providers[provider], model)
  return true
end

---Sets active provider and ensures current model is valid
---@param provider string
---@return boolean
function M.set_provider(provider)
  if not M.config.providers[provider] then
    vim.notify("Unknown provider: " .. provider, vim.log.levels.ERROR)
    return false
  end
  M.session.provider = provider

  local is_valid_model = false
  for _, model in ipairs(M.config.providers[provider]) do
    if model == M.session.model then
      is_valid_model = true
      break
    end
  end

  if not is_valid_model and #M.config.providers[provider] > 0 then
    M.session.model = M.config.providers[provider][1]
  end

  return true
end

---Sets the model we want to use
---@param model string
function M.set_model(model)
  M.session.model = model
end

---Cycles to the next available model in the current provider
---@return string # The name of the new model
function M.cycle_model()
  local list = M.config.providers[M.session.provider] or {}
  if #list == 0 then return M.session.model end

  -- Fix: Find current index and increment
  local current_idx = -1
  for i, m in ipairs(list) do
    if m == M.session.model then
      current_idx = i
      break
    end
  end

  local next_idx = (current_idx % #list) + 1
  M.session.model = list[next_idx]
  return M.session.model
end

--- History Management

---Adds a message entry and handles persistent storage
---@param role "user" | "assistant" | "system"
---@param content string
---@param opts table
function M.add_to_history(role, content, opts)
  opts = opts or {}
  local entry = {
    role = role,
    content = content,
    timestamp = os.time(),
    opts = opts
  }

  table.insert(M.session.history, entry)

  -- Trim history if too large
  if #M.session.history > M.config.ui.max_history_size then
    table.remove(M.session.history, 1)
  end

  if M.config.ui.auto_save_history then
    M.save_history()
  end
end

--- Save in history in waksai_history.json file.
function M.save_history()
  local history_file = vim.fn.stdpath("data") .. "/waksai_history.json"
  local data = {
    session = M.session,
    config = M.config
  }

  local ok, json = pcall(vim.fn.json_encode, data)
  if ok then
    local f = io.open(history_file, "w")
    if f then
      f:write(json)
      f:close()
    end
  end
end

--- Load from waksai_history.json file.
function M.load_history()
  local history_file = vim.fn.stdpath("data") .. "/waksai_history.json"
  local f = io.open(history_file, "r")
  if f then
    local content = f:read("*a")
    f:close()

    local ok, data = pcall(vim.fn.json_decode, content)
    if ok and data then
      if data.session then
        M.session = vim.tbl_deep_extend("force", M.session, data.session)
      end
      if data.config then
        M.config = vim.tbl_deep_extend("force", M.config, data.config)
      end
    end
  end
end

--- Clears the history.
function M.clear_history()
  M.session.history = {}
  if M.config.ui.auto_save_history then
    M.save_history()
  end
end

--- Context Management

---Allow us to add a context file(s).
---@param filepath string
---@return boolean
function M.add_context_file(filepath)
  for _, existing_file in ipairs(M.session.context_files) do
    if existing_file == filepath then
      return false
    end
  end

  table.insert(M.session.context_files, filepath)
  return true
end

---Remove context file(s).
---@param filepath string
---@return boolean
function M.remove_context_file(filepath)
  for i, existing_file in ipairs(M.session.context_files) do
    if existing_file == filepath then
      table.remove(M.session.context_files, i)
      return true
    end
  end
  return false
end

---  Clears context file.
function M.clear_context_files()
  M.session.context_files = {}
end

---@note(waks-test): Verify that history doesn't exceed max_history_size
function M._test_history_trimming()
  local original_size = M.config.ui.max_history_size
  local original_history = vim.deepcopy(M.session.history)

  -- Arrange
  M.config.ui.max_history_size = 2
  M.session.history = {}

  -- Act
  M.add_to_history("user", "Msg 1", {})
  M.add_to_history("user", "Msg 2", {})
  M.add_to_history("user", "Msg 3", {}) -- This should trigger a remove of Msg 1

  -- Assert
  if #M.session.history == 2 and M.session.history[1].content == "Msg 2" then
    print("✅ Test History Trimming: PASSED")
  else
    print("❌ Test History Trimming: FAILED (Size: " .. #M.session.history .. ")")
  end

  -- Cleanup
  M.config.ui.max_history_size = original_size
  M.session.history = original_history
end

return M
