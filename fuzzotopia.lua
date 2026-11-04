-- HARDINERO: calls supplied by the user; server behavior is not verified.
-- Seed calls follow the one-string payload shown in the user's Cobalt capture.
local SEED_PREFIX = "seeds#"
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
local width = math.min(520, viewport.X - 24)
local height = math.min(340, viewport.Y - 24)
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
    CanvasSize=UDim2.fromOffset(0,255),ScrollBarThickness=2,
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
    return invoke("NpcChoose","SeedKeeper, "..choice)
end
local function enabled(key)
    return alive and states[key]
end
local shopping=false
local fairyBusy=false
local fairyCleanup=function() end
local chopBusy=false
local stopWalking=function() end
local function stop(key)
    states[key]=false
    if key=="fairy" then fairyCleanup() end
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
local tendLabel=nil
local function startTend()
    if not states.tend then stop("tend") return end
    if jobs.tend then return end
    jobs.tend=task.defer(function()
        while enabled("tend") do
            local nextTime=parent:GetAttribute("HardineroNextTend") or 0
            if workspace:GetServerTimeNow()>=nextTime then
                local ok,err=pcall(fire,"FarmAction","tend")
                if not ok then
                    states.tend=false
                    if renderToggle.tend then renderToggle.tend() end
                    if tendLabel then tendLabel.Text="Tend error: "..tostring(err) end
                    report("Tend error: "..tostring(err))
                    break
                end
                parent:SetAttribute("HardineroNextTend",workspace:GetServerTimeNow()+300)
                report("Animal tending requested")
            end
            task.wait(0.25)
        end
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
    for _,key in ipairs({"seeds","normalSeeds","gears","harvest","dust","LuckyCharm","RainbowDew","wood","tend","water","ripeReturn","returnAfterBuy","fairy"}) do stop(key) end
    local buyer=jobs.buyer
    jobs.buyer=nil
    if buyer and coroutine.status(buyer)~="dead" then task.cancel(buyer) end
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
local HttpService=game:GetService("HttpService")
local shopReplyLabel=nil
local function showShopReply(keeper,reply)
    local ok,encoded=pcall(function() return HttpService:JSONEncode(reply) end)
    local message=keeper.." reply: "..(ok and encoded or tostring(reply))
    if shopReplyLabel then shopReplyLabel.Text=message:sub(1,1800) end
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
    return "HardineroStockV3_"..kind.."_"..id
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
local restockLabel=nil
local function purchaseVisit(key)
    local ids=key=="seeds" and seedIds or (key=="normalSeeds" and normalIds or gearIds)
    local prefix=key=="seeds" and "seed:" or (key=="normalSeeds" and "normal:" or "gear:")
    if not enabled(key) or not hasSelection(ids,prefix) then return end
    local kind=key=="gears" and "Gear" or "Seeds"
    local window=stockWindow()
    -- StockConfig is indexed by verified crop IDs, including the premium crops.
    local predicted=calculatedStock(kind,ids,window)
    local availableSelection=false
    for _,id in ipairs(ids) do
        if states[prefix..id] and predicted and predicted[id]>0 then availableSelection=true break end
    end
    if not availableSelection then
        shopReport("No selected "..key.." left in calculated lineup; waiting for restock")
        return
    end
    local keeper=key=="gears" and "GearKeeper" or "SeedKeeper"
    if not enabled(key) or not approachKeeper(key,keeper) then return end
    shopReport("Reading shop data in background: "..keeper)
    local reply=checkedInvoke("NpcOpen",keeper)
    showShopReply(keeper,reply)
    assert(type(reply)=="table","NpcOpen returned no menu; approach the keeper more closely")
    local stock=extractStock(reply)
    local menu=reply
    task.wait(0.25)
    if not enabled(key) then return end
    if key=="seeds" then
        shopReport("Reading Special Seeds in background")
        -- GameHUD confirms NpcChoose(keeperId, optionId).
        local response=checkedInvoke("NpcChoose","SeedKeeper, page_special")
        showShopReply(keeper,response)
        stock=extractStock(response) or stock
        menu=response
        task.wait(0.15)
    elseif key=="normalSeeds" then
        -- Default menu may already list normal seeds; follow an offered normal page if present.
        for _,option in ipairs(type(menu)=="table" and menu.Options or {}) do
            local text=tostring(option.Text or ""):lower()
            if type(option.Id)=="string" and (option.Id=="page_normal" or text:find("normal seeds",1,true)) then
                menu=checkedInvoke("NpcChoose","SeedKeeper",option.Id)
                showShopReply(keeper,menu)
                stock=extractStock(menu) or stock
                break
            end
        end
    end
    if stockWindow()~=window then
        shopReport("Restock changed during travel; recalculating next round")
        return
    end
    -- Explicit remaining stock takes priority. Otherwise use initial lineup
    -- minus this script's own request count; earlier/manual purchases are unknown.
    local liveStock=stock~=nil
    stock=stock or predicted
    if not stock then
        stop(key)
        shopReport("Special Seeds stock is missing. Send the special-page reply from Settings.")
        return
    end
    for _,id in ipairs(ids) do
        if not enabled(key) then return end
        if states[prefix..id] then
            local available=stockCount(stock,id)
            if available==nil then
                shopReport("Unknown stock for "..id.."; skipped")
            else
                local count=available
                for attempt=1,count do
                    if not enabled(key) or not states[prefix..id] or stockWindow()~=window then break end
                    if not liveStock and requestsThisWindow(kind,id,window)>=(getStockConfig().Lineup(kind,window)[id] or 0) then break end
                    shopReport("Requesting "..id.." "..attempt.."/"..count)
                    local result
                    local choice=nil
                    local selectedOption=nil
                    local seedKey=SEED_PREFIX..id
                    local gearKey="stock_"..id
                    local candidates=key~="gears" and {
                        [seedKey]=true,["SeedKeeper, "..seedKey]=true,
                        ["seeds"..id]=true,["seeds_"..id]=true,["seed_"..id]=true
                    } or {[gearKey]=true}
                    for _,option in ipairs(type(menu)=="table" and menu.Options or {}) do
                        if candidates[option.Id] then choice=option.Id selectedOption=option break end
                    end
                    if not choice then
                        shopReport("Item not offered: "..id.."; see Shop reply in Settings")
                        break
                    end
                    local text=type(selectedOption.Text)=="string" and selectedOption.Text or ""
                    local left=tonumber(text:match("%((%d+) left%)"))
                    if left==0 or text:lower():find("sold out",1,true) then break end
                    recordRequest(kind,id,window)
                    if key=="seeds" then result=seedChoice(choice)
                    elseif key=="normalSeeds" then result=invoke("NpcChoose","SeedKeeper",choice)
                    else result=invoke("NpcChoose","GearKeeper",choice) end
                    if type(result)=="table" then menu=result end
                    if result==false then
                        -- Do not repeatedly request an item explicitly rejected in this window.
                        local stockKey=requestKey(kind,id)
                        if key=="gears" then parent:SetAttribute(stockKey.."_Count",getStockConfig().Lineup(kind,window)[id] or 0) end
                        break
                    end
                    task.wait(PURCHASE_DELAY)
                end
            end
        end
    end
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
                while alive and fairyBusy do task.wait(0.1) end
                if not alive then break end
                shopping=true
                while alive and chopBusy do task.wait(0.1) end
                if not alive then break end
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
                                if not ok then stop(key) shopReport("Shop error: "..tostring(err)) end
                            end
                        end
                    end
                    returnToPosition()
                else shopReport("Restock skipped • character unavailable") end
                shopping=false
            end
        end
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
local ripeMarkers=setmetatable({},{__mode="k"})
local function startWater()
    if not states.water then stop("water") return end
    if jobs.water then return end
    jobs.water=task.defer(function()
        local sent=setmetatable({},{__mode="k"})
        local ok,err=pcall(function()
            while enabled("water") do
                local beds=ownedBeds()
                if beds then
                    for _,bed in ipairs(beds:GetChildren()) do
                        if not enabled("water") then return end
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
                bedCount=0
                for row=1,11 do
                    for col=1,10 do
                        if not enabled("harvest") then return end
                        local bedId=("Bed_%d_%d"):format(row,col)
                        if states.ripeOnly then
                            local beds=ownedBeds()
                            local bed=beds and beds:FindFirstChild(bedId)
                            local marker=bed and bed:FindFirstChild("RipeSparkle")
                            if marker and ripeMarkers[bed]~=marker then
                                fire("FarmTap",bedId,nil)
                                ripeMarkers[bed]=marker
                            elseif bed and not marker then ripeMarkers[bed]=nil end
                        else fire("FarmTap",bedId,nil) end
                        bedCount=bedCount+1
                        if harvestProgress then harvestProgress.Text="Harvest round: "..bedCount.." / 110 beds checked" end
                        task.wait(BED_DELAY)
                    end
                end
                -- Use dust only after a full owned-bed scan finds no ripe crops.
                if enabled("harvest") and states.dust then
                    task.wait(0.5)
                    if not enabled("harvest") or not states.dust then return end
                    local beds=ownedBeds()
                    local hasRipe=false
                    if beds then
                        for _,bed in ipairs(beds:GetChildren()) do
                            if bed:FindFirstChild("RipeSparkle") then
                                hasRipe=true
                                break
                            end
                        end
                    end
                    if beds and not hasRipe then
                        local used,err=requestDust()
                        if not used then
                            states.dust=false
                            if renderToggle.dust then renderToggle.dust() end
                            report("Fairy Dust error: "..tostring(err))
                        else report("No ripe crops remain • Fairy Dust requested") end
                    elseif hasRipe then
                        report("Ripe crops remain • Fairy Dust waiting")
                    end
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
                        chopBusy=true
                        attempted[nearest]=os.clock()
                        local target,center=besideTree(nearest,root)
                        local arrived=target and moveToTree(target,center)
                        if arrived and not shopping then
                            for hit=1,chopHits do
                                if not enabled("wood") or shopping or nearest.Parent~=folder or nearest:GetAttribute("Felled") then break end
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
    fairyBusy=false
    shopping=false
end
local function findFairy()
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
            elseif not shopping and not chopBusy then
                fairyBusy=true
                shopping=true
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
local function page(name)
    local p=make("ScrollingFrame", {Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,
        ScrollBarImageColor3=blue,CanvasSize=UDim2.new(),
        AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false},content)
    make("UIListLayout", {Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},p)
    pages[name]=p
    return p
end
local function textRow(p,text)
    return make("TextLabel", {Size=UDim2.new(1,-8,0,40),BackgroundTransparency=1,
        Text=text,TextWrapped=true,TextColor3=Color3.fromRGB(145,160,181),
        Font=Enum.Font.BuilderSans,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left},p)
end
local function toggle(p,label,key)
    states[key]=false
    local row=make("TextButton", {Size=UDim2.new(1,-8,0,34),Text="",
        BackgroundColor3=Color3.fromRGB(20,26,36),BorderSizePixel=0},p)
    corner(row,3)
    make("UIStroke", {Color=Color3.fromRGB(43,53,69),Thickness=1},row)
    make("TextLabel", {Position=UDim2.fromOffset(13,0),Size=UDim2.new(1,-66,1,0),
        BackgroundTransparency=1,Text=label,TextColor3=white,Font=Enum.Font.BuilderSansMedium,
        TextSize=11,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left},row)
    local track=make("Frame", {Position=UDim2.new(1,-45,0.5,-8),
        Size=UDim2.fromOffset(32,16),BackgroundColor3=Color3.fromRGB(54,63,78),BorderSizePixel=0},row)
    corner(track,20)
    local knob=make("Frame", {Position=UDim2.fromOffset(2,2),Size=UDim2.fromOffset(12,12),
        BackgroundColor3=white,BorderSizePixel=0},track)
    corner(knob,20)
    row.Activated:Connect(function()
        states[key]=not states[key]
        renderToggle[key]()
        if key=="seeds" or key=="normalSeeds" or key=="gears" or key=="harvest" then runAutomation(key)
        elseif key=="LuckyCharm" or key=="RainbowDew" then startItem(key)
        elseif key=="wood" then startChop()
        elseif key=="tend" then startTend()
        elseif key=="water" then startWater()
        elseif key=="fairy" then startFairy()
        elseif key=="dust" and states.dust and not states.harvest then
            states.harvest=true
            renderToggle.harvest()
            runAutomation("harvest")
        end
    end)
    renderToggle[key]=function()
        row.BackgroundColor3=states[key] and Color3.fromRGB(19,34,52) or Color3.fromRGB(20,26,36)
        track.BackgroundColor3=states[key] and blue or Color3.fromRGB(54,63,78)
        knob.Position=UDim2.fromOffset(states[key] and 18 or 2,2)
    end
end
local function button(p,label,callback)
    local b=make("TextButton",{Size=UDim2.new(1,-8,0,32),Text=label,
        BackgroundColor3=Color3.fromRGB(23,45,71),TextColor3=white,
        Font=Enum.Font.BuilderSansMedium,TextSize=12,BorderSizePixel=0},p)
    corner(b,3)
    b.Activated:Connect(function()
        local ok,err=pcall(callback)
        if not ok then report("Error: "..tostring(err)) end
    end)
end
local farm=page("Farm")
textRow(farm,"Select items in Seeds / Gears first. Buying repeats and spends coins until stopped.")
textRow(farm,"Buys all selected stock available in the menu or calculated lineup. Shops teleport directly to NPC prompts; saved positions are ignored.")
shopStatus=textRow(farm,"Shop status: idle")
shopStatus.Size=UDim2.new(1,-8,0,65)

textRow(farm,"Harvest sends FarmTap to all 110 beds. Ripe-state detection is unavailable; other bed behavior is unverified.")
toggle(farm,"Auto Harvest","harvest")
toggle(farm,"Return after buying (optional)","returnAfterBuy")
toggle(farm,"Return if away when crops ripen","ripeReturn")
textRow(farm,"Both return options start OFF. Crop return requires Auto Harvest. Auto Buy waits for the next 5-minute restock before visiting shops.")
toggle(farm,"Only ripe beds (RipeSparkle)","ripeOnly")
toggle(farm,"Auto Water (NeedsWater)","water")
textRow(farm,"Ripe-only is optional; OFF keeps your full-bed tapping. Auto Water checks only your garden and sends one request per watering marker.")
textRow(farm,"Harvest delay in milliseconds: 50–5000. Lower = faster; 100 ms is the default.")
local delayInput=make("TextBox",{
    Size=UDim2.new(1,-8,0,38),BackgroundColor3=Color3.fromRGB(20,26,36),
    Text=tostring(BED_DELAY*1000),PlaceholderText="Delay in ms (50–5000)",
    ClearTextOnFocus=false,TextColor3=white,Font=Enum.Font.BuilderSans,
    TextSize=12,BorderSizePixel=0},farm)
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
textRow(farm,"Enabling Fairy Dust also starts harvesting. It waits until a full scan finds no ripe crops.")
harvestProgress=textRow(farm,"Harvest round: 0 / 110 taps")
dustStatus=textRow(farm,"Fairy Dust requests: 0")
button(farm,"Use Fairy Dust now (one request)",function()
    local ok,err=requestDust()
    if not ok then report("Fairy Dust error: "..tostring(err)) end
end)
textRow(farm,"Requests do not confirm consumption. If the manual button has no effect, capture UseItem again while manually using Fairy Dust.")
local itemsPage=page("Timers")
toggle(itemsPage,"Fairy: Golden Acorn → 3 dust","fairy")
fairyLabel=textRow(itemsPage,"Fairy: OFF")
textRow(itemsPage,"Trades all available Golden Acorns, verifying the inventory decreases after every trade. Teleports to her prompt and returns when finished.")
toggle(itemsPage,"Auto Tend Animals • 5 min","tend")
tendLabel=textRow(itemsPage,"Animal tending • Ready / OFF")
textRow(itemsPage,"Tends immediately when ready, then every 5 minutes. Turning OFF stops requests; the countdown is retained in this session.")
textRow(itemsPage,"Each item uses immediately when ready, then waits 10 minutes independently. OFF pauses use, not the clock.")
for _,item in ipairs(itemIds) do
    toggle(itemsPage,"Auto "..item,item)
    itemLabels[item]=textRow(itemsPage,item.." • Ready / OFF")
end
textRow(itemsPage,"Timers count from requests, not confirmed item effects. Missing inventory is not detected.")
local function sectionTitle(container,title)
    local label=textRow(container,title)
    label.TextColor3=blue
    label.Font=Enum.Font.BuilderSansBold
    label.TextSize=13
    return label
end
local function categoryBody(container)
    local frame=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1},container)
    make("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},frame)
    return frame
end
local configOK,uiConfig=pcall(getStockConfig)
local itemOK,itemConfig=pcall(function()
    return require(game:GetService("ReplicatedStorage").Shared.ItemConfig)
end)
local crops=itemOK and itemConfig.Crops or {}
local function cropLabel(id)
    local crop=crops[id]
    if not crop then return id.." • unverified ID" end
    local label=crop.DisplayName or id
    if type(crop.PackCost)=="number" then
        label=label.." • "..crop.PackCost.." "..(crop.PackCurrency or "coins")
        if crop.PackCount then label=label.." / "..crop.PackCount.." seeds" end
    else label=label.." • pack price unavailable" end
    return label
end
local seedPage=page("Seeds")
toggle(seedPage,"Auto Buy Special Seeds","seeds")
textRow(seedPage,"Select Special Seeds, then enable Auto Buy. Visits begin at the next restock.")
sectionTitle(seedPage,"SEED CATEGORIES")
textRow(seedPage,"Tap a category to expand or hide it. Each category has its own Auto Buy toggle. Select the seeds you want in that category.")
local normalBody
button(seedPage,"Normal Seeds • common → rare",function()
    normalBody.Visible=not normalBody.Visible
end)
normalBody=categoryBody(seedPage)
if configOK and type(uiConfig.Seeds)=="table" then
    local specialSet={}
    for _,id in ipairs(seedIds) do specialSet[id]=true end
    for id,entry in pairs(uiConfig.Seeds) do
        if not specialSet[id] and type(entry)=="table" and type(entry.Chance)=="number" then table.insert(normalIds,id) end
    end
    table.sort(normalIds,function(a,b)
        local x,y=uiConfig.Seeds[a],uiConfig.Seeds[b]
        if x.Chance~=y.Chance then return x.Chance>y.Chance end
        return a<b
    end)
    toggle(normalBody,"Auto Buy Normal Seeds","normalSeeds")
    textRow(normalBody,"Select seeds and enable Auto Buy. Visits begin at the next restock; rarest seeds are last.")
    for _,id in ipairs(normalIds) do
        local entry=uiConfig.Seeds[id]
        toggle(normalBody,("%s • %g%% • %d–%d stock"):format(
            id,entry.Chance*100,entry.Min,entry.Max),"normal:"..id)
    end
else
    textRow(normalBody,"Cannot read Normal Seeds from Shared.StockConfig in this session.")
end
normalBody.Visible=false
local specialBody
button(seedPage,"Special Seeds • price low → high",function()
    specialBody.Visible=not specialBody.Visible
end)
specialBody=categoryBody(seedPage)
textRow(specialBody,"Seed-pack costs and sizes from ItemConfig. Highest known prices last; missing prices listed after those.")
local sortedSpecial={}
for _,id in ipairs(seedIds) do table.insert(sortedSpecial,id) end
table.sort(sortedSpecial,function(a,b)
    local x,y=(crops[a] or {}).PackCost or math.huge,(crops[b] or {}).PackCost or math.huge
    if x~=y then return x<y end
    return a<b
end)
for _,id in ipairs(sortedSpecial) do toggle(specialBody,cropLabel(id),"seed:"..id) end
textRow(specialBody,"StarFruitTree was not found in the exported crop definitions; Starfruit is a verified ID.")
local gearPage=page("Gears")
toggle(gearPage,"Auto Buy Selected Gears","gears")
textRow(gearPage,"Select gears, then enable Auto Buy. Visits begin at the next restock.")
sectionTitle(gearPage,"GEARS • CHEAPEST → MOST EXPENSIVE")
textRow(gearPage,"Select gears for auto-buy. Prices and rarity come from StockConfig.")
local gearFallback={
    WateringBucket={Coins=300,Rarity="Common"},GrowthTonic={Coins=1500,Rarity="Uncommon"},
    LuckyCharm={Coins=5000,Rarity="Rare"},RainbowDew={Coins=25000,Rarity="Legendary"}}
local gearData=(configOK and uiConfig.Gear) or gearFallback
table.sort(gearIds,function(a,b)
    return (gearData[a] or gearFallback[a]).Coins<(gearData[b] or gearFallback[b]).Coins
end)
for _,id in ipairs(gearIds) do
    local info=gearData[id] or gearFallback[id]
    toggle(gearPage,id.." • "..info.Rarity.." • "..info.Coins.." coins","gear:"..id)
end
local treesPage=page("Trees")
textRow(treesPage,"Move beside matching trees and chop. Shops get movement priority; harvesting continues.")
toggle(treesPage,"Auto Chop","wood")
for _,name in ipairs({"Tree_Apple","Tree_Blossom","Tree_Pine","Tree_Round"}) do
    toggle(treesPage,name,"tree:"..name)
    states["tree:"..name]=true
    renderToggle["tree:"..name]()
end
local modeButton=make("TextButton",{Size=UDim2.new(1,-8,0,32),Text="Movement: Teleport",
    BackgroundColor3=Color3.fromRGB(23,45,71),TextColor3=white,
    Font=Enum.Font.BuilderSans,TextSize=12,BorderSizePixel=0},treesPage)
corner(modeButton,7)
modeButton.Activated:Connect(function()
    chopMode=chopMode=="Teleport" and "Walk" or "Teleport"
    modeButton.Text="Movement: "..chopMode
end)
textRow(treesPage,"Hits per tree: 1–6 (your axe: 1). If teleports fail, select Walk.")
local hitsInput=make("TextBox",{Size=UDim2.new(1,-8,0,38),Text="1",ClearTextOnFocus=false,
    BackgroundColor3=Color3.fromRGB(20,26,36),TextColor3=white,
    Font=Enum.Font.BuilderSans,TextSize=12,BorderSizePixel=0},treesPage)
corner(hitsInput,7)
hitsInput.FocusLost:Connect(function()
    local n=tonumber(hitsInput.Text)
    if n and n==n and math.abs(n)<math.huge then chopHits=math.clamp(math.floor(n),1,6) end
    hitsInput.Text=tostring(chopHits)
end)
textRow(treesPage,"Each tree is retried after at least 30 seconds. Trees marked Felled or not Choppable are skipped.")
local travelPage=page("Travel")
for _,destination in ipairs({"Seeds","Gear","Forest"}) do
    button(travelPage,"Travel to "..destination,function()
        stopAll()
        fire("Travel",destination)
        report("Travel requested: "..destination)
    end)
end
local settings=page("Settings")
textRow(settings,"Auto Buy teleports beside the keeper at restock and requests shop data and purchases in the background. The E prompt is not activated.")
restockLabel=textRow(settings,"Shop restock: loading")
textRow(settings,"Lineup predicts starting stock, not live remaining stock. Local request limits persist when rerunning here, but not after rejoining.")
shopReplyLabel=textRow(settings,"Shop reply: not captured yet")
shopReplyLabel.AutomaticSize=Enum.AutomaticSize.Y
shopReplyLabel.Size=UDim2.new(1,-8,0,80)

textRow(settings,"Drag header to move; corner to resize. Minimize becomes an icon; automation continues. X stops all.")
textRow(settings,"Harvest runs alongside buying. Shops share one queue; return after both visits.")
textRow(settings,"No stock / balance detection. A sent request does not confirm a successful purchase or harvest.")
textRow(settings,"Auto Chop is in Trees. Shop trips pause chopping movement; harvesting and item timers continue.")
local returnButton
returnButton=make("TextButton",{Size=UDim2.new(1,-8,0,32),
    Text="Return to: Bed_6_5 (teleport)",BackgroundColor3=Color3.fromRGB(23,45,71),
    TextColor3=white,Font=Enum.Font.BuilderSansMedium,TextSize=12,BorderSizePixel=0},settings)
corner(returnButton,7)
returnButton.Activated:Connect(function()
    if returnMode=="Bed_6_5" then returnMode="Previous"
    elseif returnMode=="Previous" then
        if not savedCenter then returnMode="Bed_6_5"
        else returnMode="Bed center" end
    else returnMode="Bed_6_5" end
    returnButton.Text="Return to: "..returnMode.." (teleport)"
end)

button(settings,"Save current position as bed center",function()
    local position=currentPosition()
    if not position then report("Character is unavailable") return end
    savedCenter=position
    report("Bed center saved for this session")
end)
textRow(settings,"Stand between your beds, save the center, then select Bed center. Previous position is captured before each buying round.")
textRow(settings,"Seed purchase requests use the one-string format from your Cobalt capture, with seeds# as the prefix.")
button(settings,"STOP ALL",stopAll)
selectPage=function(name)
    pageTitle.Text=name=="Farm" and "Farming" or name
    for key,p in pairs(pages) do p.Visible=key==name end
    for key,b in pairs(tabs) do
        b.BackgroundColor3=key==name and Color3.fromRGB(23,45,71) or Color3.fromRGB(15,19,27)
        b.TextColor3=key==name and blue or Color3.fromRGB(172,185,204)
        b.ActiveRail.Visible=key==name
    end
end
local home=page("Main")
local function navigationRow(label,target)
    local row=make("TextButton",{Size=UDim2.new(1,-8,0,30),Text="",AutoButtonColor=true,
        BackgroundColor3=Color3.fromRGB(25,33,43),BackgroundTransparency=0.15,BorderSizePixel=0},home)
    corner(row,2)
    make("TextLabel",{Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-33,1,0),
        BackgroundTransparency=1,Text=label,TextColor3=white,TextSize=11,
        Font=Enum.Font.BuilderSansBold,TextXAlignment=Enum.TextXAlignment.Left},row)
    make("TextLabel",{Position=UDim2.new(1,-24,0,0),Size=UDim2.fromOffset(20,30),
        BackgroundTransparency=1,Text="›",TextColor3=blue,TextSize=23,Font=Enum.Font.BuilderSans},row)
    row.Activated:Connect(function() selectPage(target) end)
end
navigationRow("Automation Farming","Farm")
navigationRow("Automation Seeds","Seeds")
navigationRow("Automation Gears","Gears")
navigationRow("Automation Items & Animals","Timers")
navigationRow("Automation Trees","Trees")
navigationRow("Travel","Travel")
navigationRow("Settings","Settings")
for i,name in ipairs({"Main","Seeds","Gears","Timers","Trees","Travel","Settings"}) do
    local b=make("TextButton", {Position=UDim2.fromOffset(5,4+(i-1)*27),
        Size=UDim2.new(1,-10,0,25),Text="   "..name,TextXAlignment=Enum.TextXAlignment.Left,
        TextColor3=white,Font=Enum.Font.BuilderSansMedium,TextSize=12,BorderSizePixel=0},sidebar)
    corner(b,6)
    make("Frame",{Name="ActiveRail",Position=UDim2.new(0,1,0.5,-7),Size=UDim2.fromOffset(2,14),
        BackgroundColor3=blue,BorderSizePixel=0,Visible=false},b)
    tabs[name]=b
    b.Activated:Connect(function() selectPage(name) end)
end
make("TextLabel", {Position=UDim2.fromOffset(10,210),Size=UDim2.new(1,-20,0,32),
    BackgroundTransparency=1,Text=player.DisplayName,TextTruncate=Enum.TextTruncate.AtEnd,
    TextColor3=Color3.fromRGB(140,157,180),Font=Enum.Font.BuilderSans,TextSize=12},sidebar)
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
            if ripeReturnPending and not shopping and not chopBusy and now-lastRipeTeleport>=2 then
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
            local left=math.max(0,math.ceil((parent:GetAttribute("HardineroNextTend") or 0)-now))
            local clock=left>0 and ("%02d:%02d"):format(math.floor(left/60),left%60) or "Ready"
            tendLabel.Text="Animal tending • "..clock..(states.tend and " / ON" or " / OFF")
        end
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
