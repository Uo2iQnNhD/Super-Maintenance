-- =========================================================
-- SERVICES
-- =========================================================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- =========================================================
-- LOAD LIBRARY
-- =========================================================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Uo2iQnNhD/Super-Database/refs/heads/main/Release-Library.luau"))()

if type(Library) ~= "table" then
    error("[ZethHub] Library failed to load.", 0)
end

-- =========================================================
-- NOTIFICATION HELPER (Rayfield Style)
-- =========================================================
local function notificationText(value)
    if type(value) == "table" then
        return table.concat(value, "\n")
    end
    return tostring(value or "")
end

local function notify(title, content, duration, icon, color)
    if type(Library) ~= "table" or type(Library.Notify) ~= "function" then
        return
    end

    title = notificationText(title)
    content = notificationText(content)
    duration = tonumber(duration) or 5

    if duration < 0.1 then
        duration = 0.1
    end

    local cfg = {
        Title = title,
        Content = content,
        Duration = duration,
        Image = icon,
    }

    if color and typeof(color) == "Color3" then
        cfg.Color = color
    end

    local ok = pcall(function()
        Library:Notify(cfg)
    end)

    -- Fallback to old style if library doesn't support table yet
    if not ok then
        task.spawn(function()
            pcall(function()
                Library:Notify(content, duration, title, icon)
            end)
        end)
    end
end

-- =========================================================
-- REMOTE SCRIPT EXECUTOR HELPER
-- =========================================================
local function executeScript(url, scriptName)
    if not url or url == "" then
        notify("Error", "Script URL not found for: " .. tostring(scriptName), 5, "x-circle")
        return
    end

    notify("Executed Scripts", "Scripts Successfully Executed!", 6, "check-circle")
    task.wait(0.5)

    local ok, err = pcall(function()
        loadstring(game:HttpGet(url))()
    end)

    if not ok then
        notify(
            "Execution Error",
            "Failed to run " .. tostring(scriptName) .. "\n" .. tostring(err),
            6,
            "x-circle"
        )
    end
end

-- =========================================================
-- WINDOW SETUP
-- =========================================================

Library.ToggleKey = Enum.KeyCode.K

local Window = Library:CreateWindow({
    Title = "Ro-Netrium", Subtitle = "Created By Zaycapcay & Exterminate0",
    Tags = {
        { Text = "STEAL AN EGG", Icon = "egg", Color = Color3.fromRGB(255, 204, 0), TextColor = Color3.new(0,0,0) },
        { Text = "RNET-LATEST", Icon = "newspaper",    Color = Color3.fromRGB(46, 230, 110), TextColor = Color3.new(1,1,1) },
    },
    QuickBar = true, NetStatsBar = true, InfoTab = true, ToolsTab = true, ThemeTab = true, SaveLoad = true,
    ConfirmTitle = "Ro-Netrium", ConfirmSubtitle = "Close Ro-Netrium? Unsaved changes will be lost",
})

if not Window then
    error("[ZethHub] Failed to create Window.", 0)
end

-- Theme 
pcall(function() 
    Library:SetTheme("Royal") 
end)

-- =========================================================
-- INITIAL NOTIFY
-- =========================================================
notify("Notification Alert", "Thank you for using this scripts", 6, "bell")

-- =========================================================
-- TABS
-- =========================================================
local MainTab = Window:CreateTab("Main Scripts", "sword")

-- =========================================================
-- MAIN SCRIPTS TAB
-- =========================================================
MainTab:CreateSection("Main Menu")

MainTab:CreateParagraph({
    Title = "System Information",
    Content = {
        "This Scripts Is safe and has been tested",
        "- All these scripts are not mine",
    },
    Icon = "shield",
})

-- =========================================================
-- HELPER MULTI DROPDOWN EXECUTION
-- =========================================================

local function toSelectionList(input)
	if type(input) == "string" then
		return { input }
	end

	if type(input) ~= "table" then
		return {}
	end

	if #input > 0 then
		return input
	end

	local out = {}
	for _, v in pairs(input) do
		if type(v) == "string" then
			table.insert(out, v)
		end
	end

	return out
end

local function sendNotify(title, message, duration, icon)
	if type(notify) == "function" then
		notify(title, message, duration, icon)
	elseif type(Library) == "table" and type(Library.Notify) == "function" then
		Library:Notify(message, duration, title, icon)
	end
end

local function executeScriptList(selection, urlMap)
	local list = toSelectionList(selection)

	if #list == 0 then
		sendNotify("Error", "Please select at least one script!", 5, "x-circle")
		return
	end

	local validCount = 0
	for _, name in ipairs(list) do
		if type(name) == "string" and urlMap[name] then
			validCount = validCount + 1
		end
	end

	if validCount == 0 then
		sendNotify("Error", "Selected script has no valid URL!", 5, "x-circle")
		return
	end

	sendNotify("Status", "Executing " .. validCount .. " script(s)...", 4, "check")

	task.spawn(function()
		local done = 0

		for _, name in ipairs(list) do
			local url = type(name) == "string" and urlMap[name] or nil

			if url then
				done = done + 1

				local ok, err = pcall(function()
					if type(executeScript) == "function" then
						executeScript(url, name)
					else
						loadstring(game:HttpGet(url))()
					end
				end)

				if not ok then
					sendNotify(
						"Error",
						tostring(name) .. " failed: " .. tostring(err),
						5,
						"x-circle"
					)
				end

				if done < validCount then
					task.wait(1.2)
				end
			else
				sendNotify(
					"Error",
					"URL not found: " .. tostring(name),
					5,
					"x-circle"
				)
			end
		end

		sendNotify("Done", "All selected scripts executed.", 4, "check-circle")
	end)
