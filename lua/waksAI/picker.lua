---@mod waksAI.picker Model and Provider Selection UI
---@brief Handles the interactive selection of AI models and providers.
local state = require("waksAI.state")
local utils = require("waksAI.utils")
local bridge = require("waksAI.bridge")

local M = {}

---@class WaksPickerConfig
---@field icons table<string, string> UI Icons for different states
---@field theme table<string, string> Hex codes for UI accents
---@field dynamic_providers table Configuration for runtime provider discovery
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

---Internal helper for vim.ui.select with enhanced formatting
---@param title string The prompt title
---@param items string[] List of items to display
---@param on_choice fun(choice: string) Callback function when selected
---@param opts table? Additional formatting options (icon, current, format_item)
local function select_from_list(title, items, on_choice, opts)
    opts = opts or {}
    if not items or #items == 0 then
        bridge.notify(M.config.icons.warning .. " " .. title .. ": no items found", bridge.get_log_level("warn"))
        return
    end

    local formatted_items = {}
    local display_items = {}

    for i, item in ipairs(items) do
        local display_text = item
        local icon = opts.icon or "•"

        if opts.provider_map and opts.provider_map[item] then
            local provider = opts.provider_map[item]
            icon = M.get_provider_icon(provider)
        end

        if opts.format_item then
            display_text = opts.format_item(item, i)
        else
            display_text = icon .. " " .. item
        end

        table.insert(formatted_items, { display = display_text, value = item })
        table.insert(display_items, display_text)
    end

    local current = opts.current
    if current then
        title = title .. " (Current: " .. current .. ")"
    end

    --- @note(waks-work): implement a wrapper for the vim.ui.select()
    bridge.ui_selection(display_items, {
        prompt = M.config.icons.info .. " " .. title,
        format_item = function(item) return item end,
    }, function(choice_display)
        if not choice_display then return end
        for _, formatted in ipairs(formatted_items) do
            if formatted.display == choice_display then
                on_choice(formatted.value)
                break
            end
        end
    end)
end

---Returns the corresponding icon for a provider name
---@param provider string
---@return string
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

---Gathers all providers from state and dynamic config
---@return string[]
function M.get_all_providers()
    --- @note(waks-work): implement the wrappwrs for all of this
    local providers = vim.tbl_keys(state.config.providers)
    for provider, _ in pairs(M.config.dynamic_providers.custom_providers) do
        if not bridge.table_contains(providers, provider) then
            table.insert(providers, provider)
        end
    end
    if M.config.dynamic_providers.enabled then
        table.insert(providers, M.config.icons.dynamic .. " dynamic")
    end
    table.sort(providers)
    return providers
end

