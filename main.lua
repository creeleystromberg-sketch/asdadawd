-- Sol's RNG Material Scanner & Tracker
-- Version: v0.8.8 | Fixed Quest Board False Positive & Environment Filter

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GUI_NAME = "SolsMaterialScanner"
local VERSION = "v0.8.8"
local BUILD = "BUILD-017"

local oldGui = playerGui:FindFirstChild(GUI_NAME)
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.Parent = playerGui

-- =========================================================
-- STATE
-- =========================================================

local diagnosticEntries = {}
local diagnosticSeen = {}
local liveMonitorEnabled = false
local descendantConnection = nil

local trackerEnabled = false
local trackerConnection = nil
local trackerVisuals = {}

local navigationToken = 0
local navigationRunning = false

local startNavigation = nil
local stopNavigation = nil

-- =========================================================
-- FILTERS & MATERIAL RECOGNITION
-- =========================================================

local BLACKLIST_WORDS = {
	"quest", "board", "shop", "store", "merchant", "stella", "jake",
	"bank", "craft", "cauldron", "altar", "portal", "teleport",
	"leaderboard", "turret", "fish", "luck buff", "clover", "four leaf",
	"four-leaf", "dialogue", "talk", "roll", "buy", "sell", "trade",
	"interact", "view", "open", "read", "sign", "statue", "stand"
}

local function lowered(value)
	return string.lower(tostring(value or ""))
end

local function isBlacklisted(model, prompt)
	if prompt then
		local action = lowered(prompt.ActionText)
		local object = lowered(prompt.ObjectText)

		for _, word in ipairs(BLACKLIST_WORDS) do
			if string.find(action, word, 1, true) or string.find(object, word, 1, true) then
				return true
			end
		end
	end

	if model then
		local current = model
		while current and current ~= Workspace and current ~= game do
			local name = lowered(current.Name)
			for _, word in ipairs(BLACKLIST_WORDS) do
				if string.find(name, word, 1, true) then
					return true
				end
			end
			current = current.Parent
		end
	end

	return false
end

local function identifyMaterial(model, prompt)
	if isBlacklisted(model, prompt) then
		return nil, nil
	end

	local promptObj = prompt and lowered(prompt.ObjectText) or ""
	local promptAct = prompt and lowered(prompt.ActionText) or ""
	local modelName = model and lowered(model.Name) or ""

	local textPool = promptObj .. " " .. promptAct .. " " .. modelName

	-- Priority 1: Check direct names
	if string.find(textPool, "eternal flame", 1, true) or string.find(textPool, "flame", 1, true) or string.find(textPool, "hell", 1, true) then
		return "Eternal Flame", "Hell"
	elseif string.find(textPool, "piece of star", 1, true) or string.find(textPool, "star piece", 1, true) or (string.find(textPool, "star", 1, true) and not string.find(textPool, "start", 1, true)) then
		return "Piece of Star", "Starfall"
	elseif string.find(textPool, "feather vial", 1, true) or string.find(textPool, "feather", 1, true) or string.find(textPool, "vial", 1, true) or string.find(textPool, "heaven", 1, true) then
		return "Feather Vial", "Heaven"
	elseif string.find(textPool, "curruptaine", 1, true) or string.find(textPool, "corruptaine", 1, true) or string.find(textPool, "corrupt", 1, true) then
		return "Curruptaine", "Corruption"
	elseif string.find(textPool, "null", 1, true) or string.find(textPool, "void", 1, true) then
		return "NULL?", "Null"
	elseif string.find(textPool, "wind essence", 1, true) or string.find(textPool, "essence", 1, true) or string.find(textPool, "wind", 1, true) then
		return "Wind Essence", "Windy"
	elseif string.find(textPool, "icicle", 1, true) or string.find(textPool, "snow", 1, true) then
		return "Icicle", "Snowy"
	elseif string.find(textPool, "hour glass", 1, true) or string.find(textPool, "hourglass", 1, true) or string.find(textPool, "sand", 1, true) then
		return "Hour Glass", "Sandstorm"
	elseif string.find(textPool, "rainy bottle", 1, true) or string.find(textPool, "rain", 1, true) or string.find(textPool, "bottle", 1, true) then
		return "Rainy Bottle", "Rainy"
	end

	-- Priority 2: Check immediate child parts if model name was generic
	if model then
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") then
				local cn = lowered(child.Name)
				if string.find(cn, "flame", 1, true) then return "Eternal Flame", "Hell"
				elseif string.find(cn, "star", 1, true) and not string.find(cn, "start", 1, true) then return "Piece of Star", "Starfall"
				elseif string.find(cn, "feather", 1, true) or string.find(cn, "vial", 1, true) then return "Feather Vial", "Heaven"
				elseif string.find(cn, "corrupt", 1, true) then return "Curruptaine", "Corruption"
				elseif string.find(cn, "null", 1, true) then return "NULL?", "Null"
				elseif string.find(cn, "wind", 1, true) then return "Wind Essence", "Windy"
				elseif string.find(cn, "icicle", 1, true) then return "Icicle", "Snowy"
				elseif string.find(cn, "hour", 1, true) or string.find(cn, "sand", 1, true) then return "Hour Glass", "Sandstorm"
				elseif string.find(cn, "bottle", 1, true) then return "Rainy Bottle", "Rainy" end
			end
		end
	end

	return nil, nil
end

local materialRows = {}

-- =========================================================
-- UI BUILDER
-- =========================================================

local function uiCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 7)
	c.Parent = parent
	return c
end

local function uiStroke(parent, transparency)
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(72, 76, 86)
	s.Thickness = 1
	s.Transparency = transparency or 0.25
	s.Parent = parent
	return s
