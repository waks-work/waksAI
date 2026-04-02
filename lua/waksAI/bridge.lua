--- @mod(bridge.lua): The boundary between Neovim and waksAI logic
local M = {}

M.wo = vim.wo

--- Schedule the callback function to be invoked soon by the event loop
--- @param callback fun(...)
--- @return nil
function M.schedule_task(callback)
    local task = vim.schedule(callback)
    return task
end

--- Checks if a buffer is valid or not.
--- @param buffer number
--- @return boolean
function M.buffer_is_valid(buffer)
    local is_valid = vim.api.nvim_buf_is_valid(buffer)
    return is_valid
end

--- Spawns command as a job
--- @param command string | string[]
--- @param options? table<string, fun(...) | boolean >
--- @return number
function M.start_task(command, options)
    return vim.fn.jobstart(command, options)
end

--- Creates an new, empty and unnamed buffer.
--- @param listed boolean
--- @param scratch boolean
--- @return number
function M.create_buffer(listed, scratch)
    local buffer = vim.api.nvim_create_buf(listed, scratch)
    if buffer == nil then
        M.notify("Invalid buffer returns nil")
        return 0
    end
    return buffer
end

--- Sets the current window
--- @param window_id number
function M.set_current_window(window_id)
    vim.api.nvim_set_current_win(window_id)
end

--- Checks if the existing window is valid.
--- @param window_id number
--- @return boolean
function M.window_is_valid(window_id)
    return vim.api.nvim_win_is_valid(window_id)
end

--- Opens a new split window, or a floating window.
--- @param buffer number
--- @param enter boolean
--- @param options table
--- @return number
function M.open_window(buffer, enter, options)
    local window_id = vim.api.nvim_open_win(buffer, enter, options)
    if buffer == nil then
        M.notify("Invalid window returns nil")
        return 0
    end
    return window_id
end

--- Closes the window with the given window id.
--- @param window_id number
--- @param force boolean
--- @return number
function M.close_window(window_id, force)
    return vim.api.nvim_win_close(window_id, force)
end

--- Closes the window with the given window id.
--- @param window_id number
--- @param force boolean
--- @return number
function M.close_window(window_id, force)
    if type(window_id) ~= "number" then
        return 0 -- or print("Invalid window ID:", window_id)
    end
    return vim.api.nvim_win_close(window_id, force)
end

