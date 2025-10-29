## Neovim API Functions with Parameters

### 1. **Window Management**
- `vim.api.nvim_open_win(buffer, enter, config)`
  - `buffer`: buffer handle
  - `enter`: boolean, enter window
  - `config`: table {relative, width, height, row, col, style, border, title, ...}

- `vim.api.nvim_win_close(winid, force)`
  - `winid`: window ID
  - `force`: boolean, force close

- `vim.api.nvim_win_is_valid(winid)`
  - `winid`: window ID to check

- `vim.api.nvim_win_get_config(winid)`
  - `winid`: window ID

- `vim.api.nvim_win_set_config(winid, config)`
  - `winid`: window ID
  - `config`: window configuration table

### 2. **Buffer Management**
- `vim.api.nvim_create_buf(listed, scratch)`
  - `listed`: boolean, show in buffer list
  - `scratch`: boolean, temporary buffer

- `vim.api.nvim_buf_set_lines(buffer, start, end, strict_indexing, lines)`
  - `buffer`: buffer handle
  - `start`: start line (0-indexed)
  - `end`: end line (-1 for end)
  - `strict_indexing`: boolean
  - `lines`: table of strings

- `vim.api.nvim_buf_get_lines(buffer, start, end, strict_indexing)`
  - `buffer`: buffer handle
  - `start`: start line
  - `end`: end line
  - `strict_indexing`: boolean

- `vim.api.nvim_buf_set_option(buffer, name, value)`
  - `buffer`: buffer handle
  - `name`: option name string
  - `value`: option value

- `vim.api.nvim_buf_add_highlight(buffer, ns_id, hl_group, line, col_start, col_end)`
  - `buffer`: buffer handle
  - `ns_id`: namespace ID
  - `hl_group`: highlight group name
  - `line`: line number
  - `col_start`: start column
  - `col_end`: end column

- `vim.api.nvim_buf_set_keymap(buffer, mode, lhs, rhs, opts)`
  - `buffer`: buffer handle
  - `mode`: string 'n', 'i', 'v', etc.
  - `lhs`: left-hand side (key sequence)
  - `rhs`: right-hand side (action)
  - `opts`: table {noremap, silent, expr, nowait}

### 3. **User Input & UI**
- `vim.ui.input(opts, on_input)`
  - `opts`: table {prompt, default, completion}
  - `on_input`: function(value)

- `vim.ui.select(items, opts, on_choice)`
  - `items`: table of items
  - `opts`: table {prompt, format_item, kind}
  - `on_choice`: function(selected, index)

- `vim.notify(msg, level, opts)`
  - `msg`: string message
  - `level`: vim.log.levels.INFO/ERROR/WARN/etc.
  - `opts`: table {title, icon, timeout}

- `vim.fn.input(prompt, default, completion)`
  - `prompt`: string prompt
  - `default`: string default value
  - `completion`: completion type

- `vim.fn.confirm(msg, choices, default, type)`
  - `msg`: string message
  - `choices`: string like "&Yes\n&No\n&Cancel"
  - `default`: default choice number
  - `type`: dialog type

### 4. **Key Mapping**
- `vim.keymap.set(mode, lhs, rhs, opts)`
  - `mode`: string or table of modes
  - `lhs`: key sequence
  - `rhs`: action (string or function)
  - `opts`: table {buffer, silent, expr, desc, ...}

- `vim.api.nvim_set_keymap(mode, lhs, rhs, opts)`
  - `mode`: string mode
  - `lhs`: key sequence
  - `rhs`: action string
  - `opts`: table {noremap, silent, expr, nowait}

- `vim.api.nvim_del_keymap(mode, lhs)`
  - `mode`: string mode
  - `lhs`: key sequence

### 5. **Async & External Commands**
- `vim.fn.jobstart(cmd, opts)`
  - `cmd`: table of command and args
  - `opts`: table {on_stdout, on_stderr, on_exit, cwd, ...}

- `vim.fn.system(cmd, input)`
  - `cmd`: string command
  - `input`: string input to command