end

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(690, 430)
main.Position = UDim2.new(0.5, -345, 0.5, -215)
main.BackgroundColor3 = Color3.fromRGB(14, 15, 18)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
uiCorner(main, 10)
uiStroke(main, 0.18)

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = Color3.fromRGB(18, 19, 23)
header.BorderSizePixel = 0
header.Parent = main
uiCorner(header, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -120, 1, 0)
title.Position = UDim2.fromOffset(14, 0)
title.BackgroundTransparency = 1
title.Text = "Sol's RNG Scanner"
title.TextColor3 = Color3.fromRGB(244, 245, 247)
title.TextSize = 16
title.Font = Enum.Font.GothamMedium
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local versionLabel = Instance.new("TextLabel")
versionLabel.Size = UDim2.fromOffset(150, 18)
versionLabel.Position = UDim2.fromOffset(145, 13)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = VERSION .. "  •  " .. BUILD
versionLabel.TextColor3 = Color3.fromRGB(124, 129, 140)
versionLabel.TextSize = 10
versionLabel.Font = Enum.Font.Gotham
versionLabel.TextXAlignment = Enum.TextXAlignment.Left
versionLabel.Parent = header

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.fromOffset(30, 28)
minimizeButton.Position = UDim2.new(1, -70, 0, 8)
minimizeButton.BackgroundColor3 = Color3.fromRGB(31, 33, 39)
minimizeButton.BorderSizePixel = 0
minimizeButton.Text = "–"
minimizeButton.TextColor3 = Color3.fromRGB(220, 222, 226)
minimizeButton.TextSize = 17
minimizeButton.Font = Enum.Font.GothamMedium
minimizeButton.Parent = header
uiCorner(minimizeButton, 6)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(30, 28)
closeButton.Position = UDim2.new(1, -36, 0, 8)
closeButton.BackgroundColor3 = Color3.fromRGB(31, 33, 39)
closeButton.BorderSizePixel = 0
closeButton.Text = "×"
closeButton.TextColor3 = Color3.fromRGB(225, 120, 120)
closeButton.TextSize = 18
closeButton.Font = Enum.Font.GothamMedium
closeButton.Parent = header
uiCorner(closeButton, 6)

local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.fromOffset(138, 370)
sidebar.Position = UDim2.fromOffset(10, 50)
sidebar.BackgroundColor3 = Color3.fromRGB(17, 18, 21)
sidebar.BorderSizePixel = 0
sidebar.Parent = main
uiCorner(sidebar, 8)

local function makeTab(text, y)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -12, 0, 35)
	b.Position = UDim2.fromOffset(6, y)
	b.BackgroundColor3 = Color3.fromRGB(23, 25, 30)
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = Color3.fromRGB(170, 174, 184)
	b.TextSize = 12
	b.Font = Enum.Font.GothamMedium
	b.Parent = sidebar
	uiCorner(b, 6)
	return b
end

local materialsTabButton = makeTab("Materials", 7)
local trackerTabButton = makeTab("Tracker", 48)
local playerTabButton = makeTab("Player", 89)
local serverTabButton = makeTab("Server", 130)
local diagnosticTabButton = makeTab("Diagnostic", 171)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -166, 1, -60)
content.Position = UDim2.fromOffset(156, 50)
content.BackgroundTransparency = 1
content.Parent = main

local pages = {}

local function makePage(name)
	local p = Instance.new("Frame")
	p.Name = name
	p.Size = UDim2.fromScale(1, 1)
	p.BackgroundTransparency = 1
	p.Visible = false
	p.Parent = content
	pages[name] = p
	return p
end

local materialsPage = makePage("Materials")
local trackerPage = makePage("Tracker")
local playerPage = makePage("Player")
local serverPage = makePage("Server")
local diagnosticPage = makePage("Diagnostic")

local function pageTitle(page, text, subtitle)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 28)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = Color3.fromRGB(242, 243, 245)
	t.TextSize = 20
	t.Font = Enum.Font.GothamMedium
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = page

	local s = Instance.new("TextLabel")
	s.Size = UDim2.new(1, 0, 0, 32)
	s.Position = UDim2.fromOffset(0, 30)
	s.BackgroundTransparency = 1
	s.Text = subtitle
	s.TextColor3 = Color3.fromRGB(126, 131, 142)
	s.TextSize = 11
	s.Font = Enum.Font.Gotham
	s.TextWrapped = true
	s.TextXAlignment = Enum.TextXAlignment.Left
	s.TextYAlignment = Enum.TextYAlignment.Top
	s.Parent = page
end

pageTitle(materialsPage, "Materials", "Only genuine dropped materials appear here.")

local materialList = Instance.new("ScrollingFrame")
materialList.Size = UDim2.new(1, 0, 1, -72)
materialList.Position = UDim2.fromOffset(0, 68)
materialList.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
materialList.BorderSizePixel = 0
materialList.ScrollBarThickness = 4
materialList.AutomaticCanvasSize = Enum.AutomaticSize.Y
materialList.CanvasSize = UDim2.fromOffset(0, 0)
materialList.Parent = materialsPage
uiCorner(materialList, 8)

local materialPadding = Instance.new("UIPadding")
materialPadding.PaddingTop = UDim.new(0, 7)
materialPadding.PaddingBottom = UDim.new(0, 7)
materialPadding.PaddingLeft = UDim.new(0, 7)
materialPadding.PaddingRight = UDim.new(0, 7)
materialPadding.Parent = materialList

local materialLayout = Instance.new("UIListLayout")
materialLayout.Padding = UDim.new(0, 6)
materialLayout.SortOrder = Enum.SortOrder.LayoutOrder
materialLayout.Parent = materialList

local emptyMaterials = Instance.new("TextLabel")
emptyMaterials.Size = UDim2.new(1, -10, 0, 42)
emptyMaterials.BackgroundTransparency = 1
emptyMaterials.Text = "No materials detected on map"
emptyMaterials.TextColor3 = Color3.fromRGB(112, 117, 128)
emptyMaterials.TextSize = 12
emptyMaterials.Font = Enum.Font.Gotham
emptyMaterials.Parent = materialList

pageTitle(trackerPage, "Tracker & AI", "Visual markers and automated routing.")

local trackButton = Instance.new("TextButton")
trackButton.Size = UDim2.fromOffset(170, 36)
trackButton.Position = UDim2.fromOffset(0, 76)
trackButton.BackgroundColor3 = Color3.fromRGB(32, 35, 42)
trackButton.BorderSizePixel = 0
trackButton.Text = "TRACK ITEMS: OFF"
trackButton.TextColor3 = Color3.fromRGB(235, 236, 240)
trackButton.TextSize = 12
trackButton.Font = Enum.Font.GothamBold
trackButton.Parent = trackerPage
uiCorner(trackButton, 7)

