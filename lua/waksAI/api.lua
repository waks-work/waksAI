local M        = {}

local state    = require("waksAI.state")
local util     = require("waksAI.utils")
local ui       = require("waksAI.ui")
local context  = require("waksAI.context")
local history  = require("waksAI.history")
local edit     = require("waksAI.edit")

-- Base endpoint (can swap Ollama/DeepSeek/OpenAI/etc.)
local endpoint = state.config.endpoint

-- Send full request (non-streaming)
function M.send(prompt, on_done)
  -- Build context BEFORE adding to state so state.messages contains the new user turn later
  local ctx = context.build_request_context(prompt)

  -- Construct messages: system/context first, then user prompt (with snippet if present)
  local messages = {}

  -- System metadata
  local sys_parts = {}
  table.insert(sys_parts, "waksAI plugin local metadata:")
  table.insert(sys_parts, "File: " .. (ctx.meta.file or "unknown"))
  table.insert(sys_parts, "Cursor line: " .. (ctx.meta.line or "?"))
  if ctx.kind then table.insert(sys_parts, "Context kind: " .. tostring(ctx.kind)) end

  -- Brief project matches
  if ctx.project and #ctx.project > 0 then
    table.insert(sys_parts, "Project snippets:")
    for _, s in ipairs(ctx.project) do
      table.insert(sys_parts, string.format("- %s:%d -> %s", s.path, s.line, (s.excerpt or ""):sub(1, 80)))
    end
  end

  table.insert(messages, { role = "system", content = table.concat(sys_parts, "\n") })

  -- If there's a snippet, attach as a trimmed user assistant context block to minimize tokens
  if ctx.snippet and #ctx.snippet > 0 then
    local snippet = ctx.snippet
    if state.config.comment_trim then
      snippet = util.trim_comments(snippet)
    end
    -- Cap snippet length to avoid huge payloads (e.g., 3000 chars)
    if #snippet > 3000 then snippet = snippet:sub(1, 3000) .. "\n\n// ...trimmed..." end
    table.insert(messages,
      { role = "system", content = "RELEVANT_SNIPPET_START\n" .. snippet .. "\nRELEVANT_SNIPPET_END" })
  end

  -- Add the user prompt itself
  table.insert(messages, { role = "user", content = prompt })

  -- Add the new user message into state for local history (keeps UI display consistent)
  state.add("user", prompt)

  local payload = vim.fn.json_encode({
    session_id = "default",
    model = state.current_model(),
    messages = messages,
    stream = false,
  })

  -- POST to endpoint
  vim.fn.jobstart({
    "curl", "-s",
    "-X", "POST", endpoint,
    "-H", "Content-Type: application/json",
    "-d", payload,
  }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local joined = table.concat(data, "")
      if joined ~= "" then
        local ok, resp = pcall(vim.fn.json_decode, joined)
        if ok and resp and resp.response then
          local ai_text = resp.response
          state.add("ai", ai_text)

          -- wrap lines
          local win_width = vim.api.nvim_win_get_width(0)
          local wrapped = util.wrap(ai_text, win_width)
          local wrapped_text = table.concat(wrapped, "\n")

          -- try to extract code blocks
          local blocks = util.extract_code_blocks(ai_text)

          -- render in UI
          if on_done then on_done(wrapped_text, blocks) end

          -- If the response contains a full-file replacement or diff marker, we can handle it:
          -- Basic heuristic: if response contains "### PATCH" or unified diff markers, offer apply
          if ai_text:match("^%-%-%-") or ai_text:match("^@@") or ai_text:match("```diff") then
            -- For now, present diff and allow user to apply
            -- We assume the AI returned the new file content between ``` or full file text.
            -- Very naive: if there's a fenced code block, use first one as new content
            local first_block = blocks and blocks[1] and blocks[1].code
            if first_block and #first_block > 0 then
              -- Show diff and prompt to apply
              local bufnr = vim.fn.bufnr(ctx.meta.file)
              if bufnr == -1 then bufnr = vim.api.nvim_get_current_buf() end
              edit.show_diff_and_apply(bufnr, first_block, function()
                history.log_change(ctx.meta.file, "Applied AI patch", ai_text)
                vim.notify("Applied AI patch to " .. (ctx.meta.file or "buffer"), vim.log.levels.INFO)
              end)
            end
          end
        else
          vim.notify("API: invalid response", vim.log.levels.ERROR)
        end
      end
    end,
    on_stderr = function(_, err)
      if err and #err > 0 then
        vim.notify("API stderr: " .. table.concat(err, "\n"), vim.log.levels.WARN)
      end
    end,
    on_exit = function()
      -- no-op
    end,
  })
end

-- Stream request (for typing effect)
function M.stream(prompt, on_chunk, on_done)
  state.add("user", prompt)

  local payload = vim.fn.json_encode({
    session_id = "default",
    model = state.current_model(),
    messages = state.messages,
    stream = true,
  })

  local stream_endpoint = "http://localhost:11500/stream"
  vim.fn.jobstart({
    "curl", "-N", "-s",
    "-X", "POST", stream_endpoint,
    "-H", "Content-Type: application/json",
    "-d", payload,
  }, {
    stdout_buffered = false,
    on_stdout = function(_, data)
      for _, chunk in ipairs(data) do
        if chunk ~= "" then
          state.add("ai", chunk)
          if on_chunk then on_chunk(chunk) end
        end
      end
    end,
    on_exit = function()
      if on_done then on_done() end
    end,
  })
end

return M
