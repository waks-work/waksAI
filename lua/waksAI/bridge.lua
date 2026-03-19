--- @mod(bridge.lua): The boundary between Neovim and waksAI logic
local M = {}

--- Decodes a json string
--- @param str string
--- @return string
function M.json_decode(str)
    local ok, val = pcall(vim.fn.json_decode, str)
    if ok then return val else return nil end
end

--- Encodes a json
---@param tbl table
---@return table
function M.json_encode(tbl)
    return vim.fn.json_encode(tbl)
end

--- Wrapper for getting the current mode
--- @return string
function M.get_current_mode()
    local mode_data = vim.api.nvim_get_mode()
    return mode_data.mode
end

--- @type { row: number, col: number }
M.cursor_position = { row = 0, col = 0 }

--- Returns the cursor position in a normalized format
--- Neovim API: (1-indexed: lines, 0-indexed: columns)
--- @return table { line:number, col: number }
function M.get_cursor_position()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    return { row = row, col = col }
end

--- Get the current buffer we are currently on.
--- @return number
function M.get_current_buffer()
    local current_buf = vim.api.nvim_get_current_buf()
    return current_buf
end

--- Fetches text from a specific range.
--- Cleaned up to handle 'nil' buffers by defaulting to current.
--- @param start_idx number (O-indexed)
--- @param end_idx number (O-indexed, -1 for end of file)
--- @param buffer number|nil Defaults to 0 (current buffer)
--- @return string[]
function M.fetch_buffer_content(start_idx, end_idx, buffer)
    buffer = buffer or 0
    return vim.api.nvim_buf_get_lines(buffer, start_idx, end_idx, false)
end

--- Returns unique ID of buffer currently in focus.
---@return number
function M.get_buffer_id()
    local buffer_id = vim.api.nvim_get_current_buf()
    return buffer_id
end

--- Returns the filetype of the current buffer
---@return string | nil
function M.get_buffer_filetype()
    local file_type = vim.bo.file_type
    return file_type
end

--- Future-proofing: A single call to get all the 'context' snapshot
--- @return { mode: string, cursor: { line: number, col: number }, buffer_id: number, file_type: string }
function M.get_context_snapshot()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    return {
        mode = M.get_current_mode(),
        cursor = { line = row, col = col },
        buffer_id = M.get_buffer_id(),
        file_type = M.get_buffer_filetype()
    }
end

--- Split a string into a list of substrings.
--- @param str string The text to split
--- @param delimiter string The character to split on (e.g., "\n")
--- @param trim boolean Whether to remove empty strings from the result
--- @return string[]
function M.split_strings(str, delimiter, trim)
    return vim.split(str, delimiter, { trimempty = trim })
end

--- A "Bridge" helper: Gets the text currently selected in Visual Mode
--- @return string[]|nil
function M.get_visual_selection()
    -- Get the [line, column] for the start and end of the visual selection
    local _, s_line, s_col, _ = unpack(vim.fn.getpos("'<"))
    local _, e_line, e_col, _ = unpack(vim.fn.getpos("'>"))
    -- Handle cases where no selection exists
    if s_line == 0 or e_line == 0 then return nil end

    -- nvim_buf_get_lines uses 0-indexing
    return vim.api.nvim_buf_get_lines(0, s_line - 1, e_line, false)
end

--- ** UI **

--- Wrapper for defining highlight groups
--- @param name string The highlight group name (e.g., "AIOverlay")
--- @param opts table Highlight attributes { fg, bg, bold, italic, underline }
function M.set_highlight(name, opts)
    -- Default to global namespace (0)
    -- Maps 'fg' and 'bg' to the API's expected keys
    vim.api.nvim_set_hl(0, name, {
        fg = opts.fg,
        bg = opts.bg,
        bold = opts.bold or false,
        italic = opts.italic or false,
        underline = opts.underline or false,
        -- Add link if you want to support: M.set_hl("MyGroup", { link = "Comment" })
        link = opts.link
    })
end

--- Creates or retrieves a namespace ID.
--- @param name_str string | nil Optional: name for a new namespace.
--- @return number
function M.get_namespace_id(name_str)
    if name_str then
        return vim.api.nvim_create_namespace(name_str)
    end
end

--- Get the line from the current buffer
--- @param line_num number | string
--- @param end_item? boolean | nil
--- @return string
function M.get_line(line_num, end_item)
    local line = vim.fn.get_line(line_num, end_item)
    return line
end

--- Line number of the cursor
--- @param expression string | number[]
--- @param winid? number
--- @return number
function M.line(expression, winid)
    local line = vim.fn.line(expression, winid)
    return line
end

--- Clear all decorations (virtual text, highlights) in this namespace.
--- @param namespace_id number
--- @param bufnr number | nil Default is 0 (current buffer).
function M.clear_overlay(bufnr, namespace_id)
    bufnr = bufnr or 0
    vim.api.nvim_buf_clear_namespace(bufnr, namespace_id, 0, -1)
end

