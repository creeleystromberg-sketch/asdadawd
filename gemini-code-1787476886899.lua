-- Sol's RNG Master Hub (Safe Mobile Version)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local IsRunning = true
local RenderConn = nil
local CurrentNavThread = nil
local IsNavigating = false
local CurrentWalkSpeed = 16

local ActiveESP = {}
local ActiveTracers = {}
local LogHistory = {}

-- База материалов
local MaterialDatabase = {
    ["flame"]   = {Name = "Eternal Flame", Color = Color3.fromRGB(255, 69, 0), Biome = "Hell"},
    ["star"]    = {Name = "Piece of Star", Color = Color3.fromRGB(255, 215, 0), Biome = "Starfall"},
    ["corrupt"] = {Name = "Curruptaine",   Color = Color3.fromRGB(148, 0, 211), Biome = "Corruption"},
    ["icicle"]  = {Name = "Icicle",        Color = Color3.fromRGB(175, 238, 238), Biome = "Snowy"},
    ["snow"]    = {Name = "Icicle",        Color = Color3.fromRGB(175, 238, 238), Biome = "Snowy"},
    ["rain"]    = {Name = "Rainy Bottle",  Color = Color3.fromRGB(70, 130, 180), Biome = "Rainy"},
    ["wind"]    = {Name = "Wind Essence",  Color = Color3.fromRGB(135, 206, 235), Biome = "Windy"},
    ["hour"]    = {Name = "Hour Glass",    Color = Color3.fromRGB(238, 203, 139), Biome = "Sandstorm"},
    ["sand"]    = {Name = "Hour Glass",    Color = Color3.fromRGB(238, 203, 139), Biome = "Sandstorm"},
    ["feather"] = {Name = "Feather Vial",  Color = Color3.fromRGB(240, 248, 255), Biome = "Heaven"},
    ["null"]    = {Name = "NULL?",         Color = Color3.fromRGB(160, 32, 240), Biome = "Null"},
    ["glitch"]  = {Name = "Glitch Biome",  Color = Color3.fromRGB(0, 255, 128), Biome = "Glitch"}
}

-- Безопасная очистка старых окон
pcall(function()
    if CoreGui:FindFirstChild("SolsMasterHub") then CoreGui.SolsMasterHub:Destroy() end
    if LocalPlayer.PlayerGui:FindFirstChild("SolsMasterHub") then LocalPlayer.PlayerGui.SolsMasterHub:Destroy() end
end)

-- Создание GUI с защитой родителя
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SolsMasterHub"
ScreenGui.ResetOnSpawn = false

local parentSuccess = pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not parentSuccess or not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 260, 0, 340)
Main.Position = UDim2.new(0.02, 0, 0.15, 0)
Main.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
Main.BackgroundTransparency = 0.05
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Color3.fromRGB(45, 52, 68)
MainStroke.Thickness = 1.2

-- Шапка
local Top = Instance.new("Frame")
Top.Size = UDim2.new(1, 0, 0, 30)
Top.BackgroundTransparency = 1
Top.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.Text = "Sol's Master Hub"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Top

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 22, 0, 22)
MinBtn.Position = UDim2.new(1, -50, 0.5, -11)
MinBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
MinBtn.TextSize = 11
MinBtn.Parent = Top
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(1, -26, 0.5, -11)
CloseBtn.BackgroundColor3 = Color3.fromRGB(190, 45, 45)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 11
CloseBtn.Parent = Top
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- Переключатель вкладок
local TabSwitcher = Instance.new("Frame")
TabSwitcher.Size = UDim2.new(1, -16, 0, 26)
TabSwitcher.Position = UDim2.new(0, 8, 0, 32)
TabSwitcher.BackgroundColor3 = Color3.fromRGB(22, 25, 33)
TabSwitcher.BorderSizePixel = 0
TabSwitcher.Parent = Main
Instance.new("UICorner", TabSwitcher).CornerRadius = UDim.new(0, 6)

