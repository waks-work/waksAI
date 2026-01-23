-- ui.lua - Enhanced markdown-based UI with web-inspired styling


--[[
--
  Rule of thumb for Neovim AI UI (critical)

    You should not design a UI.

    You should design 3 interaction surfaces only:

    1. Input Surface

      Where the user types

      Inline or floating

      Single responsibility

    2. Output Surface

      Streaming text

      Diff / patch / explanation

      Scrollable, read-only

    3. Control Surface

      Keymaps

      Pickers

      Minimal commands

    If anything doesn’t fit one of these → it’s wrong.

  From now on:

    ❌ “Web-inspired”

    ❌ Panels

    ❌ Markdown tips

    ❌ Animated thinking blocks

    ❌ Tables in headers

  Replace with:

    Terminal-first, distraction-free, invisible UI

  1️⃣ Output Surface (keep most of this)

    Keep:

       - render_user
       - render_ai
       - streaming logic
       - markdown
       - copy helpers

    Remove / simplify:
       - timestamps → optional, off by default
       - emojis → keep max 2 (👤 🤖), remove rest
       - headers → one simple header, once

  2️⃣ Input Surface (change this)

      Do NOT embed input inside the chat buffer.

      Instead, do ONE of these (choose one):

      Option A (recommended)
         - Use vim.ui.input() for now
         - Dead simple
         - Zero UI bugs
         - You can replace later

          ```lua
          vim.ui.input({ prompt = "WaksAI > " }, function(text)
            if text and text ~= "" then
              -- send to backend
            end
          end)
          ```

      Option B (next iteration)
         - Separate floating buffer
         - Single-purpose
         - Closed after submit

    🚫 Never mix input + output again.

  After cleanup, this file should feel like:
     - Less than 500 lines
     - Boring
     - Predictable
     - Stable
     - Fast

  That’s how great Neovim plugins feel.

  Users should say:

  “It just works. I don’t notice the UI.”

--]] --

local state = require("waksAI.state")
local M = {}

-- ===================================
-- 🎨 UI CONFIGURATION (Web-inspired)
-- ===================================
M.config = {
  width = 70,
  min_width = 40,
  max_width = 100,
  position = "right",
  auto_scroll = true,
  show_timestamps = true,
  show_session_info = true,
  theme = {
    background = "#1e1e2e",
    foreground = "#cdd6f4",
    accent = "#89b4fa",
    secondary = "#7f849c",
    success = "#a6e3a1",
    warning = "#f9e2af",
    error = "#f38ba8",
    code_bg = "#181825",
    border = "#313244",
  },
  icons = {
    user = "👤",
    ai = "🤖",
    system = "⚙️",
    thinking = "💭",
    code = "📝",
    error = "❌",
    success = "✅",
    loading = "⏳",
    file = "📄",
    session = "🆔",
    provider = "🔌",
    model = "🧠",
    time = "🕐",
    status_online = "🟢",
    status_offline = "🔴",
    copy = "📋",
    refresh = "🔄",
  },
  animations = {
    enable = true,
    speed = 100,
  }
}

-- ===================================
-- 🔧 BUFFER MANAGEMENT
-- ===================================
function M.open_chat()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == state.buf then
        vim.api.nvim_set_current_win(win)
        return state.buf
      end
    end
    M.create_window(state.buf)
    return state.buf
  end

  -- Create new buffer with web-inspired styling
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(state.buf, "🧠 WaksAI Chat")
  vim.bo[state.buf].filetype = "markdown"
  vim.bo[state.buf].buftype = "nofile"
  vim.bo[state.buf].bufhidden = "hide"
  vim.bo[state.buf].swapfile = false
  vim.bo[state.buf].modifiable = false
  vim.bo[state.buf].syntax = "markdown"

  -- Setup buffer-local keymaps
  M.setup_keymaps(state.buf)
  M.create_window(state.buf)
  M.setup_highlights()

  return state.buf
end

