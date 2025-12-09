-- inline_ai.lua
local InlineAI = {}
InlineAI.ns = vim.api.nvim_create_namespace('inline_ai')
InlineAI.suggestions = {}
InlineAI.current_buf = nil
InlineAI.current_session_id = nil

local api = require('waksAI.api')

function InlineAI:setup_highlights()
  vim.cmd('highlight AISuggestion guifg=#4EC9B0 guibg=#1e3a28 gui=italic')
  vim.cmd('highlight AIOriginal guifg=#F48771 guibg=#3a1e1e gui=strikethrough')
  vim.cmd('highlight AICurrent guibg=#2d4a3a')
end

function InlineAI:init()
  self:setup_highlights()
  self.current_buf = nil
  self.current_session_id = "inline_ai_" .. tostring(os.time())
end

function InlineAI:generate_session_id()
  return "inline_ai_" .. tostring(os.time()) .. "_" .. math.random(1000, 9999)
end

function InlineAI:get_suggestions_for_selection()
  local buf = vim.api.nvim_get_current_buf()
  self.current_buf = buf

  -- Generate a new session ID for this request
  self.current_session_id = self:generate_session_id()

  local selection = self:get_current_selection()
  if not selection or selection == "" then
    vim.notify("No text selected for AI suggestions", vim.log.levels.WARN)
    return
  end

  vim.notify("Getting AI suggestions...", vim.log.levels.INFO)

  -- Record the activity in your database
  api.record_activity(self.current_session_id, "get_suggestions",
    vim.fn.json_encode({ filetype = vim.bo.filetype, lines = vim.fn.line('$') }))

  -- Use session-based generation for proper database tracking
  api.generate_with_session(selection, self.current_session_id, "ollama", "codellama",
    function(response)
      self:process_ai_response(selection, response)
    end)
end

