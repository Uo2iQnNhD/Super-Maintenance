--[[ Ro-netrium Hub - Survive Area 51 V3.3 ]]
--[[ Powered by Ro-Netrium Library V5.9.1 ]]
--[[ PART 1/2 — COMBINE WITH PART 2/2 INTO ONE SCRIPT, THEN EXECUTE ]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

--// LOAD RO-NETRIUM LIBRARY (latest version)
local okLib, Library = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Uo2iQnNhD/Super-Database/refs/heads/main/Release-Library.luau"))()
end)
if not okLib or type(Library) ~= "table" then
    local msg = "Failed to load Ro-netrium Library: " .. tostring(Library)
    local env = (typeof(getgenv) == "function" and getgenv()) or _G
    local prev = type(env) == "table" and (env.ZethHubLibrary or env.RoNetLibrary) or nil
    if type(prev) == "table" and type(prev.Notify) == "function" then
        pcall(function() prev:Notify(msg, 8, "Ro-netrium", "x-circle") end)
    else
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Ro-netrium", Text = msg, Duration = 8,
            })
        end)
    end
    return
end

local execName = (type(identifyexecutor) == "function" and identifyexecutor()) or "Executor"
Library.ToggleKey = Enum.KeyCode.LeftControl

local Window = Library:CreateWindow({
    Title = "Ro-netrium Hub",
    Subtitle = "Survive Area 51 V3 • " .. execName,
    Tags = {
        { Text = "Area 51", Icon = "gamepad-2", Color = Color3.fromRGB(255, 204, 0), TextColor = Color3.new(0, 0, 0) },
        { Text = "V3.3", Icon = "sparkles", Color = Color3.fromRGB(46, 230, 110), TextColor = Color3.new(0, 0, 0) },
    },
})
if not Window then return end

--// ==========================================================
--// SAFE HELPERS
--// ==========================================================
local function notify(msg, icon)
    Library:Notify(msg, 3, "Ro-netrium", icon or "info")
end

local function getChar() return LocalPlayer.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function findPath(root, ...)
    local cur = root
    for _, name in ipairs({ ... }) do
        if not cur then return nil end
        cur = cur:FindFirstChild(name)
    end
    return cur
end

local function fireTouch(part)
    local hrp = getHRP()
    if not hrp or not part then return false end
    if type(firetouchinterest) ~= "function" then return false end
    pcall(firetouchinterest, hrp, part, 0)
    pcall(firetouchinterest, hrp, part, 1)
    return true
end

local function firePrompt(prompt)
    if not prompt or type(fireproximityprompt) ~= "function" then return false end
    return pcall(fireproximityprompt, prompt)
end

local function teleport(cf)
    local hrp = getHRP()
    if hrp then hrp.CFrame = cf return true end
    return false
end

local function runExternal(url, name)
    task.spawn(function()
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if not ok or type(src) ~= "string" or src == "" then
            notify("Failed to fetch: " .. name, "x-circle") return
        end
        local chunk = loadstring(src)
        if not chunk then notify("Load error: " .. name, "x-circle") return end
        local ran = pcall(chunk)
        notify(ran and ("Executed: " .. name) or ("Error: " .. name), ran and "check-circle" or "x-circle")
    end)
end

--// Loop manager
local Loops = {}
local function StartLoop(key, interval, fn)
    if Loops[key] then return end
    Loops[key] = true
    task.spawn(function()
        while Loops[key] and not Library._destroyed do
            pcall(fn)
            task.wait(interval)
        end
        Loops[key] = false
    end)
end
local function StopLoop(key) Loops[key] = false end

local function LoopToggle(tab, name, icon, flag, tooltip, interval, fn)
    return tab:CreateToggle({
        Name = name, Icon = icon, Flag = flag, Default = false, Tooltip = tooltip,
        Callback = function(v)
            if v then StartLoop(flag, interval, fn) else StopLoop(flag) end
        end,
    })
end

--// Gun helpers
local HIT_VECTOR = Vector3.new(0.93720120191574, -0.3045220375061, -0.17005980014801)

local function getGunTool(toolName, charOnly)
    local containers = { getChar() }
    if not charOnly then
        table.insert(containers, LocalPlayer:FindFirstChildOfClass("Backpack"))
    end
    for _, container in ipairs(containers) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and tool:FindFirstChild("GunScript_Server")
                    and (not toolName or tool.Name == toolName) then
                    return tool
                end
            end
        end
    end
    return nil
end

local function inflict(tool, humanoid)
    if not tool or not humanoid or not humanoid.Parent then return end
    local head = humanoid.Parent:FindFirstChild("Head")
    local remote = findPath(tool, "GunScript_Server", "InflictTarget")
    if head and remote then
        pcall(function()
            remote:FireServer("Head", humanoid, head, tool, HIT_VECTOR)
        end)
    end
end

--// [NEW] SPAM ATTACK ENGINE — enumerates ALL models directly (reliable),
--// fires the hit remote multiple times per mob to one-hit them.
--// radius 9999 = whole map. Recursive search catches nested Humanoid/Head.
local function attackAllMobs(tool, spamCount, radius)
    if not tool then return end
    local remote = findPath(tool, "GunScript_Server", "InflictTarget")
    if not remote then return end
    local hrp = getHRP()
    local myPos = hrp and hrp.Position
    local myChar = getChar()
    spamCount = math.max(1, spamCount or 5)
    radius = radius or 9999
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model ~= myChar then
            local hum = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildWhichIsA("Humanoid", true)
            if hum and hum.Health > 0 then
                local head = model:FindFirstChild("Head") or model:FindFirstChild("Head", true)
                if head then
                    if not myPos or (head.Position - myPos).Magnitude <= radius then
                        for _ = 1, spamCount do
                            pcall(function()
                                remote:FireServer("Head", hum, head, tool, HIT_VECTOR)
                            end)
                        end
                    end
                end
            end
        end
    end
end

local function modifyGuns(applyFn, label)
    if type(getgc) ~= "function" then
        notify("getgc is not supported on this executor", "x-circle") return
    end
    local count = 0
    for _, obj in next, getgc(true) do
        if type(obj) == "table" and rawget(obj, "AmmoPerClip") then
            pcall(applyFn, obj)
            count += 1
        end
    end
    notify(label .. " → " .. count .. " guns", "check-circle")
end

--// ==========================================================
--// [FEATURE] DESTROY AC DECOYS (ONCE ON LOAD)
--// ==========================================================
local function destroyACParts()
    local n = 0
    local children = Workspace:GetChildren()
    local idx160 = children[160]
    if idx160 then
        pcall(function() idx160:Destroy() end)
        n += 1
    end
    for _, obj in ipairs(children) do
        if obj.Parent and (obj.Name == "SupplyBall" or obj.Name == "SupplyBox" or obj.Name == "SupplyCrate") then
            pcall(function() obj:Destroy() end)
            n += 1
        end
    end
    return n
end

--// ==========================================================
--// TAB: MAIN
--// ==========================================================
local MainTab = Window:CreateTab("Main", "home")

MainTab:CreateSection("Anti-Cheat Cleanup")

MainTab:CreateButton({
    Name = "Destroy AC Decoys (Once)", Icon = "trash-2",
    Tooltip = "Already runs automatically once on script load. Click manually only if decoys respawn.",
    Callback = function()
        local n = destroyACParts()
        notify("Destroyed " .. n .. " AC decoys", "check-circle")
    end,
})

