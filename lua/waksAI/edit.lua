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
    if not bridge.is_file_valid(bufnr) then
        bridge.notify("WaksAI: Target buffer no longer exists.", bridge.get_log_level("error"))
        return
    end

    local filepath = bridge.get_filename(bufnr)
    local original_content = table.concat(bridge.fetch_buffer_content(0, -1, bufnr), "\n")

    -- Write new_content to a temporary file for the diff viewT
    local tmpfile = bridge.generate_temp_filename() .. "_" .. bridge.modify_filename(filepath, ":t")
    local f = io.open(tmpfile, "w")
    if not f then
        bridge.notify("WaksAI: Failed to create temp file for diff.", bridge.get_log_level("error"))
        return
    end
    f:write(new_content)
    f:close()

    -- Create a new tab for the diff review
    bridge.execute_command("tabnew")
    local left_win = bridge.get_window_id()
    bridge.set_window_buffer(left_win, bufnr)

    -- Open the temp file on the right
    bridge.execute_command("vertical diffsplit " .. tmpfile)
    local right_win = bridge.get_window_id()

    -- Visual polish for the diff tab
    bridge.set_wrap(left_win, false)
    bridge.set_wrap(right_win, false)

    -- Prompt the user
    bridge.ui_selection({ "Apply", "Cancel" }, {
        prompt = "Review AI Changes. Apply to " .. bridge.modify_filename(filepath, ":p:.") .. "?"
    }, function(choice)
        local function cleanup()
            pcall(function()
                bridge.execute_command("tabclose")
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

            bridge.replace_line_range(bufnr, 0, -1, false, lines)

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