local TabRadar = Instance.new("TextButton")
TabRadar.Size = UDim2.new(0.5, -2, 1, -4)
TabRadar.Position = UDim2.new(0, 2, 0, 2)
TabRadar.BackgroundColor3 = Color3.fromRGB(45, 110, 225)
TabRadar.Font = Enum.Font.GothamBold
TabRadar.Text = "РАДАР"
TabRadar.TextColor3 = Color3.fromRGB(255, 255, 255)
TabRadar.TextSize = 10
TabRadar.Parent = TabSwitcher
Instance.new("UICorner", TabRadar).CornerRadius = UDim.new(0, 5)

local TabLog = Instance.new("TextButton")
TabLog.Size = UDim2.new(0.5, -2, 1, -4)
TabLog.Position = UDim2.new(0.5, 0, 0, 2)
TabLog.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
TabLog.Font = Enum.Font.GothamBold
TabLog.Text = "ЛОГ / ДАННЫЕ"
TabLog.TextColor3 = Color3.fromRGB(160, 170, 190)
TabLog.TextSize = 10
TabLog.Parent = TabSwitcher
Instance.new("UICorner", TabLog).CornerRadius = UDim.new(0, 5)

-- Контейнер Радара
local RadarContainer = Instance.new("Frame")
RadarContainer.Size = UDim2.new(1, 0, 1, -64)
RadarContainer.Position = UDim2.new(0, 0, 0, 64)
RadarContainer.BackgroundTransparency = 1
RadarContainer.Parent = Main

local SpeedBox = Instance.new("Frame")
SpeedBox.Size = UDim2.new(1, -16, 0, 24)
SpeedBox.Position = UDim2.new(0, 8, 0, 0)
SpeedBox.BackgroundColor3 = Color3.fromRGB(22, 25, 33)
SpeedBox.BorderSizePixel = 0
SpeedBox.Parent = RadarContainer
Instance.new("UICorner", SpeedBox).CornerRadius = UDim.new(0, 6)

local SpeedMinus = Instance.new("TextButton")
SpeedMinus.Size = UDim2.new(0, 26, 1, 0)
SpeedMinus.BackgroundColor3 = Color3.fromRGB(35, 40, 52)
SpeedMinus.Font = Enum.Font.GothamBold
SpeedMinus.Text = "-1"
SpeedMinus.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedMinus.TextSize = 10
SpeedMinus.Parent = SpeedBox
Instance.new("UICorner", SpeedMinus).CornerRadius = UDim.new(0, 6)

local SpeedPlus = Instance.new("TextButton")
SpeedPlus.Size = UDim2.new(0, 26, 1, 0)
SpeedPlus.Position = UDim2.new(1, -26, 0, 0)
SpeedPlus.BackgroundColor3 = Color3.fromRGB(35, 40, 52)
SpeedPlus.Font = Enum.Font.GothamBold
SpeedPlus.Text = "+1"
SpeedPlus.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedPlus.TextSize = 10
SpeedPlus.Parent = SpeedBox
Instance.new("UICorner", SpeedPlus).CornerRadius = UDim.new(0, 6)

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(1, -60, 1, 0)
SpeedLabel.Position = UDim2.new(0, 30, 0, 0)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Font = Enum.Font.GothamBold
SpeedLabel.Text = "Скорость: 16"
SpeedLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
SpeedLabel.TextSize = 10
SpeedLabel.Parent = SpeedBox

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -16, 0, 16)
Status.Position = UDim2.new(0, 8, 0, 26)
Status.BackgroundTransparency = 1
Status.Font = Enum.Font.Gotham
Status.Text = "Поиск материалов..."
Status.TextColor3 = Color3.fromRGB(140, 155, 175)
Status.TextSize = 10
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = RadarContainer

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -16, 0, 185)
Scroll.Position = UDim2.new(0, 8, 0, 44)
Scroll.BackgroundColor3 = Color3.fromRGB(11, 13, 17)
Scroll.BackgroundTransparency = 0.3
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 2
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = RadarContainer

