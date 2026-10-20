# little anime dice

Anime Dice daily-login reward script. Current release: **1.0.2**.

## Run on another computer

Load your existing Masterp Manager client first, enter Anime Dice, then run:

```lua
assert(loadstring(game:HttpGet("https://raw.githubusercontent.com/Pexchzq/little-anime-dice/main/main.lua")))()
```

`main.lua` is the complete self-contained 1.0.2 bundle. No source folders or Mac-specific paths are needed on the target computer. It does not install or download the Masterp client. Configure your executor's AutoExecute yourself if you want this script loaded on each visit.

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

`daily-login-1.0.2/` contains current source (`daily.lua`, `masterp.lua`, `runtime.lua`), `report.html`, build script, bundle and tests. Earlier `daily-login-1.0.0/` and `daily-login-1.0.1/` are retained as historical source snapshots; use `main.lua` for Masterp support.

No account captures, personal runtime reports, credentials, local shortcut files, or third-party SDK copies are published.

With Node.js and Luau installed, from `daily-login-1.0.2/`:

```sh
luau tests/daily.spec.luau
luau tests/masterp.spec.luau
node --test tests/*.spec.mjs
luau-analyze daily.lua masterp.lua
node build.mjs
luau-compile dice_daily_login_1_0_2.lua > /dev/null
```

Tests use fixtures/mocks, not live game actions or a real Manager callback. Rebuilding produces the versioned bundle; copy it to root `main.lua` when intentionally publishing a new release.
