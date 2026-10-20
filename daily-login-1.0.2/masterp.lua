-- Optional callback integration. No SDK downloads or network calls of its own.
local Masterp={}
local function copy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
local function int(n)return type(n)=='number'and n==n and n>=0 and n<math.huge and n%1==0 end
local phases={pending=true,dispatching=true,called=true,unknown=true,cancelled=true}
function Masterp.Create(deps,previous)
    local journal=previous and copy(previous)or nil;local stopped=false;local busy=false;local invalid=false
    if journal and(type(journal)~='table'or type(journal.key)~='string'or not phases[journal.phase]
        or not int(journal.claimed)or not int(journal.lastClaim))then
        invalid=true;journal={phase='invalid',reason='masterp_journal_invalid'}
    end
    local api={}
    function api.Status()return copy(journal)end
    function api.Stop()stopped=true end
    function api.Tick(s)
        if stopped or busy or invalid then return api.Status()end
        busy=true
        local ok=pcall(function()
            local r=type(s)=='table'and s.claimReceipt
            if type(r)~='table'or s.pending~=nil or s.phase=='ready'or s.gameId~=10708913337 or not int(s.userId)or s.userId<1
                or not int(r.claimed)or r.claimed<1 or r.claimed>7 or not int(r.lastClaim)or r.lastClaim<1
                or r.claimed~=s.claimed or r.lastClaim~=s.lastClaim then return end
            local key=table.concat({s.gameId,s.userId,r.claimed,r.lastClaim},':')
            if journal and journal.key==key and journal.phase~='pending'then return end
            if not journal or journal.key~=key then
                if journal and r.claimed<=journal.claimed and r.lastClaim<=journal.lastClaim then return end
                journal={key=key,claimed=r.claimed,lastClaim=r.lastClaim,phase='pending'}
            end
            local hook=deps.hook()
            if type(hook)~='function'then
                journal.reason='masterp_client_missing';deps.save(copy(journal),s);return
            end
            journal.phase='dispatching';journal.reason=nil
            local saved=deps.save(copy(journal),s,true)
            if saved~=true then journal.phase='pending';journal.reason='masterp_save_failed';return end
            if stopped then journal.phase='cancelled';deps.save(copy(journal),s,true);return end
            -- No arguments, exactly as documented in loader/README.md.
            local called=pcall(hook)
            journal.phase=called and'called'or'unknown'
            journal.reason=not called and'masterp_callback_outcome_unknown'or nil
            deps.save(copy(journal),s,true)
        end)
        busy=false
        if not ok and journal then
            if journal.phase=='dispatching'then journal.phase='unknown'end
            journal.reason='masterp_adapter_error'
        end
        return api.Status()
    end
    return api
end
return Masterp