local ScrollLayout = Instance.new("UIListLayout", Scroll)
ScrollLayout.Padding = UDim.new(0, 4)

local RadarControl = Instance.new("Frame")
RadarControl.Size = UDim2.new(1, -16, 0, 28)
RadarControl.Position = UDim2.new(0, 8, 1, -34)
RadarControl.BackgroundTransparency = 1
RadarControl.Parent = RadarContainer

local Refresh = Instance.new("TextButton")
Refresh.Size = UDim2.new(0.6, -2, 1, 0)
Refresh.BackgroundColor3 = Color3.fromRGB(45, 110, 225)
Refresh.Font = Enum.Font.GothamBold
Refresh.Text = "ОБНОВИТЬ"
Refresh.TextColor3 = Color3.fromRGB(255, 255, 255)
Refresh.TextSize = 10
Refresh.Parent = RadarControl
Instance.new("UICorner", Refresh).CornerRadius = UDim.new(0, 6)

local StopBtn = Instance.new("TextButton")
StopBtn.Size = UDim2.new(0.4, -2, 1, 0)
StopBtn.Position = UDim2.new(0.6, 2, 0, 0)
StopBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
StopBtn.Font = Enum.Font.GothamBold
StopBtn.Text = "СТОП"
StopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StopBtn.TextSize = 10
StopBtn.Parent = RadarControl
Instance.new("UICorner", StopBtn).CornerRadius = UDim.new(0, 6)

-- Контейнер Лога
local LogContainer = Instance.new("Frame")
LogContainer.Size = UDim2.new(1, 0, 1, -64)
LogContainer.Position = UDim2.new(0, 0, 0, 64)
LogContainer.BackgroundTransparency = 1
LogContainer.Visible = false
LogContainer.Parent = Main

local LogScroll = Instance.new("ScrollingFrame")
LogScroll.Size = UDim2.new(1, -16, 0, 225)
LogScroll.Position = UDim2.new(0, 8, 0, 0)
LogScroll.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
LogScroll.BorderSizePixel = 0
LogScroll.ScrollBarThickness = 3
LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogScroll.Parent = LogContainer
Instance.new("UICorner", LogScroll).CornerRadius = UDim.new(0, 6)

local LogBox = Instance.new("TextBox")
LogBox.Size = UDim2.new(1, -8, 1, 0)
LogBox.Position = UDim2.new(0, 4, 0, 4)
LogBox.BackgroundTransparency = 1
LogBox.Font = Enum.Font.Code
LogBox.TextColor3 = Color3.fromRGB(180, 225, 255)
LogBox.TextSize = 9
LogBox.TextXAlignment = Enum.TextXAlignment.Left
LogBox.TextYAlignment = Enum.TextYAlignment.Top
LogBox.ClearTextOnFocus = false
LogBox.MultiLine = true
LogBox.TextEditable = false
LogBox.Text = "=== ЖУРНАЛ МАТЕРИАЛОВ ===\n"
LogBox.Parent = LogScroll

local LogControl = Instance.new("Frame")
LogControl.Size = UDim2.new(1, -16, 0, 28)
LogControl.Position = UDim2.new(0, 8, 1, -34)
LogControl.BackgroundTransparency = 1
LogControl.Parent = LogContainer

local ClearLogBtn = Instance.new("TextButton")
ClearLogBtn.Size = UDim2.new(0.35, -2, 1, 0)
ClearLogBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
ClearLogBtn.Font = Enum.Font.GothamBold
ClearLogBtn.Text = "ОЧИСТИТЬ"
ClearLogBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
ClearLogBtn.TextSize = 10
ClearLogBtn.Parent = LogControl
Instance.new("UICorner", ClearLogBtn).CornerRadius = UDim.new(0, 6)

