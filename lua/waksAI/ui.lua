---@mod waksAI.ui Ephemeral Inline UI Engine
---@brief Manages virtual text overlays, streaming animations, and
---user input.local state = require("waksAI.state")

local state = require("waksAI.state")
local bridge = require("waksAI.bridge")
local M = {}

---@class WaksUIConfig
---@field overlay_prefix string The string prepended to virtual lines
---@field show_thinking boolean Whether to show the spinner
---@field streaming boolean Enable/disable chunked rendering
---@field thinking_frames string[] List of characters for animation
---@field thinking_speed integer Animation delay in ms
---@field icons table<string, string> UI symbols
M.config = {
    overlay_prefix = " > ",
    show_thinking = true,
    streaming = true,

    thinking_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
    thinking_speed = 80,
    streaming_speed = 25,

    icons = {
        user = "👤",
        ai = "🤖",
        thinking = "💭",
    },
}

-- ===================================
-- INLINE OVERLAY RENDERING
-- ===================================

---Renders raw lines as virtual text using extmarks
---@param line_num integer The 0-indexed line to attach to
---@param response_lines string[] The content to display
---@return integer # The namespace ID used
function M.render_inline_response(line_num, response_lines)
    local buf = bridge.get_current_buffer()
    local ns = bridge.get_namespace_id("waksai_inline")

    local max_lines = bridge.get_bline_count(buf)
    if line_num < 0 or line_num >= max_lines then
        line_num = math.max(0, math.min(line_num, max_lines - 1))
    end

    -- Clear any existing overlays in this specific namespace
    bridge.clear_overlay(buf, ns)

    local virt_lines = {}
    for _, line in ipairs(response_lines) do
        table.insert(virt_lines, { M.config.overlay_prefix .. line, "Comment" })
    end

    bridge.set_virtual_text(buf, ns, line_num, -1, virt_lines)
    return ns
end

---Displays the animated thinking spinner
---@param line_num integer|nil The line number to attach to, or nil to use cursor
function M.render_thinking(line_num)
    if type(line_num) == "string" then
        local cursor_pos = bridge.get_cursor_position()
        line_num = (cursor_pos and cursor_pos.row or 1) - 1
    elseif not line_num then
        local cursor_pos = bridge.get_cursor_position()
        line_num = (cursor_pos and cursor_pos.row or 1) - 1
    end

    local response_lines = {
        "// " .. M.config.icons.thinking .. " Thinking... [⠋]",
    }

    local ns = M.render_inline_response(line_num, response_lines)

    if M.config.show_thinking then
        M.animate_thinking(line_num, ns)
    end

    return ns
end

