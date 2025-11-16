local M = {}

-- Path where the Rust backend expects user_rules.txt
local config_path = vim.fn.expand("~/.config/nvim/ai/user_rules.txt")

-- Create folder if missing
local function ensure_dir()
  local dir = vim.fn.fnamemodify(config_path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

-- Open the rules file
function M.open_user_rules()
  ensure_dir()
  vim.cmd("edit " .. config_path)
end

-- Optionally create a Neovim command
vim.api.nvim_create_user_command("WaksAIRules", function()
  M.open_user_rules()
end, { desc = "Edit waksAI user rules configuration" })

-- Optional keymap (change <leader>wr if you like)
vim.keymap.set("n", "<leader>wc", M.open_user_rules, { desc = "Edit waksAI rules" })

return M
