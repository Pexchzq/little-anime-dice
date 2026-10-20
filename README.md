# little anime dice

Anime Dice daily-login reward script. Current release: **1.0.5** (Description + already-claimed Done + official client bootstrap).

## Run on another computer

While inside Anime Dice on the computer running Masterp Manager, run this single loader (suitable for executor AutoExecute):

```lua
assert(loadstring(game:HttpGet("https://raw.githubusercontent.com/Pexchzq/little-anime-dice/v1.0.5/main.lua")))()
```

`main.lua` is the complete self-contained 1.0.5 bundle. No source folders or Mac-specific paths are needed on the target computer. Configure your executor's AutoExecute yourself if you want this script loaded on each visit. The version tag above avoids stale cached branch contents; `main/main.lua` remains the moving latest bundle.

Version 1.0.5 sends the account's one-string Description (received today or not, current-cycle status, next full Thai date/time) before Done. Already-claimed native cooldowns qualify without a fresh script receipt. It reuses existing Masterp hooks or asynchronously loads the exact official Quick Start client if neither hook exists. Existing settings are preserved. See [policy and verification](daily-login-1.0.5/MANAGER-POLICY.md).

The developer Mac's HTTP check of the official CDN returned HTML; the target computer may differ. The loader rejects HTML and logs the failure rather than pretending to connect. `[DICE-DEBUG-105]` reports bootstrap, Description and Done stages. `_G.DiceDailyLogin.Debug()` prints an immediate read-only summary. Real remote Manager reception remains unverified.

Version 1.0.3 fixes early AutoExecute startup: it waits for the game identity, LocalPlayer and PlayerGui before checking/binding the game, then waits for native daily data and callback readiness. It starts as soon as ready, without a fixed delay. Game/player readiness and native readiness each have a 120-second budget; genuine wrong games and timeouts still fail safely. No need to run the loader a second time when initialization completes within those budgets. See `daily-login-1.0.3/STARTUP-AUDIT.md` for the regression evidence; this fix has not yet been live-verified on the remote executor.

## Behavior

- Reads native daily-reward state and claims only when eligible (observed game cooldown: 23 hours, seven rewards).
- Saves the next reward's weekday, date and time in Thai time (UTC+07:00), plus an offline HTML countdown.
- Sends `_G.Masterp_Description(message)` with received-today status, current-cycle status, last receipt and next weekday/date/time (UTC+07:00); no Sheet payload.
- Calls zero-argument `_G.Masterp_Done()` when native state shows this reward cycle already received, including a previously claimed account at startup and final-day completion. A currently pending claim must still be confirmed by count AND timestamp. Next-login files and dispatch intent must be saved/read back, and Description must return before Done.
- Deduplicates once per reward cycle per live Roblox session. Reload does not repeat the same session's Done; a new Roblox VM can report completion to the new Manager run. An uncertain same-session callback is not blindly retried.
- Does not launch Roblox, log into accounts, schedule rejoining, or install a background service. An already-existing client (including a partial initialization) is not overwritten. When both hooks are missing, the official CDN client is attempted once with Quick Start defaults only if existing settings are absent.

Masterp's documented Done behavior is to close a completed account and switch to the next account. That manager behavior is external to this script. See the [reviewed upstream API](https://github.com/Achitsak/masterp-manager/blob/13163fec08667855fac7afdd091c9fd764569e93/loader/README.md).

## Target executor requirements

Requires `loadstring`, `game:HttpGet`, `getloadedmodules`, `getconnections`, `debug.info`, `debug.getupvalues`, `readfile`, `writefile`, and `isfile`. Executors without these capabilities are not supported by the current native-callback adapter. Cross-executor/Windows operation and the real Masterp completion flow have **not** been live-verified for this release.

Universe ID: `10708913337`. The script rejects other games. If the game's native data or callback contract changes, it stops rather than guessing a new remote payload.

## Output files

These are written into **the target executor's workspace**, not a fixed Mac directory:

- `dice_daily_next_login.txt` and `dice_daily_next_login.html`: latest account's next appointment.
- `dice_daily_<UserId>_next_login.txt` and `dice_daily_<UserId>.html`: per-account reports.
- `dice_daily_<UserId>_state.json` and `.json.backup`: observed state, pending claim and completion journal.

Open the HTML/TXT after leaving the game to view the next appointment. Refresh an already-open report after a new claim. The report works offline but cannot claim rewards while Roblox is closed. Local state is not automatically transferred between computers; the native game state remains authoritative.

```lua
_G.DiceDailyLogin.Status()
_G.DiceDailyLogin.Debug()
_G.DiceDailyLogin.Stop()
```

## Source and tests

`daily-login-1.0.5/` contains current source (`daily.lua`, `masterp.lua`, `runtime.lua`), `report.html`, build script, bundle and tests. Earlier version directories are retained as historical source snapshots; use `main.lua` for the latest release.

No account captures, personal runtime reports, credentials, local shortcut files, or third-party SDK copies are published.

With Node.js and Luau installed, from `daily-login-1.0.5/`:

```sh
luau tests/daily.spec.luau
luau tests/masterp.spec.luau
node --test tests/*.spec.mjs
luau-analyze daily.lua masterp.lua
node build.mjs
luau-compile dice_daily_login_1_0_5.lua > /dev/null
```

Tests use fixtures/mocks, not live game actions or a real Manager callback. Rebuilding produces the versioned bundle; copy it to root `main.lua` when intentionally publishing a new release.
