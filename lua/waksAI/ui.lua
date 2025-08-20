local util  = require("waksAI.utils")
local state = require("waksAI.state")

local M = {}

M.chat_buf = nil
M.chat_win = nil
M.prompt_buf = nil
M.prompt_win = nil
M.loading_win = nil

-- colors (Tokyo-ish)
function M.setup_highlights()
  vim.cmd("highlight WAKSHeader      guibg=#24283b guifg=#c0caf5")
  vim.cmd("highlight WAKSUserBubble  guibg=#3a3a4a guifg=#ffffff")
  vim.cmd("highlight WAKSAIBubble    guibg=#1a1b26 guifg=#c0caf5")
  vim.cmd("highlight WAKSSystem      guibg=#1f2335 guifg=#7aa2f7")
  vim.cmd("highlight WAKSCodeBg      guibg=#16161e guifg=#c0caf5")
end

-- ensure chat floating window
function M.ensure_chat_win()
  if M.chat_buf and vim.api.nvim_buf_is_valid(M.chat_buf) and M.chat_win and vim.api.nvim_win_is_valid(M.chat_win) then
    return
  end

  local width  = util.chat_width()
  local height = util.chat_height()

  local buf = vim.api.nvim_create_buf(false, true)
  local opts = {
    style = "minimal",
    relative = "editor",
    width = width,
    height = height,
    row = 2,
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
  }
  local win = vim.api.nvim_open_win(buf, true, opts)

  M.chat_buf = buf
  M.chat_win = win

  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_win_set_option(win, "wrap", true)

  -- header
  local title = "waksAI (" .. state.current_model() .. ")"
  local header = "╭" .. string.rep("─", width-2) .. "╮"
  local title_line = "│ " .. title .. string.rep(" ", width - 4 - #title) .. "│"
  local footer = "╰" .. string.rep("─", width-2) .. "╯"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { header, title_line, footer, "" })
  for i=0,2 do
    vim.api.nvim_buf_add_highlight(buf, -1, "WAKSHeader", i, 0, -1)
  end
end

-- draw a message “bubble”
local function bubble_lines(role, text)
  local width = util.chat_width()
  local inner = width - 2
  local who   = (role == "user" and "👤 You") or (role == "ai" and "🤖 DeepSeek") or "⚙ System"
  local lines = {}
  table.insert(lines, "╭" .. string.rep("─", inner) .. "╮")
  table.insert(lines, "│ " .. who .. string.rep(" ", inner - #who) .. "│")
  for _, l in ipairs(util.wrap(text, inner)) do
    local padding = inner - #l
    table.insert(lines, "│ " .. l .. string.rep(" ", padding) .. "│")
  end
  table.insert(lines, "╰" .. string.rep("─", inner) .. "╯")
  local hl = (role == "user" and "WAKSUserBubble") or (role == "ai" and "WAKSAIBubble") or "WAKSSystem"
  return lines, hl
end

function M.append_bubble(role, content)
  if not (M.chat_buf and vim.api.nvim_buf_is_valid(M.chat_buf)) then return end
  state.add(role, content)
  local lines, hl = bubble_lines(role, content)
  local start = vim.api.nvim_buf_line_count(M.chat_buf)
  vim.api.nvim_buf_set_lines(M.chat_buf, -1, -1, false, lines)
  for i=0, #lines-1 do
    vim.api.nvim_buf_add_highlight(M.chat_buf, -1, hl, start + i, 0, -1)
  end
  vim.api.nvim_win_set_cursor(M.chat_win, {vim.api.nvim_buf_line_count(M.chat_buf), 0})
end

function M.system_note(msg)
  M.append_bubble("system", msg)
end

-- mini code editor popup for code blocks
function M.open_code_editor(lang, code)
  local width = math.min( math.floor(vim.o.columns * 0.6), 100 )
  local height = math.min( math.floor(vim.o.lines   * 0.5),  20 )

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    style="minimal", relative="editor",
    width=width, height=height,
    row=math.floor((vim.o.lines-height)/2),
    col=math.floor((vim.o.columns-width)/2),
    border="rounded",
  })
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_win_set_option(win, "wrap", false)
  if lang and #lang > 0 then
    vim.api.nvim_buf_set_option(buf, "filetype", lang)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(code, "\n", { plain = true }))
  vim.api.nvim_buf_add_highlight(buf, -1, "WAKSCodeBg", 0, 0, -1)
end

-- bottom floating prompt (keeps previous window; returns on <CR>)
function M.open_prompt(on_submit)
  -- remember current window to restore focus after we open prompt
  local prev_win = vim.api.nvim_get_current_win()

  local width = math.min(60, math.floor(vim.o.columns * 0.6))
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "prompt")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  local win = vim.api.nvim_open_win(buf, true, {
    style="minimal", relative="editor",
    width=width, height=1,
    row=vim.o.lines-3, col=math.floor((vim.o.columns - width)/2),
    border="rounded",
  })
  M.prompt_buf, M.prompt_win = buf, win
  vim.api.nvim_win_set_option(win, "winhl", "Normal:WAKSUserBubble")
  vim.fn.prompt_setprompt(buf, "You: ")

  vim.fn.prompt_setcallback(buf, function(text)
    -- restore previous window (user's buffer) after capturing
    if vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
    end
    if on_submit then on_submit(text or "") end
    if M.prompt_win and vim.api.nvim_win_is_valid(M.prompt_win) then
      vim.api.nvim_win_close(M.prompt_win, true)
    end
  end)

  vim.cmd("startinsert")
end

-- loading chip
function M.show_loading()
  if M.loading_win and vim.api.nvim_win_is_valid(M.loading_win) then return end
  local width = 26
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, false, {
    style="minimal", relative="editor",
    width=width, height=1,
    row=vim.o.lines-3, col=math.floor((vim.o.columns-width)/2),
    border="rounded",
  })
  M.loading_win = win
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"🤖 DeepSeek is typing..."})
end

function M.hide_loading()
  if M.loading_win and vim.api.nvim_win_is_valid(M.loading_win) then
    vim.api.nvim_win_close(M.loading_win, true)
    M.loading_win = nil
  end
end

return M

