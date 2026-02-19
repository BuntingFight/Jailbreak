if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
PlayerScripts:WaitForChild("LocalScript")
local LocalScript = LocalPlayer.PlayerScripts:FindFirstChild("LocalScript")

function avblfuncs(name)
    return type(getfenv()[name]) == "function" or type(_G[name]) == "function"
end

function FuncSafeCall(name, ...)
    local fn = getfenv()[name] or _G[name]
    if type(fn) ~= "function" then return nil end
    return pcall(fn, ...)
end

local BlockedPatterns = {"wh9hvr3qrm", "w.*3qrm", "NoClip", "StrafingNoPhysics", "BackpackTool", "JumpPower", "Inf Nitro", "Renamed Service", "game.GetObjects", "_G.antiarrest", "Xpcall", "VisDetect", "Getupvalues", "FailedPcall"}

function AntiCheatCheck(...)
    local args = {...}
    for _, arg in ipairs(args) do
        if type(arg) == "string" then
            for _, pattern in ipairs(BlockedPatterns) do
                if string.find(arg, pattern) then
                    return true
                end
            end
        end
    end
    return false
end

function FromAntiCheatCheck()
    if not avblfuncs("getcallingscript") then return false end
    local ok, caller = FuncSafeCall("getcallingscript")
    if not ok then return false end
    return caller ~= nil and caller == LocalScript
end

if avblfuncs("getrawmetatable") and avblfuncs("setreadonly") and avblfuncs("newcclosure") and avblfuncs("getnamecallmethod") then
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    local oldIndex = mt.__index

    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" then
            if FromAntiCheatCheck() and AntiCheatCheck(...) then
                return nil
            end
        end
        return oldNamecall(self, ...)
    end)

    mt.__index = newcclosure(function(self, key)
        if key == "JumpPower" and FromAntiCheatCheck() and typeof(self) == "Instance" and self:IsA("Humanoid") and self.Parent == LocalPlayer.Character then
            return 50
        end
        return oldIndex(self, key)
    end)

    setreadonly(mt, true)
end

if avblfuncs("getgc") and avblfuncs("isreadonly") and avblfuncs("newcclosure") then
    pcall(function()
        for _, v in pairs(getgc(true)) do
            if type(v) == "table" then
                pcall(function()
                    if rawget(v, "FireServer") and not isreadonly(v) then
                        local oldFire = v.FireServer
                        v.FireServer = newcclosure(function(self, ...)
                            if FromAntiCheatCheck() and AntiCheatCheck(...) then
                                return nil
                            end
                            return oldFire(self, ...)
                        end)
                    end
                end)
            end
        end
    end)
end

function PatchAntiCheat()
    if not LocalScript then return end
    if not avblfuncs("getsenv") then return end

    local success, env = pcall(getsenv, LocalScript)
    if not success or not env then return end

    pcall(function()
        if env.v_u_1119 ~= nil then
            env.v_u_1119 = true
        end
    end)

    pcall(function()
        if env.v_u_90 then
            env.v_u_90 = function(...)
                return not AntiCheatCheck(...) or true
            end
        end
    end)

    pcall(function()
        if env.v_u_1145 then
            env.v_u_1145 = function()
                return true
            end
        end
    end)

    pcall(function()
        if env.v_u_99 then
            local oldLoop = env.v_u_99
            env.v_u_99 = function(interval, callback, ...)
                if callback == env.v_u_1145 then
                    return true
                end
                return oldLoop(interval, callback, ...)
            end
        end
    end)
end

