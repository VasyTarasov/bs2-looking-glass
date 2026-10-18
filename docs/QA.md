# Verification of 0.92-dev

Local Windows development checks; no stable release or remote CI claim.

| Native check | Result | Assertions |
|---|---|---:|
| new_classic | PASS | 24 |
| new_hd | PASS | 50 |
| ux_classic | PASS | 45 |
| ux_hd | PASS | 58 |
| reference_classic | PASS | 7562 |
| reference_hd | PASS | 7565 |
| weapons | PASS | 1077 |
| modules | PASS | 69 |
| minimal | PASS | 22 |

Total: **16472 native assertions**. Each passed run used the hardened private-desktop launcher, exit code 0 and `result=PASS`. The player game was never used as a test fixture, and personal saves were not read.

The old F4 dispatcher was substituted into a synthetic fixture as a negative control. F4 → H reproduced the dead end and the bounded test deliberately failed; restoring the fix passes in classic and active HD. Nested F7 returns and interrupted-modal cleanup are covered.

HD tests include actual F10 key input, saved-size reuse, sharp-filter enforcement, independent startup preference, preservation of custom key conflicts, real own-window minimize/restore before deferred startup placement, and repair after a late native resize. The title-only DPI restart guard is also covered by the UX regression suite. V/M palette rows are checked for estimates below their descriptions; AoE retains an explicit total. Forecasts preserve battlers and RNG.

Installer: **55 assertions**. Update/rollback from 0.9.8-alpha: **155 assertions**. Update from the archived 0.91-dev package: **69 assertions**. These use synthetic files and test live-process refusal, integrity checks and rollback. Game-free repository tests: **18**. Three PowerShell scripts parse with UTF-8 BOM under Windows PowerShell 5.1; the installer headless check confirms English default, Russian switch and 22 modules.

The remaining native sets audit every named reference card, journal details, 105 weapon scenarios, navigation, support restrictions and module combinations. Source/runtime asset hashes and repository privacy/link checks are validated before packaging. Original description prose remains removed from 2,602 English alias entries. The two runtime assets are explicitly allowlisted.

Steam recording playback/export, every monitor/driver/DPI combination and live recovery of an already stuck older session are not claimed. The update takes effect only in a new game process. In-game reference text remains predominantly Russian. Remote game-free CI passed for the uploaded implementation commit b82849c; see [GitHub verification](https://github.com/VasyTarasov/bs2-looking-glass/actions/runs/39130135207). Native counts above come from local isolated runs.
