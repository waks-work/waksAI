-- picker.lua - Enhanced picker with dynamic model/provider support
local state = require("waksAI.state")
local utils = require("waksAI.utils")

local M = {}

-- ===================================
-- 🎨 PICKER CONFIGURATION
-- ===================================
M.config = {
  icons = {
    provider = "🔌",
    model = "🧠",
    success = "✅",
    error = "❌",
    warning = "⚠️",
    info = "ℹ️",
    add = "➕",
    refresh = "🔄",
    custom = "🎯",
    dynamic = "⚡",
  },
  theme = {
    accent = "#89b4fa",
    success = "#a6e3a1",
    warning = "#f9e2af",
    error = "#f38ba8",
  },
  -- Support for dynamic provider/model discovery
  dynamic_providers = {
    enabled = true,
    custom_providers = {}, -- User-defined providers
  }
}

-- ===================================
-- 🎯 ENHANCED PICKER FUNCTIONS
-- ===================================

-- Enhanced select with better styling and dynamic support
local function select_from_list(title, items, on_choice, opts)
  opts = opts or {}
  if not items or #items == 0 then
    vim.notify(M.config.icons.warning .. " " .. title .. ": no items found", vim.log.levels.WARN)
    return
  end

  -- Format items with icons and descriptions
  local formatted_items = {}
  local display_items = {}

  for i, item in ipairs(items) do
    local display_text = item
    local icon = opts.icon or "•"

    -- Add provider-specific icons for models
    if opts.provider_map and opts.provider_map[item] then
      local provider = opts.provider_map[item]
      icon = M.get_provider_icon(provider)
    end

    -- Format display text
    if opts.format_item then
      display_text = opts.format_item(item, i)
    else
      display_text = icon .. " " .. item
    end

    table.insert(formatted_items, { display = display_text, value = item })
    table.insert(display_items, display_text)
  end

  -- Add current selection indicator if available
  local current = opts.current
  if current then
    title = title .. " (Current: " .. current .. ")"
  end

  vim.ui.select(display_items, {
    prompt = M.config.icons.info .. " " .. title,
    format_item = function(item)
      return item
    end,
  }, function(choice_display)
    if not choice_display then return end

    -- Find the corresponding value
    for _, formatted in ipairs(formatted_items) do
      if formatted.display == choice_display then
        on_choice(formatted.value)
        break
      end
    end
  end)
end

-- Get provider icon dynamically
function M.get_provider_icon(provider)
  local provider_icons = {
    ollama = "🐋",
    openai = "⚡",
    anthropic = "🤖",
    google = "🔍",
    azure = "☁️",
    huggingface = "🤗",
    local_model = "💻",
    custom = M.config.icons.custom,
  }
  return provider_icons[provider:lower()] or M.config.icons.provider
end

-- ===================================
-- 🔌 DYNAMIC PROVIDER MANAGEMENT
-- ===================================

function M.get_all_providers()
  local providers = vim.tbl_keys(state.config.providers)

  -- Add custom providers
  for provider, _ in pairs(M.config.dynamic_providers.custom_providers) do
    if not vim.tbl_contains(providers, provider) then
      table.insert(providers, provider)
    end
  end

  -- Add dynamic provider option
  if M.config.dynamic_providers.enabled then
    table.insert(providers, M.config.icons.dynamic .. " dynamic")
  end

  table.sort(providers)
  return providers
end

function M.switch_provider()
  local providers = M.get_all_providers()
  local current_provider = state.session.provider

  select_from_list("Select AI Provider", providers, function(provider)
    -- Handle dynamic provider selection
    if provider == M.config.icons.dynamic .. " dynamic" then
      M.create_dynamic_provider()
      return
    end

    -- Check if provider exists, if not create it
    if not state.config.providers[provider] then
      state.config.providers[provider] = {}
      vim.notify(M.config.icons.add .. " Created new provider: " .. provider, vim.log.levels.INFO)
    end

    local success = state.set_provider(provider)
    if not success then return end

    -- Get available models for this provider
    local models = state.config.providers[provider] or {}
    local model_count = #models

    vim.notify(string.format(
      "%s Switched provider → %s\n%s Available models: %d",
      M.config.icons.success,
      provider,
      M.config.icons.model,
      model_count
    ), vim.log.levels.INFO)

    -- Auto-switch to first model if current model not in new provider
    local current_model = state.session.model
    local model_exists = false
    for _, model in ipairs(models) do
      if model == current_model then
        model_exists = true
        break
      end
    end

    if not model_exists and #models > 0 then
      state.session.model = models[1]
      vim.notify(string.format(
        "%s Auto-switched model → %s",
        M.config.icons.model,
        state.session.model
      ), vim.log.levels.INFO)
    elseif #models == 0 then
      vim.notify(M.config.icons.info .. " No models configured for this provider. Use ',wr' to add models.",
        vim.log.levels.INFO)
    end

    -- Update UI if chat is open
    M.refresh_ui()
  end, {
    current = current_provider,
    format_item = function(provider, idx)
      local icon = M.get_provider_icon(provider)

      local model_count = #(state.config.providers[provider] or {})
      local current_indicator = (provider == current_provider) and " ← Current" or ""

      -- Handle dynamic provider
      if provider == M.config.icons.dynamic .. " dynamic" then
        return string.format("%s %s%s", icon, "Add new provider...", current_indicator)
      end

      return string.format("%s %-12s (%d models)%s",
        icon, provider, model_count, current_indicator)
    end
  })
