---@mod waksAI.ui Enhanced Inline UI with > Prefix Overlays
---@brief Manages virtual text overlays with markdown rendering and collapsible responses

local state = require("waksAI.state")
local bridge = require("bridge")
local M = {}

---@class WaksUIConfig
---@field overlay_prefix string The prefix for AI lines (default: " > ")
---@field show_thinking boolean Whether to show spinner
---@field max_inline_lines number Maximum lines before auto-collapse
---@field thinking_frames string[] Animation frames
---@field icons table<string, string> UI symbols
M.config = {
    overlay_prefix = " > ",
    show_thinking = true,
    max_inline_lines = 10, -- Collapse if response > 10 lines

    thinking_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
    thinking_speed = 80,

    icons = {
        user = "👤",
        ai = "🤖",
        thinking = "💭",
        collapsed = "▶",
        expanded = "▼",
    },
}

-- Internal state
M.overlay_state = {
    ns = nil,                 -- Namespace for extmarks
    current_line = nil,       -- Line number where overlay is shown
    response_text = "",       -- Accumulated AI response
    is_thinking = false,      -- Thinking animation active
    thinking_timer = nil,     -- Timer handle
    is_collapsed = false,     -- Response collapsed state
    full_response_lines = {}, -- Full response (for expanding)
}

-- ============================================================================
-- NAMESPACE & HIGHLIGHTS
-- ============================================================================

function M.setup_highlights()
    bridge.set_highlight("AIThinking", { fg = "#7f849c", italic = true })
    bridge.set_highlight("AIOverlay", { fg = "#89b4fa", italic = true })
    bridge.set_highlight("AIOverlayCode", { fg = "#cba6f7", bg = "#181825" })
    bridge.set_highlight("AIAction", { fg = "#a6e3a1", bold = true })
end

function M.get_or_create_namespace()
    if not M.overlay_state.ns then
        M.overlay_state.ns = bridge.get_namespace_id("waksai_inline_overlay")
    end
    return M.overlay_state.ns
end

-- ============================================================================
-- THINKING ANIMATION
-- ============================================================================

---Start thinking spinner at cursor line
function M.show_thinking()
    local line_num = bridge.get_cursor_position() -- O-indexed
    M.overlay_state.current_line = line_num
    M.overlay_state.is_thinking = true

    M.animate_thinking(line_num)
end

