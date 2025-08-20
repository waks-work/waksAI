local M = {}

local ui    = require("waksAI.ui")
local api   = require("waksAI.api")
local state = require("waksAI.state")

function M.setup(opts)
  state.setup(opts or {})
  ui.setup_highlights()
end

-- Open/toggle the chat UI
function M.open()
  ui.ensure_chat_win()
end

-- Prompt and send
function M.prompt()
  ui.ensure_chat_win()
  ui.open_prompt(function(user_text)
    if not user_text or user_text == "" then return end
    ui.append_bubble("user", user_text)

    -- Send with conversation context (and comment minimization)
    api.send(user_text, function(ai_text, code_blocks)
      ui.append_bubble("ai", ai_text)
      if code_blocks and #code_blocks > 0 then
        for _, cb in ipairs(code_blocks) do
          ui.open_code_editor(cb.lang, cb.code)
        end
      end
    end)
  end)
end

-- Visual selection helper
function M.explain_visual()
  ui.ensure_chat_win()
  local _, ls, cs = unpack(vim.fn.getpos("'<"))
  local _, le, ce = unpack(vim.fn.getpos("'>"))
  local lines = vim.fn.getline(ls, le)
  if #lines == 0 then return end
  lines[#lines] = string.sub(lines[#lines], 1, ce)
  lines[1] = string.sub(lines[1], cs)
  local code = table.concat(lines, "\n")
  local prompt = "Explain this code:\n" .. code
  ui.append_bubble("user", prompt)
  api.send(prompt, function(ai_text, code_blocks)
    ui.append_bubble("ai", ai_text)
    if code_blocks and #code_blocks > 0 then
      for _, cb in ipairs(code_blocks) do
        ui.open_code_editor(cb.lang, cb.code)
      end
    end
  end)
end

-- Toggle model
function M.toggle_model()
  local next_model = state.cycle_model()
  ui.system_note("Model switched to " .. next_model)
end

-- Command for single-shot ask
vim.api.nvim_create_user_command("WaksAIAsk", function(opts)
  api.send(opts.args, function(reply)
    vim.notify("AI: " .. reply, vim.log.levels.INFO)
  end)
end, { nargs = "+" })

-- Command for streaming chat (optional)
vim.api.nvim_create_user_command("WaksAIChat", function()
  require("waksAI.ui").open_chat()
end, {})

-- Optional convenient keymaps
function M.keymaps()
  vim.keymap.set("n", "<leader>wa", M.open,   { desc = "waksAI: Open chat" })
  vim.keymap.set("n", "<leader>ws", M.prompt, { desc = "waksAI: Send prompt" })
  vim.keymap.set("v", "<leader>wv", M.explain_visual, { desc = "waksAI: Explain selection" })
  vim.keymap.set("n", "<leader>wm", M.toggle_model, { desc = "waksAI: Toggle model" })
end

return M



