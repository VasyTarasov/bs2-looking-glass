# Verification of 0.992-dev

Local isolated Windows checks. Development preview; no stable release.

| Native suite | Result | Assertions |
|---|---|---:|
| preferences | PASS | 32 |
| changes_classic | PASS | 98 |
| changes_hd | PASS | 130 |
| reference_classic | PASS | 7562 |
| reference_hd | PASS | 7565 |
| weapons | PASS | 1077 |
| modules | PASS | 69 |
| minimal | PASS | 22 |
| bench | PASS | 4 |

**16559 native assertions** in nine sets; the preferences set includes two fresh game processes. Each requires the hardened private-desktop launcher, exit code 0 and result=PASS. No player saves or live game were used as fixtures.

New coverage: stored options loaded during actual bootstrap, changed values loaded by a second process, battle setup preserving preferences, real input conflicts/remapping including custom WASD, B stock exhaustion/reacquisition, cooldown counters in classic/HD, exact progression/souls in synthetic headers, scoped Gear digits calling original handlers, native AP quantization, frame-state expiry compared with native frame_update, multiple skipped stunned owner turns, pre-action state removal, permanent restriction, queued and hovered speed effects, random retained AP, existing stun exclusion, unknown-data question marks, marker anchoring/bitmap styles/disposal and state/resource/global/RNG preservation across repeated forecasts.

Previous regression coverage remains: F4/H/F7 nested input and cleanup, cosmetic modal animation without AP/timer/RNG changes, AoE means, priority history/hysteresis, all named reference cards, 105 weapon execution scenarios and optional/minimal module configurations.

Installer: 55 assertions. Verified update/rollback from 0.9.8-alpha and 0.991-dev: 328 assertions, including refusal of running games/foreign edits and rollback on partial-write failure. Synthetic save/profile sentinels and engine/script files were retained. Game-free repository checks: 19. Three BOM PowerShell scripts parse under Windows PowerShell 5.1; installer validation covers both languages and 22 modules. Source/staged/package audits run before upload. Remote CI is recorded after upload; native counts above are local.

Tempo is conditional: new stuns/interrupts are deliberately omitted; unsupported transitions and unknown enemy data produce ?. Enemy/ally decisions, future damage/deaths and repeated enemy turns are not simulated. Priorities and tempo now default on, but explicit saved choices are preserved. Old save headers are not rewritten or read deeply for missing metadata. Automatic weak-battle acceleration is not implemented.

The player confirmed Steam overlay, HD mouse input and screenshots work during ordinary play. The bridge DLL is unchanged. Recording playback/export and additional monitor/driver combinations are not claimed. In-game explanations remain predominantly Russian.