MainTab:CreateParagraph({
    Title = "Decoys vs Real Supplies",
    Content = "The 3 supply-like named objects + child #160 at map start are ANTI-CHEAT decoys, so they are destroyed once on load. REAL supplies that spawn afterwards remain and can be collected via the Supply buttons in the Misc tab.",
    Icon = "info",
})

MainTab:CreateSection("Anti-Cheat Bypass")

local AC_CHILD_NAMES = { CheckUnlock = true, Maze = true, Save = true }
local acMaxChildConn, acMaxCharConn = nil, nil

local function stripACChildren(char)
    for _, child in ipairs(char:GetChildren()) do
        if AC_CHILD_NAMES[child.Name] then
            pcall(function() child:Destroy() end)
        end
    end
end

local function hookCharacterAC(char)
    if acMaxChildConn then acMaxChildConn:Disconnect() acMaxChildConn = nil end
    stripACChildren(char)
    acMaxChildConn = char.ChildAdded:Connect(function(child)
        if AC_CHILD_NAMES[child.Name] then
            pcall(function() child:Destroy() end)
        end
    end)
end

local function unhookAC()
    if acMaxChildConn then acMaxChildConn:Disconnect() acMaxChildConn = nil end
    if acMaxCharConn then acMaxCharConn:Disconnect() acMaxCharConn = nil end
end

local bypassPart = nil
local function ensureBypassPart()
    if bypassPart and bypassPart.Parent then return bypassPart end
    bypassPart = Workspace:FindFirstChild("AntiCheatBypass")
    if not bypassPart then
        local p = Instance.new("Part")
        p.Name = "AntiCheatBypass"
        p.Anchored = true
        p.Locked = true
        p.CanCollide = false
        p.Transparency = 1
        p.Size = Vector3.new(35, 2, 35)
        p.Position = Vector3.new(624, 1143.7354695, 747)
        p.Parent = Workspace
        bypassPart = p
    end
    return bypassPart
end

local acMaxToggle = MainTab:CreateToggle({
    Name = "Bypass AC MAX (Recommended)", Icon = "shield-check", Flag = "BypassACMax", Default = false,
    Tooltip = "Hook ChildAdded (instant destroy) + per-frame sweep + touch bypass part + auto re-hook on respawn",
    Callback = function(v)
        if v then
            local c = getChar()
            if c then hookCharacterAC(c) end
            acMaxCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
                task.wait(0.2)
                if Library.Flags.BypassACMax then hookCharacterAC(char) end
            end)
            StartLoop("BypassACMax", 0, function()
                local c = getChar()
                if c then stripACChildren(c) end
                fireTouch(ensureBypassPart())
            end)
        else
            StopLoop("BypassACMax")
            unhookAC()
        end
    end,
})

LoopToggle(MainTab, "Bypass Anti-Cheat 1 (Legacy)", "shield", "BypassAC1",
    "Legacy method: sweep CheckUnlock/Maze/Save every 0.03s", 0.03, function()
        local c = getChar()
        if c then stripACChildren(c) end
    end)

LoopToggle(MainTab, "Bypass Anti-Cheat 2 (Legacy)", "shield", "BypassAC2",
    "Backup method: touch bypass part only", 0, function()
        fireTouch(ensureBypassPart())
    end)

MainTab:CreateSection("Visuals")

MainTab:CreateButton({
    Name = "No Fog", Icon = "sun",
    Callback = function()
        pcall(function()
            Lighting.FogEnd = 100000
            Lighting.FogStart = 0
            Lighting.ClockTime = 14
            Lighting.Brightness = 2
            Lighting.GlobalShadows = false
        end)
        notify("Fog removed", "check-circle")
    end,
})

MainTab:CreateButton({
    Name = "Night Vision (Fullbright)", Icon = "eye",
    Callback = function()
        runExternal("https://rawscripts.net/raw/Universal-Script-fullbright-1324", "Fullbright")
    end,
})

MainTab:CreateButton({
    Name = "Auto Reporter", Icon = "flag",
    Callback = function()
        runExternal("https://rawscripts.net/raw/Universal-Script-OPEN-SOURCE-Universal-Auto-Report-Script-11095", "Auto Reporter")
    end,
})

--// ==========================================================
--// TAB: MISC
--// ==========================================================
local MiscTab = Window:CreateTab("Misc", "wrench")

MiscTab:CreateSection("Farm & Combat")

--// [FIXED] Auto Farm Money: direct model enumeration + spam hits + radius 9999.
--// Searches equipped OR backpack gun so it always works. One-hit via spam.
LoopToggle(MiscTab, "Auto Farm Money", "banknote", "AutoFarm",
    "Spam attacks ALL mobs (radius 9999) to one-hit them and farm money", 0.03, function()
        local tool = getGunTool(nil, false)
        if not tool then return end
        local spam = tonumber(Library.Flags.SpamHits) or 5
        attackAllMobs(tool, spam, 9999)
    end)

LoopToggle(MiscTab, "Auto S.M.M Buttons", "zap", "AutoSMM",
    "Auto touch all Defense buttons", 0, function()
        local defense = Workspace:FindFirstChild("Defense")
        if not defense then return end
        for _, part in ipairs(defense:GetChildren()) do
            if part:IsA("BasePart") then fireTouch(part) end
        end
    end)

LoopToggle(MiscTab, "Spam Heal Players Nearby", "heart", "SpamHeal",
    "Requires Cleansed Rifle in inventory/equipped", 0.37, function()
        local tool = getGunTool("Cleansed Rifle", false)
        if not tool then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            local c = plr.Character
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if hum and c:FindFirstChild("Head") then
                inflict(tool, hum)
            end
        end
    end)

MiscTab:CreateButton({
    Name = "Heal Players Once", Icon = "heart",
    Tooltip = "One-click version of Spam Heal (requires Cleansed Rifle)",
    Callback = function()
        local tool = getGunTool("Cleansed Rifle", false)
        if not tool then notify("Cleansed Rifle not found!", "x-circle") return end
        local n = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            local c = plr.Character
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if hum and c:FindFirstChild("Head") then inflict(tool, hum) n += 1 end
        end
        notify("Healed " .. n .. " players", "check-circle")
    end,
})

local function instantE()
    local n = 0
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then d.HoldDuration = 0 n += 1 end
    end
    return n
end

LoopToggle(MiscTab, "Auto Instant E Button", "zap", "AutoInstantE",
    "All E prompts become instant (including new ones)", 1, instantE)

MiscTab:CreateButton({
    Name = "Instant Interact E Button", Icon = "zap",
    Callback = function()
        notify("Instant E → " .. instantE() .. " prompts", "check-circle")
    end,
})

MiscTab:CreateSection("Movement (CFrame - Anti-Cheat Safe)")

local cfSpeedOn, cfSpeedVal = false, 50

local cfConn = RunService.Heartbeat:Connect(function(dt)
    if not cfSpeedOn or Library._destroyed then return end
    local char = getChar()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then return end
    if hum.Sit then return end
    if hum.MoveDirection.Magnitude > 0 then
        local extra = math.max(0, cfSpeedVal - 16)
        hrp.CFrame = hrp.CFrame + (hum.MoveDirection * extra * math.min(dt, 0.1))
    end
end)