---Opens a picker to switch the active AI provider
function M.switch_provider()
    local providers = M.get_all_providers()
    local current_provider = state.session.providers

    select_from_list("Select AI Provider", providers, function(provider)
        if provider == M.config.icons.dynamic .. " dynamic" then
            M.create_dynamic_provider()
            return
        end

        if not state.config.providers[provider] then
            state.config.providers[provider] = {}
            bridge.notify(M.config.icons.add .. " Created new provider: " .. provider)
        end

        local success = state.set_provider(provider)
        if not success then return end

        local models = state.config.providers[provider] or {}
        bridge.notify(string.format("%s Provider → %s (%d models)", M.config.icons.success, provider, #models))

        local current_model = state.session.model
        local model_exists = bridge.table_contains(models, current_model)

        if not model_exists and #models > 0 then
            state.session.model = models[1]
            bridge.notify(M.config.icons.model .. " Auto-switched model → " .. state.session.model)
        end
        M.refresh_ui()
    end, {
        current = current_provider,
        format_item = function(provider, _)
            local icon = M.get_provider_icon(provider)
            local model_count = #(state.config.providers[provider] or {})
            local current_indicator = (provider == current_provider) and " ← Current" or ""
            if provider == M.config.icons.dynamic .. " dynamic" then
                return string.format("%s %s%s", icon, "Add new provider...", current_indicator)
            end
            return string.format("%s %-12s (%d models)%s", icon, provider, model_count, current_indicator)
        end
    })
end

---Helper to fetch models for a specific provider
---@param provider string? Defaults to current session provider
---@return string[]
function M.get_models_for_provider(provider)
    provider = provider or state.session.providers
    return state.config.providers[provider] or {}
end

---Opens a picker to switch the active AI model
function M.switch_model()
    local current_provider = state.session.providers
    local models = bridge.merge_tables({}, M.get_models_for_provider(current_provider))
    local current_model = state.session.model

    table.insert(models, M.config.icons.add .. " add_new")

    select_from_list("Select Model for " .. current_provider, models, function(model)
        if model == M.config.icons.add .. " add_new" then
            M.register_model_to_provider(current_provider)
            return
        end
        state.set_model(model)
        bridge.notify(M.config.icons.success .. " Model → " .. model)
        M.refresh_ui()
    end, {
        current = current_model,
        format_item = function(model, _)
            if model == M.config.icons.add .. " add_new" then
                return M.config.icons.add .. " Add new model..."
            end
            local current_indicator = (model == current_model) and " ← Current" or ""
            return string.format("%s %s%s", M.get_provider_icon(current_provider), model, current_indicator)
        end
    })
end

---Input prompt to create a new provider at runtime
function M.create_dynamic_provider()
    bridge.ui_input({ prompt = M.config.icons.provider .. " Enter new provider name: " }, function(name)
        if not name or name == "" then return end
        if not M.is_valid_name(name) then
            bridge.notify(M.config.icons.error .. " Invalid name format", bridge.get_log_level("error"))
            return
        end
        state.config.providers[name] = {}
        bridge.notify(M.config.icons.success .. " Created provider: " .. name)
        bridge.ui_selection({ "Yes", "No" }, { prompt = "Add models to " .. name .. " now?" }, function(choice)
            if choice == "Yes" then M.register_model_to_provider(name) end
        end)
    end)
end

---Opens provider selection to register a new model
function M.register_model()
    select_from_list("Select Provider for New Model", M.get_all_providers(), function(provider)
        if provider == M.config.icons.dynamic .. " dynamic" then
            M.create_dynamic_provider()
        else
            M.register_model_to_provider(provider)
        end
    end)
end

---Input prompt to register a new model to a specific provider
---@param provider string
function M.register_model_to_provider(provider)
    bridge.ui_input({ prompt = M.config.icons.model .. " Enter model name for " .. provider .. ": " }, function(name)
        if not name or name == "" then return end
        if not M.is_valid_name(name, true) then
            bridge.notify(M.config.icons.error .. " Invalid model name", bridge.get_log_level("error"))
            return
        end
        if state.register_model(provider, name) then
            bridge.notify(M.config.icons.success .. " Registered " .. name)
            bridge.ui_selection({ "Yes", "No" }, { prompt = "Switch to " .. name .. " now?" }, function(c)
                if c == "Yes" then
                    state.session.providers = provider
                    state.session.model = name
                    M.refresh_ui()
                end
            end)
        end
    end)
end

---Validates names for providers or models
---@param name string
---@param is_model boolean?
---@return boolean
function M.is_valid_name(name, is_model)
    local pattern = is_model and "^[%w%-_%.:/]+$" or "^[%w%-_]+$"
    return name ~= nil and name:match(pattern) ~= nil
end

---Shows a diagnostic status buffer
function M.show_status()
    local s = state.session
    local lines = {
        M.config.icons.info .. " WaksAI Status",
        "-------------------",
        string.format("%s Provider: %s", M.config.icons.provider, s.provider or "None"),
        string.format("%s Model:    %s", M.config.icons.model, s.model or "None"),
        string.format("🆔 Session:  %s", s.id or "N/A"),
        string.format("💬 History:  %d messages", #(s.history or {})),
        "",
        "Available Providers:"
    }

    for p, models in pairs(state.config.providers) do
        local cur = (p == s.provider) and " ← Current" or ""
        table.insert(lines, string.format("  %s %-10s (%d models)%s", M.get_provider_icon(p), p, #models, cur))
    end

    local buf = bridge.get_current_buffer() --- vim.api.nvim_create_buf(false, true)

    bridge.replace_line_range(buf, 0, -1, false, lines)
    bridge.set_buffer_name(buf, "WaksAI-Status")
    bridge.execute_command("vertical split")
    bridge.set_window_buffer(0, buf)

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].modifiable = false
    bridge.set_keymap("n", "q", "<cmd>q<cr>", { buffer = buf })
end

---Triggers a refresh of the Chat UI if it exists
function M.refresh_ui()
    local ok, ui = pcall(require, "waksAI.ui")
    if ok and ui.refresh_chat then ui.refresh_chat() end
end

function M.list_models()
    local current_provider = state.session.providers
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
    bridge.notify(table.concat(lines, "\n"), bridge.get_log_level("info"))
end

---Cycles through available models in the current provider
function M.quick_cycle_model()
    local old = state.session.model
    local new = state.cycle_model()
    if old ~= new then
        bridge.notify(M.config.icons.model .. " Cycled → " .. new)
        M.refresh_ui()
    end
end

-- Remove model from provider
function M.remove_model()
    local current_provider = state.session.providers
    local models = M.get_models_for_provider(current_provider)

    if #models == 0 then
        bridge.notify(M.config.icons.warning .. " No models to remove from " .. current_provider,
            bridge.get_log_level("warn"))
        return
    end

    select_from_list("Remove Model from " .. current_provider, models, function(model)
        -- Find and remove the model
        for i, m in ipairs(state.config.providers[current_provider]) do
            if m == model then
                table.remove(state.config.providers[current_provider], i)
                bridge.notify(M.config.icons.success .. " Removed model: " .. model, bridge.get_log_level("info"))

                -- If current model was removed, switch to first available
                if state.session.model == model and #state.config.providers[current_provider] > 0 then
                    state.session.model = state.config.providers[current_provider][1]
                    bridge.notify(M.config.icons.info .. " Auto-switched to: " .. state.session.model,
                        bridge.get_log_level("info"))
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

---Initializes the picker with user options
---@param opts WaksPickerConfig?
function M.setup(opts)
    M.config = bridge.merge_tables(M.config, opts or {})
end

return M
