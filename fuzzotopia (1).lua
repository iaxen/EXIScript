-- HARDINERO: calls supplied by the user; server behavior is not verified.
-- Seed calls preserve the supplied ONE-string format. Set true only if
-- RSpy actually shows two arguments: "SeedKeeper", "seedsCorn".
local SEED_TWO_ARGUMENTS = false
local SEED_PREFIX = "seeds" -- Use "seeds#" only if # appears in the actual captured value.
local PURCHASE_DELAY = 1
local CYCLE_DELAY = 10
local BED_DELAY = 0.4
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
local alive=true
local jobs={}
local renderToggle={}
local Remotes=game:GetService("ReplicatedStorage"):WaitForChild("CozyVillageRemotes",10)
assert(Remotes,"CozyVillageRemotes was not found in this experience")
local status=make("TextLabel",{Position=UDim2.new(0,157,1,-27),
    Size=UDim2.new(1,-195,0,22),BackgroundTransparency=1,
    Text="Idle • all automation is OFF",TextColor3=blue,TextSize=11,
    Font=Enum.Font.Gotham,TextTruncate=Enum.TextTruncate.AtEnd,
    TextXAlignment=Enum.TextXAlignment.Left},body)
local function report(message)
    if alive then status.Text=message end
end
local function invoke(name,...)
    local remote=Remotes:FindFirstChild(name)
    assert(remote and remote:IsA("RemoteFunction"),name.." RemoteFunction missing")
    return remote:InvokeServer(...)
end
local function fire(name,...)
    local Event=Remotes:FindFirstChild(name)
    assert(Event and Event:IsA("RemoteEvent"),name.." RemoteEvent missing")
    Event:FireServer(...)
end
local function seedChoice(choice)
    if SEED_TWO_ARGUMENTS then return invoke("NpcChoose","SeedKeeper",choice) end
    return invoke("NpcChoose","SeedKeeper, "..choice)
end
local function enabled(key)
    return alive and states[key]
end
local function stop(key)
    states[key]=false
    if renderToggle[key] then renderToggle[key]() end
    local job=jobs[key]
    jobs[key]=nil
    if job and coroutine.status(job)~="dead" then task.cancel(job) end
end
local function stopAll()
    for _,key in ipairs({"seeds","gears","harvest"}) do stop(key) end
    report("Stopped • requests already sent cannot be undone")
end
local seedIds={"Corn","Starfruit","FrostLily","CloudCotton","AuroraFern",
    "EmberBulb","CandyReed","StardustBerryBush","PearlPod","HoneyBell",
    "Peachtree","Lavender","Beanstalk","Sunbloom","WindbellTree",
    "PuddingGourd","PrismGourd","DreamPlumTree","PhoenixBloom","CometSquash",
    "OpalOrchid","StarlightTree","FuzzberryTree","RainbowFruitTree",
    "MoonMelon","Lotus","AvocadoTree","MoonFlower","StarFruitTree","Watermelon"}
local gearIds={"GrowthTonic","LuckyCharm","RainbowDew"}
local function hasSelection(ids,prefix)
    for _,id in ipairs(ids) do if states[prefix..id] then return true end end
    return false
end
local function runAutomation(key)
    if not states[key] then stop(key) return end
    -- One activity at a time to avoid shop/travel interference.
    for _,other in ipairs({"seeds","gears","harvest"}) do
        if other~=key then stop(other) end
    end
    local ids=key=="seeds" and seedIds or gearIds
    local prefix=key=="seeds" and "seed:" or "gear:"
    if key~="harvest" and not hasSelection(ids,prefix) then
        stop(key) report("Select items in the "..(key=="seeds" and "Seeds" or "Gears").." tab first") return
    end
    jobs[key]=task.defer(function()
        local ok,err=pcall(function()
            if key~="harvest" then
                fire("Travel",key=="seeds" and "Seeds" or "Gear")
                task.wait(1)
            end
            while enabled(key) do
                if key=="harvest" then
                    for row=1,11 do
                        for col=1,10 do
                            if not enabled(key) then return end
                            local bed=("Bed_%d_%d"):format(row,col)
                            fire("FarmTap",bed,nil)
                            report("Harvest tap requested: "..bed)
                            task.wait(BED_DELAY)
                        end
                    end
                else
                    if not hasSelection(ids,prefix) then error("No items selected") end
                    invoke("NpcOpen",key=="seeds" and "SeedKeeper" or "GearKeeper")
                    if not enabled(key) then return end
                    if key=="seeds" then seedChoice("page_special") end
                    for _,id in ipairs(ids) do
                        if not enabled(key) then return end
                        if states[prefix..id] then
                            local result
                            if key=="seeds" then result=seedChoice(SEED_PREFIX..id)
                            else result=invoke("NpcChoose","GearKeeper","stock_"..id) end
                            report("Buy requested: "..id)
                            if result==false then report("Server returned false: "..id) end
                            task.wait(PURCHASE_DELAY)
                        end
                    end
                end
                task.wait(CYCLE_DELAY)
            end
        end)
        if not ok then
            states[key]=false
            if renderToggle[key] then renderToggle[key]() end
            report("Stopped: "..tostring(err))
            warn("HARDINERO: "..tostring(err))
        end
        jobs[key]=nil
    end)
