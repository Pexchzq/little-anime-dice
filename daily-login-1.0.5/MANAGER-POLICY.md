# Manager policy — 1.0.5

## User requirements

An account that already received its current daily reward must be marked Done in Manager even when the reward was claimed before this script started. Send the account Description before Done, including whether it claimed today and the next weekday/calendar date/time. Do not require a fresh script-generated receipt just to recognize existing native completion.

## Implementation

- Uses native validated claim count, last-claim timestamp, configured cooldown and phase. Native waiting/cooldown with at least one claimed reward, or final seven-day completion, qualifies for Done. Ready, unknown, invalid and pending/partially acknowledged claims do not qualify.
- `_G.Masterp_Description(message)` is called with one string, no Google Sheet payload. Text changes are sent; identical text is not resent every tick. Done requires Description to have returned without throwing and local schedule/journal readback to succeed.
- Description includes actual Thai-calendar "today" claim status, current reward-cycle status, accumulated days, last receipt date/time and next appointment date/time in UTC+07:00. Yesterday's claim can still be on the current 23-hour cooldown; it is not falsely labelled as received today. Day 7 has no invented day 8.
- `_G.Masterp_Done()` is zero-argument. Both documented hooks may be resolved from `_G` or `getgenv()` without rewriting SDK globals.
- Deduplication is once per native reward cycle per live Roblox session. Reloading the script in the same VM does not repeat Done. A new Roblox VM/rejoin creates a new session token and may report the same completed native cycle again for the new Manager run. The old receipt-only journal is migrated without deleting it. Same-session uncertain dispatch is not blindly repeated. A Manager task reset without restarting the same Roblox VM is not separately detectable through the documented API.

## Official client bootstrap

The user supplied both the client.lua page and full Quick Start. Reviewed [root README](https://github.com/Achitsak/masterp-manager/blob/13163fec08667855fac7afdd091c9fd764569e93/README.md), [API](https://github.com/Achitsak/masterp-manager/blob/13163fec08667855fac7afdd091c9fd764569e93/loader/README.md), and client.lua. The bootstrap uses their exact `https://cdn.masterpx.xyz/s/masterp-manager/client` endpoint after game/player readiness. Quick Start defaults (`Performance=false`, `UnlockFPS.Enable=false`, `TargetFps=10`) are set only if no existing `_G.MasterpSettings` is present.

An existing full or partial client is not overwritten or reloaded. If neither documented hook exists, one asynchronous attempt is made per VM. Reject empty/oversized/HTML/uncompilable responses; do not print downloaded code or raw errors. Stop during download prevents subsequent evaluation. No private Manager transport, guessed endpoint, credential setup or Sheet payload is introduced. The official external client runs only when the user runs the bundle, not during this development task.

Read-only HTTP from the development Mac returned HTML from that CDN. This is not proof of what the target executor receives. `[DICE-DEBUG-105] sdk_bootstrap phase=client_response_is_html` explicitly identifies that failure on the target. Missing hooks are not faked and the script cannot mark a disconnected Manager Done. There is no automatic retry of an uncertain SDK execution; a late externally installed client is still detected normally.

## Verification

The native-cooldown regression failed on 1.0.4 (no receipt -> no Done). With 1.0.5: 36 Node HTML/runtime tests, eight Daily Luau groups and ten Manager mock groups pass. Cases cover Description-before-Done, already-claimed/no-reclaim, fresh claims, calendar midnight/23h distinction, final day, namespace resolution, same/new-session and legacy journal behavior, missing/erroring SDK hooks, file failure, SDK defaults preservation, official-client mock loading, HTML/HTTP/compile failures and Stop during download. Daily/Masterp analysis and complete bundle compilation pass.

These are fixture/static checks, not live proof that the real Windows Manager received the calls. No real game script, native claim or Manager callback was executed during this change. Older audit files retained in this version's directory describe earlier versions only; this document defines the new completion policy.
