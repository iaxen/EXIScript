-- HARDINERO: calls supplied by the user; server behavior is not verified.
-- Shop choices follow GameHUD: NpcChoose(keeperId, offeredOptionId).
local SEED_PREFIX = "seeds#"
local PURCHASE_DELAY = 0.25
local BED_DELAY = 0.1 -- Seconds; adjustable live from the Main tab.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local parent = player:WaitForChild("PlayerGui")
local old = parent:FindFirstChild("FarmPanel")
if old then old:Destroy() end
local blue = Color3.fromRGB(80, 160, 255)
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
    DisplayOrder=2147483647, ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, parent)
local screen=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1},gui)
local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(800,600)
local width = math.min(480, viewport.X - 24)
local height = math.min(320, viewport.Y - 24)
local panel = make("Frame", {Size=UDim2.fromOffset(width,height),
    Position=UDim2.fromOffset((viewport.X-width)/2,(viewport.Y-height)/2),
    BackgroundColor3=Color3.fromRGB(8,12,18),BackgroundTransparency=0.08, BorderSizePixel=0,
    ClipsDescendants=true}, screen)
corner(panel,5)
make("UIStroke", {Color=Color3.fromRGB(48,76,111),Thickness=1}, panel)
local header = make("Frame", {Size=UDim2.new(1,0,0,34),
    BackgroundColor3=Color3.fromRGB(17,22,31),BorderSizePixel=0,Active=true}, panel)
local title = make("TextLabel", {Position=UDim2.fromOffset(18,0),
    Size=UDim2.new(1,-120,1,0),BackgroundTransparency=1,
    Text="Hardinero | Fuzzopia",TextColor3=blue,Font=Enum.Font.BuilderSansBold,
    TextSize=11,TextXAlignment=Enum.TextXAlignment.Left}, header)
make("UIGradient",{
    Color=ColorSequence.new(Color3.fromRGB(175,209,255),Color3.fromRGB(105,125,152)),
    Rotation=12},header)
make("Frame",{Position=UDim2.fromOffset(7,11),Size=UDim2.fromOffset(2,12),
    BackgroundColor3=blue,BorderSizePixel=0},header)
local function headerButton(text,x)
    local b=make("TextButton", {Size=UDim2.fromOffset(28,26),
        Position=UDim2.new(1,x,0,4),BackgroundColor3=Color3.fromRGB(14,19,27),
        Text=text,TextColor3=white,TextSize=20,Font=Enum.Font.BuilderSans},header)
    corner(b,6)
    return b
end
local mini=headerButton("−",-65)
local close=headerButton("×",-33)
local body=make("Frame", {Position=UDim2.fromOffset(0,34),
    Size=UDim2.new(1,0,1,-34),BackgroundTransparency=1},panel)
local sidebar=make("ScrollingFrame", {Size=UDim2.new(0,100,1,0),
    CanvasSize=UDim2.fromOffset(0,380),ScrollBarThickness=2,
    BackgroundColor3=Color3.fromRGB(15,19,27),BorderSizePixel=0},body)
local content=make("Frame", {Position=UDim2.fromOffset(110,35),
    Size=UDim2.new(1,-122,1,-61),BackgroundTransparency=1},body)
local pageTitle=make("TextLabel",{Position=UDim2.fromOffset(110,1),Size=UDim2.new(1,-122,0,29),
    BackgroundTransparency=1,Text="Main",TextColor3=white,Font=Enum.Font.BuilderSansBold,
    TextSize=17,TextXAlignment=Enum.TextXAlignment.Left},body)