--[[
-- ===================================
-- 💬 INPUT AREA FUNCTIONS
-- ===================================

-- Add input area at the bottom of chat
function M.add_input_area()
  local buf = M.open_chat()
  vim.bo[buf].modifiable = true

  local line_count = vim.api.nvim_buf_line_count(buf)

  -- Add input section separator and area
  local input_lines = {
    "",
    "---",
    "",
    "### " .. M.config.icons.user .. " **You**",
    "",
    "> Type your message below...",
    "> ",
    "> ",
    "> ",
    "",
    "**💡 Markdown Tips:**",
    "- `**bold**` • `*italic*` • `` `code` `` • `![alt](image.jpg)`",
    "- Press `++` on a new line to send • `qq` to cancel",
    ""
  }

  vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, input_lines)
  vim.bo[buf].modifiable = false

  -- Set cursor to the input area (line after "Type your message below...")
  local input_start_line = line_count + 6
  vim.api.nvim_win_set_cursor(0, { input_start_line, 2 })

  -- Enter insert mode
  vim.cmd("startinsert")

  return input_start_line
end

-- Get user input from the input area
function M.get_user_input(input_start_line)
  local buf = M.open_chat()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local user_lines = {}
  local found_end_marker = false

  -- Collect lines until we hit empty line or end marker
  for i = input_start_line, #lines do
    local line = lines[i]

    -- Check for send marker "++"
    if line:match("^>%s*%+%+%s*$") then
      found_end_marker = true
      break
    end

    -- Check for cancel marker "qq"
    if line:match("^>%s*qq%s*$") then
      return nil -- Cancel
    end

    -- Remove the "> " prefix and collect
    local content = line:gsub("^>%s*", "")
    if content ~= "" then
      table.insert(user_lines, content)
    end
  end

  if #user_lines == 0 and not found_end_marker then
    return nil -- No input
  end

  return table.concat(user_lines, "\n")
end

-- Clear the input area after sending
function M.clear_input_area(input_start_line)
  local buf = M.open_chat()
  vim.bo[buf].modifiable = true

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local end_line = #lines

  -- Find where the input area ends
  for i = input_start_line, #lines do
    if lines[i]:match("^%*%*💡 Markdown Tips:%*%*") then
      end_line = i - 1
      break
    end
  end

  -- Clear the input lines (keep the tips)
  local clear_lines = {}
  for i = input_start_line, end_line do
    table.insert(clear_lines, "")
  end

  vim.api.nvim_buf_set_lines(buf, input_start_line, end_line, false, clear_lines)
  vim.bo[buf].modifiable = false
end

-- Setup input area keymaps and autocmds
function M.setup_input_mode(input_start_line)
  local buf = M.open_chat()

  -- Add keymaps for the input mode
  local opts = { noremap = true, silent = true, buffer = buf }

  -- Quick markdown insertion shortcuts
  vim.keymap.set('i', '<C-b>', '**<Left>', opts)
  vim.keymap.set('i', '<C-i>', '*<Left>', opts)
  vim.keymap.set('i', '<C-k>', '`<Left>', opts)
  vim.keymap.set('i', '<C-p>', '![alt](<Left>', opts)

  -- Watch for send/cancel markers
  vim.api.nvim_create_autocmd("TextChanged", {
    buffer = buf,
    callback = function()
      local current_line = vim.api.nvim_get_current_line()

      -- Check for send marker
      if current_line:match("^>%s*%+%+%s*$") then
        local user_text = M.get_user_input(input_start_line)
        if user_text then
          M.clear_input_area(input_start_line)
          return user_text
        end
      end

      -- Check for cancel marker
      if current_line:match("^>%s*qq%s*$") then
        M.clear_input_area(input_start_line)
        return nil
      end
    end
  })
end
]]
function M.create_window(buf)
  if M.config.position == "float" then
    return M.create_float_window(buf)
  else
    if M.config.position == "left" then
      vim.cmd("topleft vsplit")
    else
      vim.cmd("vsplit")
    end
    vim.api.nvim_win_set_buf(0, buf)
    vim.cmd("vertical resize " .. M.config.width)

    -- Window styling
    vim.wo.winhl = "Normal:WaksAIBg,NormalNC:WaksAIBg,EndOfBuffer:WaksAIBg"
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = "no"
    vim.wo.wrap = true
    vim.wo.linebreak = true
    vim.wo.breakindent = true
    vim.wo.cursorline = true
    vim.wo.conceallevel = 2
    vim.wo.concealcursor = "nc"

    return 0
  end
end

