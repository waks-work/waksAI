-- picker.lua
local state = require("waksAI.state")
local utils = require("waksAI.utils")

local M = {}

-- helper: show list and run callback
local function select_from_list(title, items, on_choice)
  if #items == 0 then
    vim.notify(title .. ": no items found", vim.log.levels.WARN)
    return
  end

  vim.ui.select(items, { prompt = title }, function(choice)
    if choice then on_choice(choice) end
  end)
end

-- switch provider
function M.switch_provider()
  local providers = vim.tbl_keys(state.config.providers)
  select_from_list("Select Provider", providers, function(provider)
    state.set_provider(provider)
    vim.notify("🔄 Switched provider → " .. provider)
  end)
end

-- switch model
function M.switch_model()
  local models = state.get_all_models()
  select_from_list("Select Model", models, function(model)
    state.set_model(model)
    vim.notify("🧠 Switched model → " .. model)
  end)
end

-- dynamically register a new model
function M.register_model()
  vim.ui.input({ prompt = "Provider name: " }, function(provider)
    if not provider or provider == "" then return end
    vim.ui.input({ prompt = "Model name: " }, function(model)
      if not model or model == "" then return end
      state.register_model(provider, model)
      vim.notify("✅ Registered model `" .. model .. "` under provider `" .. provider .. "`")
    end)
  end)
end

return M