end

-- ===================================
-- 🧠 DYNAMIC MODEL MANAGEMENT
-- ===================================

function M.get_models_for_provider(provider)
  if not provider then
    provider = state.session.provider
  end
  return state.config.providers[provider] or {}
end

function M.switch_model()
  local current_provider = state.session.provider
  local models = M.get_models_for_provider(current_provider)
  local current_model = state.session.model

  -- Add dynamic model option
  table.insert(models, M.config.icons.add .. " add_new")

  if #models == 0 then
    vim.notify(M.config.icons.error .. " No models available for provider: " .. current_provider, vim.log.levels.ERROR)
    return
  end

  select_from_list("Select Model for " .. current_provider, models, function(model)
    -- Handle dynamic model addition
    if model == M.config.icons.add .. " add_new" then
      M.register_model_to_provider(current_provider)
      return
    end

    state.set_model(model)

    vim.notify(string.format(
      "%s Switched model → %s\n%s Provider: %s",
      M.config.icons.success,
      model,
      M.config.icons.provider,
      current_provider
    ), vim.log.levels.INFO)

    M.refresh_ui()
  end, {
    current = current_model,
    format_item = function(model, idx)
      local icon = M.get_provider_icon(current_provider)

      -- Handle add new model option
      if model == M.config.icons.add .. " add_new" then
        return string.format("%s %s", M.config.icons.add, "Add new model...")
      end

      local current_indicator = (model == current_model) and " ← Current" or ""
      return string.format("%s %s%s", icon, model, current_indicator)
    end
  })
end

-- ===================================
-- 🔄 DYNAMIC MODEL REGISTRATION
-- ===================================

function M.create_dynamic_provider()
  vim.ui.input({
    prompt = M.config.icons.provider .. " Enter new provider name: "
  }, function(provider_name)
    if not provider_name or provider_name == "" then return end

    -- Validate provider name
    if not M.is_valid_name(provider_name) then
      vim.notify(M.config.icons.error .. " Invalid provider name. Use only letters, numbers, hyphens, and underscores.",
        vim.log.levels.ERROR)
      return
    end

    -- Create the provider
    state.config.providers[provider_name] = state.config.providers[provider_name] or {}

    vim.notify(string.format(
      "%s Created provider → %s",
      M.config.icons.success,
      provider_name
    ), vim.log.levels.INFO)

    -- Ask to add models immediately
    vim.ui.select({ "Yes", "No" }, {
      prompt = M.config.icons.info .. " Add models to " .. provider_name .. " now?",
    }, function(choice)
      if choice == "Yes" then
        M.register_model_to_provider(provider_name)
      else
        -- Switch to the new provider anyway
        state.set_provider(provider_name)
        M.refresh_ui()
      end
    end)
  end)
end

function M.register_model()
  local providers = M.get_all_providers()

  select_from_list("Select Provider for New Model", providers, function(provider)
    -- Handle dynamic provider selection
    if provider == M.config.icons.dynamic .. " dynamic" then
      M.create_dynamic_provider()
      return
    end

    M.register_model_to_provider(provider)
  end, {
    format_item = function(provider, idx)
      local icon = M.get_provider_icon(provider)

      local model_count = #(state.config.providers[provider] or {})
      local count_text = string.format(" (%d models)", model_count)

      -- Handle dynamic provider
      if provider == M.config.icons.dynamic .. " dynamic" then
        return string.format("%s %s", icon, "Create new provider...")
      end

      return string.format("%s %s%s", icon, provider, count_text)
    end
  })
end

function M.register_model_to_provider(provider)
  vim.ui.input({
    prompt = M.config.icons.model .. " Enter model name for " .. provider .. ": "
  }, function(model_name)
    if not model_name or model_name == "" then return end

    -- Validate model name (more permissive for dynamic models)
    if not M.is_valid_name(model_name, true) then
      vim.notify(
        M.config.icons.error .. " Invalid model name. Use only letters, numbers, hyphens, underscores, dots, and colons.",
        vim.log.levels.ERROR)
      return
    end

    local success = state.register_model(provider, model_name)
    if not success then return end

    vim.notify(string.format(
      "%s Registered model → %s\n%s Provider: %s",
      M.config.icons.success,
      model_name,
      M.config.icons.provider,
      provider
    ), vim.log.levels.INFO)

    -- Offer to switch to new model
    vim.ui.select({ "Yes", "No" }, {
      prompt = M.config.icons.info .. " Switch to new model?",
    }, function(choice)
      if choice == "Yes" then
        state.session.provider = provider
        state.session.model = model_name
        vim.notify(M.config.icons.success .. " Switched to new model: " .. model_name, vim.log.levels.INFO)
        M.refresh_ui()
      end
    end)
  end)