function M.create_float_window(buf)
  local width = math.min(M.config.max_width, math.floor(vim.o.columns * 0.8))
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  -- Apply styling to float window
  vim.wo[win].winhl = "Normal:WaksAIBg,NormalNC:WaksAIBg,EndOfBuffer:WaksAIBg,FloatBorder:WaksAIBorder"
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = true

  return win
end

-- ===================================
-- 🎨 HIGHLIGHTS & STYLING
-- ===================================
function M.setup_highlights()
  local theme = M.config.theme

  vim.cmd(string.format([[
    highlight WaksAIBg guibg=%s guifg=%s
    highlight WaksAIBorder guifg=%s
    highlight WaksAIHeader guifg=%s gui=bold
    highlight WaksAIUser guifg=#f5c2e7 gui=bold
    highlight WaksAIAI guifg=%s gui=bold
    highlight WaksAISystem guifg=%s gui=italic
    highlight WaksAICode guibg=%s guifg=%s
    highlight WaksAISuccess guifg=%s gui=bold
    highlight WaksAIError guifg=%s gui=bold
    highlight WaksAIWarning guifg=%s gui=bold
    highlight WaksAITimestamp guifg=%s gui=italic
    highlight WaksAISession guifg=%s
    highlight link markdownH1 WaksAIHeader
    highlight link markdownH2 WaksAIHeader
    highlight link markdownH3 WaksAIHeader
  ]],
    theme.background, theme.foreground,
    theme.border,
    theme.accent,
    theme.accent,
    theme.success,
    theme.code_bg, theme.foreground,
    theme.success,
    theme.error,
    theme.warning,
    theme.secondary,
    theme.secondary
  ))
end

-- ===================================
-- 📝 RENDERING FUNCTIONS (Web-inspired)
-- ===================================
local function append_markdown(lines)
  local buf = M.open_chat()
  vim.bo[buf].modifiable = true

  local line_count = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, lines)

  vim.bo[buf].modifiable = false

  if M.config.auto_scroll then
    vim.schedule(function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == buf then
          local new_line_count = vim.api.nvim_buf_line_count(buf)
          pcall(vim.api.nvim_win_set_cursor, win, { new_line_count, 0 })
        end
      end
    end)
  end
end

local function get_timestamp()
  if not M.config.show_timestamps then return "" end
  return os.date("%H:%M")
end

-- Render beautiful header like web version
function M.render_header()
  local buf = M.open_chat()
  vim.bo[buf].modifiable = true

  local provider = state.session.provider or "unknown"
  local model = state.session.model or "unset"
  local session_id = state.session.id or "default"
  local timestamp = os.date("%Y-%m-%d %H:%M")

  local header = {
    "# 🧠 WaksAI - AI Coding Assistant",
    "",
    "---",
    "",
  }

  if M.config.show_session_info then
    vim.list_extend(header, {
      "## 📊 Session Information",
      "",
      "| | |",
      "|-|-|",
      "| " .. M.config.icons.provider .. " **Provider** | `" .. provider .. "` |",
      "| " .. M.config.icons.model .. " **Model** | `" .. model .. "` |",
      "| " .. M.config.icons.session .. " **Session** | `" .. session_id .. "` |",
      "| " .. M.config.icons.time .. " **Started** | `" .. timestamp .. "` |",
      "| " .. M.config.icons.status_online .. " **Status** | `Connected` |",
      "",
      "---",
      "",
    })
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, header)
  vim.bo[buf].modifiable = false
end

-- Render user message with web-style formatting
function M.render_user(msg)
  local timestamp = get_timestamp()
  local time_str = timestamp ~= "" and " <small>`" .. timestamp .. "`</small>" or ""

  local lines = {
    "",
    "### " .. M.config.icons.user .. " **You**" .. time_str,
    "",
  }

  -- Add message content with proper formatting
  for _, line in ipairs(vim.split(msg, "\n")) do
    if line ~= "" then
      table.insert(lines, "> " .. line)
    else
      table.insert(lines, "")
    end
  end

  table.insert(lines, "")
  table.insert(lines, "---")
  table.insert(lines, "")

  append_markdown(lines)
end

