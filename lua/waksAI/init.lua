-- Updated init.lua integration
local M = {}
local config = require("waksAI.config")
local ui = require("waksAI.ui")
local api = require("waksAI.api")
local state = require("waksAI.state")
local utils = require("waksAI.utils")
local picker = require("waksAI.picker")

function M.setup(opts)
  state.setup(opts or {})

  -- Setup UI with web-inspired theme
  ui.setup({
    width = 70,
    position = "right",
    show_timestamps = true,
    show_session_info = true,
    theme = {
      background = "#1e1e2e",
      foreground = "#cdd6f4",
      accent = "#89b4fa",
      secondary = "#7f849c",
      success = "#a6e3a1",
      warning = "#f9e2af",
      error = "#f38ba8",
      code_bg = "#181825",
      border = "#313244",
    }
  })
end

-- Enhanced open function with full UI
--[[ function M.prompt()
  ui.open_chat()

  -- Start the input mode and get a callback function
  local get_input = ui.start_input_mode()

  -- Set up a watcher to check for input
  local function check_input()
    vim.defer_fn(function()
      local user_text = get_input()
      if user_text then
        -- We have input, process it
        ui.render_user(user_text)
        ui.render_thinking("Processing your request...")

        api.send(user_text, function(ai_text, code_blocks)
          ui.clear_loading()
          ui.render_ai(ai_text)

          if code_blocks and #code_blocks > 0 then
            for _, cb in ipairs(code_blocks) do
              ui.render_ai(cb.code, { is_code = true, lang = cb.lang })
            end
          end

          -- Update session history
          table.insert(state.session.history, { role = "user", content = user_text })
          table.insert(state.session.history, { role = "assistant", content = ai_text })

          -- Restart input mode for next message
          M.prompt()
        end)
      else
        -- No input or cancelled, just keep watching
        check_input()
      end
    end, 500) -- Check every 500ms
  end

  check_input()
end ]]

function M.prompt()
  ui.open_chat()
  vim.ui.input({ 
    prompt = "You: ",
    default = ""
  }, function(user_text)
    if not user_text or user_text == "" then return end
    
    ui.render_user(user_text)
    ui.render_thinking("Processing your request...")
    
    api.send(user_text, function(ai_text, code_blocks)
      ui.clear_loading()
      ui.render_ai(ai_text)
      
      if code_blocks and #code_blocks > 0 then
        for _, cb in ipairs(code_blocks) do
          ui.render_ai(cb.code, { is_code = true, lang = cb.lang })
        end
      end
      
      -- Update session history
      table.insert(state.session.history, { role = "user", content = user_text })
      table.insert(state.session.history, { role = "assistant", content = ai_text })
    end)
  end)
end


-- Enhanced visual selection with context
function M.explain_visual()
  ui.open_chat()

  local visual_text = utils.get_visual_selection()
  if not visual_text or visual_text == "" then
    ui.render_system("No text selected", "warning")
    return
  end

  local prompt = "Explain this code and suggest improvements:\n\n```\n" .. visual_text .. "\n```"

  ui.render_user("Explain the selected code")
  ui.render_thinking("Analyzing the code structure...")

  api.send(prompt, function(ai_text, code_blocks)
    ui.clear_loading()
    ui.render_ai(ai_text)

    if code_blocks and #code_blocks > 0 then
      for _, cb in ipairs(code_blocks) do
        ui.render_ai(cb.code, { is_code = true, lang = cb.lang })
      end
    end

    -- Update history
    table.insert(state.session.history, { role = "user", content = prompt })
    table.insert(state.session.history, { role = "assistant", content = ai_text })
  end)
end

-- Toggle model with notification
function M.toggle_model()
  local next_model = state.cycle_model()
  ui.render_system("Model switched to: " .. next_model, "success")
end

-- Render chat history
function M.render_history()
  for _, entry in ipairs(state.session.history) do
    if entry.role == "user" then
      ui.render_user(entry.content)
    else
      ui.render_ai(entry.content)
    end
  end
end

-- Clear chat history
function M.clear_history()
  state.session.history = {}
  ui.clear_chat()
  ui.render_system("Chat history cleared", "success")
end

-- Keymaps with better descriptions
function M.keymaps()
  vim.keymap.set("n", "<leader>wa", M.open, { desc = "WaksAI: Open chat window" })
  vim.keymap.set("n", "<leader>ws", M.prompt, { desc = "WaksAI: Send prompt" })
  vim.keymap.set("v", "<leader>wv", M.explain_visual, { desc = "WaksAI: Explain selection" })
  vim.keymap.set("n", "<leader>wm", M.toggle_model, { desc = "WaksAI: Toggle model" })
  vim.keymap.set("n", "<leader>wc", M.clear_history, { desc = "WaksAI: Clear history" })
  vim.keymap.set("n", "<leader>wp", picker.switch_provider, { desc = "WaksAI: Switch provider" })
  vim.keymap.set("n", "<leader>wM", picker.switch_model, { desc = "WaksAI: Switch model" })
  vim.keymap.set("n", "<leader>wr", picker.register_model, { desc = "WaksAI: Register model" })
end

-- Commands
vim.api.nvim_create_user_command("WaksAIAsk", function(opts)
  api.send(opts.args, function(reply)
    vim.notify("AI: " .. reply, vim.log.levels.INFO)
  end)
end, { nargs = "+" })

vim.api.nvim_create_user_command("WaksAIChat", function()
  M.open()
end, {})

vim.api.nvim_create_user_command("WaksAIClear", function()
  M.clear_history()
end, {})

return M
