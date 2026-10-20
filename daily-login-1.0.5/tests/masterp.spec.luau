local Masterp=require('../masterp')
local Daily=require('../daily')
local function snapshot(day,last,now)
    return assert(Daily.Observe({gameId=10708913337,userId=1,claimed=day,lastClaim=last,serverNow=now,
        localNow=now,total=7,cooldown=82800}))
end
local waiting=snapshot(2,100000,100100)
local function create(options,previous)
    options=options or{}
    local state={done=0,messages={},writes={},writable=options.writable~=false}
    local env={}
    env.describe=function(...)assert(select('#',...)==1);state.messages[#state.messages+1]=(...)end
    env.done=function(...)
        assert(select('#',...)==0 and #state.messages>0,'Description before Done')
        assert(state.writes[#state.writes].phase=='dispatching','persist before callback')
        state.done+=1;if options.throw then error('uncertain callback')end
    end
    local deps={session=options.session or'live-A',text=Daily.Description,
        hook=function()return env.done end,description=function()return env.describe end,
        save=function(j)state.writes[#state.writes+1]=j;return state.writable end,
        log=options.log}
    return Masterp.Create(deps,previous),state,env
end
local a,state=create()
a.Tick(waiting);a.Tick(waiting)
assert(state.done==1 and #state.messages==1 and a.Status().evidence=='observed_native_completion')
assert(a.Diagnostics().gate=='already_reported_this_session')
print('PASS previously claimed native cooldown -> Description then Done once without a script receipt')
local ready=snapshot(1,1000,100000)
local pending=snapshot(1,1000,100000);pending.pending={attempts=1}
local b,s=create();b.Tick(ready);b.Tick(pending);assert(s.done==0)
local verified=snapshot(2,100000,100100);verified.claimReceipt={claimed=2,lastClaim=100000}
b.Tick(verified);assert(s.done==1 and b.Status().evidence=='verified_receipt')
print('PASS ready and unconfirmed claims publish status but cannot report Done')
local c,s3,e3=create();e3.describe=nil;c.Tick(waiting)
assert(s3.done==0 and c.Diagnostics().gate=='masterp_description_missing')
e3.describe=function(msg)s3.messages[#s3.messages+1]=msg end;e3.done=nil;c.Tick(waiting)
assert(s3.done==0 and c.Diagnostics().gate=='masterp_client_missing')
e3.done=function()assert(#s3.messages==1);s3.done+=1 end;c.Tick(waiting);assert(s3.done==1)
print('PASS late Description and Done hooks are resolved in the correct order')
local restored,rs=create({},a.Status());restored.Tick(waiting);assert(rs.done==0)
local newSession,ns=create({session='live-B'},a.Status());newSession.Tick(waiting);assert(ns.done==1)
local legacy,ls=create({}, {key='old-key',claimed=2,lastClaim=100000,phase='called'})
legacy.Tick(waiting);assert(ls.done==1)
print('PASS same-session dedupe and new-session/legacy-journal migration for completed accounts')
local disk,ds=create({writable=false});disk.Tick(waiting);assert(ds.done==0)
ds.writable=true;disk.Tick(waiting);assert(ds.done==1)
print('PASS report/journal persistence failure blocks Done without preventing Description')
local uncertain,us=create({throw=true});uncertain.Tick(waiting);uncertain.Tick(waiting)
assert(us.done==1 and uncertain.Status().phase=='unknown')
local uncertainRestore,urs=create({},uncertain.Status());uncertainRestore.Tick(waiting);assert(urs.done==0)
print('PASS uncertain same-session callback is not blindly repeated')
local final,fs=create();final.Tick(snapshot(7,100000,100100))
assert(fs.done==1 and fs.messages[1]:find('ไม่มีรอบถัดไป',1,true))
assert(not fs.messages[1]:find('วันที่ 8',1,true))
print('PASS native observed final day sends completion with no invented day eight')
local failed,es,ee=create();ee.describe=function()error('description failed')end
failed.Tick(waiting);assert(es.done==0 and failed.Diagnostics().gate=='description_callback_error')
ee.describe=function(text)es.messages[#es.messages+1]=text end;failed.Tick(waiting);assert(es.done==1)
print('PASS Description error cannot be bypassed by Done')
local stopped,ss=create();stopped.Stop();stopped.Tick(waiting);assert(ss.done==0 and #ss.messages==0)
local invalid,is=create();invalid.Tick({phase='unknown'});assert(is.done==0)
local badJournal,bs=create({}, {bad=true});badJournal.Tick(waiting);assert(bs.done==0)
local future=snapshot(2,100000,100100);future.lastClaim=200000
local noFuture,nfs=create();noFuture.Tick(future);assert(nfs.done==0)
print('PASS Stop, unknown/future native state and invalid journal fail safely')
local sink,cs=create({log=function()error('diagnostic sink unavailable')end})
sink.Tick(waiting);sink.Tick(waiting);assert(cs.done==1)
print('PASS diagnostic sink failure does not change Description/Done dispatch')
