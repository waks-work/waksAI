---@mod waksAI.request API Request Handler
---@brief Handles synchronous and asynchronous (streaming) communication
---with the rust ai backend.
local state = require("waksAI.state")
local bridge = require("waksAI.bridge")

local M = {}

---@private
local function json_encode(tbl) return bridge.json_encode(tbl) end

---@private
local function json_decode(str)
    bridge.json_decode(str)
end

---Sends non-streaming POST request to the backend.
---@param payload table The GenerateReq structure in provider.rs
---@param callback fun(response: table | string) Callback on completion.
function M.send(payload, callback)
    local body = json_encode(payload)

    -- Use systemlist to avoid shell scraping issues.
    local cmd = {
        "curl", "-s",
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "-d", body,
        state.config.endpoint .. "/generate",
    }

    --- @note(waks-work): add a wrapper for vim.fn.jobstart()
    bridge.start_task(cmd, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            local raw = table.concat(data, "")
            local decoded = json_decode(raw)
            if callback then callback(decoded or raw) end
        end,
        on_stderr = function(_, data)
            if #data[1] > 0 then
                bridge.notify("WaksAI Error: " .. table.concat(data, "\n"), bridge.get_log_level("error"))
            end
        end
    })
end

---Starts a POST streaming request
---@param payload table The GenerateReq structure
---@param on_chunk fun(chunk: string) Callback for every token recieved
function M.stream(payload, on_chunk)
    -- ensure our backend is configured for streaming
    local stream = true
    local cmd = {
        "curl", "-N", "-X", "POST",
        "-H", "Content-Type: application/json",
        "-d", json_encode(payload),
        state.config.endpoint .. "/stream",
    }
    return bridge.start_task(cmd, {
        on_stdout = function(_, data)
            for _, line in ipairs(data) do
                if line and line ~= "" then
                    -- Some providers wrap chunks in JSON, others send raw text.
                    -- We wrap the raw line to the UI handler to decide.
                    on_chunk(line)
                end
            end
        end,
        on_stderr = function(_, data)
            local err = table.concat(data, "")
            if #err > 0 then
                bridge.notify("Streaming Error: " .. err, bridge.get_log_level("error"))
            end
        end,
        on_exit = function()
            on_chunk("[DONE]")
        end,
    })
end

---@note(waks-test): Verify that we can construct a valid curl command.
function M._test_request_format()
    local test_payload = {
        model = "Phi3",
        messages = { { role = "user", content = "Hi" } }
    }
    local encoded = json_encode(payload)

    if encoded:match("Phi3") and encoded:match("user") then
        print("[] Test JSON Encoding: PASSED")
    else
        print("[] Test JSOM Encoding: Failed")
    end
end

return M