---Logic for the spinner loop
---@param line_num integer
---@param ns integer
function M.animate_thinking(line_num, ns)
    local frame = 1
    local timer = vim.loop.new_timer()
    state.thinking_timer = timer

    timer:start(0, M.config.thinking_speed, vim.schedule_wrap(function()
        -- Safety check: stop if thinking finished or buffer is gone
        if not state.is_thinking or not bridge.buffer_is_valid(0) then
            if not timer:is_closing() then
                timer:stop()
                timer:close()
            end
            return
        end

        local spinner = M.config.thinking_frames[frame]
        local response_lines = {
            "// " .. M.config.icons.thinking .. " Thinking... [" .. spinner .. "]",
        }

        M.render_inline_response(line_num, response_lines)
        frame = (frame % #M.config.thinking_frames) + 1
    end))
end

---Initializes the overlay state for a new AI call
---@param line_num integer
function M.render_ai_start(line_num)
    state.is_thinking = true
    state.ai_overlay_line = line_num
    state.ai_current_content = ""
    state.ai_namespace = M.render_thinking(line_num)
end

---Updates the overlay with new text chunks
---@param chunk string
function M.render_ai_stream(chunk)
    if not state.ai_overlay_line then return end

    state.is_thinking = false
    state.ai_current_content = (state.ai_current_content or "") .. chunk

    local buf = bridge.get_current_buffer()
    local ns = state.ai_namespace or bride.get_namespace_id("waksai_inline")

    local response_lines = { "// " .. M.config.icons.ai .. " Response", "" }

    for _, line in ipairs(bridge.split_strings(state.ai_current_content, "\n", false)) do
        table.insert(response_lines, line)
    end

    table.insert(response_lines, "")
    table.insert(response_lines, "[Tab: Insert] [Esc: Dismiss]")

    M.render_inline_response(state.ai_overlay_line, response_lines)
end

---Finalizes the UI state
function M.render_ai_complete()
    state.is_thinking = false
    if state.thinking_timer then
        state.thinking_timer:stop()
        state.thinking_timer:close()
        state.thinking_timer = nil
    end
end

---Finalizes the UI state
function M.render_ai_complete()
    state.is_thinking = false
    if state.thinking_timer then
        pcall(function()
            state.thinking_timer:stop()
            state.thinking_timer:close()
        end)
        state.thinking_timer = nil
    end
end

---Commits the AI suggestion to the actual buffer text
function M.accept_suggestion()
    if not state.ai_current_content then return end

    local buf = bridge.get_current_buffer()
    local line_num = state.ai_overlay_line or bridge.get_cursor_position()[1] --- Check on the one

    local code_lines = {}
    local in_code_block = false

    -- Logic to extract content inside ``` markdown blocks
    for _, line in ipairs(bridge.split_strings(state.ai_current_content, "\n", true)) do
        if line:match("^```") then
            in_code_block = not in_code_block
        elseif in_code_block then
            table.insert(code_lines, line)
        end
    end

    if #code_lines == 0 then
        code_lines = bridge.split_strings(state.ai_current_content, "\n", true)
    end

    bridge.replace_line_range(buf, line_num, line_num, false, code_lines)
    M.clear_overlay()
end

---@note(waks-work): Is still unused.
---@param callback fun(...)
function M.get_user_input(callback)
    bridge.ui_input({
        prompt = "WaksAI > ",
        default = "",
    }, function(text)
        if text and text ~= "" then
            callback(text)
        end
    end)
end

---@note(waks-work): This keybinds may change and may need to be updated
---so as to meet our requirements and the specific keymap rules we will follow.
---will be done more on init.lua file.
function M.setup_keymaps()
    -- Accept AI suggestion
    bridge.set_keymap('n', '<Tab>', function()
        if state.ai_current_content then
            M.accept_suggestion()
        end
    end, { desc = "Accept AI suggestion" })

    -- Dismiss overlay
    bridge.set_keymap('n', '<Esc>', function()
        M.clear_overlay()
    end, { desc = "Dismiss AI overlay" })

    -- Trigger AI inline
    bridge.set_keymap('n', '<leader>ai', function()
        local line_num = bridge.get_cursor_position()[1] - 1

        M.get_user_input(function(prompt)
            -- This would call your backend
            -- For now, just show thinking
            M.render_ai_start(line_num)

            -- Example: simulate response after 1 second
            --- @note(waks-work): implement a wrapper for this.
            bridge.defer_function(function()
                M.render_ai_stream("```rust\nlet example = 42;\n```")
                M.render_ai_complete()
            end, 1000)
        end)
    end, { desc = "Ask AI (inline)" })

    -- Copy last code block helper
    bridge.set_keymap('n', 'yc', function()
        if state.ai_current_content then
            ---@note(waks-work): implement the fix.
            bridge.set_register('+', state.ai_current_content)
            bridge.notify("AI response copied", bridge.get_log_level("info"))
        end
    end, { desc = "Copy AI response" })
end

---@param opts WaksUIConfig?
function M.setup(opts)
    M.config = bridge.merge_tables(M.config, opts or {})
end

M.sidebar_buf = nil
M.sidebar_win = nil

function M.open_chat()
    if M.sidebar_win and bridge.window_is_valid(M.sidebar_win) then
        bridge.set_current_window(M.sidebar_win)
        return
    end

    if not M.sidebar_buf or not bridge.buffer_is_valid(M.sidebar_buf) then
        M.sidebar_buf = bridge.create_buffer(false, true)

        vim.bo[M.sidebar_buf].buftype = "nofile"
        vim.bo[M.sidebar_buf].filetype = "markdown"
        vim.bo[M.sidebar_buf].bufhidden = "hide"

        bridge.set_buffer_name(M.sidebar_buf, "WaksAI-Chat")
    end

    bridge.execute_command("botright vsplit")
    bridge.execute_command("vertical resize 45")

    M.sidebar_win = bridge.get_window_id()
    bridge.set_window_buffer(M.sidebar_win, M.sidebar_buf)

    vim.wo[M.sidebar_win].number = false
    vim.wo[M.sidebar_win].relativenumber = false
    vim.wo[M.sidebar_win].wrap = true
    vim.wo[M.sidebar_win].winfixwidth = true
    vim.wo[M.sidebar_win].fillchars = "eob: "
    vim.wo[M.sidebar_win].signcolumn = "no"
    vim.wo[M.sidebar_win].foldcolumn = "0"
end

-- Wrapper for rendering system messages
function M.render_system(msg, level)
    local lv = level == "error" and bridge.get_log_level("error") or bridge.get_log_level("info")
    bridge.notify("WaksAI: " .. msg, lv)
end

-- Placeholder for clearing loading (used in your prompt function)
function M.clear_loading()
    M.render_ai_complete()
end

function M.render_ai(text)
    local cursor_pos = bridge.get_cursor_position()
    local line = (cursor_pos and cursor_pos.row or 1) - 1
    M.render_ai_start(line)
    M.render_ai_stream(text)
    M.render_ai_complete()
end

function M.clear_chat()
    state.session.history = {}
    if M.sidebar_buf and bridge.buffer_is_valid(M.sidebar_buf) then
        bridge.replace_line_range(M.sidebar_buf, 0, -1, false, { "# WaksAI Chat Cleared", "" })
    end
    bridge.notify("WaksAI: Chat history cleared", bridge.get_log_level("info"))
end

-- Mapping for render_user
function M.render_user(text)
    -- Your inline UI doesn't really 'render' the user text in the buffer,
    -- so we just log it for now.
    print("User: " .. text)
end

return M
