## English saved-layout correction, 1 November 2026

The 1.0 English interface now translates automatic group labels and historical movement notices loaded from an earlier Russian save. This changes presentation only: stored group membership, order, digits and custom user names are preserved. A known-hash update route accepts the original published 1.0 runtime, preserves module choices and macro profiles, backs up replaced files, and rejects unknown edits.

The actual English VM passes 32,966 localization assertions, including all 2,401 factual catalog entries and transferred automatic labels. The package passes 47 game-free tests, including same-version update and unknown-edit refusal. English generation remains reproducible. These checks supplement, rather than replace, the historical full 1.0 verification below.

Original English game text and encoded dialogue are unchanged. A local cross-language save conversion is separate from the distributed mod and is not shipped with any personal save or original game data.

# Verification of version 1.0

The final frozen runtime passes **66 native profiles / 104,609 assertions**, plus nine focused native profiles / 62 checks and two distributed-preparer profiles / 86 checks. Counts include repeated database records and contracts, not independent features. All 179 Russian/English Ruby files compile in the native game VM.

Coverage includes Russian/English default, minimal, Legacy-only, groups-only, combined input, macros without loadouts, support without groups and reference-only configurations; individual-choice smoke profiles cover the non-Steam choices. Steam is forcibly disabled in isolated native fixtures, so the Steam-labelled smoke profile does not verify live Steam integration. Focused tests exercise native/Legacy reference windows with HD and no groups, the independent macro editor, book-marker preference persistence, and actual in-game selector rendering in both languages. Instant-action priority and tempo rules are checked with automatic support absent.

Numerical/catalog, classic/HD HUD, native percentage applications, menu and queue execution, macros, loadouts, soul events, controls/sound/saves, diagnostics and interaction analysis pass. Standalone automatic support applies real items for both protagonists; standalone cleanses and Gun Break pass. The 40-battle resource soak passes at actual 2560×1440 with DPI-aware QA launch.

Installation passes 166 checks, English loose-data installation passes 5, and three original/label-corrected preview upgrade variants pass 42 checks including injected rollback, unknown-edit refusal, preserved synthetic saves/settings and idempotence. Original English archive installation requires no unpacking and restores a byte-identical original. The distributed preparer leaves its source installations unchanged and never copies personal saves.

Public offline preparation repeats all 166 install/rollback checks under the bundled interpreter using the distributed helpers. Eight additional checks run the public PowerShell launcher without system Python against an English loose-data fixture: check, install, update, reconfigure, uninstall, restored game files, preserved synthetic save and diagnostic collection excluding saves. The accepted game runtime is unchanged; these checks do not rerun the full native battle matrix.

All 43 game-free Python tests, reproducible English generation, Windows PowerShell 5.1 parsing and bilingual installer validation/preview pass. The 43 tests also pass under the actual bundled CPython 3.14.10 (32-bit). Eight offline runtime checks cover operation without Python on PATH, ignored Python environment variables, all three helper entry points, rejection of modified/missing runtime files, and successful restoration. Installer previews exercise tooltip content, focus descriptions, language changes and real checkbox dependency events; the 920×580 three-column layout is inspected in both languages. The GitHub source also accepts the known LF/CRLF variants of unchanged installed Ruby modules; modified Ruby and binary files remain rejected. Its runtime matches the accepted 1.0 package after line-ending normalization.

One initial controls-test restore assertion did not recur in two fresh accepted 59-check runs; its cause was not established and the raw failure is retained locally. The first resource attempt used the wrong DPI launch configuration; the unchanged 1440p contract passes under the required DPI-aware launcher. Early new-test fixture issues were corrected without weakening the accepted behavior contracts. Earlier runtime results predating the shared quick-rule correction are excluded from the frozen acceptance.

No complete story playthrough or universal hardware/third-party-mod certification is claimed. The historical native F12 crash is not established as fixed. Original game formulas, factual catalog assets and native graphics DLL are preserved. Shared integration files retain their verified loading order.

