--[[ Ro-netrium Hub • Smile / Infection Game ]]
--[[ Powered by Ro-Netrium Library V5.9.1 ]]
--[[ PART 1/2 — COMBINE WITH PART 2/2 INTO ONE SCRIPT, THEN EXECUTE ]]

repeat task.wait() until game:IsLoaded()

local players = game:GetService("Players")
local ws = game:GetService("Workspace")
local lighting = game:GetService("Lighting")
local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")
local team = game:GetService("Teams")
local cl = players.LocalPlayer
local cam = ws.CurrentCamera

--// LOAD RO-NETRIUM LIBRARY
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
            game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Ro-netrium", Text = msg, Duration = 8 })
        end)
    end
    return
end

local execName = (type(identifyexecutor) == "function" and identifyexecutor()) or "Executor"
Library.ToggleKey = Enum.KeyCode.LeftControl

local Window = Library:CreateWindow({
    Title = "Ro-netrium Hub",
    Subtitle = "Infection Game • " .. execName,
    Tags = {
        { Text = "Smile", Icon = "gamepad-2", Color = Color3.fromRGB(255, 204, 0), TextColor = Color3.new(0, 0, 0) },
        { Text = "V4", Icon = "sparkles", Color = Color3.fromRGB(46, 230, 110), TextColor = Color3.new(0, 0, 0) },
    },
})
if not Window then return end

--// ==========================================================
--// SELF-CONTAINED HELPERS (replace pastebin utilities)
--// ==========================================================
local function notify(msg, icon) Library:Notify(msg, 3, "Ro-netrium", icon or "info") end
local function getChar() return cl.Character end
local function getHum()
    local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid")
end
local function getHRP()
    local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function magnitude(a, b)
    if a and b then return (a.Position - b.Position).Magnitude end
    return nil
end

--// [FIX] TouchTransmitter-safe: only fire when a transmitter exists,
--// try BOTH argument orders (pcall) so it works on every executor & never errors.
local function hasTransmitter(p)
    return p and p:IsA("BasePart") and p:FindFirstChildOfClass("TouchTransmitter") ~= nil
end
local function touchBetween(a, b)
    if type(firetouchinterest) ~= "function" then return false end
    if typeof(a) ~= "Instance" or typeof(b) ~= "Instance" then return false end
    if not a:IsA("BasePart") or not b:IsA("BasePart") then return false end
    if not (hasTransmitter(a) or hasTransmitter(b)) then return false end
    pcall(firetouchinterest, a, b, 0)
    pcall(firetouchinterest, a, b, 1)
    pcall(firetouchinterest, b, a, 0)
    pcall(firetouchinterest, b, a, 1)
    return true
end
local function touchSelf(part) return touchBetween(getHRP(), part) end

local function fireClick(cd)
    if cd and type(fireclickdetector) == "function" then return pcall(fireclickdetector, cd) end
    return false
end
local function firePrompt(pp)
    if pp and type(fireproximityprompt) == "function" then return pcall(fireproximityprompt, pp) end
    return false
end
local function goTo(part, ox, oy, oz)
    local hrp = getHRP()
    if not hrp or not part then return end
    local pos = part.Position + Vector3.new(ox or 0, oy or 0, oz or 0)
    hrp.Anchored = true
    hrp.CFrame = CFrame.new(pos)
    hrp.Anchored = false
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
        Callback = function(v) if v then StartLoop(flag, interval, fn) else StopLoop(flag) end end,
    })
end

--// ==========================================================
--// [NEW] KEY SYSTEM HELPERS
--// ==========================================================
local function isKeyPart(obj)
    return obj:IsA("MeshPart") and obj.Name:lower():find("key") and obj:FindFirstChildOfClass("TouchTransmitter")
end

--// [FEATURE 1] Improved auto collect keys: KeySystem.Spots.Spot.* + Particles + legacy
local function collectAllKeys()
    local hrp = getHRP()
    if not hrp then return 0 end
    local n = 0
    local function tryKey(obj)
        if isKeyPart(obj) then touchBetween(obj, hrp) n += 1 end
    end
    local particles = ws:FindFirstChild("Particles")
    if particles then
        for _, v in ipairs(particles:GetChildren()) do tryKey(v) end
    end
    local system = ws.Map and ws.Map:FindFirstChild("System")
    if system then
        for _, desc in ipairs(system:GetDescendants()) do
            if desc.Name:lower():find("keysystem") then
                for _, k in ipairs(desc:GetDescendants()) do tryKey(k) end
            end
        end
    end
    return n
end

--// [FEATURE 5] Open key doors remotely (server validates matching key color)
local function openKeyDoors()
    local system = ws.Map and ws.Map:FindFirstChild("System")
    if not system then return 0 end
    local n = 0
    for _, sys in ipairs(system:GetChildren()) do
        local ks = sys:FindFirstChild("KeySystem")
        if ks then
            local door = ks:FindFirstChild("KeyDoor")
            if door then
                local cd = door:FindFirstChildOfClass("ClickDetector")
                local pp = door:FindFirstChildOfClass("ProximityPrompt")
                local part = door:IsA("BasePart") and door or door:FindFirstChildWhichIsA("BasePart")
                if cd then fireClick(cd) n += 1
                elseif pp then firePrompt(pp) n += 1
                elseif part then touchBetween(part, getHRP()) n += 1 end
            end
        end
    end
    return n
end

