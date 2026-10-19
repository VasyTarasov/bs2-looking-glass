# Verification of 0.999-dev

Development build. Thirteen final-build native suites pass with exit code 0 and `result=PASS` on the hardened private desktop: **605 assertions**. Synthetic fixtures only; no player saves or live-player input.

| Native suite | Assertions |
|---|---:|
| Grouped macros, numeric editor, executor, Space, double Esc and actual damage | 37 |
| Macros without Effects, Reference Cards or Controls | 6 |
| Probability-branch sequences | 12 |
| Existing queue/executor/macro UI | 53 |
| Sole/source/final weapon and multi-target estimates | 57 |
| Classic/HD broad interaction regressions | 98 + 130 |
| Classic/HD item, support and reference interactions | 45 + 58 |
| All modules / no optional modules | 69 + 22 |
| Normal / instant-Ctrl full battles | 9 + 9 |

The new suite runs 400 native executions of each reported pair, using actual database formulas/states and normal native target/effect/cost paths. Self-flagellation → Triple Shot: predicted second-action mean **12,526.8**, observed **12,576.5** (0.40% difference). Jubjub normal ID → Two-Handed Sword: predicted **1,456.4**, observed **1,498.52** (2.81%). Sampling checks permit 8% because hit/critical/variance draws remain native; these synthetic values are not the player's build. The random-attack UI must match the entire projected shot total. Live battlers, stock, cooldown data and RNG are unchanged by previews. Twenty uncached two-action estimates averaged about 14 ms in this fixture; this is a local timing observation, not a whole-game FPS claim.

Actual editor input tests choose a numbered weapon row. Native engine-frame captures were inspected for numbered choices and the two-line action/MP/cooldown picker. Repeated cached N rendering must contain exactly one Shift hint. A real instant MP-restoration row must fund the following paid skill even when current MP is insufficient. Double Esc preserves the allocated slot count and actual prior consumable effects; a preset's local guard executor must match forecast and preparation while leaving N unchanged.

Installer: **55** assertions. Update from 0.998-dev: **186** assertions including foreign-edit/running-game refusal, partial-write rollback, new-file removal during rollback, synthetic profile migration, byte-preserved names/rows, backup, idempotence and mixed-format refusal. Repository tests: **21**. PowerShell 5.1 validation passes without a visible installer. The engine, game script table, reference database and native Steam/HD helper are unchanged.

# Verification of 0.998-dev

Focused dependency fix on the verified 0.997-dev base below. Final-build native checks: reduced-module macro picker/editor **6**, full queue/weapon/macro UI **53**, all modules **69**, no optional modules **22** — **150 assertions**, all with exit code 0 and `result=PASS` on the hardened private desktop. The reduced fixture actually omits Effects, Reference Cards and Controls and exercises C dispatch/close and harmless F7 in the editor.

Installer: **55** assertions. Verified update from 0.997-dev, running-game/foreign-edit refusal, partial-write rollback and synthetic profile/save preservation: **178** assertions. Repository checks: **19**. PowerShell 5.1 installer validation is headless. The original scripts, engine and Steam bridge DLL are unchanged from 0.997-dev; the 1440p map and full battle evidence below still describe that base.

# Verification of 0.997-dev

Development preview; no stable release. Native QA uses only the hardened private-desktop launcher, exit code 0 and `result=PASS`. Tests use synthetic saves and a Steam-free fixture. No public test windows or player-game input.

| Native suite | Assertions |
|---|---:|
| Current queue/executor/macros and actual UI | 53 |
| Starting/sole/final weapon and target reference regression | 57 |
| 1440p map effect/capture/diagnostic replay | 10 |
| All 147 ring types, duplicate equipment and save/load | 157 |
| Probability-branch sequence forecasting | 12 |
| Existing classic/HD interaction regressions | 98 + 130 |
| Logging / all modules / minimal modules | 8 + 69 + 22 |
| Four full normal / instant-Ctrl battle scenarios | 9 + 9 |

**634 native assertions**, plus **20 matched battle comparisons** covering actual uses/costs, effects/damage, state/rewards, result and RNG tail in normal versus instant presentation. Installer checks: 55. Verified updates from 0.995-dev and 0.996-dev, foreign-edit/running-game refusal, injected partial-write rollback, source-file and synthetic-profile preservation: 356 assertions. PowerShell 5.1 validation runs without opening UI.

