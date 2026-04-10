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
        collapsed = "▶",
        expanded = "▼",
    },
}

--- @note(waks-work): check on the use of: bridge.set_highlight(name, opts)
--- to set a highlight group

-- INLINE OVERLAY RENDERING

--- We only need to implement this:
function M.show_collapsed_response()
    M.overlay_state.is_collapsed = true
    local summary_lines = {
        { M.config.overlay_prefix .. "// 🤖 Response [" .. #M.overlay_state.full_response_lines .. " lines]", "AIOverlay" },
        { M.config.overlay_prefix, "AIOverlay" },
        { M.config.overlay_prefix .. M.config.icons.collapsed .. " Press → to expand", "AIAction" },
        { M.config.overlay_prefix, "AIOverlay" },
        { M.config.overlay_prefix .. "[Tab: Insert] [Esc: Dismiss]", "AIAction" },
    }
    M.render_virtual_lines(M.overlay_state.current_line, summary_lines)
end

--- Expand collapsed response
function M.expand_response()
    if M.overlay_state.is_collapsed then
        M.overlay_state.is_collapsed = false
        M.render_virtual_lines(
            M.overlay_state.current_line,
            M.overlay_state.full_response_lines
        )
    end
end

--- Collapse expanded response
function M.collapse_response()
    if not M.overlay_state.is_collapsed then
        M.show_collapsed_response()
    end
end

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
    --- @class AIState
    --- @field is_thinking boolean
    --- @field ai_overlay_line integer
    --- @field ai_current_content string
    --- @field ai_namespace integer
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
    local ns = state.ai_namespace or bridge.get_namespace_id("waksai_inline")

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

--- Mapping for rendering the user inline as virtual text
---@param text string
function M.render_user_inline(text)
    local cursor_pos = bridge.get_cursor_position()
    local line_num = (cursor_pos and cursor_pos.row or 1) - 1

    local lines = {
        M.config.icons.user .. " " .. text,
        string.rep("─", 20)
    }
    M.render_inline_response(line_num, lines)
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

    -- Expand/collapse
    bridge.set_keymap('n', '<leader>we', function()
        M.expand_response()
    end, { desc = "WaksAI: Expand response" })

    bridge.set_keymap('n', '<leader>wc', function()
        M.collapse_response()
    end, { desc = "WaksAI: Collapse response" })

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

-- Wrapper for rendering system messages
function M.render_system(msg, level)
    local lv = level == "error" and bridge.get_log_level("error") or bridge.get_log_level("info")
    bridge.notify("WaksAI: " .. msg, lv)
end

-- Placeholder for clearing loading (used in your prompt function)
function M.clear_loading()
    M.render_ai_complete()
end

--- Renders AI output as an inline virtual text overlay (Ghost Text)
--- @param text string The full text or code to display
--- @param line_num integer|nil Optional 0-indexed line, defaults to cursor
function M.render_ai_inline(text, line_num)
    if not line_num then
        local cursor_pos = bridge.get_cursor_position()
        line_num = (cursor_pos and cursor_pos.row or 1) - 1
    end

    M.render_ai_start(line_num)
    M.render_ai_stream(text)
    M.render_ai_complete()
end

function M.render_ai(text, opts)
    opts = opts or {}

    if opts.inline or not (M.sidebar_win and bridge.window_is_valid(M.sidebar_win)) then
        M.render_ai_inline(text, opts.line)
    else
        M.render_ai_sidebar(text, opts)
    end
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
    M.set_sidebar_interface(M.sidebar_buf)

    vim.wo[M.sidebar_win].number = false
    vim.wo[M.sidebar_win].relativenumber = false
    vim.wo[M.sidebar_win].wrap = true
    vim.wo[M.sidebar_win].winfixwidth = true
    vim.wo[M.sidebar_win].fillchars = "eob: "
    vim.wo[M.sidebar_win].signcolumn = "no"
    vim.wo[M.sidebar_win].foldcolumn = "0"
end

function M.clear_chat()
    state.session.history = {}
    if M.sidebar_buf and bridge.buffer_is_valid(M.sidebar_buf) then
        bridge.replace_line_range(M.sidebar_buf, 0, -1, false, { "# WaksAI Chat Cleared", "" })
    end
    bridge.notify("WaksAI: Chat history cleared", bridge.get_log_level("info"))
end

--- Sets a fixed bottom area.
--- @param buffer number
function M.set_sidebar_interface(buffer)
    vim.wo[M.sidebar_win].winbar = ""
    local namespace_id = bridge.get_namespace_id("waksAi_ui")

    local width = vim.api.nvim_win_get_width(0)
    local virt_lines = {
        { string.rep("─", width), "FloatBorder" },
        { "  Ask waksAI or type '/' for commands...", "Comment" }
    }

    bridge.set_virtual_text(buffer, namespace_id, 0, 0, virt_lines)
end

--- Render ai action
--- @param text string
--- @param lang string
function M.render_ai_with_actions(text, lang)
    local start_line = bridge.get_bline_count(M.sidebar_buf)
    M.render_ai("```" .. lang .. "\n" .. text .. "\n```")
    local end_line = bridge.get_bline_count(M.sidebar_buf)

    local ns_id = bridge.get_namespace_id("waksAI_Actions")
    bridge.set_virtual_text(M.sidebar_buf, ns_id, start_line, 0, {
        virt_text = { { "  Apply Change ", "DiagnosticOk" }, { " 󰅖 Dismiss ", "DiagnosticError" } },
        virt_text_pos = "right_align",
    })

    table.insert(state.current_page_blocks, {
        start_line = start_line,
        end_line = end_line,
        content = text
    })
end

--- Animate teh thinking animation.
--- @param target_line integer
function M.animate_thinking_sidebar(target_line)
    local frame = 1
    state.thinking_timer = vim.loop.new_timer()
    state.thinking_timer:start(0, M.config.thinking_speed, vim.schedule_wrap(function()
        if not state.is_thinking or not bridge.buffer_is_valid(M.sidebar_buf) then
            M.render_ai_complete()
            return
        end

        local spinner = M.config.thinking_frames[frame]
        local display = "   " .. M.config.icons.thinking .. " Thinking... [" .. spinner .. "]"

        bridge.replace_line_range(M.sidebar_buf, target_line, target_line + 1, false, { display })
        frame = (frame % #M.config.thinking_frames) + 1
    end))
end

--- Render sidebar thinking
function M.render_thinking_sidebar()
    if not M.sidebar_buf then return end
    state.is_thinking = true
    local last_line = bridge.get_bline_count(M.sidebar_buf)
    bridge.replace_line_range(M.sidebar_buf, last_line, last_line, false,
        { "   " .. M.config.icons.thinking .. " Thinking..." })

    M.animate_thinking_sidebar(last_line)
end

--- Render ai output in sidebar
--- @param text string
--- @param opts table
function M.render_ai_sidebar(text, opts)
    if not M.sidebar_buf or not bridge.buffer_is_valid(M.sidebar_buf) then return end

    opts = opts or {}
    local all_lines = {}

    if opts.is_code then
        table.insert(all_lines, "```" .. (opts.lang or "text"))
        bridge.merge_lists(all_lines, bridge.split_strings(text, "\n", true))
        table.insert(all_lines, "```")
        table.insert(all_lines, "")
    else
        table.insert(all_lines, "## " .. M.config.icons.ai .. " waksAI")
        table.insert(all_lines, "")
        bridge.merge_tables(all_lines, bridge.split_strings(text, "\n", true))
        table.insert(all_lines, "")
    end

    local last_line = bridge.get_bline_count(M.sidebar_buf)
    bridge.replace_line_range(M.sidebar_buf, last_line, last_line, false, all_lines)

    -- Sync cursor to bottom
    if M.sidebar_win and bridge.window_is_valid(M.sidebar_win) then
        local new_count = bridge.get_bline_count(M.sidebar_buf)
        bridge.set_cursor_position(M.sidebar_win, { new_count, 0 })
    end
end

--- Mapping for render_user
--- @param text string
function M.render_user_sidebar(text)
    if not M.sidebar_buf or not bridge.buffer_is_valid(M.sidebar_buf) then
        M.open_chat()
    end

    local header = { "", "## " .. M.config.icons.user .. " User", "" }
    local lines = bridge.split_strings(text, "\n", true)
    local all_lines = bridge.merge_tables(header, lines)

    local last_line = bridge.get_bline_count(M.sidebar_buf)
    bridge.replace_line_range(M.sidebar_buf, last_line, last_line, false, all_lines)

    if M.sidebar_win and bridge.window_is_valid(M.sidebar_win) then
        local new_count = bridge.get_bline_count(M.sidebar_buf)
        bridge.set_cursor_position(M.sidebar_win, { new_count, 0 })
    end
end

M.render_thinking = M.render_thinking_sidebar
M.render_user = M.render_user_sidebar

return M
