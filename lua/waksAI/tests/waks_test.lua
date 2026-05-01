local WaksTest = {
    tests_run = 0,
    tests_failed = 0,
    current_test_failed = false,
}

--- require("waks_test")
--- TEST("WaksAI Buffer Creation", function()
---    local buf = vim.api.nvim_create_buf(false, true)
---    ASSERT_EQ(vim.api.nvim_buf_is_valid(buf), true, "Buffer should be valid")
---    vim.api.nvim_buf_set_name(buf, "WaksAI_Test")
---    ASSERT_EQ(vim.api.nvim_buf_get_name(buf):match("WaksAI_Test") ~= nil, true)
--- end)
--- REPORT()
--- nvim --headless -c "luafile tests/ui_spec.lua" -c "qa"
function TEST(description, func)
    WaksTest.tests_run = WaksTest.tests_run + 1
    WaksTest.current_test_failed = false

    io.write(string.format("[RUN] %s...", description))

    -- Execute the test logic
    local ok, err = pcall(func)

    if not ok then
        WaksTest.tests_failed = WaksTest.tests_failed + 1
        WaksTest.current_test_failed = true
        print("\n  [FAIL] " .. tostring(err))
    else
        print(" OK")
    end
end

-- Custom Assertion
function ASSERT_EQ(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s (Actual: %s, Expected: %s)", msg or "Assertion Failed", tostring(actual),
            tostring(expected)))
    end
end

function REPORT()
    if WaksTest.tests_failed == 0 then
        print(string.format("SUCCESS: %d/%d passed", WaksTest.tests_run, WaksTest.tests_run))
    else
        print(string.format("FAILURE: %d failed", WaksTest.tests_failed))
    end
    os.exit(WaksTest.tests_failed > 0 and 1 or 0)
end

return WaksTest