local CopyLogBtn = Instance.new("TextButton")
CopyLogBtn.Size = UDim2.new(0.65, -2, 1, 0)
CopyLogBtn.Position = UDim2.new(0.35, 2, 0, 0)
CopyLogBtn.BackgroundColor3 = Color3.fromRGB(35, 140, 85)
CopyLogBtn.Font = Enum.Font.GothamBold
CopyLogBtn.Text = "СКОПИРОВАТЬ"
CopyLogBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyLogBtn.TextSize = 10
CopyLogBtn.Parent = LogControl
Instance.new("UICorner", CopyLogBtn).CornerRadius = UDim.new(0, 6)

TabRadar.MouseButton1Click:Connect(function()
    TabRadar.BackgroundColor3 = Color3.fromRGB(45, 110, 225)
    TabRadar.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabLog.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
    TabLog.TextColor3 = Color3.fromRGB(160, 170, 190)
    RadarContainer.Visible = true
    LogContainer.Visible = false
end)

TabLog.MouseButton1Click:Connect(function()
    TabLog.BackgroundColor3 = Color3.fromRGB(45, 110, 225)
    TabLog.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabRadar.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
    TabRadar.TextColor3 = Color3.fromRGB(160, 170, 190)
    LogContainer.Visible = true
    RadarContainer.Visible = false
end)

local function WriteLog(text)
    table.insert(LogHistory, text)
    if #LogHistory > 100 then table.remove(LogHistory, 1) end
    LogBox.Text = table.concat(LogHistory, "\n")
    LogScroll.CanvasPosition = Vector3.new(0, 99999, 0)
end

ClearLogBtn.MouseButton1Click:Connect(function()
    LogHistory = {"=== ЛОГ ОЧИЩЕН ==="}
    LogBox.Text = LogHistory[1]
end)

CopyLogBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if setclipboard then
            setclipboard(LogBox.Text)
            CopyLogBtn.Text = "СКОПИРОВАНО!"
            task.wait(1.5)
            CopyLogBtn.Text = "СКОПИРОВАТЬ"
        end
    end)
end)

local function SetSpeed(val)
    CurrentWalkSpeed = math.clamp(val, 16, 120)
    local char = LocalPlayer.Character
    local human = char and char:FindFirstChildWhichIsA("Humanoid")
    if human then human.WalkSpeed = CurrentWalkSpeed end
    SpeedLabel.Text = "Скорость: " .. tostring(CurrentWalkSpeed)
end
SpeedMinus.MouseButton1Click:Connect(function() SetSpeed(CurrentWalkSpeed - 1) end)
SpeedPlus.MouseButton1Click:Connect(function() SetSpeed(CurrentWalkSpeed + 1) end)

local function ClearAll()
    for _, esp in pairs(ActiveESP) do
        pcall(function()
            if esp.Highlight then esp.Highlight:Destroy() end
            if esp.Billboard then esp.Billboard:Destroy() end
        end)
    end
    for _, tr in pairs(ActiveTracers) do
        pcall(function()
            if tr.Beam then tr.Beam:Destroy() end
            if tr.Att0 then tr.Att0:Destroy() end
            if tr.Att1 then tr.Att1:Destroy() end
        end)
    end
    ActiveESP = {}
    ActiveTracers = {}
end

local function StopNavigation()
    IsNavigating = false
    if CurrentNavThread then
        pcall(function() task.cancel(CurrentNavThread) end)
        CurrentNavThread = nil
    end
    local char = LocalPlayer.Character
    local human = char and char:FindFirstChildWhichIsA("Humanoid")
    if human and char:FindFirstChild("HumanoidRootPart") then
        pcall(function() human:MoveTo(char.HumanoidRootPart.Position) end)
    end
end
StopBtn.MouseButton1Click:Connect(StopNavigation)

local function Unload()
    IsRunning = false
    StopNavigation()
    if RenderConn then pcall(function() RenderConn:Disconnect() end) end
    ClearAll()
    pcall(function() ScreenGui:Destroy() end)
