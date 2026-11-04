-- HARDINERO: calls supplied by the user; server behavior is not verified.
-- Seed arguments default to two values, inferred from the gear capture.
-- Confirm the exact seed argument list in RSpy if seed buying still fails.
local SEED_TWO_ARGUMENTS = true
local SEED_PREFIX = "seeds" -- Use "seeds#" only if # appears in the actual captured value.
local PURCHASE_DELAY = 0.25
local PURCHASE_COUNT = 10
local SHOP_TRAVEL_WAIT = 2
local CYCLE_DELAY = 10
local BED_DELAY = 0.1 -- Seconds; adjustable live from the Main tab.
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
local screen=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1},gui)
local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(800,600)
local width = math.min(520, viewport.X - 24)
local height = math.min(330, viewport.Y - 24)
local panel = make("Frame", {Size=UDim2.fromOffset(width,height),
    Position=UDim2.fromOffset((viewport.X-width)/2,(viewport.Y-height)/2),
    BackgroundColor3=Color3.fromRGB(11,14,20), BorderSizePixel=0,
    ClipsDescendants=true}, screen)
corner(panel,10)
make("UIStroke", {Color=blue,Thickness=2}, panel)
local header = make("Frame", {Size=UDim2.new(1,0,0,52),
    BackgroundColor3=Color3.fromRGB(17,22,31),BorderSizePixel=0,Active=true}, panel)
local title = make("TextLabel", {Position=UDim2.fromOffset(18,0),
    Size=UDim2.new(1,-120,1,0),BackgroundTransparency=1,
    Text="HARDINERO  /  Fuzzopia",TextColor3=white,Font=Enum.Font.GothamBold,
    TextSize=14,TextXAlignment=Enum.TextXAlignment.Left}, header)
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
local sidebar=make("ScrollingFrame", {Size=UDim2.new(0,100,1,0),
    CanvasSize=UDim2.fromOffset(0,375),ScrollBarThickness=2,
    BackgroundColor3=Color3.fromRGB(15,19,27),BorderSizePixel=0},body)
local content=make("Frame", {Position=UDim2.fromOffset(110,12),
    Size=UDim2.new(1,-122,1,-40),BackgroundTransparency=1},body)
