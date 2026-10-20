import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import {execFileSync} from 'node:child_process';
const root=new URL('../',import.meta.url);const runtime=fs.readFileSync(new URL('runtime.lua',root),'utf8');const model=fs.readFileSync(new URL('daily.lua',root),'utf8');const html=fs.readFileSync(new URL('report.html',root),'utf8');
const integration=fs.readFileSync(new URL('masterp.lua',root),'utf8');
const q=s=>JSON.stringify(s);
function run(body){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'dice-daily-test-'));const file=path.join(dir,'test.luau');fs.writeFileSync(file,`
local now=100000;local files,docs={},{};local jsonId=0;local claims=0;local diskOK=true;local spawned;local labels={}
local cache={DailyRewardsClaimed=1,LastDailyRewardClaim=99000}
local config={Cooldown=82800,Rewards={1,2,3,4,5,6,7}}
local callback=function(...)assert(select('#',...)==0);assert(files['dice_daily_7_state.json'],'intent must be saved');claims+=1 end
local function signal()local s={};function s:Connect(fn)local c={};function c:Disconnect()end;return c end;return s end
local function object(name,children)local o={Name=name,children=children or{},Activated=signal()};function o:FindFirstChild(k)return self.children[k]end;function o:Destroy()end;return o end
local day=object('Day1');local days=object('Day1-6',{Day1=day});local dailyMenu=object('DailyRewards',{['Day1-6']=days})
local menus=object('Menus',{DailyRewards=dailyMenu});local gui=object('PlayerGui',{Root=object('Root',{Menus=menus})})
local player={UserId=7};function player:FindFirstChild(k)if k=='PlayerGui'then return gui end end
local http={JSONEncode=function(_,v)jsonId+=1;local raw='json:'..jsonId;docs[raw]=v;return raw end,JSONDecode=function(_,raw)return assert(docs[raw])end}
game={GameId=10708913337,IsLoaded=function()return true end,GetService=function(_,k)if k=='Players'then return{LocalPlayer=player}else return http end end}
workspace={GetServerTimeNow=function()return now end}
Instance={new=function(name)local o=object(name);if name=='TextLabel'then labels[#labels+1]=o end;return o end};Color3={fromRGB=function()return{}end};UDim2={fromOffset=function()return{}end,new=function()return{}end};UDim={new=function()return{}end};Enum={Font={Arial=1}}
task={wait=function()coroutine.yield()end,spawn=function(fn)spawned=coroutine.create(fn)end}
local oldTypeof=typeof;typeof=function(v)if type(v)=='table'and v.nativeInstance then return'Instance'end;return oldTypeof(v)end
local nativeRemote={nativeInstance=true,GetFullName=function()return'ReplicatedStorage.Network.DailyRewardService.RE.Claim'end}
local oldDebug=debug;debug=setmetatable({info=function(f,kind)assert(f==callback);if kind=='s'then return'ReplicatedStorage.Framework.Features.Rewards.DailyRewardController'else return 0,false end end,getupvalues=function()return{{_re=nativeRemote}}end},{__index=oldDebug})
getconnections=function()return{{Function=callback}}end
local exports={['ReplicatedStorage.Framework.Features.Data.DataController']={___X=cache},['ReplicatedStorage.Framework.Features.Rewards.DailyRewardConfig']=config}
local mods={};for name,v in pairs(exports)do mods[#mods+1]={GetFullName=function()return name end,value=v}end
getloadedmodules=function()return mods end;require=function(m)return m.value end
writefile=function(p,raw)if not diskOK then error('disk full')end;files[p]=raw end;readfile=function(p)return assert(files[p])end;isfile=function(p)return files[p]~=nil end
_G={}
local Daily=assert(loadstring(${q(model)}))();local fn=assert(loadstring(${q(runtime)}));setfenv(fn,getfenv())
local Masterp=assert(loadstring(${q(integration)}))()
local function launch()return fn(Daily,${q(html)},Masterp)end
${body}
print('RUNTIME PASS')
`);try{assert.match(execFileSync('luau',[file],{encoding:'utf8',timeout:10000}),/RUNTIME PASS/);}finally{fs.rmSync(dir,{recursive:true,force:true});}}
test('actual runtime exports a waiting schedule without claiming, and singleton reload stops old owner',()=>run(`local a=launch();assert(claims==0 and a.Status().nextAt==181800);assert(files['dice_daily_next_login.html']);local b=launch();assert(a~=b and claims==0);b.Stop()`));
test('actual runtime eligible callback fires once and remains unconfirmed until native data changes',()=>run(`cache.LastDailyRewardClaim=1000;local a=launch();assert(claims==1 and a.Status().claimed==1);local b=launch();assert(claims==1,'durable pending survives reload');b.Stop()`));
test('actual runtime never claims without a read-back schedule or in the wrong game',()=>run(`cache.LastDailyRewardClaim=1000;diskOK=false;local a=launch();assert(claims==0 and a.Status().reason:find('save_failed'));a.Stop();game.GameId=5578556129;assert(not pcall(launch));assert(claims==0)`));
test('after native claim acknowledgement panel and persistent text announce the new weekday/date/time',()=>run(`
now=1792453527;cache.LastDailyRewardClaim=1792370727;cache.DailyRewardsClaimed=1
local a=launch();assert(claims==1)
assert(coroutine.resume(spawned))
cache.DailyRewardsClaimed=2;cache.LastDailyRewardClaim=1792453527
assert(coroutine.resume(spawned))
assert(a.Status().reason=='claim_verified'and a.Status().nextAt==1792536327)
assert(labels[#labels].Text:find('วันที่ 3',1,true))
assert(labels[#labels].Text:find('วันพุธที่ 21 ตุลาคม 2569 เวลา 05:45:27',1,true))
assert(files['dice_daily_next_login.txt']:find('วันพุธที่ 21 ตุลาคม 2569 เวลา 05:45:27',1,true))
a.Stop()
`));
test('actual runtime calls Masterp_Done once only after receipt and next appointment are durably saved',()=>run(`
now=1792453527;cache.LastDailyRewardClaim=1792370727;cache.DailyRewardsClaimed=1
local done=0
_G.Masterp_Done=function(...)
 assert(select('#',...)==0)
 assert(files['dice_daily_next_login.txt']:find('วันพุธที่ 21 ตุลาคม 2569 เวลา 05:45:27',1,true))
 assert(docs[files['dice_daily_7_state.json']].masterpCompletion.phase=='dispatching')
 done+=1
end
local a=launch();assert(claims==1 and done==0,'request sent is not reward success')
assert(coroutine.resume(spawned));cache.DailyRewardsClaimed=2
assert(coroutine.resume(spawned));assert(done==0,'partial native replication is not reward success')
cache.LastDailyRewardClaim=1792453527
assert(coroutine.resume(spawned));assert(done==1 and a.Status().masterpCompletion.phase=='called')
local b=launch();assert(done==1,'reloading after Done does not report twice');b.Stop()
`));
test('real controller keeps confirmed receipt after disk failure and waits for SDK without claiming again',()=>run(`
now=1792453527;cache.LastDailyRewardClaim=1792370727;cache.DailyRewardsClaimed=1
local a=launch();assert(coroutine.resume(spawned));cache.DailyRewardsClaimed=2;cache.LastDailyRewardClaim=1792453527
diskOK=false;assert(coroutine.resume(spawned));local done=0
_G.Masterp_Done=function()done+=1 end
assert(coroutine.resume(spawned));assert(done==0)
diskOK=true;assert(coroutine.resume(spawned));assert(done==1 and claims==1)
assert(coroutine.resume(spawned));assert(done==1);a.Stop()
`));
test('AutoExecute waits for GameId initialization rather than rejecting Anime Dice at startup',()=>run(`
game.GameId=0;game.IsLoaded=function()return false end
local boot=coroutine.create(launch)
local ok,why=coroutine.resume(boot);assert(ok,why)
assert(coroutine.status(boot)=='suspended'and claims==0 and next(files)==nil)
game.IsLoaded=function()return true end
ok,why=coroutine.resume(boot);assert(ok,why)
assert(coroutine.status(boot)=='suspended'and claims==0,'loaded may precede GameId')
game.GameId=10708913337
ok,why=coroutine.resume(boot);assert(ok,why)
assert(coroutine.status(boot)=='dead'and _G.DiceDailyLogin.Status().phase=='waiting')
_G.DiceDailyLogin.Stop()
`));
test('AutoExecute waits through delayed LocalPlayer and PlayerGui without early IO or claims',()=>run(`
local players={};local service=game.GetService;local guiReady=false
game.GetService=function(self,k)if k=='Players'then return players end;return service(self,k)end
player.FindFirstChild=function(_,k)if k=='PlayerGui'and guiReady then return gui end end
local boot=coroutine.create(launch);local ok,why=coroutine.resume(boot);assert(ok,why)
assert(coroutine.status(boot)=='suspended'and next(files)==nil)
players.LocalPlayer=player
ok,why=coroutine.resume(boot);assert(ok,why);assert(coroutine.status(boot)=='suspended')
guiReady=true;ok,why=coroutine.resume(boot);assert(ok,why)
assert(coroutine.status(boot)=='dead'and claims==0);_G.DiceDailyLogin.Stop()
`));
test('AutoExecute reserves a fresh native-data budget after slow game loading and retries transient callback inspection',()=>run(`
local clock=0;os=setmetatable({clock=function()return clock end},{__index=os})
game.IsLoaded=function()return false end
local inspect=getconnections;getconnections=function()error('button connection not ready')end
cache.LastDailyRewardClaim=1000
local boot=coroutine.create(launch);local ok,why=coroutine.resume(boot);assert(ok,why)
clock=110;game.IsLoaded=function()return true end
ok,why=coroutine.resume(boot);assert(ok,why);assert(coroutine.status(boot)=='suspended')
clock=180;ok,why=coroutine.resume(boot);assert(ok,why)
assert(claims==0 and next(files)==nil,'not ready must not claim or persist fabricated state')
clock=220;getconnections=inspect
ok,why=coroutine.resume(boot);assert(ok,why)
assert(coroutine.status(boot)=='dead'and claims==1);_G.DiceDailyLogin.Stop()
`));
test('AutoExecute waits for replicated numeric daily fields instead of creating an unknown owner too early',()=>run(`
cache.LastDailyRewardClaim=nil
local boot=coroutine.create(launch);local ok,why=coroutine.resume(boot);assert(ok,why)
assert(coroutine.status(boot)=='suspended'and _G.DiceDailyLogin==nil and next(files)==nil)
cache.LastDailyRewardClaim=1000
ok,why=coroutine.resume(boot);assert(ok,why)
assert(coroutine.status(boot)=='dead'and claims==1);_G.DiceDailyLogin.Stop()
`));
test('late wrong-game identity is rejected before any claim, report, Done, or existing-owner stop',()=>run(`
local stopped,done=0,0
_G.DiceDailyLogin={Owned=true,Stop=function()stopped+=1 end}
_G.Masterp_Done=function()done+=1 end
game.GameId=0
local boot=coroutine.create(launch);assert(coroutine.resume(boot))
game.GameId=5578556129
local ok,why=coroutine.resume(boot);assert(not ok and tostring(why):find('Anime Dice only',1,true))
assert(claims==0 and done==0 and stopped==0 and next(files)==nil)
`));
test('uninitialized GameId times out safely without a busy loop or side effects',()=>run(`
local clock=0;os=setmetatable({clock=function()return clock end},{__index=os})
game.GameId=0
local boot=coroutine.create(launch);assert(coroutine.resume(boot));clock=121
local ok,why=coroutine.resume(boot)
assert(not ok and tostring(why):find('game identity not ready',1,true))
assert(claims==0 and next(files)==nil and _G.DiceDailyLogin==nil)
`));
test('native-data timeout leaves an existing owner and completion untouched',()=>run(`
local clock=0;os=setmetatable({clock=function()return clock end},{__index=os})
local stopped,done=0,0
_G.DiceDailyLogin={Owned=true,Stop=function()stopped+=1 end};_G.Masterp_Done=function()done+=1 end
getloadedmodules=function()return{}end
local boot=coroutine.create(launch);assert(coroutine.resume(boot));clock=121
local ok,why=coroutine.resume(boot)
assert(not ok and tostring(why):find('daily reward data/button not ready',1,true))
assert(claims==0 and done==0 and stopped==0 and next(files)==nil)
`));