end
CloseBtn.MouseButton1Click:Connect(Unload)

local mini = false
MinBtn.MouseButton1Click:Connect(function()
    mini = not mini
    if mini then
        Main.Size = UDim2.new(0, 260, 0, 30)
        TabSwitcher.Visible = false
        RadarContainer.Visible = false
        LogContainer.Visible = false
        MinBtn.Text = "+"
    else
        Main.Size = UDim2.new(0, 260, 0, 340)
        TabSwitcher.Visible = true
        RadarContainer.Visible = TabRadar.TextColor3 == Color3.fromRGB(255, 255, 255)
        LogContainer.Visible = not RadarContainer.Visible
        MinBtn.Text = "—"
    end
end)

local function DrawTracer(part, color)
    pcall(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or not part then return end

        local a0 = Instance.new("Attachment", root)
        local a1 = Instance.new("Attachment", part)

        local beam = Instance.new("Beam")
        beam.Attachment0 = a0
        beam.Attachment1 = a1
        beam.Color = ColorSequence.new(color)
        beam.Width0 = 0.15
        beam.Width1 = 0.15
        beam.FaceCamera = true
        beam.Segments = 6
        beam.Transparency = NumberSequence.new(0.3)
        beam.Parent = Workspace.Terrain

        table.insert(ActiveTracers, {Beam = beam, Att0 = a0, Att1 = a1})
    end)
end

local function DrawESP(part, labelName, color)
    pcall(function()
        local hl = Instance.new("Highlight")
        hl.Adornee = part.Parent:IsA("Model") and part.Parent or part
        hl.FillColor = color
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.35
        hl.Parent = ScreenGui

        local bg = Instance.new("BillboardGui")
        bg.Adornee = part
        bg.Size = UDim2.new(0, 130, 0, 28)
        bg.StudsOffset = Vector3.new(0, 2, 0)
        bg.AlwaysOnTop = true
        bg.Parent = ScreenGui

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextColor3 = color
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.TextSize = 10
        lbl.Text = labelName
        lbl.Parent = bg

        table.insert(ActiveESP, {Highlight = hl, Billboard = bg, Label = lbl, Part = part, Name = labelName})
        DrawTracer(part, color)
    end)
end

local function DeepIdentify(model, prompt)
    local fullText = string.lower(model.Name .. " " .. prompt.ObjectText .. " " .. prompt.ActionText)
    if model.Parent then fullText = fullText .. " " .. string.lower(model.Parent.Name) end

    if fullText:find("potion") or fullText:find("coin") or fullText:find("gold") or fullText:find("bank") or fullText:find("quest") then
        return nil, nil
    end

    for key, data in pairs(MaterialDatabase) do
        if fullText:find(key) then
            return data.Name, data.Color
        end
    end

    for _, ch in pairs(model:GetDescendants()) do
        local chName = string.lower(ch.Name)
        for key, data in pairs(MaterialDatabase) do
            if chName:find(key) then return data.Name, data.Color end
        end

        if ch:IsA("PointLight") or ch:IsA("SurfaceLight") then
            local c = ch.Color
            if c.R > 0.8 and c.G < 0.3 then return "Eternal Flame", Color3.fromRGB(255, 69, 0) end
            if c.R > 0.8 and c.G > 0.7 then return "Piece of Star", Color3.fromRGB(255, 215, 0) end
            if c.R > 0.4 and c.B > 0.6 then return "Curruptaine", Color3.fromRGB(148, 0, 211) end
            if c.B > 0.8 and c.G > 0.6 then return "Wind Essence", Color3.fromRGB(135, 206, 235) end
        end

        if ch:IsA("ParticleEmitter") then
            local pName = string.lower(ch.Name .. " " .. ch.Texture)
            if pName:find("star") then return "Piece of Star", Color3.fromRGB(255, 215, 0) end
            if pName:find("fire") or pName:find("flame") then return "Eternal Flame", Color3.fromRGB(255, 69, 0) end
            if pName:find("void") or pName:find("dark") then return "NULL?", Color3.fromRGB(160, 32, 240) end
        end
    end

    if prompt.ActionText:lower():find("pick up") or prompt.ActionText:lower():find("pickup") then
        return "Неизвестный Ресурс", Color3.fromRGB(255, 215, 0)
    end

    return nil, nil