MiscTab:CreateToggle({
    Name = "CFrame Speed", Icon = "gauge", Flag = "CFrameSpeed", Default = false,
    Tooltip = "Move fast using CFrame, WalkSpeed stays 16 → anti-cheat safe. PC & mobile.",
    Callback = function(v)
        cfSpeedOn = v
        if v then
            Library.Movement:SetWalkSpeedActive(false)
            local el = Library._elements and Library._elements["QB_WalkSpeed"]
            if el and el.Object then pcall(function() el.Object:Set(false) end) end
            notify("CFrame Speed ON (WalkSpeed stays 16)", "check-circle")
        end
    end,
})

MiscTab:CreateSlider({
    Name = "CFrame Speed Value", Icon = "gauge", Flag = "CFrameSpeedValue",
    Min = 16, Max = 300, Default = 50, Step = 1,
    Tooltip = "Total effective speed (16 = normal)",
    Callback = function(v) cfSpeedVal = v end,
})

MiscTab:CreateSection("ESP")

--// ==========================================================
--// ESP PLAYERS = BUILT-IN TOGGLE (Name + Distance + HP Bar + Team)
--// ==========================================================
local playerESPObjects = {}
local playerESPConns = {}
local playerESPAddedConn, playerESPRemovingConn = nil, nil

local function getTeamColor(plr)
    local ok, team = pcall(function() return plr.Team end)
    if ok and team then
        local ok2, col = pcall(function() return team.TeamColor.Color end)
        if ok2 and typeof(col) == "Color3" then return col end
    end
    return Color3.fromRGB(255, 255, 255)
end

local function removePlayerVisuals(plr)
    local data = playerESPObjects[plr]
    if not data then return end
    pcall(function() if data.bb and data.bb.Parent then data.bb:Destroy() end end)
    pcall(function() if data.hl and data.hl.Parent then data.hl:Destroy() end end)
    playerESPObjects[plr] = nil
end

local function clearPlayerESP(plr)
    removePlayerVisuals(plr)
    local conn = playerESPConns[plr]
    if conn then pcall(function() conn:Disconnect() end) playerESPConns[plr] = nil end
end

local function buildPlayerESP(plr, char)
    if plr == LocalPlayer or not char then return end
    if Library._destroyed then return end
    local head = char:WaitForChild("Head", 5)
    local hum = char:WaitForChild("Humanoid", 5)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not (head and hum and hrp) then return end
    if not Library.Flags.ESPPlayers then return end

    removePlayerVisuals(plr)
    local teamColor = getTeamColor(plr)

    local hl = Instance.new("Highlight")
    hl.Name = "PlayerESP_HL"
    hl.FillColor = teamColor
    hl.FillTransparency = 0.7
    hl.OutlineColor = Color3.fromRGB(0, 0, 0)
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char
    hl.Parent = char

    local bb = Instance.new("BillboardGui")
    bb.Name = "PlayerESP_GUI"
    bb.Adornee = head
    bb.Size = UDim2.new(0, 140, 0, 60)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.ResetOnSpawn = false
    bb.Parent = head

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, 14)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = plr.Name
    nameLbl.TextColor3 = teamColor
    nameLbl.TextStrokeTransparency = 0
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.Parent = bb

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1, 0, 0, 12)
    distLbl.Position = UDim2.new(0, 0, 0, 13)
    distLbl.BackgroundTransparency = 1
    distLbl.Text = "[0m]"
    distLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    distLbl.TextStrokeTransparency = 0
    distLbl.Font = Enum.Font.GothamBold
    distLbl.TextSize = 11
    distLbl.Parent = bb

    local hpBg = Instance.new("Frame")
    hpBg.Size = UDim2.new(0, 120, 0, 6)
    hpBg.Position = UDim2.new(0.5, -60, 0, 26)
    hpBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    hpBg.BorderSizePixel = 0
    hpBg.Parent = bb
    Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 3)

    local hpFill = Instance.new("Frame")
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBg
    Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 3)

    local hpLbl = Instance.new("TextLabel")
    hpLbl.Size = UDim2.new(1, 0, 0, 12)
    hpLbl.Position = UDim2.new(0, 0, 0, 34)
    hpLbl.BackgroundTransparency = 1
    hpLbl.Text = "HP: 100/100"
    hpLbl.TextColor3 = Color3.fromRGB(0, 255, 0)
    hpLbl.TextStrokeTransparency = 0
    hpLbl.Font = Enum.Font.GothamBold
    hpLbl.TextSize = 11
    hpLbl.Parent = bb

    local teamLbl = Instance.new("TextLabel")
    teamLbl.Size = UDim2.new(1, 0, 0, 10)
    teamLbl.Position = UDim2.new(0, 0, 0, 46)
    teamLbl.BackgroundTransparency = 1
    teamLbl.Text = "[" .. ((plr.Team and plr.Team.Name) or "No Team") .. "]"
    teamLbl.TextColor3 = teamColor
    teamLbl.TextStrokeTransparency = 0
    teamLbl.Font = Enum.Font.Gotham
    teamLbl.TextSize = 10
    teamLbl.Parent = bb

    playerESPObjects[plr] = {
        bb = bb, hl = hl, hum = hum, hrp = hrp,
        hpFill = hpFill, hpLbl = hpLbl, distLbl = distLbl,
    }
end

local function createPlayerESP(plr)
    if plr == LocalPlayer then return end
    if plr.Character then task.spawn(buildPlayerESP, plr, plr.Character) end
    if not playerESPConns[plr] then
        playerESPConns[plr] = plr.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            if Library.Flags.ESPPlayers then buildPlayerESP(plr, char) end
        end)
    end
end

