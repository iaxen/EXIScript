            math.clamp(startPos.X.Offset+delta.X,0,math.max(0,view.X-icon.AbsoluteSize.X)),
            math.clamp(startPos.Y.Offset+delta.Y,0,math.max(0,view.Y-icon.AbsoluteSize.Y)))
    elseif operation=="drag" then
        panel.Position=UDim2.fromOffset(
            math.clamp(startPos.X.Offset+delta.X,0,math.max(0,view.X-panel.AbsoluteSize.X)),
            math.clamp(startPos.Y.Offset+delta.Y,0,math.max(0,view.Y-panel.AbsoluteSize.Y)))
    else
        local maxW=math.max(1,view.X-panel.AbsolutePosition.X-8)
        local maxH=math.max(1,view.Y-panel.AbsolutePosition.Y-8)
        panel.Size=UDim2.fromOffset(math.clamp(startSize.X+delta.X,math.min(310,maxW),maxW),
            math.clamp(startSize.Y+delta.Y,math.min(210,maxH),maxH))
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
        math.clamp(icon.Position.X.Offset,0,math.max(0,view.X-icon.AbsoluteSize.X)),
        math.clamp(icon.Position.Y.Offset,0,math.max(0,view.Y-icon.AbsoluteSize.Y)))
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

        else ripeReturnPending=false end
        ui.bag.refresh()
        saleLimit.refresh()
        safeSales.refreshDetected()
        ui.boards.refresh()
        ui.events.refresh()
        dustCycle.status()
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
            buffs.reconcile(item)
            local remaining=math.max(0,math.ceil(deadline(item)-now))
            local clock=remaining>0 and ("%02d:%02d"):format(math.floor(remaining/60),remaining%60) or "Ready"
            local mode=not states[item] and "OFF" or (remaining>0 and "COOLDOWN" or
                (buffs.harvestReady() and "HARVESTING RIPE FRUIT" or "WAITING FOR A RIPE-FRUIT TAP"))
            itemLabels[item].Text=item.." • "..clock.." / "..mode
        end
        task.wait(0.25)
    end
end)
jobs.watchdog=task.defer(function()
    while alive do
        task.wait(5)
        for _,key in ipairs({"harvest","plant","water","dust","seeds","normalSeeds","gears","tend","LuckyCharm","RainbowDew","fairy","candyFairy","sellBoom","houseUpgrade","gardenUpgrade","pickups","wood","fishing","quest","orders","mayor","dig","rearrange"}) do
            local worker=(key=="seeds" or key=="normalSeeds" or key=="gears") and "buyer" or key
            if states[key] and (not jobs[worker] or coroutine.status(jobs[worker])=="dead") then
                movement.release(worker)
                jobs[worker]=nil
                local ok,err=pcall(ui.dispatch,key)
                if not ok then report(key.." retry: "..tostring(err)) end
            end
        end
    end
end)
close.Activated:Connect(function() gui:Destroy() end)
gui.Destroying:Connect(function()
    if config.pending then task.cancel(config.pending) config.pending=nil end
    if states.autoSave then config.save() end
    alive=false
    ui.layout.clearPreview()
    stopAll()
    if jobs.reconnectMonitor then task.cancel(jobs.reconnectMonitor) end
    if jobs.watchdog then task.cancel(jobs.watchdog) end
    if jobs.timerDisplay then task.cancel(jobs.timerDisplay) end
    for _,connection in ipairs(auxiliaryConnections) do connection:Disconnect() end
    for _,connection in ipairs(connections) do connection:Disconnect() end
end)
selectPage("Main")
config.load()