--- Adds virtual lines ( an overlay) to a specific position.
--- @param buffer number Buffer ID (0 for current)
--- @param namespace_id number Namespace ID
--- @param line number 1-indexed line number
--- @param lines table list of strings or {text, hl} pairs
--- @return number extmark_id
function M.set_virtual_text(buffer, namespace_id, line, lines)
    local virtual_lines = {}
    local default_highlight = "AIOverlay"

    for _, text in ipairs(lines) do
        if type(text) == "string" then
            table.insert(virtual_lines, { { text, default_highlight } })
        else
            table.insert(virtual_lines, { text })
        end
    end

    return vim.api.nvim_buf_set_extmark(buffer, namespace_id, line, -1, 0, {
        virt_lines = virtual_lines,
        virt_lines_above = false,
    })
end

--- Merge two tables together (Deep Merge)
--- @param table_one table The base/default table
--- @param table_two table? The table containing overrides (can be nil)
--- @return table # The merged result
function M.merge_tables(table_one, table_two)
    local merged_table = vim.tbl_deep_extend("force", table_one, table_two or {})
    return merged_table
end

--- Merge two list-like tables/array together (Deep Merge)
--- @param list_one table The base/default table
--- @param list_two table? The table containing overrides (can be nil)
--- @return table # The merged result
function M.merge_lists(list_one, list_two)
    local merged_list = vim.list_extend("force", list_one, list_two or {})
    return merged_list
end

--- Returns the correct Neovim log level ID
--- @param level "info" | "warn" | "error" | "debug" | nil
--- @return number
function M.get_log_level(level)
    local map = {
        info  = vim.log.levels.INFO,
        warn  = vim.log.levels.WARN,
        error = vim.log.levels.ERROR,
        debug = vim.log.levels.DEBUG,
    }
    return map[level] or vim.log.levels.INFO
end

--- Send a notification to the user
--- @param msg string The text to display
--- @param level_id number? The ID from M.get_log_level (defaults to INFO)
--- @return string | string[]
function M.notify(msg, level_id)
    return vim.notify("[Waksai]: " .. msg, level_id or vim.log.levels.INFO or {})
end

--- Set line wrapping for a specific window
--- @param win_id number Window handle (0 for current)
--- @param enabled boolean True to wrap, false to disable
function M.set_wrap(win_id, enabled)
    vim.wo[win_id].wrap = enabled
end

--- Execute a callback after a delay
--- @param timeout number Delay in milliseconds
--- @param callback function The function to run
--- @return uv_timer_t timer_handle
function M.set_timeout(timeout, callback)
    local timer = vim.uv.new_timer()
    timer:start(timeout, 0, function()
        timer:stop()
        timer:close()
        vim.schedule(callback) -- Ensure it runs on the main Neovim thread
    end)
    return timer
end

--- Set a keybinding
--- @param mode string | table "n", "i", "v", etc.
--- @param lhs string The key combo
--- @param rhs string | function The command or Lua function
--- @param opts table? Optional: { desc, silent, buffer }
function M.set_keymap(mode, lhs, rhs, opts)
    local defaults = { silent = true }
    vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", defaults, opts or {}))
end

--- Get the full path of the current file
--- @return string
function M.get_current_path()
    return vim.fn.expand("%:p")
end

--- Returns the name of the current file
--- @return string
function M.get_current_file_name()
    local file_name = vim.fn.expand('%:t')
    return file_name
end

--- Create a scratch buffer with specific content and filetype
--- @param filetype string The language (e.g. "lua", "markdown")
--- @param lines table List of strings
--- @return number bufnr
function M.create_scratch_buf(filetype, lines)
    -- Create: listed = false, scratch = true
    local buf = vim.api.nvim_create_buf(false, true)

    -- Set content (0-indexed)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Set filetype for Treesitter highlighting
    vim.api.nvim_set_option_value("filetype", filetype, { buf = buf })

    return buf
end

--- Get all lines from a buffer as a table
--- @param bufnr number Buffer ID (0 for current)
--- @return table
function M.get_buf_lines(bufnr)
    return vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
end

--- Gets the syntax node under the cursor
--- @return TSNode | nil
function M.get_node_at_cursor()
    local buf = M.get_current_buffer()
    local cursor = M.get_cursor_position()
    -- Treesitter uses 0-indexed rows and columns
    local ok, parser = pcall(vim.treesitter.get_parser, buf)
    if not ok or not parser then return nil end

    local tree = parser:parse()[1]
    local root = tree:root()
    return root:named_descendant_for_range(cursor.row - 1, cursor.col, cursor.row - 1, cursor.col)
end

--- Sets the (1, 0)-indexed position in the window
--- @param window_id number
--- @param position {row: number, col: number}
function M.set_cursor_position(window_id, position)
    vim.api.nvim_win_set_cursor(window_id, position)
end

--- @note(waks-work): implement the treesitter logic here.
--- vim.api.nvim_buf_get_lines()
--- vim.api.nvim_buf_set_option(buf, "filetype", "lua")
--- vim.api.nvim_create_buf(false, true)
--- vim.api.nvim_buf_set_lines(buf, 0, -1, false, code)
--- vim.api.nvim_set_current_buf(buf)
--  vim.api.nvim_buf_set_name(buf, "WaksAI-Status")
--  vim.api.nvim_win_set_buf(0, buf)
--- vim.api.nvim_win_set_cursor(0, { 2, 2 })
--- vim.fn.executable("rg")
--- vim.v.shell_error
--- vim.fn.isdirectory(dir) && vim.fn.mkdir(dir, "p")
--- vim.schedule()

--- @note(waks-work): implement this logic for this block.
--  vim.cmd("vertical split")
--  vim.bo[buf].buftype = "nofile"

return M