local stopNavigationButton = Instance.new("TextButton")
stopNavigationButton.Size = UDim2.fromOffset(110, 36)
stopNavigationButton.Position = UDim2.fromOffset(180, 76)
stopNavigationButton.BackgroundColor3 = Color3.fromRGB(49, 31, 34)
stopNavigationButton.BorderSizePixel = 0
stopNavigationButton.Text = "STOP AI"
stopNavigationButton.TextColor3 = Color3.fromRGB(229, 169, 173)
stopNavigationButton.TextSize = 12
stopNavigationButton.Font = Enum.Font.GothamBold
stopNavigationButton.Parent = trackerPage
uiCorner(stopNavigationButton, 7)

local trackerStatus = Instance.new("TextLabel")
trackerStatus.Size = UDim2.new(1, 0, 0, 70)
trackerStatus.Position = UDim2.fromOffset(0, 124)
trackerStatus.BackgroundTransparency = 1
trackerStatus.Text = "Tracker is off."
trackerStatus.TextColor3 = Color3.fromRGB(146, 151, 162)
trackerStatus.TextSize = 12
trackerStatus.Font = Enum.Font.Gotham
trackerStatus.TextWrapped = true
trackerStatus.TextXAlignment = Enum.TextXAlignment.Left
trackerStatus.TextYAlignment = Enum.TextYAlignment.Top
trackerStatus.Parent = trackerPage

local navigationStatus = Instance.new("TextLabel")
navigationStatus.Size = UDim2.new(1, 0, 0, 96)
navigationStatus.Position = UDim2.fromOffset(0, 205)
navigationStatus.BackgroundColor3 = Color3.fromRGB(18, 19, 23)
navigationStatus.BackgroundTransparency = 0.2
navigationStatus.BorderSizePixel = 0
navigationStatus.Text = "AI: idle\nClick GO next to a material in the Materials tab."
navigationStatus.TextColor3 = Color3.fromRGB(181, 185, 194)
navigationStatus.TextSize = 11
navigationStatus.Font = Enum.Font.Gotham
navigationStatus.TextWrapped = true
navigationStatus.TextXAlignment = Enum.TextXAlignment.Left
navigationStatus.TextYAlignment = Enum.TextYAlignment.Top
navigationStatus.Parent = trackerPage
uiCorner(navigationStatus, 7)
uiStroke(navigationStatus, 0.62)

local navigationPadding = Instance.new("UIPadding")
navigationPadding.PaddingTop = UDim.new(0, 9)
navigationPadding.PaddingBottom = UDim.new(0, 9)
navigationPadding.PaddingLeft = UDim.new(0, 10)
navigationPadding.PaddingRight = UDim.new(0, 10)
navigationPadding.Parent = navigationStatus

stopNavigationButton.MouseButton1Click:Connect(function()
	if stopNavigation then
		stopNavigation("Stopped by user.")
	else
		navigationStatus.Text = "AI: not initialized."
	end
end)

pageTitle(playerPage, "Player", "Local player adjustments.")

local speedCard = Instance.new("Frame")
speedCard.Size = UDim2.new(1, 0, 0, 82)
speedCard.Position = UDim2.fromOffset(0, 74)
speedCard.BackgroundColor3 = Color3.fromRGB(18, 19, 23)
speedCard.BorderSizePixel = 0
speedCard.Parent = playerPage
uiCorner(speedCard, 8)
uiStroke(speedCard, 0.5)

local speedName = Instance.new("TextLabel")
speedName.Size = UDim2.new(1, -180, 0, 24)
speedName.Position = UDim2.fromOffset(12, 10)
speedName.BackgroundTransparency = 1
speedName.Text = "WalkSpeed"
speedName.TextColor3 = Color3.fromRGB(235, 237, 240)
speedName.TextSize = 13
speedName.Font = Enum.Font.GothamMedium
speedName.TextXAlignment = Enum.TextXAlignment.Left
speedName.Parent = speedCard

local speedValue = Instance.new("TextLabel")
speedValue.Size = UDim2.fromOffset(60, 28)
speedValue.Position = UDim2.new(1, -144, 0, 27)
speedValue.BackgroundTransparency = 1
speedValue.Text = "16"
speedValue.TextColor3 = Color3.fromRGB(210, 213, 220)
speedValue.TextSize = 15
speedValue.Font = Enum.Font.GothamMedium
speedValue.Parent = speedCard

local minusSpeed = Instance.new("TextButton")
minusSpeed.Size = UDim2.fromOffset(34, 30)
minusSpeed.Position = UDim2.new(1, -82, 0, 25)
minusSpeed.BackgroundColor3 = Color3.fromRGB(31, 33, 39)
minusSpeed.BorderSizePixel = 0
minusSpeed.Text = "−"
minusSpeed.TextColor3 = Color3.fromRGB(225, 226, 230)
minusSpeed.TextSize = 18
minusSpeed.Font = Enum.Font.GothamMedium
minusSpeed.Parent = speedCard
uiCorner(minusSpeed, 6)

local plusSpeed = Instance.new("TextButton")
plusSpeed.Size = UDim2.fromOffset(34, 30)
plusSpeed.Position = UDim2.new(1, -42, 0, 25)
plusSpeed.BackgroundColor3 = Color3.fromRGB(31, 33, 39)
plusSpeed.BorderSizePixel = 0
plusSpeed.Text = "+"
plusSpeed.TextColor3 = Color3.fromRGB(225, 226, 230)
plusSpeed.TextSize = 17
plusSpeed.Font = Enum.Font.GothamMedium
plusSpeed.Parent = speedCard
uiCorner(plusSpeed, 6)

local speedHint = Instance.new("TextLabel")
speedHint.Size = UDim2.new(1, -180, 0, 20)
speedHint.Position = UDim2.fromOffset(12, 39)
speedHint.BackgroundTransparency = 1
speedHint.Text = "Adjust movement speed"
speedHint.TextColor3 = Color3.fromRGB(114, 119, 130)
speedHint.TextSize = 10
speedHint.Font = Enum.Font.Gotham
speedHint.TextXAlignment = Enum.TextXAlignment.Left
speedHint.Parent = speedCard