local function updatePlayerESP()
    local myHRP = getHRP()
    for plr, data in pairs(playerESPObjects) do
        if not data.hum.Parent or not data.hrp.Parent then
            removePlayerVisuals(plr)
        else
            pcall(function()
                local hum = data.hum
                local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                data.hpFill.Size = UDim2.new(pct, 0, 1, 0)
                data.hpLbl.Text = string.format("HP: %d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
                local col
                if pct > 0.6 then col = Color3.fromRGB(0, 255, 0)
                elseif pct > 0.3 then col = Color3.fromRGB(255, 200, 0)
                else col = Color3.fromRGB(255, 0, 0) end
                data.hpFill.BackgroundColor3 = col
                data.hpLbl.TextColor3 = col
                if myHRP then
                    local dist = math.floor((myHRP.Position - data.hrp.Position).Magnitude)
                    data.distLbl.Text = "[" .. dist .. "m]"
                    if dist < 15 then data.distLbl.TextColor3 = Color3.fromRGB(255, 50, 50)
                    elseif dist < 40 then data.distLbl.TextColor3 = Color3.fromRGB(255, 200, 0)
                    else data.distLbl.TextColor3 = Color3.fromRGB(255, 255, 255) end
                end
            end)
        end
    end
end

MiscTab:CreateToggle({
    Name = "ESP Players (Name + HP + Distance)", Icon = "eye", Flag = "ESPPlayers", Default = false,
    Tooltip = "Built-in player ESP: name, distance, health bar, HP text, team. Auto respawn & leave. Can be turned OFF.",
    Callback = function(v)
        if v then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then createPlayerESP(plr) end
            end
            if not playerESPAddedConn then
                playerESPAddedConn = Players.PlayerAdded:Connect(function(plr)
                    if Library.Flags.ESPPlayers then createPlayerESP(plr) end
                end)
                playerESPRemovingConn = Players.PlayerRemoving:Connect(function(plr)
                    clearPlayerESP(plr)
                end)
            end
            StartLoop("PlayerESPUpdate", 0.1, updatePlayerESP)
        else
            StopLoop("PlayerESPUpdate")
            if playerESPAddedConn then playerESPAddedConn:Disconnect() playerESPAddedConn = nil end
            if playerESPRemovingConn then playerESPRemovingConn:Disconnect() playerESPRemovingConn = nil end
            for _, plr in ipairs(Players:GetPlayers()) do clearPlayerESP(plr) end
        end
    end,
})

--// ESP MOBS (Name + Distance + HP Bar)
local mobESPObjects = {}
local mobESPConn = nil

local function getMobPart(model)
    return model:FindFirstChild("Head") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local function removeMobESP(model)
    local data = mobESPObjects[model]
    if not data then return end
    pcall(function() if data.bb and data.bb.Parent then data.bb:Destroy() end end)
    pcall(function() if data.hl and data.hl.Parent then data.hl:Destroy() end end)
    mobESPObjects[model] = nil
end

local function createMobESP(model)
    if mobESPObjects[model] then return end
    if not model:IsA("Model") then return end
    if model == getChar() then return end
    if Players:GetPlayerFromCharacter(model) then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local part = getMobPart(model)
    if not hum or not part then return end

    local hl = Instance.new("Highlight")
    hl.Name = "MobESP_HL"
    hl.FillColor = Color3.fromRGB(255, 60, 60)
    hl.FillTransparency = 0.6
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = model
    hl.Parent = model

    local bb = Instance.new("BillboardGui")
    bb.Name = "MobESP_BB"
    bb.Adornee = part
    bb.Size = UDim2.new(0, 150, 0, 58)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = part

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, 14)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = model.Name
    nameLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
    nameLbl.TextStrokeTransparency = 0
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 13
    nameLbl.Parent = bb

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1, 0, 0, 12)
    distLbl.Position = UDim2.new(0, 0, 0, 14)
    distLbl.BackgroundTransparency = 1
    distLbl.Text = "[0m]"
    distLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    distLbl.TextStrokeTransparency = 0
    distLbl.Font = Enum.Font.GothamBold
    distLbl.TextSize = 11
    distLbl.Parent = bb

    local hpBg = Instance.new("Frame")
    hpBg.Size = UDim2.new(0, 120, 0, 6)
    hpBg.Position = UDim2.new(0.5, -60, 0, 28)
    hpBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    hpBg.BorderSizePixel = 0
    hpBg.Parent = bb
    Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 3)

    local hpFill = Instance.new("Frame")
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBg
    Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 3)

    local hpLbl = Instance.new("TextLabel")
    hpLbl.Size = UDim2.new(1, 0, 0, 12)
    hpLbl.Position = UDim2.new(0, 0, 0, 36)
    hpLbl.BackgroundTransparency = 1
    hpLbl.Text = "HP: 100/100"
    hpLbl.TextColor3 = Color3.fromRGB(0, 255, 0)
    hpLbl.TextStrokeTransparency = 0
    hpLbl.Font = Enum.Font.GothamBold
    hpLbl.TextSize = 11
    hpLbl.Parent = bb

    mobESPObjects[model] = {
        bb = bb, hl = hl, hum = hum, part = part,
        hpFill = hpFill, hpLbl = hpLbl, distLbl = distLbl,
    }
end

