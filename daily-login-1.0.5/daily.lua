-- Pure schedule and bounded claim owner; all external IO is injected.
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
