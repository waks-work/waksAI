--- @note(waks-work): we require all the modules to be used when we conduct this tests.
local ui = require("waksAI.ui")
local state = require("waksAI.state")
local bridge = require("waksAI.bridge")

--- We use 'describe' to group related tests together.
describe("AI Overlay", function()
    --- 'before_each' runs before every 'it' block.
    --- It ensures a clean environment (fresh buffer)
    before_each(function()
        vim.api.nvim_command("enew!")
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "line one", "line two", "line three" })
    end)

    --- 'it' defines each single test case.
    it("should render virtual text correctly at the cursor position", function()
        bridge.set_cursor_position(0, { 2, 0 })

        local target_line = 1
        local sample_text = "prin('hello world')"
        ui.render_ai_inline(sample_text, target_line)

        local ns = bridge.get_namespace_id("waksai_inline")
        local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })

        assert.is_not_nil(marks)
        assert.is_true(#marks > 0, "No extmarks found in waksai_inline namespace")
        local mark_row = marks[1][2]
        assert.are.equal(target_line, mark_row)

        local virt_text = marks[1][4].virt_lines[1][1][1]
        assert.is_true(virt_text:find(sample_text) ~= nil, "Ghost text content mismatch")
    end)

    it("should clear the state and overlay when dismissed", function()
        ui.render_ai_inline("to be deleted", 0)
        ui.clear_overlay()

        local ns = bridge.get_namespace_id("waksai_inline")
        local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
        assert.are.equal(0, #marks, "Overlay was not cleared properly")
    end)
end)

describe("Async spec", function()
    it("should close the timer when the sidebar buffer is deleted", function()
        ui.open_chat()
        ui.render_thinking_sidebar()
        local timer = state.thinking_timer

        vim.api.nvim_buf_delete(ui.sidebar_buf, { force = true })
        vim.wait(ui.config.thinking_speed + 10, function() return timer:is_closing() end)
        assert.is_true(timer:is_closing(), "Timer leaked after buffer deletion!")
    end)
end)

describe("Focus spec", function()
    it("should not steal focus from the main editor window when updating sidebar", function()
        local main_win = vim.api.nvim_get_current_win()
        ui.open_chat()

        vim.api.nvim_set_current_win(main_win)
        ui.render_ai_sidebar("New AI message", {})

        local current_win = vim.api.nvim_get_current_win()
        assert.are.equal(main_win, current_win, "Focus was stolen by the sidebar update!")
    end)
end)
