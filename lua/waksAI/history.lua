local M = {}
local uv = vim.loop

local function project_root()
  -- prefer git root, else cwd
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  if git_root and git_root ~= "" and vim.fn.isdirectory(git_root) == 1 then
    return git_root
  end
  return vim.loop.cwd()
end

local function ensure_dir(p)
  if vim.fn.isdirectory(p) == 0 then
    vim.fn.mkdir(p, "p")
  end
end

local function backups_dir()
  local root = project_root()
  local d = root .. "/.wakshistory/backups"
  ensure_dir(d)
  return d
end

local function log_file_path()
  local root = project_root()
  ensure_dir(root .. "/.wakshistory")
  return root .. "/.wakshistory/log.txt"
end

-- Save backup of current file and write metadata to log
-- filepath: absolute or relative path to file
-- desc: short description
-- ai_output: raw AI response text (optional)
function M.log_change(filepath, desc, ai_output)
  local abs = vim.fn.fnamemodify(filepath, ":p")
  if vim.fn.filereadable(abs) == 0 then
    -- if file doesn't exist on disk, still log with nil backup
    local f = io.open(log_file_path(), "a")
    if f then
      f:write(os.date("%Y-%m-%d %H:%M:%S") .. " | " .. tostring(desc) .. " | " .. tostring(abs) .. " | NO_BACKUP\n")
      if ai_output then
        f:write("AI_OUTPUT_START\n" .. ai_output .. "\nAI_OUTPUT_END\n")
      end
      f:close()
    end
    return
  end

  local ts = os.time()
  local bdir = backups_dir()
  local bname = string.format("%d_%s", ts, vim.fn.fnamemodify(abs, ":t"))
  local backup_path = bdir .. "/" .. bname

  -- read current file contents
  local ok, content = pcall(function() return vim.fn.readfile(abs) end)
  if ok and content then
    vim.fn.writefile(content, backup_path)
  end

  -- append metadata log
  local f = io.open(log_file_path(), "a")
  if f then
    f:write(string.format("%s | %s | %s | %s\n", os.date("%Y-%m-%d %H:%M:%S"), tostring(desc), tostring(abs), backup_path))
    if ai_output then
      f:write("AI_OUTPUT_START\n" .. tostring(ai_output) .. "\nAI_OUTPUT_END\n")
    end
    f:close()
  end
end

-- show last N lines of log (quick tail)
function M.tail(n)
  n = n or 2000
  local p = log_file_path()
  if vim.fn.filereadable(p) == 0 then return "" end
  local f = io.open(p, "r")
  local all = f:read("*a")
  f:close()
  if #all <= n then return all end
  return all:sub(-n)
end

-- Undo last change: takes last log entry and restores the backup file.
-- WARNING: this is destructive — it overwrites the current file with the backup.
function M.undo_last()
  local p = log_file_path()
  if vim.fn.filereadable(p) == 0 then
    vim.notify("No wakshistory log present.", vim.log.levels.WARN)
    return
  end
  local lines = vim.fn.readfile(p)
  if #lines == 0 then
    vim.notify("wakshistory log is empty.", vim.log.levels.WARN)
    return
  end

  -- find last non-empty log line that includes a backup path
  local last_line
  for i = #lines, 1, -1 do
    if lines[i] and lines[i] ~= "" then
      last_line = lines[i]
      break
    end
  end
  if not last_line then
    vim.notify("No valid history entry found.", vim.log.levels.WARN)
    return
  end

  -- log format: TIMESTAMP | DESC | FILE | BACKUP_PATH
  local parts = vim.split(last_line, " | ")
  if #parts < 4 then
    vim.notify("Malformed wakshistory entry: " .. last_line, vim.log.levels.ERROR)
    return
  end
  local backup = parts[4]
  local orig = parts[3]

  if vim.fn.filereadable(backup) == 0 then
    vim.notify("Backup not found: " .. backup, vim.log.levels.ERROR)
    return
  end

  -- read backup and write to original file
  local content = vim.fn.readfile(backup)
  vim.fn.writefile(content, orig)
  vim.notify("Restored " .. orig .. " from " .. backup, vim.log.levels.INFO)
end

-- helper command to open history log quickly
function M.open_log()
  local p = log_file_path()
  vim.cmd("tabnew " .. p)
end

return M
