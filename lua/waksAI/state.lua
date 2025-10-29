local M = {}

-------------------------------------------------------
-- CONFIGURATION
-------------------------------------------------------
M.config = {
  endpoint = "http://localhost:11500/generate",   -- unified backend endpoint
  stream_endpoint = "http://localhost:11500/stream", -- stream variant
  provider = "local",                             -- default provider (auto overridden from env)
  api_key = "",                                   -- optional (for external providers)
  model = "deepseek-coder:1.3b",                  -- default model
  models = {},                                    -- flat list of models
  providers = {},                                 -- { provider = { models... } }
  max_context_turns = 12,
  comment_trim = true,
}

M.messages = {}

-------------------------------------------------------
-- SETUP
-------------------------------------------------------
function M.setup(opts)
  if opts then
    for k, v in pairs(opts) do
      M.config[k] = v
    end
  end

  -- Load ENV overrides
  local env_key = os.getenv("WAKS_API_KEY")
  if env_key and env_key ~= "" then
    M.config.api_key = env_key
  end

  local env_provider = os.getenv("WAKS_PROVIDER")
  if env_provider and env_provider ~= "" then
    M.config.provider = env_provider
  end

  local env_model = os.getenv("WAKS_MODEL")
  if env_model and env_model ~= "" then
    M.config.model = env_model
  end
end

-------------------------------------------------------
-- MODEL & PROVIDER MANAGEMENT
-------------------------------------------------------

-- Register new model under a provider
function M.register_model(provider, model_name)
  if not provider or not model_name then return end

  if not M.config.providers[provider] then
    M.config.providers[provider] = {}
  end

  -- avoid duplicates
  for _, m in ipairs(M.config.providers[provider]) do
    if m == model_name then return end
  end

  table.insert(M.config.providers[provider], model_name)

  local found = false
  for _, existing in ipairs(M.config.models) do
    if existing == model_name then
      found = true
      break
    end
  end
  if not found then
    table.insert(M.config.models, model_name)
  end
end

-- Switch current model
function M.set_model(model)
  if model and model ~= "" then
    M.config.model = model
    vim.notify("Switched to model: " .. model, vim.log.levels.INFO)
  end
end

-- Switch current provider
function M.set_provider(provider)
  if provider and provider ~= "" then
    M.config.provider = provider
    vim.notify("Switched to provider: " .. provider, vim.log.levels.INFO)
  end
end

-- Get active model
function M.current_model()
  return M.config.model
end

-- Get active provider
function M.current_provider()
  return M.config.provider
end

-- Get list of all models across all providers
function M.get_all_models()
  return M.config.models
end

-- Get models by provider
function M.get_models_by_provider(provider)
  return M.config.providers[provider] or {}
end

-------------------------------------------------------
-- MESSAGE MANAGEMENT
-------------------------------------------------------

-- Add a new message to the conversation
function M.add(role, content)
  table.insert(M.messages, { role = role, content = content })
  -- Limit context size
  if #M.messages > M.config.max_context_turns then
    table.remove(M.messages, 1)
  end
end

-- Clear message history
function M.clear_messages()
  M.messages = {}
end

return M