--// [FEATURE 6] Key holder notification
local keyHolderSeen = {}
local function scanKeyHolders()
    local current = {}
    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= cl then
            local containers = { plr.Character, plr:FindFirstChildOfClass("Backpack") }
            for _, cont in ipairs(containers) do
                if cont then
                    for _, item in ipairs(cont:GetChildren()) do
                        if item.Name:lower():find("key") then
                            local id = plr.Name .. "|" .. item.Name
                            current[id] = true
                            if not keyHolderSeen[id] then
                                notify(plr.Name .. " is holding " .. item.Name, "key")
                            end
                        end
                    end
                end
            end
        end
    end
    keyHolderSeen = current
end

--// [FEATURE 2 & 4] AntiHack + Quake Wedge destroy
local function destroyAntiHack()
    local ah = ws.Map and ws.Map:FindFirstChild("AntiHack")
    if ah then
        for _, c in ipairs(ah:GetChildren()) do pcall(function() c:Destroy() end) end
    end
end
local function destroyWedge()
    local ct = ws.Map and ws.Map:FindFirstChild("ConstantTerrain")
    local w = ct and ct:FindFirstChild("Wedge")
    if w then pcall(function() w:Destroy() end) end
end

--// ==========================================================
--// [FEATURE 3 & 7] CFrame MOVEMENT BYPASS (WS / JP / InfJump / TP)
--// ==========================================================
local cfSpeedOn, cfSpeedVal = false, 16
local cfJumpOn, cfJumpVal = false, 50
local infJumpOn = false
local bypassTPOn = false

local cfMoveConn = rs.Heartbeat:Connect(function(dt)
    if Library._destroyed or not cfSpeedOn then return end
    local hum, hrp = getHum(), getHRP()
    if not (hum and hrp) or hum.Sit then return end
    if hum.MoveDirection.Magnitude > 0 then
        local base = 16
        local stats = cl:FindFirstChild("Stats")
        if stats and stats:FindFirstChild("NormalSpeed") then base = stats.NormalSpeed.Value end
        local extra = math.max(0, cfSpeedVal - base)
        hrp.CFrame = hrp.CFrame + hum.MoveDirection * extra * math.min(dt, 0.1)
    end
end)

local cfJumpConn = uis.JumpRequest:Connect(function()
    if Library._destroyed then return end
    local hrp, hum = getHRP(), getHum()
    if not (hrp and hum) then return end
    if infJumpOn then
        hrp.CFrame = hrp.CFrame + Vector3.new(0, 6, 0)
    end
    if cfJumpOn then
        local extra = math.max(0, cfJumpVal - 50)
        if extra > 0 then
            task.spawn(function()
                local t = 0
                while t < 0.35 and not Library._destroyed do
                    local dt = rs.Heartbeat:Wait()
                    t += dt
                    local h = getHRP()
                    if h then h.CFrame = h.CFrame + Vector3.new(0, extra * dt * 1.5, 0) end
                end
            end)
        end
    end
end)

--// [FEATURE 7] Smooth teleport (small per-frame steps bypass anti-TP)
local function doTeleport(cf)
    local hrp = getHRP()
    if not hrp then return false end
    if not bypassTPOn then
        hrp.Anchored = true hrp.CFrame = cf hrp.Anchored = false
        return true
    end
    task.spawn(function()
        local rot = cf - cf.Position
        for _ = 1, 300 do
            if Library._destroyed then break end
            local h = getHRP()
            if not h then break end
            local delta = cf.Position - h.Position
            local dist = delta.Magnitude
            if dist < 3 then h.CFrame = cf break end
            h.CFrame = CFrame.new(h.Position + delta.Unit * math.min(dist, 20)) * rot
            rs.Heartbeat:Wait()
        end
    end)
    return true
end

--// ==========================================================
--// OBJECT ESP (replaces ObjectEsp)
--// ==========================================================
local espObjs = {}
local function addEsp(obj, label, color, cat)
    if not obj or espObjs[obj] then return end
    local hl = Instance.new("Highlight")
    hl.FillColor = color hl.FillTransparency = 0.5
    hl.OutlineColor = Color3.new(1, 1, 1) hl.OutlineTransparency = 0.3
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = obj hl.Parent = obj
    local bb = Instance.new("BillboardGui")
    bb.Adornee = obj bb.Size = UDim2.new(0, 130, 0, 20)
    bb.StudsOffset = Vector3.new(0, 2, 0) bb.AlwaysOnTop = true bb.Parent = obj
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, 0, 1, 0) t.BackgroundTransparency = 1
    t.Text = label t.TextColor3 = color t.TextStrokeTransparency = 0
    t.Font = Enum.Font.GothamBold t.TextSize = 12 t.Parent = bb
    espObjs[obj] = { hl = hl, bb = bb, cat = cat }
end
local function clearEspCat(cat)
    for obj, d in pairs(espObjs) do
        if d.cat == cat then
            pcall(function() if d.hl then d.hl:Destroy() end end)
            pcall(function() if d.bb then d.bb:Destroy() end end)
            espObjs[obj] = nil
        end
    end
end

--// ==========================================================
--// SHARED STATE
--// ==========================================================
local autofarmOn, hitAuraOn, auraNoAutoOn = false, false, false
local hitaurarange = 15
local funnyhitauramethod = "Blatant"
local hitauratarget = nil

