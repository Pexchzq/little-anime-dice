-- GENERATED Anime Dice Daily Login 1.0.5
local Daily=assert(loadstring([=[-- Pure schedule and bounded claim owner; all external IO is injected.
local Daily={Version='1.0.5',GameId=10708913337}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
local function integer(n)return finite(n)and n>=0 and n%1==0 end
local function copy(t)local o={};for k,v in pairs(t)do o[k]=type(v)=='table'and copy(v)or v end;return o end
function Daily.ThaiDate(timestamp)
    if not finite(timestamp)or timestamp<1 then return'ยังไม่ทราบ'end
    -- Explicit UTC +07:00, independent of the Mac/executor's local timezone.
    local d=os.date('!*t',math.floor(timestamp)+25200)
    local days={'อาทิตย์','จันทร์','อังคาร','พุธ','พฤหัสบดี','ศุกร์','เสาร์'}
    local months={'มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน','กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม'}
    return string.format('วัน%sที่ %d %s %d เวลา %02d:%02d:%02d น. (เวลาไทย)',
        days[d.wday],d.day,months[d.month],d.year+543,d.hour,d.min,d.sec)
end
function Daily.NextText(s)
    if type(s)~='table'then return'ยังไม่มีวันและเวลาที่เกมยืนยัน'end
    if s.claimed==7 and s.phase=='complete'then return'รับครบทั้ง 7 วันแล้ว — ไม่มีรอบถัดไปในชุดนี้'end
    if not finite(s.nextAt)or s.nextAt<1 or not integer(s.claimed)or s.claimed>=7
        or s.nextDay~=s.claimed+1 then return'ยังไม่มีวันและเวลาที่เกมยืนยัน'end
    return string.format('รับรางวัลวันที่ %d ได้ตั้งแต่\n%s',s.nextDay,Daily.ThaiDate(s.nextAt))
end
function Daily.Description(s)
    if type(s)~='table'or not integer(s.claimed)or not finite(s.serverObservedAt)then
        return'Anime Dice | กำลังตรวจสอบสถานะรางวัล ยังไม่ยืนยันว่ารับแล้ว'
    end
    local today=integer(s.lastClaim)and s.lastClaim>0
        and math.floor((s.lastClaim+25200)/86400)==math.floor((s.serverObservedAt+25200)/86400)
    local parts={'Anime Dice','วันนี้: '..(today and'รับแล้ว'or'ยังไม่ได้รับ'),string.format('สะสม %d/7 วัน',s.claimed)}
    if s.pending then
        parts[#parts+1]='รอบปัจจุบัน: กำลังรอเกมยืนยัน ยังไม่ถือว่ารับสำเร็จ'
        parts[#parts+1]='รับครั้งถัดไป: จะแจ้งเมื่อเกมยืนยันรอบนี้'
    elseif s.phase=='complete'and s.claimed==7 then
        parts[#parts+1]='ครบ 7 วันแล้ว | รับครั้งถัดไป: ไม่มีรอบถัดไปในชุดนี้'
    elseif s.phase=='waiting'and s.claimed>0 then
        parts[#parts+1]='รอบปัจจุบัน: รับแล้ว'
        parts[#parts+1]='รับครั้งถัดไป (วันที่ '..tostring(s.nextDay)..'): '..Daily.ThaiDate(s.nextAt)
    elseif s.phase=='ready'then
        parts[#parts+1]='รอบปัจจุบัน: ยังไม่ได้รับ รับได้แล้ว'
        parts[#parts+1]='รับครั้งถัดไป: จะแจ้งหลังรับรอบนี้สำเร็จ'
    else parts[#parts+1]='กำลังตรวจสอบ ยังไม่ยืนยันสถานะรอบปัจจุบัน'end
    if integer(s.lastClaim)and s.lastClaim>0 then parts[#parts+1]='รับล่าสุด: '..Daily.ThaiDate(s.lastClaim)end
    return table.concat(parts,' | ')
end
function Daily.Observe(v)
    if type(v)~='table'or v.gameId~=Daily.GameId then return nil,'wrong_game'end
    if not integer(v.userId)or v.userId<1 or not integer(v.claimed)or not integer(v.total)or v.total~=7
        or v.claimed>v.total or not integer(v.lastClaim)or not finite(v.cooldown)or v.cooldown<60
        or v.cooldown>604800 or not finite(v.serverNow)or not finite(v.localNow)
        or v.serverNow<1 or v.lastClaim>v.serverNow+5 or(v.claimed>0 and v.lastClaim==0)then return nil,'state_unknown'end
    local done=v.claimed>=v.total
    local nextAt=not done and(v.lastClaim==0 and v.serverNow or v.lastClaim+v.cooldown)or nil
    return{schemaVersion=1,version=Daily.Version,gameId=v.gameId,userId=v.userId,claimed=v.claimed,total=v.total,
        lastClaim=v.lastClaim,cooldown=v.cooldown,nextAt=nextAt,nextDay=not done and v.claimed+1 or nil,
        phase=done and'complete'or(nextAt<=v.serverNow and'ready'or'waiting'),
        serverObservedAt=v.serverNow,localObservedAt=v.localNow,serverOffset=v.serverNow-v.localNow}
end
function Daily.Create(deps,options)
    options=options or{}
    local enabled=options.enabled~=false;local stopped=false;local last={phase='loading'}
    local pending=options.pending and copy(options.pending)or nil
    local receipt=options.claimReceipt and copy(options.claimReceipt)or nil
    if receipt and(not integer(receipt.claimed)or receipt.claimed<1 or receipt.claimed>7
        or not integer(receipt.lastClaim)or receipt.lastClaim<1)then receipt=nil end
    if pending and(type(pending.key)~='string'or not integer(pending.claimed)or not integer(pending.lastClaim)
        or not integer(pending.attempts)or pending.attempts>3
        or not finite(pending.sentAt)or pending.sentAt<0)then pending=nil;enabled=false end
    local busy=false;local api={}
    local function store(s)
        local ok,why=deps.save(copy(s))
        if not ok then s.reason=why or'save_failed'end
    end
    function api.Tick()
        if stopped or busy then return copy(last)end
        busy=true
        local ok,result=pcall(function()
            local raw=deps.read();local s,why=Daily.Observe(raw)
            if not s then last={phase='unknown',reason=why,enabled=enabled};return end
            local key=tostring(s.claimed)..':'..tostring(s.lastClaim)
            if pending and pending.key~=key then
                -- A changed native claim count AND timestamp prove acceptance.
                if s.claimed>pending.claimed and s.lastClaim>pending.lastClaim then
                    s.reason='claim_verified';receipt={claimed=s.claimed,lastClaim=s.lastClaim};pending=nil
                else
                    s.nativeClaimed=s.claimed;s.claimed=pending.claimed;s.lastClaim=pending.lastClaim
                    s.nextDay=pending.claimed+1;s.nextAt=pending.lastClaim+s.cooldown;s.phase='ready'
                    s.enabled=enabled;s.pending=copy(pending);s.reason='state_reconciling';last=s;store(s);return
                end
            end
            s.enabled=enabled;s.pending=pending and copy(pending)or nil;s.claimReceipt=receipt and copy(receipt)or nil;last=s
            if not enabled or s.phase~='ready'then store(s);return end
            if pending and s.serverObservedAt<pending.sentAt then s.reason='clock_reconcile';store(s);return end
            if pending and pending.attempts>=3 then s.reason='claim_unconfirmed';store(s);return end
            if pending and s.serverObservedAt-pending.sentAt<15 then s.reason='waiting_server_confirmation';store(s);return end
            local candidate={key=key,claimed=s.claimed,lastClaim=s.lastClaim,attempts=pending and pending.attempts+1 or 1,sentAt=s.serverObservedAt}
            s.pending=copy(candidate);s.reason='waiting_server_confirmation'
            -- A durable intent is required BEFORE touching the native Claim button.
            local saved,err=deps.save(copy(s),true)
            if not saved then s.pending=pending and copy(pending)or nil;s.reason=err or'save_failed';return end
            pending=candidate
            if stopped or not enabled then s.reason='stopped';return end
            local called,claimError=pcall(deps.claim)
            if not called then s.reason='claim_outcome_unknown';s.detail=tostring(claimError)end
        end)
        busy=false
        if not ok then last.reason='observation_error';last.detail=tostring(result)end
        return copy(last)
    end
    function api.Status()return copy(last)end
    function api.SetEnabled(value)enabled=value==true;return api.Tick()end
    function api.Stop()enabled=false;stopped=true;last.enabled=false;return true end
    return api
end
return Daily
]=],'@dice-daily/model'))()
local Masterp=assert(loadstring([=[-- Documented Manager callbacks only; no private Manager transport protocol.
local Masterp={}
local function copy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
local function int(n)return type(n)=='number'and n==n and n>=0 and n<math.huge and n%1==0 end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
local phases={pending=true,dispatching=true,called=true,unknown=true,cancelled=true}
function Masterp.Create(deps,previous)
    local journal=previous and copy(previous)or nil;local stopped=false;local busy=false;local invalid=false
    local gate='not_checked';local description='not_sent';local lastText;local lastDescribe
    local session=deps.session or'legacy'
    local function emit(event,fields)if type(deps.log)=='function'then pcall(deps.log,event,fields or{})end end
    local function blocked(reason)gate=reason;emit('done_gate',{reason=reason,journal=journal and journal.phase or'none'})end
    if journal and(type(journal)~='table'or type(journal.key)~='string'or not phases[journal.phase]
        or not int(journal.claimed)or not int(journal.lastClaim)
        or(journal.session~=nil and type(journal.session)~='string'))then
        invalid=true;journal={phase='invalid',reason='masterp_journal_invalid'}
    end
    local api={}
    function api.Status()return copy(journal)end
    function api.Diagnostics()return{gate=gate,journal=journal and journal.phase or'none',description=description}end
    function api.Stop()stopped=true end
    function api.Tick(s)
        if stopped or busy then blocked(stopped and'stopped'or'busy');return api.Status()end
        busy=true
        local ok=pcall(function()
            if type(s)~='table'then blocked('invalid_snapshot');return end
            local text=deps.text(s);local describe=deps.description()
            if type(text)~='string'or #text>8192 then blocked('invalid_description');return end
            if type(describe)~='function'then description='client_missing';blocked('masterp_description_missing');return end
            if text~=lastText or describe~=lastDescribe then
                description='calling';emit('description_call_begin',{args=1})
                local sent,err=pcall(describe,text)
                description=sent and'called_not_manager_ack'or'callback_error'
                emit('description_call_result',{ok=sent,error_type=sent and'none'or type(err)})
                if not sent then blocked('description_callback_error');return end
                lastText=text;lastDescribe=describe
            end
            if stopped then blocked('stopped');return end
            if invalid then blocked('invalid_journal');return end
            if s.pending~=nil then blocked('claim_pending');return end
            if s.phase=='ready'then blocked('new_claim_due');return end
            if s.reason=='observation_error'then blocked('native_observation_error');return end
            if s.gameId~=10708913337 or not int(s.userId)or s.userId<1 or s.total~=7
                or not int(s.claimed)or s.claimed<1 or s.claimed>7 or not int(s.lastClaim)or s.lastClaim<1
                or not finite(s.serverObservedAt)or s.lastClaim>s.serverObservedAt+5 then
                blocked('invalid_native_state');return
            end
            local complete=s.phase=='complete'and s.claimed==7
            local cooldown=s.phase=='waiting'and s.claimed<7 and finite(s.cooldown)and s.cooldown>=60
                and s.cooldown<=604800 and finite(s.nextAt)and s.nextAt==s.lastClaim+s.cooldown
                and s.nextAt>s.serverObservedAt
            if not complete and not cooldown then blocked('daily_not_completed');return end
            -- Once per native cycle per live Roblox session, including previously claimed accounts.
            local key=table.concat({s.gameId,s.userId,s.claimed,s.lastClaim,session},':')
            if journal and journal.key==key and journal.phase~='pending'then
                blocked(journal.phase=='called'and'already_reported_this_session'or'previous_outcome_uncertain_or_cancelled');return
            end
            if not journal or journal.key~=key then
                journal={key=key,session=session,claimed=s.claimed,lastClaim=s.lastClaim,phase='pending',
                    evidence=type(s.claimReceipt)=='table'and'verified_receipt'or'observed_native_completion'}
            end
            local hook=deps.hook()
            if type(hook)~='function'then
                journal.reason='masterp_client_missing';blocked('masterp_client_missing');deps.save(copy(journal),s);return
            end
            journal.phase='dispatching';journal.reason=nil
            if deps.save(copy(journal),s,true)~=true then
                journal.phase='pending';journal.reason='masterp_save_failed';blocked('masterp_save_failed');return
            end
            if stopped then journal.phase='cancelled';deps.save(copy(journal),s,true);blocked('stopped');return end
            gate='calling';emit('done_call_begin',{args=0,dispatch_saved=true,evidence=journal.evidence})
            local called,err=pcall(hook)
            journal.phase=called and'called'or'unknown';journal.reason=not called and'masterp_callback_outcome_unknown'or nil
            gate=called and'callback_returned_not_manager_ack'or'callback_threw_outcome_unknown'
            emit('done_call_result',{reason=gate,error_type=called and'none'or type(err)})
            deps.save(copy(journal),s,true)
        end)
        busy=false
        if not ok then
            if journal then
                if journal.phase=='dispatching'then journal.phase='unknown'end
                journal.reason='masterp_adapter_error'
            end
            blocked('masterp_adapter_error')
        end
        return api.Status()
    end
    return api
end
return Masterp
]=],'@dice-daily/masterp'))()
return assert(loadstring([=[local Daily,template,Masterp=...
-- Deliberately scalar-only diagnostics: never dump SDK globals, journals or account paths.
local debugLines={}
local function trace(event,fields,force)
    pcall(function()
        local keys={};for k in pairs(fields or{})do keys[#keys+1]=k end;table.sort(keys)
        local parts={};for _,k in ipairs(keys)do parts[#parts+1]=k..'='..tostring(fields[k])end
        local line=table.concat(parts,' ')
        if force or debugLines[event]~=line then
            debugLines[event]=line;print('[DICE-DEBUG-105] '..event..' '..line)
        end
    end)
end
local function sdkTypes(name)
    name=name or'Masterp_Done'
    local globalType=type(rawget(_G,name));local envType='unavailable'
    if type(getgenv)=='function'then
        local ok,env=pcall(getgenv)
        if ok and type(env)=='table'then envType=type(rawget(env,name))end
    end
    return globalType,envType
end
local function sdkHook(name)
    local f=rawget(_G,name);if type(f)=='function'then return f end
    if type(getgenv)=='function'then
        local ok,env=pcall(getgenv)
        if ok and type(env)=='table'and type(rawget(env,name))=='function'then return rawget(env,name)end
    end
end
trace('boot',{version=Daily.Version,stage='waiting_game_identity'})
local P=game:GetService('Players');local H=game:GetService('HttpService')
local untilAt=os.clock()+120
while(not game:IsLoaded()or type(game.GameId)~='number'or game.GameId<=0)and os.clock()<untilAt do task.wait(.25)end
assert(game:IsLoaded()and type(game.GameId)=='number'and game.GameId>0,'Anime Dice startup timed out: game identity not ready')
assert(game.GameId==Daily.GameId,'This script is for Anime Dice only')
trace('boot',{version=Daily.Version,stage='waiting_player_gui'})
assert(type(writefile)=='function'and type(readfile)=='function'and type(isfile)=='function','Executor file access required')
assert(type(getloadedmodules)=='function'and type(getconnections)=='function'and type(debug.info)=='function'
    and type(debug.getupvalues)=='function','Executor native callback inspection required')
while(not P.LocalPlayer or type(P.LocalPlayer.UserId)~='number'or P.LocalPlayer.UserId<=0
    or not P.LocalPlayer:FindFirstChild('PlayerGui'))and os.clock()<untilAt do task.wait(.25)end
local player=assert(P.LocalPlayer,'Player not ready');local gui=assert(player:FindFirstChild('PlayerGui'),'PlayerGui not ready')
assert(type(player.UserId)=='number'and player.UserId>0,'Anime Dice startup timed out: player identity not ready')
trace('boot',{version=Daily.Version,stage='waiting_native_daily'})
local data,config,callback
local function findNative()
    data=nil;config=nil;callback=nil
    for _,m in ipairs(getloadedmodules())do
        local n=m:GetFullName()
        if n=='ReplicatedStorage.Framework.Features.Data.DataController'then data=require(m)
        elseif n=='ReplicatedStorage.Framework.Features.Rewards.DailyRewardConfig'then config=require(m)end
    end
    local root=gui:FindFirstChild('Root');local menus=root and root:FindFirstChild('Menus')
    local daily=menus and menus:FindFirstChild('DailyRewards');local group=daily and daily:FindFirstChild('Day1-6');local button=group and group:FindFirstChild('Day1')
    if button then
        for _,c in ipairs(getconnections(button.Activated))do
            local f=c.Function
            if type(f)=='function'then
                local ok,source=pcall(debug.info,f,'s')
                if ok and source=='ReplicatedStorage.Framework.Features.Rewards.DailyRewardController'then
                    local count,vararg=debug.info(f,'a');local ups=debug.getupvalues(f);local remote=type(ups[1])=='table'and rawget(ups[1],'_re')
                    if count==0 and not vararg and typeof(remote)=='Instance'and remote:GetFullName()=='ReplicatedStorage.Network.DailyRewardService.RE.Claim'then callback=f end
                end
            end
        end
    end
    return data and type(data.___X)=='table'and type(data.___X.DailyRewardsClaimed)=='number'
        and type(data.___X.LastDailyRewardClaim)=='number'and config and type(config.Rewards)=='table'
        and #config.Rewards==7 and type(config.Cooldown)=='number'and callback
end
-- Give native replication its own budget after the game/player are ready.
untilAt=os.clock()+120
local nativeReady=false
repeat
    local ok,ready=pcall(findNative)
    nativeReady=ok and not not ready
    if not nativeReady and os.clock()<untilAt then task.wait(.5)end
until nativeReady or os.clock()>=untilAt
assert(nativeReady,'Anime Dice startup timed out: daily reward data/button not ready')
trace('boot',{version=Daily.Version,stage='native_ready'})
assert(game.GameId==Daily.GameId,'This script is for Anime Dice only')
local old=rawget(_G,'DiceDailyLogin')
if old then assert(old.Owned==true and type(old.Stop)=='function','Existing daily script owner conflict');old.Stop()end
local statePath='dice_daily_'..player.UserId..'_state.json'
local reportPath='dice_daily_'..player.UserId..'.html'
local textPath='dice_daily_'..player.UserId..'_next_login.txt'
local latestReport='dice_daily_next_login.html'
local existing
if isfile(statePath)then
    local raw=readfile(statePath);assert(#raw<32768,'Saved daily state too large')
    local ok,s=pcall(H.JSONDecode,H,raw)
    assert(ok and type(s)=='table'and s.schemaVersion==1 and s.gameId==Daily.GameId and s.userId==player.UserId,'Saved daily state invalid; preserve it and inspect before retrying')
    existing=s
end
trace('journal_loaded',{state=existing and'present'or'none',receipt=existing and type(existing.claimReceipt)=='table'or false,
    completion=existing and existing.masterpCompletion and existing.masterpCompletion.phase or'none'})
local alive=true;local lastWrite=-math.huge;local signature;local owner;local screen;local manager
local function save(s,force)
    local pending=s.pending
    local completion=manager and manager.Status()or(existing and existing.masterpCompletion)
    local sig=table.concat({s.claimed,s.lastClaim,s.cooldown,s.phase,s.reason or'',tostring(s.enabled),pending and pending.attempts or 0,
        completion and completion.key or'',completion and completion.phase or'',completion and completion.reason or''},':')
    if not force and sig==signature and os.clock()-lastWrite<60 then return true end
    local saveStep='encode_state'
    local ok,why=pcall(function()
        s.nextLoginText=Daily.NextText(s)
        s.masterpCompletion=completion
        local raw=H:JSONEncode(s)
        saveStep='backup_readback'
        if isfile(statePath)then local previous=readfile(statePath);writefile(statePath..'.backup',previous);assert(readfile(statePath..'.backup')==previous,'backup_readback_failed')end
        saveStep='state_write_readback'
        writefile(statePath,raw);assert(readfile(statePath)==raw,'state_readback_failed')
        local safe=raw:gsub('<','\\u003c');local html=template:gsub('__STATE_JSON__',function()return safe end)
        saveStep='account_html_write_readback'
        writefile(reportPath,html);assert(readfile(reportPath)==html,'report_readback_failed')
        saveStep='latest_html_write_readback'
        writefile(latestReport,html);assert(readfile(latestReport)==html,'latest_report_readback_failed')
        local text='Anime Dice · รับรางวัล 7 วัน\n'..s.nextLoginText..'\n\nบันทึกจากสถานะที่เกมยืนยันล่าสุด ไม่ใช่การรับรางวัลขณะออฟไลน์\n'
        saveStep='account_text_write_readback'
        writefile(textPath,text);assert(readfile(textPath)==text,'text_readback_failed')
        saveStep='latest_text_write_readback'
        writefile('dice_daily_next_login.txt',text);assert(readfile('dice_daily_next_login.txt')==text,'latest_text_readback_failed')
    end)
    if ok then signature=sig;lastWrite=os.clock()end
    trace('files_result',{ok=ok,stage=ok and'all_reports_read_back'or saveStep,error_type=ok and'none'or type(why)})
    return ok,not ok and('save_failed: '..tostring(why))or nil
end
local session=rawget(_G,'DiceDailyMasterpSession')
if session then assert(type(session)=='table'and session.Owned==true,'Manager session owner conflict')end
if not session or session.GameId~=game.GameId or session.UserId~=player.UserId then
    session={Owned=true,GameId=game.GameId,UserId=player.UserId,Id=H:GenerateGUID(false)}
    _G.DiceDailyMasterpSession=session
end
manager=Masterp.Create({hook=function()return sdkHook('Masterp_Done')end,
    description=function()return sdkHook('Masterp_Description')end,text=Daily.Description,session=session.Id,
    log=function(event,fields)trace(event,fields,event=='done_call_begin'or event=='done_call_result')end,
    save=function(_,snapshot,force)return save(snapshot,force)end},existing and existing.masterpCompletion)
owner=Daily.Create({read=function()
    assert(game.GameId==Daily.GameId,'wrong_game')
    local cache=data.___X
    return{gameId=game.GameId,userId=player.UserId,claimed=cache.DailyRewardsClaimed,lastClaim=cache.LastDailyRewardClaim,
        total=#config.Rewards,cooldown=config.Cooldown,serverNow=workspace:GetServerTimeNow(),localNow=os.time()}
end,save=save,claim=function()
    assert(alive,'stopped');trace('claim_call_begin',{args=0},true)
    callback() -- Existing zero-argument UI callback, not a guessed wire call.
    trace('claim_call_returned',{note='await_native_count_and_timestamp'},true)
end},{enabled=true,pending=existing and existing.pending,claimReceipt=existing and existing.claimReceipt})
screen=Instance.new('ScreenGui');screen.Name='DiceDailyLogin_105';screen.ResetOnSpawn=false;screen.Parent=gui
local box=Instance.new('Frame');box.Size=UDim2.fromOffset(360,215);box.Position=UDim2.new(1,-375,0,65);box.BackgroundColor3=Color3.fromRGB(238,245,247);box.Parent=screen
local round=Instance.new('UICorner');round.CornerRadius=UDim.new(0,12);round.Parent=box
local label=Instance.new('TextLabel');label.Size=UDim2.new(1,-24,0,165);label.Position=UDim2.fromOffset(12,6);label.BackgroundTransparency=1;label.TextWrapped=true;label.TextSize=14;label.Font=Enum.Font.Arial;label.TextColor3=Color3.fromRGB(21,52,70);label.Parent=box
local auto=Instance.new('TextButton');auto.Size=UDim2.fromOffset(185,30);auto.Position=UDim2.fromOffset(12,175);auto.TextSize=13;auto.Parent=box
local close=Instance.new('TextButton');close.Size=UDim2.fromOffset(112,30);close.Position=UDim2.fromOffset(231,175);close.Text='หยุด / ปิด';close.TextSize=13;close.Parent=box
local connections={};local api={Owned=true,Version=Daily.Version,StatePath=statePath,ReportPath=reportPath}
local lastDebugAt=-math.huge;local lastDebugSignature
local function reportDiagnostics(s,force)
    local ok,result=pcall(function()
    local g,e=sdkTypes();local dg,de=sdkTypes('Masterp_Description');local m=manager.Diagnostics();local p=s.pending
    local cache=type(data.___X)=='table'and data.___X or{}
    local d={version=Daily.Version,phase=s.phase or'none',reason=type(s.reason)=='string'and(s.reason:match('^[%w_]+')or'unknown')or'none',
        day=s.claimed or'unknown',receipt=type(s.claimReceipt)=='table',attempts=p and p.attempts or 0,
        gate=m.gate,journal=m.journal,description=m.description,hook_G=g,hook_getgenv=e,description_G=dg,description_getgenv=de,
        sdk=type(rawget(_G,'DiceDailyMasterpBootstrap'))=='table'and _G.DiceDailyMasterpBootstrap.phase or'not_needed',
        ack_day=p and type(cache.DailyRewardsClaimed)=='number'and cache.DailyRewardsClaimed>p.claimed or false,
        ack_time=p and type(cache.LastDailyRewardClaim)=='number'and cache.LastDailyRewardClaim>p.lastClaim or false,
        next_in_seconds=type(s.nextAt)=='number'and math.max(0,math.ceil(s.nextAt-workspace:GetServerTimeNow()))or'none'}
    local sig=table.concat({d.phase,d.reason,tostring(d.day),tostring(d.receipt),d.attempts,d.gate,d.journal,g,e,dg,de,d.description,d.sdk,
        tostring(d.ack_day),tostring(d.ack_time)},':')
    if force or sig~=lastDebugSignature or os.clock()-lastDebugAt>=15 then
        lastDebugAt=os.clock();lastDebugSignature=sig;trace('summary',d,true)
    end
    return d
    end)
    if not ok then trace('diagnostic_error',{error_type=type(result)},true);return{gate='diagnostic_error'}end
    return result
end
local announced
local function display(s)
    local left=s.nextAt and math.max(0,math.ceil(s.nextAt-workspace:GetServerTimeNow()))or 0
    local status=s.phase=='complete'and'รับครบ 7 วันแล้ว'or s.phase=='ready'and'ถึงเวลารับแล้ว'or string.format('เหลือ %02d:%02d:%02d',math.floor(left/3600),math.floor(left%3600/60),left%60)
    local nextText=Daily.NextText(s)
    label.Text=string.format('Anime Dice · รางวัล 7 วัน\nรับแล้ว %s/7\n%s\n%s\n%s',tostring(s.claimed or'?'),nextText,status,s.reason or'บันทึกวันและเวลารับครั้งถัดไปแล้ว')
    auto.Text=s.enabled and'รับอัตโนมัติ: เปิด'or'รับอัตโนมัติ: ปิด'
    if s.reason=='claim_verified'and announced~=s.lastClaim then
        announced=s.lastClaim;print('[DICE-DAILY] รับรางวัลสำเร็จ\n'..nextText)
        pcall(function()game:GetService('StarterGui'):SetCore('SendNotification',{Title='รับรางวัลสำเร็จ',Text=nextText,Duration=15})end)
    end
end
api.Status=function()local s=owner.Status();s.masterpCompletion=manager.Status();return s end
api.Debug=function()return reportDiagnostics(owner.Status(),true)end -- Read-only: no Tick/save/claim/Done.
api.Stop=function()
    if not alive then return true end;alive=false;owner.Stop();manager.Stop()
    trace('stopped',{version=Daily.Version},true)
    for _,c in ipairs(connections)do c:Disconnect()end
    if screen then screen:Destroy()end
    return true
end
connections[#connections+1]=auto.Activated:Connect(function()local s=owner.SetEnabled(not owner.Status().enabled);display(s);if alive then manager.Tick(s);reportDiagnostics(s)end end)
connections[#connections+1]=close.Activated:Connect(api.Stop)
_G.DiceDailyLogin=api
-- Same official CDN target as Achitsak/masterp-manager/loader/client.lua.
-- Do not bootstrap over any visible partial client, or retry an uncertain execution.
local function startMasterpClient()
    if sdkHook('Masterp_Done')or sdkHook('Masterp_Description')then
        trace('sdk_bootstrap',{phase='existing_client_or_partial_client'});return
    end
    local previous=rawget(_G,'DiceDailyMasterpBootstrap')
    if previous then
        trace('sdk_bootstrap',{phase=type(previous)=='table'and previous.phase or'owner_conflict'});return
    end
    local boot={Owned=true,phase='scheduled'};_G.DiceDailyMasterpBootstrap=boot
    task.spawn(function()
        local function state(phase)boot.phase=phase;trace('sdk_bootstrap',{phase=phase},true)end
        if not alive then state('cancelled');return end
        if sdkHook('Masterp_Done')or sdkHook('Masterp_Description')then state('existing_client');return end
        state('fetching_official_client')
        local ok,source=pcall(function()return game:HttpGet('https://cdn.masterpx.xyz/s/masterp-manager/client',true)end)
        if not alive then state('cancelled');return end
        if not ok then state('client_http_error');return end
        if type(source)~='string'or #source==0 or #source>2097152 then state('invalid_client_response');return end
        if source:match('^%s*<')then state('client_response_is_html');return end
        local loader=loadstring(source,'@dice-daily/masterp-client')
        if type(loader)~='function'then state('client_compile_error');return end
        -- Quick Start defaults only; never overwrite settings supplied by the user's Manager.
        if rawget(_G,'MasterpSettings')==nil then
            _G.MasterpSettings={Performance=false,UnlockFPS={Enable=false,TargetFps=10}}
        end
        state('executing_official_client')
        local ran=pcall(loader)
        if not ran then state('client_execution_error');return end
        state(sdkHook('Masterp_Done')and sdkHook('Masterp_Description')and'client_hooks_ready'or'client_returned_hooks_missing')
    end)
end
startMasterpClient()
local s=owner.Tick();display(s)
print('[DICE-DAILY] '..Daily.NextText(s))
if alive then manager.Tick(s);reportDiagnostics(s)end
task.spawn(function()
    while alive do task.wait(2);if alive then local current=owner.Tick();display(current);if alive then manager.Tick(current);reportDiagnostics(current)end end end
end)
return api
]=],'@dice-daily/runtime'))(Daily,[=[<!doctype html>
<html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
<title>Anime Dice · เวลารับรางวัล 7 วัน</title>
<style>
:root{color-scheme:light;font-family:Thonburi,"Helvetica Neue",sans-serif;color:#153446;background:#eef5f7}*{box-sizing:border-box}body{margin:0;padding:6vh 22px}main{max-width:760px;margin:auto;background:#fff;border:1px solid #cedde3;border-radius:22px;padding:clamp(22px,5vw,46px)}header{display:flex;align-items:center;gap:14px}.die{font-size:42px;color:#d68c37}h1{font-size:24px;margin:0}header p,.muted{font-size:13px;color:#617b88}header p{margin:4px 0}section{margin-top:32px}.eyebrow{color:#466d83;font-size:13px;margin:0 0 12px}#countdown{font-family:Menlo,monospace;font-weight:600;font-size:clamp(29px,7vw,52px);letter-spacing:-2px;margin:12px 0}#date{line-height:1.8;font-size:17px}#days{display:grid;grid-template-columns:repeat(7,1fr);gap:8px;margin:28px 0}.day{border:1px solid #cedde3;border-radius:12px;text-align:center;padding:14px 3px}.day b{display:block;font-size:22px}.day span{font-size:10px;color:#617b88}.done{background:#e8f2ec;border-color:#bad7c7}.next{border:2px solid #466d83;padding:13px 2px;background:#eef5f7}#note{padding:15px;background:#f4f7f8;border-radius:12px;font-size:13px;line-height:1.8}footer{border-top:1px solid #e4ecef;margin-top:28px;padding-top:20px}button{font:inherit;border:1px solid #cedde3;border-radius:9px;padding:10px 16px;color:#153446;background:#fff;cursor:pointer}button:focus-visible{outline:3px solid #d68c37;outline-offset:3px}#account{font-size:12px;color:#617b88}@media(max-width:480px){body{padding:16px 10px}#days{gap:4px}.day{padding:12px 1px}.day span{font-size:9px}h1{font-size:20px}}
</style></head><body><main>
<header><span class="die" aria-hidden="true">⚄</span><div><h1>Anime Dice</h1><p>สมุดรับรางวัล 7 วัน · เปิดดูได้แม้ปิดเกม</p></div></header>
<section aria-live="polite"><p class="eyebrow" id="heading">วันและเวลารับครั้งถัดไป</p><div id="date"></div><div id="countdown">—</div></section>
<div id="days" aria-label="วันที่รับรางวัล"></div><p id="account"></p><p id="note"></p>
<footer><p id="sync" class="muted"></p><p class="muted">ไฟล์นี้นับเวลาต่อได้โดยไม่เปิด Roblox แต่รับรางวัลแทนคุณขณะออฟไลน์ไม่ได้ หลังรับรางวัลหรือเปลี่ยนบัญชี ให้รันสคริปต์ในเกมแล้วรีเฟรชไฟล์นี้</p><button id="refresh" type="button">อ่านข้อมูลล่าสุดจากไฟล์</button></footer>
</main><script type="application/json" id="state">__STATE_JSON__</script>
<script>
'use strict';
const state=JSON.parse(document.getElementById('state').textContent);
const $=id=>document.getElementById(id);
const valid=state.gameId===10708913337&&Number.isInteger(state.claimed)&&state.claimed>=0&&state.claimed<=7&&state.total===7&&Number.isFinite(state.serverOffset)&&Number.isFinite(state.serverObservedAt)&&(state.claimed===7||Number.isFinite(state.nextAt));
const date=t=>new Intl.DateTimeFormat('th-TH',{dateStyle:'full',timeStyle:'medium',timeZone:'Asia/Bangkok'}).format(new Date(t*1000));
function render(now=Date.now()){
 if(!valid){$('heading').textContent='ข้อมูลไม่สมบูรณ์';$('countdown').textContent='ยังคำนวณไม่ได้';$('note').textContent='เข้า Anime Dice แล้วรันสคริปต์อีกครั้ง ห้ามใช้ไฟล์จากเกมอื่น';return;}
 const left=Math.max(0,Math.ceil(state.nextAt-(now/1000+state.serverOffset)));
 $('heading').textContent=state.claimed===7?'รับครบทั้ง 7 วันแล้ว':`รางวัลวันที่ ${state.claimed+1} · รอครบ ${state.cooldown/3600} ชั่วโมงจากครั้งล่าสุด`;
 $('countdown').textContent=state.claimed===7?'ครบ 7 / 7':left===0?'ถึงเวลารับแล้ว':`${String(Math.floor(left/3600)).padStart(2,'0')} : ${String(Math.floor(left%3600/60)).padStart(2,'0')} : ${String(left%60).padStart(2,'0')}`;
 $('date').textContent=state.claimed===7?'ไม่มีรอบถัดไปในชุดรางวัลนี้':`รับรางวัลวันที่ ${state.claimed+1} ครั้งถัดไป: ${date(state.nextAt)} (เวลาไทย)`;
 $('account').textContent=`รับแล้ว ${state.claimed}/7 วัน · บัญชี ${state.userId}`;
 $('sync').textContent=`ข้อมูลเกมยืนยันล่าสุด: ${date(state.serverObservedAt)} · ไม่ใช่สถานะสดหลังออกเกม`;
 const warning={claim_unconfirmed:'ส่งคำขอแล้ว แต่เกมยังไม่ยืนยัน กรุณาเข้าเกมเพื่อตรวจสอบ — ยังไม่นับว่าได้รับรางวัล',waiting_server_confirmation:'กำลังรอเกมยืนยันการรับรางวัล — ยังไม่นับว่าสำเร็จ',state_reconciling:'ข้อมูลกำลังอัปเดต กรุณารันสคริปต์ในเกมอีกครั้ง',save_failed:'บันทึกไฟล์ไม่สำเร็จ ต้องซิงก์ใหม่'};
 $('note').textContent=warning[state.reason]||(state.claimed===7?'ครบตามสถานะล่าสุดที่เกมส่งมาแล้ว':left===0?'ถึงเวลาจากข้อมูลล่าสุดแล้ว เข้าเกมและรันสคริปต์เพื่อรับ/ยืนยันรางวัลวันถัดไป':'ปิดหน้าไฟล์หรือปิดเกมได้ เมื่อเปิดใหม่จะคำนวณเวลาที่เหลือจากวันและเวลาที่บันทึกไว้');
}
if(valid){for(let day=1;day<=7;day++){const el=document.createElement('div');el.className='day'+(day<=state.claimed?' done':day===state.claimed+1?' next':'');const b=document.createElement('b');b.textContent=day;const text=document.createElement('span');text.textContent=day<=state.claimed?'รับแล้ว':day===state.claimed+1?'รอบถัดไป':'ยังไม่ถึง';el.append(b,text);$('days').append(el);}}
$('refresh').addEventListener('click',()=>location.reload());render();setInterval(render,1000);
</script></body></html>
]=],Masterp)