## Guide publication checks

The current source suite has 45 tests, including two additional documentation-media boundary tests. All 21 media files from the public Russian Steam guide are retained with original bytes and recorded SHA-256 hashes, formats and dimensions. The two GIFs retain 295 and 383 frames. Documentation media are allowed only at declared `docs/assets/guide/` paths with matching hashes and image signatures; runtime binary restrictions are unchanged. Text, section order, local media links and GitHub-rendered image tags are checked separately. These documentation changes do not modify the accepted game runtime or the published v1.0 ZIP.

## Historical verification records

# Verification of 0.99995-dev

The final runtime has 177 verified mod files. Seventeen native profiles pass 102,754 assertions, including complete English classic/HD localization and actual English native stats, names, feature/effect order and formulas. English authored interface text is checked for Cyrillic and untranslated Japanese technical labels; the native item193 separator name is preserved exactly. The English type renderer does not mutate the game database.

English inventory/loadouts, menus, instant support for both protagonists, Gun Break, percentage effects and numerical sequence/zero-defense oracles pass. Russian catalog parity, classic/HD HUD and menus pass. Four separate optional module configurations add 24 checks. Native visual QA compiles all 86 English Ruby source files using the game's Ruby VM and captures real settings/F7 windows and the actual HD GPU output. Counts include database loops and repeated contracts, not independent features.

Installation acceptance passes 166 checks: original English archive preflight/install/configure/remove/reinstall, byte-identical original restoration, ciphertext preservation outside the eight script-directory bytes and appended bootstrap, preservation of ignored loose base Data, wrong-language/incompatible-record refusal, real previous ZIP Russian upgrade, idempotence, and injected write failures before/after archive activation with rollback. Synthetic save/settings sentinels remain unchanged. English loose install/removal also passes.

The public distributed preparer runs against final English and Russian installer outputs; 186 source files per profile remain unchanged. Personal saves and Steam authentication are not used. Original encrypted data are not distributed with the mod. The owned native helper and original Russian factual catalogs are unchanged.

All 28 Python checks, compiled-localization reproducibility and PowerShell parse/installer validation pass. These checks do not constitute a complete story playthrough or universal device/third-party-mod certification. The historical F12 crash is not claimed fixed. See [language and installation details](LOCALIZATION-099995.md).

# Verification of 0.99994-dev

Twenty-eight frozen-source native profiles pass 29,678 assertions. New HUD mechanics coverage runs in classic/HD (3,880/3,890), checks actual item-menu and enemy-selection output, and compares 144 native first-hit applications per profile. A separate zero-DEF/MDF suite adds 20 checks. Existing focused UI (7,279/7,315), all 4,802 RU/EN cards, important content (456), baseline/matrix, percentage (680 each; 420 native applications each), presentation, weapons, queues, menus, optional configurations and native HD rendering (69) pass. Counts include entry loops and repeated contracts, not independent features.

The static HUD check requires every named entry to have nonempty text and no technical state identity. Explicit cases cover missing damage/healing formulas, Turtle Soup's two resource effects, extra-command features, Weakness, granted evasion, equal-bonus grouping, complete Abyss Armour state coverage and the actual rapier multipliers. Final accepted GPU frames show target selection and the labelled first-hit fallback; the test waits for renderer activation and requests a fresh own frame before readback. Original descriptions and all ten palette entries retain their previous acceptance checks.

The recent log contains 240 forecast contexts for troop 620. Reconstruction uses recorded transformations and parameters; native quick-use expenditure, exact state timers and RNG remain unrecovered. A counter on one Alice reproduces the area-action refusal. The per-recipient first-hit fallback isolates its recipient, while the full sequence retains its original safeguards. Zero defence matches native arithmetic and damage. No complete counterattack or arbitrary boss-event simulation is claimed.

