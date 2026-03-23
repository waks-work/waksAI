local bridge = require "bridge"
---@mod waksAI.config Configuration Management
local M = {}

local rules_path = bridge.get_file_path("~/.config/nvim/ai/user_rules.txt")

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
    local dir = bridge.modify_filename(rules_path, ":h")
    if bridge.is_directory(dir) == 0 then
        bridge.make_directory(dir, "p")
    end
end

--- Open the rules file for manual editing
function M.open_user_rules()
    ensure_dir()
    bridge.execute_command("edit " .. rules_path)
end

--- Initialize configuration
---@param opts WaksConfig?
function M.setup(opts)
    M.options = bridge.merge_tables(M.defaults, opts or {})

    bridge.create_user_command("WaksAIRules", function()
        M.open_user_rules()
    end, { desc = "Edit waksAI user rules configuration" })

    -- Setup keymap
    bridge.set_keymap("n", "<leader>wc", M.open_user_rules, { desc = "Edit waksAI rules" })

    return M.options
end
