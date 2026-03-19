---@mod waksAI.utils Enhanced utilities for
---@brief Handles and acts as a utility module for mostly used methods.
local state = require("waksAI.state")
local bridge = require("waksAI.bridge")
local M = {}

---Wraps text to a specified width, preserving existing newlines.
---@param text string The raw content to wrap.
---@param width number The maximum character width per line.
---@return string[] # A table of lines formatted for nvim_buf_set_lines.
function M.wrap(text, width)
    width = width or 80
    local lines = bridge.split_strings(text, "\n", false)
    local out = {}

    for _, raw_line in ipairs(lines) do
        if #raw_line <= width then
            table.insert(out, raw_line)
        else
            local current_line = ""
            for word in raw_line:gmatch("%S+") do
                if #current_line + #word + 1 > width then
                    table.insert(out, current_line .. "  ") -- Markdown soft break
                    current_line = word
                else
                    current_line = (current_line == "") and word or (current_line .. " " .. word)
                end
            end
            if #current_line > 0 then table.insert(out, current_line) end
        end
    end

    ---@note(waks-explanation):
    --- This function performs "Greedy Word Wrapping."
    --- 1. It respects original intent by splitting the text into paragraphs via existing '\n'.
    --- 2. It iterates through each word, checking if adding it exceeds the 'width' suitcase.
    --- 3. If a word doesn't fit, it "closes" the current line and starts a new one.
    --- 4. It appends two spaces ("  ") at the end of forced breaks to respect Markdown
    ---    soft-wrap standards, ensuring the UI renders it as a continuous block.

    return out
end

--- AI OUTPUT

---Escapes strings for safe JSON transmission via Curl.
---@param str string The raw string.
---@return string
function M.escape_json(str)
    if not str then return "" end
    return str
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
end

---Compresses long comments to keep the UI clean.
---@param code string The code block from AI.
---@return string
function M.trim_comments(code)
    if not code then return "" end
    -- Trim single-line // comments (C-style, JS, Rust)
    code = code:gsub("//[^\n]+", function(c)
        return (#c > 40) and "// …" or c
    end)
    -- Trim multi-line /* */ comments
    code = code:gsub("/%*.-%*/", "/* … */")
    -- Trim shell-style # comments (Python, Bash, Lua -- is handled differently)
    code = code:gsub("#[^\n]+", function(c)
        return (#c > 40) and "# …" or c
    end)
    return code
end

---Parses Markdown code blocks into a structured table.
---@param s string The full AI response.
---@return table # Returns { {lang = "rust", code = "..."}, ... }
function M.extract_code_blocks(s)
    local blocks = {}
    -- Pattern: Look for ``` followed by language (optional) and content until closing ```
    for lang, body in s:gmatch("```(%w*)\n?(.-)```") do
        table.insert(blocks, {
            lang = (lang == "" and "text" or lang),
            --- @fix: in need of fix and find the right wrapper for replacement of vim.trim(code)
            code = vim.trim(body)
        })
    end
    return blocks
end

---@note(waks-explanation):
--- This is the engine for 'edit.lua'. It extracts the code within Markdown fences.
--- We use the non-greedy '.-' pattern to ensure that if the AI sends multiple blocks,
--- we capture each one separately rather than one giant block from the first to last tick.

---Gets the text selected out in visual mode.
---@return nil | string[]
function M.get_visual_selection()
    local mode = bridge.get_current_mode()
    if mode ~= "v" and mode ~= "V" then
        return nil
    end

    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local start_line, start_col = start_pos[2], start_pos[3]
    local end_line, end_col = end_pos[2], end_pos[3]

    -- Adjust for 1-based vs 0-based indexing
    start_col = start_col - 1
    end_col = end_col

    local buffer = bridge.get_current_buffer()
    local lines = bridge.fetch_buffer_content(start_line, end_line, buffer)

    if #lines == 0 then
        return ""
    end

    -- Handle single line selection
    if #lines == 1 then
        return string.sub(lines[1], start_col + 1, end_col)
    end

    -- Handle multi-line selection
    local result = {}
    for i, line in ipairs(lines) do
        if i == 1 then
            table.insert(result, string.sub(line, start_col + 1))
        elseif i == #lines then
            table.insert(result, string.sub(line, 1, end_col))
        else
            table.insert(result, line)
        end
    end

    return table.concat(result, "\n")
end

---Handles formating of models in provider ie icons,...
---@param provider string Name of the provider
---@return string
function M.format_provider(provider)
    local icons = {
        ollama = "🐋",
        openai = "⚡",
        anthropic = "🤖"
    }
    return string.format("%s %s", icons[provider] or "🔌", provider)
end

---Formats the model.
---@param model string
---@param provider string
---@return string
function M.format_model(model, provider)
    local provider_icon = M.format_provider(provider)
    return string.format("%s %s", provider_icon, model)
end

---Creates a status line component.
---@return string
function M.get_status_line()
    if not state or not state.session then
        return "WaksAI: Inactive"
    end

    local provider = state.session.provider or "?"
    local model = state.session.model or "?"
    local provider_icons = {
        ollama = "🐋",
        openai = "⚡",
        anthropic = "🤖"
    }

    local icon = provider_icons[provider] or "🧠"
    return string.format("%s %s/%s", icon, provider, model)
end

---Checks if the model name is valid.
---@param name string
---@return boolean
function M.is_valid_model_name(name)
    return name and name:match("^[%w%-_%.]+$") ~= nil
end

---Checks if the model name is valid.
---@param name string
---@return boolean
function M.is_valid_provider_name(name)
    return name and name:match("^[%w%-_]+$") ~= nil
end

---Checks if the model exists.
---@param provider string
---@param model string
---@return boolean
function M.model_exists(provider, model)
    if not state.config.providers[provider] then
        return false
    end

    for _, m in ipairs(state.config.providers[provider]) do
        if m == model then
            return true
        end
    end

    return false
end

--- STATISTICS UTILITIES

---A rough estimation of tokens
---@param text string
---@return integer
function M.estimate_tokens(text)
    if not text then return 0 end
    -- Rough estimation: ~4 characters per token
    return math.ceil(#text / 4)
end

---Stats for the session.
---@return table
function M.get_session_stats()
    if not state or not state.session then
        return { messages = 0, tokens = 0 }
    end

    local history = state.session.history or {}
    local total_tokens = 0

    for _, msg in ipairs(history) do
        total_tokens = total_tokens + M.estimate_tokens(msg.content)
    end

    return {
        messages = #history,
        tokens = total_tokens
    }
end

return M
