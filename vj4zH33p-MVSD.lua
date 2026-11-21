--[[
    RO-NETRIUM: Murderer Vs Sheriff Duels
    This script is still in the testing stage, expect bugs
    Powered: Zaycapcay & Exterminate0
    + Anti-AFK | Walk to Pad RANDOM (curved, exit-lobby-first)
]]

-- // [1] INITIALIZATION & SERVICES
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Uo2iQnNhD/Super-Database/refs/heads/main/Release-Library.luau"))()
if not Library then warn("[Ro-Netrium] Failed to load library!") return end
Library.ToggleKey = Enum.KeyCode.RightShift

local Window = Library:CreateWindow({
    Title = "Ro-Netrium", Subtitle = "Created By Zaycapcay & Exterminate0",
    Tags = {
        { Text = "MVSD",       Icon = "gamepad-2", Color = Color3.fromRGB(255,204,0), TextColor = Color3.new(0,0,0) },
        { Text = "RNET-A5", Icon = "flame",    Color = Color3.fromRGB(255,70,90), TextColor = Color3.new(1,1,1) },
        { Text = "RELEASE", Icon = "newspaper",    Color = Color3.fromRGB(0,0,255), TextColor = Color3.new(2,2,2) },
    },
    QuickBar = true, NetStatsBar = true, InfoTab = true, ToolsTab = true, ThemeTab = true, SaveLoad = true,
    ConfirmTitle = "Ro-Netrium", ConfirmSubtitle = "Close Ro-Netrium? Unsaved changes will be lost.",
})
if not Window then return end

-- // [1b] DEFAULT THEME = ROYAL (bukan RGB)
pcall(function() Library:SetTheme("Royal") end)
pcall(function()
    local tp = Library._elements and Library._elements["ZethHub_ThemePreset"]
    if tp and tp.Object and tp.Object.Set then tp.Object:Set("Royal") end
    local rb = Library._elements and Library._elements["ZethHub_Rainbow"]
    if rb and rb.Object and rb.Object.Set then rb.Object:Set(false) end
end)

Library:Notify("Ro-Netrium MVSD loaded! RightShift = show/hide.", 5, "Ro-Netrium", "sparkles")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local M = Library.Movement
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local ShootGun = Remotes and Remotes:FindFirstChild("ShootGun")
local Stab = Remotes and Remotes:FindFirstChild("Stab")
local ThrowHit = Remotes and Remotes:FindFirstChild("ThrowHit")
local ThrowStart = Remotes and Remotes:FindFirstChild("ThrowStart")

-- // [2] CONFIGURATION & STATE
local S = {
    AutoShootEnabled = false, AutoShootCooldown = 0.1, WallCheck = true,

    SilentAimEnabled = false,
    SilentAimPart = "Torso",
    SilentAimMaxDist = 400,
    SilentAimWallCheck = true,

    AutoUnanchor = false,

    KillGunEnabled = false, KillKnifeEnabled = false,
    KillGunDelay = 0.01, KillKnifeDelay = 0.01,
    KillGunBurst = 5, KillKnifeBurst = 5,

    CrashAllEnabled = false, CrashAllDelay = 0.1,

    LagEnabled = false, LagRemote = "ThrowHit", LagDelay = 0.01, LagBatch = 25,

    BurstMode = false,
    BatchMode = false,

    AntiLagEnabled = false, AntiLagLimit = 15,
    AntiLagFX = true, AntiLagSounds = true,

    ESPEnabled = false, ESPNames = true, ESPDistance = true, ESPRange = 300,
    MovementMode = "Normal",

    AntiAFK = true,
}

local function effGunBurst()   return S.BurstMode and S.KillGunBurst   or 1 end
local function effKnifeBurst() return S.BurstMode and S.KillKnifeBurst or 1 end
local function effBatch()      return S.BatchMode and S.LagBatch       or 1 end

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

local LOBBY_TEAMS = {
    lobby = true, choosing = true, choose = true, spectator = true, spectators = true,
    watching = true, watch = true, waiting = true, wait = true,
    none = true, afk = true, menu = true, idle = true,
}
local function teamOk(p)
    local t = p.Team
    if not t then return false end
    local n = string.lower(tostring(t.Name or ""))
    if n == "" or LOBBY_TEAMS[n] then return false end
    return true
end

local function nearPad(pos)
    for _, pad in ipairs(getPads()) do
        if pad and pad.Parent and (pos - pad.Position).Magnitude <= 130 then return true end
    end
    return false
end

local function myMatchRoot()
    if not teamOk(LocalPlayer) then return nil end
    local char = LocalPlayer.Character
    if not char or not char:IsDescendantOf(Workspace) then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return nil end
    if nearPad(root.Position) then return nil end
    return root
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
    p.Name = "RN_Tracer"
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
    local origin = root.Position

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
                return part, part.Position
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
                    local part, pos = visiblePart(plr)
                    if part then bestPos, bestHit, bestDist = pos, part, d end
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
        local origin = myRoot.Position
        makeSound(139527135965700, myRoot, 1)
        makeTracer(origin, bestPos)
        if ShootGun then ShootGun:FireServer(origin, bestPos, bestHit, bestPos) end
        return true
    end
    return false
end

local nextShot = 0
task.spawn(function()
    while true do
        task.wait(0.02)
        if S.AutoShootEnabled and not S.CrashAllEnabled and not S.KillGunEnabled and not S.KillKnifeEnabled then
            local now = tick()
            if now >= nextShot then
                if heldGun() then
                    if fireAtBestTarget() then nextShot = now + S.AutoShootCooldown
                    else nextShot = now + 0.1 end
                end
            end
        end
    end
end)

local function targetList()
    local out = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok, root = validTarget(plr)
        if ok then table.insert(out, {player = plr, root = root}) end
    end
    return out
end

-- // [5a] CRASH ALL
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
                                for _ = 1, 100 do
                                    ThrowStart:FireServer(root.Position, (t.root.Position - root.Position).Unit)
                                end
                            end
                        end
                        task.wait(S.CrashAllDelay)
                    else
                        local n = math.min(#list, 4)
                        for i = 1, n do
                            local t = list[i]
                            if t and t.root and t.root.Parent then
                                local pos = t.root.Position
                                if ThrowHit then ThrowHit:FireServer(t.root, pos) end
                                if Stab then Stab:FireServer(t.root) end
                            end
                        end
                        lagStart = nil
                        task.wait(0.5)
                    end
                else lagStart = nil task.wait(0.1) end
            else lagStart = nil task.wait(0.1) end
        end
    end
end)

