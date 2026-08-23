-- Sol's RNG Material Scanner & Navigator
-- Version: v0.8.1 | Fixed Jump Physics & Strict Biome Mappings

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GUI_NAME = "SolsMaterialScanner"
local VERSION = "v0.8.1"
local BUILD = "BUILD-015"

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
local navigationTargetModel = nil
local navigationTargetName = nil

local startNavigation = nil
local stopNavigation = nil

local KEYWORDS = {
	"bottle", "potion", "flame", "eternal", "corrupt", "corruption",
	"material", "collect", "pickup", "item", "spawn", "biome",
	"token", "star", "rain", "wind", "hell", "heaven", "void",
	"galaxy", "comet", "meteor", "strange", "null"
}

-- =========================================================
-- MATERIAL & BIOME MAPPINGS
-- =========================================================

local MATERIAL_INFO = {
	["Wind Essence"] = "Windy",
	["Icicle"] = "Snowy",
	["Rainy Bottle"] = "Rainy",
	["Hour Glass"] = "Sandstorm",
	["Eternal Flame"] = "Hell",
	["Piece of Star"] = "Starfall",
	["Feather Vial"] = "Heaven",
	["Curruptaine"] = "Corruption",
	["NULL?"] = "Null",
}

local function lowered(value)
	return string.lower(tostring(value or ""))
end

local function getMaterialBiome(rawName)
	if not rawName or rawName == "" then
		return "Unknown", "Material"
	end

	if MATERIAL_INFO[rawName] then
		return MATERIAL_INFO[rawName], rawName
	end

	local low = lowered(rawName)

	if string.find(low, "null", 1, true) or string.find(low, "void", 1, true) then
		return "Null", "NULL?"
	elseif string.find(low, "wind", 1, true) then
		return "Windy", "Wind Essence"
	elseif string.find(low, "rain", 1, true) or string.find(low, "bottle", 1, true) then
		return "Rainy", "Rainy Bottle"
	elseif string.find(low, "sand", 1, true) or string.find(low, "hour", 1, true) then
		return "Sandstorm", "Hour Glass"
	elseif string.find(low, "flame", 1, true) or string.find(low, "hell", 1, true) or string.find(low, "fire", 1, true) or string.find(low, "eternal", 1, true) then
		return "Hell", "Eternal Flame"
	elseif string.find(low, "star", 1, true) then
		return "Starfall", "Piece of Star"
	elseif string.find(low, "feather", 1, true) or string.find(low, "heaven", 1, true) or string.find(low, "vial", 1, true) then
		return "Heaven", "Feather Vial"
	elseif string.find(low, "corrupt", 1, true) then
		return "Corruption", "Curruptaine"
	elseif string.find(low, "icicle", 1, true) or string.find(low, "snow", 1, true) then
		return "Snowy", "Icicle"
	end

	for name, biome in pairs(MATERIAL_INFO) do
		if lowered(name) == low then
			return biome, name
		end
	end

	return "Special / Other", rawName
end

local selectedMaterialModel = nil
local selectedMaterialName = nil
local materialRows = {}

-- =========================================================
-- UI HELPERS
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

pageTitle(materialsPage, "Materials", "Only materials currently detected by the tracker appear here.")

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
emptyMaterials.Text = "No materials detected"
emptyMaterials.TextColor3 = Color3.fromRGB(112, 117, 128)
emptyMaterials.TextSize = 12
emptyMaterials.Font = Enum.Font.Gotham
emptyMaterials.Parent = materialList

pageTitle(trackerPage, "Tracker & AI", "Visual beams and natural pathfinding navigation.")

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
navigationStatus.Text = "AI: idle\nPress GO next to a detected material."
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
		navigationStatus.Text = "AI: not initialized yet."
	end
end)

pageTitle(playerPage, "Player", "Local movement and speed adjustments.")

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
speedHint.Text = "Changes by exactly 1"
speedHint.TextColor3 = Color3.fromRGB(114, 119, 130)
speedHint.TextSize = 10
speedHint.Font = Enum.Font.Gotham
speedHint.TextXAlignment = Enum.TextXAlignment.Left
speedHint.Parent = speedCard

pageTitle(serverPage, "Private Server", "Paste a private server link or a server instance id.")

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
serverStatus.Text = "Waiting for a link."
serverStatus.TextColor3 = Color3.fromRGB(125, 130, 141)
serverStatus.TextSize = 11
serverStatus.Font = Enum.Font.Gotham
serverStatus.TextWrapped = true
serverStatus.TextXAlignment = Enum.TextXAlignment.Left
serverStatus.TextYAlignment = Enum.TextYAlignment.Center
serverStatus.Parent = serverPage