The new UI test enters an instant item after an already selected paid action, resumes exactly slot two, forecasts the next attack, and commits through the real native turn boundary before testing final equipment. It checks sole technique source versus magic executor, healing/self-state and normal-attack TP propagation, interleaved instant macro rows, paid budgets, persistence/failed writes, missing-item cancellation, both Shift attack routes, repeated C opening/closing, HD sidebar placement and nested H return. Macro forecasting projects scheduled instant effects without changing the live world or RNG.

The 1440p map check restores the exact camera position, checks source pixels and rendered wave/scroll phase against the original full-map effect, releases the owned padded crop, and verifies that the native capture fence suppresses temporary frames then resumes presentation. The bridge change adds this explicit fence; game/engine/Steam API files are not replaced. Steam overlay behavior was previously confirmed in normal play; this isolated run does not claim another live Steam recording test.

In a controlled replay of 2400 repeated map-command sites, individual records cost 11,485 ms versus 46 ms for four aggregate records. Real state/inventory/resource changes still receive individual records. This isolates diagnostic overhead, not whole-game FPS. Both full-map and cropped heat-render runs reached the fixture's 60 FPS cap (180 frames each), so no FPS gain is attributed to cropping from that measurement. Continued normal play and five-second diagnostic summaries are still needed to assess every reported map slowdown.

Rings are excluded by equipment type, not by names or a fixed list. Every duplicate and lower upgrade tier remains. The 0.996-dev predecessor also passed 157 checks both with and without diagnostics. Existing losses are not automatically guessed/refunded: targeted recovery requires attributable backups or local logs. No player saves/logs/recovery plans are distributed.

# Previous 0.995-dev verification

Diagnostics extension, not a claimed slowdown fix. Five native suites on the hardened private desktop: diagnostics probe 28 assertions, diagnostics-only probe 28, existing logging replay 8, all modules 69, minimal modules 22 — **155 assertions**. Synthetic state and RNG are unchanged by observers; exceptions/return values propagate; disabled/closed tracing does not accumulate; preferences reload; context/phase/slow-row caps and histogram overflow labels are checked. Native frame-counter jumps cannot fabricate huge FPS; known transitions break ordinary frame intervals. Real frame calls emit bounded, valid JSON performance records, including modal/focus labels and diagnostic/window timing.

No live-player input or saves are used. The initial 181-second external observation ran without native tests; subsequent synthetic QA used a below-normal launcher priority and the unchanged private-desktop/job/error-dialog containment. Parser validation confirms the synthetic performance records are JSON and respect all caps. Microbenchmarks are noisy under a concurrently active game; they are not a universal zero-overhead claim.

Installer: 55 assertions. Update/refusal/injected-partial-write rollback from 0.993-dev and 0.994-dev: 345 assertions. Game-free repository checks: 19; PowerShell 5.1 installer validation runs without UI. No game/engine/Steam bridge binary changes. New code is not injected into the running player process; collection begins on its next launch after updating. No player logs or external observation data are published.

The profiler keeps only five-second aggregates with a maximum of 16 contexts, 32 phase rows and eight slow examples. No ObjectSpace walk or per-frame file flush. Native self-process counters are sampled only when publishing. Phase timings are inclusive and can overlap; Graphics.update includes pacing/presentation. Explicit overlay, save/load and graphics-transition waits are excluded from ordinary consecutive-frame intervals but separately timed. Unknown pauses remain visible in long-gap counters, with an additional FPS excluding gaps over one second. Focus transitions that occur entirely inside an opaque native wait cannot always be reconstructed. Existing 0.993 heartbeat FPS remains a coarse legacy measure; the new performance records are the detailed source.

# Previous 0.994-dev verification

Development preview; native runs use only the hardened private-desktop launcher, with exit code 0 and result=PASS required. Synthetic fixtures only; no live-player controls or personal saves.

## Current Ctrl presentation checks

| Native suite | Assertions |
|---|---:|
| speed_classic | 48 |
| speed_hd (2560×1440) | 49 |
| speed_minimal (no optional modules) | 48 |
| system_normal | 9 |
| system_instant | 9 |
| resources_classic (40 cycles) | 48 |
| changes_classic | 98 |
| changes_hd | 130 |
| modules | 69 |
| minimal | 22 |

The dedicated tests exercise real native transition/fade calls, all standard collapse/appearance effects including boss collapse, active-animation sprite disposal, popup disposal, window animation, picture/screen effects, cooperative event waits, preference reload and the real settings handler. Held Ctrl leaves command input manual and does not advance AP or frame-state counters through skipped presentation waits. Map/menu behavior and exception-safe transition scope restoration are checked.

