-- utils.lua - Enhanced utilities for WaksAI
local M = {}

-- ===================================
-- # 📝 TEXT PROCESSING
-- ===================================

-- Wrap words to width
function M.wrap(text, width)
  width = width or 80
  local out, line = {}, ""
  for word in text:gmatch("%S+") do
    if #line + #word + 1 > width then
      table.insert(out, line .. "  ") -- markdown soft break
      line = word
    else
      line = (#line == 0) and word or (line .. " " .. word)
    end
  end
  if #line > 0 then table.insert(out, line) end
  return out
end

-- JSON escape for curl -d
function M.escape_json(str)
  return str
    :gsub("\\", "\\\\")
    :gsub('"', '\\"')
    :gsub("\n", "\\n")
    :gsub("\r", "\\r")
    :gsub("\t", "\\t")
end

-- Reduce huge comments
function M.trim_comments(code)
  code = code:gsub("//[^\n]+", function(c)
    return (#c > 40) and "// …" or c
  end)
  code = code:gsub("/%*.-%*/", "/* … */")
  code = code:gsub("#[^\n]+", function(c)
    return (#c > 40) and "# …" or c
  end)
  return code
end

-- Extract fenced code blocks: returns { {lang="lua", code="..."}, ... }
function M.extract_code_blocks(s)
  local blocks = {}
  for lang, body in s:gmatch("```(%w*)\n?(.-)```") do
    table.insert(blocks, { lang = lang or "", code = body })
  end
  return blocks
end

-- ===================================
-- # 🎨 UI UTILITIES
-- ===================================

-- Get visual selection text
function M.get_visual_selection()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" then
    return nil
  end
  
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]
  
  -- Adjust for 1-based vs 0-based indexing
  start_col = start_col - 1
  end_col = end_col
  
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  
  if #lines == 0 then
    return ""
  end
  
  -- Handle single line selection
  if #lines == 1 then
    return string.sub(lines[1], start_col + 1, end_col)
  end
  
  -- Handle multi-line selection
  local result = {}
  for i, line in ipairs(lines) do
    if i == 1 then
      table.insert(result, string.sub(line, start_col + 1))
    elseif i == #lines then
      table.insert(result, string.sub(line, 1, end_col))
    else
      table.insert(result, line)
    end
  end
  
  return table.concat(result, "\n")
end

-- Format provider name with icon
function M.format_provider(provider)
  local icons = {
    ollama = "🐋",
    openai = "⚡",
    anthropic = "🤖"
  }
  return string.format("%s %s", icons[provider] or "🔌", provider)
end

-- Format model name with provider context
function M.format_model(model, provider)
  local provider_icon = M.format_provider(provider)
  return string.format("%s %s", provider_icon, model)
end

-- Create status line component
function M.get_status_line()
  if not state or not state.session then
    return "WaksAI: Inactive"
  end
  
  local provider = state.session.provider or "?"
  local model = state.session.model or "?"
  local provider_icons = {
    ollama = "🐋",
    openai = "⚡", 
    anthropic = "🤖"
  }
  
  local icon = provider_icons[provider] or "🧠"
  return string.format("%s %s/%s", icon, provider, model)
end

-- ===================================
-- # 🔧 VALIDATION UTILITIES
-- ===================================

-- Validate model name format
function M.is_valid_model_name(name)
  return name and name:match("^[%w%-_%.]+$") ~= nil
end

-- Validate provider name format  
function M.is_valid_provider_name(name)
  return name and name:match("^[%w%-_]+$") ~= nil
end

-- Check if model exists in provider
function M.model_exists(provider, model)
  if not state.config.providers[provider] then
    return false
  end
  
  for _, m in ipairs(state.config.providers[provider]) do
    if m == model then
      return true
    end
  end
  
  return false
end

-- ===================================
--  # 📊 STATISTICS UTILITIES
-- ===================================

-- Count tokens in text (rough estimation)
function M.estimate_tokens(text)
  if not text then return 0 end
  -- Rough estimation: ~4 characters per token
  return math.ceil(#text / 4)
end

-- Get session statistics
function M.get_session_stats()
  if not state or not state.session then
    return { messages = 0, tokens = 0 }
  end
  
  local history = state.session.history or {}
  local total_tokens = 0
  
  for _, msg in ipairs(history) do
    total_tokens = total_tokens + M.estimate_tokens(msg.content)
  end
  
  return {
    messages = #history,
    tokens = total_tokens
  }
end

return M
