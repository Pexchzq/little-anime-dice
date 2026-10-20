-- GENERATED Anime Dice Daily Login 1.0.1
local Daily=assert(loadstring([=[-- Pure schedule and bounded claim owner; all external IO is injected.
local Daily={Version='1.0.1',GameId=10708913337}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
local function integer(n)return finite(n)and n>=0 and n%1==0 end
local function copy(t)local o={};for k,v in pairs(t)do o[k]=type(v)=='table'and copy(v)or v end;return o end
function Daily.NextText(s)
    if type(s)~='table'then return'ยังไม่มีวันและเวลาที่เกมยืนยัน'end
    if s.claimed==7 and s.phase=='complete'then return'รับครบทั้ง 7 วันแล้ว — ไม่มีรอบถัดไปในชุดนี้'end
    if not finite(s.nextAt)or s.nextAt<1 or not integer(s.claimed)or s.claimed>=7
        or s.nextDay~=s.claimed+1 then return'ยังไม่มีวันและเวลาที่เกมยืนยัน'end
    -- Explicit UTC +07:00, independent of the Mac/executor's local timezone.
    local d=os.date('!*t',math.floor(s.nextAt)+25200)
    local days={'อาทิตย์','จันทร์','อังคาร','พุธ','พฤหัสบดี','ศุกร์','เสาร์'}
    local months={'มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน','กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม'}
    return string.format('รับรางวัลวันที่ %d ได้ตั้งแต่\nวัน%sที่ %d %s %d เวลา %02d:%02d:%02d น. (เวลาไทย)',
        s.nextDay,days[d.wday],d.day,months[d.month],d.year+543,d.hour,d.min,d.sec)
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
                if s.claimed>pending.claimed and s.lastClaim>pending.lastClaim then s.reason='claim_verified';pending=nil
                else
                    s.nativeClaimed=s.claimed;s.claimed=pending.claimed;s.lastClaim=pending.lastClaim
                    s.nextDay=pending.claimed+1;s.nextAt=pending.lastClaim+s.cooldown;s.phase='ready'
                    s.enabled=enabled;s.pending=copy(pending);s.reason='state_reconciling';last=s;store(s);return
                end
            end
            s.enabled=enabled;s.pending=pending and copy(pending)or nil;last=s
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
return assert(loadstring([=[local Daily,template=...
assert(game.GameId==Daily.GameId,'This script is for Anime Dice only')
assert(type(writefile)=='function'and type(readfile)=='function'and type(isfile)=='function','Executor file access required')
local P=game:GetService('Players');local H=game:GetService('HttpService')
local untilAt=os.clock()+60
while(not game:IsLoaded()or not P.LocalPlayer or not P.LocalPlayer:FindFirstChild('PlayerGui'))and os.clock()<untilAt do task.wait(.25)end
local player=assert(P.LocalPlayer,'Player not ready');local gui=assert(player:FindFirstChild('PlayerGui'),'PlayerGui not ready')
local old=rawget(_G,'DiceDailyLogin')
if old then assert(old.Owned==true and type(old.Stop)=='function','Existing daily script owner conflict');old.Stop()end
local data,config,callback
local function findNative()
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
    return data and type(data.___X)=='table'and config and type(config.Rewards)=='table'and callback
end
while not findNative()and os.clock()<untilAt do task.wait(1)end
assert(data and config and callback,'Daily reward data/button not ready; rerun after loading the lobby')
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
local alive=true;local lastWrite=-math.huge;local signature;local owner;local screen
local function save(s,force)
    local pending=s.pending
    local sig=table.concat({s.claimed,s.lastClaim,s.cooldown,s.phase,s.reason or'',tostring(s.enabled),pending and pending.attempts or 0},':')
    if not force and sig==signature and os.clock()-lastWrite<60 then return true end
    local ok,why=pcall(function()
        s.nextLoginText=Daily.NextText(s)
        local raw=H:JSONEncode(s)
        if isfile(statePath)then local previous=readfile(statePath);writefile(statePath..'.backup',previous);assert(readfile(statePath..'.backup')==previous,'backup_readback_failed')end
        writefile(statePath,raw);assert(readfile(statePath)==raw,'state_readback_failed')
        local safe=raw:gsub('<','\\u003c');local html=template:gsub('__STATE_JSON__',function()return safe end)
        writefile(reportPath,html);assert(readfile(reportPath)==html,'report_readback_failed')
        writefile(latestReport,html);assert(readfile(latestReport)==html,'latest_report_readback_failed')
        local text='Anime Dice · รับรางวัล 7 วัน\n'..s.nextLoginText..'\n\nบันทึกจากสถานะที่เกมยืนยันล่าสุด ไม่ใช่การรับรางวัลขณะออฟไลน์\n'
        writefile(textPath,text);assert(readfile(textPath)==text,'text_readback_failed')
        writefile('dice_daily_next_login.txt',text);assert(readfile('dice_daily_next_login.txt')==text,'latest_text_readback_failed')
    end)
    if ok then signature=sig;lastWrite=os.clock()end
    return ok,not ok and('save_failed: '..tostring(why))or nil
end
owner=Daily.Create({read=function()
    assert(game.GameId==Daily.GameId,'wrong_game')
    local cache=data.___X
    return{gameId=game.GameId,userId=player.UserId,claimed=cache.DailyRewardsClaimed,lastClaim=cache.LastDailyRewardClaim,
        total=#config.Rewards,cooldown=config.Cooldown,serverNow=workspace:GetServerTimeNow(),localNow=os.time()}
end,save=save,claim=function()
    assert(alive,'stopped');callback() -- Existing zero-argument UI callback, not a guessed wire call.
end},{enabled=true,pending=existing and existing.pending})
screen=Instance.new('ScreenGui');screen.Name='DiceDailyLogin_101';screen.ResetOnSpawn=false;screen.Parent=gui
local box=Instance.new('Frame');box.Size=UDim2.fromOffset(360,215);box.Position=UDim2.new(1,-375,0,65);box.BackgroundColor3=Color3.fromRGB(238,245,247);box.Parent=screen
local round=Instance.new('UICorner');round.CornerRadius=UDim.new(0,12);round.Parent=box
local label=Instance.new('TextLabel');label.Size=UDim2.new(1,-24,0,165);label.Position=UDim2.fromOffset(12,6);label.BackgroundTransparency=1;label.TextWrapped=true;label.TextSize=14;label.Font=Enum.Font.Arial;label.TextColor3=Color3.fromRGB(21,52,70);label.Parent=box
local auto=Instance.new('TextButton');auto.Size=UDim2.fromOffset(185,30);auto.Position=UDim2.fromOffset(12,175);auto.TextSize=13;auto.Parent=box
local close=Instance.new('TextButton');close.Size=UDim2.fromOffset(112,30);close.Position=UDim2.fromOffset(231,175);close.Text='หยุด / ปิด';close.TextSize=13;close.Parent=box
local connections={};local api={Owned=true,Version=Daily.Version,StatePath=statePath,ReportPath=reportPath}
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
api.Status=owner.Status
api.Stop=function()
    if not alive then return true end;alive=false;owner.Stop()
    for _,c in ipairs(connections)do c:Disconnect()end
    if screen then screen:Destroy()end
    return true
end
connections[#connections+1]=auto.Activated:Connect(function()display(owner.SetEnabled(not owner.Status().enabled))end)
connections[#connections+1]=close.Activated:Connect(api.Stop)
_G.DiceDailyLogin=api
local s=owner.Tick();display(s)
print('[DICE-DAILY-101] '..H:JSONEncode({phase=s.phase,claimed=s.claimed,nextAt=s.nextAt,report=reportPath}))
print('[DICE-DAILY] '..Daily.NextText(s))
task.spawn(function()
    while alive do task.wait(2);if alive then display(owner.Tick())end end
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
]=])
