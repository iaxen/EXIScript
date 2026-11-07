-- EXIScript universal loader. Each game is maintained in its own file.
local BUILD="20261107-startup-3"
local RS=game:GetService("ReplicatedStorage")
local BASE="https://raw.githubusercontent.com/iaxen/EXIS_Games/main/"
local boot,label
local function status(message,failed)
    warn("EXIScript ["..BUILD.."] "..message)
    if label and label.Parent then
        label.Text="EXIS | "..BUILD.."\n"..message
        label.TextColor3=failed and Color3.fromRGB(255,130,130) or Color3.fromRGB(80,160,255)
    end
end
pcall(function()
    local player=game:GetService("Players").LocalPlayer
    local parent=player and player:WaitForChild("PlayerGui",10)
    if not parent then return end
    local old=parent:FindFirstChild("EXISLoaderStatus")
    if old then old:Destroy()end
    boot=Instance.new("ScreenGui");boot.Name="EXISLoaderStatus";boot.ResetOnSpawn=false;boot.DisplayOrder=2147483646;boot.Parent=parent
    label=Instance.new("TextLabel");label.Size=UDim2.fromOffset(360,125);label.Position=UDim2.new(.5,-180,.5,-62)
    label.BackgroundColor3=Color3.fromRGB(8,12,18);label.TextWrapped=true;label.TextSize=13;label.Parent=boot
    local close=Instance.new("TextButton");close.Size=UDim2.fromOffset(24,24);close.Position=UDim2.new(.5,155,.5,-62);close.Text="×";close.Parent=boot
    close.Activated:Connect(function()boot:Destroy()end)
end)
status("Waiting for Roblox to load…")
local loadedAt=os.clock()
while not game:IsLoaded() and os.clock()-loadedAt<30 do task.wait(.1)end
if not game:IsLoaded()then status("Roblox did not finish loading in 30 seconds. Re-execute after joining.",true);return false end
if type(loadstring)~="function"then status("loadstring is unavailable in this client environment.",true);return false end
local routes={
    {
        name="Steal an Egg",file="Games/StealAnEgg.lua",
        placeIds={[107778070777162]=true},
        detect=function()
            local client=RS:FindFirstChild("Client")
            local shared=RS:FindFirstChild("Shared")
            return client and client:FindFirstChild("EggState")~=nil
                and client:FindFirstChild("PlotState")~=nil
                and shared and shared:FindFirstChild("Remotes")~=nil
        end,
    },
    {
        name="ZombieRushSurvival",file="Games/ZombieRushSurvival.lua",
        placeIds={[82457571485380]=true,[87413622775071]=true},
    },
    {
        name="MrbeastIslandEscape",file="Games/MrbeastIslandEscape.lua",
        placeIds={[108645230905176]=true},
        detect=function()
            local engine=RS:FindFirstChild("Engine")
            local service=engine and engine:FindFirstChild("Service")
            return service and service:FindFirstChild("MrbeastQuest")~=nil
        end,
    },
    {
        name="Fuzzotopia: Cozy Hideaway",file="Games/Fuzzotopia.lua",
        detect=function()return RS:FindFirstChild("CozyVillageRemotes")~=nil end,
    },
}
local function selectRoute()
    for _,route in ipairs(routes) do
        if route.placeIds and route.placeIds[game.PlaceId] then return route end
        if route.gameIds and route.gameIds[game.GameId] then return route end
    end
    for _,route in ipairs(routes) do if route.detect and route.detect() then return route end end
end
status("Detecting game • Place "..game.PlaceId.." • Game "..game.GameId)
local route=selectRoute()
local started=os.clock()
while not route and os.clock()-started<20 do
    task.wait(0.25)
    route=selectRoute()
end
if not route then
    status("Unsupported game or native services not loaded. PlaceId="..game.PlaceId.." GameId="..game.GameId,true)
    return false
end
local url=BASE..route.file.."?exis="..BUILD.."-"..tostring(os.time())
status("Downloading "..route.name.."…")
local ok,source=pcall(function()return game:HttpGet(url)end)
if not ok or type(source)~="string" or source=="" then
    status("Download failed for "..route.name..": "..tostring(source),true)
    return false
end
status("Compiling "..route.name.." • "..#source.." bytes")
local compileOK,compiled,compileError=pcall(loadstring,source,"EXIScript/"..route.name)
if not compileOK or type(compiled)~="function" then
    status("Compile failed: "..tostring(compileOK and compileError or compiled),true)
    return false
end
status("Starting "..route.name.."…")
local success,result,runtimeError=pcall(compiled)
if not success or result==false then
    status("Startup failed for "..route.name..": "..tostring(success and runtimeError or result),true)
    return false
end
status(route.name.." launched. Enable its Master switch to start automation.")
if boot then boot:Destroy()end
return true
