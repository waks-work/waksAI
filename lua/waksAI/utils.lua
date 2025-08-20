local M = {}

-- wrap words to width
function M.wrap(text, width)
  local out, line = {}, ""
  for word in text:gmatch("%S+") do
    if #line + #word + 1 > width then
      table.insert(out, line)
      line = word
    else
      line = (#line == 0) and word or (line .. " " .. word)
    end
  end
  if #line > 0 then table.insert(out, line) end
  return out
end

-- UI sizes
function M.chat_width()
  local w = math.floor(vim.o.columns * 0.5)
  if w < 40 then w = 40 end
  if w > 80 then w = 80 end
  return w
end

function M.chat_height()
  local h = math.floor(vim.o.lines * 0.7)
  if h < 12 then h = 12 end
  if h > 40 then h = 40 end
  return h
end

-- JSON escape for curl -d
function M.escape_json(str)
  str = str:gsub('\\','\\\\')
  str = str:gsub('"','\\"')
  str = str:gsub('\n','\\n')
  return str
end

-- Reduce huge comments
function M.trim_comments(code)
  -- long single-line comments (C/JS/TS style)
  code = code:gsub("//[^\n][^\n][^\n][^\n][^\n][^\n][^\n][^\n][^\n][^\n][^\n][^\n][^\n][^\n][^\n][^\n][^\n][^\n]+", "// …")
  -- block comments
  code = code:gsub("/%*.-%*/", "/* … */")
  -- python/hash long comments
  code = code:gsub("#[%s%p%w][^\n][^\n][^\n][^\n][^\n][^\n][^\n][^\n]+", "# …")
  return code
end

-- Extract fenced code blocks: returns { {lang="lua", code="..."}, ... }
function M.extract_code_blocks(s)
  local blocks = {}
  -- ```lang\n...\n```
  for lang, body in s:gmatch("```(%w+)%s*(.-)\n```") do
    table.insert(blocks, { lang = lang, code = body })
  end
  -- bare code fences too
  for body in s:gmatch("```%s*(.-)\n```") do
    table.insert(blocks, { lang = "", code = body })
  end
  return blocks
end

return M



