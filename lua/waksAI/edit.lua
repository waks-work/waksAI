local M = {}
local history = require("waksAI.history")

-- Show diff and offer to apply. Will create a backup before applying.
-- bufnr: buffer number of the file to modify
-- new_content: string with the proposed new file content
-- ai_output: raw AI response (for logging), optional
-- on_apply: callback after apply
function M.show_diff_and_apply(bufnr, new_content, ai_output, on_apply)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify("Invalid buffer for apply", vim.log.levels.ERROR)
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  -- Write new_content to temp file
  local tmpfile = vim.fn.tempname() .. ".tmp"
  local f = io.open(tmpfile, "w")
  if not f then
    vim.notify("Failed to write temporary file for diff", vim.log.levels.ERROR)
    return
  end
  f:write(new_content)
  f:close()

  -- create a tab with left=original, right=tmpfile
  vim.cmd("tabnew")
  local left_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(left_win, bufnr)
  vim.cmd("vsplit " .. tmpfile)
  local right_win = vim.api.nvim_get_current_win()

  -- enable diff mode across both windows
  vim.cmd("windo diffthis")

  -- Ask user
  vim.ui.select({ "Apply", "Cancel" }, { prompt = "Apply AI changes to file?" }, function(choice)
    -- always cleanup diff and tmp even on cancel
    local function cleanup()
      pcall(function()
        vim.cmd("diffoff!")
        vim.cmd("tabclose")
        os.remove(tmpfile)
      end)
    end

    if choice == "Apply" then
      -- create backup before applying
      pcall(function()
        history.log_change(filepath, "AI edit", ai_output or "")
      end)

      -- replace buffer contents
      local lines = vim.split(new_content, "\n")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      if on_apply then pcall(on_apply) end
      vim.notify("Applied AI changes to " .. (filepath or "buffer"), vim.log.levels.INFO)
      cleanup()
      return
    end

    -- user cancelled
    cleanup()
    vim.notify("AI changes canceled", vim.log.levels.INFO)
  end)
end

return M