pageTitle(diagnosticPage, "Diagnostic", "Keep the existing scanner available while we build the navigation system.")

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

	local materialEntries = {}
	for _, entry in ipairs(entries or {}) do
		local biome, cleanName = getMaterialBiome(entry.name)
		entry.name = cleanName
		table.insert(materialEntries, { entry = entry, biome = biome })
	end

	emptyMaterials.Visible = #materialEntries == 0

	for index, data in ipairs(materialEntries) do
		local entry = data.entry

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
		details.Text = data.biome .. "  •  " .. tostring(math.floor(entry.distance + 0.5)) .. " studs"
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
			selectedMaterialModel = entry.model
			selectedMaterialName = entry.name
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
-- ITEM DETECTION LOGIC
-- =========================================================

local trackerBlacklistNames = {
	["fishshop"] = true, ["miscs"] = true, ["casecover"] = true,
	["startflip"] = true, ["rig"] = true, ["r6"] = true,
	["bankposition"] = true, ["summereventturrets"] = true,
	["questboard"] = true, ["lime"] = true, ["title"] = true,
	["shop"] = true, ["inter"] = true, ["portal"] = true,
	["liquid"] = true, ["bottomjoint"] = true,
}

local function trackerRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function containsExcludedText(value)
	local text = lowered(value)
	return string.find(text, "clover", 1, true) ~= nil
		or string.find(text, "four leaf", 1, true) ~= nil
		or string.find(text, "four-leaf", 1, true) ~= nil
		or string.find(text, "luck buff", 1, true) ~= nil
end

local function modelContainsExcludedText(model)
	if not model then return true end
	if containsExcludedText(model.Name) then return true end

	for _, descendant in ipairs(model:GetDescendants()) do
		if containsExcludedText(descendant.Name) then return true end
		if descendant:IsA("ProximityPrompt") then
			if containsExcludedText(descendant.ActionText) or containsExcludedText(descendant.ObjectText) then
				return true
			end
		end
	end
	return false
end

local function findPickupModelFromPrompt(prompt)
	if not prompt or not prompt.Parent then return nil end

	local current = prompt.Parent
	local map = Workspace:FindFirstChild("Map")

	while current and current ~= Workspace do
		if current:IsA("Model") then
			if map and current.Parent == map then return current end
			if current.Parent and lowered(current.Parent.Name) == "spawneditems" then return current end
		end
		current = current.Parent
	end
	return nil
end