All 28 game-free Python checks and PowerShell syntax checks pass. The verified 0.99993 archive upgrades in a synthetic installation: four own files change, all 90 match, fourteen sentinels remain byte-identical and repeat update is idempotent. The native DLL and game data/formulas are unchanged. The historical full replay corpus was not rerun; this update exercises the affected path and retained numerical regressions. See [HUD repair](HUD-099994.md).

# Verification of 0.99993-dev

Thirty-one frozen-source native profiles pass 50,507 assertions. They include full catalog parity (27,935), all 4,802 RU/EN F7 cards, focused classic/HD UI (7,279/7,315), four optional configurations, native HD rendering (69), and the existing numerical, percentage, queue, cleansing, support, menu, economy and boot regressions. Counts include record loops and repeated contracts, not independent features.

All 2,401 original descriptions are compared literally, and their source objects remain unchanged. The original help height, ten visible palette entries, manual per-item battle toggles, battle-end reset, ignored legacy activations, absence of reserves/caps, native cleansing past the former cap, and removal of the custom Game Over are checked. Eight colored-soul events consume the chosen quantity. Thirty rapid selections perform no sequence calculations; one settled result is reused. This measures the selected code path, not universal frame rates.

The Corpse Dragon Threat case checks five native repeats with an unharmed attacker carrying revival, plus sixteen seeded native series. Possible recipient death/revival remains explicitly unsupported. Formula ownership colors are verified in the test game's own GPU frame. The complete native HD suite also covers bounds, resizing, physical DPI and rollback. Its process is DPI-aware; no global display setting is changed.

All 28 game-free Python checks pass. A verified 0.99992 archive upgrades in a synthetic installation: eleven own files change, all 89 match, thirteen of fourteen sentinels remain byte-identical, and only retired defeat/retry flags are removed from the remaining configuration. Repeating the update is idempotent. Full historical forecast replay was not repeated for this update; the numerical regression profiles pass and the new revival case has independent native samples. The historical F12 limitation remains. See [focused interface changes](FOCUSED-099993.md).

# Verification of 0.99992-dev

Twenty-nine frozen-source native profiles pass 38,180 assertions. Eight catalog profiles add 28,016 checks: full native parity (27,935), classic/HD UI (28/32), four optional module combinations (5/3/5/5), and accepted HD text/bounds plus capture rejection (3). The remaining 21 profiles retain the previous numerical, percentage, queue, cleansing, support, menu and control regressions (10,164). Counts include loops and repeated contracts, not independent features.

The independent catalog source validator passes 40,229 checks; all 29 input files match their manifest. Complete descriptions, drawbacks, per-hit formulas, separate HP/MP effects, current-resource integer division, actual source variants, 12-to-14 live hit-count changes, knowledge restrictions, last-line access, remapped reading keys, all ten palette digits, detail-window disposal and unchanged state/RNG are covered. The previous conditional x0.64 resistance explanation and HD weapon action controls are preserved. Four old presentation assertions follow the new wording/footer/full-inline contracts; their mechanical expectations remain checked.

All 28 game-free Python checks pass. The real verified 0.99991 archive upgrades in a synthetic compatible installation: five own files change, all 89 own files match, fourteen game/save/configuration sentinels remain unchanged and repeating the update is idempotent. Both new suites run through the public preparer against the verified installed source. Numerical modules are byte-identical to the previous audited version; the historical corpus was not rerun for this presentation update.

Native windows were inspected from the isolated game's own RGSS canvas. HD checks use accepted native text and measured bounds; HD layout illustrations reproduce that text and do not establish final compositor output at every resolution. A QA capture now rejects an oversized client area before image allocation and initializes the destination bitmap. This is test tooling, not a renderer patch. The historical F12 limitation remains. See [catalog integration](CATALOG-099992.md).

# Verification of 0.99991-dev