end
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
        renderToggle[key]()
        if key=="seeds" or key=="gears" or key=="harvest" then runAutomation(key) end
    end)
    renderToggle[key]=function()
        track.BackgroundColor3=states[key] and blue or Color3.fromRGB(54,63,78)
        knob.Position=UDim2.fromOffset(states[key] and 25 or 3,3)
    end
end
local function button(p,label,callback)
    local b=make("TextButton",{Size=UDim2.new(1,-8,0,42),Text=label,
        BackgroundColor3=Color3.fromRGB(22,49,82),TextColor3=white,
        Font=Enum.Font.GothamMedium,TextSize=13,BorderSizePixel=0},p)
    corner(b,7)
    b.Activated:Connect(function()
        local ok,err=pcall(callback)
        if not ok then report("Error: "..tostring(err)) end
    end)
end
local farm=page("Main")
textRow(farm,"Select items in Seeds / Gears first. Buying repeats and spends coins until stopped.")
toggle(farm,"Auto Buy Selected Seeds","seeds")
toggle(farm,"Auto Buy Selected Gears","gears")
textRow(farm,"Harvest sends FarmTap to all 110 beds. Ripe-state detection is unavailable; other bed behavior is unverified.")
toggle(farm,"Repeat Harvest Taps (all beds)","harvest")
button(farm,"STOP ALL",stopAll)
textRow(farm,"Chopping and Fairy Dust are unavailable: their action arguments have not been supplied.")
local seedPage=page("Seeds")
textRow(seedPage,"Choose seeds. Exact purchase argument format still needs an in-game check.")
for _,id in ipairs(seedIds) do toggle(seedPage,id,"seed:"..id) end
local gearPage=page("Gears")
textRow(gearPage,"Choose gears to purchase repeatedly.")
for _,id in ipairs(gearIds) do toggle(gearPage,id,"gear:"..id) end
local travelPage=page("Travel")
for _,destination in ipairs({"Seeds","Gear","Forest"}) do
    button(travelPage,"Travel to "..destination,function()
        stopAll()
        fire("Travel",destination)
        report("Travel requested: "..destination)
    end)
end
local settings=page("Settings")
textRow(settings,"Drag header to move; drag bottom-right corner to resize. Closing stops all loops.")
textRow(settings,"One activity runs at a time. Purchase requests: 1 second apart; cycle pause: 10 seconds.")
textRow(settings,"No stock / balance detection. A sent request does not confirm a successful purchase or harvest.")
textRow(settings,"Tree names saved: Tree_Apple, Tree_Blossom, Tree_Pine, Tree_Round. Chop arguments are still missing.")
button(settings,"STOP ALL",stopAll)
local function selectPage(name)
    for key,p in pairs(pages) do p.Visible=key==name end
    for key,b in pairs(tabs) do
        b.BackgroundColor3=key==name and Color3.fromRGB(22,49,82) or Color3.fromRGB(15,19,27)
        b.TextColor3=key==name and blue or white
    end
end
for i,name in ipairs({"Main","Seeds","Gears","Travel","Settings"}) do
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
    alive=false
    stopAll()
    for _,connection in ipairs(connections) do connection:Disconnect() end
end)
selectPage("Main")
