local M = {}

-- Return basic file + cursor info
function M.get_current_context()
  local file = vim.fn.expand("%:p")
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  return {
    file = file,
    line = row,
    col = col,
  }
end

-- If user visually selects code, return string; works for v and V
function M.get_selected_code()
  local mode = vim.fn.mode()
  if not (mode == "v" or mode == "V" or mode == "\22") then
    return nil
  end
  local s = vim.fn.getpos("'<")
  local e = vim.fn.getpos("'>")
  local sr, sc = s[2], s[3]
  local er, ec = e[2], e[3]
  if not (sr and er) then return nil end

  local lines = vim.api.nvim_buf_get_lines(0, sr - 1, er, false)
  if #lines == 0 then return nil end

  lines[1] = string.sub(lines[1], sc)
  lines[#lines] = string.sub(lines[#lines], 1, ec)
  return table.concat(lines, "\n")
end

-- Heuristic: return the surrounding function/block for the cursor.
-- Tries treesitter first, falls back to simple regex scanning.
function M.get_surrounding_function()
  -- Try Treesitter node traversal (if available)
  local has_ts, ts = pcall(require, "nvim-treesitter.ts_utils")
  if has_ts then
    local node = ts.get_node_at_cursor()
    while node do
      local type_name = node:type()
      if type_name:match("function") or type_name:match("method") or type_name:match("function_declaration") or type_name:match("function_definition") or type_name:match("method_definition") then
        local sr, sc, er, ec = node:range()
        local lines = vim.api.nvim_buf_get_lines(0, sr, er + 1, false)
        return table.concat(lines, "\n")
      end
      node = node:parent()
    end
  end

  -- Fallback: find nearest "function" / "def" / "{"
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local buflines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Scan upward for function start
  local start = 1
  for i = row, 1, -1 do
    local l = buflines[i] or ""
    if l:match("^%s*function%s+") or l:match("^%s*def%s+") or l:match("^%s*fn%s+") or l:match("%b{}%s*$") or l:match("^%s*[%w_]+%s*%b()") then
      start = i
      break
    end
  end

  -- Scan downward for function end (blank line or next function)
  local finish = #buflines
  for i = row, #buflines do
    local l = buflines[i] or ""
    if l:match("^%s*end%s*$") or l:match("^%s*$") and i > row + 5 then
      finish = i
      break
    end
    -- stop if next function begins
    if i > row and (l:match("^%s*function%s+") or l:match("^%s*def%s+")) then
      finish = i - 1
      break
    end
  end

  local lines = vim.api.nvim_buf_get_lines(0, start - 1, finish, false)
  return table.concat(lines, "\n")
end

-- Search project for relevant snippets using ripgrep (fast). Returns table of {path, line, excerpt}
-- If ripgrep (rg) not available, returns empty list.
function M.get_project_snippets(query, max_results)
  max_results = max_results or 5
  local snippets = {}
  if vim.fn.executable("rg") == 0 then return snippets end

  -- sanitize basic single quote by escaping
  local safe_q = query:gsub("'", "'\\''")
  local cmd = string.format("rg --no-heading --line-number -S -n -g '!.git' -g '!node_modules' -e '%s' -m %d", safe_q,
    max_results)
  local handle = io.popen(cmd)
  if not handle then return snippets end
  local out = handle:read("*a")
  handle:close()
  for line in out:gmatch("[^\n]+") do
    -- format: path:lineno:content
    local path, lineno, content = line:match("([^:]+):(%d+):(.*)")
    if path and lineno and content then
      table.insert(snippets, { path = path, line = tonumber(lineno), excerpt = content })
    end
  end
  return snippets
end

-- Build a trimmed context payload to send with a request.
-- Strategy:
-- 1. If there is a visual selection -> send only selection + metadata
-- 2. Else: include current function (or surrounding chunk) + 5 lines of context above/below
-- 3. Optionally attach 1-2 project snippets (grep) matching the user's prompt/keywords
function M.build_request_context(user_prompt)
  local ctx = {}
  local sel = M.get_selected_code()
  local meta = M.get_current_context()
  ctx.meta = meta

  if sel and sel:match("%S") then
    ctx.kind = "selection"
    ctx.snippet = sel
    return ctx
  end

  local fn_code = M.get_surrounding_function()
  if fn_code and #fn_code > 50 then
    ctx.kind = "function"
    ctx.snippet = fn_code
    return ctx
  end

  -- fallback: send the current buffer around cursor (20 lines window)
  local row = meta.line
  local buflines = vim.api.nvim_buf_get_lines(0, math.max(0, row - 11),
    math.min(vim.api.nvim_buf_line_count(0), row + 10), false)
  ctx.kind = "window"
  ctx.snippet = table.concat(buflines, "\n")

  -- If user prompt contains likely identifiers, add a few project matches
  local kws = user_prompt:match("%w+")
  if kws then
    ctx.project = M.get_project_snippets(kws, 3)
  end

  return ctx
end

return M