Twenty-one frozen-source native profiles pass 10,164 assertions. They cover the new percentage suite in classic and HD (680 each; 420 native applications each), new presentation/evidence suite (107/111), complete reference catalog (7,565), baseline arithmetic (35), mechanism matrix (102), weapons (4), catalog (4), queue/iteration regressions (58/37/42), previous cleansing (321), upkeep (243), Gun Break (27), menus (35/36), system/controls (59), and three optional-module boot profiles (6 each). These are repeated controlled contracts, not 10,164 independent features.

The percentage suite independently enumerates all 89 original negative-resource records and isolates their 95 effects across REC rates, preserving Item PHA behavior. Full unmodified techniques are also applied to real boss templates. The presentation suite verifies first-hit labels, separate target names, HP/MP separation, uncertain death, knowledge restrictions, numeric trace fields, target-sensitive deduplication, string-variable exclusion and untouched state/RNG. Native F7 frames for Lindamea and Unis were visually checked.

A separate mean check combines 50% hit chance with a 50% chance to halve REC before percentage damage. The analytic mean and forecast are both 11,300; the original executor averages 11,311.01 over 8,192 seeded applications. All sampled values fall inside the predicted bounds. This controlled result does not establish every historical mean.

All 28 game-free Python checks pass. A real verified 0.9999 archive upgrades in a synthetic compatible installation: nine own files change, all 86 own files match, fourteen game/save/configuration sentinels remain unchanged and repeating the update is idempotent. Both new suites are routable through the public preparation tool. The full historical corpus uses byte-identical numerical modules; presentation-only effect-label revisions is covered by the final profiles. It is analysed with explicit reconstruction limits; see [forecast audit methodology](FORECAST-099991.md).

The full corpus accounts for 18,488 source records / 18,402 distinct contexts. After a 215-context supplement restoring native quick-use counter initialization (historical spent counts are unrecorded and assumed fresh), there are no unexpected queue exceptions. Paired direct-action checks change from 20,537 within-range / 3,957 mismatches / 17,896 unsupported to 24,972 / 1 / 17,417, with 110 unpayable on both sides. Of prior mismatches, 3,847 become within-range and 109 explicitly unsupported; 24,280 shared native sample sets are identical. The remaining mismatch has an incompatible original enemy template. Removing 2,261 numeric checks with resources exceeding reconstructed maxima leaves 22,712 within-range checks and no remaining mismatches; this still does not establish exact historical state. Raw full runs are retained alongside the initialization supplement.

# Verification of 0.9999-dev

Eleven profiles pass 1,159 native assertions: new cleansing/wine/rules classic and HD (321 each), previous upkeep (243), resin and item-window regressions (99), classic/HD menus (35/36), Gun Break (27), controls/system (59), and three module boot profiles (6 each: no modules, semantic groups only, and normal modules without custom controls). All runtime source hashes are frozen for this batch. Counts include repeated controlled contracts, not independent features.

The new suite exercises both protagonist records, every literal cleanse target, absent and combined states, stock refill, reserves, default battle caps, same-period reapplication, native removal failure, intentional madness and stale-marker removal, optional thaw, manual and automatic wine, the next real battle, native sleep restrictions, rule persistence and write failure. The settings windows are created and exercised in the native renderer. The independent accepted catalog contains 24 item records.

All 28 game-free Python checks pass. A verified real 0.9998 archive upgrades in a separate synthetic installation: four own files are updated/added, all 86 own files match, eleven game/save/configuration sentinels remain unchanged (including item activations and rule settings), and repeating the update is idempotent. Game data and native binaries are unchanged. See [automation rules](AUTOMATION-09999.md).

# Verification of 0.9998-dev

Seven focused native profiles pass 602 assertions: `auto_items09998` classic/HD (101 each), the independent 16-item `polish_support` matrix (243), classic/HD menu regressions (35/36), Gun Break (27) and system/control behavior (59). The new item catalog does not derive its expectations from the production whitelist. The fire-resin omission is reproduced on unmodified 0.9997 before the correction.

