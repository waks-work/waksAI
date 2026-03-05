---@mod waksAI.inline_ai Inline AI Suggestion Engine
---@brief Handles virtual text overlays, diff previews, and buffer modifications.

---@class AISuggestion
---@field line_num integer The starting line of the suggestion
---@field original_lines string[] The code before AI intervention
---@field ai_lines string[] The code proposed by the AI
---@field type "modification"|"addition"|"deletion"
---@field session_id string The session GUID for database tracking
---@field display_start integer Virtual tracking for start of UI overlay
---@field display_end integer Virtual tracking for end of UI overlay

local InlineAI              = {}

---@type integer Namespace ID for inline virtual text
InlineAI.ns                 = vim.api.nvim_create_namespace('inline_ai')

---@type table<integer, AISuggestion> Active suggestions mapped by line number
InlineAI.suggestions        = {}

---@type integer|nil The buffer currently being processed
InlineAI.current_buf        = nil

---@type string|nil Active session identifier
InlineAI.current_session_id = nil

local api                   = require('waksAI.api')

--- UI

--- Configures the aesthetics for the inline diffs
function InlineAI:setup_highlights()
  vim.cmd('highlight AISuggestion guifg=#4EC9B0 guibg=#1e3a28 gui=italic')
  vim.cmd('highlight AIOriginal guifg=#F48771 guibg=#3a1e1e gui=strikethrough')
  vim.cmd('highlight AICurrent guibg=#2d4a3a')
end

--- Initializes the engine state
function InlineAI:init()
  self:setup_highlights()
  self.current_buf        = nil
  self.current_session_id = "inline_ai_" .. tostring(os.time())
end

--- LOGIC AND API

--- Generates a unique ID for database persistence
---@return string
function InlineAI:generate_session_id()
  return "inline_ai_" .. tostring(os.time()) .. "_" .. math.random(1000, 9999)
end

---Triggered by user to fetch suggestions for the current line or visual selection
function InlineAI:get_suggestions_for_selection()
  local buf               = vim.api.nvim_get_current_buf()
  self.current_buf        = buf
  self.current_session_id = self:generate_session_id()

  local selection         = self:get_current_selection()
  if not selection or selection == "" then
    vim.notify("No text selected for AI suggestions", vim.log.levels.WARN)
    return
  end

  vim.notify("Getting AI suggestions...", vim.log.levels.INFO)

  -- Record activity to Rust backend
  api.record_activity(self.current_session_id, "get_suggestions",
    vim.fn.json_encode({ filetype = vim.bo.filetype, lines = vim.fn.line('$') }))

  api.generate_with_session(selection, self.current_session_id, "ollama", "codellama",
    function(response)
      self:process_ai_response(selection, response)
    end)
end

