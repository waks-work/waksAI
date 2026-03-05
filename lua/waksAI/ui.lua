---@mod waksAI.ui Ephemeral Inline UI Engine
---@brief Manages virtual text overlays, streaming animations, and
---user input.local state = require("waksAI.state")

local state = require("waksAI.state")
local M = {}

---@class WaksUIConfig
---@field overlay_prefix string The string prepended to virtual lines
---@field show_thinking boolean Whether to show the spinner
---@field streaming boolean Enable/disable chunked rendering
---@field thinking_frames string[] List of characters for animation
---@field thinking_speed integer Animation delay in ms
---@field icons table<string, string> UI symbols
M.config = {
  overlay_prefix = " > ",
  show_thinking = true,
  streaming = true,

  thinking_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
  thinking_speed = 80,
  streaming_speed = 25,

  icons = {
    user = "👤",
    ai = "🤖",
    thinking = "💭",
  },
}

-- ===================================
-- 📍 INLINE OVERLAY RENDERING
-- ===================================

---Renders raw lines as virtual text using extmarks
---@param line_num integer The 0-indexed line to attach to
---@param response_lines string[] The content to display
---@return integer # The namespace ID used
function M.render_inline_response(line_num, response_lines)
  local buf = vim.api.nvim_get_current_buf()
  local ns = vim.api.nvim_create_namespace("waksai_inline")

  -- Clear any existing overlays in this specific namespace
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local virt_lines = {}
  for _, line in ipairs(response_lines) do
    table.insert(virt_lines, {
      { M.config.overlay_prefix .. line, "Comment" }
    })
  end

  vim.api.nvim_buf_set_extmark(buf, ns, line_num, 0, {
    virt_lines = virt_lines,
    virt_lines_above = false,
  })

  return ns
end

---Displays the animated thinking spinner
---@param line_num integer
function M.render_thinking(line_num)
  local response_lines = {
    "// " .. M.config.icons.thinking .. " Thinking... [⠋]",
  }

  local ns = M.render_inline_response(line_num, response_lines)

  if M.config.show_thinking then
    M.animate_thinking(line_num, ns)
  end

  return ns
end