All 28 game-free Python checks pass. A verified real 0.9997 archive updates to 0.9998 in a separate synthetic compatible installation, with two own files changed, all 85 own files matched, ten game/save/configuration sentinels preserved and an idempotent repeat. The original game database and native renderer are unchanged. See [automatic item correction](AUTO-ITEMS-09998.md) for the exact supported items and preserved manual decisions.

# Verification of 0.9997-dev

Whole-pack audit. Accepted results: 28 native profiles / 9,759 assertions; 37 module configurations / 222 boot/menu assertions; 28 game-free Python checks. Counts include record loops and repeated contracts, not independent features. The independent suites cover content (456), automatic items (223), Gun Break (27), equipment (61), native economy events (34) and system behavior (59). Standalone loadouts add 41.

A forecast_matrix attempt without its required HD-only QuickDamage widget failed due to test configuration. Its accepted HD rerun passes 102 assertions; the raw failed attempt is retained. Historical version/input/forecast contracts remain historical rather than being weakened for a green result.

After the bulk regression, only reassigned-control hints and the conditional F7 hint changed in three UI files. Affected contracts were rerun in system, Gun Break and classic/HD/standalone equipment profiles. The native renderer and game formulas are unchanged. Native frames of references, counters, effects and loadouts were visually inspected.

A real 0.9996-dev archive was installed into a separate synthetic compatible game, updated and updated again. Eight own files change; all 85 module files match the candidate. Twelve synthetic game/save/configuration sentinels are byte-preserved. The public preparation tool also prepares a verified installed source and runs the new content suite successfully.

The earlier F12 access violation remains unresolved. Two live fresh-process handoffs and normal exit of the original installed game returned zero; this is not a demonstrated crash fix. No full story playthrough or all-device/all-DPI certification is claimed. See [audit scope](POLISH.md).

# Verification of 0.9996-dev

Five native runs passed with process exit 0 and result=PASS: live09996 (24 classic / 25 HD assertions), menus09995 (35 classic), menus09994 (51 HD) and modules (61). Total: 196 assertions, including repeated profile checks. Three additional assertions reproduce the two reported defects on the unchanged published 0.9995-dev tree.

The focused regression uses protagonist actor 2, real ordinary-menu D marking, actual quick-item execution and inventory consumption. Two Carpenter Bolts reach native ATK buff level 2, spend exactly two items, leave paid slots free and stop at maximum. One item stops at level 1 without an error. Inspection stays paused while the list is open. A companion cannot be armed. Native action-end processing retains the maximum buff.

Gun Break coverage: all six unavailable favorite entries, actual equipped shield, actual equipped rifle, only its supplied interrupt, native cooldown disappearance/return, switching back to shield, an ordinary learned skill at zero MP, custom combat V/M and out-of-battle favorite inspection. Stored favorites and custom slots are not deleted.

All 24 repository/update Python tests pass. Integration verifies 85 module hashes against the published 0.9995-dev ZIP, previews and applies six own-file changes to a synthetic installation, then confirms idempotence. Synthetic game/script/save/options/macros/automation/module settings and unrelated install metadata are preserved. All 85 installed own files still match 0.9995-dev: the real installation was not updated.

Unresolved crash: the Windows Application log records Game.exe / RGSS301.dll, exception 0xc0000005 at module offset 0x0010ac8e on 24 October, 15:31 Moscow. The immediately preceding mod session records F12, a fresh child process and RGSSReset during parent teardown. These establish timing, not the exact fault cause. No retained dump was available. Native bridge and restart code are unchanged. Full playthrough, live F12 handoff and live Steam were not revalidated; this build is not presented as a fix for that crash.

# Historical verification

# Verification of 0.9995-dev

Native execution: 18 suite/profile runs, 831 assertions, each with process exit 0 and result=PASS. This includes repeated checks under HD, native and copied user-option profiles; counts are not independent mechanisms.

