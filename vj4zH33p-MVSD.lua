--[[
    RO-NETRIUM MVSD
    Ultra-Fast Kill All (Heartbeat) + Updated UI (Icon Tags)
]]

-- // [1] INITIALIZATION & SERVICES
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Uo2iQnNhD/Super-Database/refs/heads/main/Release-Library.luau"))()
if not Library then warn("[Ro-Netrium] Failed to load library!") return end
Library.ToggleKey = Enum.KeyCode.RightShift

local Window = Library:CreateWindow({
    Title = "Ro-Netrium", Subtitle = "Created By Zaycapcay & Exterminate0",
    Tags = {
        { Text = "MVSD",       Icon = "gamepad-2", Color = Color3.fromRGB(255,204,0),  TextColor = Color3.new(0,0,0) },
        { Text = "SUPER ULTRA",      Icon = "flame",     Color = Color3.fromRGB(255,70,90),  TextColor = Color3.new(1,1,1) },
    },
    QuickBar = true, NetStatsBar = true, InfoTab = true, ToolsTab = true, ThemeTab = true, SaveLoad = true,
    ConfirmTitle = "Ro-Netrium", ConfirmSubtitle = "Close Ro-Netrium? Unsaved changes will be lost.",
})
if not Window then return end
Library:Notify("Ro-Netrium MVSD loaded! RightShift = show/hide.", 5, "Ro-Netrium", "sparkles")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local M = Library.Movement

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local ShootGun = Remotes and Remotes:FindFirstChild("ShootGun")
local Stab = Remotes and Remotes:FindFirstChild("Stab")
local ThrowHit = Remotes and Remotes:FindFirstChild("ThrowHit")
local ThrowStart = Remotes and Remotes:FindFirstChild("ThrowStart")

-- // [2] CONFIGURATION & STATE
local S = {
    GunAuraEnabled = false, GunAuraCooldown = 0.1, WallCheck = true,
    -- [ULTRA] default 0.01s + burst可调
    KillGunEnabled = false, KillKnifeEnabled = false,
    KillGunDelay = 0.01, KillKnifeDelay = 0.01,
    KillGunBurst = 5, KillKnifeBurst = 5,
    CrashAllEnabled = false, CrashAllDelay = 0.1,
    LagEnabled = false, LagRemote = "ThrowHit", LagDelay = 0.01, LagBatch = 25,
    AntiLagEnabled = false, AntiLagLimit = 15,
    ESPEnabled = false, ESPNames = true, ESPDistance = true, ESPRange = 300,
    MovementMode = "Normal",
}

-- // [3] UTILITY FUNCTIONS
local padList, padLast = {}, 0
local function getPads()
    if tick() - padLast > 5 then
        padList = {}
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("BasePart") and d.Name:lower():find("pad") then table.insert(padList, d) end
        end
        padLast = tick()
    end
    return padList
end

local function validTarget(plr)
    if not plr or plr == LocalPlayer or not plr.Parent then return false end
    if plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then return false end
    local char = plr.Character
    if not char or not char.Parent or not char:IsDescendantOf(Workspace) then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health <= 0 or not root or not root.Parent then return false end
    local pos = root.Position
    for _, pad in ipairs(getPads()) do
        if pad and pad.Parent and (pos - pad.Position).Magnitude <= 130 then return false end
    end
    return true, root, hum, char
end

local function isKnife(t)
    if not t:IsA("Tool") then return false end
    if t:GetAttribute("ThrowSpeed") ~= nil then return true end
    local n = string.lower(t.Name)
    return n:find("knife") or n:find("blade") or n:find("karambit") or n:find("bayonet") or n:find("нож")
end

local function isGun(t)
    if not t:IsA("Tool") then return false end
    if isKnife(t) then return false end
    if t:GetAttribute("Cooldown") ~= nil then return true end
    local n = string.lower(t.Name)
    return n:find("gun") or n:find("pistol") or n:find("revolver") or n:find("shotgun")
        or n:find("rifle") or n:find("deagle") or n:find("glock") or n:find("usp") or n:find("awp") or n:find("ak") or n:find("m4")
