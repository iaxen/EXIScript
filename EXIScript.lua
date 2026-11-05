-- EXIScript universal loader. Each game is maintained in its own file.
if not game:IsLoaded() then game.Loaded:Wait() end
local RS=game:GetService("ReplicatedStorage")
local BASE="https://raw.githubusercontent.com/iaxen/EXIS/main/"
local routes={
    {
        name="MrBeast Island Escape",file="Games/IslandEscape.lua",
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
local route=selectRoute()
local started=os.clock()
while not route and os.clock()-started<20 do
    task.wait(0.25)
    route=selectRoute()
end
if not route then
    warn("EXIScript: unsupported game or game services not loaded. PlaceId="..game.PlaceId.." GameId="..game.GameId)
    return
end
local ok,source=pcall(function()return game:HttpGet(BASE..route.file)end)
if not ok or type(source)~="string" or source=="" then
    warn("EXIScript: failed to download "..route.name..". Check the repository paths and connection.")
    return
end
local compiled,compileError=loadstring(source,"EXIScript/"..route.name)
if not compiled then warn("EXIScript: "..tostring(compileError));return end
local success,runtimeError=pcall(compiled)
if not success then warn("EXIScript: "..route.name..": "..tostring(runtimeError)) end