### 6. **Buffer/File Info**
- `vim.fn.expand(what)`
  - `what`: string like '%', '%:p', '<cword>'

- `vim.fn.getcwd()`
- `vim.api.nvim_get_current_buf()`
- `vim.api.nvim_buf_get_name(buffer)`
  - `buffer`: buffer handle

- `vim.fn.fnamemodify(filename, modifier)`
  - `filename`: string path
  - `modifier`: string like ':p', ':h', ':t'

### 7. **Autocommands & Events**
- `vim.api.nvim_create_autocmd(event, opts)`
  - `event`: string or table of events
  - `opts`: table {pattern, callback, command, group, desc, once, nested}

- `vim.api.nvim_create_augroup(name, opts)`
  - `name`: string group name
  - `opts`: table {clear}

- `vim.api.nvim_del_autocmd(id)`
  - `id`: autocmd ID

### 8. **Commands**
- `vim.api.nvim_create_user_command(name, command, opts)`
  - `name`: string command name
  - `command`: function or string command
  - `opts`: table {desc, nargs, complete, range, ...}

- `vim.api.nvim_del_user_command(name)`
  - `name`: string command name

### 9. **UI Enhancements**
- `vim.api.nvim_set_hl(ns_id, name, val)`
  - `ns_id`: namespace ID (0 for global)
  - `name`: string highlight group name
  - `val`: table {fg, bg, bold, italic, ...}

- `vim.fn.hlexists(name)`
  - `name`: string highlight group name

- `vim.api.nvim_echo(chunks, history, opts)`
  - `chunks`: table of {text, hl_group}
  - `history`: boolean
  - `opts`: table

### 10. **Utility Functions**
- `vim.fn.json_encode(value)`
  - `value`: Lua value to encode

- `vim.fn.json_decode(string)`
  - `string`: JSON string to decode

- `vim.fn.split(string, pattern, keepempty)`
  - `string`: string to split
  - `pattern`: separator pattern
  - `keepempty`: boolean

- `vim.tbl_extend(behavior, ...tables)`
  - `behavior`: "force", "keep", or "error"
  - `...tables`: tables to merge

- `vim.fn.has(feature)`
  - `feature`: string feature name


I'll create a comprehensive Neovim API cheat sheet with code examples for each function.

## Neovim API Cheat Sheet

**File: `neovim_api_cheatsheet.lua`**