--- Extracts text from the buffer based on current mode
---@return string|nil
function InlineAI:get_current_selection()
  local mode = vim.fn.mode()
  if mode:match("[vV\22]") then
    local start_pos = vim.fn.getpos("'<")
    local end_pos   = vim.fn.getpos("'>")
    local lines     = vim.api.nvim_buf_get_lines(self.current_buf, start_pos[2] - 1, end_pos[2], false)

    if #lines > 0 then
      if mode == "V" then
        return table.concat(lines, "\n")
      else
        local first = lines[1]
        local last  = lines[#lines]
        if #lines == 1 then
          return string.sub(first, start_pos[3], end_pos[3])
        end
        lines[1]      = string.sub(first, start_pos[3])
        lines[#lines] = string.sub(last, 1, end_pos[3])
        return table.concat(lines, "\n")
      end
    end
  end
  return vim.fn.getline('.')
end

--- Orchestrates the conversion of raw AI response to UI suggestions
---@param original_text string
---@param ai_response string
function InlineAI:process_ai_response(original_text, ai_response)
  if not ai_response or ai_response == "" then
    vim.notify("No AI response received", vim.log.levels.ERROR)
    return
  end

  local suggestions = self:parse_ai_response(original_text, ai_response)
  if not suggestions or vim.tbl_isempty(suggestions) then
    vim.notify("No code suggestions found", vim.log.levels.WARN)
    return
  end

  self:show_suggestions(suggestions)
end

---Parses response into structured data
---@param original_text string
---@param ai_response string
---@return table<integer, AISuggestion>
function InlineAI:parse_ai_response(original_text, ai_response)
  local suggestions         = {}
  local current_line        = vim.fn.line('.')

  suggestions[current_line] = {
    line_num       = current_line,
    original_lines = vim.split(original_text, '\n'),
    ai_lines       = vim.split(ai_response, '\n'),
    type           = 'modification',
    session_id     = self.current_session_id
  }
  return suggestions
end

--- RENDERING & VIRTUAL TEXT

--- Renders suggestions into the buffer
---@param suggestions_map table<integer, AISuggestion>
function InlineAI:show_suggestions(suggestions_map)
  self:clear_all_suggestions()
  self.suggestions = suggestions_map
  self.current_buf = self.current_buf or vim.api.nvim_get_current_buf()

  for line_num, suggestion in pairs(suggestions_map) do
    self:display_suggestion(line_num, suggestion)
  end

  self:setup_keybinds()
  self:goto_first_suggestion()
end

--- Displays virtual text and background highlights for a suggestion
---@param line_num integer
---@param suggestion AISuggestion
function InlineAI:display_suggestion(line_num, suggestion)
  -- Highlight the original code with a "strikethrough" effect
  vim.api.nvim_buf_add_highlight(
    self.current_buf, self.ns, "AIOriginal", line_num - 1, 0, -1
  )

  -- Render the new code as virtual text lines
  for i, ai_line in ipairs(suggestion.ai_lines) do
    local display_line = line_num + i - 2 -- Adjusting for 0-index
    vim.api.nvim_buf_set_extmark(self.current_buf, self.ns, line_num - 1, 0, {
      virt_lines = { { { "➤ " .. ai_line, "AISuggestion" } } },
      virt_lines_above = false
    })
  end

  suggestion.display_start = line_num
  suggestion.display_end = line_num + #suggestion.ai_lines - 1
end

--- Inline AI Keybinding
---@note(waks-work): This keybinds may change and may need to be updated
---so as to meet our requirements and the specific keymap rules we will follow.
---will be done more on init.lua file.
function InlineaAI:setup_keybinds()
  local opts = { noremap = true, silent = true, buffer = self.current_buf }

  vim.keymap.set('n', '<Leader>aa', function() self:accept_current() end, opts)
  vim.keymap.set('n', '<Leader>rr', function() self:reject_current() end, opts)
  vim.keymap.set('n', ']a', function() self:next_suggestion() end, opts)
  vim.keymap.set('n', '[a', function() self:prev_suggestion() end, opts)
end

--- Applies the AI suggestion to the buffer and logs to DB
function InlineAI:accept_current()
  local line = vim.fn.line('.')
  local suggestion = self:find_suggestion_at_line(line)

  if not suggestion then return end

  local file_name = vim.fn.expand('%:t')

  -- PERSIST TO RUST BACKEND
  api.record_code_change(
    suggestion.session_id,
    file_name,
    table.concat(suggestion.original_lines, '\n'),
    table.concat(suggestion.ai_lines, '\n'),
    "AI suggestion accepted"
  )

  -- APPLY BUFFER CHANGE
  vim.api.nvim_buf_set_lines(
    self.current_buf,
    suggestion.line_num - 1,
    suggestion.line_num - 1 + #suggestion.original_lines,
    true,
    suggestion.ai_lines
  )

  self:clear_suggestion(suggestion.line_num)
  vim.notify("AI Change Applied & Recorded", vim.log.levels.INFO)
end

---Clears a suggestion from UI and logic
---@param line_num integer
function InlineAI:clear_suggestion(line_num)
  if self.suggestions[line_num] then
    vim.api.nvim_buf_clear_namespace(self.current_buf, self.ns, 0, -1)
    self.suggestions[line_num] = nil
  end
end

function InlineAI:clear_all_suggestions()
  if self.current_buf then
    vim.api.nvim_buf_clear_namespace(self.current_buf, self.ns, 0, -1)
  end
  self.suggestions = {}
end

--- Rejects the current suggestions provided by the ai.
function InlineAI:reject_current()
  local line       = vim.fn.line('.')
  local suggestion = self:find_suggestion_at_line(line)

  if suggestion then
    -- Record rejection activity
    api.record_activity(suggestion.session_id, "reject_suggestion",
      vim.fn.json_encode({ line = suggestion.line_num, file = vim.fn.expand('%:t') }))

    self:clear_suggestion(suggestion.line_num)
    vim.notify("AI suggestion rejected", vim.log.levels.INFO)
  end
end

--- Locates a suggestion object based on cursor line
---@param line integer
---@return AISuggestion|nil
function InlineAI:find_suggestion_at_line(line)
  for _, suggestion in pairs(self.suggestions) do
    if line >= suggestion.display_start and line <= suggestion.display_end then
      return suggestion
    end
  end
  return nil
end

function InlineAI:next_suggestion()
  local current_line = vim.fn.line('.')
  local next_line    = nil

  for line_num, _ in pairs(self.suggestions) do
    if line_num > current_line and (next_line == nil or line_num < next_line) then
      next_line = line_num
    end
  end

  if next_line then
    vim.api.nvim_win_set_cursor(0, { next_line, 0 })
  end
end

function InlineAI:prev_suggestion()
  local current_line = vim.fn.line('.')
  local prev_line = nil

  for line_num, _ in pairs(self.suggestions) do
    if line_num < current_line and (prev_line == nil or line_num > prev_line) then
      prev_line = line_num
    end
  end

  if prev_line then
    vim.api.nvim_win_set_cursor(0, { prev_line, 0 })
  end
end

function InlineAI:goto_first_suggestion()
  local first_line = nil
  for line_num, _ in pairs(self.suggestions) do
    if first_line == nil or line_num < first_line then
      first_line = line_num
    end
  end
  if first_line then
    vim.api.nvim_win_set_cursor(0, { first_line, 0 })
  end
end

-- Initialize and Set Up Global Keybindings
InlineAI:init()

return InlineAI
