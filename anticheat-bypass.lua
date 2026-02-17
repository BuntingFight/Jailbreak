if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
PlayerScripts:WaitForChild("LocalScript")
local LocalScript = LocalPlayer.PlayerScripts:FindFirstChild("LocalScript")

local BlockedPatterns = {"wh9hvr3qrm", "w.*3qrm", "NoClip", "StrafingNoPhysics", "BackpackTool", "JumpPower", "Inf Nitro", "Renamed Service", "game.GetObjects", "_G.antiarrest", "Xpcall", "VisDetect", "Getupvalues", "FailedPcall"}

local function AntiCheatCheck(...)
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

local function FromAntiCheatCheck()
    local caller = getcallingscript()
    if caller and caller == LocalScript then
        return true
    end
    return false
end

local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
local oldIndex = mt.__index

setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    
    if method == "FireServer" then
        if FromAntiCheatCheck() and AntiCheatCheck(...) then
            warn("Blocked AC call:", ...)
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

local function HookRemoteEvents()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            pcall(function()
                if rawget(v, "FireServer") and not isreadonly(v) then
                    local oldFire = v.FireServer
                    v.FireServer = newcclosure(function(self, ...)
                        if FromAntiCheatCheck() and AntiCheatCheck(...) then
                            warn("Blocked GC FireServer:", ...)
                            return nil
                        end
                        return oldFire(self, ...)
                    end)
                end
            end)
        end
    end
end

pcall(HookRemoteEvents)

local function PatchAntiCheat()
    if not LocalScript then return end
    
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

task.spawn(function()
    task.wait(2)
    if LocalScript then
        PatchAntiCheat()
    end
end)

print("Monitoring", #BlockedPatterns, "patterns")

local DisabledConnections = {}

local function DisableConnection(conn)
    if conn.Function and conn.Enabled and not DisabledConnections[conn] then
        conn:Disable()
        DisabledConnections[conn] = true
        return true
    end
    return false
end

local function HookHumanoidStates()
    local function ProcessHumanoid(humanoid)
        if not humanoid then return end
        
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

local function HookBackpack()
    local backpack = LocalPlayer:WaitForChild("Backpack", 10)
    if not backpack then return end
    
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
    debug.getupvalues = nil
    game.GetObjects = nil
end)

getgenv().BlockAC = {
    Active = true,
    
    SFireServer = function(remote, ...)
        remote:FireServer(...)
    end,
    
    GetEnv = function()
        if LocalScript then
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
        
        return success
    end,
    
    DisableAllConnections = function()
        local disabled = 0
        
        if LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
            if humanoid then
                pcall(function()
                    for _, signal in pairs({"StateChanged"}) do
                        local connections = getconnections(humanoid[signal])
                        for _, conn in pairs(connections) do
                            pcall(function()
                                if DisableConnection(conn) then
                                    disabled = disabled + 1
                                end
                            end)
                        end
                    end
                end)
            end
        end
        
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            pcall(function()
                local connections = getconnections(backpack.ChildAdded)
                for _, conn in pairs(connections) do
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

task.spawn(function()
    while task.wait() do
        getgenv().BlockAC.DisableAllChecks()
        getgenv().BlockAC.DisableAllConnections()
    end
end)