local function promptLooksLikePickup(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
		return false
	end

	local action = lowered(prompt.ActionText)
	local objectText = lowered(prompt.ObjectText)

	if containsExcludedText(action) or containsExcludedText(objectText) then
		return false
	end

	if action == "pick up" or action == "pickup" or action == "collect" or action == "take" then
		return true
	end

	local parent = prompt.Parent
	local gp = parent and parent.Parent and lowered(parent.Parent.Name) or ""

	if trackerBlacklistNames[gp] then return false end
	if gp == "map" or gp == "spawneditems" then return true end

	return findPickupModelFromPrompt(prompt) ~= nil
end

local function targetPartForModel(model, prompt)
	if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
		return prompt.Parent
	end

	local bottle = model:FindFirstChild("Bottle", true)
	if bottle and bottle:IsA("BasePart") then return bottle end

	local windB = model:FindFirstChild("windb", true)
	if windB and windB:IsA("BasePart") then return windB end

	local windC = model:FindFirstChild("windc", true)
	if windC and windC:IsA("BasePart") then return windC end

	local hitox = model:FindFirstChild("Hitox", true)
	if hitox and hitox:IsA("BasePart") then return hitox end

	local nullPart = model:FindFirstChild("Null", true) or model:FindFirstChild("NULL", true) or model:FindFirstChild("NULL?", true)
	if nullPart and nullPart:IsA("BasePart") then return nullPart end

	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function detectedItemName(model, prompt)
	local objectText = prompt and tostring(prompt.ObjectText or "") or ""
	local actionText = prompt and tostring(prompt.ActionText or "") or ""

	if objectText ~= "" and lowered(objectText) ~= "item" and lowered(objectText) ~= "object" and not containsExcludedText(objectText) then
		local _, standardName = getMaterialBiome(objectText)
		return standardName
	end

	local modelName = model and model.Name or ""
	local lowerModelName = lowered(modelName)
	if modelName ~= "" and lowerModelName ~= "model" and lowerModelName ~= "spawneditems" and lowerModelName ~= "workspace" and not containsExcludedText(modelName) then
		local biome, standardName = getMaterialBiome(modelName)
		if biome ~= "Special / Other" then return standardName end
	end

	if actionText ~= "" and lowered(actionText) ~= "pick up" and lowered(actionText) ~= "pickup" and lowered(actionText) ~= "interact" and not containsExcludedText(actionText) then
		local _, standardName = getMaterialBiome(actionText)
		return standardName
	end

	if model:FindFirstChild("Null", true) or model:FindFirstChild("NULL", true) or model:FindFirstChild("null", true)
		or model:FindFirstChild("NULL?", true) or model:FindFirstChild("Null?", true) then
		return "NULL?"
	end

	if model:FindFirstChild("windb", true) or model:FindFirstChild("windc", true) then
		return "Wind Essence"
	end

	if model:FindFirstChild("Bottle", true) then
		return "Rainy Bottle"
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local n = tostring(descendant.Name)
			local ln = lowered(n)
			if n ~= "" and ln ~= "meshpart" and ln ~= "part" and ln ~= "hitox" and not containsExcludedText(n) then
				local biome, standardName = getMaterialBiome(n)
				if biome ~= "Special / Other" then return standardName end
				return n
			end
		end
	end

	return "Material"
end

local function getAllPickupEntries()
	local root = trackerRoot()
	local entries = {}
	local seen = {}

	if not root then return entries end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and promptLooksLikePickup(descendant) then
			local model = findPickupModelFromPrompt(descendant)
			if model and not seen[model] and not modelContainsExcludedText(model) then
				local part = targetPartForModel(model, descendant)
				if part then
					seen[model] = true
					table.insert(entries, {
						model = model,
						prompt = descendant,
						part = part,
						name = detectedItemName(model, descendant),
						distance = (root.Position - part.Position).Magnitude,
					})
				end
			end
		end
	end

	table.sort(entries, function(a, b) return a.distance < b.distance end)
	return entries
end

-- =========================================================
-- CLEAN NAVIGATION & GROUNDED JUMP LOGIC
-- =========================================================

local NAV_MAX_REPATHS = 8
local NAV_WAYPOINT_TIMEOUT = 3.5
local NAV_STUCK_TIME = 1.0
local NAV_REACH_DISTANCE = 3.8
local JUMP_COOLDOWN = 0.8
local lastJumpTime = 0

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

-- Only jumps if on the ground and cooldown has elapsed
local function tryGroundedJump(humanoid)
	if not humanoid or humanoid.Health <= 0 then return end
	local now = os.clock()
	if now - lastJumpTime < JUMP_COOLDOWN then return end
	if humanoid.FloorMaterial == Enum.Material.Air then return end

	lastJumpTime = now
	humanoid.Jump = true
end

-- Raycast in front to detect obstacles without mid-air floating
local function isObstacleAhead(root, targetPosition, character)
	local origin = root.Position - Vector3.new(0, 1.2, 0)
	local direction = (Vector3.new(targetPosition.X, origin.Y, targetPosition.Z) - origin).Unit * 2.8

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local result = Workspace:Raycast(origin, direction, params)
	return result ~= nil
end

local function safeGroundAt(position, character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = character and { character } or {}
	params.IgnoreWater = false

	local origin = position + Vector3.new(0, 5, 0)
	local direction = Vector3.new(0, -25, 0)

	return Workspace:Raycast(origin, direction, params) ~= nil
end

local function tryFirePrompt(prompt)
	if not prompt or not prompt.Parent or not prompt.Enabled then
		return false, "Pickup prompt disappeared."
	end

	if type(fireproximityprompt) == "function" then
		local ok, err = pcall(function()
			fireproximityprompt(prompt, 0)
		end)
		return ok, ok and nil or tostring(err)
	end

	return false, "Executor missing fireproximityprompt; press E."
end

local function waitForWaypoint(token, humanoid, root, destination, isJump)
	local started = os.clock()
	local lastMovementTime = os.clock()
	local lastPosition = root.Position

	while os.clock() - started < NAV_WAYPOINT_TIMEOUT do
		if token ~= navigationToken or not navigationRunning then
			return false, "cancelled"
		end

		if not humanoid.Parent or humanoid.Health <= 0 or not root.Parent then
			return false, "character unavailable"
		end

		local currentPos = root.Position
		local distance = (currentPos - destination).Magnitude
		local deltaY = destination.Y - currentPos.Y

		if isJump or deltaY > 1.4 or isObstacleAhead(root, destination, player.Character) then
			tryGroundedJump(humanoid)
		end

		if distance <= NAV_REACH_DISTANCE then
			return true
		end

		local moved = (currentPos - lastPosition).Magnitude
		if moved >= 0.7 then
			lastPosition = currentPos
			lastMovementTime = os.clock()
		elseif os.clock() - lastMovementTime >= NAV_STUCK_TIME then
			tryGroundedJump(humanoid)
			lastMovementTime = os.clock()
		end

		task.wait(0.06)
	end

	return false, "waypoint timeout"
end

local function directApproachSmart(token, entry, humanoid, root)
	if not entry.part or not entry.part.Parent then return false, "Target gone." end

	local started = os.clock()
	while os.clock() - started < 10 do
		if token ~= navigationToken or not navigationRunning then return false, "cancelled" end
		if not humanoid.Parent or humanoid.Health <= 0 or not root.Parent then return false, "dead" end

		local targetPos = entry.part.Position
		local dist = (root.Position - targetPos).Magnitude

		if dist <= math.max(4.5, (entry.prompt and entry.prompt.MaxActivationDistance or 8) - 1) then
			return true, "Reached target"
		end

		humanoid:MoveTo(targetPos)

		if (targetPos.Y - root.Position.Y) > 1.4 or isObstacleAhead(root, targetPos, player.Character) then
			tryGroundedJump(humanoid)
		end

		task.wait(0.08)
	end

	return false, "Direct walk timed out."
end

local function followComputedPath(token, entry, humanoid, root)
	if not entry.part or not entry.part.Parent then
		return false, "Target disappeared."
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2.0,
		AgentHeight = 5.0,
		AgentCanJump = true,
		AgentCanClimb = true,
		AgentJumpHeight = 7.0,
		AgentMaxSlope = 50.0,
		WaypointSpacing = 3.5,
	})

	local ok, computeError = pcall(function()
		path:ComputeAsync(root.Position, entry.part.Position)
	end)

	if not ok or path.Status ~= Enum.PathStatus.Success then
		return directApproachSmart(token, entry, humanoid, root)
	end

	local waypoints = path:GetWaypoints()
	if #waypoints < 2 then
		return directApproachSmart(token, entry, humanoid, root)
	end

	for index = 2, #waypoints do
		if token ~= navigationToken or not navigationRunning then
			return false, "cancelled"
		end

		if not entry.model or not entry.model.Parent or not entry.part or not entry.part.Parent then
			return false, "Target disappeared."
		end

		local waypoint = waypoints[index]
		local isJumpAction = (waypoint.Action == Enum.PathWaypointAction.Jump)

		if not isJumpAction and not safeGroundAt(waypoint.Position, player.Character) then
			return false, "Recalculating over void"
		end

		local currentDistance = (root.Position - entry.part.Position).Magnitude
		if currentDistance <= math.max(4.5, (entry.prompt and entry.prompt.MaxActivationDistance or 8) - 1.0) then
			return true, "Reached pickup range."
		end

		setNavigationStatus(
			"AI: walking to " .. entry.name,
			"Waypoint " .. tostring(index - 1) .. "/" .. tostring(#waypoints - 1),
			tostring(math.floor(currentDistance + 0.5)) .. " studs remaining"
		)

		humanoid:MoveTo(waypoint.Position)

		local reached, why = waitForWaypoint(
			token,
			humanoid,
			root,
			waypoint.Position,
			isJumpAction
		)

		if not reached then
			return false, why
		end
	end

	return true, "Path completed."
end

stopNavigation = function(reason)
	navigationToken += 1
	navigationRunning = false
	navigationTargetModel = nil
	navigationTargetName = nil

	local _, humanoid, root = navigationCharacter()
	if humanoid and root then
		humanoid:MoveTo(root.Position)
	end

	setNavigationStatus("AI: idle", reason or "Navigation stopped.")
end

startNavigation = function(entry)
	if not entry or not entry.model or not entry.model.Parent or not entry.part or not entry.part.Parent then
		setNavigationStatus("AI: error", "Selected material no longer exists.")
		return
	end

	navigationToken += 1
	local token = navigationToken

	navigationRunning = true
	navigationTargetModel = entry.model
	navigationTargetName = entry.name

	setNavigationStatus("AI: route initiated", entry.name, tostring(math.floor(entry.distance + 0.5)) .. " studs away")

	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Navigation AI",
			Text = "Navigating to " .. entry.name,
			Duration = 3
		})
	end)

	task.spawn(function()
		for attempt = 1, NAV_MAX_REPATHS do
			if token ~= navigationToken or not navigationRunning then return end

			if not entry.model.Parent or not entry.part.Parent then
				stopNavigation("Material was collected or disappeared.")
				return
			end

			local _, humanoid, root = navigationCharacter()
			if not humanoid or not root then
				stopNavigation("Character is unavailable.")
				return
			end

			local targetDistance = (root.Position - entry.part.Position).Magnitude
			local activationDistance = entry.prompt and math.max(4.5, entry.prompt.MaxActivationDistance) or 8

			if targetDistance <= activationDistance then
				setNavigationStatus("AI: arrived at " .. entry.name, "Collecting material...")
				local fired, fireError = tryFirePrompt(entry.prompt)

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
					setNavigationStatus("AI: arrived", fireError or "Press E to collect.")
					return
				end
			end

			setNavigationStatus("AI: pathfinding", entry.name, "Attempt " .. tostring(attempt) .. "/" .. tostring(NAV_MAX_REPATHS))

			local reached, reason = followComputedPath(token, entry, humanoid, root)

			if token ~= navigationToken or not navigationRunning then return end

			if reached then
				task.wait(0.1)
			else
				setNavigationStatus("AI: recalculating", reason or "Path rerouted.", "Attempt " .. tostring(attempt) .. "/" .. tostring(NAV_MAX_REPATHS))
				task.wait(0.2)
			end
		end

		if token == navigationToken and navigationRunning then
			navigationRunning = false
			setNavigationStatus("AI: stopped", "Could not safely reach target.")
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

local function createTrackerVisual(model, targetPart)
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
	beam.Width0 = 1.15
	beam.Width1 = 0.78
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Brightness = 3
	beam.Segments = 24
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(225, 230, 238)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 198, 210))
	})
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.1, 0.02),
		NumberSequenceKeypoint.new(0.9, 0.02),
		NumberSequenceKeypoint.new(1, 0.15)
	})
	beam.Parent = root

	local highlight = Instance.new("Highlight")
	highlight.Name = "SolsTrackerHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(235, 238, 244)
	highlight.FillTransparency = 0.9
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0.18
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
	nameLabel.TextStrokeTransparency = 1
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextWrapped = true
	nameLabel.Parent = card

	local distanceLabel = Instance.new("TextLabel")
	distanceLabel.Name = "DistanceLabel"
	distanceLabel.Size = UDim2.new(1, -14, 0, 16)
	distanceLabel.Position = UDim2.fromOffset(7, 28)
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.TextColor3 = Color3.fromRGB(166, 172, 184)
	distanceLabel.TextStrokeTransparency = 1
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
			createTrackerVisual(entry.model, entry.part)
			visual = trackerVisuals[entry.model]
		end

		if visual then
			if visual.nameLabel then visual.nameLabel.Text = entry.name end
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
		trackerStatus.Text = "No pickup prompts found. Waiting for materials..."
		return
	end

	trackerStatus.Text = "Tracked materials: " .. tostring(#entries)
		.. "\nNearest: " .. entries[1].name
		.. " — " .. tostring(math.floor(entries[1].distance + 0.5)) .. " studs"
end

local function startTracker()
	trackerEnabled = true
	trackButton.Text = "TRACK ITEMS: ON"
	trackButton.BackgroundColor3 = Color3.fromRGB(92, 68, 18)
	trackerStatus.Text = "Scanning pickup prompts..."

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

local function containsKeyword(text)
	local low = string.lower(text)
	for _, keyword in ipairs(KEYWORDS) do
		if string.find(low, keyword, 1, true) then return true end
	end
	return false
end

local function getCharacterRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getObjectPosition(instance)
	if instance:IsA("BasePart") then return instance.Position end
	if instance:IsA("Model") then
		local ok, pivot = pcall(function() return instance:GetPivot() end)
		if ok then return pivot.Position end
	end
	local parent = instance.Parent
	if parent then
		if parent:IsA("BasePart") then return parent.Position end
		if parent:IsA("Model") then
			local ok, pivot = pcall(function() return parent:GetPivot() end)
			if ok then return pivot.Position end
		end
	end
	return nil
end

local function getDistance(instance)
	local root = getCharacterRoot()
	local position = getObjectPosition(instance)
	if not root or not position then return nil end
	return (root.Position - position).Magnitude
end

local function getPositionText(instance)
	local position = getObjectPosition(instance)
	if not position then return "?" end
	return string.format("%.1f, %.1f, %.1f", position.X, position.Y, position.Z)
end

local function getPath(instance)
	local parts = {}
	local current = instance
	while current and current ~= game do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return table.concat(parts, ".")
end

local function isInteresting(instance)
	if instance:IsA("ProximityPrompt") then return true, "ProximityPrompt" end
	if instance:IsA("ClickDetector") then return true, "ClickDetector" end
	if instance:IsA("TouchTransmitter") then return true, "TouchTransmitter" end
	if (instance:IsA("Model") or instance:IsA("BasePart") or instance:IsA("Tool") or instance:IsA("Folder")) and containsKeyword(instance.Name) then
		return true, "Name keyword"
	end
	return false, nil
end

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
		"\nReason: " .. entry.reason .. " | Distance: " .. distanceText .. " | Pos: " .. entry.position ..
		"\nParent: " .. entry.parent .. "\nPath: " .. entry.path
	row.Parent = resultsFrame
	uiCorner(row, 5)
end

local function addEntry(instance, reason, source)
	if not instance or not instance.Parent then return end
	local path = getPath(instance)
	local uniqueKey = source .. "|" .. path
	if diagnosticSeen[uniqueKey] then return end

	diagnosticSeen[uniqueKey] = true
	local parentName = instance.Parent and instance.Parent:GetFullName() or "?"
	local entry = {
		source = source,
		name = instance.Name,
		className = instance.ClassName,
		reason = reason,
		distance = getDistance(instance),
		position = getPositionText(instance),
		parent = parentName,
		path = path
	}

	table.insert(diagnosticEntries, entry)
	addVisualRow(#diagnosticEntries, entry)
end

local function buildExportText()
	local lines = {
		"=== Sol's RNG Diagnostic Export ===",
		"Entries: " .. tostring(#diagnosticEntries),
		""
	}
	for index, entry in ipairs(diagnosticEntries) do
		local distanceText = entry.distance and string.format("%.1f", entry.distance) or "?"
		table.insert(lines, string.format(
			"[%d]\nSource: %s\nName: %s\nClass: %s\nReason: %s\nDistance: %s\nPosition: %s\nParent: %s\nPath: %s\n",
			index, entry.source, entry.name, entry.className, entry.reason, distanceText, entry.position, entry.parent, entry.path
		))
	end
	return table.concat(lines, "\n")
end

scanButton.MouseButton1Click:Connect(function()
	diagnosticStatus.Text = "Scanning Workspace..."
	local beforeCount = #diagnosticEntries
	for _, instance in ipairs(Workspace:GetDescendants()) do
		local interesting, reason = isInteresting(instance)
		if interesting then addEntry(instance, reason, "SCAN") end
	end
	diagnosticStatus.Text = "Manual scan complete. Added " .. (#diagnosticEntries - beforeCount) .. " | Total: " .. #diagnosticEntries
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
				local interesting, reason = isInteresting(instance)
				if interesting then
					addEntry(instance, reason, "LIVE")
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
	local exportText = buildExportText()
	if #diagnosticEntries == 0 then
		diagnosticStatus.Text = "Nothing to copy yet."
		return
	end
	if copyToClipboard(exportText) then
		diagnosticStatus.Text = "Copied " .. #diagnosticEntries .. " entries to clipboard."
	else
		diagnosticStatus.Text = "Clipboard failed. Check console."
		print(exportText)
	end
end)

clearButton.MouseButton1Click:Connect(function()
	diagnosticEntries = {}
	diagnosticSeen = {}
	clearRows()
	diagnosticStatus.Text = "Diagnostic log cleared."
end)

-- =========================================================
-- INITIALIZATION
-- =========================================================

print("[Sols RNG Scanner] " .. VERSION .. " " .. BUILD .. " Loaded.")

pcall(function()
	StarterGui:SetCore("SendNotification", {
		Title = "Sols Scanner " .. VERSION,
		Text = "Navigation & Item names ready.",
		Duration = 4
	})
end)