pageTitle(serverPage, "Private Server", "Teleport directly via Join Guard, link, or JobId.")

local serverInput = Instance.new("TextBox")
serverInput.Size = UDim2.new(1, 0, 0, 38)
serverInput.Position = UDim2.fromOffset(0, 76)
serverInput.BackgroundColor3 = Color3.fromRGB(18, 19, 23)
serverInput.BorderSizePixel = 0
serverInput.PlaceholderText = "https://www.roblox.com/share?code=..."
serverInput.PlaceholderColor3 = Color3.fromRGB(91, 96, 107)
serverInput.Text = ""
serverInput.TextColor3 = Color3.fromRGB(232, 234, 238)
serverInput.TextSize = 11
serverInput.Font = Enum.Font.Code
serverInput.ClearTextOnFocus = false
serverInput.Parent = serverPage
uiCorner(serverInput, 7)
uiStroke(serverInput, 0.55)

local joinServer = Instance.new("TextButton")
joinServer.Size = UDim2.fromOffset(100, 34)
joinServer.Position = UDim2.fromOffset(0, 124)
joinServer.BackgroundColor3 = Color3.fromRGB(42, 129, 78)
joinServer.BorderSizePixel = 0
joinServer.Text = "JOIN"
joinServer.TextColor3 = Color3.fromRGB(245, 250, 247)
joinServer.TextSize = 12
joinServer.Font = Enum.Font.GothamBold
joinServer.Parent = serverPage
uiCorner(joinServer, 7)

local serverStatus = Instance.new("TextLabel")
serverStatus.Size = UDim2.new(1, -112, 0, 52)
serverStatus.Position = UDim2.fromOffset(112, 120)
serverStatus.BackgroundTransparency = 1
serverStatus.Text = "Waiting for link."
serverStatus.TextColor3 = Color3.fromRGB(125, 130, 141)
serverStatus.TextSize = 11
serverStatus.Font = Enum.Font.Gotham
serverStatus.TextWrapped = true
serverStatus.TextXAlignment = Enum.TextXAlignment.Left
serverStatus.TextYAlignment = Enum.TextYAlignment.Center
serverStatus.Parent = serverPage

pageTitle(diagnosticPage, "Diagnostic", "Workspace scanner for prompts and parts.")

local buttonRow = Instance.new("Frame")
buttonRow.Size = UDim2.new(1, 0, 0, 34)
buttonRow.Position = UDim2.fromOffset(0, 70)
buttonRow.BackgroundTransparency = 1
buttonRow.Parent = diagnosticPage

local function diagnosticButton(text, width, x)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width, 30)
	b.Position = UDim2.fromOffset(x, 0)
	b.BackgroundColor3 = Color3.fromRGB(31, 33, 39)
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = Color3.fromRGB(220, 222, 228)
	b.TextSize = 11
	b.Font = Enum.Font.GothamMedium
	b.Parent = buttonRow
	uiCorner(b, 6)
	return b
end

local scanButton = diagnosticButton("SCAN", 72, 0)
local liveButton = diagnosticButton("LIVE: OFF", 92, 78)
local copyButton = diagnosticButton("COPY ALL", 92, 176)
local clearButton = diagnosticButton("CLEAR", 72, 274)

local diagnosticStatus = Instance.new("TextLabel")
diagnosticStatus.Size = UDim2.new(1, 0, 0, 30)
diagnosticStatus.Position = UDim2.fromOffset(0, 108)
diagnosticStatus.BackgroundTransparency = 1
diagnosticStatus.Text = "SCAN = current objects | LIVE = newly created objects"
diagnosticStatus.TextColor3 = Color3.fromRGB(120, 125, 136)
diagnosticStatus.TextSize = 10
diagnosticStatus.Font = Enum.Font.Gotham
diagnosticStatus.TextXAlignment = Enum.TextXAlignment.Left
diagnosticStatus.Parent = diagnosticPage

local resultsFrame = Instance.new("ScrollingFrame")
resultsFrame.Size = UDim2.new(1, 0, 1, -145)
resultsFrame.Position = UDim2.fromOffset(0, 140)
resultsFrame.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
resultsFrame.BorderSizePixel = 0
resultsFrame.ScrollBarThickness = 4
resultsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
resultsFrame.CanvasSize = UDim2.fromOffset(0, 0)
resultsFrame.Parent = diagnosticPage
uiCorner(resultsFrame, 8)

local resultsPadding = Instance.new("UIPadding")
resultsPadding.PaddingTop = UDim.new(0, 7)
resultsPadding.PaddingBottom = UDim.new(0, 7)
resultsPadding.PaddingLeft = UDim.new(0, 7)
resultsPadding.PaddingRight = UDim.new(0, 7)
resultsPadding.Parent = resultsFrame

local resultsLayout = Instance.new("UIListLayout")
resultsLayout.Padding = UDim.new(0, 5)
resultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
resultsLayout.Parent = resultsFrame

local miniButton = Instance.new("TextButton")
miniButton.Size = UDim2.fromOffset(44, 44)
miniButton.Position = UDim2.new(0.5, -22, 0.5, -22)
miniButton.BackgroundColor3 = Color3.fromRGB(18, 19, 23)
miniButton.BorderSizePixel = 0
miniButton.Text = "S"
miniButton.TextColor3 = Color3.fromRGB(235, 237, 240)
miniButton.TextSize = 16
miniButton.Font = Enum.Font.GothamBold
miniButton.Visible = false
miniButton.Active = true
miniButton.Draggable = true
miniButton.Parent = gui
uiCorner(miniButton, 9)
uiStroke(miniButton, 0.32)

local function showPage(name, button)
	for pageName, page in pairs(pages) do
		page.Visible = pageName == name
	end

	for _, b in ipairs({
		materialsTabButton,
		trackerTabButton,
		playerTabButton,
		serverTabButton,
		diagnosticTabButton
	}) do
		b.BackgroundColor3 = Color3.fromRGB(23, 25, 30)
		b.TextColor3 = Color3.fromRGB(150, 154, 165)
	end

	button.BackgroundColor3 = Color3.fromRGB(34, 37, 44)
	button.TextColor3 = Color3.fromRGB(241, 242, 245)