local selectPage
local pages={}
local tabs={}
local states={}
local configChanged=function() end
local alive=true
local jobs={}
local renderToggle={}
local Remotes=game:GetService("ReplicatedStorage"):WaitForChild("CozyVillageRemotes",10)
assert(Remotes,"CozyVillageRemotes was not found in this experience")
local status=make("TextLabel",{Position=UDim2.new(0,110,1,-27),
    Size=UDim2.new(1,-148,0,22),BackgroundTransparency=1,
    Text="Idle • all automation is OFF",TextColor3=blue,TextSize=11,
    Font=Enum.Font.Code,TextTruncate=Enum.TextTruncate.AtEnd,
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
    return invoke("NpcChoose","SeedKeeper",choice)
end
local function enabled(key)
    return alive and states[key]
end
local shopping=false
local fairyBusy=false
local fairyCleanup=function() end
local activityCleanup=function() end
local chopBusy=false
local stopWalking=function() end
local findFairy
local movement={owner=nil,waiting={},rank={buyer=0,seeds=0,normalSeeds=0,harvest=1,dust=1.5,sellBoom=2,fairy=-1,candyFairy=2.5,tend=4,gardenUpgrade=4,houseUpgrade=4,pickups=5,wood=6,fishing=7}}
movement.ready=function() return true end
function movement.active(key)
    if key=="buyer" then return alive and (states.seeds or states.normalSeeds or states.gears) end
    return alive and states[key]
end
function movement.release(key)
    movement.waiting[key]=nil
    if movement.owner==key then
        movement.owner=nil
        shopping=false
        chopBusy=false
        fairyBusy=false
    end
end
function movement.acquire(key)
    movement.waiting[key]=movement.waiting[key] or os.clock()
    while movement.active(key) do
        local first=nil
        local score=math.huge
        for candidate,since in pairs(movement.waiting) do
            if movement.active(candidate) and movement.ready(candidate) then
                local rank=movement.rank[candidate] or 8
                local value=rank<3 and rank or math.max(3,rank-math.min(2,(os.clock()-since)*0.1))
                if value<score then first,score=candidate,value end
            elseif not movement.active(candidate) then movement.waiting[candidate]=nil end
        end
        if not movement.owner and first==key then
            movement.waiting[key]=nil
            movement.owner=key
            shopping=key~="wood" and key~="harvest"
            chopBusy=key=="wood" or key=="harvest"
            fairyBusy=key=="fairy" or (key~="buyer" and key~="wood" and key~="harvest")
            return true
        end
        task.wait(0.05)
    end
    movement.waiting[key]=nil
    return false
end
local function stop(key)
    states[key]=false
    if key=="fairy" then fairyCleanup() end
    movement.release(key)
    if key=="pickups" or key=="fishing" or key=="sellBoom" or key=="houseUpgrade" or key=="gardenUpgrade" or key=="candyFairy" then activityCleanup(key) end
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
            local inventory=player:FindFirstChild("Inventory")
            local stock=inventory and inventory:FindFirstChild(item)
            local available=stock and (stock:IsA("IntValue") or stock:IsA("NumberValue")) and stock.Value>0
            if states.harvest and movement.owner=="harvest" and available and now>=deadline(item) then
                local ok,err=pcall(fire,"UseItem",item)
                if not ok then
                    states[item]=false
                    if renderToggle[item] then renderToggle[item]() end
                    report("Item error: "..tostring(err))
                    break
                end
                -- Local request timer; server success is not acknowledged.
                parent:SetAttribute("HardineroNext_"..item,workspace:GetServerTimeNow()+cooldown)
                configChanged()
                report("Use requested: "..item)
            end
            task.wait(0.25)
        end
        jobs[item]=nil
    end)
end
local tendLabel=nil
local animalCare={needed=0}
local function animalsNeedingCare()
    local village=workspace:FindFirstChild("CozyVillage")
    local animals=village and village:FindFirstChild("RanchAnimals")
    local needs={}
    if animals then
        for _,animal in ipairs(animals:GetChildren()) do
            if animal:GetAttribute("OwnerUserId")==player.UserId then
                local root=animal:FindFirstChild("Root")
                local prompt=root and root:FindFirstChild("CarePrompt")
                if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled
                    and not prompt.ActionText:lower():find("busy",1,true) then
                    needs[#needs+1]=animal.Name.."|"..prompt.ActionText.."|"..prompt.ObjectText
                end
            end
        end
    end
    table.sort(needs)
    animalCare.needed=#needs
    return #needs,table.concat(needs,";")
end
local function startTend()
    if not states.tend then stop("tend") return end
    if jobs.tend then return end
    jobs.tend=task.defer(function()
        local lastSignature=nil
        local lastRequest=0
        while enabled("tend") do
            local count,signature=animalsNeedingCare()
            if count>0 and (signature~=lastSignature or os.clock()-lastRequest>=5) then
                if not movement.acquire("tend") then break end
                count,signature=animalsNeedingCare()
                if count>0 then
                    local ok,err=pcall(fire,"FarmAction","tend")
                    if not ok then
                        movement.release("tend")
                        states.tend=false
                        renderToggle.tend()
                        report("Tend error: "..tostring(err))
                        break
                    end
                    lastSignature=signature
                    lastRequest=os.clock()
                    report("Tending requested for "..count.." animals needing care")
                end
                movement.release("tend")
            elseif count==0 then lastSignature=nil end
            task.wait(0.5)
        end
        movement.release("tend")
        jobs.tend=nil
    end)
end
local ownedBeds
local returnMode="Bed_6_5"
local ripeReturnPending=false
local function bedReturnPosition()
    local beds=ownedBeds and ownedBeds()
    local bed=beds and beds:FindFirstChild("Bed_6_5")
    if not bed then return end
    if bed:IsA("BasePart") then return bed.CFrame*CFrame.new(0,bed.Size.Y/2+3,0) end
    if bed:IsA("Model") then return bed:GetPivot()*CFrame.new(0,3,0) end
end
local savedCenter=nil
local pendingReturn=nil
local function currentPosition()
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    return root and root.CFrame
end
-- Count the whole owned bed grid, including narrow paths between beds.
local function atOwnBeds(position)
    local beds=ownedBeds and ownedBeds()
    if not beds then return false end
    for _,bed in ipairs(beds:GetChildren()) do
        if bed.Name:match("^Bed_%d+_%d+$") and (bed:IsA("BasePart") or bed:IsA("Model")) then
            local cf,size
            if bed:IsA("BasePart") then cf,size=bed.CFrame,bed.Size
            else cf,size=bed:GetBoundingBox() end
            local offset=cf:PointToObjectSpace(position)
            if math.abs(offset.X)<=size.X/2+3 and math.abs(offset.Z)<=size.Z/2+3
                and math.abs(offset.Y)<=size.Y/2+12 then return true end
        end
    end
    return false
end
local function tryRipeReturn()
    if not (alive and states.harvest and states.ripeReturn and ripeReturnPending) then return false end
    local c=player.Character
    local root=c and c:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    if atOwnBeds(root.Position) then
        ripeReturnPending=false
        return true
    end
    local target=bedReturnPosition()
    if not target then return false end
    root.CFrame=target
    ripeReturnPending=false
    report("Ripe crops detected • returned to Bed_6_5")
    return true
end
local function returnToPosition()
    local target=pendingReturn
    pendingReturn=nil
    if not states.returnAfterBuy then return end
    if returnMode=="Bed_6_5" then target=bedReturnPosition() or target end
    if tryRipeReturn() then return end
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if target and root and not atOwnBeds(root.Position)
        and (root.Position-target.Position).Magnitude>2 then root.CFrame=target end
end
local function stopAll()
    if jobs.seedCheck then task.cancel(jobs.seedCheck) jobs.seedCheck=nil end
    for _,key in ipairs({"seeds","normalSeeds","gears","harvest","dust","LuckyCharm","RainbowDew","wood","tend","water","ripeReturn","returnAfterBuy","fairy","candyFairy","antiAfk","pickups","fishing","sellBoom","houseUpgrade","gardenUpgrade"}) do stop(key) end
    local buyer=jobs.buyer
    jobs.buyer=nil
    if buyer and coroutine.status(buyer)~="dead" then task.cancel(buyer) end
    movement.release("buyer")
    shopping=false
    returnToPosition()
    report("Stopped • requests already sent cannot be undone")
end
local normalIds={}
local seedIds={"CrystalRose","Corn","Starfruit","FrostLily","CloudCotton","AuroraFern",
    "EmberBulb","CandyReed","StardustBush","PearlPod","Honeybell",
    "PeachTree","Lavender","Beanstalk","Sunbloom","WindbellTree",
    "PuddingGourd","PrismGourd","DreamPlumTree","PhoenixBloom","CometSquash",
    "OpalOrchid","StarlightTree","FuzzberryTree","RainbowFruitTree",
    "MoonMelon","Lotus","AvocadoTree","Moonflower","Watermelon"}
local gearIds={"WateringBucket","GrowthTonic","LuckyCharm","RainbowDew"}
local function hasSelection(ids,prefix)
    for _,id in ipairs(ids) do if states[prefix..id] then return true end end
    return false
end
-- Harvest has its own worker; one buyer visits both shops sequentially.
local gearDiagnostics={log={},reply=nil,statusLabel=nil,replyLabel=nil}
local shopStatus=nil
local function shopReport(message)
    report(message)
    if shopStatus then shopStatus.Text=message end
    gearDiagnostics.log[#gearDiagnostics.log+1]=message
    if #gearDiagnostics.log>15 then table.remove(gearDiagnostics.log,1) end
    if gearDiagnostics.statusLabel then gearDiagnostics.statusLabel.Text=table.concat(gearDiagnostics.log,"\n") end
end
local function checkedInvoke(name,...)
    local result=invoke(name,...)
    assert(result~=false,name.." was rejected by server")
    return result
end
local HttpService=game:GetService("HttpService")
local shopReplyLabel=nil
local seedDiagnostics={active=nil,labels={},replies={},logs={seeds={},normalSeeds={}}}

local function showShopReply(keeper,reply)
    local ok,encoded=pcall(function() return HttpService:JSONEncode(reply) end)
    local message=keeper.." reply: "..(ok and encoded or tostring(reply))
    if keeper:find("GearKeeper",1,true) then
        gearDiagnostics.reply=message
        if gearDiagnostics.replyLabel then gearDiagnostics.replyLabel.Text=message end
    elseif shopReplyLabel then shopReplyLabel.Text=message:sub(1,1800) end
    if keeper:find("SeedKeeper",1,true) and seedDiagnostics.active then
        local key=seedDiagnostics.active
        seedDiagnostics.replies[key]=message
        if seedDiagnostics.labels[key] then seedDiagnostics.labels[key].Text=message end
    end
    print("HARDINERO "..message)
end
local function keeperPrompt(keeper)
    for _,prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled and prompt:GetAttribute("NpcId")==keeper then
            return prompt
        end
    end
end
local function approachKeeper(key,keeper)
    local prompt=keeperPrompt(keeper)
    assert(prompt,"No active interaction prompt for "..keeper)
    local part=prompt:FindFirstAncestorWhichIsA("BasePart")
    local model=prompt:FindFirstAncestorWhichIsA("Model")
    local position=part and part.Position or (model and model:GetPivot().Position)
    assert(position,"NPC interaction position unavailable")
    local c=player.Character
    local root=c and c:FindFirstChild("HumanoidRootPart")
    local humanoid=c and c:FindFirstChildOfClass("Humanoid")
    assert(root and humanoid,"Character unavailable")
    local direction=Vector3.new(root.Position.X-position.X,0,root.Position.Z-position.Z)
    direction=direction.Magnitude>0.1 and direction.Unit or Vector3.new(0,0,1)
    local destination=position+direction*2.5
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={c,model or part}
    local ground=workspace:Raycast(destination+Vector3.new(0,12,0),Vector3.new(0,-60,0),params)
    if ground then destination=Vector3.new(destination.X,ground.Position.Y+humanoid.HipHeight+root.Size.Y/2,destination.Z) end
    shopReport("Teleporting beside "..keeper)
    root.CFrame=CFrame.lookAt(destination,Vector3.new(position.X,destination.Y,position.Z))
    task.wait(0.35)
    if not enabled(key) then return false end
    assert((root.Position-position).Magnitude<=prompt.MaxActivationDistance,"NPC teleport was rejected or is outside interaction range")
    -- Shop requests return menu data directly; only the game's prompt handler renders it.
    if key=="fairy" then
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration+0.15)
        prompt:InputHoldEnd()
        task.wait(0.25)
    end
    return enabled(key)
end
local function yieldShopForFarm(key,keeper)
    local owner=movement.owner
    if not owner or not movement.higherPending(owner) then return true end
    movement.release(owner)
    if not movement.acquire(owner) or not enabled(key) then return false end
    if not approachKeeper(key,keeper) then return false end
    local menu=checkedInvoke("NpcOpen",keeper)
    if key=="seeds" then
        local page="page_special"
        for _,option in ipairs(type(menu)=="table" and menu.Options or {}) do
            if option.Id=="page_special" or tostring(option.Text or ""):lower():find("special seeds",1,true) then page=option.Id break end
        end
        checkedInvoke("NpcChoose",keeper,page)
    end
    return true
end
local function extractStock(reply)
    -- Only accept an explicit stock map; never infer quantities from prices or inventory.
    if type(reply)~="table" then return end
    local stock=reply.stock or reply.Stock
    if type(stock)=="table" then return stock end
    local parsed={}
    local found=false
    for _,option in ipairs(reply.Options or {}) do
        if type(option.Id)=="string" and type(option.Text)=="string" then
            local remaining=option.Text:match("%((%d+) left%)")
            if remaining then
                parsed[option.Id]=tonumber(remaining)
                found=true
            end
        end
    end
    if found then return parsed end
end
local function stockCount(stock,id)
    if not stock then return end
    local entry=stock[id] or stock["stock_"..id] or stock[SEED_PREFIX..id]
        or stock["seeds#"..id] or stock["seeds_"..id] or stock["seed_"..id] or stock["seed#"..id]
    local value=entry
    if type(entry)=="table" then value=entry.remaining or entry.stock or entry.Stock end
    if type(value)=="number" and value==value and value>=0 and value<math.huge then
        return math.floor(value)
    end
end
local stockConfig=nil
local function getStockConfig()
    if stockConfig then return stockConfig end
    local shared=game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
    local module=shared and shared:FindFirstChild("StockConfig")
    assert(module and module:IsA("ModuleScript"),"Shared.StockConfig module unavailable")
    local config=require(module)
    assert(type(config)=="table" and type(config.Lineup)=="function"
        and type(config.Window)=="function","StockConfig has an unexpected format")
    stockConfig=config
    return config
end
local function stockWindow()
    local config=getStockConfig()
    return config.Window(math.floor(workspace:GetServerTimeNow()))
end
local function requestKey(kind,id)
    return "HardineroStockV4_"..kind.."_"..id
end
local function requestsThisWindow(kind,id,window)
    local key=requestKey(kind,id)
    if parent:GetAttribute(key.."_Window")~=window then return 0 end
    return parent:GetAttribute(key.."_Count") or 0
end
local function recordRequest(kind,id,window)
    local key=requestKey(kind,id)
    local count=requestsThisWindow(kind,id,window)
    parent:SetAttribute(key.."_Window",window)
    parent:SetAttribute(key.."_Count",count+1)
end
local function calculatedStock(kind,ids,window)
    local lineup=getStockConfig().Lineup(kind,window)
    local remaining={}
    for _,id in ipairs(ids) do
        remaining[id]=math.max(0,(lineup[id] or 0)-requestsThisWindow(kind,id,window))
    end
    return remaining
end
local seedStatus={}
local function seedReport(key,message)
    report(message)
    local log=seedDiagnostics.logs[key]
    log[#log+1]=os.date("%H:%M:%S").."  "..message
    if #log>12 then table.remove(log,1) end
    if seedStatus[key] then seedStatus[key].Text=table.concat(log,"\n") end
    print("HARDINERO seeds: "..message)
end
local function seedInventoryCount(id)
    local inventory=player:FindFirstChild("Inventory")
    local config=require(game:GetService("ReplicatedStorage").Shared.ItemConfig)
    local crop=config.Crops[id]
    local item=inventory and crop and inventory:FindFirstChild(crop.SeedItemId)
    if not item then return 0 end
    if item:IsA("IntValue") or item:IsA("NumberValue") then return item.Value end
    return nil
end
local function purchaseSeeds(key)
    seedDiagnostics.active=key
    seedReport(key,"Starting "..(key=="seeds" and "Special" or "Normal").." Seeds visit")
    local ids=key=="seeds" and seedIds or normalIds
    local selection=key=="seeds" and "seed:" or "normal:"
    if not enabled(key) or not hasSelection(ids,selection) then return end
    if not approachKeeper(key,"SeedKeeper") then return end
    seedReport(key,"NpcOpen request: SeedKeeper")
    local menu=checkedInvoke("NpcOpen","SeedKeeper")
    assert(type(menu)=="table","SeedKeeper returned no dialogue")
    showShopReply("SeedKeeper",menu)
    local page=nil
    for _,option in ipairs(menu.Options or {}) do
        local text=tostring(option.Text or ""):lower()
        if key=="seeds" and (option.Id=="page_special" or text:find("special seeds",1,true)) then page=option.Id break end
        if key=="normalSeeds" and (option.Id=="page_normal" or text:find("normal seeds",1,true)) then page=option.Id break end
    end
    if key=="seeds" and not page then
        seedReport(key,"No Special Seeds choice returned. Open Settings > Shop diagnostics.")
        return
    end
    if page then
        seedReport(key,"Selecting page: "..tostring(page))
        menu=checkedInvoke("NpcChoose","SeedKeeper",page)
    end
    assert(type(menu)=="table" and type(menu.Options)=="table","Seed page returned no Options")
    local config=require(game:GetService("ReplicatedStorage").Shared.ItemConfig)
    local matched={}
    local purchases=0
    local outcomes={}
    for sweep=1,10 do
        local beforeSweep=purchases
        local visited={}
        local seenThisSweep={}
        if sweep>1 then
            if not yieldShopForFarm(key,"SeedKeeper") then return end
            menu=checkedInvoke("NpcOpen","SeedKeeper")
            if page then menu=checkedInvoke("NpcChoose","SeedKeeper",page) end
            seedReport(key,"Rechecking remaining selected stock, pass "..sweep)
        end
    for pageNumber=1,40 do
        if not enabled(key) then return end
        showShopReply("SeedKeeper",menu)
        local signature={}
        for _,option in ipairs(menu.Options or {}) do signature[#signature+1]=tostring(option.Id) end
        local fingerprint=table.concat(signature,"|")
        seedReport(key,"Offered IDs: "..fingerprint)
        if visited[fingerprint] then break end
        visited[fingerprint]=true
        seedReport(key,"Reading seed page "..pageNumber.." ("..#(menu.Options or {}).." choices)")
        for _,id in ipairs(ids) do
            if not enabled(key) then return end
            if states[selection..id] and not seenThisSweep[id] then
                if not yieldShopForFarm(key,"SeedKeeper") then return end
                local crop=config.Crops[id]
                local chosen=nil
                local candidates={
                    ["seeds#"..id]=true,["seeds"..id]=true,["seeds_"..id]=true,
                    ["seed_"..id]=true,["seed#"..id]=true
                }
                for _,option in ipairs(menu.Options or {}) do
                    if candidates[option.Id] then chosen=option break end
                end
                if chosen then
                    matched[id]=true
                    seenThisSweep[id]=true
                    local label=tostring(chosen.Text or ""):lower()
                    local live=tonumber(chosen.Remaining or chosen.Stock)
                        or tonumber(label:match("(%d+)%s+left"))
                    local max=(getStockConfig().Seeds[id] or {}).Max or 1
                    local amount=live or max
                    if label:find("sold out",1,true) or label:find("out of stock",1,true) then amount=0 end
                    if amount==0 then outcomes[id]="sold out / zero stock" end
                    if crop and (crop.UnlockLevel or 1)>(tonumber(player:GetAttribute("FarmLevel")) or 1) then
                        seedReport(key,id.." requires Farm Lv "..crop.UnlockLevel)
                        amount=0
                        outcomes[id]="locked at Farm Lv "..crop.UnlockLevel
                    end
                    for attempt=1,math.min(amount,50) do
                        if not yieldShopForFarm(key,"SeedKeeper") then return end
                        if not enabled(key) or not states[selection..id] then return end
                        local before=seedInventoryCount(id)
                        seedReport(key,"Buying "..id.." via "..tostring(chosen.Id))
                        local result=invoke("NpcChoose","SeedKeeper",chosen.Id)
                        if result==false or result==nil then
                            outcomes[id]="server declined request"
                            seedReport(key,"Server declined "..id.."; result="..tostring(result))
                            showShopReply("SeedKeeper purchase",result)
                            break
                        end
                        local replyText=type(result)=="table" and tostring(result.Text or "") or tostring(result)
                        local started=os.clock()
                        repeat task.wait(0.05)
                        until not enabled(key) or seedInventoryCount(id)~=before or os.clock()-started>=3
                        local after=seedInventoryCount(id)
                        if before~=nil and after~=nil and after>before then
                            purchases=purchases+1
                            seedReport(key,"Confirmed "..id..": +"..(after-before).." seeds")
                            outcomes[id]="purchased; awaiting stock recheck"
                        else
                            outcomes[id]="not confirmed: "..replyText:sub(1,100)
                            seedReport(key,"No seed increase for "..id..". Reply: "..replyText:sub(1,180))
                            showShopReply("SeedKeeper purchase",result)
                            break
                        end
                        task.wait(PURCHASE_DELAY)
                    end
                end
            end
        end
        local nextPage=nil
        for _,option in ipairs(menu.Options or {}) do
            if type(option.Id)=="string" and tostring(option.Text or ""):lower():find("next page",1,true) then
                nextPage=option.Id
                break
            end
        end
        if not nextPage then break end
        seedReport(key,"Selecting next page: "..nextPage)
        menu=checkedInvoke("NpcChoose","SeedKeeper",nextPage)
        assert(type(menu)=="table","Next seed page returned no menu")
    end
        if purchases==beforeSweep then break end
        if sweep==10 then seedReport(key,"Stock recheck limit reached; inspect remaining quantities") end
    end
    local missing={}
    for _,id in ipairs(ids) do
        if states[selection..id] then
            if not matched[id] then missing[#missing+1]=id
            else seedReport(key,id..": "..(outcomes[id] or "checked")) end
        end
    end
    if #missing>0 then seedReport(key,"Not offered on scanned pages: "..table.concat(missing,", ")) end
    seedReport(key,"Seed visit finished: "..purchases.." purchases confirmed")
end
local restockLabel=nil
local function purchaseVisit(key)
    if key=="seeds" or key=="normalSeeds" then return purchaseSeeds(key) end
    if not enabled("gears") or not hasSelection(gearIds,"gear:") then return end
    if not approachKeeper("gears","GearKeeper") then return end
    local window=stockWindow()
    local total=0
    local outcomes={}
    local function itemCount(id)
        local inventory=player:FindFirstChild("Inventory")
        local item=inventory and inventory:FindFirstChild(id)
        return item and (item:IsA("IntValue") or item:IsA("NumberValue")) and item.Value or 0
    end
    for sweep=1,3 do
        if not enabled("gears") or stockWindow()~=window then break end
        local beforeSweep=total
        local menu=checkedInvoke("NpcOpen","GearKeeper")
        assert(type(menu)=="table","GearKeeper returned no shop menu")
        showShopReply("GearKeeper",menu)
        shopReport("Gear stock pass "..sweep)
        for _,id in ipairs(gearIds) do
            if not enabled("gears") or stockWindow()~=window then return end
            if states["gear:"..id] then
                local option=nil
                for _,candidate in ipairs(menu.Options or {}) do
                    if candidate.Id=="stock_"..id then option=candidate break end
                end
                if not option then
                    outcomes[id]="not offered"
                else
                    local text=tostring(option.Text or ""):lower()
                    local amount=tonumber(option.Remaining or option.Stock)
                        or tonumber(text:match("(%d+)%s+left"))
                    local stock=extractStock(menu)
                    amount=amount or stockCount(stock,id)
                    if text:find("sold out",1,true) or text:find("out of stock",1,true) then amount=0 end
                    amount=amount or (getStockConfig().Gear[id] or {}).Max or 1
                    if amount==0 then outcomes[id]="sold out / zero stock" end
                    for attempt=1,math.min(amount,50) do
                        if not enabled("gears") or not states["gear:"..id] then break end
                        if not yieldShopForFarm("gears","GearKeeper") then return end
                        local before=itemCount(id)
                        shopReport("Buying "..id.." "..attempt.."/"..amount)
                        local result=invoke("NpcChoose","GearKeeper",option.Id)
                        local started=os.clock()
                        repeat task.wait(0.05)
                        until not enabled("gears") or itemCount(id)>before or os.clock()-started>=3
                        local after=itemCount(id)
                        if after>before then
                            total=total+1
                            outcomes[id]="purchased; awaiting final stock check"
                            shopReport("Confirmed "..id..": +"..(after-before))
                        else
                            local text=type(result)=="table" and tostring(result.Text or "") or tostring(result)
                            outcomes[id]="not confirmed: "..text:sub(1,100)
                            shopReport(id..": "..outcomes[id])
                            showShopReply("GearKeeper purchase",result)
                            break
                        end
                        task.wait(PURCHASE_DELAY)
                    end
                end
            end
        end
        if total==beforeSweep then break end
    end
    for _,id in ipairs(gearIds) do
        if states["gear:"..id] then shopReport(id..": "..(outcomes[id] or "not checked")) end
    end
    shopReport("Gear visit finished: "..total.." purchases confirmed")
end
local function startBuyer()
    if jobs.buyer then return end
    jobs.buyer=task.defer(function()
        -- The game announces restocks when StockConfig.Window changes.
        -- Capture the current window so enabling a toggle never starts a shop trip immediately.
        local observedWindow=stockWindow()
        shopReport("Auto Buy enabled • waiting for the next restock")
        while alive and (states.seeds or states.normalSeeds or states.gears) do
            local window=stockWindow()
            if window==observedWindow then
                task.wait(0.5)
            else
                observedWindow=window
                if not movement.acquire("buyer") then break end
                local previous=currentPosition()
                if previous then
                    pendingReturn=(returnMode=="Bed center" and savedCenter) or previous
                    for _,key in ipairs({"normalSeeds","seeds","gears"}) do
                        if enabled(key) then
                            local ids=key=="seeds" and seedIds or (key=="normalSeeds" and normalIds or gearIds)
                            local prefix=key=="seeds" and "seed:" or (key=="normalSeeds" and "normal:" or "gear:")
                            if not hasSelection(ids,prefix) then
                                stop(key)
                                shopReport("No "..key.." selected; buying stopped")
                            else
                                local ok,err=pcall(purchaseVisit,key)
                                if not ok then
                                    stop(key)
                                    shopReport("Shop error: "..tostring(err))
                                    if key~="gears" then seedReport(key,"ERROR: "..tostring(err)) end
                                end
                            end
                        end
                    end
                    returnToPosition()
                else shopReport("Restock skipped • character unavailable") end
                movement.release("buyer")
            end
        end
        movement.release("buyer")
        jobs.buyer=nil
    end)
end
ownedBeds=function()
    local village=workspace:FindFirstChild("CozyVillage")
    local gardens=village and village:FindFirstChild("PlayerGardens")
    if gardens then
        for _,garden in ipairs(gardens:GetChildren()) do
            if garden:GetAttribute("OwnerUserId")==player.UserId then return garden:FindFirstChild("Beds") end
        end
    end
end
local function inventoryAmount(id)
    local inventory=player:FindFirstChild("Inventory")
    local item=inventory and inventory:FindFirstChild(id)
    if item and (item:IsA("IntValue") or item:IsA("NumberValue")) then return item.Value end
    return 0
end
local function farmReadiness()
    local beds=ownedBeds()
    local ripe,growing=0,0
    if beds then
        for _,bed in ipairs(beds:GetChildren()) do
            if bed:FindFirstChild("RipeSparkle") then ripe=ripe+1 end
            if bed:FindFirstChild("CropVisual") then growing=growing+1 end
        end
    end
    return ripe,growing,inventoryAmount("FairyDust")
end
function movement.higherPending(key)
    local rank=movement.rank[key] or 8
    if states.fairy and findFairy and inventoryAmount("GoldenAcorn")>0 and findFairy() and rank>movement.rank.fairy then return true end
    if states.harvest then
        local ripe,growing,dust=farmReadiness()
        if ripe>0 and rank>movement.rank.harvest then return true end
        if states.dust and dust>0 and ripe==0 and growing>0 and rank>movement.rank.dust then return true end
    end
    for candidate in pairs(movement.waiting) do
        if movement.active(candidate) and movement.ready(candidate) and (movement.rank[candidate] or 8)<rank then return true end
    end
    return false
end
local ripeMarkers=setmetatable({},{__mode="k"})
local ripeAttempts=setmetatable({},{__mode="k"})
local function startWater()
    if not states.water then stop("water") return end
    if jobs.water then return end
    jobs.water=task.defer(function()
        local sent=setmetatable({},{__mode="k"})
        local ok,err=pcall(function()
            while enabled("water") do
                local beds=not movement.owner and ownedBeds() or nil
                if beds then
                    for _,bed in ipairs(beds:GetChildren()) do
                        if not enabled("water") then return end
                        if movement.owner then break end
                        local marker=bed:FindFirstChild("NeedsWater")
                        if marker and sent[bed]~=marker and not bed:FindFirstChild("RipeSparkle") then
                            fire("FarmTap",bed.Name,nil)
                            sent[bed]=marker
                            task.wait(BED_DELAY)
                        elseif not marker then sent[bed]=nil end
                    end
                end
                task.wait(1)
            end
        end)
        if not ok then
            states.water=false
            if renderToggle.water then renderToggle.water() end
            report("Water error: "..tostring(err))
        end
        jobs.water=nil
    end)
end
local harvestProgress=nil
local dustStatus=nil
local bedCount=0
local dustRequests=0
local dustAwaitingRipening=false
local dustRequestTime=0
local function requestDust()
    local ok,err=pcall(fire,"UseItem","FairyDust")
    if ok then
        dustRequests=dustRequests+1
        dustAwaitingRipening=true
        dustRequestTime=workspace:GetServerTimeNow()
        if dustStatus then dustStatus.Text="Fairy Dust requests: "..dustRequests.." • last request sent" end
    else
        if dustStatus then dustStatus.Text="Fairy Dust error: "..tostring(err) end
        warn("HARDINERO Fairy Dust: "..tostring(err))
    end
    return ok,err
end
movement.ready=function(key)
    local ripe,growing,dust=farmReadiness()
    if ripe>0 then dustAwaitingRipening=false end
    if key=="harvest" then return ripe>0 end
    if key=="dust" then
        return states.harvest and ripe==0 and growing>0 and dust>0
            and (not dustAwaitingRipening or workspace:GetServerTimeNow()-dustRequestTime>=10)
    end
    if key=="wood" or key=="pickups" then
        if states.harvest then return ripe==0 and dust==0 end
    end
    return true
end
local function startDust()
    if not states.dust then stop("dust") return end
    if jobs.dust then return end
    jobs.dust=task.defer(function()
        while enabled("dust") do
            if not movement.acquire("dust") then break end
            local ripe,growing,count=farmReadiness()
            if ripe==0 and growing>0 and count>0 and states.harvest then
                local used,err=requestDust()
                if not used then
                    states.dust=false
                    renderToggle.dust()
                    report("Fairy Dust error: "..tostring(err))
                end
            end
            movement.release("dust")
            task.wait(0.25)
        end
        movement.release("dust")
        jobs.dust=nil
    end)
end
local function runAutomation(key)
    if key~="harvest" then
        if states[key] then
            local ids=key=="seeds" and seedIds or (key=="normalSeeds" and normalIds or gearIds)
            local prefix=key=="seeds" and "seed:" or (key=="normalSeeds" and "normal:" or "gear:")
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
                if not movement.acquire("harvest") then return end
                tryRipeReturn()
                local c=player.Character
                local root=c and c:FindFirstChild("HumanoidRootPart")
                if root and not atOwnBeds(root.Position) then
                    local target=bedReturnPosition()
                    if target then root.CFrame=target task.wait(0.2) end
                end
                bedCount=0
                for row=1,11 do
                    if movement.higherPending("harvest") then break end
                    for col=1,10 do
                        if movement.higherPending("harvest") then break end
                        if not enabled("harvest") then movement.release("harvest") return end
                        local bedId=("Bed_%d_%d"):format(row,col)
                        local requested=false
                        if states.ripeOnly then
                            local beds=ownedBeds()
                            local bed=beds and beds:FindFirstChild(bedId)
                            local marker=bed and bed:FindFirstChild("RipeSparkle")
                            if marker and (ripeMarkers[bed]~=marker or os.clock()-(ripeAttempts[bed] or 0)>=1) then
                                fire("FarmTap",bedId,nil)
                                requested=true
                                ripeMarkers[bed]=marker
                                ripeAttempts[bed]=os.clock()
                            elseif bed and not marker then ripeMarkers[bed]=nil end
                        else fire("FarmTap",bedId,nil) requested=true end
                        bedCount=bedCount+1
                        if harvestProgress then harvestProgress.Text="Harvest round: "..bedCount.." / 110 beds checked" end
                        if requested then task.wait(BED_DELAY) end
                    end
                end

                movement.release("harvest")
                task.wait(0.1)
            end
        end)
        movement.release("harvest")
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
        if not enabled("wood") or shopping or movement.higherPending("wood") then stopWalking() return false end
        if waypoint.Action==Enum.PathWaypointAction.Jump then humanoid.Jump=true end
        humanoid:MoveTo(waypoint.Position)
        local stepStart=os.clock()
        repeat
            task.wait(0.05)
            if not enabled("wood") or shopping or movement.higherPending("wood") or humanoid.Health<=0 then stopWalking() return false end
            if os.clock()-stepStart>4 or os.clock()-started>25 then stopWalking() return false end
        until (Vector3.new(root.Position.X,0,root.Position.Z)-Vector3.new(waypoint.Position.X,0,waypoint.Position.Z)).Magnitude<2
    end
    -- Finish the approach precisely; path waypoints alone can stop short.
    humanoid:MoveTo(target-Vector3.new(0,3,0))
    local finalStart=os.clock()
    repeat
        if not enabled("wood") or shopping or movement.higherPending("wood") then stopWalking() return false end
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
                            if treeNames[tree.Name] and tree:GetAttribute("Choppable")==true
                                and not tree:GetAttribute("Felled") and states["tree:"..tree.Name]
                                and os.clock()-(attempted[tree] or -math.huge)>=30 then
                                local position=treePosition(tree)
                                local distance=position and (position-root.Position).Magnitude or math.huge
                                if distance<best then nearest,best=tree,distance end
                            end
                        end
                    end
                    if not nearest then task.wait(1)
                    else
                        if not movement.acquire("wood") then return end
                        root=select(1,characterParts())
                        if not root or nearest.Parent~=folder then movement.release("wood") return end
                        attempted[nearest]=os.clock()
                        local target,center=besideTree(nearest,root)
                        local arrived=target and moveToTree(target,center)
                        if arrived and not shopping then
                            for hit=1,chopHits do
                                if not enabled("wood") or shopping or movement.higherPending("wood") or nearest.Parent~=folder or nearest:GetAttribute("Felled") then break end
                                fire("Chop",nearest)
                                report("Chop requested: "..nearest.Name.." ("..hit..")")
                                task.wait(0.12)
                            end
                        end
                        movement.release("wood")
                        task.wait(0.05)
                    end
                end
            end
        end)
        movement.release("wood")
        stopWalking()
        if not ok then
            states.wood=false
            if renderToggle.wood then renderToggle.wood() end
            report("Chop error: "..tostring(err))
        end
        jobs.wood=nil
    end)
end
local fairyLabel=nil
local fairyOrigin=nil
local function fairyReport(message)
    report(message)
    if fairyLabel then fairyLabel.Text=message end
end
fairyCleanup=function()
    if not fairyBusy then return end
    stopWalking()
    local handled=tryRipeReturn()
    local target=fairyOrigin
    local c=player.Character
    local root=c and c:FindFirstChild("HumanoidRootPart")
    if not handled and root and target and not atOwnBeds(root.Position) then root.CFrame=target end
    fairyOrigin=nil
    movement.release("fairy")
end
findFairy=function()
    for _,prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local id=prompt:GetAttribute("NpcId")
            if type(id)=="string" then
                local model=prompt:FindFirstAncestorWhichIsA("Model")
                local clue=(id.." "..prompt.ObjectText.." "..(model and model.Name or "")):lower()
                if clue:find("fairy",1,true) or clue:find("twinkle",1,true) then return prompt,id end
            end
        end
    end
end
local function acorns()
    local inventory=player:FindFirstChild("Inventory")
    local value=inventory and inventory:FindFirstChild("GoldenAcorn")
    if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then return value.Value end
    return 0
end
local function startFairy()
    if not states.fairy then stop("fairy") return end
    if jobs.fairy then return end
    jobs.fairy=task.defer(function()
        while enabled("fairy") do
            local prompt,id=findFairy()
            if not prompt then fairyReport("Fairy: waiting for a visible NPC prompt")
            elseif acorns()<1 then fairyReport("Fairy: waiting for a Golden Acorn")
            else
                if not movement.acquire("fairy") then break end
                fairyOrigin=currentPosition()
                local ok,err=pcall(function()
                    if not approachKeeper("fairy",id) then return end
                    local trades=0
                    while enabled("fairy") and prompt.Parent and prompt.Enabled and acorns()>0 do
                        local menu=checkedInvoke("NpcOpen",id)
                        local choice=nil
                        for _,option in ipairs(type(menu)=="table" and menu.Options or {}) do
                            local text=tostring(option.Text or ""):lower()
                            if type(option.Id)=="string" and text:find("3 fairy dust",1,true)
                                and text:find("golden acorn",1,true) then choice=option.Id break end
                        end
                        if not choice then
                            showShopReply(id,menu)
                            error("Fairy trade option unavailable; see Shop reply in Settings")
                        end
                        local before=acorns()
                        invoke("NpcChoose",id,choice)
                        local started=os.clock()
                        repeat task.wait(0.1)
                        until not enabled("fairy") or acorns()<before or os.clock()-started>=3
                        if not enabled("fairy") then return end
                        if acorns()>=before then error("Fairy trade not confirmed: Golden Acorn count did not decrease") end
                        trades=trades+1
                        fairyReport("Fairy trades: "..trades.." • acorns remaining: "..acorns())
                        task.wait(0.25)
                    end
                end)
                fairyCleanup()
                if not ok then
                    states.fairy=false
                    renderToggle.fairy()
                    fairyReport("Fairy error: "..tostring(err))
                end
            end
            task.wait(3)
        end
        fairyCleanup()
        jobs.fairy=nil
    end)
end
-- Prompt actions share the movement queue with shops, trees and the fairy.
local activityOwner=nil
local activityStatus={}
local catchSequence=0
local auxiliaryConnections={}
local catchEvent=game:GetService("ReplicatedStorage").Shared:FindFirstChild("FishingCatchEvent")
if catchEvent and catchEvent:IsA("RemoteEvent") then
    auxiliaryConnections[#auxiliaryConnections+1]=catchEvent.OnClientEvent:Connect(function(kind)
        if kind=="catch" then catchSequence=catchSequence+1 end
    end)
end
local function activityReport(key,message)
    report(message)
    if activityStatus[key] then activityStatus[key].Text=message end
end
activityCleanup=function(key)
    if activityOwner~=key then return end
    stopWalking()
    activityOwner=nil
    movement.release(key)
end
local function teleportPrompt(key,prompt)
    if not enabled(key) or not prompt.Parent or not prompt.Enabled then return false end
    local c=player.Character
    local root=c and c:FindFirstChild("HumanoidRootPart")
    local humanoid=c and c:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return false end
    local part=prompt:FindFirstAncestorWhichIsA("BasePart")
    local model=prompt:FindFirstAncestorWhichIsA("Model")
    local holder=prompt.Parent
    local pos=holder:IsA("Attachment") and holder.WorldPosition or (part and part.Position or (model and model:GetPivot().Position))
    if not pos then return false end
    local offset=Vector3.new(root.Position.X-pos.X,0,root.Position.Z-pos.Z)
    offset=offset.Magnitude>0.1 and offset.Unit or Vector3.new(1,0,0)
    local target=pos+offset*math.min(2.5,prompt.MaxActivationDistance*0.5)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={c,model or part}
    local ground=workspace:Raycast(target+Vector3.new(0,15,0),Vector3.new(0,-80,0),params)
    if ground then target=Vector3.new(target.X,ground.Position.Y+humanoid.HipHeight+root.Size.Y/2,target.Z) end
    if key=="pickups" then target=pos+Vector3.new(0,math.min(1,prompt.MaxActivationDistance*0.25),0) end
    if key~="fishing" or (root.Position-pos).Magnitude>prompt.MaxActivationDistance*0.8 then
        root.CFrame=CFrame.new(target)
        task.wait(0.2)
    end
    if not enabled(key) or not prompt.Parent then return false end
    if (root.Position-pos).Magnitude>prompt.MaxActivationDistance then return false end
    if type(fireproximityprompt)=="function" then
        fireproximityprompt(prompt)
    else
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration+0.05)
        prompt:InputHoldEnd()
    end
    return true
end
local pickupNames={
    ["wildflowers"]=true,["candy"]=true,["acorn"]=true,["bird feather"]=true,
    ["forest mushroom"]=true,["golden acorn"]=true,["four leaf clover"]=true,
    ["four-leaf clover"]=true,["clover"]=true}
do
    local ok,config=pcall(function() return require(game:GetService("ReplicatedStorage").Shared.ItemConfig) end)
    if ok then
        for _,item in pairs(config.Forage or {}) do
            if type(item)=="table" and type(item.DisplayName)=="string" then
                pickupNames[item.DisplayName:lower()]=true
            end
        end
    end
end
local function closestPrompt(predicate)
    local c=player.Character
    local root=c and c:FindFirstChild("HumanoidRootPart")
    local closest,distance=nil,math.huge
    if not root then return end
    local island=workspace:FindFirstChild("FuzzIsland") or workspace
    for _,prompt in ipairs(island:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled and predicate(prompt) then
            local part=prompt:FindFirstAncestorWhichIsA("BasePart")
            if part then
                local d=(root.Position-part.Position).Magnitude
                if d<distance then closest,distance=prompt,d end
            end
        end
    end
    return closest
end
local function visibleForestDrop(attempted)
    local folder=workspace:FindFirstChild("ForestFinds",true)
    if not folder then return end
    local c=player.Character
    local root=c and c:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local closest,best=nil,math.huge
    for _,drop in ipairs(folder:GetChildren()) do
        if (drop:IsA("Model") or drop:IsA("BasePart")) and drop.Name:match("^Find_")
            and os.clock()-(attempted[drop] or -math.huge)>=5 then
            local part=drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart",true)
            if part and part.Transparency<1 then
                local distance=(part.Position-root.Position).Magnitude
                if distance<best then closest,best=drop,distance end
            end
        end
    end
    return closest
end
local function collectForestDrop(key,drop)
    local c=player.Character
    local root=c and c:FindFirstChild("HumanoidRootPart")
    if not root or not drop.Parent then return false end
    local part=drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart",true)
    if not part then return false end
    -- Drops are discovered as Find_* objects, independent of whether a prompt is visible.
    root.CFrame=CFrame.new(part.Position+Vector3.new(0,0.8,0))
    task.wait(0.15)
    if not enabled(key) then return false end
    local prompt=drop:FindFirstChildWhichIsA("ProximityPrompt",true)
    if prompt and prompt.Enabled then
        if type(fireproximityprompt)=="function" then fireproximityprompt(prompt)
        else prompt:InputHoldBegin() task.wait(prompt.HoldDuration+0.05) prompt:InputHoldEnd() end
    else
        local click=drop:FindFirstChildWhichIsA("ClickDetector",true)
        if click and type(fireclickdetector)=="function" then fireclickdetector(click) end
        if type(firetouchinterest)=="function" then
            firetouchinterest(root,part,0)
            task.wait(0.05)
            firetouchinterest(root,part,1)
        end
    end
    -- Ordinary physical contact also works for touch-driven drops.
    task.wait(0.2)
    return drop.Parent==nil or part.Parent==nil
end
local function ownedGarden()
    local beds=ownedBeds()
    return beds and beds.Parent
end
local function offeredChoice(menu,predicate)
    for _,option in ipairs(type(menu)=="table" and menu.Options or {}) do
        if type(option.Id)=="string" and predicate(tostring(option.Text or ""):lower(),option.Id:lower()) then return option.Id end
    end
end
local function npcAction(key,npc,predicate)
    if not approachKeeper(key,npc) then return false end
    local menu=checkedInvoke("NpcOpen",npc)
    showShopReply(npc,menu)
    local choice=offeredChoice(menu,predicate)
    if not choice and key=="sellBoom" then
        local page=offeredChoice(menu,function(text)
            return text:find("sell crops",1,true) or text:find("sell produce",1,true)
        end)
        if page then
            menu=checkedInvoke("NpcChoose",npc,page)
            showShopReply(npc,menu)
            choice=offeredChoice(menu,predicate)
        end
    end
    if not choice then
        activityReport(key,"Required offer not in "..npc.." menu; see Shop reply")
        states[key]=false
        renderToggle[key]()
        return false
    end
    if key=="sellBoom" then
        local ends=tonumber(workspace:GetAttribute("IslandEventEndsAt")) or 0
        if workspace:GetAttribute("IslandEvent")~="MarketBoom" or ends<=workspace:GetServerTimeNow() then
            activityReport(key,"Market Boom ended before sale; waiting for next event")
            return false
        end
    end
    local result=invoke("NpcChoose",npc,choice)
    if result==false then activityReport(key,"Server declined "..key) return false end
    activityReport(key,"Requested "..key.." from "..npc)
    return true
end
local function startActivity(key)
    if not states[key] then stop(key) return end
    if jobs[key] then return end
    jobs[key]=task.defer(function()
        local attempted=setmetatable({},{__mode="k"})
        local lastMarket=nil
        local nextAttempt=0
        while enabled(key) do
            local now=workspace:GetServerTimeNow()
            local boom=workspace:GetAttribute("IslandEvent")=="MarketBoom"
            local boomEnd=tonumber(workspace:GetAttribute("IslandEventEndsAt")) or 0
            local ready=now>=nextAttempt
            if key=="sellBoom" then ready=ready and boom and boomEnd>now and lastMarket~=boomEnd end
            if ready then
                if not movement.acquire(key) then break end
                activityOwner=key
                local ok,err=pcall(function()
                    if key=="pickups" then
                        local drop=visibleForestDrop(attempted)
                        if drop then
                            attempted[drop]=os.clock()
                            local name=drop.Name
                            if collectForestDrop(key,drop) then
                                activityReport(key,"Collected "..name)
                            else activityReport(key,"Contact/interaction requested: "..name.."; will recheck") end
                        else activityReport(key,"Watching ForestFinds for visible drops") end
                        nextAttempt=workspace:GetServerTimeNow()+0.15
                    elseif key=="fishing" then
                        local prompt=closestPrompt(function(p)
                            return p.Name=="FishingPrompt" and (p.ObjectText:lower():find("lake",1,true)
                                or p:FindFirstAncestor("FishingSpot_Lake"))
                        end)
                        if prompt then
                            local sequence=catchSequence
                            if teleportPrompt(key,prompt) then
                                activityReport(key,"Cast requested at "..prompt.ObjectText)
                                local started=workspace:GetServerTimeNow()
                                repeat task.wait(0.05)
                                until not enabled(key) or catchSequence>sequence or movement.higherPending(key) or workspace:GetServerTimeNow()-started>=15
                                activityReport(key,catchSequence>sequence and "Fish catch confirmed" or "Waiting for next available cast")
                            end
                        else activityReport(key,"No available Cast Line prompt") end
                        nextAttempt=workspace:GetServerTimeNow()+0.05
                    elseif key=="sellBoom" then
                        if npcAction(key,"Grocer",function(text)
                            return text:find("sell all",1,true)~=nil
                        end) then lastMarket=boomEnd end
                        nextAttempt=now+15
                    elseif key=="houseUpgrade" then
                        npcAction(key,"Carpenter",function(text)
                            return (text:find("upgrade",1,true) or text:find("expand",1,true))
                                and (text:find("house",1,true) or text:find("cottage",1,true) or text:find("home",1,true))
                        end)
                        nextAttempt=now+15
                    elseif key=="gardenUpgrade" then
                        local garden=ownedGarden()
                        local prompt=garden and garden:FindFirstChild("UpgradeFarm",true)
                        if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
                            teleportPrompt(key,prompt)
                            activityReport(key,"Garden upgrade requested")
                        else activityReport(key,"Owned garden upgrade unavailable or already complete") end
                        nextAttempt=now+15
                    end
                end)
                activityCleanup(key)
                if not ok then
                    states[key]=false
                    renderToggle[key]()
                    activityReport(key,"Stopped: "..tostring(err))
                end
            elseif key=="sellBoom" and not boom then
                activityReport(key,"Waiting for the Market Boom event")
            end
            task.wait(key=="fishing" and 0.05 or 0.5)
        end
        activityCleanup(key)
        jobs[key]=nil
    end)
end
local candyFairyLabel=nil
local function candyFairyReport(message)
    report(message)
    if candyFairyLabel then candyFairyLabel.Text=message end
end
local function fairyPrompts()
    local prompts={}
    for _,prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled and type(prompt:GetAttribute("NpcId"))=="string" then
            local id=prompt:GetAttribute("NpcId")
            local model=prompt:FindFirstAncestorWhichIsA("Model")
            local name=(id.." "..prompt.ObjectText.." "..(model and model.Name or "")):lower()
            if name:find("fairy",1,true) or name:find("twinkle",1,true) then prompts[#prompts+1]=prompt end
        end
    end
    return prompts
end
local function startCandyFairy()
    if not states.candyFairy then stop("candyFairy") return end
    if jobs.candyFairy then return end
    jobs.candyFairy=task.defer(function()
        local nextCheck=setmetatable({},{__mode="k"})
        while enabled("candyFairy") do
            if inventoryAmount("Candy")>0 then
                for _,prompt in ipairs(fairyPrompts()) do
                    if not enabled("candyFairy") then break end
                    if os.clock()>=(nextCheck[prompt] or 0) then
                        if not movement.acquire("candyFairy") then return end
                        activityOwner="candyFairy"
                        local ok,err=pcall(function()
                            local id=prompt:GetAttribute("NpcId")
                            if not approachKeeper("candyFairy",id) then return end
                            local menu=checkedInvoke("NpcOpen",id)
                            showShopReply(id,menu)
                            local choice=offeredChoice(menu,function(text)
                                return text:find("candy",1,true) and text:find("fairy dust",1,true)
                            end)
                            if not choice then
                                candyFairyReport("No Candy → Fairy Dust offer from "..id)
                                nextCheck[prompt]=os.clock()+15
                                return
                            end
                            local beforeCandy=inventoryAmount("Candy")
                            local beforeDust=inventoryAmount("FairyDust")
                            invoke("NpcChoose",id,choice)
                            local started=os.clock()
                            repeat task.wait(0.1)
                            until not enabled("candyFairy") or (inventoryAmount("Candy")<beforeCandy and inventoryAmount("FairyDust")>beforeDust) or os.clock()-started>=4
                            if inventoryAmount("Candy")<beforeCandy and inventoryAmount("FairyDust")>beforeDust then
                                candyFairyReport("Candy trade confirmed at "..id.." • candy left: "..inventoryAmount("Candy"))
                                nextCheck[prompt]=os.clock()+0.25
                            else
                                candyFairyReport("Candy trade not confirmed at "..id.."; see NPC reply")
                                nextCheck[prompt]=os.clock()+15
                            end
                        end)
                        activityCleanup("candyFairy")
                        if not ok then candyFairyReport("Candy trade error: "..tostring(err)) nextCheck[prompt]=os.clock()+15 end
                    end
                end
            else candyFairyReport("Waiting for Candy") end
            task.wait(0.5)
        end
        activityCleanup("candyFairy")
        jobs.candyFairy=nil
    end)
end
auxiliaryConnections[#auxiliaryConnections+1]=player.Idled:Connect(function()
    if not states.antiAfk then return end
    local ok,err=pcall(function()
        local virtualUser=game:GetService("VirtualUser")
        virtualUser:CaptureController()
        local camera=workspace.CurrentCamera
        local cf=camera and camera.CFrame or CFrame.new()
        virtualUser:Button2Down(Vector2.new(0,0),cf)
        task.wait(0.05)
        virtualUser:Button2Up(Vector2.new(0,0),cf)
    end)
    report(ok and "Anti-idle input sent" or "Anti-idle unavailable: "..tostring(err))
end)
local ui={}
function ui.page(name)
    local frame=make("ScrollingFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
        BorderSizePixel=0,ScrollBarThickness=2,ScrollBarImageColor3=blue,
        AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),Visible=false},content)
    make("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},frame)
    pages[name]=frame
    return frame
end
function ui.text(container,text)
    return make("TextLabel",{Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,Text=text,TextWrapped=true,TextSize=10,
        TextColor3=Color3.fromRGB(156,175,198),Font=Enum.Font.BuilderSans,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top},container)
end
function ui.group(container,name)
    local frame=make("Frame",{Size=UDim2.new(1,-5,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=Color3.fromRGB(16,23,34),BorderSizePixel=0},container)
    corner(frame,8)
    make("UIStroke",{Color=Color3.fromRGB(37,64,96),Thickness=1},frame)
    make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,0)},frame)
    local header=make("TextButton",{LayoutOrder=0,Size=UDim2.new(1,0,0,31),
        BackgroundTransparency=1,Text="  "..name,TextXAlignment=Enum.TextXAlignment.Left,
        TextColor3=white,TextSize=11,Font=Enum.Font.BuilderSansBold},frame)
    local arrow=make("TextLabel",{Position=UDim2.new(1,-26,0,0),Size=UDim2.fromOffset(23,31),
        BackgroundTransparency=1,Text="›",TextColor3=blue,TextSize=19,Font=Enum.Font.BuilderSans},header)
    local body=make("Frame",{LayoutOrder=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,Visible=false},frame)
    make("UIPadding",{PaddingLeft=UDim.new(0,7),PaddingRight=UDim.new(0,7),
        PaddingTop=UDim.new(0,3),PaddingBottom=UDim.new(0,7)},body)
    make("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},body)
    header.Activated:Connect(function()
        body.Visible=not body.Visible
        arrow.Text=body.Visible and "⌄" or "›"
    end)
    return body
end
function ui.dispatch(key)
    if key=="seeds" or key=="normalSeeds" or key=="gears" or key=="harvest" then runAutomation(key)
    elseif key=="LuckyCharm" or key=="RainbowDew" then startItem(key)
    elseif key=="wood" then startChop()
    elseif key=="tend" then startTend()
    elseif key=="water" then startWater()
    elseif key=="fairy" then startFairy()
    elseif key=="candyFairy" then startCandyFairy()
    elseif key=="pickups" or key=="fishing" or key=="sellBoom" or key=="houseUpgrade" or key=="gardenUpgrade" then startActivity(key)
    elseif key=="dust" then
        if states.dust and not states.harvest then states.harvest=true renderToggle.harvest() runAutomation("harvest") end
        startDust()
    end
end
function ui.toggle(container,label,key,default)
    states[key]=default==true
    local row=make("TextButton",{Size=UDim2.new(1,0,0,29),Text="",BorderSizePixel=0,
        BackgroundColor3=Color3.fromRGB(21,30,43)},container)
    corner(row,5)
    make("TextLabel",{Position=UDim2.fromOffset(7,0),Size=UDim2.new(1,-53,1,0),
        BackgroundTransparency=1,Text=label,TextColor3=white,TextSize=10,TextWrapped=true,
        Font=Enum.Font.BuilderSans,TextXAlignment=Enum.TextXAlignment.Left},row)
    local track=make("Frame",{Position=UDim2.new(1,-37,0.5,-7),Size=UDim2.fromOffset(29,14),
        BackgroundColor3=Color3.fromRGB(47,59,75),BorderSizePixel=0},row)
    corner(track,8)
    local knob=make("Frame",{Position=UDim2.fromOffset(2,2),Size=UDim2.fromOffset(10,10),
        BackgroundColor3=white,BorderSizePixel=0},track)
    corner(knob,8)
    renderToggle[key]=function()
        track.BackgroundColor3=states[key] and blue or Color3.fromRGB(47,59,75)
        knob.Position=UDim2.fromOffset(states[key] and 17 or 2,2)
    end
    renderToggle[key]()
    row.Activated:Connect(function()
        states[key]=not states[key]
        renderToggle[key]()
        ui.dispatch(key)
        configChanged(key=="autoSave")
    end)
end
function ui.button(container,label,callback)
    local button=make("TextButton",{Size=UDim2.new(1,0,0,28),Text=label,TextSize=10,
        TextColor3=white,Font=Enum.Font.BuilderSans,BackgroundColor3=Color3.fromRGB(23,45,71),BorderSizePixel=0},container)
    corner(button,5)
    button.Activated:Connect(function()
        local ok,err=pcall(callback)
        if not ok then report(tostring(err)) end
    end)
    return button
end
function ui.number(container,value,minimum,maximum,onChange)
    local input=make("TextBox",{Size=UDim2.new(1,0,0,27),Text=tostring(value),ClearTextOnFocus=false,
        TextSize=10,TextColor3=white,Font=Enum.Font.Code,BackgroundColor3=Color3.fromRGB(13,20,30),BorderSizePixel=0},container)
    corner(input,5)
    input.FocusLost:Connect(function()
        local n=tonumber(input.Text)
        if n and n==n and math.abs(n)<math.huge then
            value=math.clamp(math.floor(n+0.5),minimum,maximum)
            onChange(value)
            configChanged()
        end
        input.Text=tostring(value)
    end)
    return input
end
local config={path="hardinero_"..player.UserId.."_"..game.PlaceId..".json",loading=false,pending=nil,numbers={}}
function config.status(message)
    report(message)
    if config.label then config.label.Text=message end
end
function config.snapshot()
    local toggles={}
    for key,value in pairs(states) do if type(value)=="boolean" then toggles[key]=value end end
    local timers={}
    for _,item in ipairs(itemIds) do timers[item]=deadline(item) end
    return {version=1,userId=player.UserId,placeId=game.PlaceId,toggles=toggles,
        options={bedDelay=BED_DELAY,chopHits=chopHits,chopMode=chopMode,returnMode=returnMode,
            savedCenter=savedCenter and {savedCenter:GetComponents()} or nil},timers=timers}
end
function config.save()
    if type(writefile)~="function" then config.status("Saving unavailable: executor writefile is missing") return false end
    local ok,err=pcall(function() writefile(config.path,HttpService:JSONEncode(config.snapshot())) end)
    config.status(ok and "Config saved" or "Save failed: "..tostring(err))
    return ok
end
function config.validNumber(value,minimum,maximum)
    return type(value)=="number" and value==value and value>=minimum and value<=maximum
end
function config.apply(data)
    assert(type(data)=="table" and data.version==1,"Unsupported config format")
    assert(data.userId==player.UserId and data.placeId==game.PlaceId,"Config belongs to a different player or place")
    assert(type(data.toggles)=="table","Config toggle list is missing")
    config.loading=true
    stopAll()
    -- Restore every selection before starting any automation worker.
    for key,value in pairs(data.toggles) do
        if renderToggle[key] and type(value)=="boolean" then states[key]=value end
    end
    local options=type(data.options)=="table" and data.options or {}
    if config.validNumber(options.bedDelay,0.05,5) then BED_DELAY=options.bedDelay end
    if config.validNumber(options.chopHits,1,6) then chopHits=math.floor(options.chopHits) end
    if options.chopMode=="Walk" or options.chopMode=="Teleport" then chopMode=options.chopMode end
    if options.returnMode=="Previous" or options.returnMode=="Bed center" or options.returnMode=="Bed_6_5" then returnMode=options.returnMode end
    if type(options.savedCenter)=="table" and #options.savedCenter==12 then
        local valid=true
        for _,value in ipairs(options.savedCenter) do if not config.validNumber(value,-10000000,10000000) then valid=false break end end
        if valid then savedCenter=CFrame.new(table.unpack(options.savedCenter)) end
    end
    local timers=type(data.timers)=="table" and data.timers or {}
    local now=workspace:GetServerTimeNow()
    for _,item in ipairs(itemIds) do
        if config.validNumber(timers[item],0,now+cooldown+1) then parent:SetAttribute("HardineroNext_"..item,timers[item]) end
    end
    for _,render in pairs(renderToggle) do render() end
    if config.numbers.delay then config.numbers.delay.Text=tostring(math.floor(BED_DELAY*1000)) end
    if config.numbers.hits then config.numbers.hits.Text=tostring(chopHits) end
    for _,key in ipairs({"harvest","water","dust","seeds","normalSeeds","gears","tend","LuckyCharm","RainbowDew","fairy","candyFairy","sellBoom","houseUpgrade","gardenUpgrade","pickups","wood","fishing"}) do
        if states[key] then ui.dispatch(key) end
    end
    config.loading=false
end
function config.load()
    if type(readfile)~="function" then config.status("Loading unavailable: executor readfile is missing") return false end
    if type(isfile)=="function" and not isfile(config.path) then config.status("No saved config yet; changes will auto-save") return false end
    local ok,err=pcall(function() config.apply(HttpService:JSONDecode(readfile(config.path))) end)
    config.loading=false
    config.status(ok and "Saved config restored" or "Load failed: "..tostring(err))
    return ok
end
configChanged=function(force)
    if config.loading or (not force and states.autoSave==false) then return end
    if config.pending then task.cancel(config.pending) end
    config.pending=task.delay(0.4,function()
        config.pending=nil
        if alive then config.save() end
    end)
end
-- Main contains the actual farming grind, with no duplicate navigation rows.
ui.main=ui.page("Main")
ui.harvest=ui.group(ui.main,"Harvest")
ui.toggle(ui.harvest,"Auto Harvest","harvest")
ui.toggle(ui.harvest,"Ripe crops only","ripeOnly",true)
ui.text(ui.harvest,"Stock buying has top priority. Harvest pauses at the next bed check for shop trips, then resumes and returns to your beds when needed.")
ui.text(ui.harvest,"Delay between bed checks, in milliseconds (50–5000).")
config.numbers.delay=ui.number(ui.harvest,BED_DELAY*1000,50,5000,function(n) BED_DELAY=n/1000 end)
harvestProgress=ui.text(ui.harvest,"Harvest: OFF")
ui.dust=ui.group(ui.main,"Fairy Dust")
ui.toggle(ui.dust,"Use when zero crops are ripe","dust")
ui.text(ui.dust,"Starts Auto Harvest. Checks every second for zero ripe beds and at least one growing crop. Waits for server crop updates after using dust.")
dustStatus=ui.text(ui.dust,"Fairy Dust requests: 0")
ui.water=ui.group(ui.main,"Watering")
ui.toggle(ui.water,"Auto Water","water")
ui.text(ui.water,"Waters your own beds when NeedsWater appears.")
ui.returns=ui.group(ui.main,"Optional returns")
ui.toggle(ui.returns,"Return after shopping","returnAfterBuy")
ui.toggle(ui.returns,"Return when ripe and away","ripeReturn")
ui.text(ui.returns,"Both start OFF. Crop return requires Auto Harvest and only teleports if you are outside your beds.")
ui.button(ui.main,"STOP ALL",stopAll)
ui.seedPage=ui.page("Seeds")
ui.seedDiagnostics=ui.group(ui.seedPage,"Shop diagnostics")
ui.text(ui.seedDiagnostics,"Separate logs for Normal and Special Seeds. Updated automatically during shop visits; no purchases are triggered by opening diagnostics.")
for _,entry in ipairs({{key="normalSeeds",name="Normal Seeds"},{key="seeds",name="Special Seeds"}}) do
    local body=ui.group(ui.seedDiagnostics,entry.name.." diagnostics")
    seedStatus[entry.key]=ui.text(body,"No seed visit recorded yet")
    ui.text(body,"Latest server reply")
    seedDiagnostics.labels[entry.key]=ui.text(body,"No reply yet")
    ui.button(body,"Copy diagnostics",function()
        local output=entry.name.."\n"..table.concat(seedDiagnostics.logs[entry.key],"\n")
            .."\n\n"..(seedDiagnostics.replies[entry.key] or "No reply yet")
        if type(setclipboard)=="function" then setclipboard(output) report("Seed diagnostics copied")
        else report("Clipboard function unavailable; diagnostics remain visible here") end
    end)
    ui.button(body,"Clear log",function()
        seedDiagnostics.logs[entry.key]={}
        seedDiagnostics.replies[entry.key]=nil
        seedStatus[entry.key].Text="Log cleared"
        seedDiagnostics.labels[entry.key].Text="No reply yet"
    end)
end
ui.seedRoot=ui.group(ui.seedPage,"Seeds")
ui.normal=ui.group(ui.seedRoot,"Normal Seeds")
ui.toggle(ui.normal,"Auto Buy Normal Seeds","normalSeeds")
ui.text(ui.normal,"Buys selected Normal Seeds at the next restock, beside SeedKeeper, in the background.")
ui.special=ui.group(ui.seedRoot,"Special Seeds")
ui.toggle(ui.special,"Auto Buy Special Seeds","seeds")
ui.button(ui.special,"Buy selected Special Seeds now",function()
    if not states.seeds then report("Enable Auto Buy Special Seeds and select items first") return end
    if jobs.seedCheck then return end
    jobs.seedCheck=task.defer(function()
        if movement.acquire("seeds") then
            local ok,err=pcall(purchaseSeeds,"seeds")
            movement.release("seeds")
            if not ok then seedReport("seeds",tostring(err)) end
        end
        jobs.seedCheck=nil
    end)
end)
ui.text(ui.special,"Opens the offered Special Seeds page through NpcChoose before reading its choices and buying selected seeds.")
ui.config=getStockConfig()
ui.items=require(game:GetService("ReplicatedStorage").Shared.ItemConfig)
ui.specialSet={}
for _,id in ipairs(seedIds) do ui.specialSet[id]=true end
for id in pairs(ui.config.Seeds or {}) do
    if not ui.specialSet[id] then table.insert(normalIds,id) end
end
function ui.seedSort(a,b)
    local x,y=(ui.items.Crops[a] or {}).PackCost or math.huge,(ui.items.Crops[b] or {}).PackCost or math.huge
    if x~=y then return x<y end
    return a<b
end
table.sort(normalIds,ui.seedSort)
ui.specialSorted={}
for _,id in ipairs(seedIds) do table.insert(ui.specialSorted,id) end
table.sort(ui.specialSorted,ui.seedSort)
function ui.seedList(container,ids,prefix)
    for _,id in ipairs(ids) do
        local crop=ui.items.Crops[id] or {}
        local label=crop.DisplayName or id
        if crop.PackCost then label=label.." • "..crop.PackCost.." "..(crop.PackCurrency or "coins") end
        ui.toggle(container,label,prefix..id)
    end
end
ui.seedList(ui.normal,normalIds,"normal:")
ui.seedList(ui.special,ui.specialSorted,"seed:")
ui.gearPage=ui.page("Gears")
ui.gear=ui.group(ui.gearPage,"Gear buying")
ui.toggle(ui.gear,"Auto Buy Selected Gears","gears")
ui.text(ui.gear,"All four item selections start ON. Buys their available quantities at restock, without showing the shop menu.")
for _,id in ipairs(gearIds) do
    local info=ui.config.Gear[id] or {}
    ui.toggle(ui.gear,id.." • "..tostring(info.Coins or "?").." coins","gear:"..id,true)
end
shopStatus=ui.text(ui.gear,"Shop status: idle")
ui.gearDiagnostics=ui.group(ui.gearPage,"GearKeeper diagnostics")
restockLabel=ui.text(ui.gearDiagnostics,"Waiting for restock")
gearDiagnostics.statusLabel=ui.text(ui.gearDiagnostics,"No gear visit recorded yet")
gearDiagnostics.replyLabel=ui.text(ui.gearDiagnostics,"No GearKeeper reply yet")
ui.button(ui.gearDiagnostics,"Copy gear diagnostics",function()
    local output=table.concat(gearDiagnostics.log,"\n").."\n\n"..(gearDiagnostics.reply or "No reply yet")
    if type(setclipboard)=="function" then setclipboard(output) report("Gear diagnostics copied")
    else report("Clipboard function unavailable") end
end)
ui.button(ui.gearDiagnostics,"Clear gear log",function()
    gearDiagnostics.log={}
    gearDiagnostics.reply=nil
    gearDiagnostics.statusLabel.Text="Log cleared"
    gearDiagnostics.replyLabel.Text="No reply yet"
end)
ui.marketPage=ui.page("Market")
ui.market=ui.group(ui.marketPage,"Market Boom selling")
ui.toggle(ui.market,"Auto Sell during Market Boom","sellBoom")
ui.text(ui.market,"Waits for MarketBoom, visits Bram, and selects the offered sell-all-crops choice once during the active event.")
activityStatus.sellBoom=ui.text(ui.market,"Waiting for Market Boom")
ui.forestPage=ui.page("Forest")
ui.forest=ui.group(ui.forestPage,"Forest drops")
ui.toggle(ui.forest,"Auto Pick Up","pickups")
ui.text(ui.forest,"Watches visible Find_* objects in ForestFinds, teleports onto each drop and interacts or makes contact. Does not wait for a prompt to appear.")
activityStatus.pickups=ui.text(ui.forest,"Pickups: OFF")
ui.fishPage=ui.page("Fishing")
ui.fish=ui.group(ui.fishPage,"Lake fishing")
ui.toggle(ui.fish,"Auto Fish at the lake","fishing")
ui.text(ui.fish,"Uses only the lake Cast Line prompt. Queues another cast immediately after a catch, subject to server cooldown and higher-priority tasks.")
activityStatus.fishing=ui.text(ui.fish,"Lake fishing: OFF")
ui.treePage=ui.page("Trees")
ui.tree=ui.group(ui.treePage,"Chopping")
ui.toggle(ui.tree,"Auto Chop","wood")
ui.text(ui.tree,"Runs when the farm has zero ripe crops and no Fairy Dust. Chops one tree per turn and yields to harvest, dust, shops and forest collection.")
ui.button(ui.tree,"Change movement mode",function() chopMode=chopMode=="Teleport" and "Walk" or "Teleport" report("Tree movement: "..chopMode) configChanged() end)
ui.text(ui.tree,"Hits per tree (1–6).")
config.numbers.hits=ui.number(ui.tree,chopHits,1,6,function(n) chopHits=n end)
ui.treeTypes=ui.group(ui.tree,"Tree selections")
for _,name in ipairs({"Tree_Apple","Tree_Blossom","Tree_Pine","Tree_Round"}) do ui.toggle(ui.treeTypes,name,"tree:"..name,true) end
ui.upgradePage=ui.page("Upgrades")
ui.house=ui.group(ui.upgradePage,"House upgrades")
ui.toggle(ui.house,"Auto Upgrade House","houseUpgrade")
ui.text(ui.house,"Visits Carpenter and selects an offered house/cottage upgrade. Repeats while enabled and can spend your coins.")
activityStatus.houseUpgrade=ui.text(ui.house,"House upgrades: OFF")
ui.garden=ui.group(ui.upgradePage,"Garden upgrades")
ui.toggle(ui.garden,"Auto Upgrade Garden","gardenUpgrade")
ui.text(ui.garden,"Activates UpgradeFarm in your owned garden. Repeated upgrades can spend your coins.")
activityStatus.gardenUpgrade=ui.text(ui.garden,"Garden upgrades: OFF")
ui.timerPage=ui.page("Timers")
ui.animals=ui.group(ui.timerPage,"Animals")
ui.toggle(ui.animals,"Auto Tend Animals","tend")
ui.text(ui.animals,"Checks your owned animals every half-second and tends when an enabled CarePrompt needs attention. No five-minute timer.")
tendLabel=ui.text(ui.animals,"Animal tending: OFF")
ui.candyFairy=ui.group(ui.timerPage,"Candy for Fairy Dust")
ui.toggle(ui.candyFairy,"Auto Offer Candy to Fairies","candyFairy")
ui.text(ui.candyFairy,"Looks for fairies anywhere on the map. Selects only a returned menu offer explicitly naming Candy and Fairy Dust, and verifies both inventory changes.")
candyFairyLabel=ui.text(ui.candyFairy,"Candy trades: OFF")
ui.fairy=ui.group(ui.timerPage,"Fairy trading")
ui.toggle(ui.fairy,"Trade all Golden Acorns","fairy")
ui.text(ui.fairy,"Highest priority when the fairy appears and Golden Acorns are available. Finishes all confirmed acorn trades before releasing the task to shops, harvesting or other jobs.")
fairyLabel=ui.text(ui.fairy,"Fairy trading: OFF")
for _,item in ipairs(itemIds) do
    local body=ui.group(ui.timerPage,item)
    ui.toggle(body,"Auto "..item,item)
    ui.text(body,"Uses only during an active Auto Harvest turn, then waits ten minutes. Toggle each item independently; timers continue while harvesting is paused.")
    itemLabels[item]=ui.text(body,"Ready / OFF")
end
ui.travelPage=ui.page("Travel")
ui.travel=ui.group(ui.travelPage,"Travel destinations")
for _,destination in ipairs({"Seeds","Gear","Forest"}) do
    ui.button(ui.travel,"Travel to "..destination,function() stopAll() fire("Travel",destination) end)
end
ui.settingsPage=ui.page("Settings")
ui.config=ui.group(ui.settingsPage,"Saved config")
ui.toggle(ui.config,"Auto Save settings","autoSave",true)
ui.text(ui.config,"Saves toggles, seed/gear selections, speed, tree settings, return settings and item timers on this device. Run the loader after rejoining to restore and resume your enabled tasks.")
config.label=ui.text(ui.config,"Config ready")
ui.button(ui.config,"Save config now",config.save)
ui.button(ui.config,"Load saved config",config.load)
ui.queue=ui.group(ui.settingsPage,"Task priorities")
ui.text(ui.queue,"Priority: finish Golden Acorn fairy trades → restock stock buying → ripe harvest → Fairy Dust when zero are ripe → other tasks. With zero ripe crops and zero Fairy Dust, chopping and visible forest drops take turns. Other jobs share remaining time.")
ui.text(ui.queue,"An active tree, trade or cast finishes before the next turn. Timed item requests do not move your character.")
ui.diag=ui.group(ui.settingsPage,"Other NPC replies")
shopReplyLabel=ui.text(ui.diag,"Shop reply not captured yet")
ui.text(ui.diag,"StockConfig predicts initial quantities. Returned remaining stock takes priority; earlier manual purchases can reduce actual availability.")
ui.position=ui.group(ui.settingsPage,"Return destination")
ui.button(ui.position,"Cycle return destination",function()
    if returnMode=="Bed_6_5" then returnMode="Previous"
    elseif returnMode=="Previous" and savedCenter then returnMode="Bed center"
    else returnMode="Bed_6_5" end
    report("Return destination: "..returnMode)
    configChanged()
end)
ui.button(ui.position,"Save current position",function() savedCenter=currentPosition() report("Return position saved") configChanged() end)
ui.text(ui.position,"Enable a return toggle in Main to use this setting. Default destination is Bed_6_5.")
ui.antiAfk=ui.group(ui.settingsPage,"Anti AFK")
ui.toggle(ui.antiAfk,"Prevent Roblox idle disconnect","antiAfk")
ui.text(ui.antiAfk,"Responds to Roblox's idle event with a small input while this session is running. It cannot keep the app running if the phone suspends it.")
ui.safety=ui.group(ui.settingsPage,"Controls")
ui.text(ui.safety,"Drag the title bar, resize from the corner, or minimize to the H icon. Closing or Stop All stops the automation.")
ui.button(ui.safety,"STOP ALL",stopAll)
ui.selected=nil
selectPage=function(name)
    if ui.selected==name then content.Visible=not content.Visible return end
    ui.selected=name
    content.Visible=true
    pageTitle.Text=name
    for key,frame in pairs(pages) do frame.Visible=key==name end
    for key,button in pairs(tabs) do
        button.BackgroundColor3=key==name and Color3.fromRGB(23,45,71) or Color3.fromRGB(15,19,27)
        button.TextColor3=key==name and blue or white
    end
end
for index,name in ipairs({"Main","Seeds","Gears","Market","Forest","Fishing","Trees","Upgrades","Timers","Travel","Settings"}) do
    local button=make("TextButton",{Position=UDim2.fromOffset(5,4+(index-1)*27),
        Size=UDim2.new(1,-10,0,24),Text="  "..name,TextXAlignment=Enum.TextXAlignment.Left,
        BackgroundColor3=Color3.fromRGB(15,19,27),BorderSizePixel=0,TextColor3=white,
        Font=Enum.Font.BuilderSansMedium,TextSize=10},sidebar)
    corner(button,7)
    make("UIStroke",{Color=Color3.fromRGB(35,56,79),Thickness=1},button)
    tabs[name]=button
    button.Activated:Connect(function() selectPage(name) end)
end
local grip=make("TextButton", {AnchorPoint=Vector2.new(1,1),Position=UDim2.fromScale(1,1),
    Size=UDim2.fromOffset(30,28),BackgroundTransparency=1,Text="◢",TextColor3=blue,
    TextSize=22,Active=true},panel)
local icon=make("TextButton",{Name="OpenHardinero",Size=UDim2.fromOffset(52,52),
    Position=UDim2.fromOffset(12,90),BackgroundColor3=Color3.fromRGB(13,27,47),
    Text="H",TextColor3=blue,Font=Enum.Font.BuilderSansBold,TextSize=24,
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
local ripeSeen=setmetatable({},{__mode="k"})
local lastRipeTeleport=0
jobs.timerDisplay=task.defer(function()
    while alive do
        local now=workspace:GetServerTimeNow()
        if states.harvest and states.ripeReturn then
            local beds=ownedBeds()
            if beds then
                for _,bed in ipairs(beds:GetChildren()) do
                    local marker=bed:FindFirstChild("RipeSparkle")
                    if marker and ripeSeen[bed]~=marker then
                        ripeSeen[bed]=marker
                        ripeReturnPending=true
                    elseif not marker then ripeSeen[bed]=nil end
                end
            end
            if ripeReturnPending and not movement.owner and now-lastRipeTeleport>=2 then
                if tryRipeReturn() then lastRipeTeleport=now end
            end
        else ripeReturnPending=false end
        if restockLabel then
            local ok,seconds=pcall(function()
                local config=getStockConfig()
                return config.SecondsLeft(math.floor(now))
            end)
            restockLabel.Text=ok and ("Shop restock: %02d:%02d"):format(math.floor(seconds/60),seconds%60)
                or "StockConfig unavailable; see shop error"
        end
        if tendLabel then
            tendLabel.Text="Animals needing care: "..animalCare.needed..(states.tend and " / ON" or " / OFF")
        end
        for _,item in ipairs(itemIds) do
            local remaining=math.max(0,math.ceil(deadline(item)-now))
            local clock=remaining>0 and ("%02d:%02d"):format(math.floor(remaining/60),remaining%60) or "Ready"
            local mode=not states[item] and "OFF" or (states.harvest and movement.owner=="harvest" and "Harvest active" or "Waiting for harvest turn")
            itemLabels[item].Text=item.." • "..clock.." / "..mode
        end
        task.wait(0.25)
    end
end)
close.Activated:Connect(function() gui:Destroy() end)
gui.Destroying:Connect(function()
    if config.pending then task.cancel(config.pending) config.pending=nil end
    if states.autoSave then config.save() end
    alive=false
    stopAll()
    if jobs.timerDisplay then task.cancel(jobs.timerDisplay) end
    for _,connection in ipairs(auxiliaryConnections) do connection:Disconnect() end
    for _,connection in ipairs(connections) do connection:Disconnect() end
end)
selectPage("Main")
config.load()