local function updateMobESP()
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") then createMobESP(m) end
    end
    local myHRP = getHRP()
    for model, data in pairs(mobESPObjects) do
        if not model.Parent or not data.hum.Parent then
            removeMobESP(model)
        else
            pcall(function()
                local hum = data.hum
                local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                data.hpFill.Size = UDim2.new(pct, 0, 1, 0)
                data.hpLbl.Text = string.format("HP: %d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
                local col
                if pct > 0.6 then col = Color3.fromRGB(0, 255, 0)
                elseif pct > 0.3 then col = Color3.fromRGB(255, 200, 0)
                else col = Color3.fromRGB(255, 0, 0) end
                data.hpFill.BackgroundColor3 = col
                data.hpLbl.TextColor3 = col
                if myHRP and data.part.Parent then
                    local dist = math.floor((myHRP.Position - data.part.Position).Magnitude)
                    data.distLbl.Text = "[" .. dist .. "m]"
                    if dist < 30 then data.distLbl.TextColor3 = Color3.fromRGB(255, 50, 50)
                    elseif dist < 80 then data.distLbl.TextColor3 = Color3.fromRGB(255, 200, 0)
                    else data.distLbl.TextColor3 = Color3.fromRGB(255, 255, 255) end
                end
            end)
        end
    end
end

MiscTab:CreateToggle({
    Name = "ESP Mobs (Name + HP + Distance)", Icon = "eye", Flag = "ESPMobs", Default = false,
    Tooltip = "Mob name, distance, health bar & HP text + red highlight. Can be fully turned OFF.",
    Callback = function(v)
        if v then
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("Model") then createMobESP(d) end
            end
            if not mobESPConn then
                mobESPConn = Workspace.DescendantAdded:Connect(function(d)
                    if d:IsA("Model") then
                        task.spawn(function()
                            task.wait(0.15)
                            if Library.Flags.ESPMobs then createMobESP(d) end
                        end)
                    end
                end)
            end
            StartLoop("MobESPUpdate", 0.1, updateMobESP)
        else
            StopLoop("MobESPUpdate")
            if mobESPConn then mobESPConn:Disconnect() mobESPConn = nil end
            for model in pairs(mobESPObjects) do removeMobESP(model) end
        end
    end,
})

--// ==========================================================
--// SUPPLY COLLECT (REAL supplies, not decoys)
--// ==========================================================
MiscTab:CreateSection("Supply")

local function collectSupply(names, collectAll, label)
    task.spawn(function()
        local hrp = getHRP()
        if not hrp then notify("Character not ready", "x-circle") return end
        local startPos = hrp.CFrame
        local list = {}
        for _, obj in ipairs(Workspace:GetChildren()) do
            for _, n in ipairs(names) do
                if obj.Name == n then
                    table.insert(list, obj)
                    break
                end
            end
        end
        if #list == 0 then notify("No " .. label .. " on the map", "x-circle") return end

        local targets = collectAll and list or { list[math.random(1, #list)] }
        for _, obj in ipairs(targets) do
            if Library._destroyed then return end
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                if obj.Name == "SupplyCrate" then pcall(function() part.Anchored = true end) end
                teleport(part.CFrame + Vector3.new(0, 3, 0))
                task.wait(0.25)
                for _, d in ipairs(obj:GetDescendants()) do
                    if d:IsA("ProximityPrompt") then firePrompt(d) end
                end
                if obj:IsA("ProximityPrompt") then firePrompt(obj) end
                task.wait(0.3)
                if obj.Name == "SupplyBall" then pcall(function() part.Anchored = false end) end
            end
        end
        teleport(startPos)
        notify(collectAll and ("Collected " .. #targets .. " " .. label) or ("Got 1 " .. label), "check-circle")
    end)
end

MiscTab:CreateButton({
    Name = "Get Supply Box", Icon = "package",
    Tooltip = "Collect 1 random real supply box (AC decoys already removed on load)",
    Callback = function() collectSupply({ "SupplyCrate" }, false, "Supply Box") end,
})
MiscTab:CreateButton({
    Name = "Get Supply Ball", Icon = "box",
    Tooltip = "Collect 1 random real supply ball",
    Callback = function() collectSupply({ "SupplyBall" }, false, "Supply Ball") end,
})
MiscTab:CreateButton({
    Name = "Collect All Supply Boxes", Icon = "package",
    RequireConfirm = true,
    ConfirmTitle = "Collect All Boxes",
    ConfirmContent = "Teleport to every real Supply Box, then return to your start position. Continue?",
    ConfirmCooldown = 2,
    Callback = function() collectSupply({ "SupplyBox", "SupplyCrate" }, true, "Supply Boxes") end,
})
MiscTab:CreateButton({
    Name = "Collect All Supply Balls", Icon = "box",
    RequireConfirm = true,
    ConfirmTitle = "Collect All Balls",
    ConfirmContent = "Teleport to every real Supply Ball, then return to your start position. Continue?",
    ConfirmCooldown = 2,
    Callback = function() collectSupply({ "SupplyBall" }, true, "Supply Balls") end,
})

--// [NEW] AUTO COLLECT SUPPLY ON SPAWN (queued so teleports never overlap)
local autoSupplyConn = nil
local autoSupplyBusy = false
local autoSupplyQueue = {}

local function isSupplyName(name)
    return name == "SupplyCrate" or name == "SupplyBall"
end

local function processAutoSupply()
    if autoSupplyBusy then return end
    autoSupplyBusy = true
    task.spawn(function()
        while #autoSupplyQueue > 0 and Library.Flags.AutoCollectSupply and not Library._destroyed do
            local obj = table.remove(autoSupplyQueue, 1)
            if obj and obj.Parent then
                local hrp = getHRP()
                if hrp then
                    local startPos = hrp.CFrame
                    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                    if part then
                        pcall(function() part.Anchored = true end)
                        teleport(part.CFrame + Vector3.new(0, 3, 0))
                        task.wait(0.2)
                        for _, d in ipairs(obj:GetDescendants()) do
                            if d:IsA("ProximityPrompt") then firePrompt(d) end
                        end
                        task.wait(0.2)
                        pcall(function() part.Anchored = false end)
                    end
                    teleport(startPos)
                    notify("Auto-collected " .. obj.Name, "check-circle")
                end
            end
            task.wait(0.1)
        end
        autoSupplyBusy = false
    end)
end

local function queueAutoSupply(obj)
    if not Library.Flags.AutoCollectSupply then return end
    if not isSupplyName(obj.Name) then return end
    task.spawn(function()
        task.wait(0.5)
        if obj.Parent and Library.Flags.AutoCollectSupply then
            table.insert(autoSupplyQueue, obj)
            processAutoSupply()
        end
    end)
end

MiscTab:CreateToggle({
    Name = "Auto Collect Supply (On Spawn)", Icon = "package", Flag = "AutoCollectSupply", Default = false,
    Tooltip = "Automatically collects SupplyCrate / SupplyBall / SupplyBox the moment they spawn. Note: teleports you to each supply.",
    Callback = function(v)
        if v then
            for _, obj in ipairs(Workspace:GetChildren()) do
                if isSupplyName(obj.Name) then
                    table.insert(autoSupplyQueue, obj)
                end
            end
            processAutoSupply()
            if not autoSupplyConn then
                autoSupplyConn = Workspace.ChildAdded:Connect(queueAutoSupply)
            end
            notify("Auto Collect Supply enabled", "check-circle")
        else
            if autoSupplyConn then autoSupplyConn:Disconnect() autoSupplyConn = nil end
            autoSupplyQueue = {}
            notify("Auto Collect Supply disabled", "info")
        end
    end,
})

--// ==========================================================
--// TAB: GUN MODS
--// ==========================================================
local GunTab = Window:CreateTab("Gun Mods", "crosshair")

GunTab:CreateSection("Combat")

--// [UPDATED] Kill-Aura: super-fast (per-frame) + spam hits + radius 9999 default
local killAuraToggle = LoopToggle(GunTab, "Kill-Aura", "target", "KillAura",
    "Super-fast spam attack on ALL mobs (radius 9999, one-hit)", 0, function()
        local tool = getGunTool(nil, true)
        if not tool then return end
        local spam = tonumber(Library.Flags.SpamHits) or 5
        local range = tonumber(Library.Flags.KillAuraRange) or 9999
        attackAllMobs(tool, spam, range)
    end)

GunTab:CreateSlider({
    Name = "Kill Aura Range", Icon = "crosshair", Flag = "KillAuraRange",
    Min = 10, Max = 9999, Default = 9999, Step = 1,
    Tooltip = "Attack radius (9999 = whole map)",
})

GunTab:CreateSlider({
    Name = "Spam Hits Per Tick", Icon = "zap", Flag = "SpamHits",
    Min = 1, Max = 20, Default = 5, Step = 1,
    Tooltip = "Hit remotes fired per mob each tick. Higher = faster one-hit. Lower this if you get kicked for spam.",
})

GunTab:CreateKeybind({
    Name = "Kill Aura Hotkey", Icon = "key", Flag = "KillAuraKey",
    CurrentKeybind = Enum.KeyCode.Unknown,
    Tooltip = "Press this key to toggle Kill Aura ON/OFF",
    Callback = function()
        killAuraToggle:Set(not (Library.Flags.KillAura == true))
    end,
})

GunTab:CreateSection("Gun Modifications")

local MODS = {
    { Name = "INF AMMO", Icon = "database", Apply = function(g) g.AmmoPerClip = math.huge end },
    { Name = "RAPID FIRE", Icon = "zap", Apply = function(g) g.FireRate = 0.01 g.Auto = true end },
    { Name = "FLAMING BULLET", Icon = "flame", Apply = function(g) g.FlamingBullet = true end },
    { Name = "SUPER BULLET SPEED", Icon = "gauge", Apply = function(g) g.BulletSpeed = math.huge end },
    { Name = "INF RANGE", Icon = "crosshair", Apply = function(g) g.Radius = math.huge end },
    { Name = "INSTANT RELOAD", Icon = "refresh-cw", Apply = function(g) g.ReloadTime = 0 end },
    { Name = "NO RECOIL", Icon = "target", Apply = function(g) g.CameraShakingEnabled = false end },
    { Name = "NO SPREAD", Icon = "scan", Apply = function(g) g.Spread = 0 end },
    { Name = "GIGANTIC AMMO", Icon = "box", Apply = function(g) g.BulletSize = Vector3.new(8, 8, 100) end },
}

local selectedMods = {}
GunTab:CreateMultiDropdown({
    Name = "Select Mods (Combo)", Icon = "layers", Flag = "GunModsSelected",
    Options = (function()
        local t = {}
        for _, m in ipairs(MODS) do table.insert(t, m.Name) end
        return t
    end)(),
    Placeholder = "None selected",
    Callback = function(list) selectedMods = list end,
})

GunTab:CreateButton({
    Name = "Apply Selected Mods", Icon = "play",
    Callback = function()
        if #selectedMods == 0 then notify("Select mods in the dropdown first!", "x-circle") return end
        local map = {}
        for _, m in ipairs(MODS) do map[m.Name] = m.Apply end
        modifyGuns(function(g)
            for _, name in ipairs(selectedMods) do
                if map[name] then map[name](g) end
            end
        end, "Combo Mods")
    end,
})

GunTab:CreateButton({
    Name = "Open All (Except Big Ammo)", Icon = "sparkles",
    RequireConfirm = true,
    ConfirmTitle = "Open All Mods",
    ConfirmContent = "All gun mods will be enabled (except Gigantic Ammo). Continue?",
    ConfirmCooldown = 3,
    Callback = function()
        modifyGuns(function(g)
            for _, m in ipairs(MODS) do
                if m.Name ~= "GIGANTIC AMMO" then m.Apply(g) end
            end
        end, "Open All")
    end,
})

for _, m in ipairs(MODS) do
    GunTab:CreateButton({
        Name = m.Name, Icon = m.Icon,
        Callback = function() modifyGuns(m.Apply, m.Name) end,
    })
end

GunTab:CreateSection("Equip Tools")

GunTab:CreateButton({
    Name = "Equip All Guns (PC)", Icon = "package",
    Callback = function()
        local c = getChar()
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not c or not bp then notify("Character/Backpack not ready", "x-circle") return end
        local n = 0
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then tool.Parent = c n += 1 end
        end
        notify("Equipped " .. n .. " guns", "check-circle")
    end,
})

LoopToggle(GunTab, "Equip All Guns (Mobile)", "smartphone", "EquipAllMobile",
    "Auto equip all tools from backpack (for mobile)", 0.1, function()
        local c = getChar()
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not c or not bp then return end
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then tool.Parent = c end
        end
    end)

--// ==========================================================
--// PART 1/2 DONE — PASTE PART 2/2 RIGHT BELOW THIS LINE
--// DO NOT EXECUTE UNTIL PART 2 IS PASTED!
--// ==========================================================

--[[ PART 2/2 : Antis + God Mode + Get Guns + Teleports + Craft + Final ]]

--// ==========================================================
--// TAB: ANTIS
--// ==========================================================
local AntiTab = Window:CreateTab("Antis", "shield")

AntiTab:CreateSection("Protection")

local ownerIds = { [135303445] = true, [984829886] = true }
local ownerConn = nil
AntiTab:CreateToggle({
    Name = "Anti-Owner (Auto Kick)", Icon = "shield-alert", Flag = "AntiOwner", Default = false,
    Tooltip = "Automatically kick you if an owner joins the server",
    Callback = function(v)
        if v then
            for _, p in ipairs(Players:GetPlayers()) do
                if ownerIds[p.UserId] then
                    pcall(function() LocalPlayer:Kick("Blocked User Joined: " .. p.Name) end)
                    return
                end
            end
            ownerConn = Players.PlayerAdded:Connect(function(p)
                if ownerIds[p.UserId] then
                    pcall(function() LocalPlayer:Kick("Blocked User Joined: " .. p.Name) end)
                end
            end)
            notify("Anti-Owner enabled", "shield-check")
        else
            if ownerConn then ownerConn:Disconnect() ownerConn = nil end
        end
    end,
})

AntiTab:CreateButton({
    Name = "Safe Incinerator", Icon = "flame",
    Callback = function()
        pcall(function() Workspace.Incinerator.Challenge1.Model.Model.ChallengeGate:Destroy() end)
        pcall(function() Workspace.Incinerator.Acid:Destroy() end)
        local inc = Workspace:FindFirstChild("Incinerator")
        if inc then
            for _, obj in ipairs(inc:GetChildren()) do
                if obj.Name == "FlameTrap" then pcall(function() obj:Destroy() end) end
            end
        end
        notify("Incinerator is safe", "check-circle")
    end,
})

AntiTab:CreateButton({
    Name = "Safe Mech O Lantern", Icon = "shield",
    Tooltip = "Click when the event starts • removes boss kill parts",
    Callback = function()
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj.Name == "MechGun" then pcall(function() obj:Destroy() end) end
        end
        local boss = findPath(Workspace, "CyberLand", "Mech O' Lantern")
        if boss then
            for _, name in ipairs({ "DamagePart", "GunSkill", "GunSkill2", "ScytheSkill", "Scythe" }) do
                local part = boss:FindFirstChild(name)
                if part then pcall(function() part:Destroy() end) end
            end
            notify("Mech O Lantern is safe", "check-circle")
        else
            notify("Boss not spawned yet (event not started?)", "x-circle")
        end
    end,
})

LoopToggle(AntiTab, "Anti-Mech-Gun", "shield", "AntiMechGun",
    "Auto destroy MechGun spawns", 0, function()
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj.Name == "MechGun" then pcall(function() obj:Destroy() end) end
        end
    end)

AntiTab:CreateButton({
    Name = "Anti One Hit Kill", Icon = "shield-check",
    Callback = function()
        local n = 0
        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid")
                and not Players:GetPlayerFromCharacter(model) then
                for _, d in ipairs(model:GetDescendants()) do
                    if d:IsA("TouchTransmitter") then
                        pcall(function() d:Destroy() end) n += 1
                    end
                end
            end
        end
        notify("Removed " .. n .. " kill touches", "check-circle")
    end,
})

AntiTab:CreateButton({
    Name = "Anti-Hunter", Icon = "eye-off",
    Callback = function()
        local maze = Workspace:FindFirstChild("MazeWorld")
        if not maze then notify("MazeWorld not found", "x-circle") return end
        local n = 0
        for _, obj in ipairs(maze:GetChildren()) do
            if obj.Name == "Hunter" then pcall(function() obj:Destroy() end) n += 1 end
        end
        notify("Removed " .. n .. " Hunters", "check-circle")
    end,
})

AntiTab:CreateButton({
    Name = "Anti-FlameTrap", Icon = "flame",
    Callback = function()
        local inc = Workspace:FindFirstChild("Incinerator")
        if not inc then notify("Incinerator not found", "x-circle") return end
        for _, obj in ipairs(inc:GetChildren()) do
            if obj.Name == "FlameTrap" then pcall(function() obj:Destroy() end) end
        end
        notify("FlameTraps removed", "check-circle")
    end,
})

AntiTab:CreateButton({
    Name = "Anti-FreezeTrap", Icon = "cloud",
    Callback = function()
        local ice = Workspace:FindFirstChild("IceZone")
        if not ice then notify("IceZone not found", "x-circle") return end
        for _, obj in ipairs(ice:GetChildren()) do
            if obj.Name == "FreezeTrap" then pcall(function() obj:Destroy() end) end
        end
        notify("FreezeTraps removed", "check-circle")
    end,
})

AntiTab:CreateButton({
    Name = "Anti-FactoryDead", Icon = "settings",
    Callback = function()
        local floor = Workspace:FindFirstChild("Floor 2")
        if not floor then notify("Floor 2 not found", "x-circle") return end
        for _, obj in ipairs(floor:GetChildren()) do
            if obj:IsA("Part") and obj.Name == "Part" then
                local tt = obj:FindFirstChildWhichIsA("TouchTransmitter")
                if tt then pcall(function() tt:Destroy() end) end
            end
        end
        notify("Factory kill parts disabled", "check-circle")
    end,
})

AntiTab:CreateButton({
    Name = "Anti-Bulls", Icon = "x-circle",
    Callback = function()
        local bulls = Workspace:FindFirstChild("Bulls")
        if not bulls then notify("Bulls not found", "x-circle") return end
        for _, obj in ipairs(bulls:GetChildren()) do
            pcall(function() obj:Destroy() end)
        end
        notify("Bulls removed", "check-circle")
    end,
})

AntiTab:CreateButton({
    Name = "Anti-Lava", Icon = "flame",
    Callback = function()
        local lava = Workspace:FindFirstChild("LavaZone")
        if not lava then notify("LavaZone not found", "x-circle") return end
        for _, d in ipairs(lava:GetDescendants()) do
            if d:IsA("BasePart") and d.Name == "Lava" then
                pcall(function() d.CanTouch = false end)
            end
        end
        notify("Lava is safe", "check-circle")
    end,
})

AntiTab:CreateSection("Universal")

AntiTab:CreateButton({ Name = "Anti-Fall", Icon = "navigation",
    Callback = function() runExternal("https://raw.githubusercontent.com/zephyr10101/AntiFall/main/Script", "Anti-Fall") end })
AntiTab:CreateButton({ Name = "Anti-Void", Icon = "shield",
    Callback = function() runExternal("https://rawscripts.net/raw/Universal-Script-Anti-Void-Script-18124", "Anti-Void") end })
AntiTab:CreateButton({ Name = "Anti-AFK", Icon = "clock",
    Callback = function() runExternal("https://raw.githubusercontent.com/evxncodes/mainroblox/main/anti-afk", "Anti-AFK") end })

--// ==========================================================
--// TAB: GOD MODE
--// ==========================================================
local GodTab = Window:CreateTab("God Mode", "shield-check")

GodTab:CreateParagraph({
    Title = "How It Works",
    Content = "Toggles keep auto-touching the armor so god mode never expires. Safe if the armor isn't on the map yet.",
    Icon = "info",
})

local ARMORS = {
    { Name = "God Mode Free", Armor = "Blizzard Armor", Flag = "GodFree", Icon = "shield" },
    { Name = "God Mode 10 Minutes", Armor = "Iron Armor - 10 min Playtime", Flag = "God10", Icon = "shield" },
    { Name = "God Mode 15 Minutes", Armor = "Silver Armor - 15 min Playtime", Flag = "God15", Icon = "shield" },
    { Name = "God Mode 30 Minutes", Armor = "Golden Armor - 30 min Playtime", Flag = "God30", Icon = "shield" },
    { Name = "God Mode 60 Minutes", Armor = "Diamond Armor - 60 min Playtime", Flag = "God60", Icon = "gem" },
    { Name = "God Mode Cultist Armor", Armor = "Cultist Armor", Flag = "GodCultist", Icon = "crown" },
}

local function armorHead(name)
    return findPath(Workspace, "Misc", name, "Head")
end

for _, a in ipairs(ARMORS) do
    LoopToggle(GodTab, a.Name, a.Icon, a.Flag, "Auto touch " .. a.Armor, 0, function()
        fireTouch(armorHead(a.Armor))
    end)
end

LoopToggle(GodTab, "God Mode CRAZY (All Armors)", "crown", "GodCrazy",
    "Touch ALL armors at once • strongest", 0.01, function()
        for _, a in ipairs(ARMORS) do
            fireTouch(armorHead(a.Armor))
        end
    end)

--// ==========================================================
--// TAB: GET GUNS
--// ==========================================================
local GetTab = Window:CreateTab("Get Guns", "database")

GetTab:CreateParagraph({ Title = "Information!", Content = "More Bypassed Get Guns Soon", Icon = "info" })

local function touchTarget(path, label)
    local part = findPath(Workspace, table.unpack(path))
    if fireTouch(part) then
        notify(label .. " ✓", "check-circle")
    else
        notify(label .. " not found (event not active?)", "x-circle")
    end
end

GetTab:CreateButton({
    Name = "Bypassed Get Ice Bow", Icon = "shield-check",
    Tooltip = "Don't spam click! Get the gun without a ban",
    Callback = function()
        task.spawn(function()
            teleport(CFrame.new(624.92657470703, 1142.2391357422, 750.24084472656))
            task.wait(1.3)
            local giver = findPath(Workspace, "IceZone", "GetIceCrossbow")
            if giver then
                local part = giver:IsA("Model")
                    and (giver.PrimaryPart or giver:FindFirstChildWhichIsA("BasePart"))
                    or giver
                if part then teleport(CFrame.new(part.Position)) end
                notify("Ice Bow obtained (bypassed)", "check-circle")
            else
                notify("GetIceCrossbow not found", "x-circle")
            end
        end)
    end,
})

GetTab:CreateButton({
    Name = "Get All Guns In This Tab", Icon = "sparkles",
    RequireConfirm = true,
    ConfirmTitle = "Get All Guns",
    ConfirmContent = "Grab all instant guns at once (Ice Bow, Lava, HEX, Red Missile, LXW). Continue?",
    ConfirmCooldown = 3,
    Callback = function()
        local paths = {
            { "IceZone", "GetIceCrossbow", "Head" },
            { "LavaZone", "Escape", "Head" },
            { "Exit" },
            { "Floor 2", "GetHEXGun", "Head" },
            { "Floor 2", "GetRedMissile", "Head" },
        }
        local n = 0
        for _, p in ipairs(paths) do
            if fireTouch(findPath(Workspace, table.unpack(p))) then n += 1 end
            task.wait(0.15)
        end
        notify("Got " .. n .. "/" .. #paths .. " guns", "check-circle")
    end,
})

GetTab:CreateButton({ Name = "Get Ice Bow (Instant)", Icon = "zap",
    Callback = function() touchTarget({ "IceZone", "GetIceCrossbow", "Head" }, "Ice Bow") end })
GetTab:CreateButton({ Name = "Get Lava Gun (Instant)", Icon = "flame",
    Callback = function() touchTarget({ "LavaZone", "Escape", "Head" }, "Lava Gun") end })
GetTab:CreateButton({ Name = "Get Hex Spitter (Instant)", Icon = "zap",
    Callback = function() touchTarget({ "Floor 2", "GetHEXGun", "Head" }, "Hex Spitter") end })
GetTab:CreateButton({ Name = "Get Red Missile (Instant)", Icon = "target",
    Callback = function() touchTarget({ "Floor 2", "GetRedMissile", "Head" }, "Red Missile") end })
GetTab:CreateButton({ Name = "Get LXW (Instant)", Icon = "zap",
    Callback = function() touchTarget({ "Exit" }, "LXW") end })

GetTab:CreateButton({
    Name = "Get Water Gun OP", Icon = "droplet",
    Tooltip = "Requires Instant E Button enabled",
    Callback = function()
        task.spawn(function()
            for _, valveName in ipairs({ "Valve1", "Valve2" }) do
                local valve = findPath(Workspace, "Sewer", valveName)
                local prompt = valve and valve:FindFirstChild("ProximityPrompt")
                local tries = 0
                while prompt and prompt.Enabled and tries < 60 and not Library._destroyed do
                    teleport(valve.CFrame)
                    firePrompt(prompt)
                    tries += 1
                    task.wait(0.1)
                end
            end
            teleport(CFrame.new(-362, 960, -54))
            notify("Water Gun sequence complete", "check-circle")
        end)
    end,
})

GetTab:CreateButton({
    Name = "Get Fire Sword OP", Icon = "flame",
    Tooltip = "Requires Instant E Button + Anti Bulls",
    Callback = function()
        task.spawn(function()
            local button = findPath(Workspace, "Incinerator", "ChallengeButton7", "Button")
            local prompt = button and button:FindFirstChild("ProximityPrompt")
            local tries = 0
            while prompt and prompt.Enabled and tries < 60 and not Library._destroyed do
                teleport(button.CFrame)
                firePrompt(prompt)
                tries += 1
                task.wait(0.1)
            end
            teleport(CFrame.new(61, 1062, 1158))
            notify("Fire Sword sequence complete", "check-circle")
        end)
    end,
})

GetTab:CreateButton({
    Name = "Get Security Tablet", Icon = "monitor",
    Tooltip = "Click after the boss dies",
    Callback = function()
        local obj = Workspace:FindFirstChild("GetSecurityTablet")
        if obj and obj:IsA("BasePart") then
            teleport(obj.CFrame)
            notify("Teleported to Security Tablet", "check-circle")
        else
            notify("GetSecurityTablet not spawned yet", "x-circle")
        end
    end,
})

GetTab:CreateButton({ Name = "Get Reapers Scythe", Icon = "zap",
    Callback = function() touchTarget({ "GetReaperGun" }, "Reapers Scythe") end })
GetTab:CreateButton({ Name = "Get RGB (Event)", Icon = "sparkles",
    Callback = function() touchTarget({ "CorruptedZone", "RGB - 9999 Cell", "Head" }, "RGB") end })
GetTab:CreateButton({ Name = "Get LXD (Event)", Icon = "gem",
    Callback = function() touchTarget({ "DeadGround", "LXD - 9999 Cell", "Head" }, "LXD") end })
GetTab:CreateButton({ Name = "Get Corrupted Rifle (Event)", Icon = "zap",
    Callback = function() touchTarget({ "NightCity", "Exit", "Head" }, "Corrupted Rifle") end })
GetTab:CreateButton({ Name = "Get ScareCrow Skull (Event)", Icon = "crown",
    Callback = function() touchTarget({ "GetScarecrowSkull" }, "ScareCrow Skull") end })
GetTab:CreateButton({ Name = "Get Mecha Gun (Event)", Icon = "cpu",
    Callback = function() touchTarget({ "CyberLand", "GetMechGun" }, "Mecha Gun") end })

--// ==========================================================
--// TAB: TELEPORTS
--// ==========================================================
local TPTab = Window:CreateTab("Teleports", "map-pin")

local TELEPORTS = {
    { Name = "Lobby", Pos = Vector3.new(710.11, 1149.99, 738.18) },
    { Name = "Reapers Room", Pos = Vector3.new(-192.62, 982.00, 279.22) },
    { Name = "Sherrif Room", Pos = Vector3.new(-492.40, 881.10, -278.16) },
    { Name = "Water Room", Pos = Vector3.new(-361.76, 971.10, -219.05) },
    { Name = "Crafting Room", Pos = Vector3.new(953.65, 1059.99, 714.63) },
    { Name = "Mineshaft", Pos = Vector3.new(-471, 753, 920) },
    { Name = "Mecha Boss", Pos = Vector3.new(794.52, 849.99, -615.50) },
    { Name = "Enter Wrong Portal", Pos = Vector3.new(246.69, 1099.08, 1813.13) },
    { Name = "Enter Portal", Pos = Vector3.new(-104.40, 982.50, 833.76) },
}

for _, tp in ipairs(TELEPORTS) do
    TPTab:CreateButton({
        Name = tp.Name, Icon = "navigation",
        Callback = function()
            if teleport(CFrame.new(tp.Pos)) then
                notify("Teleported: " .. tp.Name, "map-pin")
            else
                notify("Character not ready", "x-circle")
            end
        end,
    })
end

--// ==========================================================
--// TAB: CRAFT GUNS
--// ==========================================================
local CraftTab = Window:CreateTab("Craft Guns", "hammer")

local CRAFTS = {
    { Name = "Obsidian Gun", Req = "WaterGun + LavaGun", Part = "Obsidian Gun" },
    { Name = "Blue Missile Launcher", Req = "RedMissile + WaterGun", Part = "Blue Missile Launcher" },
    { Name = "Acid Gun", Req = "WaterGun + ReapersScythe", Part = "Acid Gun" },
    { Name = "Tracker", Req = "SecurityCamera + RGB", Part = "Tracker" },
    { Name = "Dual Revolver", Req = "Revolver + Dual LX3", Part = "Dual Revolver" },
    { Name = "Cleansed Rifle", Req = "Corrupted Rifle + LXW", Part = "Cleansed Rifle" },
    { Name = "Spitfire", Req = "Revolver + HexSpitter + Vulkan", Part = "Spitfire" },
    { Name = "Inglaciator", Req = "WaterGun + RedMissile + IceBow", Part = "Snowball Launcher" },
    { Name = "Brass Sword", Req = "Vulkan + HexSpitter + FireSword", Part = "Brass Sword" },
    { Name = "Solar Ray", Req = "LXW + HexSpitter + RGB + Vulkan", Part = "Solar Ray" },
}

for _, craft in ipairs(CRAFTS) do
    CraftTab:CreateButton({
        Name = craft.Name, Icon = "hammer",
        Tooltip = "Requires: " .. craft.Req,
        Callback = function()
            touchTarget({ "CraftingRoom", craft.Part, "Head" }, craft.Name)
        end,
    })
end

--// ==========================================================
--// FINALIZATION
--// ==========================================================

local acRemoved = destroyACParts()

pcall(function()
    local sign = findPath(Workspace, "MazeWorld", "ESCAPE FROM THIS HELL")
    if sign then sign:Destroy() end
end)

acMaxToggle:Set(true)

if Window._extraCleanups then
    table.insert(Window._extraCleanups, function()
        cfSpeedOn = false
        pcall(function() if cfConn then cfConn:Disconnect() end end)
        --// Player ESP
        StopLoop("PlayerESPUpdate")
        if playerESPAddedConn then pcall(function() playerESPAddedConn:Disconnect() end) playerESPAddedConn = nil end
        if playerESPRemovingConn then pcall(function() playerESPRemovingConn:Disconnect() end) playerESPRemovingConn = nil end
        for _, plr in ipairs(Players:GetPlayers()) do clearPlayerESP(plr) end
        --// Mob ESP
        StopLoop("MobESPUpdate")
        if mobESPConn then pcall(function() mobESPConn:Disconnect() end) mobESPConn = nil end
        for model in pairs(mobESPObjects) do removeMobESP(model) end
        --// Auto Supply
        if autoSupplyConn then pcall(function() autoSupplyConn:Disconnect() end) autoSupplyConn = nil end
        autoSupplyQueue = {}
        --// AC hooks
        StopLoop("BypassACMax")
        unhookAC()
    end)
end

MainTab:Activate()

Library:Notify("Script loaded • " .. acRemoved .. " AC decoys destroyed • Bypass MAX enabled!", 5, "Ro-netrium", "check-circle")
Library:Notify("V3.3: Super-fast spam Kill-Aura + fixed Auto Farm (9999) + Auto Collect Supply on spawn.", 6, "Update V3.3", "sparkles")

--[[ DONE 2/2 — Ro-netrium Hub V3.3 x Ro-Netrium Library V5.9.1 ]]
