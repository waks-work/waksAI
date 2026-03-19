-- Neovim API Cheat Sheet for Vibe Tool Development
-- Complete function reference with practical examples

local M = {}

-- 1. WINDOW MANAGEMENT
M.window_examples = {
    nvim_open_win = function()
        -- Create a floating window
        local buf = vim.api.nvim_create_buf(false, true)
        local win = vim.api.nvim_open_win(buf, true, {
            relative  = "editor",
            width     = 60,
            height    = 10,
            col       = 10,
            row       = 5,
            style     = "minimal",
            border    = "rounded",
            title     = "Vibe Suggestion",
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
        vim.api.nvim_buf_add_highlight(buf, -1, "Title", 0, 0, -1)   -- Line 0
        vim.api.nvim_buf_add_highlight(buf, -1, "Comment", 1, 0, -1) -- Line 1
    end,

    nvim_buf_set_keymap = function(buf)
        -- Set buffer-local keymap
        vim.api.nvim_buf_set_keymap(buf, 'n', '<ESC>',
            '<cmd>q<CR>', { noremap = true, silent = true })
    end
}

-- 3. USER INPUT & UI
M.ui_examples = {
    ui_input = function()
        -- Get text input from user
        vim.ui.input({
            prompt  = "Vibe: ",
            default = "Improve this code"
        }, function(input)
            if input then
                print("User entered: " .. input)
            end
        end)
    end,

    ui_select = function()
        -- Show selection menu
        local items = { "Refactor", "Document", "Optimize", "Debug" }
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
            title   = "Vibe AI",
            icon    = "🎯",
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
            { noremap = true, silent = true })
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
        vim.fn.jobstart({ 'curl', 'http://localhost:11500/health' }, {
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
        local result = vim.fn.system({ 'echo', 'hello vibe' })
        print("System result: " .. result)
    end
}

-- 6. BUFFER/FILE INFO
M.file_examples = {
    expand = function()
        -- Expand file paths
        local current_file = vim.fn.expand('%:p')     -- Full path
        local file_name    = vim.fn.expand('%:t')     -- Just filename
        local word         = vim.fn.expand('<cword>') -- Current word

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
        local dir       = vim.fn.fnamemodify(full_path, ':h') -- /home/user/project/src
        local name      = vim.fn.fnamemodify(full_path, ':t') -- main.rs
        local ext       = vim.fn.fnamemodify(full_path, ':e') -- rs
    end
}

-- 7. AUTOCOMMANDS & EVENTS
M.autocmd_examples = {
    nvim_create_autocmd = function()
        -- Create autocommand group
        local vibe_group = vim.api.nvim_create_augroup('VibeGroup', { clear = true })

        -- Track file changes
        vim.api.nvim_create_autocmd({ 'BufWritePost' }, {
            group    = vibe_group,
            pattern  = '*.rs,*.lua,*.py',
            desc     = 'Track file changes for Vibe',
            callback = function(args)
                print("File saved: " .. args.file)
            end
        })

        -- Auto-start session
        vim.api.nvim_create_autocmd({ 'VimEnter' }, {
            group    = vibe_group,
            once     = true,
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
            desc  = 'Get AI suggestion',
            nargs = '?' -- Optional argument
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
            fg   = '#00ff00',
            bg   = '#1a1a1a',
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
            { "Vibe: ",              "Title" },
            { "AI suggestion ready", "Normal" }
        }, true, {})
    end
}

-- 10. UTILITY FUNCTIONS
M.utility_examples = {
    json_encode = function()
        -- Convert table to JSON
        local data = {
            session_id = "vibe_123",
            file_path  = "main.rs",
            content    = "fn main() {}"
        }
        local json = vim.fn.json_encode(data)
        print("JSON: " .. json)
    end,

    json_decode = function()
        -- Parse JSON to table
        local json_str = '{"suggestion": "Use match instead", "confidence": 0.9}'
        local data     = vim.fn.json_decode(json_str)
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
        local defaults = { border = "rounded", width = 60 }
        local user     = { width = 80, title = "Vibe" }
        local merged   = vim.tbl_extend("force", defaults, user)
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
            col   = math.floor((vim.o.columns - 60) / 2),
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
