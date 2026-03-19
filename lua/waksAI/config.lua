local bridge = require "bridge"
---@mod waksAI.config Configuration Management
local M = {}

local config_path_rules = vim.fn.expand("~/.config/nvim/ai/user_rules.txt")

---@class WaksConfig
M.defaults = {
    -- Backend connection
    endpoint = "http://127.0.0.1:11500",

    provider = "ollama",
    model = "llama2",

    ui = {
        float_width = 0.8,
        float_height = 0.8,
        border = "rounded",
        auto_save_history = true,
        max_history_size = 50,
    },
    agent_mode = false,
    rules_path = rules_path,
}

---@type WaksConfig
M.options = {}

--- Create folder if missing
local function ensure_dir()
    ---@note(waks-work): ensure implemented.
    local dir = vim.fn.fnamemodify(config_path_rules, ":h")
    if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
    end
end

--- Open the rules file for manual editing
function M.open_user_rules()
    ensure_dir()
    vim.cmd("edit " .. rules_path)
end

--- Initialize configuration
---@param opts WaksConfig?
function M.setup(opts)
    --- @fix: bridge.merge_tables(table_one, table_two)
    M.options = bridge(M.defaults, opts or {})

    -- Create the WaksAIRules command
    --- @note(waks-work): ensure you make an implementation for this.
    vim.api.nvim_create_user_command("WaksAIRules", function()
        M.open_user_rules()
    end, { desc = "Edit waksAI user rules configuration" })

    -- Setup keymap
    bridge.set_keymap("n", "<leader>wc", M.open_user_rules, { desc = "Edit waksAI rules" })

    return M.options
end
