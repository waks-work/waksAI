local M        = {}
local state    = require("waksAI.state")
local util     = require("waksAI.utils")
local ui       = require("waksAI.ui")

-- Base endpoint (can swap Ollama/DeepSeek/OpenAI/etc.)
local endpoint = state.config.endpoint

-- Send full request (non-streaming)
function M.send(prompt, on_done)
  state.add("user", prompt)

  -- Preprocess if needed
  if state.config.comment_trim then
    prompt = util.trim_comments(prompt)
  end

  local payload = vim.fn.json_encode({
    session_id = "default",
    model = state.current_model(),
    messages = state.messages,
    stream = false,
  })

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
          state.add("ai", resp.response)

          -- Extract any code blocks
          local blocks = util.extract_code_blocks(resp.response)

          if on_done then
            on_done(resp.response, blocks)
          end
        end
      end
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

  vim.fn.jobstart({
    "curl", "-N", "-s",
    "-X", "POST", endpoint .. "/stream",
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