end

local function findTool(kind, container)
    if not container then return nil end
    for _, t in ipairs(container:GetChildren()) do
        if t:IsA("Tool") then
            if kind == "gun" and isGun(t) then return t end
            if kind == "knife" and isKnife(t) then return t end
        end
    end
    return nil
end

local function equip(kind)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum then return nil end
    local held = char:FindFirstChildOfClass("Tool")
    if held then
        if kind == "gun" and isGun(held) then return held end
        if kind == "knife" and isKnife(held) then return held end
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local t = findTool(kind, char) or findTool(kind, bp)
    if t then hum:EquipTool(t) return t end
    return nil
end

local function heldGun()
    local char = LocalPlayer.Character
    local held = char and char:FindFirstChildOfClass("Tool")
    if held and isGun(held) then return held end
    return nil
end

-- // [4] VISUALS & EFFECTS
local function makeSound(id, parent, vol)
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(id)
    s.Volume = vol or 1
    s.Parent = parent or Workspace
    s:Play()
    Debris:AddItem(s, 5)
    return s
end

local tracers = {}
local function makeTracer(a, b)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Material = Enum.Material.Neon
    p.Color = Color3.new(1, 1, 1)
    p.Size = Vector3.new(0.12, 0.12, (a - b).Magnitude)
    p.CFrame = CFrame.new(a:Lerp(b, 0.5), b)
    p.Parent = Workspace
    table.insert(tracers, p)
    Debris:AddItem(p, 1.5)
end

local function clearTracers()
    for _, p in ipairs(tracers) do if p and p.Parent then p:Destroy() end end
    tracers = {}
end

LocalPlayer.CharacterAdded:Connect(function() clearTracers() end)

