---@mod waksAI.context Context Gathering Engine
---@brief This module gathers code context from the current buffer
---and project to provide LLM with relevant information.
local M = {}

---@class WaksContextMeta
---@field file string Absolute path to the file
---@field line number 1-indexed cursor row
---@field col number 1-indexed cursor column

---Return basic file and  cursor info
---@return WaksContextMeta
function M.get_current_context()
    local file = vim.fn.expand("%:p")
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    return {
        file = file,
        line = row,
        col = col,
    }
end

---Retrieves the text currently selected in visual mode
---Handles character-wise (v), line-wise (V) and block-wise (C-v)
---@return string | nil # The selected text with '\n' or nil if not selected.
function M.get_selected_code()
    local check_mode = vim.fn.mode()
    local is_visual = check_mode:match("[vV\22]")
    if not is_visual then return nil end

    -- Note: We use 'region' logic for modern Neovim stability. So that the marks
    -- are not updated after leaving visual mode like in  '< and >' or by calling gv
    local s = vim.fn.getpos("v")
    local e = vim.fn.getpos(".")

    ---@note(waks-work): Math Explanation
    --- Neovim row positions are 1-indexed. nvim_buf_get_lines is 0-indexed.
    --- sr-1: Converts the starting line to 0-index.
    --- er: The end line is exclusive in nvim_buf_get_lines, so 'er' effectively
    --- includes the line e[2].
    local sr, sc = s[2], s[3]
    local er, ec = e[2], e[3]

    -- Flip coordinates if the user selected in reverse (bottom to top)
    if sr > er then
        sr, er = er, sr
        sc, ec = ec, sc
    elseif sr == er and sc > ec then
        sc, ec = ec, sc
    end

    local lines = vim.api.nvim_buf_get_lines(0, sr - 1, er, false)
    if #lines == 0 then return nil end

    -- Handle column slicing (Byte-indexed)
    -- If line-wise (V), we don't need to slice columns.
    if check_mode ~= "V" then
        -- Handle the end first to not mess up start indices
        lines[#lines] = string.sub(lines[#lines], 1, ec)
        lines[1] = string.sub(lines[1], sc)
    end

    return table.concat(lines, "\n")
end

---@note(waks-test): Self-contained test for visual selection math.
---This creates a hidden buffer simulates selection, verifies output
function M._test_code_selection_visual_mode()
    local created_buf = vim.api.nvim_create_buf(false, true)
    local test_lines = { "local x = 10", "local y = 20", "print(x + y)" }
    vim.api.nvim_buf_set_lines(created_buf, 0, -1, false, test_lines)

    -- Switch to this buffer for the test
    local original_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_buf(created_buf)

    -- Simulate "v" mode selection: "x = 10" (Line 1, Col 7 to 12)
    -- Positions in marks are {bufnr, row, col, off}
    vim.api.nvim_buf_set_mark(created_buf, "<", 1, 6, {}) -- 'x'
    vim.api.nvim_buf_set_mark(created_buf, ">", 1, 11, {}) -- '0'

    -- We have to mock the mode because we aren't physically pressing keys
    local original_mode_func = vim.fn.mode
    vim.fn.mode = function() return "v" end

    -- Execution_3
    local result = M.get_selected_code()

    -- Assertion & Validation
    local expected = "x = 10"
    if result == expected then
        print("✅ Test Visual Selection (Char): PASSED")
    else
        print("❌ Test Visual Selection (Char): FAILED")
        print("   Expected: '" .. expected .. "'")
        print("   Got:      '" .. (result or "nil") .. "'")
    end

    -- 5. Cleanup
    vim.fn.mode = original_mode_func -- Restore original mode function
    vim.api.nvim_set_current_buf(original_buf)
    vim.api.nvim_buf_delete(created_buf, { force = true })
end

---Heuristic: return the surrounding function/block for the cursor.
---Tries treesitter -> falls back to simple regex scanning(legacy/unsupported).
---@return string | nil # The function selected or if nil if not selected.
function M.get_surrounding_function()
    ---@note(waks-work): Attempt native Tree-sitter first
    local has_ts, _ = pcall(require, "vim.treesitter")
    if has_ts then
        -- Get node at cursor natively (Neovim 0.9+)
        local node = vim.treesitter.get_node()
        while node do
            local type = node:type()
            if type:match("function") or type:match("method")
                or type:match("procedure") or type == "function_item"
            then
                local sr, sc, er, ec = node:range()
                local lines = vim.api.nvim_buf_get_lines(0, sr, er + 1, false)
                return table.concat(lines, "\n")
            end
            node = node:parent()
        end
    end

    ---@note(waks-work): Fallback Regex Logic
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local buflines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    -- Optimization: Less than 100 lines up to prevent lag
    local scan_limit = math.max(1, row - 100)
    local start_line = 1

    for i = row, scan_limit, -1 do
        local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1] or ""
        -- Improved regex to catch Rust 'fn', Python 'def', JS 'function'/'=>', Lua 'function'
        if line:match("^%s*function%s+") or line:match("^%s*def%s+")
            or line:match("^%s*fn%s+") or line:match("^%s*pub%s+fn")
            or line:match("=>%s*{")
        then
            start_line = i
            break
        end
    end

    -- Scan downward for logical end
    local total_lines = vim.api.nvim_buf_line_count(0)
    local end_line = math.min(total_lines, row + 50)
    for i = row, total_lines do
        local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1] or ""
        if line:match("^%s*end%s*$") or line:match("^}") then
            end_line = i
            break
        end
    end

    --- @fix: bridge.fetch_buffer_contents(start_idx, end_idx, buffer)
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    return #lines > 0 and table.concat(lines, "\n") or nil
end