-- Render AI message with code blocks and beautiful formatting
function M.render_ai(msg, opts)
  opts = opts or {}
  local timestamp = get_timestamp()
  local time_str = timestamp ~= "" and " <small>`" .. timestamp .. "`</small>" or ""

  local lines = {
    "",
    "### " .. M.config.icons.ai .. " **WaksAI**" .. time_str,
    "",
  }

  if opts.is_code then
    -- Enhanced code block with header like web version
    local lang = opts.lang or ""
    table.insert(lines, "#### " .. M.config.icons.code .. " Code Example")
    table.insert(lines, "")
    table.insert(lines, "```" .. lang)
    vim.list_extend(lines, vim.split(msg, "\n"))
    table.insert(lines, "```")
    table.insert(lines, "")
    table.insert(lines, "*" .. M.config.icons.copy .. " Use `yc` to copy this code block*")
    table.insert(lines, "")
  else
    -- Regular text with better formatting
    for _, line in ipairs(vim.split(msg, "\n")) do
      if line ~= "" then
        table.insert(lines, line)
      else
        table.insert(lines, "")
      end
    end
  end

  table.insert(lines, "---")
  table.insert(lines, "")

  append_markdown(lines)
end

-- Render thinking indicator with animated dots
function M.render_thinking(thought)
  local lines = {
    "",
    "> " .. M.config.icons.thinking .. " **Thinking**",
    ">",
  }

  for _, line in ipairs(vim.split(thought, "\n")) do
    table.insert(lines, "> " .. line)
  end

  table.insert(lines, ">")
  table.insert(lines, "> *" .. M.config.icons.loading .. " Processing...*")
  table.insert(lines, "")

  append_markdown(lines)
end

-- Render context files panel like web version
function M.render_context_files(files)
  if not files or #files == 0 then return end

  local lines = {
    "",
    "## 📁 Active Context",
    "",
  }

  for _, file in ipairs(files) do
    table.insert(lines, "- " .. M.config.icons.file .. " `" .. file .. "`")
  end

  table.insert(lines, "")
  table.insert(lines, "---")
  table.insert(lines, "")

  append_markdown(lines)
end

-- Render quick actions panel
function M.render_quick_actions()
  local lines = {
    "",
    "## 🔧 Quick Actions",
    "",
    "- " .. M.config.icons.refresh .. " **Refresh Context** - `,ar`",
    "- " .. M.config.icons.copy .. " **Copy Last Code** - `yc`",
    "- " .. M.config.icons.file .. " **Clear Chat** - `,ac`",
    "- " .. M.config.icons.model .. " **Toggle Model** - `,wm`",
    "",
    "---",
    "",
  }

  append_markdown(lines)
end

-- Enhanced system messages
function M.render_system(msg, level)
  level = level or "info"
  local icon = M.config.icons.system
  local color = ""

  if level == "error" then
    icon = M.config.icons.error
    color = "color=#f38ba8"
  elseif level == "success" then
    icon = M.config.icons.success
    color = "color=#a6e3a1"
  elseif level == "warning" then
    icon = M.config.icons.warning
    color = "color=#f9e2af"
  elseif level == "loading" then
    icon = M.config.icons.loading
    color = "color=#89b4fa"
  end

  local lines = {
    "",
    "> **" .. icon .. " " .. level:upper() .. "**: " .. msg,
    "",
  }

  append_markdown(lines)
end

-- Streaming response functions
function M.render_ai_start()
  local timestamp = get_timestamp()
  local time_str = timestamp ~= "" and " <small>`" .. timestamp .. "`</small>" or ""

  state.ai_message_start_line = vim.api.nvim_buf_line_count(M.open_chat())

  append_markdown({
    "",
    "### " .. M.config.icons.ai .. " **WaksAI**" .. time_str,
    "",
    M.config.icons.thinking .. " *Thinking...*",
    "",
  })
end

function M.render_ai_stream(chunk)
  if not state.ai_current_content then
    state.ai_current_content = ""
  end
  state.ai_current_content = state.ai_current_content .. chunk

  local buf = M.open_chat()
  vim.bo[buf].modifiable = true

  local start_line = state.ai_message_start_line + 4
  local end_line = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, start_line, end_line, false, {})

  local content_lines = vim.split(state.ai_current_content, "\n")
  vim.api.nvim_buf_set_lines(buf, start_line, start_line, false, content_lines)

  vim.bo[buf].modifiable = false

  if M.config.auto_scroll then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == buf then
        local line_count = vim.api.nvim_buf_line_count(buf)
        pcall(vim.api.nvim_win_set_cursor, win, { line_count, 0 })
      end
    end
  end
end