function InlineAI:get_current_selection()
  local mode = vim.fn.mode()

  if mode == "v" or mode == "V" or mode == "" then
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local lines = vim.api.nvim_buf_get_lines(
      self.current_buf,
      start_pos[2] - 1,
      end_pos[2],
      false
    )

    if #lines > 0 then
      if mode == "V" then
        return table.concat(lines, "\n")
      else
        local first_line = lines[1]
        local last_line = lines[#lines]

        if #lines == 1 then
          return string.sub(first_line, start_pos[3], end_pos[3])
        else
          first_line = string.sub(first_line, start_pos[3], -1)
          last_line = string.sub(last_line, 1, end_pos[3])
          lines[1] = first_line
          lines[#lines] = last_line
          return table.concat(lines, "\n")
        end
      end
    end
  else
    local line = vim.fn.getline('.')
    return line
  end

  return nil
end

function InlineAI:process_ai_response(original_text, ai_response)
  if not ai_response or ai_response == "" then
    vim.notify("No AI response received", vim.log.levels.ERROR)
    return
  end

  local suggestions = self:parse_ai_response(original_text, ai_response)

  if not suggestions or vim.tbl_isempty(suggestions) then
    vim.notify("No code suggestions found in AI response", vim.log.levels.WARN)
    return
  end

  self:show_suggestions(suggestions)
end

function InlineAI:parse_ai_response(original_text, ai_response)
  local suggestions = {}

  local current_line = vim.fn.line('.')
  local original_lines = vim.split(original_text, '\n')

  suggestions[current_line] = {
    line_num = current_line,
    original_lines = original_lines,
    ai_lines = vim.split(ai_response, '\n'),
    type = 'modification',
    session_id = self.current_session_id
  }

  return suggestions
end

function InlineAI:show_suggestions(suggestions_map)
  self:clear_all_suggestions()

  self.suggestions = suggestions_map
  self.current_buf = self.current_buf or vim.api.nvim_get_current_buf()

  for line_num, suggestion in pairs(suggestions_map) do
    self:display_suggestion(line_num, suggestion)
  end

  self:setup_keybinds()
  self:goto_first_suggestion()

  vim.notify(string.format("Displaying %d AI suggestions", vim.tbl_count(suggestions_map)),
    vim.log.levels.INFO)
end

function InlineAI:display_suggestion(line_num, suggestion)
  vim.api.nvim_buf_add_highlight(
    self.current_buf, self.ns, "AIOriginal", line_num - 1, 0, -1
  )

  for i, ai_line in ipairs(suggestion.ai_lines) do
    local display_line = line_num + i - 1

    vim.api.nvim_buf_set_virtual_text(
      self.current_buf,
      self.ns,
      display_line,
      { { "➤ " .. ai_line, "AISuggestion" } },
      {}
    )
  end

  suggestion.display_start = line_num
  suggestion.display_end = line_num + #suggestion.ai_lines - 1
end

function InlineAI:setup_keybinds()
  local opts = { noremap = true, silent = true, buffer = self.current_buf }

  vim.keymap.set('n', '<Leader>aa', function() self:accept_current() end, opts)
  vim.keymap.set('n', '<Leader>rr', function() self:reject_current() end, opts)
  vim.keymap.set('n', ']a', function() self:next_suggestion() end, opts)
  vim.keymap.set('n', '[a', function() self:prev_suggestion() end, opts)
end

function InlineAI:accept_current()
  local line = vim.fn.line('.')
  local suggestion = self:find_suggestion_at_line(line)

  if not suggestion then
    vim.notify("No AI suggestion at current line", vim.log.levels.WARN)
    return
  end

  -- Record code change in database before applying
  local file_name = vim.fn.expand('%:t')
  api.record_code_change(
    suggestion.session_id,
    file_name,
    table.concat(suggestion.original_lines, '\n'),
    table.concat(suggestion.ai_lines, '\n'),
    "AI suggestion accepted"
  )

  -- Apply the change
  vim.api.nvim_buf_set_lines(
    self.current_buf,
    suggestion.line_num - 1,
    suggestion.line_num - 1 + #suggestion.original_lines,
    true,
    suggestion.ai_lines
  )

  -- Record acceptance activity
  api.record_activity(suggestion.session_id, "accept_suggestion",
    vim.fn.json_encode({ line = suggestion.line_num, file = file_name }))

  self:clear_suggestion(suggestion.line_num)
  vim.notify("AI suggestion accepted", vim.log.levels.INFO)
end

function InlineAI:reject_current()
  local line = vim.fn.line('.')
  local suggestion = self:find_suggestion_at_line(line)

  if suggestion then
    -- Record rejection activity
    api.record_activity(suggestion.session_id, "reject_suggestion",
      vim.fn.json_encode({ line = suggestion.line_num, file = vim.fn.expand('%:t') }))

    self:clear_suggestion(suggestion.line_num)
    vim.notify("AI suggestion rejected", vim.log.levels.INFO)
  end
end

function InlineAI:find_suggestion_at_line(line)
  for line_num, suggestion in pairs(self.suggestions) do
    if line >= suggestion.display_start and line <= suggestion.display_end then
      return suggestion
    end
  end
  return nil
end

function InlineAI:next_suggestion()
  local current_line = vim.fn.line('.')
  local next_line = nil

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

function InlineAI:clear_suggestion(line_num)
  if self.suggestions[line_num] then
    local suggestion = self.suggestions[line_num]

    for i = suggestion.display_start, suggestion.display_end do
      vim.api.nvim_buf_clear_namespace(self.current_buf, self.ns, i - 1, i)
    end

    self.suggestions[line_num] = nil
  end
end

function InlineAI:clear_all_suggestions()
  if self.current_buf then
    vim.api.nvim_buf_clear_namespace(self.current_buf, self.ns, 0, -1)
  end
  self.suggestions = {}
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

vim.keymap.set('n', '<Leader>ai', function()
  InlineAI:get_suggestions_for_selection()
end, { desc = "Get AI suggestions for selection" })

vim.keymap.set('v', '<Leader>ai', function()
  InlineAI:get_suggestions_for_selection()
end, { desc = "Get AI suggestions for selection" })

vim.api.nvim_create_user_command('AISuggest', function()
  InlineAI:get_suggestions_for_selection()
end, { desc = "Get AI code suggestions" })

return InlineAI
