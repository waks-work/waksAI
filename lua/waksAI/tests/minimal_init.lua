vim.cmd('packadd plenary.nvim')
local tests_dir = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":p:h")
local plugin_dir = vim.fn.fnamemodify(tests_dir, ":h")

vim.opt.rtp:append(plugin_dir)

local plenary_path = vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim")
if vim.fn.isdirectory(plenary_path) == 1 then
    vim.opt.rtp:append(plenary_path)
end

require("waksAI").setup({})

print("✅ Environment Ready")