---Logic for the spinner loop
---@param line_num integer
---@param ns integer
function M.animate_thinking(line_num, ns)
  local frame = 1
  local timer = vim.loop.new_timer()
  state.thinking_timer = timer

  timer:start(0, M.config.thinking_speed, vim.schedule_wrap(function()
    -- Safety check: stop if thinking finished or buffer is gone
    if not state.is_thinking or not vim.api.nvim_buf_is_valid(0) then
      if not timer:is_closing() then
        timer:stop()
        timer:close()
      end
      return
    end

    local spinner = M.config.thinking_frames[frame]
    local response_lines = {
      "// " .. M.config.icons.thinking .. " Thinking... [" .. spinner .. "]",
    }

    M.render_inline_response(line_num, response_lines)
    frame = (frame % #M.config.thinking_frames) + 1
  end))
end

---Initializes the overlay state for a new AI call
---@param line_num integer
function M.render_ai_start(line_num)
  state.is_thinking = true
  state.ai_overlay_line = line_num
  state.ai_current_content = ""
  state.ai_namespace = M.render_thinking(line_num)
end

---Updates the overlay with new text chunks
---@param chunk string
function M.render_ai_stream(chunk)
  if not state.ai_overlay_line then return end

  state.is_thinking = false
  state.ai_current_content = (state.ai_current_content or "") .. chunk

  local buf = vim.api.nvim_get_current_buf()
  local ns = state.ai_namespace or vim.api.nvim_create_namespace("waksai_inline")

  local response_lines = { "// " .. M.config.icons.ai .. " Response", "" }

  for _, line in ipairs(vim.split(state.ai_current_content, "\n")) do
    table.insert(response_lines, line)
  end

  table.insert(response_lines, "")
  table.insert(response_lines, "[Tab: Insert] [Esc: Dismiss]")

  M.render_inline_response(state.ai_overlay_line, response_lines)
end

---Finalizes the UI state
function M.render_ai_complete()
  state.is_thinking = false
  if state.thinking_timer then
    state.thinking_timer:stop()
    state.thinking_timer:close()
    state.thinking_timer = nil
  end
end

---Cleans the buffer for all inline AI overlays.
function M.clear_overlay()
  local buf = vim.api.nvim_get_current_buf()
  local ns = state.ai_namespace or vim.api.nvim_create_namespace("waksai_inline")

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  state.ai_overlay_line = nil
  state.ai_current_content = nil
  state.is_thinking = false
end

---Commits the AI suggestion to the actual buffer text
function M.accept_suggestion()
  if not state.ai_current_content then return end

  local buf = vim.api.nvim_get_current_buf()
  local line_num = state.ai_overlay_line or vim.api.nvim_win_get_cursor(0)[1]

  local code_lines = {}
  local in_code_block = false

  -- Logic to extract content inside ``` markdown blocks
  for _, line in ipairs(vim.split(state.ai_current_content, "\n")) do
    if line:match("^```") then
      in_code_block = not in_code_block
    elseif in_code_block then
      table.insert(code_lines, line)
    end
  end

  if #code_lines == 0 then
    code_lines = vim.split(state.ai_current_content, "\n")
  end

  vim.api.nvim_buf_set_lines(buf, line_num, line_num, false, code_lines)
  M.clear_overlay()
end

---@note(waks-work): Is still unused.
---@param callback fun(...)
function M.get_user_input(callback)
  vim.ui.input({
    prompt = "WaksAI > ",
    default = "",
  }, function(text)
    if text and text ~= "" then
      callback(text)
    end
  end)
end

---@note(waks-work): This keybinds may change and may need to be updated
---so as to meet our requirements and the specific keymap rules we will follow.
---will be done more on init.lua file.
function M.setup_keymaps()
  -- Accept AI suggestion
  vim.keymap.set('n', '<Tab>', function()
    if state.ai_current_content then
      M.accept_suggestion()
    end
  end, { desc = "Accept AI suggestion" })

  -- Dismiss overlay
  vim.keymap.set('n', '<Esc>', function()
    M.clear_overlay()
  end, { desc = "Dismiss AI overlay" })

  -- Trigger AI inline
  vim.keymap.set('n', '<leader>ai', function()
    local line_num = vim.api.nvim_win_get_cursor(0)[1] - 1

    M.get_user_input(function(prompt)
      -- This would call your backend
      -- For now, just show thinking
      M.render_ai_start(line_num)

      -- Example: simulate response after 1 second
      vim.defer_fn(function()
        M.render_ai_stream("```rust\nlet example = 42;\n```")
        M.render_ai_complete()
      end, 1000)
    end)
  end, { desc = "Ask AI (inline)" })

  -- Copy last code block helper
  vim.keymap.set('n', 'yc', function()
    if state.ai_current_content then
      vim.fn.setreg('+', state.ai_current_content)
      vim.notify("AI response copied", vim.log.levels.INFO)
    end
  end, { desc = "Copy AI response" })
end

---@param opts WaksUIConfig?
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Alias for opening the input (since you don't have a chat window yet)
function M.open_chat()
  -- This is a placeholder since your current UI is inline only
  -- We can just notify or trigger the input directly
  vim.notify("WaksAI: Inline Mode Active", vim.log.levels.INFO)
end

-- Wrapper for rendering system messages
function M.render_system(msg, level)
  local lv = level == "error" and vim.log.levels.ERROR or vim.log.levels.INFO
  vim.notify("WaksAI: " .. msg, lv)
end

-- Placeholder for clearing loading (used in your prompt function)
function M.clear_loading()
  M.render_ai_complete()
end

-- Mapping for render_ai (using your streaming start)
function M.render_ai(text)
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1
  M.render_ai_start(line)
  M.render_ai_stream(text)
  M.render_ai_complete()
end

-- Mapping for render_user
function M.render_user(text)
  -- Your inline UI doesn't really 'render' the user text in the buffer,
  -- so we just log it for now.
  print("User: " .. text)
end

return M
