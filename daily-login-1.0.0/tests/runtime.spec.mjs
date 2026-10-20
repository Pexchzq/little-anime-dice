import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import {execFileSync} from 'node:child_process';
const root=new URL('../',import.meta.url);const runtime=fs.readFileSync(new URL('runtime.lua',root),'utf8');const model=fs.readFileSync(new URL('daily.lua',root),'utf8');const html=fs.readFileSync(new URL('report.html',root),'utf8');
const q=s=>JSON.stringify(s);
function run(body){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'dice-daily-test-'));const file=path.join(dir,'test.luau');fs.writeFileSync(file,`
local now=100000;local files,docs={},{};local jsonId=0;local claims=0;local diskOK=true
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
Instance={new=function(name)return object(name)end};Color3={fromRGB=function()return{}end};UDim2={fromOffset=function()return{}end,new=function()return{}end};UDim={new=function()return{}end};Enum={Font={Arial=1}}
task={wait=function()end,spawn=function()end}
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
local function launch()return fn(Daily,${q(html)})end
${body}
print('RUNTIME PASS')
`);try{assert.match(execFileSync('luau',[file],{encoding:'utf8',timeout:10000}),/RUNTIME PASS/);}finally{fs.rmSync(dir,{recursive:true,force:true});}}
test('actual runtime exports a waiting schedule without claiming, and singleton reload stops old owner',()=>run(`local a=launch();assert(claims==0 and a.Status().nextAt==181800);assert(files['dice_daily_next_login.html']);local b=launch();assert(a~=b and claims==0);b.Stop()`));
test('actual runtime eligible callback fires once and remains unconfirmed until native data changes',()=>run(`cache.LastDailyRewardClaim=1000;local a=launch();assert(claims==1 and a.Status().claimed==1);local b=launch();assert(claims==1,'durable pending survives reload');b.Stop()`));
test('actual runtime never claims without a read-back schedule or in the wrong game',()=>run(`cache.LastDailyRewardClaim=1000;diskOK=false;local a=launch();assert(claims==0 and a.Status().reason:find('save_failed'));a.Stop();game.GameId=5578556129;assert(not pcall(launch));assert(claims==0)`));