function M.render_ai_complete()
  append_markdown({
    "",
    "---",
    "",
  })
  state.ai_current_content = nil
end

-- ===================================
-- ⌨️ ENHANCED KEYMAPS
-- ===================================
function M.setup_keymaps(buf)
  local opts = { noremap = true, silent = true, buffer = buf }

  -- Navigation
  vim.keymap.set("n", "q", function()
    vim.cmd("close")
  end, opts)

  vim.keymap.set("n", "<Esc>", function()
    vim.cmd("close")
  end, opts)

  -- Chat actions
  vim.keymap.set("n", "<leader>ac", function()
    M.clear_chat()
  end, opts)

  vim.keymap.set("n", "<leader>aw", function()
    M.toggle_width()
  end, opts)

  vim.keymap.set("n", "<leader>ar", function()
    M.refresh_chat()
  end, opts)

  -- Input mode
  vim.keymap.set("n", "<leader>ai", function()
    M.start_input_mode()
  end, { desc = "Start input mode" })

  -- Code actions
  vim.keymap.set("n", "yc", function()
    M.copy_last_code_block()
  end, opts)

  vim.keymap.set("n", "yy", function()
    M.copy_last_message()
  end, opts)

  -- Session management
  vim.keymap.set("n", "<leader>as", function()
    M.show_session_info()
  end, opts)
end

-- ===================================
-- 🔧 UTILITY FUNCTIONS
-- ===================================
function M.clear_chat()
  local buf = M.open_chat()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  vim.bo[buf].modifiable = false
  M.render_header()
  M.render_quick_actions()
  vim.notify("Chat cleared", vim.log.levels.INFO)
end

function M.refresh_chat()
  M.clear_chat()
  M.render_system("Chat refreshed", "success")
end

function M.toggle_width()
  local current = vim.api.nvim_win_get_width(0)
  local new_width

  if current <= M.config.min_width then
    new_width = M.config.width
  elseif current < M.config.width then
    new_width = M.config.max_width
  else
    new_width = M.config.min_width
  end

  vim.cmd("vertical resize " .. new_width)
  vim.notify("Window width: " .. new_width, vim.log.levels.INFO)
end

function M.copy_last_code_block()
  local buf = M.open_chat()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local in_code = false
  local code_lines = {}
  local lang = ""

  for i = #lines, 1, -1 do
    local line = lines[i]
    if line:match("^```") then
      if in_code then
        lang = line:match("^```(.*)$") or ""
        break
      else
        in_code = true
      end
    elseif in_code then
      table.insert(code_lines, 1, line)
    end
  end

  if #code_lines > 0 then
    local code = table.concat(code_lines, "\n")
    vim.fn.setreg("+", code)
    vim.notify("Code copied to clipboard" .. (lang ~= "" and " (" .. lang .. ")" or ""), vim.log.levels.INFO)
  else
    vim.notify("No code block found", vim.log.levels.WARN)
  end
end

function M.copy_last_message()
  local buf = M.open_chat()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local in_message = false
  local message_lines = {}

  for i = #lines, 1, -1 do
    local line = lines[i]
    if line:match("^### 🤖") or line:match("^### 👤") then
      if in_message then break end
      in_message = true
    elseif in_message and line ~= "---" and line ~= "" then
      if not line:match("^```") then
        table.insert(message_lines, 1, line)
      end
    end
  end

  if #message_lines > 0 then
    local message = table.concat(message_lines, "\n")
    vim.fn.setreg("+", message)
    vim.notify("Message copied to clipboard", vim.log.levels.INFO)
  else
    vim.notify("No message found", vim.log.levels.WARN)
  end
end

function M.show_session_info()
  local provider = state.session.provider or "unknown"
  local model = state.session.model or "unset"
  local session_id = state.session.id or "default"

  local info = string.format(
    "Session: %s\nProvider: %s\nModel: %s\nHistory: %d messages",
    session_id, provider, model, #(state.session.history or {})
  )

  vim.notify(info, vim.log.levels.INFO)
end

function M.get_status()
  if not state.session then
    return "WaksAI: Inactive"
  end

  return string.format(
    "🧠 %s/%s",
    state.session.provider or "?",
    state.session.model or "?"
  )
end

-- ===================================
-- 🎯 SETUP
-- ===================================
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)
  M.setup_highlights()
end

return M
