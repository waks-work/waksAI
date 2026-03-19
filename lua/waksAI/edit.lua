local M = {}
local api = require("waksAI.api")
local state = require("waksAI.state")
local bridge = require("waksAI.bridge")

---Show a side-by-side diff and offer to apply the changes.
---@param bufnr number Buffer to modify
---@param new_content string The full new content proposed by AI
---@param description string? Optional description for the database log
---@param on_apply fun()? Optional callback after applying
function M.show_diff_and_apply(bufnr, new_content, description, on_apply)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        vim.notify("WaksAI: Target buffer no longer exists.", vim.log.levels.ERROR)
        return
    end

    local filepath = vim.api.nvim_buf_get_name(bufnr)
    local original_content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

    -- Write new_content to a temporary file for the diff view
    local tmpfile = vim.fn.tempname() .. "_" .. vim.fn.fnamemodify(filepath, ":t")
    local f = io.open(tmpfile, "w")
    if not f then
        --- @fix: bridge.notify(msg)
        vim.notify("WaksAI: Failed to create temp file for diff.", vim.log.levels.ERROR)
        return
    end
    f:write(new_content)
    f:close()

    -- Create a new tab for the diff review
    vim.cmd("tabnew")
    local left_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(left_win, bufnr)

    -- Open the temp file on the right
    vim.cmd("vertical diffsplit " .. tmpfile)
    local right_win = vim.api.nvim_get_current_win()

    -- Visual polish for the diff tab
    vim.wo[left_win].wrap = false
    vim.wo[right_win].wrap = false

    -- Prompt the user
    vim.ui.select({ "Apply", "Cancel" }, {
        prompt = "Review AI Changes. Apply to " .. vim.fn.fnamemodify(filepath, ":p:.") .. "?"
    }, function(choice)
        local function cleanup()
            pcall(function()
                ---@note(waks-work): make an implementation for this two
                vim.cmd("tabclose")
                os.remove(tmpfile)
            end)
        end

        if choice == "Apply" then
            -- 1. Sync the change to the Rust Backend (SQLite)
            api.record_code_change(
                filepath,
                original_content,
                new_content,
                description or "AI automated refactor"
            )

            -- 2. Update the actual buffer
            local lines = bridge.split_strings(new_content, "\n", true)
            --- @note(waks-work): make an implementation for this
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

            if on_apply then on_apply() end
            bridge.notify("WaksAI: Changes applied successfully.", bridge.get_log_level("info"))
            cleanup()
        else
            bridge.notify("WaksAI: Changes discarded.", bridge.get_log_level("info"))
            cleanup()
        end
    end)
end

return M