The audit regressions cover depleted item -> favorite/filter -> Enter, palette exhaustion -> group/prefix changes, custom duplicate rows, digit choice differing from cursor, MP/cooldown/seal refusal, automatic support before remembered menu restoration, idle/F7/target-cancel pauses, target confirmation, native instant-item upkeep and recovery after malformed diagnostic text. Current audit-fix suites: menus09995 (36 HD / 35 native / 36 copied-option assertions), diagnostic_text09995 (13).

Regression suites: menus09994 (51), queue09993 (42), iteration09992 with diagnostics (58), iteration0997 (51), iteration0999 with HD (37), forecast_matrix with HD (102), macros_optional0998 with semantic+loadouts only (6), modules (61), battle_retry (24), resources0993 (48), map_return (55), diagnostics0995 (28), adversarial (36), stress with diagnostics (112). Stress includes 100 synthetic save slots, injected failures, 150 screen lifecycles and 3600 native frames; its previous malformed-text failure now passes.

The test fixture is Steam-free and uses synthetic game state without player saves. All 33 module smoke combinations pass: no optional modules, each of 21 individual modules excluding live Steam, eight omissions from the full set and three combinations. They initialize native menu/settings/battle windows. A smoke test is not full behavioral coverage for every combination. Installation and target update checks use synthetic script/save/profile sentinels. The published 0.9994-dev module tree is checked by its real archive hashes, updated to 0.9995-dev and checked for idempotence. Four own files change; engine scripts, saves, settings, macros and an unrelated install metadata field retain their sentinels.

24 game-free repository/update tests pass. The malformed-text cases include invalid/incomplete UTF-8, an invalid UTF-16 surrogate, valid Cyrillic/escaping and Windows-1251, followed by another successfully recorded event. Cyclic values remain bounded and nonfinite floats remain null.

Historical tests below document older contracts. Several expect old version literals, N2/N3 shelves or menu closure; do not treat all historical files as the current mandatory suite or silently weaken their assertions. HD/diagnostic/legacy/persisted-preference prerequisites must be explicit when running a scenario. Full playthrough, live Steam features and exhaustive display/DPI combinations were not retested for this patch.

# Verification of 0.9994-dev

Native execution: ten suites, 389 assertions, each with process exit 0 and `result=PASS`. The isolated game uses synthetic state and fresh BS2Suite/BS2QoL profiles; no player saves are copied. Counts include repeated/aggregate assertions and are not counts of independent features.

| Suite | Assertions |
|---|---:|
| Physical input and repeat menus | 51 |
| Previous queue/action ownership regressions | 42 |
| Instant items, macros and source/executor weapons | 51 |
| Grouped macros/probability sequences | 37 |
| Continuation/cancellation/highlight regressions with Diagnostics | 58 |
| Actual defeat/retry/victory | 24 |
| Reduced semantic groups + loadouts | 6 |
| Native module smoke checks | 61 |
| HD palette performance | 4 |
| Native menu/map return | 55 |

The new 51 assertions drive physical key presses through real scene/window updates. They cover native item/technique favorites and filtering, profile reload, V ↔ C, double-Esc from palettes/native lists/C/target pickers, held-key and timeout boundaries, native/curated instant and paid choices, Shift attacks, multiple enemies/allies, target cancellation, real paid execution/cost, next-input return, actor separation, explicit exit and item exhaustion. HD checks activate the actual renderer and exercise hidden native palette/C windows, not only their underlying Ruby handlers.

The old full-battle retry driver now explicitly exits the repeated item menu after its intended single flask; the original 24 gameplay assertions remain. The module smoke test's version assertion is advanced to this build. These are adaptations to the requested menu contract, not relaxed resource/queue assertions.

Game-free package/update checks: 24 tests. Read-only compatibility check of the installed 0.9992-dev build succeeds with `changes=false`. Previous 0.9993-dev hashes are retained for verified module updates. Original files remain unchanged. Current HD timing: 30 unchanged palette reads took 0 ms, 30 selection changes took 16–31 ms in the fixture.

