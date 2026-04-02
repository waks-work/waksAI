local state = require("waksAI.state")
local ui = require("waksAI.ui")
local bridge = require("waksAI.bridge")

describe("Backend parser spec", function()
    it("should close the timer when the sidebar buffer is deleted", function()
        ui.open_chat()
        ui.render_thinking_sidebar()
        local timer = state.thinking_timer

        vim.api.nvim_buf_delete(ui.sidebar_buf, { force = true })
        vim.wait(ui.config.thinking_speed + 10, function()
            return timer:is_closing()
        end)

        assert.is_true(timer:is_closing(), "Timer leaked after buffer deletion!")
    end)
end)