local funnyfolder = Instance.new("Folder")
funnyfolder.Parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
local hitauratargethl = Instance.new("Highlight")
hitauratargethl.Parent = funnyfolder
hitauratargethl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
hitauratargethl.Enabled = false
hitauratargethl.FillColor = Color3.fromRGB(255, 0, 0)
hitauratargethl.FillTransparency = 0.5
hitauratargethl.OutlineColor = Color3.fromRGB(255, 255, 255)
hitauratargethl.OutlineTransparency = 0.5

local MAIN_WEAPONS = { "Bat", "Branch", "Katana", "Spear", "Chain", "Packed Ice" }
local function hasMainWeapon()
    local c, bp = getChar(), cl:FindFirstChildOfClass("Backpack")
    for _, name in ipairs(MAIN_WEAPONS) do
        if (c and c:FindFirstChild(name)) or (bp and bp:FindFirstChild(name)) then return true end
    end
    return false
end
local function getToolHitbox(tool)
    if not tool then return nil end
    for _, name in ipairs({ "Handle", "BodyAttach", "Hitbox" }) do
        local p = tool:FindFirstChild(name)
        if p and p:FindFirstChildOfClass("TouchTransmitter") then return p end
    end
    return nil
end
local function isEnemy(plr)
    return plr ~= cl and plr.Character and plr.Team ~= cl.Team
end

--// ==========================================================
--// TAB: HOME
--// ==========================================================
local HomeTab = Window:CreateTab("Home", "home")
HomeTab:CreateLabel({ Text = "Welcome " .. cl.DisplayName .. "!", Icon = "user" })
HomeTab:CreateSection("Info")
HomeTab:CreateButton({
    Name = "Discord Server Link", Icon = "link",
    Callback = function()
        local ok, link = pcall(function() return game:HttpGet("https://pastebin.com/raw/sX4xZuYK") end)
        if ok and type(setclipboard) == "function" then
            setclipboard(link) notify("Discord link copied", "check-circle")
        else notify("Failed to fetch link", "x-circle") end
    end,
})
HomeTab:CreateParagraph({
    Title = "Update Logs V4",
    Content = "• Ported to Ro-Netrium Library\n• Improved auto-collect keys (KeySystem.Spots.Spot)\n• Remote key doors + key holder notifications\n• AntiHack & Quake Wedge removal\n• CFrame Speed / Jump / Inf-Jump bypass\n• Smooth anti-TP teleport",
    Icon = "info",
})
local safecode = HomeTab:CreateLabel({ Text = "Safe code: ...", Icon = "lock" })

--// ==========================================================
--// TAB: MAIN
--// ==========================================================
local MainTab = Window:CreateTab("Main", "home")
MainTab:CreateSection("Autofarm")

LoopToggle(MainTab, "Autofarm", "banknote", "Autofarm",
    "Auto kill lowest-HP enemy as Human; auto-respawn as Smiling", 0, function()
        autofarmOn = true
        local hum = getHum()
        if hum then hum.Health = 0 end
        local lowestHealth, closestPlayer, closestDistance = math.huge, nil, 9999
        for _, v in ipairs(players:GetPlayers()) do
            if isEnemy(v) then
                local h = v.Character:FindFirstChildOfClass("Humanoid")
                local hrp = v.Character:FindFirstChild("HumanoidRootPart")
                if h and h.Health > 0 and hrp then
                    local dist = magnitude(hrp, getHRP())
                    if dist and dist <= 9999 then
                        if h.Health < lowestHealth or (h.Health == lowestHealth and dist < closestDistance) then
                            closestPlayer, closestDistance, lowestHealth = v, dist, h.Health
                        end
                    end
                end
            end
        end
        local myTeam = cl.Team
        if myTeam == team:FindFirstChild("Smiling") and getHum() and getHum().Health > 0 then
            getHum().Health = 0
        end
        if myTeam == team:FindFirstChild("Human") and closestPlayer and closestPlayer.Character then
            local eh = closestPlayer.Character:FindFirstChildOfClass("Humanoid")
            local ehrp = closestPlayer.Character:FindFirstChild("HumanoidRootPart")
            if eh and eh.Health > 0 and ehrp then
                cam.CameraSubject = closestPlayer.Character
                local c = getChar()
                if not c:FindFirstChildOfClass("Tool") and not cl:FindFirstChildOfClass("Backpack"):FindFirstChildOfClass("Tool") then
                    local bat = ws.Map and ws.Map:FindFirstChild("HumanBase")
                    bat = bat and bat:FindFirstChild("Vendor")
                    bat = bat and bat:FindFirstChild("BatCollection")
                    if bat and bat:FindFirstChild("HitBox") then
                        goTo(bat.HitBox, 0, -5, 0)
                        touchBetween(bat.HitBox, getHRP())
                    end
                else
                    local hrp = getHRP()
                    if hrp then hrp.CFrame = CFrame.new(-280, -7, -50) end
                end
                local tool = c:FindFirstChildOfClass("Tool")
                if not tool then
                    local bp = cl:FindFirstChildOfClass("Backpack")
                    local bpt = bp and bp:FindFirstChildOfClass("Tool")
                    if bpt then bpt.Parent = c tool = bpt end
                end
                local hitbox = getToolHitbox(tool)
                local swing = tool and tool:FindFirstChild("SwingEvent")
                if hitbox and swing then
                    touchBetween(hitbox, ehrp)
                    pcall(function() swing:FireServer() end)
                end
            end
        end
    end)

