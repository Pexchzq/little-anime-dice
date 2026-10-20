# AutoExecute startup fix — 1.0.3

## Report and reproduction

The user's first AutoExecute failed with `dice-daily/runtime:2: This script is for Anime Dice only`; manually running again worked. Version 1.0.2 checked GameId before waiting for the game to load. A deterministic fixture using the actual runtime source reproduced the same line-2 exception when GameId was initially zero. This demonstrates an initialization race consistent with the screenshot, not a live measurement of the remote computer's GameId.

Before patch: `node --test --test-name-pattern=AutoExecute tests/runtime.spec.mjs` failed with that exact exception. After patch: the same scenario passes.

## Changes

- Wait for `game:IsLoaded()` and a positive GameId, then enforce the existing Anime Dice universe guard.
- Wait for LocalPlayer, a positive UserId, and PlayerGui before binding native UI/data.
- Initial game/player readiness budget: 120 seconds. Native module, numeric state and exact callback readiness get a separate 120-second budget.
- Poll readiness; do not add a fixed 10/30-second sleep. Retry transient callback inspection failures without claiming.
- Reject genuinely wrong games and fail safely on readiness timeout. Keep an existing owner running until the new native binding is ready.
- Keep claim verification, disk-readback gates, next-login reporting and Masterp completion behavior unchanged.

## Verification

- Eight pure Daily behavior groups pass.
- Five Masterp mock behavior groups pass.
- Eighteen Node HTML/runtime tests pass, including seven startup regressions: late identity, late player/GUI, separate native budget plus transient inspection error, partial native state, wrong-game identity, identity timeout, native timeout preserving an existing owner.
- `luau-analyze daily.lua masterp.lua` passes.
- Generated 1.0.3 bundle compiles with `luau-compile`.
- No temporary debug instrumentation added. No live game script, reward callback or real Masterp Done was executed during this fix.

The remote executor's next fresh AutoExecute remains the required live verification. The runtime still requires its documented native callback introspection APIs.