-- // [5b] KILL ALL
local function killGunPass(burst)
    if not ShootGun then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    equip("gun")
    local origin = root.Position
    local n = burst or effGunBurst()
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
    local n = burst or effKnifeBurst()
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

local lastGunKill, lastKnifeKill = 0, 0
RunService.Heartbeat:Connect(function()
    if S.CrashAllEnabled then return end
    local now = os.clock()
    if S.KillGunEnabled and (now - lastGunKill) >= S.KillGunDelay then
        lastGunKill = now
        killGunPass()
    end
    if S.KillKnifeEnabled and not S.KillGunEnabled and (now - lastKnifeKill) >= S.KillKnifeDelay then
        lastKnifeKill = now
        killKnifePass()
    end
end)

-- // [5c] SILENT AIM
local AimEnv = (typeof(getgenv) == "function" and getgenv()) or _G

if AimEnv.RN_AimConn then
    pcall(function() AimEnv.RN_AimConn:Disconnect() end)
    AimEnv.RN_AimConn = nil
end
if AimEnv.RN_AimDrawing then
    pcall(function() AimEnv.RN_AimDrawing.Visible = false end)
    pcall(function() AimEnv.RN_AimDrawing:Remove() end)
    pcall(function() AimEnv.RN_AimDrawing:Destroy() end)
    AimEnv.RN_AimDrawing = nil
end
pcall(function()
    if Drawing and typeof(Drawing.clear) == "function" then Drawing.clear() end
end)

local function purgeAimGuis()
    local parents = {}
    pcall(function() table.insert(parents, game:GetService("CoreGui")) end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then table.insert(parents, pg) end
    end)
    if typeof(gethui) == "function" then
        pcall(function() local h = gethui(); if h then table.insert(parents, h) end end)
    end
    for _, p in ipairs(parents) do
        if p then
            for _, ch in ipairs(p:GetChildren()) do
                if ch.Name == "RN_AimCircle" then pcall(function() ch:Destroy() end) end
            end
        end
    end
end
purgeAimGuis()
task.delay(1.5, purgeAimGuis)
task.delay(4, purgeAimGuis)

local function aimCenter()
    local cam = Workspace.CurrentCamera
    if not cam then return Vector2.new(0, 0) end
    if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        return cam.ViewportSize / 2
    end
    local inset = GuiService:GetGuiInset()
    local m = UserInputService:GetMouseLocation()
    return Vector2.new(m.X + inset.X, m.Y + inset.Y)
end