LoopToggle(MainTab, "No Slowdown", "gauge", "NoSlowdown",
    "Restore WalkSpeed to NormalSpeed when slowed", 0.4, function()
        if autofarmOn then return end
        local hum = getHum()
        local stats = cl:FindFirstChild("Stats")
        if hum and stats and stats:FindFirstChild("NormalSpeed") then
            if hum.WalkSpeed < stats.NormalSpeed.Value then hum.WalkSpeed = stats.NormalSpeed.Value end
        end
    end)

MainTab:CreateSection("Aura")
MainTab:CreateSlider({
    Name = "Hit Aura Range", Icon = "crosshair", Flag = "HitAuraRange",
    Min = 0, Max = 100, Default = 15, Step = 0.5, Suffix = " studs",
    Callback = function(v) hitaurarange = v end,
})
MainTab:CreateDropdown({
    Name = "Hit Aura Method", Icon = "layers", Flag = "HitAuraMethod",
    Options = { "Blatant", "Legit" }, Default = "Blatant",
    Callback = function(v) funnyhitauramethod = v end,
})

local function findAuraTarget()
    local closestPlayer, closestDistance = nil, hitaurarange
    for _, v in ipairs(players:GetPlayers()) do
        if isEnemy(v) then
            local h = v.Character:FindFirstChildOfClass("Humanoid")
            local hrp = v.Character:FindFirstChild("HumanoidRootPart")
            if h and h.Health > 0 and hrp then
                local dist = magnitude(hrp, getHRP())
                if dist and dist <= hitaurarange then
                    if h.WalkSpeed <= 5 and h.WalkSpeed >= 1 and cl.Team == team:FindFirstChild("Human") then
                        closestPlayer, closestDistance = v, dist
                    elseif dist < closestDistance then
                        closestPlayer, closestDistance = v, dist
                    end
                end
            end
        end
    end
    hitauratarget = closestPlayer
    return closestPlayer
end

local function doAura(autoSwing)
    if autofarmOn then return end
    local c = getChar()
    if not c then return end
    local target = findAuraTarget()
    if not target or not target.Character then return end
    local ehrp = target.Character:FindFirstChild("HumanoidRootPart")
    local eh = target.Character:FindFirstChildOfClass("Humanoid")
    if not (ehrp and eh and eh.Health > 0) then return end
    local stats = c:FindFirstChild("Stats")
    local grabbed = stats and stats:FindFirstChild("Grabbed")
    if cl.Team == team:FindFirstChild("Human") then
        if grabbed and grabbed.Value then return end
        local tool = c:FindFirstChildOfClass("Tool")
        local hitbox = getToolHitbox(tool)
        local swing = tool and tool:FindFirstChild("SwingEvent")
        if hitbox then
            touchBetween(hitbox, ehrp)
            if autoSwing then
                if funnyhitauramethod == "Legit" then pcall(function() tool:Activate() end)
                elseif swing then pcall(function() swing:FireServer() end) end
            end
        end
    elseif cl.Team == team:FindFirstChild("Smiling") then
        local ragdoll = stats and stats:FindFirstChild("Ragdoll")
        local tgrabbed = target.Character:FindFirstChild("Stats") and target.Character.Stats:FindFirstChild("Grabbed")
        local hum = getHum()
        local torso = c:FindFirstChild("Torso")
        if (tgrabbed and tgrabbed.Value) or (ragdoll and ragdoll.Value) then return end
        if not (hum and hum.WalkSpeed > 5 and torso) then return end
        local infected = c:FindFirstChild("Infected")
        local infectEvent = infected and infected:FindFirstChild("InfectEvent")
        local torsoPart = torso:FindFirstChild("Part")
        if infectEvent and torsoPart then
            if autoSwing then pcall(function() infectEvent:FireServer() end) end
            touchBetween(torsoPart, ehrp)
        end
    end
end

LoopToggle(MainTab, "Hit / Infect Aura", "target", "HitAura",
    "Auto hit/infect nearest enemy in range", 0, function()
        hitAuraOn = true
        doAura(true)
    end)

LoopToggle(MainTab, "Aura (No Auto Swing)", "target", "AuraNoAuto",
    "Touch enemy with weapon hitbox only (no swing/infect fire)", 0, function()
        auraNoAutoOn = true
        if not hitAuraOn then doAura(false) end
    end)

LoopToggle(MainTab, "Show Target", "eye", "ShowTarget",
    "Highlight current aura target", 0.1, function()
        if hitauratarget and hitauratarget.Character then
            local h = hitauratarget.Character:FindFirstChildOfClass("Humanoid")
            local dist = magnitude(hitauratarget.Character:FindFirstChild("HumanoidRootPart"), getHRP())
            if h and h.Health > 0 and dist and dist <= hitaurarange then
                hitauratargethl.Adornee = hitauratarget.Character
                hitauratargethl.Enabled = true
                return
            end
        end
        hitauratargethl.Adornee = nil
        hitauratargethl.Enabled = false
    end)

MainTab:CreateSection("Mods")
LoopToggle(MainTab, "No Cooldown [Weapons]", "zap", "NoCDWeapon",
    "Reset equipped weapon cooldown", 0.5, function()
        local tool = getChar() and getChar():FindFirstChildOfClass("Tool")
        local cd = tool and tool:FindFirstChild("Cooldown")
        if cd and cd.Value > 0 then cd.Value = 0 end
    end)
LoopToggle(MainTab, "No Cooldown [Infect]", "zap", "NoCDInfect",
    "Reset infect cooldown", 0.5, function()
        local c = getChar()
        local infected = c and c:FindFirstChild("Infected")
        local infect = infected and infected:FindFirstChild("Infect")
        local cd = infect and infect:FindFirstChild("Cooldown")
        if cd and cd.Value > 0 then cd.Value = 0 end
    end)