end

materialsTabButton.MouseButton1Click:Connect(function() showPage("Materials", materialsTabButton) end)
trackerTabButton.MouseButton1Click:Connect(function() showPage("Tracker", trackerTabButton) end)
playerTabButton.MouseButton1Click:Connect(function() showPage("Player", playerTabButton) end)
serverTabButton.MouseButton1Click:Connect(function() showPage("Server", serverTabButton) end)
diagnosticTabButton.MouseButton1Click:Connect(function() showPage("Diagnostic", diagnosticTabButton) end)

showPage("Materials", materialsTabButton)

minimizeButton.MouseButton1Click:Connect(function()
	main.Visible = false
	miniButton.Visible = true
end)

miniButton.MouseButton1Click:Connect(function()
	miniButton.Visible = false
	main.Visible = true
end)

closeButton.MouseButton1Click:Connect(function()
	navigationToken += 1
	navigationRunning = false

	if descendantConnection then
		descendantConnection:Disconnect()
		descendantConnection = nil
	end

	if trackerConnection then
		trackerConnection:Disconnect()
		trackerConnection = nil
	end

	for _, visual in pairs(trackerVisuals) do
		for _, object in pairs(visual) do
			if typeof(object) == "Instance" then
				pcall(function() object:Destroy() end)
			end
		end
	end

	gui:Destroy()
end)

local function currentHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function refreshSpeedValue()
	local humanoid = currentHumanoid()
	speedValue.Text = humanoid and tostring(math.floor(humanoid.WalkSpeed + 0.5)) or "?"
end

minusSpeed.MouseButton1Click:Connect(function()
	local humanoid = currentHumanoid()
	if humanoid then
		humanoid.WalkSpeed = math.max(1, humanoid.WalkSpeed - 1)
		refreshSpeedValue()
	end
end)

plusSpeed.MouseButton1Click:Connect(function()
	local humanoid = currentHumanoid()
	if humanoid then
		humanoid.WalkSpeed = humanoid.WalkSpeed + 1
		refreshSpeedValue()
	end
end)

player.CharacterAdded:Connect(function()
	task.wait(1)
	refreshSpeedValue()
end)

refreshSpeedValue()

-- =========================================================
-- UTILITY / SERVER JOIN
-- =========================================================

local function getExternalUrlOpener()
	if type(openurl) == "function" then return openurl end
	if type(open_url) == "function" then return open_url end
	if syn and type(syn.open_url) == "function" then return syn.open_url end
	return nil
end

local function copyToClipboard(text)
	local clipboard =
		(type(setclipboard) == "function" and setclipboard)
		or (type(toclipboard) == "function" and toclipboard)
		or (syn and type(syn.write_clipboard) == "function" and syn.write_clipboard)

	if clipboard then
		local ok = pcall(function() clipboard(text) end)
		return ok
	end
	return false
end

local function cleanServerInput(raw)
	local text = tostring(raw or ""):gsub("\\_", "_")
	local url = text:match("(https?://[^%s%)%]]+)")
	if url then text = url end
	text = text:gsub('[">]+$', ""):gsub("%s+", "")
	return text
end

joinServer.MouseButton1Click:Connect(function()
	local text = cleanServerInput(serverInput.Text)
	if text == "" then
		serverStatus.Text = "Paste a server link first."
		return
	end
	serverInput.Text = text

	local joinGuardId = text:match("^https?://join%-guard%.solsstattracker%.com/([%w_%-]+)")
	if joinGuardId then
		serverStatus.Text = "Join Guard detected. Opening..."
		local opener = getExternalUrlOpener()
		if opener then
			pcall(function() opener(text) end)
		else
			copyToClipboard(text)
			serverStatus.Text = "Link copied — complete verification in your browser."
		end
		return
	end

	local gameInstanceId = text:match("[?&]gameInstanceId=([^&]+)")
	if gameInstanceId then
		serverStatus.Text = "Joining server instance..."
		pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, gameInstanceId, player) end)
		return
	end

	if string.find(lowered(text), "roblox.com/", 1, true) and (text:match("[?&]code=([^&]+)") or text:match("[?&]privateServerLinkCode=([^&]+)")) then
		local opener = getExternalUrlOpener()
		if opener then
			pcall(function() opener(text) end)
		else
			copyToClipboard(text)
			serverStatus.Text = "Private server link copied to clipboard."
		end
		return
	end

	if #text > 20 and not string.find(lowered(text), "http", 1, true) then
		serverStatus.Text = "Joining JobId..."
		pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, text, player) end)
		return
	end

	serverStatus.Text = "Unsupported server link format."
end)

-- =========================================================
-- MATERIAL UI REFRESH
-- =========================================================

local function clearMaterialRows()
	for _, row in pairs(materialRows) do
		if row.frame and row.frame.Parent then
			row.frame:Destroy()
		end
	end
	materialRows = {}
end

local function refreshMaterialsUI(entries)
	clearMaterialRows()

	emptyMaterials.Visible = #entries == 0

	for index, entry in ipairs(entries) do
		local row = Instance.new("Frame")
		row.Name = "Material_" .. index
		row.Size = UDim2.new(1, -4, 0, 58)
		row.BackgroundColor3 = Color3.fromRGB(19, 20, 24)
		row.BorderSizePixel = 0
		row.LayoutOrder = index
		row.Parent = materialList
		uiCorner(row, 7)
		uiStroke(row, 0.62)

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -155, 0, 24)
		name.Position = UDim2.fromOffset(10, 6)
		name.BackgroundTransparency = 1
		name.Text = entry.name
		name.TextColor3 = Color3.fromRGB(239, 240, 243)
		name.TextSize = 13
		name.Font = Enum.Font.GothamMedium
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Parent = row

		local details = Instance.new("TextLabel")
		details.Size = UDim2.new(1, -155, 0, 18)
		details.Position = UDim2.fromOffset(10, 31)
		details.BackgroundTransparency = 1
		details.Text = entry.biome .. "  •  " .. tostring(math.floor(entry.distance + 0.5)) .. " studs"
		details.TextColor3 = Color3.fromRGB(124, 129, 140)
		details.TextSize = 10
		details.Font = Enum.Font.Gotham
		details.TextXAlignment = Enum.TextXAlignment.Left
		details.Parent = row

		local go = Instance.new("TextButton")
		go.Size = UDim2.fromOffset(70, 30)
		go.Position = UDim2.new(1, -80, 0.5, -15)
		go.BackgroundColor3 = Color3.fromRGB(43, 137, 81)
		go.BorderSizePixel = 0
		go.Text = "GO"
		go.TextColor3 = Color3.fromRGB(247, 251, 248)
		go.TextSize = 11
		go.Font = Enum.Font.GothamBold
		go.Parent = row
		uiCorner(go, 6)

		go.MouseButton1Click:Connect(function()
			showPage("Tracker", trackerTabButton)

			if startNavigation then
				startNavigation(entry)
			else
				navigationStatus.Text = "AI error: navigation module not ready."
			end
		end)

		materialRows[entry.model] = {
			frame = row,
			name = entry.name
		}
	end