```lua
-- Neovim API Cheat Sheet for Vibe Tool Development
-- Complete function reference with practical examples

local M = {}

-- 1. WINDOW MANAGEMENT
M.window_examples = {
    nvim_open_win = function()
        -- Create a floating window
        local buf = vim.api.nvim_create_buf(false, true)
        local win = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = 60,
            height = 10,
            col = 10,
            row = 5,
            style = "minimal",
            border = "rounded",
            title = "Vibe Suggestion",
            title_pos = "center"
        })
        return win
    end,

    nvim_win_close = function(winid)
        -- Close a window
        vim.api.nvim_win_close(winid, false) -- false = don't force close
    end,

    nvim_win_is_valid = function(winid)
        -- Check if window still exists
        return vim.api.nvim_win_is_valid(winid)
    end
}

-- 2. BUFFER MANAGEMENT
M.buffer_examples = {
    nvim_create_buf = function()
        -- Create a temporary buffer (not listed, scratch)
        return vim.api.nvim_create_buf(false, true)
    end,

    nvim_buf_set_lines = function(buf)
        -- Set buffer content
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "🎯 Vibe AI Suggestion",
            "",
            "This is a sample suggestion",
            "Press <ESC> to close"
        })
    end,

    nvim_buf_get_lines = function(buf)
        -- Get all lines from buffer
        return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    end,

    nvim_buf_set_option = function(buf)
        -- Make buffer read-only
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        vim.api.nvim_buf_set_option(buf, 'readonly', true)
    end,

    nvim_buf_add_highlight = function(buf)
        -- Add syntax highlighting
        vim.api.nvim_buf_add_highlight(buf, -1, "Title", 0, 0, -1) -- Line 0
        vim.api.nvim_buf_add_highlight(buf, -1, "Comment", 1, 0, -1) -- Line 1
    end,

    nvim_buf_set_keymap = function(buf)
        -- Set buffer-local keymap
        vim.api.nvim_buf_set_keymap(buf, 'n', '<ESC>', 
            '<cmd>q<CR>', {noremap = true, silent = true})
    end
}

-- 3. USER INPUT & UI
M.ui_examples = {
    ui_input = function()
        -- Get text input from user
        vim.ui.input({
            prompt = "Vibe: ",
            default = "Improve this code"
        }, function(input)
            if input then
                print("User entered: " .. input)
            end
        end)
    end,

    ui_select = function()
        -- Show selection menu
        local items = {"Refactor", "Document", "Optimize", "Debug"}
        vim.ui.select(items, {
            prompt = "Choose action:",
            format_item = function(item)
                return "🔧 " .. item
            end
        }, function(choice, idx)
            if choice then
                print("Selected: " .. choice .. " (index: " .. idx .. ")")
            end
        end)
    end,

    notify = function()
        -- Show notification
        vim.notify("Vibe: Suggestion applied!", vim.log.levels.INFO, {
            title = "Vibe AI",
            icon = "🎯",
            timeout = 2000
        })
    end,

    fn_input = function()
        -- Legacy input (blocking)
        local result = vim.fn.input("Enter context: ", "default text")
        print("Got: " .. result)
    end,

    fn_confirm = function()
        -- Yes/No dialog
        local choice = vim.fn.confirm("Apply this suggestion?", "&Yes\n&No\n&Cancel", 1)
        print("User choice: " .. choice)
    end
}

-- 4. KEY MAPPING
M.keymap_examples = {
    keymap_set = function()
        -- Modern keymap (recommended)
        vim.keymap.set('n', '<leader>vs', function()
            print("Vibe suggest triggered!")
        end, { desc = "Vibe suggest" })
    end,

    nvim_set_keymap = function()
        -- Legacy keymap
        vim.api.nvim_set_keymap('n', '<leader>vv', 
            ':lua print("Quick actions")<CR>', 
            {noremap = true, silent = true})
    end,

    nvim_del_keymap = function()
        -- Remove keymap
        vim.api.nvim_del_keymap('n', '<leader>vv')
    end
}

-- 5. ASYNC & EXTERNAL COMMANDS
M.async_examples = {
    jobstart = function()
        -- Run external command async
        vim.fn.jobstart({'curl', 'http://localhost:11500/health'}, {
            on_stdout = function(_, data)
                if data then
                    print("Backend response: " .. table.concat(data))
                end
            end,
            on_stderr = function(_, error)
                print("Error: " .. table.concat(error))
            end
        })
    end,

    system = function()
        -- Run command and get output (blocking)
        local result = vim.fn.system({'echo', 'hello vibe'})
        print("System result: " .. result)
    end
}

-- 6. BUFFER/FILE INFO
M.file_examples = {
    expand = function()
        -- Expand file paths
        local current_file = vim.fn.expand('%:p') -- Full path
        local file_name = vim.fn.expand('%:t')    -- Just filename
        local word = vim.fn.expand('<cword>')     -- Current word
        
        print("File: " .. current_file)
        print("Name: " .. file_name)
        print("Word: " .. word)
    end,

    getcwd = function()
        -- Get current directory
        return vim.fn.getcwd()
    end,

    nvim_get_current_buf = function()
        -- Get current buffer handle
        return vim.api.nvim_get_current_buf()
    end,

    nvim_buf_get_name = function(buf)
        -- Get buffer file path
        return vim.api.nvim_buf_get_name(buf)
    end,

    fnamemodify = function()
        -- File path manipulation
        local full_path = "/home/user/project/src/main.rs"
        local dir = vim.fn.fnamemodify(full_path, ':h') -- /home/user/project/src
        local name = vim.fn.fnamemodify(full_path, ':t') -- main.rs
        local ext = vim.fn.fnamemodify(full_path, ':e') -- rs
    end
}

-- 7. AUTOCOMMANDS & EVENTS
M.autocmd_examples = {
    nvim_create_autocmd = function()
        -- Create autocommand group
        local vibe_group = vim.api.nvim_create_augroup('VibeGroup', {clear = true})
        
        -- Track file changes
        vim.api.nvim_create_autocmd({'BufWritePost'}, {
            group = vibe_group,
            pattern = '*.rs,*.lua,*.py',
            desc = 'Track file changes for Vibe',
            callback = function(args)
                print("File saved: " .. args.file)
            end
        })
        
        -- Auto-start session
        vim.api.nvim_create_autocmd({'VimEnter'}, {
            group = vibe_group,
            once = true,
            callback = function()
                print("Vibe: Ready for AI coding!")
            end
        })
    end,

    nvim_del_autocmd = function(id)
        -- Remove specific autocommand
        vim.api.nvim_del_autocmd(id)
    end
}

-- 8. COMMANDS
M.command_examples = {
    nvim_create_user_command = function()
        -- Create user commands
        vim.api.nvim_create_user_command('VibeStart', function()
            print("Starting Vibe session...")
        end, {
            desc = 'Start Vibe coding session'
        })
        
        vim.api.nvim_create_user_command('VibeSuggest', function(opts)
            local context = opts.args
            print("Getting suggestion for: " .. (context or "current code"))
        end, {
            desc = 'Get AI suggestion',
            nargs = '?'  -- Optional argument
        })
    end,

    nvim_del_user_command = function(name)
        -- Remove user command
        vim.api.nvim_del_user_command(name)
    end
}

-- 9. UI ENHANCEMENTS
M.ui_enhancement_examples = {
    nvim_set_hl = function()
        -- Define custom highlight groups
        vim.api.nvim_set_hl(0, 'VibeSuggestion', {
            fg = '#00ff00',
            bg = '#1a1a1a',
            bold = true
        })
        
        vim.api.nvim_set_hl(0, 'VibeDiffAdd', {
            fg = '#00ff00',
            bg = '#002200'
        })
    end,

    hlexists = function()
        -- Check if highlight exists
        if vim.fn.hlexists('VibeSuggestion') == 1 then
            print("Vibe highlight exists!")
        end
    end,

    nvim_echo = function()
        -- Echo with highlighting
        vim.api.nvim_echo({
            {"Vibe: ", "Title"},
            {"AI suggestion ready", "Normal"}
        }, true, {})
    end
}

-- 10. UTILITY FUNCTIONS
M.utility_examples = {
    json_encode = function()
        -- Convert table to JSON
        local data = {
            session_id = "vibe_123",
            file_path = "main.rs",
            content = "fn main() {}"
        }
        local json = vim.fn.json_encode(data)
        print("JSON: " .. json)
    end,

    json_decode = function()
        -- Parse JSON to table
        local json_str = '{"suggestion": "Use match instead", "confidence": 0.9}'
        local data = vim.fn.json_decode(json_str)
        print("Suggestion: " .. data.suggestion)
    end,

    split = function()
        -- Split string
        local lines = vim.fn.split("line1\nline2\nline3", "\n")
        for i, line in ipairs(lines) do
            print(i .. ": " .. line)
        end
    end,

    tbl_extend = function()
        -- Merge tables
        local defaults = {border = "rounded", width = 60}
        local user = {width = 80, title = "Vibe"}
        local merged = vim.tbl_extend("force", defaults, user)
        -- Result: {border = "rounded", width = 80, title = "Vibe"}
    end,

    has = function()
        -- Check Neovim features
        if vim.fn.has('nvim-0.8') == 1 then
            print("Neovim 0.8+ detected")
        end
        
        if vim.fn.has('unix') == 1 then
            print("Running on Unix system")
        end
    end
}

-- QUICK REFERENCE TABLE
M.quick_reference = {
    floating_window = [[
        local buf = vim.api.nvim_create_buf(false, true)
        local win = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = 60,
            height = 12,
            col = math.floor((vim.o.columns - 60) / 2),
            row = math.floor((vim.o.lines - 12) / 2),
            style = "minimal",
            border = "rounded"
        })
    ]],

    user_input = [[
        vim.ui.input({prompt = "Context: "}, function(input)
            if input then require('vibe').get_suggestion(input) end
        end)
    ]],

    async_backend_call = [[
        vim.fn.jobstart({'curl', '-X', 'POST', 'http://localhost:11500/generate', ...}, {
            on_stdout = function(_, data)
                local response = vim.fn.json_decode(table.concat(data))
                -- Handle response
            end
        })
    ]],

    buffer_operations = [[
        -- Get current file content
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local content = table.concat(lines, '\n')
        
        -- Replace buffer content
        vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(new_content, '\n'))
    ]]
}

return M
```