MainTab:CreateSection("Weapons")
LoopToggle(MainTab, "Auto-Get Main Weapon", "package", "AutoGetWeapon",
    "Auto grab a main weapon when you have none (Human)", 0.55, function()
        if autofarmOn then return end
        local c = getChar()
        local stats = c and c:FindFirstChild("Stats")
        local grabbed = stats and stats:FindFirstChild("Grabbed")
        if not (c and stats) or (grabbed and grabbed.Value) then return end
        if cl.Team ~= team:FindFirstChild("Human") or hasMainWeapon() then return end
        local hrp = getHRP()
        if not hrp then return end
        local oldpos = hrp.CFrame
        local vendor = ws.Map and ws.Map:FindFirstChild("HumanBase")
        vendor = vendor and vendor:FindFirstChild("Vendor")
        local bat = vendor and vendor:FindFirstChild("BatCollection")
        local bottle = vendor and vendor:FindFirstChild("BottleCollection")
        local tries = 0
        repeat
            if bat and bat:FindFirstChild("HitBox") then
                goTo(bat.HitBox, 0, -5, 0)
                touchBetween(bat.HitBox, getHRP())
                if bottle and bottle:FindFirstChild("HitBox") then touchBetween(bottle.HitBox, getHRP()) end
            end
            task.wait(1 / 69)
            tries += 1
            local h = getHum()
        until hasMainWeapon() or tries > 100 or (h and h.Health <= 0) or (grabbed and grabbed.Value) or cl.Team ~= team:FindFirstChild("Human") or Library._destroyed
        local h2 = getHRP()
        if h2 then h2.CFrame = oldpos end
    end)

LoopToggle(MainTab, "Auto-Collect Weapons", "package", "AutoCollectWeapons",
    "Collect all weapon Collection models remotely", 0.5, function()
        if autofarmOn then return end
        local system = ws.Map and ws.Map:FindFirstChild("System")
        if not system then return end
        local c, bp = getChar(), cl:FindFirstChildOfClass("Backpack")
        for _, v in ipairs(system:GetChildren()) do
            if v:IsA("Model") then
                for _, m in ipairs(v:GetDescendants()) do
                    if m.Name:match("Collection") and m:IsA("Model") then
                        local wname = m.Name:match("(.+)Collection")
                        if not ((bp and bp:FindFirstChild(wname)) or (c and c:FindFirstChild(wname))) then
                            local cd = m:FindFirstChildOfClass("ClickDetector")
                            if cd then fireClick(cd)
                            elseif m:FindFirstChild("Handle") and m.Handle:FindFirstChildOfClass("TouchTransmitter") then
                                touchBetween(m.Handle, getHRP())
                            end
                        end
                    end
                end
            end
        end
    end)

MainTab:CreateButton({
    Name = "Get Main Weapon (Once)", Icon = "package",
    Callback = function()
        task.spawn(function()
            if autofarmOn then return end
            local c = getChar()
            local stats = c and c:FindFirstChild("Stats")
            local grabbed = stats and stats:FindFirstChild("Grabbed")
            if not (c and stats) or (grabbed and grabbed.Value) then return end
            if cl.Team ~= team:FindFirstChild("Human") or hasMainWeapon() then return end
            local hrp = getHRP()
            if not hrp then return end
            local oldpos = hrp.CFrame
            local vendor = ws.Map and ws.Map:FindFirstChild("HumanBase")
            vendor = vendor and vendor:FindFirstChild("Vendor")
            local bat = vendor and vendor:FindFirstChild("BatCollection")
            local bottle = vendor and vendor:FindFirstChild("BottleCollection")
            local tries = 0
            repeat
                if bat and bat:FindFirstChild("HitBox") then
                    goTo(bat.HitBox, 0, -5, 0)
                    touchBetween(bat.HitBox, getHRP())
                    if bottle and bottle:FindFirstChild("HitBox") then touchBetween(bottle.HitBox, getHRP()) end
                end
                task.wait(1 / 69)
                tries += 1
                local h = getHum()
            until hasMainWeapon() or tries > 100 or (h and h.Health <= 0) or (grabbed and grabbed.Value) or cl.Team ~= team:FindFirstChild("Human") or Library._destroyed
            local h2 = getHRP()
            if h2 then h2.CFrame = oldpos end
            notify("Main weapon obtained", "check-circle")
        end)
    end,
})

MainTab:CreateSection("Items")
LoopToggle(MainTab, "Auto-Collect Coins", "banknote", "AutoCollectCoins",
    "Collect all SmileCoins remotely", 0.2, function()
        local hrp = getHRP()
        if not hrp then return end
        local system = ws.Map and ws.Map:FindFirstChild("System")
        if system then
            for _, v in ipairs(system:GetChildren()) do
                local css = v:FindFirstChild("CoinSpawnSystem")
                if css and css:FindFirstChild("Coins") then
                    for _, l in ipairs(css.Coins:GetChildren()) do
                        if l.Name:match("SmileCoin") then touchBetween(l, hrp) end
                    end
                end
            end
        end
        local particles = ws:FindFirstChild("Particles")
        if particles then
            for _, v in ipairs(particles:GetChildren()) do
                if v.Name:match("SmileCoin") and v:FindFirstChildOfClass("TouchTransmitter") then
                    touchBetween(v, hrp)
                end
            end
        end
    end)

