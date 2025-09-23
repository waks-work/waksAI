-- ui.lua
local state = require("waksAI.state")

local M = {}

-- Opens or reuses a right-hand markdown buffer for chat
function M.open_chat()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    return state.buf
  end

  -- Create new buffer
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(state.buf, "WaksAI")
  vim.bo[state.buf].filetype = "markdown"

  -- Open in right vertical split
  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, state.buf)
  vim.cmd("vertical resize 60")

  -- Make it non-modifiable by default
  vim.bo[state.buf].modifiable = false
  vim.bo[state.buf].buftype = "nofile"
  vim.bo[state.buf].bufhidden = "hide"

  return state.buf
end

-- Append markdown text to buffer
local function append_markdown(lines)
  local buf = M.open_chat()
  vim.bo[buf].modifiable = true

  local line_count = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, lines)

  vim.bo[buf].modifiable = false
  vim.api.nvim_win_set_cursor(0, {vim.api.nvim_buf_line_count(buf), 0})
end

-- Public: render a user message
function M.render_user(msg)
  append_markdown({
    "### 👤 User",
    msg,
    ""
  })
end

-- Public: render an AI message
function M.render_ai(msg, opts)
  opts = opts or {}
  local lines = { "### 🤖 AI" }

  if opts.is_code then
    table.insert(lines, "```" .. (opts.lang or ""))
    vim.list_extend(lines, vim.split(msg, "\n"))
    table.insert(lines, "```")
  else
    vim.list_extend(lines, vim.split(msg, "\n"))
  end

  table.insert(lines, "")
  append_markdown(lines)
end

return M