end

-- ===================================
-- ✅ VALIDATION FUNCTIONS
-- ===================================

function M.is_valid_name(name, is_model)
  if is_model then
    -- More permissive for model names (can include : / . etc.)
    return name and name:match("^[%w%-_%.:/]+$") ~= nil
  else
    -- Stricter for provider names
    return name and name:match("^[%w%-_]+$") ~= nil
  end
end

-- ===================================
-- 📊 STATUS & INFO
-- ===================================

function M.show_status()
  local provider = state.session.provider or "unknown"
  local model = state.session.model or "unset"
  local session_id = state.session.id or "default"
  local history_count = #(state.session.history or {})

  local status_lines = {
    string.format("%s WaksAI Status", M.config.icons.info),
    string.format("%s Provider: %s", M.config.icons.provider, provider),
    string.format("%s Model: %s", M.config.icons.model, model),
    string.format("%s Session: %s", "🆔", session_id),
    string.format("%s History: %d messages", "💬", history_count),
    "",
    string.format("%s Available Providers:", M.config.icons.info)
  }

  -- Add provider info
  for p, models in pairs(state.config.providers) do
    local icon = M.get_provider_icon(p)
    local current_indicator = (p == provider) and " ← Current" or ""
    status_lines[#status_lines + 1] = string.format("  %s %s (%d models)%s", icon, p, #models, current_indicator)
  end

  -- Show custom providers
  if next(M.config.dynamic_providers.custom_providers) then
    status_lines[#status_lines + 1] = ""
    status_lines[#status_lines + 1] = string.format("%s Custom Providers:", M.config.icons.custom)
    for p, models in pairs(M.config.dynamic_providers.custom_providers) do
      status_lines[#status_lines + 1] = string.format("  %s %s (%d models)", M.config.icons.custom, p, #models)
    end
  end

  -- Show in split window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "WaksAI Status")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, status_lines)

  vim.cmd("split")
  vim.api.nvim_win_set_buf(0, buf)

  -- Window options
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  vim.wo.wrap = true
  vim.wo.number = false
  vim.wo.relativenumber = false

  -- Keymaps
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, silent = true })
end

-- ===================================
-- 🔧 UTILITY FUNCTIONS
-- ===================================

function M.refresh_ui()
  -- Refresh chat UI if it's open
  local ok, chat_ui = pcall(require, "waksAI.ui")
  if ok and chat_ui.refresh_chat then
    chat_ui.refresh_chat()
  end
end

function M.list_models()
  local current_provider = state.session.provider
  local current_model = state.session.model

  local lines = {
    M.config.icons.info .. " Available Models:",
    ""
  }

  for provider, model_list in pairs(state.config.providers) do
    local provider_icon = M.get_provider_icon(provider)

    lines[#lines + 1] = string.format("%s %s:", provider_icon, provider)

    for _, model in ipairs(model_list) do
      local current_indicator = (provider == current_provider and model == current_model) and " ← Current" or ""
      lines[#lines + 1] = string.format("  • %s%s", model, current_indicator)
    end

    lines[#lines + 1] = ""
  end

  -- Show in preview
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- Quick model cycling with notification
function M.quick_cycle_model()
  local old_model = state.session.model
  local new_model = state.cycle_model()

  if old_model ~= new_model then
    vim.notify(string.format(
      "%s Cycled model → %s",
      M.config.icons.model,
      new_model
    ), vim.log.levels.INFO)
    M.refresh_ui()
  else
    vim.notify(M.config.icons.warning .. " Only one model available", vim.log.levels.WARN)
  end
end

-- Remove model from provider
function M.remove_model()
  local current_provider = state.session.provider
  local models = M.get_models_for_provider(current_provider)

  if #models == 0 then
    vim.notify(M.config.icons.warning .. " No models to remove from " .. current_provider, vim.log.levels.WARN)
    return
  end

  select_from_list("Remove Model from " .. current_provider, models, function(model)
    -- Find and remove the model
    for i, m in ipairs(state.config.providers[current_provider]) do
      if m == model then
        table.remove(state.config.providers[current_provider], i)
        vim.notify(M.config.icons.success .. " Removed model: " .. model, vim.log.levels.INFO)

        -- If current model was removed, switch to first available
        if state.session.model == model and #state.config.providers[current_provider] > 0 then
          state.session.model = state.config.providers[current_provider][1]
          vim.notify(M.config.icons.info .. " Auto-switched to: " .. state.session.model, vim.log.levels.INFO)
        elseif #state.config.providers[current_provider] == 0 then
          state.session.model = nil
        end

        M.refresh_ui()
        break
      end
    end
  end, {
    format_item = function(model, idx)
      local icon = M.get_provider_icon(current_provider)
      local current_indicator = (model == state.session.model) and " ← Current" or ""
      return string.format("%s %s%s", icon, model, current_indicator)
    end
  })
end

-- ===================================
-- 🎯 SETUP
-- ===================================

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

return M