**File: `usage_examples.lua`**

```lua
-- Practical usage examples for Vibe tool

-- 1. COMPLETE SUGGESTION FLOW
local function show_suggestion_flow()
    -- Create suggestion window
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = 70,
        height = 15,
        col = math.floor((vim.o.columns - 70) / 2),
        row = math.floor((vim.o.lines - 15) / 2),
        style = "minimal",
        border = "rounded",
        title = "🎯 Vibe AI Suggestion",
        title_pos = "center"
    })
    
    -- Set content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "File: main.rs",
        "",
        "💡 Consider using match statement instead of multiple if-else",
        "",
        "Actions:",
        "  <Enter> - Apply suggestion",
        "  <Esc>  - Dismiss", 
        "  r      - Request revision",
        "  d      - Show diff"
    })
    
    -- Make it pretty
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_add_highlight(buf, -1, "Title", 0, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "Special", 2, 0, -1)
    
    -- Keymaps
    vim.keymap.set('n', '<CR>', function()
        vim.api.nvim_win_close(win, true)
        vim.notify("Suggestion applied!", vim.log.levels.INFO)
    end, {buffer = buf})
    
    vim.keymap.set('n', '<Esc>', function()
        vim.api.nvim_win_close(win, true)
    end, {buffer = buf})
end

-- 2. BACKEND COMMUNICATION
local function call_vibe_backend()
    local current_file = vim.fn.expand('%:p')
    local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    
    local request_data = {
        file_path = current_file,
        content = content,
        session_id = "vibe_" .. os.time()
    }
    
    vim.fn.jobstart({
        'curl', '-X', 'POST', 'http://localhost:11500/generate',
        '-H', 'Content-Type: application/json',
        '-d', vim.fn.json_encode(request_data)
    }, {
        on_stdout = function(_, data)
            if data and #data > 0 then
                local response = vim.fn.json_decode(table.concat(data))
                if response and response.suggestion then
                    show_suggestion_flow()
                end
            end
        end,
        on_stderr = function(_, error)
            vim.notify("Vibe backend error: " .. table.concat(error), vim.log.levels.ERROR)
        end
    })
end

-- 3. SETUP VIBE COMMANDS
local function setup_vibe_commands()
    vim.api.nvim_create_user_command('VibeSuggest', function(opts)
        local context = opts.args
        vim.notify("Getting AI suggestion...", vim.log.levels.INFO)
        call_vibe_backend()
    end, {
        desc = 'Get AI code suggestion',
        nargs = '?'
    })
    
    vim.api.nvim_create_user_command('VibeStart', function()
        vim.notify("🎉 Vibe session started!", vim.log.levels.INFO)
    end, {
        desc = 'Start Vibe coding session'
    })
end

-- 4. KEYBINDINGS
local function setup_vibe_keymaps()
    vim.keymap.set('n', '<leader>vs', '<cmd>VibeSuggest<CR>', {
        desc = 'Vibe suggest'
    })
    
    vim.keymap.set('n', '<leader>vv', function()
        vim.ui.select({"Suggestion", "Session Info", "Apply Last"}, {
            prompt = "Vibe Actions:"
        }, function(choice)
            if choice == "Suggestion" then
                vim.cmd('VibeSuggest')
            end
        end)
    end, {
        desc = 'Vibe quick actions'
    })
end
```

This cheat sheet gives you every Neovim API function you need with practical examples for building your Vibe tool UI!