print("Monitoring", #BlockedPatterns, "patterns")

local DisabledConnections = {}

function DisableConnection(conn)
    if not conn then return false end
    if DisabledConnections[conn] then return false end
    local ok, enabled = pcall(function() return conn.Enabled end)
    local ok2, fn = pcall(function() return conn.Function end)
    if ok and ok2 and enabled and fn then
        local disOk = pcall(function() conn:Disable() end)
        if disOk then
            DisabledConnections[conn] = true
            return true
        end
    end
    return false
end

function HookHumanoidStates()
    function ProcessHumanoid(humanoid)
        if not humanoid then return end
        if not avblfuncs("getconnections") then return end

        pcall(function()
            local connections = getconnections(humanoid.StateChanged)
            local disabled = 0

            for _, conn in pairs(connections) do
                pcall(function()
                    if DisableConnection(conn) then
                        disabled = disabled + 1
                    end
                end)
            end

            if disabled > 0 then
                warn("Disabled", disabled, "StateChanged connections")
            end
        end)
    end

    LocalPlayer.CharacterAdded:Connect(function(char)
        local humanoid = char:WaitForChild("Humanoid", 5)
        ProcessHumanoid(humanoid)
    end)

    if LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        ProcessHumanoid(humanoid)
    end
end

task.spawn(HookHumanoidStates)

function HookBackpack()
    local backpack = LocalPlayer:WaitForChild("Backpack", 10)
    if not backpack then return end
    if not avblfuncs("getconnections") then return end

    pcall(function()
        local connections = getconnections(backpack.ChildAdded)
        local disabled = 0

        for _, conn in pairs(connections) do
            pcall(function()
                if DisableConnection(conn) then
                    disabled = disabled + 1
                end
            end)
        end

        if disabled > 0 then
            warn("Disabled", disabled, "Backpack connections")
        end
    end)
end

task.spawn(HookBackpack)

pcall(function()
    _G.antiarrest = nil
    if avblfuncs("debug") and debug.getupvalues ~= nil then
        debug.getupvalues = nil
    end
    game.GetObjects = nil
end)

getgenv().BlockAC = {
    Active = true,

    SFireServer = function(remote, ...)
        remote:FireServer(...)
    end,

    GetEnv = function()
        if LocalScript and avblfuncs("getsenv") then
            local success, env = pcall(getsenv, LocalScript)
            return success and env or nil
        end
        return nil
    end,

    DisableAllChecks = function()
        local env = getgenv().BlockAC.GetEnv()
        if not env then return false end

        local success = false

        local flags = {"v_u_1119", "v_u_1123", "v_u_1028", "v_u_1029", "v_u_900"}
        for _, flag in ipairs(flags) do
            pcall(function()
                if env[flag] ~= nil then
                    env[flag] = true
                    success = true
                end
            end)
        end

        local functions = {"v_u_1145", "v_u_966", "v_u_1007"}
        for _, funcName in ipairs(functions) do
            pcall(function()
                if env[funcName] then
                    env[funcName] = function() return true end
                    success = true
                end
            end)
        end

        for k, v in pairs(env) do
            if type(v) == "function" then
                if type(k) == "string" and string.find(string.lower(k), "cheatcheck") then
                    pcall(hookfunction, v, function() end)
                    success = true
                end

                if avblfuncs("getconstants") then
                    local ok, consts = pcall(getconstants, v)
                    if ok and consts then
                        for _, c in pairs(consts) do
                            if type(c) == "string" then
                                for _, pattern in ipairs({"wh9hvr3qrm", "w%.%*3qrm", "CheatCheck", "anticheat"}) do
                                    if string.find(c, pattern) then
                                        pcall(hookfunction, v, function() end)
                                        success = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                end

                if avblfuncs("getupvalues") then
                    local ok, uvs = pcall(getupvalues, v)
                    if ok and uvs then
                        for _, uv in pairs(uvs) do
                            if type(uv) == "string" then
                                for _, pattern in ipairs({"wh9hvr3qrm", "w.*3qrm", "CheatCheck"}) do
                                    if string.find(tostring(uv), pattern) then
                                        pcall(hookfunction, v, function() end)
                                        success = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        return success
    end,

    DisableAllConnections = function()
        if not avblfuncs("getconnections") then return 0 end

        local disabled = 0

        if LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
            if humanoid then
                pcall(function()
                    for _, conn in pairs(getconnections(humanoid.StateChanged)) do
                        pcall(function()
                            if DisableConnection(conn) then
                                disabled = disabled + 1
                            end
                        end)
                    end
                end)
            end
        end

        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            pcall(function()
                for _, conn in pairs(getconnections(backpack.ChildAdded)) do
                    pcall(function()
                        if DisableConnection(conn) then
                            disabled = disabled + 1
                        end
                    end)
                end
            end)
        end

        if disabled > 0 then
            warn("Disabled", disabled, "connections")
        end

        return disabled
    end
}

task.spawn(function() PatchAntiCheat() end)

task.spawn(function()
    while task.wait(2) do
		getgenv().BlockAC.DisableAllConnections()
		getgenv().BlockAC.DisableAllChecks()
    end
end)
