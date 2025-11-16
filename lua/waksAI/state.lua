-- state.lua - Enhanced state management
local M = {}

-- ===================================
-- 🔧 CONFIGURATION
-- ===================================
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

-- ===================================
-- 💾 STATE
-- ===================================
M.session = {
  id = "default",
  provider = "ollama",
  model = "llama2",
  history = {},
  context_files = {},
  settings = {
    auto_scroll = true,
    show_timestamps = true,
    wrap_lines = true,
  }
}

-- Buffer reference for UI
M.buf = nil

-- ===================================
-- ⚙️ API
-- ===================================
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.load_history()
end

function M.get_all_models()
  local models = {}
  for _, list in pairs(M.config.providers) do
    vim.list_extend(models, list)
  end
  return models
end

function M.register_model(provider, model)
  M.config.providers[provider] = M.config.providers[provider] or {}
  
  -- Check if model already exists
  for _, existing_model in ipairs(M.config.providers[provider]) do
    if existing_model == model then
      vim.notify("Model '" .. model .. "' already exists in provider '" .. provider .. "'", vim.log.levels.WARN)
      return false
    end
  end
  
  table.insert(M.config.providers[provider], model)
  return true
end

function M.set_provider(provider)
  if not M.config.providers[provider] then
    vim.notify("Unknown provider: " .. provider, vim.log.levels.ERROR)
    return false
  end
  M.session.provider = provider
  
  -- Ensure current model is valid for new provider
  local valid_model = false
  for _, model in ipairs(M.config.providers[provider]) do
    if model == M.session.model then
      valid_model = true
      break
    end
  end
  
  if not valid_model and #M.config.providers[provider] > 0 then
    M.session.model = M.config.providers[provider][1]
  end
  
  return true
end

function M.set_model(model)
  M.session.model = model
end

function M.cycle_model()
  local list = M.config.providers[M.session.provider] or {}
  if #list == 0 then return M.session.model end

  local idx = vim.fn.index(list, M.session.model)
  idx = (idx + 1) % #list
  M.session.model = list[idx + 1]
  return M.session.model
end

-- ===================================
-- 💾 HISTORY MANAGEMENT
-- ===================================
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

function M.clear_history()
  M.session.history = {}
  if M.config.ui.auto_save_history then
    M.save_history()
  end
end

-- ===================================
-- 📁 CONTEXT MANAGEMENT
-- ===================================
function M.add_context_file(filepath)
  for _, existing_file in ipairs(M.session.context_files) do
    if existing_file == filepath then
      return false
    end
  end
  
  table.insert(M.session.context_files, filepath)
  return true
end

function M.remove_context_file(filepath)
  for i, existing_file in ipairs(M.session.context_files) do
    if existing_file == filepath then
      table.remove(M.session.context_files, i)
      return true
    end
  end
  return false
end

function M.clear_context_files()
  M.session.context_files = {}
end

return M

