local Masterp=require('../masterp')
local s={gameId=10708913337,userId=1,claimed=2,lastClaim=100000,claimReceipt={claimed=2,lastClaim=100000}}
local writes={};local calls=0;local hook
local api=Masterp.Create({hook=function()return hook end,save=function(journal)writes[#writes+1]=journal;return true end})
api.Tick({gameId=10708913337,userId=1,claimed=1,lastClaim=1000,phase='waiting'})
assert(calls==0 and #writes==0,'a waiting/login snapshot is not claim completion')
api.Tick(s);assert(api.Status().phase=='pending'and calls==0,'missing SDK must not break the reward')
hook=function(...)assert(select('#',...)==0);assert(writes[#writes].phase=='dispatching','persist before callback');calls+=1 end
api.Tick(s);api.Tick(s);assert(calls==1 and api.Status().phase=='called')
local restored=Masterp.Create({hook=function()return hook end,save=function()return true end},api.Status())
restored.Tick(s);assert(calls==1,'reload cannot report the same receipt twice')
print('PASS verified receipt -> durable zero-argument Masterp_Done once; late SDK supported')
local prevented=0;local writable=false
local noDisk=Masterp.Create({hook=function()return function()prevented+=1 end end,save=function()return writable end})
noDisk.Tick(s);assert(prevented==0 and noDisk.Status().phase=='pending')
writable=true;noDisk.Tick(s);assert(prevented==1)
print('PASS failed schedule/journal persistence blocks Done until a successful save')
local badCalls=0;local unknown=Masterp.Create({hook=function()return function()badCalls+=1;error('unknown downstream outcome')end end,save=function()return true end})
unknown.Tick(s);unknown.Tick(s);assert(badCalls==1 and unknown.Status().phase=='unknown')
local uncertain=Masterp.Create({hook=function()return function()badCalls+=1 end end,save=function()return true end},
 {key='10708913337:1:2:100000',claimed=2,lastClaim=100000,phase='dispatching'})
uncertain.Tick(s);assert(badCalls==1)
print('PASS thrown callback and restored dispatch intent are not blindly repeated')
local stopped=Masterp.Create({hook=function()return function()error('stopped hook')end end,save=function()return true end})
stopped.Stop();stopped.Tick(s);assert(stopped.Status()==nil)
api.Tick({gameId=10708913337,userId=1,claimed=7,lastClaim=999999,phase='complete'})
assert(calls==1,'observing old completion at boot is not a new claimed reward')
api.Tick({gameId=10708913337,userId=1,claimed=7,lastClaim=999999,claimReceipt={claimed=7,lastClaim=999999}})
assert(calls==2,'a newly confirmed day 7 receipt reports Done as well')
print('PASS Stop, old completion observation and real final-day receipt remain distinct')
local delayed=0
local late=Masterp.Create({hook=function()return function()delayed+=1 end end,save=function()return true end})
local inFlight={gameId=10708913337,userId=1,claimed=2,lastClaim=100000,phase='ready',pending={attempts=1},claimReceipt={claimed=2,lastClaim=100000}}
late.Tick(inFlight);assert(delayed==0,'an older receipt must not report Done while the current claim is in flight')
inFlight.pending=nil;late.Tick(inFlight);assert(delayed==0,'an old receipt must not mark a currently due daily run done')
inFlight.phase='waiting';late.Tick(inFlight);assert(delayed==1)
print('PASS late SDK never reports an old receipt over a new eligible/in-flight claim')
