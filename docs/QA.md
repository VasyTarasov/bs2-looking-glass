# Verification of 0.991-dev

Local isolated Windows checks; experimental development build, no stable release.

| Native check | Result | Assertions |
|---|---|---:|
| changes_classic | PASS | 65 |
| changes_hd | PASS | 96 |
| reference_classic | PASS | 7562 |
| reference_hd | PASS | 7565 |
| weapons | PASS | 1077 |
| modules | PASS | 69 |
| minimal | PASS | 22 |
| bench | PASS | 4 |

**16460 native assertions** across 8 current sets. The same hardened private-desktop launcher requires exit code 0 and result=PASS. Personal saves and the live player process were not used as fixtures.

Coverage includes real WASZ input and item-list exclusions, preserved D, removed F5 command, actual breathing/mist under H without AP/state/resource/RNG changes, F4/H/F7 nesting and cleanup, AoE minimum/maximum/sum, bounded rolling history, frequency thresholds, cooldown, preference reload, actual use tracking, duplicate-finish protection, tempo integration/knowledge/RNG safeguards, cache reuse/invalidation and deferred sidebar calculation. Reference sets cover all named cards and 105 weapon scenarios.

## Palette CPU timing

Same synthetic battle, same HD mode, 30 repetitions per group. These measure Ruby palette row construction, not end-to-end key or GPU latency. GetTickCount resolution is coarse; zero means below clock resolution.

Before (0.92-dev):

```text
V stable_30_ms=140 selection_30_ms=422
M stable_30_ms=16 selection_30_ms=125
N stable_30_ms=63 selection_30_ms=406
```

After (0.991-dev):

```text
V stable_30_ms=0 selection_30_ms=31
M stable_30_ms=0 selection_30_ms=31
N stable_30_ms=0 selection_30_ms=32
```

Installer: 55 assertions. Update/rollback from 0.9.8-alpha: 163 assertions. Update from archived 0.92-dev: 73 assertions; the same migration is checked with Git-style LF Ruby sources. Known line-ending variants are accepted by verified canonical hashes; code edits remain refused. Synthetic settings/save sentinels and engine assets are retained, foreign changes/running games are refused, and partial writes roll back. Game-free repository checks: 19. Three PowerShell scripts parse with BOM under Windows PowerShell 5.1; headless installer confirms English default, Russian switch and 22 modules.

Steam overlay, HD mouse interaction and screenshots are confirmed by the player during normal play. The native bridge DLL is unchanged in this preview. Recording playback/export was not retested. Remote CI is checked after upload; native counts above are local results.

The tempo aid is conditional on current effects/AP rates, not a future enemy-AI simulation; repeated enemy turns and future effects can change it. Adaptive ordering is opt-in and records only completed battles while enabled. All monitor/driver combinations are not claimed. In-game mechanics text remains predominantly Russian. Runtime assets, staged content and archive hashes are audited before publication.
