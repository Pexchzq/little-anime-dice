local Daily,template,Masterp=...
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
