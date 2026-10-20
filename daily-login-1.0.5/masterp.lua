-- Documented Manager callbacks only; no private Manager transport protocol.
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