end

-- =========================================================
-- SCANNER & OBJECT SEARCH
-- =========================================================

local function trackerRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function targetPartForModel(model, prompt)
	if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
		return prompt.Parent
	end

	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function getAllPickupEntries()
	local root = trackerRoot()
	local entries = {}
	local seen = {}

	if not root then return entries end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and descendant.Enabled then
			local model = descendant:FindFirstAncestorOfClass("Model")
			if model and not seen[model] then
				local standardName, biome = identifyMaterial(model, descendant)
				if standardName and biome then
					local part = targetPartForModel(model, descendant)
					if part then
						seen[model] = true
						table.insert(entries, {
							model = model,
							prompt = descendant,
							part = part,
							name = standardName,
							biome = biome,
							distance = (root.Position - part.Position).Magnitude,
						})
					end
				end
			end
		end
	end

	table.sort(entries, function(a, b) return a.distance < b.distance end)
	return entries
end

-- =========================================================
-- PATHFINDING NAVIGATION
-- =========================================================

local NAV_MAX_REPATHS = 6

local function setNavigationStatus(line1, line2, line3)
	local lines = { line1 }
	if line2 and line2 ~= "" then table.insert(lines, line2) end
	if line3 and line3 ~= "" then table.insert(lines, line3) end
	navigationStatus.Text = table.concat(lines, "\n")
end

local function navigationCharacter()
	local character = player.Character
	if not character then return nil, nil, nil end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return character, nil, nil
	end

	return character, humanoid, root
end

local function tryFirePrompt(prompt)
	if not prompt or not prompt.Parent or not prompt.Enabled then
		return false, "Prompt unavailable."
	end

	if type(fireproximityprompt) == "function" then
		local ok, err = pcall(function()
			fireproximityprompt(prompt, 0)
		end)
		return ok, ok and nil or tostring(err)
	end

	return false, "Press E to collect."
end

