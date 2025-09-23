local M = {}

-- wrap words to width
function M.wrap(text, width)
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

return M
