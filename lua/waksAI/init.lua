---@mod waksAI Main Entry Point
---@brief Integrated AI Assistant for Neovim with dynamic provider support.
package.loaded["waksAI.code_change"] = nil
local M                              = {}

-- Internal Module Imports
local state                          = require("waksAI.state")
local ui                             = require("waksAI.ui")
local api                            = require("waksAI.api")
local utils                          = require("waksAI.utils")
local picker                         = require("waksAI.picker")
local bridge                         = require("waksAI.bridge")
--- local inline = require("waksAI.code_change")

---Initializes the plugin and merges user configuration.
---@param opts table? Configuration options
function M.setup(opts)
    -- 1. Initialize Global State
    state.setup(opts or {})

    -- 2. Initialize UI Components
    ui.setup({
        width             = 70,
        position          = "right",
        show_timestamps   = true,
        show_session_info = true,
        theme             = {
            background = "#1e1e2e",
            foreground = "#cdd6f4",
            accent     = "#89b4fa",
            secondary  = "#7f849c",
            success    = "#a6e3a1",
            warning    = "#f9e2af",
            error      = "#f38ba8",
            code_bg    = "#181825",
            border     = "#313244",
        }
    })

    -- 3. Register Global Keymaps
    M.keymaps()

    local inline = require("waksAI.code_change")
    -- 4. Initial Hardware/Highlight setup
    inline:init()
end

---Opens the chat window and prompts for user input.
function M.prompt()
    ui.open_chat()
    bridge.ui_input({ prompt = "Question for AI:" }, function(user_text)
        if not user_text or user_text == "" then return end

        ui.render_user_sidebar(user_text)
        ui.render_thinking_sidebar()

        api.send(user_text, function(ai_text, code_blocks)
            ui.clear_loading()
            ui.render_ai_sidebar(ai_text, code_blocks)

            if code_blocks and #code_blocks > 0 then
                for _, cb in ipairs(code_blocks) do
                    ui.render_ai_with_actions(cb.code, { is_code = true, lang = cb.lang })
                end
            end

            -- Update session history for context retention
            table.insert(state.session.history, { role = "user", content = user_text })
            table.insert(state.session.history, { role = "assistant", content = ai_text })
        end)
    end)
end

function M.explain_visual()
    local visual_text = utils.get_visual_selection()
    if not visual_text or visual_text == "" then
        ui.render_system("No text selected", "warning")
        return
    end

    -- Choice: We provide a default context so the user knows what they are explaining
    local default_text = "Please explain this code:\n"

    bridge.ui_input({
        prompt = "Explain Selection",
        default = default_text
    }, function(user_instructions)
        if not user_instructions or user_instructions == "" then return end

        -- Refined Prompt Construction
        local final_prompt = string.format(
            "%s\n\n### CONTEXT: SELECTED CODE\n```\n%s\n```",
            user_instructions,
            visual_text
        )

        -- Switch to the Sidebar UI
        ui.open_chat()
        ui.render_user_inline(user_instructions)
        ui.render_thinking() -- Target the sidebar buffer instead of line_num

        api.send(final_prompt, function(ai_text, code_blocks)
            ui.clear_loading()
            ui.render_ai(ai_text, { inline = true })

            if code_blocks and #code_blocks > 0 then
                for _, cb in ipairs(code_blocks) do
                    ui.render_ai(cb.code, { is_code = true, lang = cb.lang, inline = true })
                end
            end

            -- Persist to State
            table.insert(state.session.history, { role = "user", content = final_prompt })
            table.insert(state.session.history, { role = "assistant", content = ai_text })
        end)
    end)
end

-- In init.lua or code_change.lua
function M.quick_suggest()
    local prompt = "Generate a hello world function"
    api.send(prompt, function(answer)
        -- This will appear right under the cursor as virtual text
        ui.render_ai_inline(answer)
    end)
end

---Cycles through available models and notifies the user.
function M.toggle_model()
    local next_model = state.cycle_model()
    ui.render_system("Model switched to: " .. next_model, "success")
end

function M.toggle_chat()
    if M.sidebar_win and bridge.window_is_valid(M.sidebar_win) then
        local success, err = pcall(function()
            bridge.close_window(M.sidebar_win, true)
        end)
        M.sidebar_win = nil -- Always clear the reference after closing

        if not success then
            bridge.notify("Window close failed: " .. tostring(err), bridge.get_log_level("warn"))
        end
    else
        ui.open_chat()
    end
end

---Clears the current chat session buffer and history.
function M.clear_history()
    state.session.history = {}
    ui.clear_chat()
    ui.render_system("Chat history cleared", "success")
end

-- Render chat history
function M.render_history()
    for _, entry in ipairs(state.session.history) do
        if entry.role == "user" then
            ui.render_user(entry.content)
        else
            ui.render_ai(entry.content)
        end
    end
end

function M.keymaps()
    local n = "n"
    local v = "v"

    -- Chat UI Controls
    bridge.set_keymap(n, "<leader>ws", M.prompt, { desc = "WaksAI: Send prompt" })
    bridge.set_keymap(v, "<leader>wv", M.explain_visual, { desc = "WaksAI: Explain selection" })
    bridge.set_keymap(n, "<leader>wc", M.clear_history, { desc = "WaksAI: Clear history" })

    -- Model & Provider Management (Pickers)
    bridge.set_keymap(n, "<leader>wp", picker.switch_provider, { desc = "WaksAI: Switch provider" })
    bridge.set_keymap(n, "<leader>wM", picker.switch_model, { desc = "WaksAI: Switch model" })
    bridge.set_keymap(n, "<leader>wr", picker.register_model, { desc = "WaksAI: Register model" })

    -- Inline AI (Ghost Text)
    bridge.set_keymap({ n, v }, "<leader>ai", function()
        require("waksAI.code_change"):get_suggestions_for_selection()
    end, { desc = "WaksAI: Inline suggestion" })
end

bridge.create_user_command("WaksAIAsk", function(opts)
    api.send(opts.args, function(reply)
        bridge.notify("AI: " .. reply, bridge.get_log_level("info"))
    end)
end, { nargs = "+" })

return M