--- Prompts the user for input allowing for potentially asynchronous work until on_confirm
--- @param prompt_user table
--- @param on_confirm fun(input: string | string[] | number[])
function M.ui_input(prompt_user, on_confirm)
    local width            = math.floor(vim.o.columns * 0.6)
    local height           = 10

    local bufnr            = M.create_buffer(false, true)
    vim.bo[bufnr].filetype = "markdown"

    local win_opts         = {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "single",
        title = " " .. (prompt_user.prompt or "Input") .. " ",
        title_pos = "center",
    }

    local window_id        = M.open_window(bufnr, true, win_opts)
    if prompt_user.default then
        M.replace_line_range(bufnr, 0, -1, false, M.split_strings(prompt_user.default, "\n", true))
    end
    M.set_cursor_position(window_id, { 1, #M.fetch_buffer_content(0, -1, bufnr) })

    local function submit()
        local lines = M.fetch_buffer_content(0, -1, bufnr)
        local content = table.concat(lines, "\n")
        M.close_window(window_id, true)
        if on_confirm then on_confirm(content) end
    end

    M.set_keymap('i', '<C-s>', submit, { buffer = bufnr, noremap = true, silent = true })
    M.set_keymap('n', '<Esc>', function() M.close_window(window_id, true) end, { buffer = bufnr })

    M.set_window_options(window_id, 'number', false)
    M.set_window_options(window_id, 'relativenumber', false)

    M.execute_command("startinsert")
end

--- Sets window options for a given window
--- @param window_id number
--- @param option string
--- @param value any
function M.set_window_options(window_id, option, value)
    vim.api.nvim_win_set_option(window_id, option, value)
end

--- Defers calling the callback until the timeout passes in ms.
--- @param callback fun(...)
--- @param timeout number
--- @return table
function M.defer_function(callback, timeout)
    return vim.defer_fn(callback, timeout)
end

--- Set the register name to the value given
--- @param rname string
--- @param value any
--- @param options? string
--- @return any
function M.set_register(rname, value, options)
    return vim.fn.setreg(rname, value, options)
end

--- Checks if table contains a given value either directly or via predicate that is checked for each value
--- @param tbl table
--- @param value any
--- @param options? table
--- @return boolean
function M.table_contains(tbl, value, options)
    local has_value = vim.tbl_contains(tbl, value, options)
    return has_value
end

--- @note(waks-work): look at vim.list_contains also and also look at vim.loop.timer ui.lua line 70

--- Returns the standard path locations of various default files and directories
--- @param str 'cache'|'config'|'config_dirs'|'data'|'data_dirs'|'log'|'run'|'state'
--- @return string | string[]
function M.get_standard_path(str)
    return vim.fn.stdpath(str)
end

--- Decodes a json string
--- @param str string
--- @return string
function M.json_decode(str)
    local ok, val = pcall(vim.json.decode, str)
    return ok and val or nil
end

--- Encodes a json
---@param tbl {filetype?: string, line?: number } | table?
---@return table
function M.json_encode(tbl)
    return vim.fn.json_encode(tbl)
end

--- Trim whitespace from both side of the string.
--- @param ut_string string
--- @return string
function M.trim_whitespace(ut_string)
    local trimmed_string = vim.trim(ut_string)
    return trimmed_string
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
    if not M.buffer_is_valid(buffer) then
        return {}
    end
    return vim.api.nvim_buf_get_lines(buffer, start_idx, end_idx, false)
end

--- Returns unique ID of buffer currently in focus.
---@return number
function M.get_buffer_id()
    local buffer_id = vim.api.nvim_get_current_buf()
    return buffer_id
end

--- Gets the current window id
--- @return number
function M.get_window_id()
    local window_id = vim.api.nvim_get_current_win()
    return window_id
end

--- Sets the full filename of a buffer
--- @param buffer number
--- @param name string
--- @return nil
function M.set_buffer_name(buffer, name)
    return vim.api.nvim_buf_set_name(buffer, name)
end

--- Generates a temporary(non-existent) flilename located at tempdir.
--- @return string
function M.generate_temp_filename()
    local tfile_name = vim.fn.tempname()
    return tfile_name
end

--- Replaces a line range in a buffer
--- @param buffer number
--- @param start_idx number
--- @param end_idx number
--- @param strict_idx boolean
--- @param replacement string[] | number[]
--- @return nil
function M.replace_line_range(buffer, start_idx, end_idx, strict_idx, replacement)
    local new_lines = vim.api.nvim_buf_set_lines(buffer, start_idx, end_idx, strict_idx, replacement)
    return new_lines
end

--- Adds highlighting to a specific buffer
--- @param buffer number
--- @param namespace_id number
--- @param highlight_group string
--- @param line_no number
--- @param start_col number
--- @param end_col number
--- @return nil
function M.add_buffer_highlight(buffer, namespace_id, highlight_group, line_no, start_col, end_col)
    vim.api.nvim_buf_add_highlight(buffer, namespace_id, highlight_group, line_no, start_col, end_col)
end

--- Returns the filetype of the current buffer
---@return string | nil
function M.get_buffer_filetype()
    local file_type = vim.bo.filetype
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
    -- Ensure marks are updated
    local mode = vim.api.nvim_get_mode().mode
    if mode == "v" or mode == "V" or mode == "\22" then
        -- Force exit to visual mode to update marks
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", true)
    end

    local s_line = vim.fn.line("'<")
    local e_line = vim.fn.line("'>")
    if s_line == 0 then return nil end

    return vim.api.nvim_buf_get_lines(0, s_line - 1, e_line, false)
end

--- Executes VimScript commands
--- @param command table | string
function M.execute_command(command)
    local cmd = vim.cmd(command)
    return cmd
end

--- Fetches the number of lines in a given buffer.
--- @param buffer number
--- @return number
function M.get_bline_count(buffer)
    local line_count = vim.api.nvim_buf_line_count(buffer)
    return line_count
end

--- Expand wildcards and some keywords
--- @param pstring string
--- @return string
function M.get_file_path(pstring)
    return vim.fn.expand(pstring)
end

--- Check if directory exists
--- @param directory string
--- @return boolean
function M.is_directory(directory)
    return vim.fn.isdirectory(directory)
end

--- Creates a directory with the name given.
--- @param directory string
--- @param flags string?
--- @param prot string?
--- @return number
function M.make_directory(directory, flags, prot)
    return vim.fn.mkdir(directory, flags or "", prot)
end

--- Creates a global user command that the user can use.
--- @param cmd_name string Must begin with an uppercase
--- @param command table | string | boolean | fun(...) Can be a function, single table
--- @param options? {desc: string, force?: boolean, preview?: fun(...) }
--- @return nil | string
function M.create_user_command(cmd_name, command, options)
    local user_command = vim.api.nvim_create_user_command(cmd_name, command, options)
    return user_command
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
    local line = vim.fn.getline(line_num, end_item)
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
--- @param column? number
--- @param lines table list of strings or {text, hl} pairs
--- @return number extmark_id
function M.set_virtual_text(buffer, namespace_id, line, column, lines)
    local virtual_lines = {}
    local default_highlight = "AIOverlay"
    local column = column or -1

    for _, text in ipairs(lines) do
        if type(text) == "string" then
            table.insert(virtual_lines, { { text, default_highlight } })
        else
            table.insert(virtual_lines, { text })
        end
    end

    return vim.api.nvim_buf_set_extmark(buffer, namespace_id, line, column, {
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

--- @note(waks-work): implement two separate wrappers for this two in line 291 in picker.lua:
--- vim.bo[buf].buftype = "nofile"; vim.bo[buf].modifiable = false

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

--- Gets the full name of the  buffer opened
--- @param bufnr number | string
--- @return string
function M.get_filename(bufnr)
    local file_name = vim.api.nvim_buf_get_name(bufnr or 0)
    return file_name
end

--- Check the buffer to see if it is valid.
--- @param buffer_id number
--- @return boolean
function M.is_file_valid(buffer_id)
    local is_valid = vim.api.nvim_buf_is_valid(buffer_id)
    return is_valid
end

--- Prompts the user to pick from a list of items.
--- @param items table | string[]
--- @param options table | string[]
--- @param on_choice fun(choice: string?, index: number?)
--- @return nil | string
function M.ui_selection(items, options, on_choice)
    local ui_selection = vim.ui.select(items, options, on_choice)
    return ui_selection
end

--- Modify filename depending on the mods provided
--- @param filename string
--- @param mods string
--- @return string
function M.modify_filename(filename, mods)
    local new_filename = vim.fn.fnamemodify(filename, mods)
    return new_filename
end

--- Set the current buffer in a window with no side effects.
--- @param window number
--- @param buffer number
--- @return number
function M.set_window_buffer(window, buffer)
    local new_window = vim.api.nvim_win_set_buf(window, buffer)
    return new_window
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
