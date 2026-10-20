# little anime dice

Anime Dice daily-login reward script. Current release: **1.0.4** (Done diagnostics).

## Run on another computer

Load your existing Masterp Manager client first, enter Anime Dice, then run:

```lua
assert(loadstring(game:HttpGet("https://raw.githubusercontent.com/Pexchzq/little-anime-dice/main/main.lua")))()
```

`main.lua` is the complete self-contained 1.0.4 bundle. No source folders or Mac-specific paths are needed on the target computer. It does not install or download the Masterp client. Configure your executor's AutoExecute yourself if you want this script loaded on each visit.

Version 1.0.4 adds `[DICE-DEBUG-104]` console diagnostics for missing Done. To bypass cached older responses, use `main.lua?v=1.0.4`. Capture the summary/gate/callback lines after about 15 seconds, or run `_G.DiceDailyLogin.Debug()` for a read-only summary. Claim and Done eligibility/deduplication rules are unchanged. See [Done diagnostic guide](daily-login-1.0.4/DONE-DEBUG.md). The remote Manager symptom is not yet diagnosed or live-verified.

Version 1.0.3 fixes early AutoExecute startup: it waits for the game identity, LocalPlayer and PlayerGui before checking/binding the game, then waits for native daily data and callback readiness. It starts as soon as ready, without a fixed delay. Game/player readiness and native readiness each have a 120-second budget; genuine wrong games and timeouts still fail safely. No need to run the loader a second time when initialization completes within those budgets. See `daily-login-1.0.3/STARTUP-AUDIT.md` for the regression evidence; this fix has not yet been live-verified on the remote executor.

## Behavior

- Reads native daily-reward state and claims only when eligible (observed game cooldown: 23 hours, seven rewards).
- Saves the next reward's weekday, date and time in Thai time (UTC+07:00), plus an offline HTML countdown.
- Calls `_G.Masterp_Done()` with zero arguments only after a native claim is confirmed by both claim count and timestamp, and the next-login reports are saved and read back.
- Deduplicates completion per account and reward receipt using a local journal. If the callback outcome is uncertain, it does not blindly send it again.
- Does **not** send a new Done just because an account boots on cooldown or was previously complete. Does not launch Roblox, log into accounts, schedule rejoining, or install a background service.

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
_G.DiceDailyLogin.Stop()
```

## Source and tests

`daily-login-1.0.4/` contains current source (`daily.lua`, `masterp.lua`, `runtime.lua`), `report.html`, build script, bundle and tests. Earlier version directories are retained as historical source snapshots; use `main.lua` for the latest release.

No account captures, personal runtime reports, credentials, local shortcut files, or third-party SDK copies are published.

With Node.js and Luau installed, from `daily-login-1.0.4/`:

```sh
luau tests/daily.spec.luau
luau tests/masterp.spec.luau
node --test tests/*.spec.mjs
luau-analyze daily.lua masterp.lua
node build.mjs
luau-compile dice_daily_login_1_0_4.lua > /dev/null
```

Tests use fixtures/mocks, not live game actions or a real Manager callback. Rebuilding produces the versioned bundle; copy it to root `main.lua` when intentionally publishing a new release.