MainTab:CreateSection("ESP")
LoopToggle(MainTab, "Weapons ESP", "eye", "WeaponsESP",
    "Highlight weapon Collection models", 1, function()
        local system = ws.Map and ws.Map:FindFirstChild("System")
        if not system then return end
        for _, v in ipairs(system:GetChildren()) do
            for _, m in ipairs(v:GetDescendants()) do
                if m.Name:match("Collection") then
                    local part = m:FindFirstChild("Handle") or m:FindFirstChild("Part")
                    if part then addEsp(part, m.Name:match("(.+)Collection") or m.Name, Color3.fromRGB(0, 255, 0), "weapon") end
                end
            end
        end
    end)
--// cleanup weapons esp on off handled via flag watcher in finalization

LoopToggle(MainTab, "Keys ESP", "eye", "KeysESP",
    "Highlight all keys with their color", 1, function()
        local hrp = getHRP()
        local particles = ws:FindFirstChild("Particles")
        if particles then
            for _, v in ipairs(particles:GetChildren()) do
                if isKeyPart(v) then addEsp(v, v.Name, v.Color, "key") end
            end
        end
        local system = ws.Map and ws.Map:FindFirstChild("System")
        if system then
            for _, desc in ipairs(system:GetDescendants()) do
                if isKeyPart(desc) then addEsp(desc, desc.Name, desc.Color, "key") end
            end
        end
    end)

--// ==========================================================
--// PART 1/2 DONE — PASTE PART 2/2 RIGHT BELOW THIS LINE
--// DO NOT EXECUTE UNTIL PART 2 IS PASTED!
--// ==========================================================
--[[ PART 2/2 : Keys + Bypass + Misc + Finalization ]]

--// ==========================================================
--// TAB: KEYS (NEW)
--// ==========================================================
local KeysTab = Window:CreateTab("Keys", "key")
KeysTab:CreateSection("Key Farming")

LoopToggle(KeysTab, "Auto-Collect All Keys (Improved)", "key", "AutoCollectKeys",
    "Collects keys from KeySystem.Spots.Spot.* + Particles + legacy, no teleport", 0.3, function()
        collectAllKeys()
    end)

LoopToggle(KeysTab, "Auto Open Key Doors (Remote)", "door-open", "AutoOpenDoors",
    "Collect keys then open every KeyDoor remotely (matching color enforced by server)", 0.6, function()
        collectAllKeys()
        openKeyDoors()
    end)

LoopToggle(KeysTab, "Notify Key Holders", "bell", "NotifyKeyHolders",
    "Notify when a player picks up a key", 1, function()
        scanKeyHolders()
    end)

KeysTab:CreateSection("Manual")
KeysTab:CreateButton({
    Name = "Collect All Keys (Once)", Icon = "key",
    Callback = function()
        local n = collectAllKeys()
        notify("Collected " .. n .. " keys", "check-circle")
    end,
})
KeysTab:CreateButton({
    Name = "Open All Key Doors (Once)", Icon = "door-open",
    Tooltip = "Collects keys first, then opens all KeyDoors remotely",
    Callback = function()
        collectAllKeys()
        local n = openKeyDoors()
        notify("Opened " .. n .. " key doors", "check-circle")
    end,
})
KeysTab:CreateParagraph({
    Title = "How Key Doors Work",
    Content = "Doors only open with the matching key color (e.g. white door = white key). Auto-collect gives you every key, then the door interaction is fired remotely so you never walk to the door.",
    Icon = "info",
})

--// ==========================================================
--// TAB: BYPASS (NEW)
--// ==========================================================
local BypassTab = Window:CreateTab("Bypass", "shield-check")
BypassTab:CreateSection("Anti-Cheat")

LoopToggle(BypassTab, "Bypass Anti-Cheat (AntiHack)", "shield", "BypassAntiHack",
    "Destroy Map.AntiHack.Part continuously", 0.2, function()
        destroyAntiHack()
    end)

LoopToggle(BypassTab, "Anti Quake Kill (Wedge)", "mountain", "AntiQuakeWedge",
    "Destroy Map.ConstantTerrain.Wedge kill-brick during earthquake", 0.2, function()
        destroyWedge()
    end)

BypassTab:CreateSection("Movement Bypass (CFrame)")
BypassTab:CreateToggle({
    Name = "CFrame WalkSpeed (Bypass)", Icon = "gauge", Flag = "CFrameSpeed", Default = false,
    Tooltip = "Move fast via CFrame; real WalkSpeed stays default = anti-cheat safe",
    Callback = function(v)
        cfSpeedOn = v
        if v then notify("CFrame Speed ON (WalkSpeed untouched)", "check-circle") end
    end,
})
BypassTab:CreateSlider({
    Name = "CFrame Speed Value", Icon = "gauge", Flag = "CFrameSpeedValue",
    Min = 16, Max = 300, Default = 50, Step = 1,
    Callback = function(v) cfSpeedVal = v end,
})
BypassTab:CreateToggle({
    Name = "CFrame JumpPower (Bypass)", Icon = "arrow-up", Flag = "CFrameJump", Default = false,
    Tooltip = "Extra jump height via CFrame; real JumpPower stays default",
    Callback = function(v) cfJumpOn = v end,
})
BypassTab:CreateSlider({
    Name = "CFrame Jump Value", Icon = "arrow-up", Flag = "CFrameJumpValue",
    Min = 50, Max = 300, Default = 80, Step = 1,
    Callback = function(v) cfJumpVal = v end,
})
BypassTab:CreateToggle({
    Name = "Infinite Jump (CFrame Bypass)", Icon = "chevrons-up", Flag = "InfJumpBypass", Default = false,
    Tooltip = "Mid-air hops via CFrame (no ChangeState) = bypass jump anti-cheat",
    Callback = function(v) infJumpOn = v end,
})
BypassTab:CreateToggle({
    Name = "Bypass Teleport (Smooth)", Icon = "navigation", Flag = "BypassTP", Default = false,
    Tooltip = "Manual teleports move in small steps to bypass anti-TP",
    Callback = function(v) bypassTPOn = v end,
})