Four full battles run with identical seeds and Ctrl held in normal versus instant mode. Twenty comparisons match: action use sequence/costs, per-target effects/damage, final party/inventory/gold/experience state, result and RNG tail. Controlled visual initialization and mist are isolated by the documented QA option. The native hit-shake path uses the separate visual RNG in the installable mod, in both modes.

| Scenario | Normal frames | Instant frames |
|---|---:|---:|
| Items and attacks | 689 | 81 |
| Magic | 543 | 133 |
| Escape | 75 | 37 |
| Allowed defeat | 307 | 112 |

These are complete input-driven synthetic flows, not just animation duration. CPU/resource loading and native AP scheduling still consume time. No claim is made that every custom event/movie becomes zero-time. Choices and conditional forced-action waits are not bypassed.

Installer: 55 assertions. Update/refusal/partial-write rollback from 0.9.8-alpha, 0.991-dev and 0.993-dev: 501 assertions, preserving engine/scripts and synthetic save/profile sentinels. Game-free repository checks and PowerShell 5.1 validation run before packaging. No engine or Steam bridge binary changes.

# Previous 0.993-dev resource evidence

Development preview; no stable release. All native checks use the hardened private-desktop launcher and require exit code 0 plus result=PASS. No personal saves, live-player input or public test windows.

| Fixed-build native suite | Assertions |
|---|---:|
| resources_classic | 48 |
| resources_hd | 49 |
| changes_classic | 98 |
| changes_hd | 130 |
| modules | 69 |
| minimal | 22 |

**416 assertions** for the resource fix and current regressions; the bounded old-build negative control separately reproduces the defect. The classic resource soak was run while developing the same resource code before the version-label bump; the 1440p soak and main regressions ran as 0.993-dev.

## Resource evidence

Reported session was 0.991-dev and stopped on a map-to-battle transition. It contained no Ruby exception or clean exit. Live metadata showed a fragmented 32-bit address space: roughly 272 MiB free in total, largest free region about 6.2 MiB. This was a metadata-only region query, not a memory dump. This is consistent with allocation pressure, not proof of the exact native throw site.

The verified native enemy-gauge script allocated a full 640×480 bitmap for every HP/MP/TP/AP strip and did not dispose it with its Sprite. Eight alternating battles from the reported map/troops retained 14,745,600 gauge pixels (56.25 MiB). Negative-control private memory rose from 69.89 to 124.75 MiB; explicitly freeing those buffers and collecting dropped it back to about 63.65 MiB. These are synthetic fixtures, not measurements read from a save.

The negative control and fixed-build soaks deliberately retain bitmap wrappers after sprite teardown, making resource-ownership assertions independent of garbage collection. Forty classic cycles retain zero gauge pixels: last thirty private-memory samples 62.64–63.72 MiB, GDI 375 throughout. Forty actual 2560×1440 HD cycles also retain zero: warmed private memory 128.41–129.41 MiB, GDI 384 throughout. Every displayed pixel in the compact strips is compared with a full-screen buffer rendered by the same native gauge method. These are bounded reproducible soaks, not a claim of unlimited-session stability on every driver.

The fix releases only owned strip buffers, preserves cached/shared textures, and collects native temporaries at completed battle teardown. It does not change battle formulas, AP/state progression, enemy AI, Steam renderer code or engine binaries. Diagnostics sample self-process numeric counters only, once per normal heartbeat when enabled.

## Other checks

Installer: 55 assertions. Update/refusal/partial-write rollback from 0.9.8-alpha, 0.991-dev and 0.992-dev: 497 assertions. Engine/script bytes and synthetic save/profile sentinels are retained. Game-free repository checks: 19; PowerShell 5.1 installer validates without UI. Runtime assets, staged source and archive are audited before publication. CI status is recorded after upload.

Current classic/HD regressions retain F4/H/F7 nesting, visual/RNG separation, forecast behavior, controls, options persistence, B stock hiding, cooldowns and Gear digits. The unchanged reference/105-weapon checks last passed in 0.992-dev; they were not counted again as new 0.993 assertions.

The player confirmed Steam overlay, HD mouse and screenshots work. The bridge DLL is unchanged; recording playback/export was not retested. The C++ screenshot alone does not identify an exact allocator/call stack, so other native crash causes remain possible.
