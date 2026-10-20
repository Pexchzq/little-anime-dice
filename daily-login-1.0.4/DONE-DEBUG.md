# Done diagnostics — 1.0.4

Requested diagnostic release for a remote executor where Manager does not show Done. The remote failure's actual cause is **not yet established**. This release adds observability, not a new completion policy. Keep the diagnostic logs for the user's console capture; they are intentional, not leftover probes.

## Capture

Load `main.lua?v=1.0.4`. Wait approximately 15 seconds after the panel appears, then capture console lines prefixed `[DICE-DEBUG-104]`, especially `summary`, `done_gate`, `files_result`, `done_call_begin`, and `done_call_result`. Summaries print on state changes and at most once per 15-second heartbeat for unchanged state. Other repeated identical events are suppressed.

For an immediate read-only summary:

```lua
_G.DiceDailyLogin.Debug()
```

This command observes existing state only; it does not tick the claim/Done owners, save files, reset journals, or send a callback. Do not manually call Done or delete state files to diagnose this issue.

## Meaning

- `gate=no_verified_receipt`: no verified receipt for this script's own claim. A cooldown snapshot or already-completed login alone does not produce Done under the existing policy.
- `gate=claim_pending`: claim sent but native count AND timestamp have not both confirmed. `attempts`, `ack_day`, `ack_time` and `reason` distinguish partial acknowledgement and exhausted attempts.
- `gate=new_claim_due`: old receipt cannot complete a newly eligible claim.
- `gate=masterp_client_missing`: the integration cannot see a function at `_G.Masterp_Done`. `hook_G` and `hook_getgenv` report **types only**; a function exclusively in getgenv is diagnostic evidence of a namespace difference, not automatically used as a substitute.
- `gate=masterp_save_failed`: durable completion intent/report gate failed. `files_result ok=false stage=...` identifies the failed read/write/readback operation.
- `gate=already_reported`: the receipt was previously recorded as called. It is not sent again.
- `gate=previous_outcome_uncertain_or_cancelled`: stored dispatching/unknown/cancelled result is not blindly retried.
- `done_call_begin args=0 dispatch_saved=true`: about to enter the existing callback; not proof of Manager acknowledgement.
- `done_call_result reason=callback_returned_not_manager_ack`: callback returned without throwing; external Manager reception remains unverified.
- `done_call_result reason=callback_threw_outcome_unknown`: callback threw. The error's **type**, not its possibly sensitive raw message, is printed; there is no automatic repeat.
- `masterp_adapter_error`, `invalid_journal`, or `invalid_or_mismatched_receipt`: diagnostic gate requiring inspection, not a reason to bypass claim verification.

The log never dumps globals, user IDs, usernames, journal keys, account paths, SDK settings, raw exception messages, or credentials. No additional network endpoint or SDK download was introduced. No diagnostic log invokes Done itself. Logging failures are isolated from the dispatch path. Existing Masterp dedupe and native claim verification remain unchanged.

## Verification

The new diagnostic regression first failed on 1.0.3 because the diagnostic prefix/gates were absent. With instrumentation: 23 Node HTML/runtime tests, eight Daily Luau groups, and six Masterp mock groups pass. The additional cases cover cooldown/no receipt, global-vs-getgenv SDK visibility, durable zero-argument dispatch, reload dedupe, readback failures, thrown callback privacy/no retry, read-only Debug, and failing diagnostic sinks. Analysis of daily/masterp modules and compilation of the generated bundle pass.

No live game script, native reward claim, or real Manager callback was executed during this change. Console evidence from the target executor is still required before diagnosing or claiming to fix its Done symptom.