This is a separately packaged development version. Input menus do not execute or refund actions; native paid slots and target rules still control the battle. Exhaustive playthrough, all HD sizes and every module combination are outside these checks. Historical evidence below is not counted as a newly rerun suite.

# Verification of 0.9993-dev

Each suite below uses the native Ruby 1.9.2 engine, a fresh synthetic profile and the hardened private-desktop launcher. Success requires both process exit 0 and `result=PASS`. Game assets are read only to prepare the isolated fixture; no personal saves are copied.

| Native suite | Assertions / evidence |
|---|---|
| Queue/action ownership regressions | 42: failed auto-item cancellation and real ATB renewal; successful two-level stacking; selected versus alternative preparation; full/HD/F7 agreement and immutable state/RNG; cache preparation/finishing/source/executor/target changes; unchanged-result reuse; clear/reuse; actual C picker over Gun Break support; remaining instant-step visibility, including one paid slot |
| Instant items, source/final weapons and macros | 51 |
| Current continuations, native cancellation and interaction highlights, with Diagnostics | 58 |
| Grouped macros and probability sequences, with HD | 37 |
| Weapon source/executor oracle | 4 aggregate assertions over the suite's 3,494 native targeting/repeat comparisons |
| Battle retry | 24 |
| Only semantic groups and loadouts | 6 |
| HD performance | 4; 30 unchanged palette reads took 0–15 ms, 30 selection changes took 31–32 ms in this fixture |

The focused A1, A2 and A3 regressions failed against the unchanged 0.9992-dev module for their intended reasons before their respective fixes. Clear/reuse likewise reproduced the old item expenditure. B2 was reproduced through real menu handlers over a visible native Gun Break support suggestion, rather than only by injecting a populated guard slot.

The selected Carpenter Bolt example now agrees at 718.96 mean direct damage across the full step and selected-action inspection; the explicit alternative is 564.3. Replacing a prepared macro with the same paid IDs without preparation changes the short result from approximately 719 to 564. These are controlled examples, not a statistical claim about every enemy/build.

Game-free repository and update checks: 24 tests, including update preview/application/idempotence, modified-file refusal, rollback after an injected write failure, profile/save sentinels and archive integrity. The actual installed 0.9992-dev module also passes updater compatibility **without applying** an update. PowerShell sources parse successfully. Original source, installed module, selected game/configuration files are compared against their pre-work hashes.

Known scope: this is a separate development package, not an installed update or a full playthrough. The forecast keeps its existing unknown/conditional cases and branch limit. Steam overlay and every HD resolution are not re-certified by these changes. Historical results below describe earlier versions and are not counted as newly rerun checks.

# Verification of 0.9992-dev

The hardened private-desktop launcher is used throughout: exit code 0 plus `result=PASS`, synthetic game state, no personal saves or public game windows. There is no live-player input or arbitrary script evaluation in the highlighter.

| Native suite | Assertions / evidence |
|---|---|
| Current continuation, cancellation and interaction regressions | 58; repeated attack → spell, native fractional TP → damage, safe/near-lethal Endure, four self-flagellation weapons × four difficulty settings, actual guard/attack cancellation, current-page/SAN gates, empty corpse choices/common event, state/RNG preservation, held/released Alt rendering and resource release on native character rebuild |
| Interaction catalogue | 2 aggregate assertions: all 20,755 interactive page records across 410 maps classified without exceptions or world/RNG mutation, in the controlled initial state. This is not proof of every reachable event outcome |
| Forecast mechanism matrix / formula baseline / first-hit corpus | 102 / 35 / 4; existing native-oracle coverage retained, including 15,552 first-hit applications |
| Grouped macros / probability sequences / source-final weapons | 37 / 12 / 57 |
| Reduced-module macros | 6 |
| Classic / HD broad interactions | 98 / 130 |
| Classic / HD support/reference interactions | 45 / 58 |
| All modules / minimal modules | 69 / 22 |
| Normal / instant-Ctrl full battles | 9 / 9 |
| Performance diagnostics with full / minimal modules | 28 / 28 |

