# Verification of 0.994-dev

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