local function getAimPart(char)
    if not char then return nil end
    local function pick(list)
        for _, n in ipairs(list) do
            local p = char:FindFirstChild(n)
            if p and p:IsA("BasePart") then return p end
        end
        return nil
    end
    local c = S.SilentAimPart
    if c == "Head" then
        return pick({ "Head", "HumanoidRootPart" })
    elseif c == "Arm" then
        return pick({ "RightUpperArm", "RightLowerArm", "RightHand", "Right Arm",
                      "LeftUpperArm", "LeftLowerArm", "LeftHand", "Left Arm", "HumanoidRootPart" })
    elseif c == "Leg" then
        return pick({ "RightUpperLeg", "RightLowerLeg", "RightFoot", "Right Leg",
                      "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "Left Leg", "HumanoidRootPart" })
    else
        return pick({ "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart" })
    end
end

local function firstOnScreen(cam, tc, root)
    local list = {}
    local ap = getAimPart(tc)
    if ap then list[#list + 1] = ap end
    local t2 = tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("Torso")
    local h2 = tc:FindFirstChild("Head")
    if t2 then list[#list + 1] = t2 end
    if h2 then list[#list + 1] = h2 end
    if root then list[#list + 1] = root end
    for _, p in ipairs(list) do
        if p and p.Parent then
            local sp, on = cam:WorldToViewportPoint(p.Position)
            if on and sp.Z > 0 then
                return p, Vector2.new(sp.X, sp.Y)
            end
        end
    end
    return nil
end

local function saVisible(origin, part, targetChar, baseIgnore)
    if not part or not part.Parent then return false end
    local ignore = {}
    for _, v in ipairs(baseIgnore) do ignore[#ignore + 1] = v end
    local from = origin
    for _ = 1, 8 do
        local dir = part.Position - from
        if dir.Magnitude <= 0.05 then return true end
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = ignore
        rp.IgnoreWater = true
        local hit = Workspace:Raycast(from, dir, rp)
        if not hit or not hit.Instance then return false end
        if hit.Instance:IsDescendantOf(targetChar) then return true end
        local solid, trans = true, 0
        pcall(function() solid = hit.Instance.CanCollide end)
        pcall(function() trans = hit.Instance.Transparency end)
        if (not solid) or trans >= 0.9 then
            ignore[#ignore + 1] = hit.Instance
            from = hit.Position + dir.Unit * 0.05
        else
            return false
        end
    end
    return false
end

local function silentAimFire()
    if not ShootGun then return end
    local myRoot = myMatchRoot()
    if not myRoot then return end
    if not heldGun() then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local myTeam = LocalPlayer.Team
    local center = aimCenter()
    local origin = myRoot.Position + Vector3.new(0, 1.5, 0)

    local cands = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and teamOk(plr) then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local rt = char and char:FindFirstChild("HumanoidRootPart")
            if char and hum and rt and hum.Health > 0 and char:IsDescendantOf(Workspace) then
                local d3 = (rt.Position - myRoot.Position).Magnitude
                if d3 <= S.SilentAimMaxDist and not nearPad(rt.Position) then
                    local part, sp = firstOnScreen(cam, char, rt)
                    if part and sp then
                        cands[#cands + 1] = { char = char, root = rt, part = part, sp = sp, team = plr.Team, d3 = d3 }
                    end
                end
            end
        end
    end
    if #cands == 0 then return end

    local oppTeam, oppD
    for _, c in ipairs(cands) do
        if c.team ~= myTeam and (not oppD or c.d3 < oppD) then
            oppD, oppTeam = c.d3, c.team
        end
    end
    if not oppTeam then return end

    local list = {}
    for _, c in ipairs(cands) do
        if c.team == oppTeam then
            c.aimDist = (c.sp - center).Magnitude
            list[#list + 1] = c
        end
    end
    if #list == 0 then return end
    table.sort(list, function(a, b) return a.aimDist < b.aimDist end)

    local baseIgnore = { LocalPlayer.Character, cam }
    for _, c in ipairs(list) do
        local tryParts = { c.part }
        local t2 = c.char:FindFirstChild("UpperTorso") or c.char:FindFirstChild("Torso")
        local h2 = c.char:FindFirstChild("Head")
        if t2 then tryParts[#tryParts + 1] = t2 end
        if h2 then tryParts[#tryParts + 1] = h2 end
        if c.root then tryParts[#tryParts + 1] = c.root end
        for _, p in ipairs(tryParts) do
            if p and p.Parent then
                local visible = true
                if S.SilentAimWallCheck then
                    visible = saVisible(origin, p, c.char, baseIgnore)
                end
                if visible then
                    local pos = p.Position
                    ShootGun:FireServer(origin, pos, p, pos)
                    makeTracer(origin, pos)
                    makeSound(139527135965700, myRoot, 1)
                    return
                end
            end
        end
    end
end

local lastSilentShot = 0
local function trySilentShot()
    if not S.SilentAimEnabled then return end
    if Library._confirmOpen or Library._actionOpen then return end
    local now = os.clock()
    if now - lastSilentShot < 0.12 then return end
    lastSilentShot = now
    silentAimFire()
end

AimEnv.RN_Click = function(gp)
    if gp then return end
    trySilentShot()
end
AimEnv.RN_TouchBegin = function(input, gp)
    if gp then return end
    AimEnv.RN_TouchTrack = AimEnv.RN_TouchTrack or {}
    AimEnv.RN_TouchTrack[input] = { t = os.clock(), pos = input.Position }
end
AimEnv.RN_TouchEnd = function(input)
    local tr = AimEnv.RN_TouchTrack and AimEnv.RN_TouchTrack[input]
    if AimEnv.RN_TouchTrack then AimEnv.RN_TouchTrack[input] = nil end
    if not tr then return end
    local dt = os.clock() - tr.t
    local moved = (input.Position - tr.pos).Magnitude
    if dt <= 0.25 and moved <= 12 then
        local vp = Camera.ViewportSize
        if tr.pos.X >= vp.X * 0.5 then trySilentShot() end
    end
end

if not AimEnv.RN_InputHooked then
    UserInputService.InputBegan:Connect(function(input, gp)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if AimEnv.RN_Click then AimEnv.RN_Click(gp) end
        elseif input.UserInputType == Enum.UserInputType.Touch then
            if AimEnv.RN_TouchBegin then AimEnv.RN_TouchBegin(input, gp) end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            if AimEnv.RN_TouchEnd then AimEnv.RN_TouchEnd(input) end
        end
    end)
    AimEnv.RN_InputHooked = true
end

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
                    for _ = 1, effBatch() do remote:FireServer(unpack(args)) end
                end
            end
            task.wait(S.LagDelay)
        else task.wait(0.2) end
    end
end)

-- // [6b] ANTI-LAG v2
local AL = {
    Enabled = false, RemoveFX = true, MuteSounds = true, MaxObjectsPerSecond = 15,
    Keywords = {
        "knife","blade","throw","handle","projectile","tool",
        "bullet","tracer","muzzle","flash","impact","spark","smoke",
        "casing","shell","beam","trail","shot","fx","vfx","effect","blood","debris",
    },
}
local FX_CLASS = {
    ParticleEmitter = true, Trail = true, Beam = true,
    Fire = true, Smoke = true, Sparkles = true,
    PointLight = true, SpotLight = true, SurfaceLight = true,
    Explosion = true,
}
local alCount, alWindow = 0, os.clock()
local alSpamUntil = 0

local function alNameMatch(inst)
    if not inst then return false end
    local ok, n = pcall(function() return string.lower(inst.Name) end)
    if not ok or not n then return false end
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
local function alIsSmall(p)
    local s = p.Size
    return (s.X <= 6 and s.Y <= 6 and s.Z <= 6)
end
local function alLooksLikeTracer(p)
    if not p.Anchored or p.CanCollide then return false end
    local s = p.Size
    if math.max(s.X, s.Y, s.Z) < 3 then return false end
    local thin = 0
    if s.X <= 0.7 then thin += 1 end
    if s.Y <= 0.7 then thin += 1 end
    if s.Z <= 0.7 then thin += 1 end
    return thin >= 2
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
local function alDestroy(inst)
    task.defer(function()
        if inst and inst.Parent then pcall(function() inst:Destroy() end) end
    end)
end
local function alHandle(d)
    if not AL.Enabled then return end
    if d.Name == "RN_Tracer" or d.Name == "RN_ESP" or d.Name == "RN_ESP_Tag" then return end
    local now = os.clock()
    if now - alWindow >= 1 then alCount = 0 alWindow = now end
    alCount += 1
    if alCount > AL.MaxObjectsPerSecond then alSpamUntil = now + 2 end
    local spam = now < alSpamUntil
    if d:IsA("Sound") then
        if AL.MuteSounds and (spam or alNameMatch(d) or alNameMatch(d.Parent)) then
            pcall(function() d:Stop() d.Volume = 0 end)
            alDestroy(d)
        end
        return
    end
    if FX_CLASS[d.ClassName] then
        if not AL.RemoveFX then return end
        local par = d.Parent
        if not spam and par and par:IsA("BasePart") and alIsStructure(par) then return end
        if spam or alNameMatch(d) or alNameMatch(par) then
            pcall(function() d.Enabled = false end)
            alDestroy(d)
        end
        return
    end
    if d:IsA("BasePart") then
        if alIsStructure(d) then return end
        local nameMatch = alNameMatch(d)
        local tracer = AL.RemoveFX and alLooksLikeTracer(d)
        if d.Anchored then
            if not (tracer or (nameMatch and alIsSmall(d))) then return end
        else
            if not (nameMatch or tracer or spam) then return end
        end
        if alProtected(d) then return end
        alDestroy(d)
        return
    end
    if d:IsA("Model") then
        if not alNameMatch(d) then return end
        if alProtected(d) then return end
        alDestroy(d)
    end
end
Workspace.DescendantAdded:Connect(function(d)
    if not AL.Enabled then return end
    alHandle(d)
end)
local function alInitialSweep()
    for _, obj in ipairs(Workspace:GetChildren()) do
        alHandle(obj)
        if obj:IsA("Model") or obj:IsA("Folder") then
            for _, ch in ipairs(obj:GetChildren()) do alHandle(ch) end
        end
    end
end

-- // [7] ESP SYSTEM
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
        local show, color, dist = false, ESP_ENEMY, 0
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

-- // [8b] AUTO UNANCHOR
RunService.Stepped:Connect(function()
    if not S.AutoUnanchor then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.Anchored then
            pcall(function() p.Anchored = false end)
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            if hum.PlatformStand then hum.PlatformStand = false end
            if hum.Sit then hum.Sit = false end
            if hum.WalkSpeed == 0 then
                hum.WalkSpeed = (M.WalkSpeedActive and M.WalkSpeedValue or 16)
            end
            if hum.UseJumpPower and hum.JumpPower == 0 then
                hum.JumpPower = (M.JumpPowerActive and M.JumpPowerValue or 50)
            end
            if not hum.UseJumpPower and hum.JumpHeight == 0 then
                hum.JumpHeight = 7.2
            end
        end)
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        for _, c in ipairs(root:GetChildren()) do
            if c:IsA("BodyPosition") or c:IsA("BodyGyro")
                or c:IsA("AlignPosition") or c:IsA("AlignOrientation") then
                pcall(function() c:Destroy() end)
            end
        end
    end
end)

-- // [8c] ANTI-AFK + DUEL PAD WALKER (RANDOM PAD)
local OUTSIDE_CF = CFrame.new(1, -504, 290) -- titik di luar lobby

-- Seed random supaya pilihan pad tidak monoton saat re-execute
pcall(function()
    math.randomseed(math.floor((os.clock() * 1000) % 2147483647))
    math.random()
end)

-- [RANDOM] Daftar pad tetap per mode: Bagian 1 (kanan/kiri) + Bagian 2 (kiri/kanan)
local DUEL_PADS = {
    ["1v1"] = {
        { pos = Vector3.new(-13, -504, 295), side = "Kanan", section = 1 },
        { pos = Vector3.new(-13, -504, 301), side = "Kiri",  section = 1 },
        { pos = Vector3.new(17,  -504, 294), side = "Kiri",  section = 2 },
        { pos = Vector3.new(16,  -504, 299), side = "Kanan", section = 2 },
    },
    ["2v2"] = {
        { pos = Vector3.new(-12, -504, 308), side = "Kanan", section = 1 },
        { pos = Vector3.new(-12, -504, 315), side = "Kiri",  section = 1 },
        { pos = Vector3.new(17,  -504, 308), side = "Kiri",  section = 2 },
        { pos = Vector3.new(17,  -504, 315), side = "Kanan", section = 2 },
    },
    ["3v3"] = {
        { pos = Vector3.new(-11, -504, 325), side = "Kanan", section = 1 },
        { pos = Vector3.new(-10, -504, 331), side = "Kiri",  section = 1 },
        { pos = Vector3.new(17,  -504, 324), side = "Kiri",  section = 2 },
        { pos = Vector3.new(17,  -504, 331), side = "Kanan", section = 2 },
    },
    ["4v4"] = {
        { pos = Vector3.new(-10, -504, 343), side = "Kanan", section = 1 },
        { pos = Vector3.new(-9,  -504, 351), side = "Kiri",  section = 1 },
        { pos = Vector3.new(16,  -504, 342), side = "Kiri",  section = 2 },
        { pos = Vector3.new(16,  -504, 350), side = "Kanan", section = 2 },
    },
}

-- Anti-AFK: reset idle timer supaya tidak ke-kick 20 menit
LocalPlayer.Idled:Connect(function()
    if not S.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end)
task.spawn(function()
    while true do
        task.wait(60)
        if S.AntiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
    end
end)

local function insideLobby(root)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { LocalPlayer.Character }
    rp.IgnoreWater = true
    local dir = OUTSIDE_CF.Position - root.Position
    if dir.Magnitude > 5 then
        local hit = Workspace:Raycast(root.Position, dir, rp)
        if hit and hit.Instance and hit.Instance.CanCollide then return true end
    end
    local up = Workspace:Raycast(root.Position, Vector3.new(0, 60, 0), rp)
    if up and up.Instance and up.Instance.CanCollide then return true end
    return false
end

local RN_Walk = { active = false, cancel = false }
local function walkRoute(points)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    RN_Walk.active = true
    RN_Walk.cancel = false
    for _, wp in ipairs(points) do
        if RN_Walk.cancel then break end
        hum:MoveTo(wp)
        local t0 = os.clock()
        local last = root.Position
        local stuck = 0
        while os.clock() - t0 < 10 do
            task.wait(0.1)
            if RN_Walk.cancel then break end
            local cur = root.Position
            if (cur - wp).Magnitude < 5 then break end
            if (cur - last).Magnitude < 0.3 then
                stuck += 0.1
                if stuck >= 0.8 then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    stuck = 0
                end
            else
                stuck = 0
            end
            last = cur
        end
    end
    RN_Walk.active = false
    return true
end

local function walkToPadPos(pos)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    -- kalau di dalam lobby: keluar dulu (CFrame ke titik luar), baru walk
    if insideLobby(root) then
        root.CFrame = OUTSIDE_CF + Vector3.new(0, 3, 0)
        task.wait(0.15)
        char = LocalPlayer.Character
        root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
    end
    local start = root.Position
    local target = pos + Vector3.new(0, 3, 0)
    local dir = target - start
    local perp = Vector3.new(-dir.Z, 0, dir.X)
    if perp.Magnitude > 1 then
        perp = perp.Unit * math.clamp(dir.Magnitude * 0.12, 4, 18)
    else
        perp = Vector3.new(0, 0, 0)
    end
    local mid = start:Lerp(target, 0.5) + perp
    local pts = { OUTSIDE_CF.Position + Vector3.new(0, 3, 0), mid, target }
    if (start - pts[1]).Magnitude < 8 then table.remove(pts, 1) end
    walkRoute(pts)
end

-- [RANDOM] Pilih acak salah satu pad dari mode yang dipilih
local function walkToRing(mode)
    local list = DUEL_PADS[tostring(mode)]
    if not list or #list == 0 then
        Library:Notify("Pad " .. tostring(mode) .. " not found.", 3, "Duel", "x-circle")
        return
    end
    local pick = list[math.random(1, #list)]
    Library:Notify("Walking to " .. mode .. " pad (Bagian " .. pick.section .. " - " .. pick.side .. ")", 4, "Duel", "navigation")
    walkToPadPos(pick.pos)
end

-- // [9] SLIDER LOCK HELPER
local function setSliderEnabled(flag, enabled, lockText)
    local el = Library._elements and Library._elements[flag]
    if not el or not el.Frame then return end
    local f = el.Frame
    local gate = f:FindFirstChild("RN_Gate")
    if not gate then
        gate = Instance.new("Frame")
        gate.Name = "RN_Gate"
        gate.Size = UDim2.new(1, 0, 1, 0)
        gate.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
        gate.BackgroundTransparency = 0.35
        gate.BorderSizePixel = 0
        gate.ZIndex = 60
        gate.Active = true
        gate.Parent = f
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = gate
        local lbl = Instance.new("TextLabel")
        lbl.Name = "LockLabel"
        lbl.Size = UDim2.new(1, -12, 1, 0)
        lbl.Position = UDim2.new(0, 6, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = lockText or "LOCKED"
        lbl.TextColor3 = Color3.fromRGB(235, 235, 240)
        lbl.TextTransparency = 0.15
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.ZIndex = 61
        lbl.Parent = gate
    end
    local lbl = gate:FindFirstChild("LockLabel")
    if lbl and lockText then lbl.Text = lockText end
    gate.Visible = not enabled
end

local function applyGates()
    setSliderEnabled("MVSD_KillGunBurst",   S.BurstMode, "🔒  Enable BURST MODE first")
    setSliderEnabled("MVSD_KillKnifeBurst", S.BurstMode, "🔒  Enable BURST MODE first")
    setSliderEnabled("MVSD_LagBatch",       S.BatchMode, "🔒  Enable BATCH MODE first")
end

-- // [9b] ACTION ADAPTER
local function showAction(cfg)
    local yes = cfg.ConfirmText or "Apply"
    local no  = cfg.CancelText or "Revert"
    local payload = {
        Title = cfg.Title,
        Content = cfg.Content, Text = cfg.Content, Message = cfg.Content, Desc = cfg.Content,
        Icon = cfg.Icon or "triangle-alert",
        Danger = true,
        ConfirmText = yes, YesText = yes, OkText = yes,
        CancelText = no,  NoText = no,
        OnConfirm = cfg.OnConfirm, OnYes = cfg.OnConfirm, Callback = cfg.OnConfirm,
        OnCancel = cfg.OnCancel,  OnNo = cfg.OnCancel,
        RequireConfirm = true,
    }
    local targets = {
        { o = Library, n = "Action" }, { o = Library, n = "ShowAction" },
        { o = Library, n = "ShowActionConfirm" }, { o = Library, n = "ActionConfirm" },
        { o = Library, n = "Confirm" }, { o = Window, n = "Action" },
        { o = Window, n = "ShowAction" }, { o = Window, n = "ShowActionConfirm" },
        { o = Window, n = "ActionConfirm" }, { o = Window, n = "Confirm" },
    }
    for _, t in ipairs(targets) do
        local fn = t.o and t.o[t.n]
        if type(fn) == "function" then
            if pcall(fn, t.o, payload) then return true end
            if pcall(fn, payload) then return true end
        end
    end
    return false
end

local lastBurstPrompt = 0
local function burstGuard(kind, value, flag, apply)
    apply(value)
    if value <= 20 then return end
    if Library._actionOpen or Library._confirmOpen then return end
    local now = os.clock()
    if now - lastBurstPrompt < 2 then return end
    lastBurstPrompt = now
    local shown = showAction({
        Title = "High Burst Warning",
        Content = string.format(
            "%dx %s burst is above the safe limit (20x).\nThis can cause heavy character delay / rubber-banding and high ping.\n\nApply anyway?",
            value, kind),
        Icon = "triangle-alert",
        ConfirmText = "Apply", CancelText = "Revert",
        OnConfirm = function()
            Library:Notify(value .. "x " .. kind .. " burst applied. Watch your ping!", 4, "Kill All", "flame")
        end,
        OnCancel = function()
            apply(20)
            local el = Library._elements and Library._elements[flag]
            if el and el.Object and el.Object.Set then
                pcall(function() el.Object:Set(20) end)
            end
            Library:Notify("Reverted to 20x (safe limit).", 3, "Kill All", "shield")
        end,
    })
    if not shown then
        Library:Notify("Warning: " .. value .. "x " .. kind .. " burst WILL cause character delay!", 5, "Kill All", "triangle-alert")
    end
end

-- // [9c] INTERFACE VISIBILITY HELPERS
local function findLibGui()
    local parents = {}
    pcall(function() table.insert(parents, game:GetService("CoreGui")) end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then table.insert(parents, pg) end
    end)
    if typeof(gethui) == "function" then
        pcall(function() local h = gethui(); if h then table.insert(parents, h) end end)
    end
    for _, p in ipairs(parents) do
        if p then
            local g = p:FindFirstChild("ZethHubV5")
            if g then return g end
        end
    end
    return nil
end
local function setNamedVisible(names, v)
    local g = findLibGui()
    if not g then return end
    for _, d in ipairs(g:GetDescendants()) do
        for _, n in ipairs(names) do
            if d.Name == n and d:IsA("GuiObject") then
                pcall(function() d.Visible = v end)
            end
        end
    end
end
local function setKeybindList(v)
    if Window and Window.ToggleKeybindList then
        pcall(function() Window:ToggleKeybindList(v) end)
    else
        setNamedVisible({"KeybindList"}, v)
    end
end
local function setQuickBar(v)
    if Window and Window.SetQuickBarVisible then
        pcall(function() Window:SetQuickBarVisible(v) end)
    else
        setNamedVisible({"QuickBar"}, v)
    end
end
local function setNetStats(v)
    if Window and Window.SetNetStatsBarVisible then
        pcall(function() Window:SetNetStatsBarVisible(v) end)
    else
        setNamedVisible({"NetStatsBar", "NetStatsOuter", "NetStatsInner", "SidebarNetStats"}, v)
    end
end

-- // [10] UI CONSTRUCTION
local Main = Window:CreateTab("Main", "crosshair")
local Binds = Window:CreateTab("Keybind", "key")

Main:CreateSection("Auto Shoot")
local tAutoShoot = Main:CreateToggle({Name = "Auto Shoot", Icon = "target", Flag = "MVSD_AutoShoot", Default = false,
    Tooltip = "Automatically shoots the nearest enemy while holding a gun, knife = pause When auto shoot on",
    Callback = function(v) S.AutoShootEnabled = v end})
Main:CreateToggle({Name = "Wall Check", Icon = "shield", Flag = "MVSD_WallCheck", Default = true,
    Tooltip = "Only shoot enemies you can actually see",
    Callback = function(v) S.WallCheck = v end})
Main:CreateSlider({Name = "Auto Shoot Cooldown", Icon = "timer", Min = 0.1, Max = 6, Default = 0.1, Step = 0.05, Flag = "MVSD_AutoShootCooldown",
    Format = function(v) return string.format("%.2fs", v) end, Callback = function(v) S.AutoShootCooldown = v end})

Main:CreateSection("Silent Aim (Manual)")
local tSilentAim = Main:CreateToggle({Name = "Enable Silent Aim Manual", Icon = "crosshair", Flag = "MVSD_SilentAim", Default = false,
    Tooltip = "On-screen method: each manual click hits ONE enemy nearest to your aim",
    Callback = function(v)
        S.SilentAimEnabled = v
        Library:Notify(v and "Silent Aim ON, 1 target per click" or "Silent Aim OFF.", 3, "Silent Aim", "crosshair")
    end})
Main:CreateToggle({Name = "Silent Aim Wall Check", Icon = "shield", Flag = "MVSD_SilentWall", Default = true,
    Tooltip = "ON = bullets never go through walls, If the closest enemy is blocked, it tries the next one",
    Callback = function(v) S.SilentAimWallCheck = v end})
Main:CreateDropdown({Name = "Aim Part", Icon = "user", Options = {"Leg", "Arm", "Torso", "Head"},
    Default = "Torso", Flag = "MVSD_SilentPart",
    Callback = function(v) S.SilentAimPart = v end})
Main:CreateSlider({Name = "Aim Max Distance", Icon = "gauge", Min = 50, Max = 1500, Default = 400, Step = 10, Flag = "MVSD_SilentMaxDist",
    Format = function(v) return tostring(v) .. " studs" end,
    Callback = function(v) S.SilentAimMaxDist = v end})
Main:CreateParagraph({Title = "Silent Aim Info", Icon = "info",
    Content = "On-Screen Method, and it only works while you actually hold a gun and click Anywhere\nTargets are limited to the enemy team of Your match within Aim Max Distance\nEach click hits ONE enemy nearest to your aim point"})

Main:CreateSection("Kill All (Ultra Fast)")
local tKillGun = Main:CreateToggle({Name = "Kill All Gun", Icon = "crosshair", Flag = "MVSD_KillGun", Default = false,
    Tooltip = "High-speed shooting, Pauses Knife kill",
    Callback = function(v) S.KillGunEnabled = v end})
local tKillKnife = Main:CreateToggle({Name = "Kill All Knife", Icon = "sword", Flag = "MVSD_KillKnife", Default = false,
    Tooltip = "Throwing at high speed, Auto-paused if Kill Gun is ON",
    Callback = function(v) S.KillKnifeEnabled = v end})
Main:CreateSlider({Name = "Kill Gun Delay", Icon = "timer", Min = 0.01, Max = 0.5, Default = 0.01, Step = 0.01, Flag = "MVSD_KillGunDelay",
    Format = function(v) return string.format("%.2fs", v) end, Callback = function(v) S.KillGunDelay = v end})
Main:CreateSlider({Name = "Kill Knife Delay", Icon = "timer", Min = 0.01, Max = 0.5, Default = 0.01, Step = 0.01, Flag = "MVSD_KillKnifeDelay",
    Format = function(v) return string.format("%.2fs", v) end, Callback = function(v) S.KillKnifeDelay = v end})

Main:CreateToggle({Name = "Burst Mode", Icon = "layers", Flag = "MVSD_BurstMode", Default = false,
    Tooltip = "Unlocks the burst sliders below, OFF = 1 hit per tick/Back to Normal",
    Callback = function(v)
        S.BurstMode = v
        applyGates()
        if v then
            Library:Notify("Burst Mode ON, burst sliders unlocked", 4, "Burst", "layers")
        else
            Library:Notify("Burst Mode OFF, burst forced to 1x", 3, "Burst", "shield")
        end
    end})
Main:CreateSlider({Name = "Kill Gun Burst", Icon = "layers", Min = 1, Max = 30, Default = 5, Step = 1, Flag = "MVSD_KillGunBurst",
    Format = function(v) return tostring(v) .. "x" end,
    Callback = function(v) burstGuard("Gun", v, "MVSD_KillGunBurst", function(n) S.KillGunBurst = n end) end})
Main:CreateSlider({Name = "Kill Knife Burst", Icon = "layers", Min = 1, Max = 30, Default = 5, Step = 1, Flag = "MVSD_KillKnifeBurst",
    Format = function(v) return tostring(v) .. "x" end,
    Callback = function(v) burstGuard("Knife", v, "MVSD_KillKnifeBurst", function(n) S.KillKnifeBurst = n end) end})
Main:CreateButton({Name = "Kill All Gun (Once)", Icon = "target",
    Callback = function() killGunPass() Library:Notify("Kill All Gun burst executed.", 3, "Kill All", "crosshair") end})
Main:CreateButton({Name = "Kill All Knife (Once)", Icon = "sword",
    Callback = function() killKnifePass() Library:Notify("Kill All Knife burst executed.", 3, "Kill All", "sword") end})
Main:CreateParagraph({Title = "⚠️ Burst Warning", Icon = "triangle-alert",
    Content = "Burst sliders are LOCKED until Burst Mode is ON, Recommended: keep Burst Mode OFF for normal use, or 5x-10x if you need extra power"})

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

Player:CreateSection("Character")
local tUnanchor = Player:CreateToggle({Name = "Auto Unanchor Character", Icon = "unlock", Flag = "MVSD_AutoUnanchor", Default = false,
    Tooltip = "Can Move during the 5-second prep freeze",
    Callback = function(v)
        S.AutoUnanchor = v
        Library:Notify(v and "Auto Unanchor ON, you can move during prep." or "Auto Unanchor OFF.", 3, "Character", "unlock")
    end})
Player:CreateParagraph({Title = "Auto Unanchor", Icon = "info",
    Content = "Keeps your character unanchored and removes freeze constraints, Lets you move during the 5s pre-round countdown"})

Player:CreateSection("Anti AFK")
Player:CreateToggle({Name = "Anti AFK / Idle", Icon = "timer", Flag = "MVSD_AntiAFK", Default = true,
    Tooltip = "Prevents the 20-minute idle kick by simulating activity",
    Callback = function(v)
        S.AntiAFK = v
        Library:Notify(v and "Anti AFK ON, you will not be idle-kicked." or "Anti AFK OFF.", 3, "Anti AFK", "timer")
    end})
Player:CreateParagraph({Title = "Anti AFK", Icon = "info",
    Content = "Resets the idle timer periodically so the 20-minute AFK kick never triggers. Keep ON while idling in lobby."})

Player:CreateSection("ESP")
Player:CreateToggle({Name = "ESP Player", Icon = "eye", Flag = "MVSD_ESP", Default = false,
    Tooltip = "Match-only ESP, Auto-disables & destroys library ESP to prevent overlap",
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
    Content = "Player tab & Quick Bar share the same engine, ESP only shows your current match"})

-- Two-Way Sync for Movement
local QB = Window.QuickBarRows
if not AimEnv.RN_MWrapped then
    AimEnv.RN_MWrapped = true
    local function wrap(name, key)
        local orig = M[name]
        M[name] = function(self, v, ...)
            orig(self, v, ...)
            if AimEnv.RN_Syncing then return end
            AimEnv.RN_Syncing = true
            local tg = AimEnv.RN_SyncTargets or {}
            local obj = tg[key]
            if obj and obj.Set then pcall(obj.Set, obj, v) end
            AimEnv.RN_Syncing = false
        end
    end
    wrap("SetInfJump", "InfJump")
    wrap("SetWalkSpeedActive", "Move")
    wrap("SetWalkSpeed", "Walk")
    wrap("SetJumpPowerActive", "JumpEn")
    wrap("SetJumpPower", "JumpVal")
end
AimEnv.RN_SyncTargets = { InfJump = pInf, Move = pMove, Walk = pWalk, JumpEn = pJumpEn, JumpVal = pJumpVal }

-- Misc Tab
local Misc = Window:CreateTab("Misc", "skull")

Misc:CreateSection("Crash All")
local tCrashAll = Misc:CreateToggle({Name = "Crash All", Icon = "x-circle", Flag = "MVSD_CrashAll", Default = false,
    Tooltip = "100 knife throws per enemy, Pauses Kill All & Auto Shoot.",
    Callback = function(v) S.CrashAllEnabled = v lagStart = nil end})
Misc:CreateSlider({Name = "Crash All Delay", Icon = "clock", Min = 0.06, Max = 0.3, Default = 0.1, Step = 0.01, Flag = "MVSD_CrashDelay",
    Format = function(v) return string.format("%.2fs", v) end, Callback = function(v) S.CrashAllDelay = v end})
Misc:CreateParagraph({Title = "Crash Mode (Super)", Icon = "flame",
    Content = "100 knife throws per enemy each tick for 1s\nKill Phase: hits 4 enemies, then waits 0.5s, Repeats automatically"})

Misc:CreateSection("Server Lag")
Misc:CreateToggle({Name = "Server Lag", Icon = "wifi", Flag = "MVSD_Lag", Default = false,
    Tooltip = "Spams the selected remote using How Much Send.",
    Callback = function(v) S.LagEnabled = v end})
Misc:CreateDropdown({Name = "Select Remote", Icon = "send", Options = {"ThrowHit", "ThrowStart", "ShootGun", "Stab"}, Default = "ThrowHit", Flag = "MVSD_LagRemote", Callback = function(v) S.LagRemote = v end})
Misc:CreateSlider({Name = "Cooldown Send", Icon = "timer", Min = 0.01, Max = 0.5, Default = 0.01, Step = 0.01, Flag = "MVSD_LagDelay",
    Format = function(v) return string.format("%.2fs", v) end, Callback = function(v) S.LagDelay = v end})
Misc:CreateToggle({Name = "Batch Mode", Icon = "layers", Flag = "MVSD_BatchMode", Default = false,
    Tooltip = "Unlocks How Much Send, OFF = 1 remote per tick/back to normal",
    Callback = function(v)
        S.BatchMode = v
        applyGates()
        if v then
            Library:Notify("Batch Mode ON, How Much Send unlocked, This is the main delay source", 5, "Server Lag", "triangle-alert")
        else
            Library:Notify("Batch Mode OFF, send forced to 1", 3, "Server Lag", "shield")
        end
    end})
Misc:CreateSlider({Name = "How Much Send", Icon = "layers", Min = 1, Max = 9999, Default = 25, Step = 1, Flag = "MVSD_LagBatch",
    Format = function(v) return tostring(v) .. "x" end,
    Callback = function(v) S.LagBatch = v
        if v > 100 then
            Library:Notify("Warning: " .. v .. "x send batch is very heavy — expect delay!", 5, "Server Lag", "triangle-alert")
        end
    end})
Misc:CreateParagraph({Title = "⚠️ Delay Source", Icon = "triangle-alert",
    Content = "How Much Send only affects Server Lag now, Start at 5-25x. Above 100x causes heavy character delay/nDo not stack high Batch with high Burst Mode"})

Misc:CreateSection("Anti Lag")
Misc:CreateToggle({Name = "Anti Lag", Icon = "shield", Flag = "MVSD_AntiLag", Default = false,
    Tooltip = "Removes enemy gun-shot VFX spam (tracers, muzzle flash, impacts) that lags mobile",
    Callback = function(v)
        S.AntiLagEnabled = v
        AL.Enabled = v
        if v then
            alCount, alWindow, alSpamUntil = 0, os.clock(), 0
            alInitialSweep()
            Library:Notify("Anti Lag ON, gun FX spam will be cleaned", 3, "Anti Lag", "shield")
        else
            Library:Notify("Anti Lag OFF.", 3, "Anti Lag", "shield")
        end
    end})
Misc:CreateToggle({Name = "Remove Gun FX", Icon = "sparkles", Flag = "MVSD_AntiLagFX", Default = true,
    Tooltip = "Remove all visual effects\nReducing lag when enemies kill all used gun",
    Callback = function(v) S.AntiLagFX = v AL.RemoveFX = v end})
Misc:CreateToggle({Name = "Mute Spam Sounds", Icon = "bell", Flag = "MVSD_AntiLagSounds", Default = true,
    Tooltip = "Mute & remove gunshot sound spam",
    Callback = function(v) S.AntiLagSounds = v AL.MuteSounds = v end})
Misc:CreateSlider({Name = "Anti Lag Limit", Icon = "gauge", Min = 5, Max = 60, Default = 15, Step = 1, Flag = "MVSD_AntiLagLimit",
    Format = function(v) return tostring(v) .. "/s" end,
    Callback = function(v) S.AntiLagLimit = v AL.MaxObjectsPerSecond = v end})
Misc:CreateParagraph({Title = "Anti Lag", Icon = "info",
    Content = "Detecting spam parts/visual effects, Such as gun sound, Gun FX, etc."})

-- // [10b] DUEL TAB (RANDOM PAD ONLY)
local Duel = Window:CreateTab("Duel", "gamepad-2")
Duel:CreateSection("Walk to Pad (Random)")
Duel:CreateButton({Name = "Walk to Pad 1v1", Icon = "navigation",
    Callback = function() task.spawn(walkToRing, "1v1") end})
Duel:CreateButton({Name = "Walk to Pad 2v2", Icon = "navigation",
    Callback = function() task.spawn(walkToRing, "2v2") end})
Duel:CreateButton({Name = "Walk to Pad 3v3", Icon = "navigation",
    Callback = function() task.spawn(walkToRing, "3v3") end})
Duel:CreateButton({Name = "Walk to Pad 4v4", Icon = "navigation",
    Callback = function() task.spawn(walkToRing, "4v4") end})
Duel:CreateButton({Name = "Stop Walking", Icon = "x-circle",
    Callback = function() RN_Walk.cancel = true Library:Notify("Walk cancelled", 2, "Duel", "x-circle") end})
Duel:CreateParagraph({Title = "Walk Info", Icon = "info",
    Content = "Each click picks a RANDOM pad for that mode (Bagian 1 or Bagian 2, Kiri or Kanan)\nWalks a curved (non-straight) route: exit lobby first if inside, then arc around to the pad\nAuto-jumps when stuck on obstacles"})

-- // [11] KEYBIND TAB
Binds:CreateSection("Combat Binds")
Binds:CreateKeybind({Name = "Kill All Gun", Icon = "crosshair", Flag = "Bind_KillGun",
    CurrentKeybind = Enum.KeyCode.G, Tooltip = "Toggle Kill All Gun ON/OFF",
    Callback = function() tKillGun:Set(not S.KillGunEnabled) end})
Binds:CreateKeybind({Name = "Kill All Knife", Icon = "sword", Flag = "Bind_KillKnife",
    CurrentKeybind = Enum.KeyCode.H, Tooltip = "Toggle Kill All Knife ON/OFF",
    Callback = function() tKillKnife:Set(not S.KillKnifeEnabled) end})
Binds:CreateKeybind({Name = "Crash All", Icon = "x-circle", Flag = "Bind_CrashAll",
    CurrentKeybind = Enum.KeyCode.J, Tooltip = "Toggle Crash All ON/OFF",
    Callback = function() tCrashAll:Set(not S.CrashAllEnabled) end})
Binds:CreateKeybind({Name = "Auto Shoot", Icon = "target", Flag = "Bind_AutoShoot",
    CurrentKeybind = Enum.KeyCode.K, Tooltip = "Toggle Auto Shoot ON/OFF",
    Callback = function() tAutoShoot:Set(not S.AutoShootEnabled) end})
Binds:CreateKeybind({Name = "Silent Aim Manual", Icon = "crosshair", Flag = "Bind_SilentAim",
    CurrentKeybind = Enum.KeyCode.Y, Tooltip = "Toggle Silent Aim Manual ON/OFF",
    Callback = function() if tSilentAim then tSilentAim:Set(not S.SilentAimEnabled) end end})
Binds:CreateKeybind({Name = "Auto Unanchor", Icon = "unlock", Flag = "Bind_Unanchor",
    CurrentKeybind = Enum.KeyCode.U, Tooltip = "Toggle Auto Unanchor Character ON/OFF",
    Callback = function() if tUnanchor then tUnanchor:Set(not S.AutoUnanchor) end end})

Binds:CreateSection("Interface & Visibility")
Binds:CreateKeybind({Name = "Hide/Show Interface", Icon = "eye", Flag = "Bind_ToggleUI",
    CurrentKeybind = Enum.KeyCode.RightControl, Tooltip = "Toggle the whole interface",
    Callback = function() Window:Toggle() end})
Binds:CreateToggle({Name = "Show Keybind List", Icon = "key", Flag = "RN_ShowKeybindList", Default = not IS_MOBILE,
    Tooltip = "Show/hide the floating Keybinds panel",
    Callback = function(v) setKeybindList(v) end})
Binds:CreateToggle({Name = "Show Quick Bar 1", Icon = "gauge", Flag = "RN_ShowQuickBar", Default = not IS_MOBILE,
    Tooltip = "Show/hide the floating Quick Bar panel",
    Callback = function(v) setQuickBar(v) end})
Binds:CreateToggle({Name = "Show Net Performance", Icon = "activity", Flag = "RN_ShowNetStats", Default = not IS_MOBILE,
    Tooltip = "Show/hide the Net performance panel",
    Callback = function(v) setNetStats(v) end})
Binds:CreateParagraph({Title = "How to use", Icon = "info",
    Content = "Click the key badge on the right to rebind any key, Use the Visibility toggles above to hide Quick bar, Net Performance, Keybind"})

setKeybindList(not IS_MOBILE)
setQuickBar(not IS_MOBILE)
setNetStats(not IS_MOBILE)

task.defer(applyGates)

-- // [12] STARTUP: RESET CHARACTER 1x
task.spawn(function()
    task.wait(3)
    if Library._destroyed then return end
    local done = false
    local conn
    conn = LocalPlayer.CharacterAdded:Connect(function(c)
        if done then return end
        done = true
        if conn then pcall(function() conn:Disconnect() end) end
        local h = c:WaitForChild("Humanoid", 5)
        if h then
            task.wait(0.4)
            pcall(function() end)
            Library:Notify("Character reset, speed normalized", 3, "Startup", "refresh-cw")
        end
    end)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local ok = false
    if hum then ok = pcall(function() hum.Health = 0 end) end
    if (not ok or not hum) and char then
        pcall(function() char:BreakJoints() end)
    end
    task.delay(8, function()
        if not done and conn then pcall(function() conn:Disconnect() end) end
    end)
end)

Library:Notify("Ro-Netrium Hub Ready to used!", 5, "Ro-Netrium", "flame")