end

local function HasSolidGround(fromPos, toPos, char)
    local dir = (toPos - fromPos).Unit
    local checkPos = fromPos + (dir * 3.0) + Vector3.new(0, 1.5, 0)

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {char, ScreenGui}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local hit = Workspace:Raycast(checkPos, Vector3.new(0, -22, 0), rayParams)
    return hit ~= nil
end

local function NeedsJump(char, root)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {char}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local lookDir = root.CFrame.LookVector * 2.8
    local lowHit = Workspace:Raycast(root.Position - Vector3.new(0, 0.8, 0), lookDir, rayParams)
    local highHit = Workspace:Raycast(root.Position + Vector3.new(0, 2.2, 0), lookDir, rayParams)

    return lowHit ~= nil and highHit == nil
end

local function SmartNavigate(targetPart, itemName)
    StopNavigation()

    CurrentNavThread = task.spawn(function()
        IsNavigating = true
        local char = LocalPlayer.Character
        local human = char and char:FindFirstChildWhichIsA("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not char or not human or not root or not targetPart then return end

        human.WalkSpeed = CurrentWalkSpeed
        WriteLog(string.format("🚀 [МАРШРУТ] Иду к: %s", itemName))

        local path = PathfindingService:CreatePath({
            AgentRadius = 2.4,
            AgentHeight = 5.0,
            AgentCanJump = true,
            AgentJumpHeight = 14,
            AgentMaxSlope = 60,
            WaypointSpacing = 2.8
        })

        local success = pcall(function()
            path:ComputeAsync(root.Position, targetPart.Position)
        end)

        if not success or path.Status ~= Enum.PathStatus.Success then
            Status.Text = "Прямой путь..."
            pcall(function() human:MoveTo(targetPart.Position) end)
            IsNavigating = false
            return
        end

        local waypoints = path:GetWaypoints()
        for i, waypoint in ipairs(waypoints) do
            if not IsNavigating or not char.Parent or human.Health <= 0 then break end

            local wpPos = waypoint.Position

            if not HasSolidGround(root.Position, wpPos, char) and (wpPos.Y <= root.Position.Y) then
                if (root.Position - wpPos).Magnitude < 11 then
                    human.Jump = true
                else
                    Status.Text = "Обрыв!"
                    break
                end
            end

            if waypoint.Action == Enum.PathWaypointAction.Jump or (wpPos.Y > root.Position.Y + 1.2) then
                human.Jump = true
            end

            pcall(function() human:MoveTo(wpPos) end)

            local reached = false
            local lastPos = root.Position
            local stuckCount = 0

            while not reached and IsNavigating do
                task.wait(0.04)

                if NeedsJump(char, root) then
                    human.Jump = true
                end

                local hDist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(wpPos.X, 0, wpPos.Z)).Magnitude
                if hDist < 3.2 and math.abs(root.Position.Y - wpPos.Y) < 5.5 then
                    reached = true
                    break
                end

                if (root.Position - lastPos).Magnitude < 0.25 then
                    stuckCount = stuckCount + 1
                    if stuckCount > 8 then
                        human.Jump = true
                        pcall(function() human:MoveTo(wpPos + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))) end)
                        stuckCount = 0
                    end
                else
                    stuckCount = 0
                    lastPos = root.Position
                end
            end
        end

        pcall(function() human:MoveTo(root.Position) end)
        IsNavigating = false
        Status.Text = "На месте!"
        WriteLog(string.format("✅ [ПРИБЫЛ] %s", itemName))
    end)
end

