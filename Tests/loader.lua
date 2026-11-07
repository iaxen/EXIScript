local source=assert(io.open('EXIScript.lua')):read('*a')
local fetched
local logs={}
local function run(place,modules)
 fetched=nil
 local rs={FindFirstChild=function(_,name)return modules and modules[name]end}
 game={PlaceId=place,GameId=0,IsLoaded=function()return true end,GetService=function()return rs end,
  HttpGet=function(_,url)fetched=url;return '_G.EXIS_LOADER_TEST_STARTED=true'end}
 loadstring=load;task={wait=function()error('unexpected wait for supported route')end};warn=function(message)logs[#logs+1]=message end
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
print('PASS downloads include a revision and freshness query')
assert(fetched:find('?exis=',1,true))
local function failingSource(text)
 logs={};game.PlaceId=107778070777162;game.HttpGet=function()return text end
 local result=assert(load(source))()
 assert(result==false)
 return table.concat(logs,'\n')
end
assert(failingSource("return false, 'native adapter missing'"):find('native adapter missing',1,true))
print('PASS a caught game startup failure is reported instead of launched')
assert(failingSource('this is not valid Lua!'):find('Compile failed',1,true))
print('PASS compile failures are reported with their stage')
assert(failingSource(''):find('Download failed',1,true))
print('PASS empty downloads are rejected before compilation')
local previous=game.HttpGet;game.HttpGet=function()error('network unavailable')end
assert(assert(load(source))()==false and table.concat(logs,'\n'):find('network unavailable',1,true))
game.HttpGet=previous
print('PASS thrown download failures retain the actual network error')
print('10 universal loader execution and failure reporting checks passed')
