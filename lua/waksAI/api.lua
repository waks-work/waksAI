local M       = {}

local state   = require("waksAI.state")
local request = require("waksAI.request")
local util    = require("waksAI.utils")
local ui      = require("waksAI.ui")
local context = require("waksAI.context")
local history = require("waksAI.history")
local edit    = require("waksAI.edit")

-------------------------------------------------------
-- Non-streaming AI request
-------------------------------------------------------
function M.send(prompt, on_done)
  local ctx = context.build_request_context(prompt)

  -------------------------------------------------------
  -- Build messages
  -------------------------------------------------------
  local messages = {}

  -- === System metadata ===
  local sys_parts = {
    "waksAI local metadata:",
    "File: " .. (ctx.meta.file or "unknown"),
    "Cursor line: " .. (ctx.meta.line or "?"),
  }

  if ctx.kind then table.insert(sys_parts, "Context kind: " .. tostring(ctx.kind)) end

  if ctx.project and #ctx.project > 0 then
    table.insert(sys_parts, "Project snippets:")
    for _, s in ipairs(ctx.project) do
      table.insert(sys_parts, string.format("- %s:%d -> %s", s.path, s.line, (s.excerpt or ""):sub(1, 80)))
    end
  end
  table.insert(messages, { role = "system", content = table.concat(sys_parts, "\n") })

  -- === Code context (snippet) ===
  if ctx.snippet and #ctx.snippet > 0 then
    local snippet = ctx.snippet
    if state.config.comment_trim then snippet = util.trim_comments(snippet) end
    if #snippet > 3000 then snippet = snippet:sub(1, 3000) .. "\n\n// ...trimmed..." end
    table.insert(messages, {
      role = "system",
      content = "RELEVANT_SNIPPET_START\n" .. snippet .. "\nRELEVANT_SNIPPET_END"
    })
  end

  -- === User message ===
  table.insert(messages, { role = "user", content = prompt })
  state.add("user", prompt)

  -------------------------------------------------------
  -- Build payload
  -------------------------------------------------------
  local payload = {
    session_id = "default",
    provider = state.config.provider, -- dynamic
    model = state.config.model,       -- dynamic model from state
    api_key = state.config.api_key,   -- from env if available
    messages = messages,
    stream = false,
  }

  -------------------------------------------------------
  -- Send request
  -------------------------------------------------------
  request.send_message(payload, function(resp)
    if not resp or not resp.response then
      vim.notify("API: Invalid response from backend", vim.log.levels.ERROR)
      return
    end

    local ai_text = resp.response
    state.add("ai", ai_text)

    -- Wrap and extract
    local win_width = vim.api.nvim_win_get_width(0)
    local wrapped_text = table.concat(util.wrap(ai_text, win_width), "\n")
    local blocks = util.extract_code_blocks(ai_text)

    if on_done then on_done(wrapped_text, blocks) end

    -------------------------------------------------------
    -- Handle possible diff/patch
    -------------------------------------------------------
    if ai_text:match("^%-%-%-") or ai_text:match("^@@") or ai_text:match("```diff") then
      local first_block = blocks and blocks[1] and blocks[1].code
      if first_block and #first_block > 0 then
        local bufnr = vim.fn.bufnr(ctx.meta.file)
        if bufnr == -1 then bufnr = vim.api.nvim_get_current_buf() end

        edit.show_diff_and_apply(bufnr, first_block, function()
          history.log_change(ctx.meta.file, "Applied AI patch", ai_text)
          vim.notify("Applied AI patch to " .. (ctx.meta.file or "buffer"), vim.log.levels.INFO)
        end)
      end
    end
  end)
end

-------------------------------------------------------
-- Streaming AI request
-------------------------------------------------------
function M.stream(prompt, on_chunk, on_done)
  state.add("user", prompt)

  local payload = {
    session_id = "default",
    provider = state.config.provider,
    model = state.config.model,
    api_key = state.config.api_key,
    messages = state.messages,
    stream = true,
  }

  request.stream_message(payload, on_chunk, on_done)
end

return M