local pages={}
local tabs={}
local states={}
local alive=true
local jobs={}
local renderToggle={}
local Remotes=game:GetService("ReplicatedStorage"):WaitForChild("CozyVillageRemotes",10)
assert(Remotes,"CozyVillageRemotes was not found in this experience")
local status=make("TextLabel",{Position=UDim2.new(0,110,1,-27),
    Size=UDim2.new(1,-148,0,22),BackgroundTransparency=1,
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
local shopping=false
local chopBusy=false
local stopWalking=function() end
local function stop(key)
    states[key]=false
    if key=="wood" then chopBusy=false stopWalking() end
    if renderToggle[key] then renderToggle[key]() end
    local job=jobs[key]
    jobs[key]=nil
    if job and coroutine.status(job)~="dead" then task.cancel(job) end
end
local itemIds={"LuckyCharm","RainbowDew"}
local itemLabels={}
local cooldown=600
local function deadline(item)
    return parent:GetAttribute("HardineroNext_"..item) or 0
end
local function startItem(item)
    if not states[item] then stop(item) return end
    if jobs[item] then return end
    jobs[item]=task.defer(function()
        while enabled(item) do
            local now=workspace:GetServerTimeNow()
            if now>=deadline(item) then
                local ok,err=pcall(fire,"UseItem",item)
                if not ok then
                    states[item]=false
                    if renderToggle[item] then renderToggle[item]() end
                    report("Item error: "..tostring(err))
                    break
                end
                -- Local request timer; server success is not acknowledged.
                parent:SetAttribute("HardineroNext_"..item,workspace:GetServerTimeNow()+cooldown)
                report("Use requested: "..item)
            end
            task.wait(0.25)
        end
        jobs[item]=nil
    end)
end
local returnMode="Previous"
local savedCenter=nil
local pendingReturn=nil
local function currentPosition()
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    return root and root.CFrame
end
local function returnToPosition()
    local target=pendingReturn
    pendingReturn=nil
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if target and root then root.CFrame=target end
end
local function stopAll()
    for _,key in ipairs({"seeds","gears","harvest","dust","LuckyCharm","RainbowDew","wood"}) do stop(key) end
    local buyer=jobs.buyer
    jobs.buyer=nil
    if buyer and coroutine.status(buyer)~="dead" then task.cancel(buyer) end
    shopping=false
    returnToPosition()
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
-- Harvest has its own worker; one buyer visits both shops sequentially.
local shopStatus=nil
local function shopReport(message)
    report(message)
    if shopStatus then shopStatus.Text=message end
end
local function checkedInvoke(name,...)
    local result=invoke(name,...)
    assert(result~=false,name.." was rejected by server")
    return result
end
local function purchaseVisit(key)
    local ids=key=="seeds" and seedIds or gearIds
    local prefix=key=="seeds" and "seed:" or "gear:"
    if not enabled(key) or not hasSelection(ids,prefix) then return end
    local keeper=key=="seeds" and "SeedKeeper" or "GearKeeper"
    shopReport("Travel requested: "..keeper)
    fire("Travel",key=="seeds" and "Seeds" or "Gear")
    task.wait(SHOP_TRAVEL_WAIT)
    if not enabled(key) then return end
    shopReport("Opening "..keeper)
    checkedInvoke("NpcOpen",keeper)
    task.wait(0.4)
    if not enabled(key) then return end
    if key=="seeds" then
        shopReport("Opening seed special page")
        local response=seedChoice("page_special")
        assert(response~=false,"Seed special page rejected; check NpcChoose arguments")
        task.wait(0.25)
    end
    for _,id in ipairs(ids) do
        if not enabled(key) then return end
        if states[prefix..id] then
            local count=PURCHASE_COUNT
            for attempt=1,count do
                if not enabled(key) or not states[prefix..id] then break end
                shopReport("Requesting "..id.." "..attempt.."/"..count)
                local result
                if key=="seeds" then result=seedChoice(SEED_PREFIX..id)
                else result=invoke("NpcChoose","GearKeeper","stock_"..id) end
                if result==false then
                    shopReport("Rejected: "..id.."; skipping remaining requests")
                    task.wait(0.5)
                    break
                end
                task.wait(PURCHASE_DELAY)
            end
        end
    end
end
local function startBuyer()
    if jobs.buyer then return end
    jobs.buyer=task.defer(function()
        while alive and (states.seeds or states.gears) do
            shopping=true
            while alive and chopBusy do task.wait(0.1) end
            if not alive then break end
            local previous=currentPosition()
            if not previous then
                shopping=false
                report("Waiting for character")
                task.wait(1)
            else
                pendingReturn=(returnMode=="Bed center" and savedCenter) or previous
                for _,key in ipairs({"seeds","gears"}) do
                    if enabled(key) then
                        local ids=key=="seeds" and seedIds or gearIds
                        local prefix=key=="seeds" and "seed:" or "gear:"
                        if not hasSelection(ids,prefix) then
                            stop(key)
                            report("No "..key.." selected; buying stopped")
                        else
                            local ok,err=pcall(purchaseVisit,key)
                            if not ok then stop(key) shopReport("Shop error: "..tostring(err)) end
                        end
                    end
                end
                -- Return after both enabled shop visits, including shop failures.
                returnToPosition()
                shopping=false
                if alive and (states.seeds or states.gears) then task.wait(CYCLE_DELAY) end
            end
        end
        jobs.buyer=nil
    end)
end
local harvestProgress=nil
local dustStatus=nil
local bedCount=0
local dustRequests=0
local function requestDust()
    local ok,err=pcall(fire,"UseItem","FairyDust")
    if ok then
        dustRequests=dustRequests+1
        if dustStatus then dustStatus.Text="Fairy Dust requests: "..dustRequests.." • last request sent" end
    else
        if dustStatus then dustStatus.Text="Fairy Dust error: "..tostring(err) end
        warn("HARDINERO Fairy Dust: "..tostring(err))
    end
    return ok,err
end
local function runAutomation(key)
    if key~="harvest" then
        if states[key] then
            local ids=key=="seeds" and seedIds or gearIds
            local prefix=key=="seeds" and "seed:" or "gear:"
            if not hasSelection(ids,prefix) then
                stop(key) report("Select items in the "..key.." tab first") return
            end
            startBuyer()
        end
        -- Let an active buyer finish returning when a shop toggle is disabled.
        return
    end
    if not states.harvest then stop("harvest") return end
    if jobs.harvest then return end
    jobs.harvest=task.defer(function()
        local ok,err=pcall(function()
            while enabled("harvest") do
                bedCount=0
                for row=1,11 do
                    for col=1,10 do
                        if not enabled("harvest") then return end
                        fire("FarmTap",("Bed_%d_%d"):format(row,col),nil)
                        bedCount=bedCount+1
                        if harvestProgress then harvestProgress.Text="Harvest round: "..bedCount.." / 110 taps" end
                        task.wait(BED_DELAY)
                    end
                end
                -- Only a fully completed 110-bed round can trigger Fairy Dust.
                if enabled("harvest") and states.dust then
                    -- Allow the last bed request to settle before the item request.
                    task.wait(0.3)
                    if not enabled("harvest") or not states.dust then return end
                    local used,err=requestDust()
                    if not used then
                        states.dust=false
                        if renderToggle.dust then renderToggle.dust() end
                        report("Fairy Dust error: "..tostring(err))
                    else report("110 bed taps completed • Fairy Dust requested") end
                end
            end
        end)
        if not ok then
            states.harvest=false
            if renderToggle.harvest then renderToggle.harvest() end
            report("Harvest error: "..tostring(err))
        end
        jobs.harvest=nil
    end)
end
local treeNames={Tree_Apple=true,Tree_Blossom=true,Tree_Pine=true,Tree_Round=true}
local chopMode="Teleport"
local chopHits=1
local Pathfinding=game:GetService("PathfindingService")
local function characterParts()
    local c=player.Character
    return c and c:FindFirstChild("HumanoidRootPart"),c and c:FindFirstChildOfClass("Humanoid")
end
stopWalking=function()
    local root,humanoid=characterParts()
    if root and humanoid then humanoid:MoveTo(root.Position) end
end
local function treesFolder()
    local island=workspace:FindFirstChild("FuzzIsland")
    local nature=island and island:FindFirstChild("Nature")
    return nature and nature:FindFirstChild("Trees")
end
local function treePosition(tree)
    if tree:IsA("Model") then return tree:GetPivot().Position end
    if tree:IsA("BasePart") then return tree.Position end
end
local function besideTree(tree,root)
    local center=treePosition(tree)
    if not center then return end
    local direction=Vector3.new(root.Position.X-center.X,0,root.Position.Z-center.Z)
    direction=direction.Magnitude>0.1 and direction.Unit or Vector3.new(1,0,0)
    -- Aim near the trunk rather than five studs away from the tree pivot.
    local sample=center+direction*1.8
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={tree,player.Character}
    local ground=workspace:Raycast(sample+Vector3.new(0,40,0),Vector3.new(0,-160,0),params)
    if not ground then return end
    return ground.Position+Vector3.new(0,3,0),center
end
local function moveToTree(target,center)
    local root,humanoid=characterParts()
    if not root or not humanoid or humanoid.Health<=0 then return false end
    if chopMode=="Teleport" then
        root.CFrame=CFrame.lookAt(target,Vector3.new(center.X,target.Y,center.Z))
        task.wait(0.15)
        root=select(1,characterParts())
        return root and (Vector3.new(root.Position.X,0,root.Position.Z)-Vector3.new(target.X,0,target.Z)).Magnitude<2
    end
    local path=Pathfinding:CreatePath({AgentCanJump=true,WaypointSpacing=3})
    path:ComputeAsync(root.Position,target)
    if path.Status~=Enum.PathStatus.Success then return false end
    local started=os.clock()
    for _,waypoint in ipairs(path:GetWaypoints()) do
        if not enabled("wood") or shopping then stopWalking() return false end
        if waypoint.Action==Enum.PathWaypointAction.Jump then humanoid.Jump=true end
        humanoid:MoveTo(waypoint.Position)
        local stepStart=os.clock()
        repeat
            task.wait(0.05)
            if not enabled("wood") or shopping or humanoid.Health<=0 then stopWalking() return false end
            if os.clock()-stepStart>4 or os.clock()-started>25 then stopWalking() return false end
        until (Vector3.new(root.Position.X,0,root.Position.Z)-Vector3.new(waypoint.Position.X,0,waypoint.Position.Z)).Magnitude<2
    end
    -- Finish the approach precisely; path waypoints alone can stop short.
    humanoid:MoveTo(target-Vector3.new(0,3,0))
    local finalStart=os.clock()
    repeat
        if not enabled("wood") or shopping then stopWalking() return false end
        local distance=(Vector3.new(root.Position.X,0,root.Position.Z)-Vector3.new(target.X,0,target.Z)).Magnitude
        if distance<=1.2 then
            root.CFrame=CFrame.lookAt(root.Position,Vector3.new(center.X,root.Position.Y,center.Z))
            return true
        end
        task.wait(0.05)
    until os.clock()-finalStart>2
    return false
end
local function startChop()
    if not states.wood then stop("wood") return end
    if jobs.wood then return end
    jobs.wood=task.defer(function()
        local attempted=setmetatable({},{__mode="k"})
        local ok,err=pcall(function()
            while enabled("wood") do
                if shopping then task.wait(0.2)
                else
                    local folder=treesFolder()
                    assert(folder,"Workspace.FuzzIsland.Nature.Trees was not found")
                    local root=select(1,characterParts())
                    local nearest,best=nil,math.huge
                    if root then
                        for _,tree in ipairs(folder:GetChildren()) do
                            if treeNames[tree.Name] and states["tree:"..tree.Name]
                                and os.clock()-(attempted[tree] or -math.huge)>=30 then
                                local position=treePosition(tree)
                                local distance=position and (position-root.Position).Magnitude or math.huge
                                if distance<best then nearest,best=tree,distance end
                            end
                        end
                    end
                    if not nearest then task.wait(1)
                    else
                        chopBusy=true
                        attempted[nearest]=os.clock()
                        local target,center=besideTree(nearest,root)
                        local arrived=target and moveToTree(target,center)
                        if arrived and not shopping then
                            for hit=1,chopHits do
                                if not enabled("wood") or shopping or nearest.Parent~=folder then break end
                                fire("Chop",nearest)
                                report("Chop requested: "..nearest.Name.." ("..hit..")")
                                task.wait(0.12)
                            end
                        end
                        chopBusy=false
                        task.wait(0.05)
                    end
                end
            end
        end)
        chopBusy=false
        stopWalking()
        if not ok then
            states.wood=false
            if renderToggle.wood then renderToggle.wood() end
            report("Chop error: "..tostring(err))
        end
        jobs.wood=nil
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
        TextSize=12,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left},row)
    local track=make("Frame", {Position=UDim2.new(1,-58,0.5,-11),
        Size=UDim2.fromOffset(44,22),BackgroundColor3=Color3.fromRGB(54,63,78),BorderSizePixel=0},row)
    corner(track,20)
    local knob=make("Frame", {Position=UDim2.fromOffset(3,3),Size=UDim2.fromOffset(16,16),
        BackgroundColor3=white,BorderSizePixel=0},track)
    corner(knob,20)
    row.Activated:Connect(function()
        states[key]=not states[key]
        renderToggle[key]()
        if key=="seeds" or key=="gears" or key=="harvest" then runAutomation(key)
        elseif key=="LuckyCharm" or key=="RainbowDew" then startItem(key)
        elseif key=="wood" then startChop()
        elseif key=="dust" and states.dust and not states.harvest then
            states.harvest=true
            renderToggle.harvest()
            runAutomation("harvest")
        end
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
textRow(farm,"Buy requests per selected item, per visit: 1–10. Default: 10. Limited stock may reject extra requests.")
local countInput=make("TextBox",{Size=UDim2.new(1,-8,0,38),Text="10",ClearTextOnFocus=false,
    BackgroundColor3=Color3.fromRGB(24,29,39),TextColor3=white,
    Font=Enum.Font.Gotham,TextSize=13,BorderSizePixel=0},farm)
corner(countInput,7)
countInput.FocusLost:Connect(function()
    local n=tonumber(countInput.Text)
    if n and n==n and math.abs(n)<math.huge then PURCHASE_COUNT=math.clamp(math.floor(n),1,10) end
    countInput.Text=tostring(PURCHASE_COUNT)
end)
shopStatus=textRow(farm,"Shop status: idle")
shopStatus.Size=UDim2.new(1,-8,0,65)

textRow(farm,"Harvest sends FarmTap to all 110 beds. Ripe-state detection is unavailable; other bed behavior is unverified.")
toggle(farm,"Repeat Harvest Taps (all beds)","harvest")
textRow(farm,"Harvest delay in milliseconds: 50–5000. Lower = faster; 100 ms is the default.")
local delayInput=make("TextBox",{
    Size=UDim2.new(1,-8,0,38),BackgroundColor3=Color3.fromRGB(24,29,39),
    Text=tostring(BED_DELAY*1000),PlaceholderText="Delay in ms (50–5000)",
    ClearTextOnFocus=false,TextColor3=white,Font=Enum.Font.Gotham,
    TextSize=13,BorderSizePixel=0},farm)
corner(delayInput,7)
delayInput.FocusLost:Connect(function()
    local milliseconds=tonumber(delayInput.Text)
    if not milliseconds or milliseconds~=milliseconds
        or milliseconds==math.huge or milliseconds==-math.huge then
        delayInput.Text=tostring(math.floor(BED_DELAY*1000+0.5))
        report("Enter a number from 50 to 5000 milliseconds")
        return
    end
    milliseconds=math.clamp(math.floor(milliseconds+0.5),50,5000)
    BED_DELAY=milliseconds/1000
    delayInput.Text=tostring(milliseconds)
    report("Harvest delay: "..milliseconds.." ms ("..BED_DELAY.." s)")
end)

button(farm,"STOP ALL",stopAll)
toggle(farm,"Fairy Dust after 110 taps","dust")
textRow(farm,"Enabling Fairy Dust also starts harvesting. It requests dust after each full 110-bed round, never before.")
harvestProgress=textRow(farm,"Harvest round: 0 / 110 taps")
dustStatus=textRow(farm,"Fairy Dust requests: 0")
button(farm,"Use Fairy Dust now (one request)",function()
    local ok,err=requestDust()
    if not ok then report("Fairy Dust error: "..tostring(err)) end
end)
textRow(farm,"Requests do not confirm consumption. If the manual button has no effect, capture UseItem again while manually using Fairy Dust.")
local itemsPage=page("Timers")
textRow(itemsPage,"Each item uses immediately when ready, then waits 10 minutes independently. OFF pauses use, not the clock.")
for _,item in ipairs(itemIds) do
    toggle(itemsPage,"Auto "..item,item)
    itemLabels[item]=textRow(itemsPage,item.." • Ready / OFF")
end
textRow(itemsPage,"Timers count from requests, not confirmed item effects. Missing inventory is not detected.")
local seedPage=page("Seeds")
textRow(seedPage,"Choose seeds. NpcChoose now sends two arguments; confirm the seed key in RSpy if rejected.")
for _,id in ipairs(seedIds) do toggle(seedPage,id,"seed:"..id) end
local gearPage=page("Gears")
textRow(gearPage,"Choose gears to purchase repeatedly.")
for _,id in ipairs(gearIds) do toggle(gearPage,id,"gear:"..id) end
local treesPage=page("Trees")
textRow(treesPage,"Move beside matching trees and chop. Shops get movement priority; harvesting continues.")
toggle(treesPage,"Auto Chop","wood")
for _,name in ipairs({"Tree_Apple","Tree_Blossom","Tree_Pine","Tree_Round"}) do
    toggle(treesPage,name,"tree:"..name)
    states["tree:"..name]=true
    renderToggle["tree:"..name]()
end
local modeButton=make("TextButton",{Size=UDim2.new(1,-8,0,42),Text="Movement: Teleport",
    BackgroundColor3=Color3.fromRGB(22,49,82),TextColor3=white,
    Font=Enum.Font.Gotham,TextSize=13,BorderSizePixel=0},treesPage)
corner(modeButton,7)
modeButton.Activated:Connect(function()
    chopMode=chopMode=="Teleport" and "Walk" or "Teleport"
    modeButton.Text="Movement: "..chopMode
end)
textRow(treesPage,"Hits per tree: 1–6 (your axe: 1). If teleports fail, select Walk.")
local hitsInput=make("TextBox",{Size=UDim2.new(1,-8,0,38),Text="1",ClearTextOnFocus=false,
    BackgroundColor3=Color3.fromRGB(24,29,39),TextColor3=white,
    Font=Enum.Font.Gotham,TextSize=13,BorderSizePixel=0},treesPage)
corner(hitsInput,7)
hitsInput.FocusLost:Connect(function()
    local n=tonumber(hitsInput.Text)
    if n and n==n and math.abs(n)<math.huge then chopHits=math.clamp(math.floor(n),1,6) end
    hitsInput.Text=tostring(chopHits)
end)
textRow(treesPage,"Each tree is retried after at least 30 seconds. Chopped-state detection is unavailable; removed objects are skipped.")
local travelPage=page("Travel")
for _,destination in ipairs({"Seeds","Gear","Forest"}) do
    button(travelPage,"Travel to "..destination,function()
        stopAll()
        fire("Travel",destination)
        report("Travel requested: "..destination)
    end)
end
local settings=page("Settings")
textRow(settings,"Drag header to move; corner to resize. Minimize becomes an icon; automation continues. X stops all.")
textRow(settings,"Harvest runs alongside buying. Shops share one queue; return after both visits.")
textRow(settings,"No stock / balance detection. A sent request does not confirm a successful purchase or harvest.")
textRow(settings,"Auto Chop is in Trees. Shop trips pause chopping movement; harvesting and item timers continue.")
local returnButton
returnButton=make("TextButton",{Size=UDim2.new(1,-8,0,42),
    Text="Return to: Previous position",BackgroundColor3=Color3.fromRGB(22,49,82),
    TextColor3=white,Font=Enum.Font.GothamMedium,TextSize=12,BorderSizePixel=0},settings)
corner(returnButton,7)
returnButton.Activated:Connect(function()
    if returnMode=="Previous" then
        if not savedCenter then report("Stand in the middle of your beds and save it first") return end
        returnMode="Bed center"
    else returnMode="Previous" end
    returnButton.Text="Return to: "..returnMode
end)
button(settings,"Save current position as bed center",function()
    local position=currentPosition()
    if not position then report("Character is unavailable") return end
    savedCenter=position
    report("Bed center saved for this session")
end)
textRow(settings,"Stand between your beds, save the center, then select Bed center. Previous position is captured before each buying round.")
textRow(settings,"Seed calls default to two arguments, matching the gear format. Change only to match your captured output.")
local seedModeButton=make("TextButton",{Size=UDim2.new(1,-8,0,42),Text="Seed arguments: Two",
    BackgroundColor3=Color3.fromRGB(22,49,82),TextColor3=white,
    Font=Enum.Font.Gotham,TextSize=12,BorderSizePixel=0},settings)
corner(seedModeButton,7)
seedModeButton.Activated:Connect(function()
    SEED_TWO_ARGUMENTS=not SEED_TWO_ARGUMENTS
    seedModeButton.Text="Seed arguments: "..(SEED_TWO_ARGUMENTS and "Two" or "One string")
end)
textRow(settings,"Seed purchase prefix: seeds (example seedsCorn). Use seeds# only if the capture includes #.")
local prefixInput=make("TextBox",{Size=UDim2.new(1,-8,0,38),Text=SEED_PREFIX,
    ClearTextOnFocus=false,BackgroundColor3=Color3.fromRGB(24,29,39),TextColor3=white,
    Font=Enum.Font.Gotham,TextSize=13,BorderSizePixel=0},settings)
corner(prefixInput,7)
prefixInput.FocusLost:Connect(function()
    if prefixInput.Text=="seeds" or prefixInput.Text=="seeds#" then SEED_PREFIX=prefixInput.Text end
    prefixInput.Text=SEED_PREFIX
end)
button(settings,"STOP ALL",stopAll)
local function selectPage(name)
    for key,p in pairs(pages) do p.Visible=key==name end
    for key,b in pairs(tabs) do
        b.BackgroundColor3=key==name and Color3.fromRGB(22,49,82) or Color3.fromRGB(15,19,27)
        b.TextColor3=key==name and blue or white
    end
end
for i,name in ipairs({"Main","Seeds","Gears","Timers","Trees","Travel","Settings"}) do
    local b=make("TextButton", {Position=UDim2.fromOffset(8,10+(i-1)*42),
        Size=UDim2.new(1,-16,0,36),Text="   "..name,TextXAlignment=Enum.TextXAlignment.Left,
        TextColor3=white,Font=Enum.Font.GothamMedium,TextSize=13,BorderSizePixel=0},sidebar)
    corner(b,6)
    tabs[name]=b
    b.Activated:Connect(function() selectPage(name) end)
end
make("TextLabel", {Position=UDim2.fromOffset(10,316),Size=UDim2.new(1,-20,0,32),
    BackgroundTransparency=1,Text=player.DisplayName,TextTruncate=Enum.TextTruncate.AtEnd,
    TextColor3=Color3.fromRGB(140,157,180),Font=Enum.Font.Gotham,TextSize=12},sidebar)
local grip=make("TextButton", {AnchorPoint=Vector2.new(1,1),Position=UDim2.fromScale(1,1),
    Size=UDim2.fromOffset(30,28),BackgroundTransparency=1,Text="◢",TextColor3=blue,
    TextSize=22,Active=true},panel)
local icon=make("TextButton",{Name="OpenHardinero",Size=UDim2.fromOffset(52,52),
    Position=UDim2.fromOffset(12,90),BackgroundColor3=Color3.fromRGB(13,27,47),
    Text="H",TextColor3=blue,Font=Enum.Font.GothamBold,TextSize=24,
    Visible=false,BorderSizePixel=0},screen)
corner(icon,18)
make("UIStroke",{Color=blue,Thickness=2},icon)
local iconDragged=false
mini.Activated:Connect(function()
    panel.Visible=false
    icon.Visible=true
end)
icon.Activated:Connect(function()
    if iconDragged then return end
    panel.Visible=true
    icon.Visible=false
end)
local operation,activeInput,startPoint,startPos,startSize
local connections={}
local function begin(input,mode)
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
    operation=mode
    activeInput=input
    startPoint=input.Position
    startPos=mode=="icon" and icon.Position or panel.Position
    if mode=="icon" then iconDragged=false end
    startSize=panel.AbsoluteSize
end
header.InputBegan:Connect(function(input) begin(input,"drag") end)
grip.InputBegan:Connect(function(input) begin(input,"resize") end)
icon.InputBegan:Connect(function(input) begin(input,"icon") end)
connections[1]=UIS.InputChanged:Connect(function(input)
    if not operation then return end
    local mouse=activeInput.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement
    if not mouse and input~=activeInput then return end
    local delta=input.Position-startPoint
    local cam=workspace.CurrentCamera
    local view=screen.AbsoluteSize
    if operation=="icon" then
        if delta.Magnitude>6 then iconDragged=true end
        icon.Position=UDim2.fromOffset(
            math.clamp(startPos.X.Offset+delta.X,0,math.max(0,view.X-52)),
            math.clamp(startPos.Y.Offset+delta.Y,0,math.max(0,view.Y-52)))
    elseif operation=="drag" then
        panel.Position=UDim2.fromOffset(
            math.clamp(startPos.X.Offset+delta.X,0,math.max(0,view.X-panel.AbsoluteSize.X)),
            math.clamp(startPos.Y.Offset+delta.Y,0,math.max(0,view.Y-panel.AbsoluteSize.Y)))
    else
        local maxW=math.max(1,view.X-panel.AbsolutePosition.X-8)
        local maxH=math.max(1,view.Y-panel.AbsolutePosition.Y-8)
        panel.Size=UDim2.fromOffset(math.clamp(startSize.X+delta.X,math.min(300,maxW),maxW),
            math.clamp(startSize.Y+delta.Y,math.min(240,maxH),maxH))
    end
end)
connections[2]=UIS.InputEnded:Connect(function(input)
    if input==activeInput then operation=nil activeInput=nil end
end)
local function fitScreen()
    local view=screen.AbsoluteSize
    if view.X<=0 or view.Y<=0 then return end
    local size=panel.AbsoluteSize
    local w=math.min(size.X,math.max(1,view.X-16))
    local h=math.min(size.Y,math.max(1,view.Y-16))
    panel.Size=UDim2.fromOffset(w,h)
    panel.Position=UDim2.fromOffset(
        math.clamp(panel.Position.X.Offset,0,math.max(0,view.X-w)),
        math.clamp(panel.Position.Y.Offset,0,math.max(0,view.Y-h)))
    icon.Position=UDim2.fromOffset(
        math.clamp(icon.Position.X.Offset,0,math.max(0,view.X-52)),
        math.clamp(icon.Position.Y.Offset,0,math.max(0,view.Y-52)))
end
connections[3]=screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitScreen)
task.defer(fitScreen)
jobs.timerDisplay=task.defer(function()
    while alive do
        local now=workspace:GetServerTimeNow()
        for _,item in ipairs(itemIds) do
            local remaining=math.max(0,math.ceil(deadline(item)-now))
            local clock=remaining>0 and ("%02d:%02d"):format(math.floor(remaining/60),remaining%60) or "Ready"
            itemLabels[item].Text=item.."  •  "..clock..(states[item] and " / ON" or " / OFF")
        end
        task.wait(0.25)
    end
end)
close.Activated:Connect(function() gui:Destroy() end)
gui.Destroying:Connect(function()
    alive=false
    stopAll()
    if jobs.timerDisplay then task.cancel(jobs.timerDisplay) end
    for _,connection in ipairs(connections) do connection:Disconnect() end
end)
selectPage("Main")