BypassTab:CreateSection("Raw Movement (Library)")
BypassTab:CreateToggle({
    Name = "Raw WalkSpeed (Detectable)", Icon = "gauge", Flag = "RawWS", Default = false,
    Tooltip = "Uses library WalkSpeed. Only use if no speed anti-cheat.",
    Callback = function(v) Library.Movement:SetWalkSpeedActive(v) end,
})
BypassTab:CreateSlider({
    Name = "Raw WalkSpeed Value", Icon = "gauge", Flag = "RawWSValue",
    Min = 16, Max = 200, Default = 50, Step = 1,
    Callback = function(v) Library.Movement:SetWalkSpeed(v) end,
})
BypassTab:CreateToggle({
    Name = "Raw JumpPower (Detectable)", Icon = "arrow-up", Flag = "RawJP", Default = false,
    Callback = function(v) Library.Movement:SetJumpPowerActive(v) end,
})
BypassTab:CreateSlider({
    Name = "Raw JumpPower Value", Icon = "arrow-up", Flag = "RawJPValue",
    Min = 50, Max = 300, Default = 80, Step = 1,
    Callback = function(v) Library.Movement:SetJumpPower(v) end,
})

--// ==========================================================
--// TAB: MISC
--// ==========================================================
local MiscTab = Window:CreateTab("Misc", "wrench")
MiscTab:CreateSection("Remove Stuffs")

LoopToggle(MiscTab, "Auto-Remove Infectors", "shield", "AutoRemoveInfectors",
    "Destroy/neutralize infector parts", 0.3, function()
        local system = ws.Map and ws.Map:FindFirstChild("System")
        if system then
            for _, v in ipairs(system:GetChildren()) do
                if v:IsA("Model") then
                    for _, m in ipairs(v:GetDescendants()) do
                        if m:IsA("Model") and (m.Name:match("Infector") or m.Name:match("Part")) then
                            for _, l in ipairs(m:GetChildren()) do
                                if l:IsA("BasePart") and l.BrickColor == BrickColor.new("Institutional white") then
                                    pcall(function() l:Destroy() end)
                                end
                            end
                        elseif m:IsA("Part") and m:FindFirstChildOfClass("TouchTransmitter") and m:FindFirstChild("InfectScript") and m:FindFirstChild("SmilesEmitter") and m.BrickColor == BrickColor.new("Institutional white") then
                            pcall(function() m:Destroy() end)
                        end
                    end
                end
            end
        end
        local infectors = ws.Map and ws.Map:FindFirstChild("Infectors")
        if infectors then
            for _, v in ipairs(infectors:GetChildren()) do
                if v:IsA("Model") then
                    for _, m in ipairs(v:GetChildren()) do
                        if m:IsA("BasePart") then m.CanTouch = false m.CanCollide = false m.Transparency = 1 end
                    end
                end
            end
        end
    end)

LoopToggle(MiscTab, "Auto-Remove Anti-Smilers", "shield", "AutoRemoveAntiSmilers",
    "Destroy/neutralize anti-smiler kill gates", 0.3, function()
        local system = ws.Map and ws.Map:FindFirstChild("System")
        if system then
            for _, v in ipairs(system:GetChildren()) do
                if v:IsA("Model") then
                    for _, m in ipairs(v:GetDescendants()) do
                        if m:IsA("Model") and (m.Name:lower():match("part") or m.Name:match("Infector") or m.Name:match("AntiSmiler")) then
                            for _, l in ipairs(m:GetChildren()) do
                                if l:IsA("BasePart") and l.BrickColor == BrickColor.new("Neon orange") and m:FindFirstChild("InfectScript") and l.Transparency == 0.7 then
                                    pcall(function() l:Destroy() end)
                                end
                            end
                        elseif m:IsA("Part") and m:FindFirstChildOfClass("TouchTransmitter") and m:FindFirstChild("InfectScript") and m.BrickColor == BrickColor.new("Neon orange") and m.Transparency == 0.7 then
                            pcall(function() m:Destroy() end)
                        end
                    end
                end
            end
        end
        local ct = ws.Map and ws.Map:FindFirstChild("ConstantTerrain")
        local kgs = ct and ct:FindFirstChild("KillGateSwitcher")
        if kgs then
            for _, v in ipairs(kgs:GetChildren()) do
                if v.Name:lower():match("gate") and v.BrickColor == BrickColor.new("Neon orange") then
                    v.CanTouch = false v.CanCollide = false v.Transparency = 1
                end
            end
        end
    end)