end

-- =========================================================
-- MAIN SCRIPTS - MULTI DROPDOWN
-- =========================================================

local MAIN_SCRIPTS_OPTIONS = {
	"NIGHT [HUB & KEYLESS]",
	"LENNON [HUB & KEYLESS]",
	"MIRANDA [HUB & KEYLESS]",
	"Chilli [HUB & FREE]",
	"Sena [NEW UPDATE]",
	"Venyx [HUB]",
	"AXON [HUB & KEYLESS]",
	"CODIUM [HUB & FREE]",
	"LIMBO [FREE]",
    "FIGGY [RELEASE]",
}

local MAIN_SCRIPTS_URLS = {
	["NIGHT [HUB & KEYLESS]"] = "https://raw.githubusercontent.com/WhiteX1208/Scripts/refs/heads/main/StealEggOnly.luau",
	["LENNON [HUB & KEYLESS]"] = "https://flowauth.net/v1/ui/584e23b68f5f361081321954763ab5e5.lua",
	["MIRANDA [HUB & KEYLESS]"] = "https://flowauth.net/v1/ui/5f7a6b969f81332d7994e3b5eb71c686.lua",
	["Chilli [HUB & FREE]"] = "https://raw.githubusercontent.com/tienkhanh1/spicy/main/Chilli.lua",
	["Sena [NEW VERSION]"] = "https://senahub.xyz/senaloader",
	["Venyx [HUB]"] = "https://raw.githubusercontent.com/tienkhanh1/Venyx/main/VenyxHub",
	["AXON [HUB & KEYLESS]"] = "https://api.luarmor.net/files/v3/loaders/97c3f6db55a2cf72141537a85458e5a7.lua",
    ["CODIUM [HUB & FREE]"] = "https://getcodium.xyz/loader.luau",
	["LIMBO [FREE]"] = "https://limbohub.my.id/loader.lua",
    ["FIGGY [RELEASE]"] = "https://raw.githubusercontent.com/napun87/stealaneggv2/refs/heads/main/figfy.lua",
}

local selectedMainScripts = {}

MainTab:CreateMultiDropdown({
	Name = "Select Scripts",
	Icon = "layers",
	Options = MAIN_SCRIPTS_OPTIONS,
	Default = {},
	Placeholder = "None selected",
	Flag = "MainScriptMulti",
	Tooltip = "Select one or more main scripts to execute",
	Callback = function(list)
		selectedMainScripts = toSelectionList(list)
	end,
})

MainTab:CreateButton({
	Name = "Execute Selected Scripts",
	Icon = "play",
	Tooltip = "Execute all selected main scripts",
	Callback = function()
		executeScriptList(selectedMainScripts, MAIN_SCRIPTS_URLS)
	end,
})

-- =========================================================
-- PET SPAWNER & MORE - MULTI DROPDOWN
-- =========================================================

MainTab:CreateSection("Pet Spawner & More")

MainTab:CreateParagraph({
	Title = "Guide Information",
	Content = {
		"This Scripts Is safe and has been tested",
		"- All these scripts are not mine",
		"- This script is client-side only and not the real thing, so don't get your hopes up too high",
	},
	Icon = "book-open",
})

local PET_SPAWNER_OPTIONS = {
	"PET SPAWNER 1 [FREE & CLIENT]",
	"PET SPAWNER 2 [FREE & CLIENT]",
	"PET SPAWNER 3 [KEYLESS & CLIENT]",
	"PET SPAWNER 4 [KEYLESS & CLIENT]",
	"GIFTER GAMEPASS [KEYLESS & CLIENT]",
    "TENSHISC [PET FINDER/RADAR]",
}

local PET_SPAWNER_URLS = {
	["PET SPAWNER 1 [FREE & CLIENT]"] = "https://raw.githubusercontent.com/zenvex4/StealAnEgg/refs/heads/main/Loader.lua",
	["PET SPAWNER 2 [FREE & CLIENT]"] = "https://raw.githubusercontent.com/INF-Hub-PL/StealAEggScript/refs/heads/main/Pet_SpawnerV1",
	["PET SPAWNER 3 [KEYLESS & CLIENT]"] = "https://scriptversekey.xyz/s/steal-an-egg-pet-spawner",
	["PET SPAWNER 4 [KEYLESS & CLIENT]"] = "https://pastefy.app/t06eyyrw/raw",
	["GIFTER GAMEPASS [KEYLESS & CLIENT]"] = "https://pastefy.app/CkaV7ET8/raw",
    ["TENSHISC [PET FINDER/RADAR]"] = "https://raw.githubusercontent.com/syss1211/Tenshi-script/main/NYX.lua",
}

local selectedPetScripts = {}

MainTab:CreateMultiDropdown({
	Name = "Select Scripts",
	Icon = "layers",
	Options = PET_SPAWNER_OPTIONS,
	Default = {},
	Placeholder = "None selected",
	Flag = "PetScriptMulti",
	Tooltip = "Select one or more pet spawners/extra scripts",
	Callback = function(list)
		selectedPetScripts = toSelectionList(list)
	end,
})

MainTab:CreateButton({
	Name = "Execute Selected Scripts",
	Icon = "play",
	Tooltip = "Execute all selected pet spawner scripts",
	Callback = function()
		executeScriptList(selectedPetScripts, PET_SPAWNER_URLS)
	end,
})