-- // [5] COMBAT LOGIC
local function visiblePart(plr)
    local char = LocalPlayer.Character
    local tc = plr.Character
    if not char or not tc then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local origin = root.Position + Vector3.new(0, 1.5, 0)

    local targets = {}
    local torso = tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("Torso")
    if torso then targets[#targets + 1] = torso end
    local hrp = tc:FindFirstChild("HumanoidRootPart")
    if hrp then targets[#targets + 1] = hrp end
    local head = tc:FindFirstChild("Head")
    if head then targets[#targets + 1] = head end

    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { char, Camera }
    rp.IgnoreWater = true

    for _, part in ipairs(targets) do
        local dir = part.Position - origin
        if dir.Magnitude > 0.05 then
            local hit = Workspace:Raycast(origin, dir, rp)
            if hit and hit.Instance and hit.Instance:IsDescendantOf(tc) then
                return part, hit.Position, hit.Instance
            end
        end
    end
    return nil
end

local function getBestTarget()
    local char = LocalPlayer.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil, nil, nil end

    local bestPos, bestHit, bestDist
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok, rt, hum = validTarget(plr)
        if ok and hum.Health > 0 then
            local d = (rt.Position - myRoot.Position).Magnitude
            if not bestDist or d < bestDist then
                if S.WallCheck then
                    local part, pos, hit = visiblePart(plr)
                    if part then bestPos, bestHit, bestDist = pos, hit, d end
                else
                    bestPos, bestHit, bestDist = rt.Position, rt, d
                end
            end
        end
    end
    return bestPos, bestHit, myRoot
end

local function fireAtBestTarget()
    local bestPos, bestHit, myRoot = getBestTarget()
    if bestPos and bestHit and myRoot then
        local origin = myRoot.Position + Vector3.new(0, 1.5, 0)
        makeSound(139527135965700, myRoot, 1)
        makeTracer(origin, bestPos)
        if ShootGun then ShootGun:FireServer(origin, bestPos, bestHit, bestPos) end
        return true
    end
    return false
end

-- Gun Aura Loop
local nextShot = 0
task.spawn(function()
    while true do
        task.wait(0.02)
        if S.GunAuraEnabled and not S.CrashAllEnabled and not S.KillGunEnabled and not S.KillKnifeEnabled then
            local now = tick()
            if now >= nextShot then
                if heldGun() then
                    if fireAtBestTarget() then nextShot = now + S.GunAuraCooldown
                    else nextShot = now + 0.1 end
                end
            end
        end
    end
end)

-- Crash All Loop
local function targetList()
    local out = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok, root = validTarget(plr)
        if ok then table.insert(out, {player = plr, root = root}) end
    end
    return out
end

local lagStart = nil
task.spawn(function()
    while true do
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then lagStart = nil task.wait(0.1)
        else
            if S.CrashAllEnabled then
                local list = targetList()
                local tool = equip("knife")
                if tool and #list > 0 then
                    if not lagStart then lagStart = tick() end
                    if tick() - lagStart <= 1 then
                        if ThrowStart then
                            for _, t in ipairs(list) do
                                for _ = 1, 67 do ThrowStart:FireServer(root.Position, (t.root.Position - root.Position).Unit) end
                            end
                        end
                        task.wait(S.CrashAllDelay)
                    else
                        if ThrowHit then
                            local n = math.min(#list, math.random(1, 4))
                            local pool = {table.unpack(list)}
                            local picks = {}
                            for _ = 1, n do
                                local i = math.random(1, #pool)
                                table.insert(picks, pool[i])
                                table.remove(pool, i)
                            end
                            for _, t in ipairs(picks) do ThrowHit:FireServer(t.root, t.root.Position) end
                        end
                        lagStart = nil
                        task.wait(0.5)
                    end
                else lagStart = nil task.wait(0.1) end
            else lagStart = nil task.wait(0.1) end
        end
    end
end)

-- // [5b] KILL ALL — ULTRA FAST (Heartbeat driven)
-- Burst penuh dikirim tanpa inner health-check (health tidak update dalam 1 frame)
local function killGunPass(burst)
    if not ShootGun then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    equip("gun")
    local origin = root.Position
    local n = burst or S.KillGunBurst
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok, rt, hum = validTarget(plr)
        if ok and hum.Health > 0 then
            local pos = rt.Position
            for _ = 1, n do
                ShootGun:FireServer(origin, pos, rt, pos)
            end
        end
    end
end

local function killKnifePass(burst)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    equip("knife")
    local n = burst or S.KillKnifeBurst
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok, rt, hum = validTarget(plr)
        if ok and hum.Health > 0 then
            local pos = rt.Position
            for _ = 1, n do
                if Stab then Stab:FireServer(rt) end
                if ThrowHit then ThrowHit:FireServer(rt, pos) end
            end
        end
    end
end

-- [ULTRA] Single Heartbeat connection = presisi frame-perfect, tanpa drift task.wait
local lastGunKill, lastKnifeKill = 0, 0
RunService.Heartbeat:Connect(function()
    if S.CrashAllEnabled then return end
    local now = os.clock()

    if S.KillGunEnabled and (now - lastGunKill) >= S.KillGunDelay then
        lastGunKill = now
        killGunPass(S.KillGunBurst)
    end

    -- Knife pause saat Kill Gun aktif (hindari rebutan equip tool)
    if S.KillKnifeEnabled and not S.KillGunEnabled and (now - lastKnifeKill) >= S.KillKnifeDelay then
        lastKnifeKill = now
        killKnifePass(S.KillKnifeBurst)
    end
end)

-- // [6] SERVER LAG
local function lagArgs(name)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local pos = root and root.Position or Vector3.new(0, 10, 0)
    local rnd = pos + Vector3.new(math.random(-5, 5), math.random(1, 5), math.random(-5, 5))
    if name == "ShootGun" then return {pos, rnd, Workspace, rnd}
    elseif name == "ThrowStart" then return {pos, (rnd - pos).Unit}
    elseif name == "ThrowHit" then return {Workspace, rnd}
    elseif name == "Stab" then return {Workspace} end
    return {}
end

task.spawn(function()
    local map = {ShootGun = ShootGun, ThrowStart = ThrowStart, ThrowHit = ThrowHit, Stab = Stab}
    while true do
        if S.LagEnabled then
            local tool = (S.LagRemote == "ShootGun") and equip("gun") or equip("knife")
            if tool then
                local remote = map[S.LagRemote]
                if remote then
                    local args = lagArgs(S.LagRemote)
                    for _ = 1, S.LagBatch do remote:FireServer(unpack(args)) end
                end
            end
            task.wait(S.LagDelay)
        else task.wait(0.2) end
    end
end)

-- // [6b] ANTI-LAG (Mono Hub style — lightweight, event-driven only)
local AL = {
    Enabled = false,
    MaxObjectsPerSecond = 15,
    DisablePhysics = true,
    MuteSpamSounds = true,
    Keywords = { "knife", "blade", "throw", "handle", "projectile", "tool" },
}
local alCount, alWindow = 0, os.clock()

local function alNameMatch(inst)
    if not inst then return false end
    local n = string.lower(inst.Name)
    for _, k in ipairs(AL.Keywords) do
        if n:find(k, 1, true) then return true end
    end
    return false
end

local function alIsStructure(p)
    if not p.Anchored then return false end
    local s = p.Size
    return (s.X > 12 or s.Y > 12 or s.Z > 12)
end

local function alProtected(inst)
    local a = inst.Parent
    while a and a ~= Workspace do
        if a:IsA("Tool") then return true end
        if a:IsA("Model") and Players:GetPlayerFromCharacter(a) then return true end
        a = a.Parent
    end
    return false
end

local function alHandle(d)
    if not AL.Enabled then return end

    local now = os.clock()
    if now - alWindow >= 1 then
        alCount = 0
        alWindow = now
    end

    if d:IsA("Sound") then
        if AL.MuteSpamSounds and (alCount > AL.MaxObjectsPerSecond or alNameMatch(d.Parent or d)) then
            pcall(function() d:Stop() d.Volume = 0 d:Destroy() end)
        end
        return
    end

    if d:IsA("BasePart") then
        if alIsStructure(d) then return end
        if not alNameMatch(d) then return end
        if alProtected(d) then return end
        alCount += 1
        if alCount > AL.MaxObjectsPerSecond then
            task.defer(function()
                if d and d.Parent then pcall(function() d:Destroy() end) end
            end)
        elseif AL.DisablePhysics then
            pcall(function() d.CanCollide = false d.CanTouch = false d.Massless = true end)
        end
        return
    end

    if d:IsA("Model") then
        if not alNameMatch(d) then return end
        if alProtected(d) then return end
        alCount += 1
        if alCount > AL.MaxObjectsPerSecond then
            task.defer(function()
                if d and d.Parent then pcall(function() d:Destroy() end) end
            end)
        elseif AL.DisablePhysics then
            for _, p in ipairs(d:GetDescendants()) do
                if p:IsA("BasePart") and not alIsStructure(p) then
                    pcall(function() p.CanCollide = false p.CanTouch = false p.Massless = true end)
                end
            end
        end
    end
end

Workspace.DescendantAdded:Connect(function(d)
    if not AL.Enabled then return end
    if d:IsA("BasePart") or d:IsA("Sound") or d:IsA("Model") then alHandle(d) end
end)

local function alInitialSweep()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("BasePart") or obj:IsA("Sound") or obj:IsA("Model") then alHandle(obj) end
    end
end

-- // [7] ESP SYSTEM (With Distance & Anti-Overlap)
local ESP = { Enabled = false, Range = 300, Names = true, Distance = true, Objects = {} }
local ESP_ENEMY = Color3.fromRGB(255, 60, 60)
local ESP_TEAM  = Color3.fromRGB(60, 120, 255)

local function espNearPad(pos)
    for _, pad in ipairs(getPads()) do
        if pad and pad.Parent and (pos - pad.Position).Magnitude <= 130 then return true end
    end
    return false
end

local function espMyRoot()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    if espNearPad(root.Position) then return nil end
    return root
end

local function espRemove(p)
    local o = ESP.Objects[p]
    if o then
        if o.hl then pcall(function() o.hl:Destroy() end) end
        if o.bb then pcall(function() o.bb:Destroy() end) end
        ESP.Objects[p] = nil
    end
end

local function clearLibraryESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then
            local hl = char:FindFirstChild("PlayerESP_HL")
            if hl then pcall(function() hl:Destroy() end) end
            local head = char:FindFirstChild("Head")
            if head then
                local bb = head:FindFirstChild("PlayerESP_GUI")
                if bb then pcall(function() bb:Destroy() end) end
            end
        end
    end
end

Workspace.DescendantAdded:Connect(function(d)
    if ESP.Enabled and (d.Name == "PlayerESP_GUI" or d.Name == "PlayerESP_HL") then
        task.defer(function()
            if d and d.Parent then pcall(function() d:Destroy() end) end
        end)
    end
end)

local function espCreate(p, color, dist)
    local char = p.Character
    if not char then return end
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not head then return end

    local libHL = char:FindFirstChild("PlayerESP_HL")
    if libHL then pcall(function() libHL:Destroy() end) end
    local libBB = head:FindFirstChild("PlayerESP_GUI")
    if libBB then pcall(function() libBB:Destroy() end) end

    local hl = Instance.new("Highlight")
    hl.Name = "RN_ESP"
    hl.Adornee = char
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char

    local bb, txt, dtxt
    if ESP.Names or ESP.Distance then
        bb = Instance.new("BillboardGui")
        bb.Name = "RN_ESP_Tag"
        bb.Adornee = head
        bb.Size = UDim2.new(0, 160, 0, 34)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = head

        local y = 0
        if ESP.Names then
            txt = Instance.new("TextLabel")
            txt.Size = UDim2.new(1, 0, 0, 16)
            txt.Position = UDim2.new(0, 0, 0, y)
            txt.BackgroundTransparency = 1
            txt.Text = p.Name
            txt.TextColor3 = color
            txt.TextStrokeTransparency = 0
            txt.Font = Enum.Font.GothamBold
            txt.TextSize = 12
            txt.Parent = bb
            y = y + 16
        end
        if ESP.Distance then
            dtxt = Instance.new("TextLabel")
            dtxt.Size = UDim2.new(1, 0, 0, 14)
            dtxt.Position = UDim2.new(0, 0, 0, y)
            dtxt.BackgroundTransparency = 1
            dtxt.Text = string.format("[%dm]", math.floor(dist or 0))
            dtxt.TextColor3 = Color3.new(1, 1, 1)
            dtxt.TextStrokeTransparency = 0
            dtxt.Font = Enum.Font.GothamBold
            dtxt.TextSize = 11
            dtxt.Parent = bb
        end
    end
    ESP.Objects[p] = {hl = hl, bb = bb, txt = txt, dist = dtxt, color = color}
end

local function espClearAll()
    for _, p in ipairs(Players:GetPlayers()) do espRemove(p) end
end

local function espUpdate()
    if ESP.Enabled then clearLibraryESP() end
    local myRoot = espMyRoot()
    local myTeam = LocalPlayer.Team
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then espRemove(p) continue end
        local char = p.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local show = false
        local color = ESP_ENEMY
        local dist = 0
        if myRoot and root and hum and hum.Health > 0 and not espNearPad(root.Position) then
            dist = (root.Position - myRoot.Position).Magnitude
            if dist <= ESP.Range then
                show = true
                if myTeam and p.Team and p.Team == myTeam then color = ESP_TEAM end
            end
        end
        if show then
            local o = ESP.Objects[p]
            if not o or (o.hl and o.hl.Adornee ~= char) then
                espRemove(p)
                espCreate(p, color, dist)
            else
                if o.color ~= color then
                    o.color = color
                    if o.hl then o.hl.FillColor = color o.hl.OutlineColor = color end
                    if o.txt then o.txt.TextColor3 = color end
                end
                if o.dist then o.dist.Text = string.format("[%dm]", math.floor(dist)) end
            end
        else
            espRemove(p)
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.25)
        if ESP.Enabled then espUpdate() else espClearAll() end
    end
end)
Players.PlayerRemoving:Connect(espRemove)

-- // [8] MOVEMENT SYSTEM
RunService.RenderStepped:Connect(function(dt)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    if S.MovementMode == "CFrame" and M.WalkSpeedActive and hum.MoveDirection.Magnitude > 0 then
        hum.WalkSpeed = 16
        root.CFrame = root.CFrame + hum.MoveDirection * (M.WalkSpeedValue * dt)
    end
end)

-- // [9] UI CONSTRUCTION
-- Main Tab
local Main = Window:CreateTab("Main", "crosshair")
Main:CreateSection("Auto Shoot")
Main:CreateToggle({Name = "Gun Aura", Icon = "target", Flag = "MVSD_GunAura", Default = false,
    Tooltip = "Auto shoot while holding gun; switch to knife = pause", Callback = function(v) S.GunAuraEnabled = v end})
Main:CreateToggle({Name = "Wall Check", Icon = "shield", Flag = "MVSD_WallCheck", Default = true,
    Tooltip = "Only shoot enemies you can actually see (no shooting through walls)",
    Callback = function(v) S.WallCheck = v end})
Main:CreateSlider({Name = "Auto Shoot Cooldown", Icon = "timer", Min = 0.1, Max = 6, Default = 0.1, Step = 0.05, Flag = "MVSD_GunAuraCooldown",
    Format = function(v) return string.format("%.2fs", v) end, Callback = function(v) S.GunAuraCooldown = v end})

Main:CreateSection("Kill All (Ultra Fast)")
Main:CreateToggle({Name = "Kill All Gun", Icon = "crosshair", Flag = "MVSD_KillGun", Default = false,
    Tooltip = "Heartbeat-driven burst fire. Ultra fast (0.01s). Pauses Knife kill.",
    Callback = function(v) S.KillGunEnabled = v end})
Main:CreateToggle({Name = "Kill All Knife", Icon = "sword", Flag = "MVSD_KillKnife", Default = false,
    Tooltip = "Heartbeat-driven stab/throw burst. Auto-paused if Kill Gun is ON.",
    Callback = function(v) S.KillKnifeEnabled = v end})
Main:CreateSlider({Name = "Kill Gun Delay", Icon = "timer", Min = 0.01, Max = 0.5, Default = 0.01, Step = 0.01, Flag = "MVSD_KillGunDelay",
    Format = function(v) return string.format("%.2fs", v) end, Callback = function(v) S.KillGunDelay = v end})
Main:CreateSlider({Name = "Kill Knife Delay", Icon = "timer", Min = 0.01, Max = 0.5, Default = 0.01, Step = 0.01, Flag = "MVSD_KillKnifeDelay",
    Format = function(v) return string.format("%.2fs", v) end, Callback = function(v) S.KillKnifeDelay = v end})
Main:CreateSlider({Name = "Kill Gun Burst", Icon = "layers", Min = 1, Max = 30, Default = 5, Step = 1, Flag = "MVSD_KillGunBurst",
    Format = function(v) return tostring(v) .. "x" end, Callback = function(v) S.KillGunBurst = v end})
Main:CreateSlider({Name = "Kill Knife Burst", Icon = "layers", Min = 1, Max = 30, Default = 5, Step = 1, Flag = "MVSD_KillKnifeBurst",
    Format = function(v) return tostring(v) .. "x" end, Callback = function(v) S.KillKnifeBurst = v end})
Main:CreateButton({Name = "Kill All Gun (Once)", Icon = "target",
    Callback = function() killGunPass(15) Library:Notify("Kill All Gun burst executed.", 3, "Kill All", "crosshair") end})
Main:CreateButton({Name = "Kill All Knife (Once)", Icon = "sword",
    Callback = function() killKnifePass(15) Library:Notify("Kill All Knife burst executed.", 3, "Kill All", "sword") end})
Main:CreateParagraph({Title = "Ultra Mode", Icon = "flame",
    Content = "Kill All now runs on Heartbeat (frame-perfect). Delay 0.01s + Burst 5x = up to ~300 hits/sec per enemy. Lower the burst if your device struggles."})

-- Player Tab
local Player = Window:CreateTab("Player", "user")
Player:CreateSection("Movement")
local pMove = Player:CreateToggle({Name = "Movement", Icon = "activity", Flag = "MVSD_Movement", Default = false,
    Callback = function(v) M:SetWalkSpeedActive(v) end})
local pWalk = Player:CreateSlider({Name = "Walk Speed", Icon = "gauge", Min = 0, Max = 200, Default = 16, Step = 1, Flag = "MVSD_WalkSpeed",
    Callback = function(v) M:SetWalkSpeed(v) end})
local pMode = Player:CreateDropdown({Name = "Movement Mode", Icon = "list", Options = {"Normal", "CFrame", "SafeWalk"},
    Default = "Normal", Flag = "MVSD_MoveMode", Callback = function(v) S.MovementMode = v end})

Player:CreateSection("Jump")
local pInf = Player:CreateToggle({Name = "Infinite Jump", Icon = "chevron-up", Flag = "MVSD_InfJump", Default = false,
    Callback = function(v) M:SetInfJump(v) end})
local pJumpEn = Player:CreateToggle({Name = "Jump Power", Icon = "arrow-up", Flag = "MVSD_JumpEnable", Default = false,
    Callback = function(v) M:SetJumpPowerActive(v) end})
local pJumpVal = Player:CreateSlider({Name = "Jump Power Value", Icon = "gauge", Min = 50, Max = 1000, Default = 50, Step = 1,
    Flag = "MVSD_JumpPower", Callback = function(v) M:SetJumpPower(v) end})

Player:CreateSection("ESP")
Player:CreateToggle({Name = "ESP Player", Icon = "eye", Flag = "MVSD_ESP", Default = false,
    Tooltip = "Match-only ESP. Auto-disables & destroys library ESP to prevent overlap.",
    Callback = function(v)
        S.ESPEnabled = v
        ESP.Enabled = v
        if not v then
            espClearAll()
        else
            clearLibraryESP()
            if Library and Library._elements and Library._elements["ESPPlayerToggle"] then
                local el = Library._elements["ESPPlayerToggle"]
                if el and el.Object and el.Object.Set then
                    pcall(function() el.Object:Set(false) end)
                end
            end
        end
    end})
Player:CreateToggle({Name = "ESP Names", Icon = "type", Flag = "MVSD_ESPNames", Default = true,
    Tooltip = "Show player name tags", Callback = function(v) S.ESPNames = v ESP.Names = v espClearAll() end})
Player:CreateToggle({Name = "ESP Distance", Icon = "gauge", Flag = "MVSD_ESPDistance", Default = true,
    Tooltip = "Show distance [m] under name", Callback = function(v) S.ESPDistance = v ESP.Distance = v espClearAll() end})
Player:CreateSlider({Name = "ESP Match Range", Icon = "gauge", Min = 100, Max = 2000, Default = 300, Step = 10, Flag = "MVSD_ESPRange",
    Format = function(v) return tostring(v) .. " studs" end, Callback = function(v) S.ESPRange = v ESP.Range = v end})
Player:CreateParagraph({Title = "Note", Icon = "info",
    Content = "Player tab & Quick Bar share the same engine (Library.Movement). ESP only shows your current match."})

-- Two-Way Sync for Movement
local QB = Window.QuickBarRows
local syncing = false
local function wrap(name, fn)
    local orig = M[name]
    M[name] = function(self, v, ...)
        orig(self, v, ...)
        if syncing then return end
        syncing = true pcall(fn, v) syncing = false
    end
end
wrap("SetInfJump", function(v) pInf:Set(v) if QB and QB.InfJump then QB.InfJump:Set(v) end end)
wrap("SetWalkSpeedActive", function(v) pMove:Set(v) if QB and QB.WalkToggle then QB.WalkToggle:Set(v) end end)
wrap("SetWalkSpeed", function(v) pWalk:Set(v) if QB and QB.WalkSlider then QB.WalkSlider:Set(v) end end)
wrap("SetJumpPowerActive", function(v) pJumpEn:Set(v) if QB and QB.JumpToggle then QB.JumpToggle:Set(v) end end)
wrap("SetJumpPower", function(v) pJumpVal:Set(v) if QB and QB.JumpSlider then QB.JumpSlider:Set(v) end end)

-- Misc Tab
local Misc = Window:CreateTab("Misc", "skull")
Misc:CreateSection("Crash All")
Misc:CreateToggle({Name = "Crash All", Icon = "x-circle", Flag = "MVSD_CrashAll", Default = false,
    Tooltip = "Kill enemies + lag server (knife spam). Pauses Kill All.", Callback = function(v) S.CrashAllEnabled = v end})
Misc:CreateSlider({Name = "Crash All Delay", Icon = "clock", Min = 0.06, Max = 0.3, Default = 0.1, Step = 0.01, Flag = "MVSD_CrashDelay",
    Format = function(v) return string.format("%.2fs", v) end, Callback = function(v) S.CrashAllDelay = v end})

Misc:CreateSection("Server Lag")
Misc:CreateToggle({Name = "Server Lag", Icon = "wifi", Flag = "MVSD_Lag", Default = false, Callback = function(v) S.LagEnabled = v end})
Misc:CreateDropdown({Name = "Select Remote", Icon = "send", Options = {"ThrowHit", "ThrowStart", "ShootGun", "Stab"}, Default = "ThrowHit", Flag = "MVSD_LagRemote", Callback = function(v) S.LagRemote = v end})
Misc:CreateSlider({Name = "Cooldown Send", Icon = "timer", Min = 0.01, Max = 0.5, Default = 0.01, Step = 0.01, Flag = "MVSD_LagDelay",
    Format = function(v) return string.format("%.2fs", v) end, Callback = function(v) S.LagDelay = v end})
Misc:CreateSlider({Name = "How Much Send", Icon = "layers", Min = 1, Max = 9999, Default = 25, Step = 1, Flag = "MVSD_LagBatch", Callback = function(v) S.LagBatch = v end})

Misc:CreateToggle({Name = "Anti Lag (Light)", Icon = "shield", Flag = "MVSD_AntiLag", Default = false,
    Tooltip = "Mono-style lightweight anti-lag. Event-driven only, no heavy scanning.",
    Callback = function(v)
        S.AntiLagEnabled = v
        AL.Enabled = v
        if v then
            alCount, alWindow = 0, os.clock()
            alInitialSweep()
            Library:Notify("Anti Lag ON (light mode).", 3, "Anti Lag", "shield")
        else
            Library:Notify("Anti Lag OFF.", 3, "Anti Lag", "shield")
        end
    end})
Misc:CreateSlider({Name = "Anti Lag Limit", Icon = "gauge", Min = 5, Max = 60, Default = 15, Step = 1, Flag = "MVSD_AntiLagLimit",
    Format = function(v) return tostring(v) .. "/s" end,
    Callback = function(v) S.AntiLagLimit = v AL.MaxObjectsPerSecond = v end})
Misc:CreateParagraph({Title = "Anti Lag", Icon = "info",
    Content = "Lightweight Mono-style protection: only reacts to new objects (no full workspace scans). Cleans spam knives/projectiles and mute spam sounds. Large anchored map parts, tools and characters are protected."})

Window:ToggleKeybindList(true)
Library:Notify("MVSD Ultra: Heartbeat Kill All (0.01s + burst) + Icon Tags.", 5, "Ro-Netrium", "flame")
