local Daily,template=...
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