RenderConn = RunService.RenderStepped:Connect(function()
    if not IsRunning then return end
    pcall(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        for _, esp in pairs(ActiveESP) do
            if esp.Part and esp.Part.Parent then
                local dist = math.floor((root.Position - esp.Part.Position).Magnitude)
                esp.Label.Text = string.format("%s [%dм]", esp.Name, dist)
            end
        end
    end)
end)

local function Scan()
    if not IsRunning then return end
    ClearAll()
    pcall(function()
        for _, c in pairs(Scroll:GetChildren()) do
            if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
        end
    end)

    local found = {}
    local processed = {}

    pcall(function()
        for _, prompt in pairs(Workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                local model = prompt.Parent
                if model and not model:IsDescendantOf(LocalPlayer.Character) then
                    local gParent = model.Parent and model.Parent.Name or ""
                    if gParent == "Map" or gParent == "SpawnedItems" or gParent == "Workspace" then
                        local targetPart = model:IsA("BasePart") and model or model:FindFirstChildWhichIsA("BasePart")
                        if targetPart and not processed[targetPart] then
                            local name, color = DeepIdentify(model, prompt)
                            if name then
                                processed[targetPart] = true
                                table.insert(found, {Name = name, Color = color, Part = targetPart, Model = model})
                            end
                        end
                    end
                end
            end
        end
    end)

    if not IsNavigating then
        Status.Text = "Материалов: " .. tostring(#found)
    end

    if #found == 0 then
        pcall(function()
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, 0, 0, 40)
            empty.BackgroundTransparency = 1
            empty.Font = Enum.Font.Gotham
            empty.Text = "Материалов нет.\nЖди спавна биома."
            empty.TextColor3 = Color3.fromRGB(110, 120, 140)
            empty.TextSize = 10
            empty.Parent = Scroll
        end)
        return
    end

    for _, item in pairs(found) do
        DrawESP(item.Part, item.Name, item.Color)

        pcall(function()
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 32)
            row.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
            row.BorderSizePixel = 0
            row.Parent = Scroll
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

            local tag = Instance.new("Frame")
            tag.Size = UDim2.new(0, 3, 1, -8)
            tag.Position = UDim2.new(0, 5, 0, 4)
            tag.BackgroundColor3 = item.Color
            tag.BorderSizePixel = 0
            tag.Parent = row

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(0.6, 0, 1, 0)
            nameLbl.Position = UDim2.new(0, 14, 0, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.Text = item.Name
            nameLbl.TextColor3 = Color3.fromRGB(235, 235, 235)
            nameLbl.TextSize = 10
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Parent = row

            local goBtn = Instance.new("TextButton")
            goBtn.Size = UDim2.new(0, 46, 0, 22)
            goBtn.Position = UDim2.new(1, -51, 0.5, -11)
            goBtn.BackgroundColor3 = Color3.fromRGB(40, 145, 80)
            goBtn.Font = Enum.Font.GothamBold
            goBtn.Text = "ИДТИ"
            goBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            goBtn.TextSize = 9
            goBtn.Parent = row
            Instance.new("UICorner", goBtn).CornerRadius = UDim.new(0, 4)

            goBtn.MouseButton1Click:Connect(function()
                Status.Text = "Иду к: " .. item.Name
                SmartNavigate(item.Part, item.Name)
            end)
        end)
    end
end

Refresh.MouseButton1Click:Connect(Scan)

pcall(function()
    Workspace.DescendantAdded:Connect(function(desc)
        if desc:IsA("ProximityPrompt") then
            task.wait(0.1)
            local model = desc.Parent
            if model and not model:IsDescendantOf(LocalPlayer.Character) then
                local name, _ = DeepIdentify(model, desc)
                if name then
                    WriteLog(string.format("✨ [СПАВН] %s", name))
                    if not IsNavigating then Scan() end
                end
            end
        end
    end)
end)

Scan()
task.spawn(function()
    while IsRunning do
        task.wait(5)
        if IsRunning and not IsNavigating then
            Scan()
        end
    end
end)