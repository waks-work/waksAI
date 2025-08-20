local M = {}
local ui = require("waksAI.ui")

-- Non-current floating prompt that does NOT steal focus from your code window.
function M.floating_input(prompt, on_enter)
  local width = math.min(64, math.floor(vim.o.columns * 0.6))
  local row = vim.o.lines - 2
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "prompt"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false

  local win = vim.api.nvim_open_win(buf, false, {
    style = "minimal", relative = "editor",
    width = width, height = 1, row = row, col = col, border = "rounded",
  })
  vim.api.nvim_win_set_option(win, "winhl", "Normal:ChatUserBubble")
  vim.fn.prompt_setprompt(buf, prompt .. " ")

  vim.fn.prompt_setcallback(buf, function(input)
    if input and input ~= "" then
      -- Append to chat (single insertion)
      ui.append_bubble("user", input)
      if on_enter then on_enter(input) end
    end
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end)

  -- Keep your main window as-is; just focus this input temporarly
  vim.api.nvim_set_current_win(win)
  vim.cmd("startinsert")
end

return M