---Thinking spinner loop
---@param line_num number
function M.animate_thinking(line_num)
    --- @note(waks-work): fix this and ensure the timer works as expected.
    local frame = 1
    local timer = vim.loop.new_timer()
    M.overlay_state.thinking_timer = timer

    timer:start(0, M.config.thinking_speed, vim.schedule_wrap(function()
        if not M.overlay_state.is_thinking then
            timer:stop()
            timer:close()
            return
        end

        local spinner = M.config.thinking_frames[frame]
        local virt_lines = {
            { { M.config.overlay_prefix .. "// 🤖 Thinking... [" .. spinner .. "]", "AIThinking" } }
        }

        M.render_virtual_lines(line_num, virt_lines)
        frame = (frame % #M.config.thinking_frames) + 1
    end))
end

function M.stop_thinking()
    M.overlay_state.is_thinking = false
    if M.overlay_state.thinking_timer then
        M.overlay_state.thinking_timer:stop()
        M.overlay_state.thinking_timer:close()
        M.overlay_state.thinking_timer = nil
    end
end

-- ============================================================================
-- VIRTUAL TEXT RENDERING
-- ============================================================================

---Render virtual lines at a specific line number
---@param line_num number 0-indexed line
---@param virt_lines table[] Array of line chunks
function M.render_virtual_lines(line_num, virt_lines)
    local buf = bridge.get_current_buffer()

    local ns = M.get_or_create_namespace()

    bridge.clear_ovelay(buf, ns)
    bridge.set_virtual_text(buf, ns, line_num, virt_lines)
end

-- ============================================================================
-- MARKDOWN PARSING & RENDERING
-- ============================================================================

--- @note(waks-work): relook carefully at this logic and make sure it works.
---Parse markdown and create formatted virtual lines
---@param text string Raw AI response
---@return table[] Virtual line chunks
function M.parse_markdown_to_virt_lines(text)
    local virt_lines = {}
    local in_code_block = false
    local code_lang = ""

    -- Header line
    table.insert(virt_lines, {
        { M.config.overlay_prefix .. "// 🤖 Response", "AIOverlay" }
    })
    table.insert(virt_lines, {
        { M.config.overlay_prefix, "AIOverlay" }
    })

    for _, line in ipairs(vim.split(text, "\n")) do
        -- Code block detection
        if line:match("^```") then
            in_code_block = not in_code_block
            if in_code_block then
                code_lang = line:match("^```(%w*)")
                table.insert(virt_lines, {
                    { M.config.overlay_prefix .. "```" .. (code_lang or ""), "AIOverlayCode" }
                })
            else
                table.insert(virt_lines, {
                    { M.config.overlay_prefix .. "```", "AIOverlayCode" }
                })
            end
        elseif in_code_block then
            table.insert(virt_lines, {
                { M.config.overlay_prefix .. line, "AIOverlayCode" }
            })
        else
            -- Regular markdown (bold, bullets, etc.)
            local chunks = M.parse_markdown_inline(line)
            table.insert(virt_lines, chunks)
        end
    end

    -- Action hints
    table.insert(virt_lines, {
        { M.config.overlay_prefix, "AIOverlay" }
    })
    table.insert(virt_lines, {
        { M.config.overlay_prefix .. "[Tab: Insert] [Esc: Dismiss]", "AIAction" }
    })

    return virt_lines
end

---Parse inline markdown (bold, bullets)
---@param line string
---@return table[] Chunks with highlights
function M.parse_markdown_inline(line)
    -- Simple implementation - can be enhanced
    local chunks = {}

    -- Check for bullets
    if line:match("^%s*[•·-]") then
        table.insert(chunks, { M.config.overlay_prefix .. line, "AIOverlay" })
        -- Check for bold **text**
    elseif line:match("%*%*(.-)%*%*") then
        -- This is simplified - proper parsing would split and highlight
        table.insert(chunks, { M.config.overlay_prefix .. line, "AIOverlay" })
    else
        table.insert(chunks, { M.config.overlay_prefix .. line, "AIOverlay" })
    end

    return chunks
end

-- ============================================================================
-- STREAMING RESPONSE
-- ============================================================================

---Start streaming AI response
function M.start_streaming_response()
    local line_num = vim.api.nvim_win_get_cursor(0)[1] - 1
    M.overlay_state.current_line = line_num
    M.overlay_state.response_text = ""
    M.overlay_state.full_response_lines = {}
    M.overlay_state.is_collapsed = false

    M.show_thinking()
end

---Update response with new chunk
---@param chunk string
function M.stream_chunk(chunk)
    M.stop_thinking()
    M.overlay_state.response_text = M.overlay_state.response_text .. chunk

    -- Parse and render
    local virt_lines = M.parse_markdown_to_virt_lines(M.overlay_state.response_text)
    M.overlay_state.full_response_lines = virt_lines

    -- Auto-collapse if too long
    if #virt_lines > M.config.max_inline_lines then
        M.show_collapsed_response()
    else
        M.render_virtual_lines(M.overlay_state.current_line, virt_lines)
    end
end

---Complete streaming
function M.complete_response()
    M.stop_thinking()
    -- Final render is already done in stream_chunk
end

-- ============================================================================
-- COLLAPSIBLE RESPONSES
-- ============================================================================

---Show collapsed summary (for long responses)
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

---Expand collapsed response
function M.expand_response()
    if M.overlay_state.is_collapsed then
        M.overlay_state.is_collapsed = false
        M.render_virtual_lines(
            M.overlay_state.current_line,
            M.overlay_state.full_response_lines
        )
    end
end

---Collapse expanded response
function M.collapse_response()
    if not M.overlay_state.is_collapsed then
        M.show_collapsed_response()
    end
end

-- ============================================================================
-- ACCEPTING/DISMISSING
-- ============================================================================

---Accept AI suggestion and insert into buffer
function M.accept_suggestion()
    if not M.overlay_state.response_text then return end

    local buf = bridge.get_current_buffer()
    local line_num = bridge.get_cursor_position()

    -- Extract code from markdown
    local code_lines = M.extract_code_from_response(M.overlay_state.response_text)

    if #code_lines > 0 then
        bridge.replace_line_range(buf, line_num + 1, line_num + 1, false, code_lines)
        local level_id = bridge.get_log_level("info")
        bridge.notify("✅ AI suggestion inserted", level_id)
    end

    M.clear_overlay()
end

---Extract code blocks from markdown
---@param text string
---@return string[]
function M.extract_code_from_response(text)
    local code_lines = {}
    local in_code_block = false

    for _, line in ipairs(bridge.split_strings(text, "\n", true)) do
        if line:match("^```") then
            in_code_block = not in_code_block
        elseif in_code_block then
            table.insert(code_lines, line)
        end
    end

    -- If no code blocks found, return entire response
    if #code_lines == 0 then
        code_lines = bridge.split_strings(text, "\n", true)
    end

    return code_lines
end

---Clear overlay and reset state
function M.clear_overlay()
    local buf = bridge.get_current_buffer()
    local ns = M.get_or_create_namespace()

    bridge.clear_overlay(buf, ns)

    M.stop_thinking()
    M.overlay_state.current_line = nil
    M.overlay_state.response_text = ""
    M.overlay_state.full_response_lines = {}
    M.overlay_state.is_collapsed = false
end

-- ============================================================================
-- KEYMAPS
-- ============================================================================

function M.setup_keymaps()
    -- Accept suggestion
    bridge.set_keymap('n', 'Tab', function()
        if M.overlay_state.response_text ~= "" then
            M.accept_suggestion()
        end
    end, { desc = "WaksAI: Accept suggestion" })
    -- Dismiss overlay
    bridge.set_keymap('n', '<Esc>', function()
        M.clear_overlay()
    end, { desc = "WaksAI: Dismiss overlay" })

    -- Expand/collapse
    bridge.set_keymap('n', '<Right>', function()
        M.expand_response()
    end, { desc = "WaksAI: Expand response" })

    bridge.set_keymap('n', '<Left>', function()
        M.collapse_response()
    end, { desc = "WaksAI: Collapse response" })

    -- Copy response
    bridge.set_keymap('n', 'yc', function()
        if M.overlay_state.response_text ~= "" then
            bridge.set_register('+', M.overlay_state.response_text)
            bridge.notify("📋 AI response copied", bridge.get_log_level("info"))
        end
    end, { desc = "WaksAI: Copy AI response" })
end

-- ============================================================================
-- SETUP & COMPATIBILITY
-- ============================================================================

---Initialize UI module
---@param opts WaksUIConfig?
function M.setup(opts)
    M.config = bridge.merge_tables(M.config, opts or {})
    M.setup_highlights()
    M.setup_keymaps()
    M.get_or_create_namespace()
end

-- Compatibility aliases for existing code
function M.render_ai_start(line_num)
    M.overlay_state.current_line = line_num or
        (bridge.get_cursor_position()[1] - 1) --- @note(waks-work): relook at the -1 logic
    M.show_thinking()
end

function M.render_ai_stream(chunk)
    M.stream_chunk(chunk)
end

function M.render_ai_complete()
    M.complete_response()
end

function M.render_thinking(msg)
    M.show_thinking()
end

function M.clear_loading()
    M.stop_thinking()
end

function M.open_chat()
    bridge.notify("WaksAI: Inline Mode Active (Agent mode coming soon!)", bridge.get_log_level("info"))
end

return M
