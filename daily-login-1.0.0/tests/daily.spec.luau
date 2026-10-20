local Daily=require('../daily')
local row=Daily.Observe({gameId=10708913337,userId=1,claimed=1,lastClaim=1792370727,cooldown=82800,total=7,serverNow=1792371296,localNow=1792371296})
assert(row.nextAt==1792453527 and row.nextDay==2 and row.phase=='waiting')
print('PASS captured day 1 schedules day 2 after exactly 23 hours')
local base={gameId=10708913337,userId=1,claimed=1,lastClaim=1000,cooldown=82800,total=7,serverNow=83800,localNow=83800}
local claims=0;local stored;local writable=true
local function clone(v)local n={};for k,x in pairs(v)do n[k]=x end;return n end
local owner=Daily.Create({read=function()return clone(base)end,save=function(s)if not writable then return false,'disk_full'end;stored=s;return true end,
 claim=function()assert(stored.pending.attempts==claims+1,'intent must be durable before claim');claims+=1 end})
owner.Tick();owner.Tick();assert(claims==1 and owner.Status().reason=='waiting_server_confirmation')
base.claimed=2 -- Replication may arrive separately; never call this acceptance yet.
base.serverNow=83820
owner.Tick();assert(claims==1 and owner.Status().reason=='state_reconciling')
base.lastClaim=83800;owner.Tick();assert(owner.Status().reason=='claim_verified'and owner.Status().nextAt==166600)
print('PASS native acknowledgement requires count and timestamp; partial updates cannot dispatch again')
local bad=clone(base);bad.gameId=5578556129;assert(Daily.Observe(bad)==nil)
bad=clone(base);bad.claimed=8;assert(Daily.Observe(bad)==nil)
bad=clone(base);bad.lastClaim=bad.serverNow+60;assert(Daily.Observe(bad)==nil)
bad=clone(base);bad.claimed=0;bad.lastClaim=0;assert(Daily.Observe(bad).phase=='ready')
bad=clone(base);bad.claimed=7;assert(Daily.Observe(bad).phase=='complete'and Daily.Observe(bad).nextAt==nil)
print('PASS unknown/wrong game/future state refused, first day ready, day 7 complete')
base.claimed=1;base.lastClaim=1000;base.serverNow=83800;writable=false
local noWrite=Daily.Create({read=function()return clone(base)end,save=function()return false,'disk_full'end,claim=function()error('must not claim')end})
assert(noWrite.Tick().reason=='disk_full');noWrite.Stop();noWrite.Tick()
print('PASS persistence failure and Stop cannot claim')
local attempts=0;local intent
local bounded=Daily.Create({read=function()return clone(base)end,save=function(s)intent=s;return true end,claim=function()attempts+=1 end})
bounded.Tick();base.serverNow=83816;bounded.Tick();base.serverNow=83832;bounded.Tick();base.serverNow=83850
assert(bounded.Tick().reason=='claim_unconfirmed'and attempts==3)
local restored=Daily.Create({read=function()return clone(base)end,save=function()return true end,claim=function()error('reloading cannot reset attempt cap')end},{pending=intent.pending})
assert(restored.Tick().reason=='claim_unconfirmed');restored.Stop()
print('PASS retries are spaced/capped and durable across reload')
local paused=Daily.Create({read=function()return clone(base)end,save=function()return true end,claim=function()error('disabled')end},{enabled=false})
paused.Tick();assert(paused.Status().enabled==false)
print('PASS disabled controller observes only')
base.claimed=6;base.lastClaim=1000;base.serverNow=83800
local finalDay=Daily.Create({read=function()return clone(base)end,save=function()return true end,claim=function()end})
finalDay.Tick();base.claimed=7
assert(finalDay.Tick().claimed==6,'partial day 7 update must not display completion before acknowledgement')
base.lastClaim=83800;assert(finalDay.Tick().phase=='complete')
print('PASS partial day 7 acknowledgement never displays a premature completion')