The interaction corpus reports supported interactions, invisible/no-effect/empty cases and conservative omissions separately; unknown script conditions/control flow are not turned into speculative markers. Actual current-page transitions and visibility are verified by the focused native tests. A captured engine frame was visually inspected for the gold markers. Repeated redraws do not create more marker bitmaps or duplicate diagnostic records. Original engine, script table, reference data and native Steam/HD helper are unchanged.

Installer checks: 55. Update from 0.9991-dev: 192, including refusal/rollback and profile preservation. Repository checks: 21. Windows PowerShell 5.1 validation remains headless. See [forecast scope](FORECAST.md) for remaining numerical limitations; this development build is not an exhaustive proof of all combat/event combinations.

# Verification of 0.9991-dev

This build audits common forecasting paths, not only the two reported sequences. The earlier 605 assertions described the complete UI/gameplay suite, not independent proof of every damage mechanic. See [forecast scope, evidence and limitations](FORECAST.md) for exactly what each oracle covers.

All sixteen native suites below finish with exit code 0 and `result=PASS` using the hardened private-desktop launcher. Only synthetic fixtures are used; no personal saves or live-player input. Native formula evaluation, item application and random draws belong to the isolated oracle, never to the preview.

| Native suite | Assertions / independent coverage |
|---|---|
| Mechanism matrix | 102 assertions: native counters/reflection, weighted means, buff/debuff/state transitions, all 20 difficulty settings, all 33 state-dependent skill-selection rules, F7/short context, resource/retargeting boundaries and immutable previews |
| Formula/baseline oracle | 35 assertions; 824 expression comparisons, 1,048 enemy prediction constructions, 868 landed native samples |
| Full skill/item first-hit corpus | 4 aggregate assertions over 1,389 classified records, 648 formula records, 15,552 native applications and 13,268 landed conditional-range comparisons; zero mismatches |
| Weapon source/executor oracle | 4 aggregate assertions over 500 weapons, 24 normal IDs and 3,494 targeting/repeat comparisons; zero mismatches |
| Grouped macros and reported actual-damage pairs | 37 |
| Minimal-dependency macros / probability-branch sequences | 6 / 12 |
| Sole/source/final weapon and multi-target estimates | 57 |
| Classic / HD broad interactions | 98 / 130 |
| Classic / HD item/support/reference interactions | 45 / 58 |
| All modules / no optional modules | 69 / 22 |
| Normal / instant-Ctrl full battles | 9 / 9 |

Mean checks include 2,000 native counter/reflection invocations, 3,000 combined crit/Guard-bypass/resistance/evasion/cancellation applications, 2,000 recovery-mode applications and 2,000 probabilistic debuff-then-damage sequences. These have declared sampling tolerances. The complete first-hit corpus tests conditional ranges, not every mean or every multi-action state. Weapon platform checks establish target/repeat counts, not every equipment damage distribution.

The matrix also verifies that an already selected transformed ID is not transformed again during targeting, that a final weapon removing its enabling state does not change that selected ID, and that the sequence card does not invent a 0% hit chance from a missing legacy field. Unverified resource-dependent continuations, response damage, survival/retargeting or scheduled special effects produce an unknown/partial result; possible HP-triggered battle scripts qualify later figures and suppress a certified series total without reading hidden thresholds or script bodies.

Installer: **55** assertions. Update from 0.999-dev: **188**, including refusal of running games/foreign edits, injected-failure rollback, removal of newly added files on rollback, profile byte preservation, migration idempotence and synthetic-save sentinels. Repository checks: **21**. PowerShell 5.1 `-ValidateOnly` passes without showing UI. No game binary, original script table, reference database or Steam/HD native helper is changed by this version.

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
