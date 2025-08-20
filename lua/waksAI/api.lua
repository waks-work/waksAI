local M = {}

-- Base URL (DeepSeek / Ollama / OpenAI compatible)
-- 👉 Adjust if you swap models
local base_url = "http://localhost:11434/v1/chat/completions"
local model = "deepseek-coder:1.3b"

-- === SSE Streaming ===
local function stream_request(prompt, on_chunk, on_complete)
  vim.fn.jobstart(
    {
      "curl",
      "-N", -- keep connection open
      "-s",
      "-X", "POST",
      base_url,
      "-H", "Content-Type: application/json",
      "-d", vim.fn.json_encode({
        model = model,
        stream = true,
        messages = {
          { role = "user", content = prompt }
        }
      }),
    },
    {
      stdout_buffered = false,
      on_stdout = function(_, data, _)
        for _, line in ipairs(data) do
          if line ~= "" and line:sub(1, 5) == "data:" then
            local ok, json = pcall(vim.fn.json_decode, line:sub(6))
            if ok and json.choices and json.choices[1].delta
              and json.choices[1].delta.content
            then
              on_chunk(json.choices[1].delta.content)
            end
          end
        end
      end,
      on_exit = function()
        if on_complete then on_complete() end
      end,
    }
  )
end

-- === Public API ===
function M.ask(prompt)
  -- Create a fresh buffer for the reply
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_set_current_buf(bufnr)

  local lines = {}
  stream_request(
    prompt,
    function(chunk)
      table.insert(lines, chunk)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { table.concat(lines) })
    end,
    function()
      table.insert(lines, "\n--- [done] ---")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { table.concat(lines) })
    end
  )
end

-- === Command Mapping ===
vim.api.nvim_create_user_command("WaksAIAsk", function(opts)
  M.ask(opts.args)
end, { nargs = "+" })

return M






