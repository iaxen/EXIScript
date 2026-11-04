-- Fuzzopia interface only. No game actions or remote calls.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local parent = player:WaitForChild("PlayerGui")
local old = parent:FindFirstChild("FarmPanel")
if old then old:Destroy() end
local blue = Color3.fromRGB(35, 135, 255)
local white = Color3.fromRGB(232, 238, 248)
local function make(class, props, parentObject)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parentObject
    return obj
end
local function corner(obj, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, obj)
end
local gui = make("ScreenGui", {Name="FarmPanel", ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, parent)
local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(800,600)
local width = math.min(720, viewport.X - 24)
local height = math.min(440, viewport.Y - 24)
local panel = make("Frame", {Size=UDim2.fromOffset(width,height),
    Position=UDim2.fromOffset((viewport.X-width)/2,(viewport.Y-height)/2),
    BackgroundColor3=Color3.fromRGB(11,14,20), BorderSizePixel=0,
    ClipsDescendants=true}, gui)
corner(panel,10)
make("UIStroke", {Color=blue,Thickness=2}, panel)
local header = make("Frame", {Size=UDim2.new(1,0,0,52),
    BackgroundColor3=Color3.fromRGB(17,22,31),BorderSizePixel=0,Active=true}, panel)
local title = make("TextLabel", {Position=UDim2.fromOffset(18,0),
    Size=UDim2.new(1,-120,1,0),BackgroundTransparency=1,
    Text="HARDINERO  /  Fuzzopia",TextColor3=white,Font=Enum.Font.GothamBold,
    TextSize=17,TextXAlignment=Enum.TextXAlignment.Left}, header)
local function headerButton(text,x)
    local b=make("TextButton", {Size=UDim2.fromOffset(34,30),
        Position=UDim2.new(1,x,0,11),BackgroundColor3=Color3.fromRGB(28,35,47),
        Text=text,TextColor3=white,TextSize=20,Font=Enum.Font.Gotham},header)
    corner(b,6)
    return b
end
local mini=headerButton("−",-82)
local close=headerButton("×",-42)
local body=make("Frame", {Position=UDim2.fromOffset(0,52),
    Size=UDim2.new(1,0,1,-52),BackgroundTransparency=1},panel)
local sidebar=make("Frame", {Size=UDim2.new(0,145,1,0),
    BackgroundColor3=Color3.fromRGB(15,19,27),BorderSizePixel=0},body)
local content=make("Frame", {Position=UDim2.fromOffset(157,12),
    Size=UDim2.new(1,-173,1,-40),BackgroundTransparency=1},body)
local pages={}
local tabs={}
local states={}
local function page(name)
    local p=make("ScrollingFrame", {Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,
        ScrollBarImageColor3=blue,CanvasSize=UDim2.new(),
        AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false},content)
    make("UIListLayout", {Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder},p)
    pages[name]=p
    return p
end
local function textRow(p,text)
    return make("TextLabel", {Size=UDim2.new(1,-8,0,40),BackgroundTransparency=1,
        Text=text,TextWrapped=true,TextColor3=Color3.fromRGB(145,160,181),
        Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left},p)
end
local function toggle(p,label,key)
    states[key]=false
    local row=make("TextButton", {Size=UDim2.new(1,-8,0,47),Text="",
        BackgroundColor3=Color3.fromRGB(24,29,39),BorderSizePixel=0},p)
    corner(row,7)
    make("UIStroke", {Color=Color3.fromRGB(43,53,69),Thickness=1},row)
    make("TextLabel", {Position=UDim2.fromOffset(13,0),Size=UDim2.new(1,-91,1,0),
        BackgroundTransparency=1,Text=label,TextColor3=white,Font=Enum.Font.GothamMedium,
        TextSize=13,TextXAlignment=Enum.TextXAlignment.Left},row)
    local track=make("Frame", {Position=UDim2.new(1,-58,0.5,-11),
        Size=UDim2.fromOffset(44,22),BackgroundColor3=Color3.fromRGB(54,63,78),BorderSizePixel=0},row)
    corner(track,20)
    local knob=make("Frame", {Position=UDim2.fromOffset(3,3),Size=UDim2.fromOffset(16,16),
        BackgroundColor3=white,BorderSizePixel=0},track)
    corner(knob,20)
    row.Activated:Connect(function()
        states[key]=not states[key]
        track.BackgroundColor3=states[key] and blue or Color3.fromRGB(54,63,78)
        knob.Position=UDim2.fromOffset(states[key] and 25 or 3,3)
        -- Connect authorized game behavior here later.
    end)
end
local farm=page("Main")
textRow(farm,"FARM CONTROLS  •  UI preview")
toggle(farm,"Auto Buy Seeds","seeds")
toggle(farm,"Auto Buy Gears","gears")
toggle(farm,"Auto Chop Wood","wood")
toggle(farm,"Auto Harvest","harvest")
toggle(farm,"Auto Fairy Dust","dust")
local trees=page("Trees")
textRow(trees,"TREE FILTERS  •  Select tree types")
for _,name in ipairs({"Tree_Apple","Tree_Blossom","Tree_Pine","Tree_Round"}) do
    toggle(trees,name,name)
end
local settings=page("Settings")
textRow(settings,"Drag the header to move. Drag the bottom-right corner to resize.")
textRow(settings,"Controls store UI state only. Automation is not connected.")
local function selectPage(name)
    for key,p in pairs(pages) do p.Visible=key==name end
    for key,b in pairs(tabs) do
        b.BackgroundColor3=key==name and Color3.fromRGB(22,49,82) or Color3.fromRGB(15,19,27)
        b.TextColor3=key==name and blue or white
    end
end
for i,name in ipairs({"Main","Trees","Settings"}) do
    local b=make("TextButton", {Position=UDim2.fromOffset(8,10+(i-1)*42),
        Size=UDim2.new(1,-16,0,36),Text="   "..name,TextXAlignment=Enum.TextXAlignment.Left,
        TextColor3=white,Font=Enum.Font.GothamMedium,TextSize=13,BorderSizePixel=0},sidebar)
    corner(b,6)
    tabs[name]=b
    b.Activated:Connect(function() selectPage(name) end)
end
make("TextLabel", {Position=UDim2.new(0,10,1,-42),Size=UDim2.new(1,-20,0,32),
    BackgroundTransparency=1,Text=player.DisplayName,TextTruncate=Enum.TextTruncate.AtEnd,
    TextColor3=Color3.fromRGB(140,157,180),Font=Enum.Font.Gotham,TextSize=12},sidebar)
local grip=make("TextButton", {AnchorPoint=Vector2.new(1,1),Position=UDim2.fromScale(1,1),
    Size=UDim2.fromOffset(30,28),BackgroundTransparency=1,Text="◢",TextColor3=blue,
    TextSize=22,Active=true},panel)
local collapsed=false
local expanded=panel.Size
mini.Activated:Connect(function()
    collapsed=not collapsed
    if collapsed then expanded=panel.Size end
    body.Visible=not collapsed
    grip.Visible=not collapsed
    panel.Size=collapsed and UDim2.new(expanded.X.Scale,expanded.X.Offset,0,52) or expanded
    mini.Text=collapsed and "+" or "−"
end)
local operation,activeInput,startPoint,startPos,startSize
local connections={}
local function begin(input,mode)
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
    operation=mode
    activeInput=input
    startPoint=input.Position
    startPos=panel.Position
    startSize=panel.AbsoluteSize
end
header.InputBegan:Connect(function(input) begin(input,"drag") end)
grip.InputBegan:Connect(function(input) begin(input,"resize") end)
connections[1]=UIS.InputChanged:Connect(function(input)
    if not operation then return end
    local mouse=activeInput.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement
    if not mouse and input~=activeInput then return end
    local delta=input.Position-startPoint
    local cam=workspace.CurrentCamera
    local view=cam and cam.ViewportSize or viewport
    if operation=="drag" then
        panel.Position=UDim2.fromOffset(
            math.clamp(startPos.X.Offset+delta.X,0,math.max(0,view.X-panel.AbsoluteSize.X)),
            math.clamp(startPos.Y.Offset+delta.Y,0,math.max(0,view.Y-panel.AbsoluteSize.Y)))
    else
        local maxW=math.max(1,view.X-panel.AbsolutePosition.X-8)
        local maxH=math.max(1,view.Y-panel.AbsolutePosition.Y-8)
        panel.Size=UDim2.fromOffset(math.clamp(startSize.X+delta.X,math.min(380,maxW),maxW),
            math.clamp(startSize.Y+delta.Y,math.min(260,maxH),maxH))
    end
end)
connections[2]=UIS.InputEnded:Connect(function(input)
    if input==activeInput then operation=nil activeInput=nil end
end)
close.Activated:Connect(function() gui:Destroy() end)
gui.Destroying:Connect(function()
    for _,connection in ipairs(connections) do connection:Disconnect() end
end)
selectPage("Main")
