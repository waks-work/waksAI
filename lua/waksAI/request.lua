local state = require("waksAI.state")
local json = vim.fn.json_encode and vim.fn.json_decode and vim.fn or require("dkjson")
local M = {}

-------------------------------------------------------
-- Send normal (non-streaming) AI request
-------------------------------------------------------
function M.send_message(payload, callback)
  if not payload or not payload.model or not payload.provider then
    vim.notify("request.send_message: missing model or provider", vim.log.levels.ERROR)
    return
  end

  local endpoint = string.format(
    "%s/api/ai?provider=%s&model=%s",
    state.config.endpoint or "http://127.0.0.1:11500",
    payload.provider,
    payload.model
  )

  vim.fn.jobstart({
    "curl", "-s",
    "-X", "POST", endpoint,
    "-H", "Content-Type: application/json",
    "-d", vim.fn.json_encode(payload),
  }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local output = table.concat(data, "")
      if output ~= "" then
        local ok, decoded = pcall(vim.fn.json_decode, output)
        if ok and decoded then
          if callback then callback(decoded) end
        else
          vim.notify("Invalid JSON response from backend", vim.log.levels.ERROR)
        end
      end
    end,
    on_stderr = function(_, err)
      if err and #err > 0 then
        vim.notify("Backend stderr: " .. table.concat(err, "\n"), vim.log.levels.WARN)
      end
    end,
  })
end

-------------------------------------------------------
-- Stream AI response (SSE or chunked)
-------------------------------------------------------
function M.stream_message(payload, on_chunk, on_done)
  if not payload or not payload.model or not payload.provider then
    vim.notify("request.stream_message: missing model or provider", vim.log.levels.ERROR)
    return
  end

  local stream_endpoint = string.format(
    "%s/api/ai/stream?provider=%s&model=%s",
    state.config.endpoint or "http://127.0.0.1:11500",
    payload.provider,
    payload.model
  )

  vim.fn.jobstart({
    "curl", "-N", "-s",
    "-X", "POST", stream_endpoint,
    "-H", "Content-Type: application/json",
    "-d", vim.fn.json_encode(payload),
  }, {
    stdout_buffered = false,
    on_stdout = function(_, data)
      for _, chunk in ipairs(data) do
        if chunk ~= "" and on_chunk then
          on_chunk(chunk)
        end
      end
    end,
    on_exit = function()
      if on_done then on_done() end
    end,
  })
end

return M
