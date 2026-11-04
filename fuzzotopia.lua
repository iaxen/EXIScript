local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Remove the previous panel when running again.
local existing = playerGui:FindFirstChild("FarmPanel")
if existing then
    existing:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "FarmPanel"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(300, 350)
panel.Position = UDim2.new(0.5, -150, 0.5, -175)
panel.BackgroundColor3 = Color3.fromRGB(27, 29, 38)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, -50, 0, 48)
header.BackgroundTransparency = 1
header.Text = "Fuzzopia • Farm Panel"
header.TextColor3 = Color3.fromRGB(240, 240, 250)
header.Font = Enum.Font.GothamBold
header.TextSize = 16
header.Active = true
header.Parent = panel

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.fromOffset(40, 38)
minimize.Position = UDim2.new(1, -45, 0, 5)
minimize.BackgroundTransparency = 1
minimize.Text = "−"
minimize.TextColor3 = Color3.new(1, 1, 1)
minimize.TextSize = 24
minimize.Parent = panel

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.fromOffset(12, 52)
content.Size = UDim2.new(1, -24, 1, -64)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new()
content.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = content

local states = {}

local function addToggle(label, key)
    states[key] = false

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -6, 0, 42)
    button.BackgroundColor3 = Color3.fromRGB(42, 45, 58)
    button.TextColor3 = Color3.fromRGB(230, 230, 240)
    button.Font = Enum.Font.Gotham
    button.TextSize = 13
    button.Text = label .. "  :  OFF"
    button.Parent = content
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

    button.Activated:Connect(function()
        states[key] = not states[key]
        button.Text = label .. "  :  " .. (states[key] and "ON" or "OFF")
        button.BackgroundColor3 = states[key]
            and Color3.fromRGB(89, 65, 150)
            or Color3.fromRGB(42, 45, 58)

        -- UI state only. Add the corresponding behavior later.
    end)
end

addToggle("Auto Buy Seeds", "buySeeds")
addToggle("Auto Buy Gears", "buyGears")
addToggle("Auto Chop Wood", "chopWood")
addToggle("Auto Harvest", "harvest")
addToggle("Auto Fairy Dust", "fairyDust")

local note = Instance.new("TextLabel")
note.Size = UDim2.new(1, -6, 0, 28)
note.BackgroundTransparency = 1
note.Text = "Interface preview • actions not connected"
note.TextColor3 = Color3.fromRGB(160, 163, 180)
note.Font = Enum.Font.Gotham
note.TextSize = 11
note.Parent = content

local collapsed = false
minimize.Activated:Connect(function()
    collapsed = not collapsed
    content.Visible = not collapsed
    panel.Size = UDim2.fromOffset(300, collapsed and 48 or 350)
    minimize.Text = collapsed and "+" or "−"
end)

-- Drag using the title area with mouse or touch.
local dragInput, dragStart, startPosition

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
        dragStart = input.Position
        startPosition = panel.Position
    end
end)

local moveConnection = UserInputService.InputChanged:Connect(function(input)
    if not dragInput then return end

    local isMouse = dragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement

    if isMouse or input == dragInput then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
        )
    end
end)

local endConnection = UserInputService.InputEnded:Connect(function(input)
    if input == dragInput then
        dragInput = nil
    end
end)

gui.Destroying:Connect(function()
    moveConnection:Disconnect()
    endConnection:Disconnect()
end)