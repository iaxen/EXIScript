local source=assert(io.open('EXIScript.lua')):read('*a')
local fetched
local function run(place,modules)
 fetched=nil
 local rs={FindFirstChild=function(_,name)return modules and modules[name]end}
 game={PlaceId=place,GameId=0,IsLoaded=function()return true end,GetService=function()return rs end,
  HttpGet=function(_,url)fetched=url;return '_G.EXIS_LOADER_TEST_STARTED=true'end}
 loadstring=load;task={wait=function()error('unexpected wait for supported route')end};warn=function(message)error(message)end
 _G.EXIS_LOADER_TEST_STARTED=false
 assert(load(source))()
 assert(_G.EXIS_LOADER_TEST_STARTED)
 return fetched
end
assert(run(107778070777162):find('Games/StealAnEgg.lua',1,true));print('PASS Steal an Egg place route executes the correct file')
local node={FindFirstChild=function(_,name)return name=='EggState'or name=='PlotState'or name=='Remotes'end}
assert(run(0,{Client=node,Shared=node}):find('Games/StealAnEgg.lua',1,true));print('PASS native module detection supports alternate places')
assert(run(82457571485380):find('Games/ZombieRushSurvival.lua',1,true));print('PASS ZombieRush route is preserved')
assert(run(108645230905176):find('Games/MrbeastIslandEscape.lua',1,true));print('PASS MrBeast route is preserved')
assert(run(0,{CozyVillageRemotes={}}):find('Games/Fuzzotopia.lua',1,true));print('PASS Fuzzotopia detection is preserved')
print('5 universal loader execution checks passed')