---@note(waks-test): Verify the regex fallback for function detection
function M._test_surrounding_function_regex()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, "filetype", "lua")

    local code = {
        "local function test_me()",
        "  print('hello')",
        "end",
        "",
        "test_me()"
    }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, code)

    -- Place cursor inside the function (Line 2)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { 2, 2 })

    local result = M.get_surrounding_function()

    -- Validate
    if result and result:match("function test_me") and result:match("end") then
        print("✅ Test Surrounding Function: PASSED")
    else
        print("❌ Test Surrounding Function: FAILED")
    end

    vim.api.nvim_buf_delete(buf, { force = true })
end

---Search for relevant snippets using ripgrep
---@param query string Search term
---@param max_results number? Default is 5
---@return table[] # List of paths {path, line, except}
function M.get_project_snippets(query, max_results)
    max_results = max_results or 5
    local snippets = {}
    if vim.fn.executable("rg") == 0 then return snippets end

    -- Use vim.fn.systemlist which has a much safer execution
    -- -S (smart case), -n (line number), -m (max matches per file)
    local cmd = {
        "rg", "--no-heading", "--line-number", "-S",
        "-g", "!.git", "-g", "!node_modules",
        "-m", tostring(max_results), "--", query, "."
    }

    local output = vim.fn.systemlist(cmd)
    if vim.v.shell_error ~= 0 and #output == 0 then return snippets end

    for _, line in ipairs(output) do
        -- Pattern matches: file:line:content
        local path, line_no, content = line:match("([^:]+):(%d+):(.*)")
        if path and line_no and content then
            table.insert(snippets, {
                path = path,
                line = tonumber(line_no),
                excerpt = vim.trim(content)
            })
        end
        if #snippets >= max_results then break end
    end
    return snippets
end

---Build a context for the LLM request.
---@param user_prompt string The user's prompt to extract keywords.
---@return table # The context object with meta, kind and snippet.
function M.build_request_context(user_prompt)
    local ctx = {
        meta = M.get_current_context(),
        project = {}
    }
    local sel = M.get_selected_code()

    if sel and sel:match("%S") then
        ctx.kind = "selection"
        ctx.snippet = sel
    else
        local fn_code = M.get_surrounding_function()
        if fn_code and #fn_code > 50 then
            ctx.kind = "function"
            ctx.snippet = fn_code
        else
            -- Fallback: 20-line window around cursor
            local row = ctx.meta.line
            local start = math.max(0, row - 10)
            local finish = math.min(vim.api.nvim_buf_line_count(0), row + 10)
            local lines = vim.api.nvim_buf_get_lines(0, start, finish, false)
            ctx.kind = "window"
            ctx.snippet = table.concat(lines, "\n")
        end
    end

    -- Always try to find 2-3 relevant project snippets to provide "Global Awareness"
    -- Only if the prompt is long enough to have useful keywords
    if #user_prompt > 3 then
        local keyword = user_prompt:match("[%w_]{3,}") -- find first 3+ char word
        if keyword then
            ctx.project = M.get_project_snippets(keyword, 3)
        end
    end

    return ctx
end

---@note(waks-test): Verify that Ripgrep can find this file itself
function M._test_project_search()
    -- Search for a unique string in this file
    local query = "get_project_snippets"
    local results = M.get_project_snippets(query, 1)

    if #results > 0 then
        print("✅ Test Project Search: PASSED (Found '" .. query .. "' in " .. results[1].path .. ")")
    else
        -- If this fails, ensure you are in the project root and 'rg' is installed
        print("❌ Test Project Search: FAILED (Check if 'rg' is in PATH)")
    end
end

return M