MiscTab:CreateSection("Teleports")
local TELEPORTS = {
    { Name = "End", Pos = Vector3.new(-322, 14, -4) },
    { Name = "End Safeplace", Pos = Vector3.new(-349, 3, 25) },
    { Name = "Human Base", Pos = Vector3.new(5, 3, 8) },
    { Name = "Sign Place Safeplace", Pos = Vector3.new(-40, 3, 51) },
}
for _, tp in ipairs(TELEPORTS) do
    MiscTab:CreateButton({
        Name = tp.Name, Icon = "navigation",
        Callback = function()
            if doTeleport(CFrame.new(tp.Pos)) then notify("Teleported: " .. tp.Name, "map-pin")
            else notify("Character not ready", "x-circle") end
        end,
    })
end

MiscTab:CreateSection("Local Player")
MiscTab:CreateButton({
    Name = "Reset", Icon = "refresh-cw",
    Callback = function()
        local hum = getHum()
        if hum and hum.Health > 0 then hum:TakeDamage(100) end
    end,
})
MiscTab:CreateButton({
    Name = "Infect Self", Icon = "flame",
    Callback = function()
        if cl.Team ~= team:FindFirstChild("Human") then return end
        local hum = getHum()
        if not (hum and hum.Health > 0) then return end
        local infectors = ws.Map and ws.Map:FindFirstChild("Infectors")
        if not infectors then return end
        for _, v in ipairs(infectors:GetChildren()) do
            if v:IsA("Model") then
                for _, l in ipairs(v:GetChildren()) do
                    if l:IsA("Part") and l:FindFirstChildOfClass("TouchTransmitter") then
                        touchBetween(l, getHRP())
                    end
                end
            end
        end
    end,
})
MiscTab:CreateLabel({ Text = "Default WalkSpeed: 16", Icon = "info" })
MiscTab:CreateSlider({
    Name = "Walkspeed Changer (Raw)", Icon = "gauge", Flag = "RawWalkspeedChanger",
    Min = 0, Max = 50, Default = 16, Step = 0.5, Suffix = " speed",
    Tooltip = "Sets real WalkSpeed + NormalSpeed (detectable). Use CFrame Speed in Bypass tab for safety.",
    Callback = function(v)
        local hum = getHum()
        if hum then
            hum.WalkSpeed = v
            local stats = cl:FindFirstChild("Stats")
            if stats and stats:FindFirstChild("NormalSpeed") then stats.NormalSpeed.Value = v end
        end
    end,
})

--// ==========================================================
--// FINALIZATION
--// ==========================================================

--// [FEATURE 2 & 4] destroy AntiHack + Wedge once on load
destroyAntiHack()
destroyWedge()

--// Safe code auto-update
task.spawn(function()
    while not Library._destroyed do
        local system = ws.Map and ws.Map:FindFirstChild("System")
        local raided = system and system:FindFirstChild("Raided Hideout")
        local safe = raided and raided:FindFirstChild("Safe")
        local part = safe and safe:FindFirstChild("Part")
        local code = part and part:FindFirstChild("safeCode")
        if code then pcall(function() safecode:Set("Safe code: " .. tostring(code.Value)) end) end
        task.wait(1)
    end
end)

--// Flag watchers: clear state / ESP when toggles turn OFF
task.spawn(function()
    local prev = {}
    while not Library._destroyed do
        local F = Library.Flags
        if prev.Autofarm and not F.Autofarm then
            autofarmOn = false
            cam.CameraSubject = getChar()
            local ct = ws.Map and ws.Map:FindFirstChild("ConstantTerrain")
            if ct then
                for _, p in ipairs(ct:GetChildren()) do
                    if p.Name:match("Baseplate") then p.CanCollide = true end
                end
            end
        end
        autofarmOn = F.Autofarm == true
        if prev.HitAura and not F.HitAura then hitAuraOn = false end
        hitAuraOn = F.HitAura == true
        if prev.AuraNoAuto and not F.AuraNoAuto then auraNoAutoOn = false end
        auraNoAutoOn = F.AuraNoAuto == true
        if prev.WeaponsESP and not F.WeaponsESP then clearEspCat("weapon") end
        if prev.KeysESP and not F.KeysESP then clearEspCat("key") end
        if prev.ShowTarget and not F.ShowTarget then
            hitauratargethl.Enabled = false hitauratargethl.Adornee = nil
        end
        if prev.NotifyKeyHolders and not F.NotifyKeyHolders then keyHolderSeen = {} end
        prev = {
            Autofarm = F.Autofarm, HitAura = F.HitAura, AuraNoAuto = F.AuraNoAuto,
            WeaponsESP = F.WeaponsESP, KeysESP = F.KeysESP, ShowTarget = F.ShowTarget,
            NotifyKeyHolders = F.NotifyKeyHolders,
        }
        task.wait(0.2)
    end
end)

--// Full cleanup on library destroy
if Window._extraCleanups then
    table.insert(Window._extraCleanups, function()
        pcall(function() if cfMoveConn then cfMoveConn:Disconnect() end end)
        pcall(function() if cfJumpConn then cfJumpConn:Disconnect() end end)
        clearEspCat("weapon") clearEspCat("key")
        hitauratargethl.Enabled = false hitauratargethl.Adornee = nil
        pcall(function() if funnyfolder then funnyfolder:Destroy() end end)
    end)
end

MainTab:Activate()
Library:Notify("Ro-netrium Hub loaded • AntiHack & Wedge removed • Keys/Bypass ready!", 5, "Ro-netrium", "check-circle")

--[[ DONE 2/2 — Ro-netrium Hub V4 x Ro-Netrium Library V5.9.1 ]]