local function moveToWaypoint(token, humanoid, root, targetPos)
	local started = os.clock()
	humanoid:MoveTo(targetPos)

	while os.clock() - started < 3.2 do
		if token ~= navigationToken or not navigationRunning then return false, "cancelled" end
		if not humanoid.Parent or humanoid.Health <= 0 or not root.Parent then return false, "unavailable" end

		local currentPos = root.Position
		local dist = (Vector3.new(currentPos.X, 0, currentPos.Z) - Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude

		if dist <= 3.4 then
			return true
		end

		task.wait(0.05)
	end

	return false, "timeout"
end

local function directApproach(token, entry, humanoid, root)
	local started = os.clock()
	while os.clock() - started < 8 do
		if token ~= navigationToken or not navigationRunning then return false end
		if not entry.part or not entry.part.Parent then return false end

		local targetPos = entry.part.Position
		local dist = (root.Position - targetPos).Magnitude

		if dist <= math.max(4.5, (entry.prompt and entry.prompt.MaxActivationDistance or 8) - 1.0) then
			return true
		end

		humanoid:MoveTo(targetPos)
		task.wait(0.08)
	end

	return false
end

local function followPath(token, entry, humanoid, root)
	if not entry.part or not entry.part.Parent then return false, "Target gone" end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2.0,
		AgentHeight = 5.0,
		AgentCanJump = true,
		AgentJumpHeight = 7.5,
		AgentMaxSlope = 50.0,
		WaypointSpacing = 4.0,
	})

	local ok, _ = pcall(function()
		path:ComputeAsync(root.Position, entry.part.Position)
	end)

	if not ok or path.Status ~= Enum.PathStatus.Success then
		return directApproach(token, entry, humanoid, root), "Direct walk"
	end

	local waypoints = path:GetWaypoints()
	if #waypoints < 2 then
		return directApproach(token, entry, humanoid, root), "Direct walk"
	end

	for i = 2, #waypoints do
		if token ~= navigationToken or not navigationRunning then return false, "cancelled" end
		if not entry.model.Parent or not entry.part.Parent then return false, "Target gone" end

		local wp = waypoints[i]
		local remainingDist = (root.Position - entry.part.Position).Magnitude

		if remainingDist <= math.max(4.5, (entry.prompt and entry.prompt.MaxActivationDistance or 8) - 1.0) then
			return true, "In range"
		end

		setNavigationStatus(
			"AI: walking to " .. entry.name,
			"Waypoint " .. tostring(i - 1) .. "/" .. tostring(#waypoints - 1),
			tostring(math.floor(remainingDist + 0.5)) .. " studs remaining"
		)

		local reached, why = moveToWaypoint(token, humanoid, root, wp.Position)
		if not reached and why == "cancelled" then
			return false, "cancelled"
		end
	end

	return true, "Completed"
end

stopNavigation = function(reason)
	navigationToken += 1
	navigationRunning = false

	local _, humanoid, root = navigationCharacter()
	if humanoid and root then
		humanoid:MoveTo(root.Position)
	end

	setNavigationStatus("AI: idle", reason or "Navigation stopped.")
end

startNavigation = function(entry)
	if not entry or not entry.model or not entry.model.Parent or not entry.part or not entry.part.Parent then
		setNavigationStatus("AI: error", "Material no longer exists.")
		return
	end

	navigationToken += 1
	local token = navigationToken

	navigationRunning = true

	setNavigationStatus("AI: routing", entry.name, tostring(math.floor(entry.distance + 0.5)) .. " studs away")

	task.spawn(function()
		for attempt = 1, NAV_MAX_REPATHS do
			if token ~= navigationToken or not navigationRunning then return end
			if not entry.model.Parent or not entry.part.Parent then
				stopNavigation("Material was collected.")
				return
			end

			local _, humanoid, root = navigationCharacter()
			if not humanoid or not root then
				stopNavigation("Character unavailable.")
				return
			end

			local targetDist = (root.Position - entry.part.Position).Magnitude
			local activationDist = entry.prompt and math.max(4.5, entry.prompt.MaxActivationDistance) or 8

			if targetDist <= activationDist then
				setNavigationStatus("AI: arrived at " .. entry.name, "Collecting material...")
				local fired, err = tryFirePrompt(entry.prompt)
				if fired then
					task.wait(0.35)
					if not entry.model.Parent then
						navigationRunning = false
						setNavigationStatus("AI: complete", entry.name .. " collected.")
						return
					end
					task.wait(0.5)
					if not entry.model.Parent then
						navigationRunning = false
						setNavigationStatus("AI: complete", entry.name .. " collected.")
						return
					end
				else
					navigationRunning = false
					setNavigationStatus("AI: arrived", err or "Press E to collect.")
					return
				end
			end

			setNavigationStatus("AI: walking", entry.name, "Attempt " .. tostring(attempt) .. "/" .. tostring(NAV_MAX_REPATHS))

			local reached, reason = followPath(token, entry, humanoid, root)
			if token ~= navigationToken or not navigationRunning then return end

			if reached then
				task.wait(0.1)
			else
				setNavigationStatus("AI: rerouting", reason or "Path rerouted.", "Attempt " .. tostring(attempt) .. "/" .. tostring(NAV_MAX_REPATHS))
				task.wait(0.2)
			end
		end

		if token == navigationToken and navigationRunning then
			navigationRunning = false
			setNavigationStatus("AI: stopped", "Could not reach target.")
		end
	end)
end

-- =========================================================
-- VISUAL TRACKING
-- =========================================================

local function destroyTrackerVisual(model)
	local visual = trackerVisuals[model]
	if not visual then return end

	for _, object in pairs(visual) do
		if typeof(object) == "Instance" then
			pcall(function() object:Destroy() end)
		end
	end
	trackerVisuals[model] = nil
end

local function clearTrackerVisuals()
	local models = {}
	for model in pairs(trackerVisuals) do table.insert(models, model) end
	for _, model in ipairs(models) do destroyTrackerVisual(model) end
end

local function createTrackerVisual(model, targetPart, name, biome)
	local root = trackerRoot()
	if not root or not model or not targetPart then return end

	destroyTrackerVisual(model)

	local sourceAttachment = Instance.new("Attachment")
	sourceAttachment.Name = "SolsTrackerSource"
	sourceAttachment.Parent = root

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "SolsTrackerTarget"
	targetAttachment.Parent = targetPart

	local beam = Instance.new("Beam")
	beam.Name = "SolsTrackerBeam"
	beam.Attachment0 = sourceAttachment
	beam.Attachment1 = targetAttachment
	beam.Width0 = 1.1
	beam.Width1 = 0.7
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Brightness = 2.5
	beam.Segments = 24
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 0.15)
	})
	beam.Parent = root

	local highlight = Instance.new("Highlight")
	highlight.Name = "SolsTrackerHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(235, 238, 244)
	highlight.FillTransparency = 0.88
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0.2
	highlight.Parent = gui

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SolsTrackerBillboard"
	billboard.Adornee = targetPart
	billboard.Size = UDim2.fromOffset(178, 50)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(14, 15, 18)
	card.BackgroundTransparency = 0.18
	card.BorderSizePixel = 0
	card.Parent = billboard
	uiCorner(card, 7)

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(220, 224, 232)
	cardStroke.Thickness = 1
	cardStroke.Transparency = 0.58
	cardStroke.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -14, 0, 25)
	nameLabel.Position = UDim2.fromOffset(7, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(248, 249, 251)
	nameLabel.TextSize = 13
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.Text = name .. " (" .. biome .. ")"
	nameLabel.TextWrapped = true
	nameLabel.Parent = card

	local distanceLabel = Instance.new("TextLabel")
	distanceLabel.Name = "DistanceLabel"
	distanceLabel.Size = UDim2.new(1, -14, 0, 16)
	distanceLabel.Position = UDim2.fromOffset(7, 28)
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.TextColor3 = Color3.fromRGB(166, 172, 184)
	distanceLabel.TextSize = 11
	distanceLabel.Font = Enum.Font.Gotham
	distanceLabel.Parent = card

	trackerVisuals[model] = {
		sourceAttachment = sourceAttachment,
		targetAttachment = targetAttachment,
		beam = beam,
		highlight = highlight,
		billboard = billboard,
		card = card,
		nameLabel = nameLabel,
		distanceLabel = distanceLabel,
		targetPart = targetPart,
	}
end

local function updateTracker()
	if not trackerEnabled then return end

	local entries = getAllPickupEntries()
	refreshMaterialsUI(entries)
	local active = {}

	for _, entry in ipairs(entries) do
		active[entry.model] = true
		local visual = trackerVisuals[entry.model]
		if not visual or not visual.beam or not visual.beam.Parent or visual.targetPart ~= entry.part then
			createTrackerVisual(entry.model, entry.part, entry.name, entry.biome)
			visual = trackerVisuals[entry.model]
		end

		if visual then
			if visual.nameLabel then visual.nameLabel.Text = entry.name .. " (" .. entry.biome .. ")" end
			if visual.distanceLabel then
				visual.distanceLabel.Text = tostring(math.floor(entry.distance + 0.5)) .. " studs"
			end
		end
	end

	local stale = {}
	for model in pairs(trackerVisuals) do
		if not active[model] or not model.Parent then table.insert(stale, model) end
	end
	for _, model in ipairs(stale) do destroyTrackerVisual(model) end

	if #entries == 0 then
		trackerStatus.Text = "No items detected on map."
		return
	end

	trackerStatus.Text = "Tracked materials: " .. tostring(#entries)
		.. "\nNearest: " .. entries[1].name .. " (" .. entries[1].biome .. ")"
		.. " — " .. tostring(math.floor(entries[1].distance + 0.5)) .. " studs"
end

local function startTracker()
	trackerEnabled = true
	trackButton.Text = "TRACK ITEMS: ON"
	trackButton.BackgroundColor3 = Color3.fromRGB(92, 68, 18)
	trackerStatus.Text = "Scanning workspace..."

	if trackerConnection then trackerConnection:Disconnect() end

	local elapsed = 0
	trackerConnection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.35 then
			elapsed = 0
			updateTracker()
		end
	end)
	updateTracker()
end

local function stopTracker()
	trackerEnabled = false
	trackButton.Text = "TRACK ITEMS: OFF"
	trackButton.BackgroundColor3 = Color3.fromRGB(48, 48, 48)

	if trackerConnection then
		trackerConnection:Disconnect()
		trackerConnection = nil
	end

	clearTrackerVisuals()
	refreshMaterialsUI({})
	trackerStatus.Text = "Tracker is off."
end

trackButton.MouseButton1Click:Connect(function()
	if trackerEnabled then stopTracker() else startTracker() end
end)

-- =========================================================
-- DIAGNOSTIC SYSTEM
-- =========================================================

local function clearRows()
	for _, child in ipairs(resultsFrame:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end
end

local function addVisualRow(index, entry)
	local distanceText = entry.distance and string.format("%.1f", entry.distance) or "?"
	local row = Instance.new("TextLabel")
	row.Name = "Result_" .. index
	row.Size = UDim2.new(1, -4, 0, 92)
	row.BackgroundColor3 = Color3.fromRGB(29, 29, 29)
	row.BorderSizePixel = 0
	row.TextColor3 = Color3.fromRGB(225, 225, 225)
	row.TextSize = 11
	row.Font = Enum.Font.Code
	row.TextWrapped = true
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextYAlignment = Enum.TextYAlignment.Top
	row.Text = "[" .. index .. "] [" .. entry.source .. "] " .. entry.name .. " <" .. entry.className .. ">" ..
		"\nDistance: " .. distanceText .. " | Pos: " .. entry.position ..
		"\nParent: " .. entry.parent .. "\nPath: " .. entry.path
	row.Parent = resultsFrame
	uiCorner(row, 5)
end

local function addEntry(instance, source)
	if not instance or not instance.Parent then return end
	local path = instance:GetFullName()
	local uniqueKey = source .. "|" .. path
	if diagnosticSeen[uniqueKey] then return end

	diagnosticSeen[uniqueKey] = true
	local root = trackerRoot()
	local pos = instance:IsA("BasePart") and instance.Position or (instance:IsA("Model") and instance:GetPivot().Position) or Vector3.zero
	local dist = root and (root.Position - pos).Magnitude or nil

	local entry = {
		source = source,
		name = instance.Name,
		className = instance.ClassName,
		distance = dist,
		position = string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z),
		parent = instance.Parent and instance.Parent:GetFullName() or "?",
		path = path
	}

	table.insert(diagnosticEntries, entry)
	addVisualRow(#diagnosticEntries, entry)
end

scanButton.MouseButton1Click:Connect(function()
	diagnosticStatus.Text = "Scanning Workspace..."
	local beforeCount = #diagnosticEntries
	for _, instance in ipairs(Workspace:GetDescendants()) do
		if instance:IsA("ProximityPrompt") then
			addEntry(instance, "SCAN")
		end
	end
	diagnosticStatus.Text = "Scan complete. Added " .. (#diagnosticEntries - beforeCount) .. " entries."
end)

liveButton.MouseButton1Click:Connect(function()
	liveMonitorEnabled = not liveMonitorEnabled
	if liveMonitorEnabled then
		liveButton.Text = "LIVE: ON"
		liveButton.BackgroundColor3 = Color3.fromRGB(42, 78, 48)
		if descendantConnection then descendantConnection:Disconnect() end
		descendantConnection = Workspace.DescendantAdded:Connect(function(instance)
			if not liveMonitorEnabled then return end
			task.delay(0.15, function()
				if not liveMonitorEnabled or not instance or not instance.Parent then return end
				if instance:IsA("ProximityPrompt") then
					addEntry(instance, "LIVE")
					diagnosticStatus.Text = "Captured: " .. instance.Name .. " | Total: " .. #diagnosticEntries
				end
			end)
		end)
		diagnosticStatus.Text = "Live monitor active."
	else
		liveButton.Text = "LIVE: OFF"
		liveButton.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
		if descendantConnection then
			descendantConnection:Disconnect()
			descendantConnection = nil
		end
		diagnosticStatus.Text = "Live monitor stopped."
	end
end)

copyButton.MouseButton1Click:Connect(function()
	if #diagnosticEntries == 0 then
		diagnosticStatus.Text = "Nothing to copy."
		return
	end
	local lines = {"=== Diagnostic Export ==="}
	for i, e in ipairs(diagnosticEntries) do
		table.insert(lines, string.format("[%d] %s <%s> | Pos: %s | Path: %s", i, e.name, e.className, e.position, e.path))
	end
	local exportText = table.concat(lines, "\n")
	if copyToClipboard(exportText) then
		diagnosticStatus.Text = "Copied to clipboard."
	else
		print(exportText)
	end
end)

clearButton.MouseButton1Click:Connect(function()
	diagnosticEntries = {}
	diagnosticSeen = {}
	clearRows()
	diagnosticStatus.Text = "Log cleared."
end)

-- =========================================================
-- INITIALIZATION
-- =========================================================

print("[Sols RNG Scanner] " .. VERSION .. " " .. BUILD .. " Loaded.")

pcall(function()
	StarterGui:SetCore("SendNotification", {
		Title = "Sols Scanner " .. VERSION,
		Text = "Quest Board fixed. Ready to scan.",
		Duration = 4
	})
end)
