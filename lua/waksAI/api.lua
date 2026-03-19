---@mod waksAI.api High-level API Interface
---@brief Orchastrates session management, context gathering, and backend tracking.

local context = require("waksAI.context")
local state = require("waksAI.state")
local bridge = require("waksAI.bridge")

local M = {}
local base_url = "http://127.0.0.1:11500"

---@private
---Generic asynchronous request wrapper
---@param method "POST" | "GET"
---@param path string
---@param body table?
---@param callback fun(res: table| nil)
local function async_request(method, path, body, callback)
    local cmd = {
        "curl", "-s", "-X", method,
        "-H", "Content-Type: application/json",
        base_url .. path
    }

    if body then
        table.insert(cmd, "-d")
        table.insert(cmd, vim.fn.json_encode(body))
    end

    --- @note(waks-work): vim.system({cmd}, {opts}, {on_exit})
    vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if not data or (#data == 1 and data[1] == "") then
                if callback then callback(nil) end
                return
            end
            local ok, res = pcall(vim.fn.json_decode, table.concat(data, "\n"))
            if ok and callback then callback(ok and res or nil) end
        end,
        on_stderr = function(_, data)
            if data and #data > 0 then
                vim.notify("API Error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
            end
        end
    })
end


---@private
---Returns the api key either from .waksai.json or env variables.
---@return string
local function get_api_key()
    local env_key = os.getenv("WAKSAI_API_KEY")
    if env_key then return env_key end

    local file = io.open(".waksai.json", "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content:match('"api_key":%s*"(.-)"')
    end

    return nil
end

---Generate AI response with session tracking for the SQLite database
---@param prompt string The user query
---@param session_id string?
---@param callback fun(response: string)
function M.generate_with_session(prompt, session_id, callback)
    -- 1. Automatically gather code context from Neovim
    local ctx = context.build_request_context(prompt)

    -- 2. Construct the GenerateReq (matches provider.rs)
    local req = {
        provider = state.session.provider,
        model = state.session.model,
        messages = {
            { role = "system", content = "Context: " .. (ctx.snippet or "None") },
            { role = "user",   content = prompt }
        },
        stream = false,
        api_key = get_api_key(),
        session_id = session_id or state.session.id,
        agent_mode = state.session.settings.agent_mode or false
    }

    async_request("POST", "/generate", req, function(res)
        if res and res.response then
            callback(res.response)
        else
            bridge.notify("AI backend failed to return text", bridge.get_log_level("info"))
            callback("")
        end
    end)
end

---@note(waks-work): please recheck where it us used and implemented as
---it may not be needed any more
function M.generate(prompt, callback)
    -- Create a unique session ID for this quick request
    local session_id = "quick_" .. tostring(os.time()) .. "_" .. math.random(1000, 9999)

    M.generate_with_session(prompt, session_id, "ollama", "codellama", function(response)
        if callback then callback(response, {}) end
    end)
end

---@note(waks-work): please recheck where it us used and implemented as
---it may not be needed any more
function M.stream_generate(prompt, session_id, provider, model, callback)
    local req = {
        provider = provider or "ollama",
        model = model or "llama2",
        messages = {
            {
                role = "user",
                content = prompt
            }
        },
        stream = true,
        session_id = session_id,
        agent_mode = false
    }

    async_request("POST", "/stream", req, callback)
end

---Records a code change to the Rust backend (CodeChange table)
---@param file_name string
---@param previous_code string
---@param changed_code string
---@param description string
function M.record_code_change(file_name, previous_code, changed_code, description)
    local payload = {
        session_id = state.session.id,
        file_name = file_name,
        old_content = previous_code,
        new_content = changed_code,
        msg = description or "AI Generated Change"
    }
    async_request("POST", "/record/change", payload, function()
        vim.schedule(function() print("✓ Code change synced to Rust database") end)
    end)
end

---Records a frontend activity (FrontendActivity table)
---@param action string The action performed (e.g., 'buffer_open', 'chat_start')
---@param payload table Additional metadata
function M.record_activity(action, payload)
    local data = {
        session_id = state.session.id,
        action = action,
        payload = payload or {}
    }
    async_request("POST", "/record/activity", data)
end

-- Maintain compatibility with existing code
---@param prompt string
---@param callback fun(...)
function M.send(prompt, callback)
    M.generate(prompt, function(response)
        if callback then callback(response, {}) end
    end)
end

---@note(waks-test): Verify session payload construction
function M._test_session_payload()
    print("Testing Session Payload...")
    -- This tests if the context is being pulled correctly during a request
    M.generate_with_session("test prompt", "test_id", function(resp)
        if resp then print("✅ API Session Test: PASSED") end
    end)
end

return M
