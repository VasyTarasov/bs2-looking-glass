## 1.04 — 2026-11-13

- Fixed a reproduced double-reward and silent-exit path when an instant action defeats the last enemy. The completed battle no longer resumes its old input/action handler.
- Instant action sequences stop at victory or battle abort. Cleanup does not restore a completed battle's queued actions or overwrite a newly started battle.
- Optional priority bookkeeping runs after the engine finishes battle cleanup; an error there no longer prevents the battle from ending. Unexpected execution errors are no longer swallowed as macro validation failures.
- Fixed startup when reference cards are disabled. Legacy battle plan and key hints stay hidden while the HD sidebar has accepted their replacement, including the battle fade-out; classic and sidebar-disabled modes retain their normal panels.
- Added native-engine regression tests, including a comparison against 1.03 through the original main loop and a 40-battle accelerated run. This addresses the reproduced mechanism; it does not establish the cause of every reported game exit.

## 1.03 — 2026-11-06

Fix rapid flickering between the original game image and HD output in windowed modes. The GDI parent and OpenGL child now use the required clipping styles; original GDI rendering is preserved. Returning to the title screen keeps the current window size and HD/classic mode. The full-screen launch preference still applies to a fresh launch.

## 1.02 — 2026-11-05

Real Steam follow-up: fix background HD startup; supply missing Steam app-id metadata for Loader without replacing user files; keep the running Loader game on F12 instead of restarting without its mods. Safely update the initial 1.02 package.

Broader installer recognition: clean Steam English, both verified restoration archives, Larry translations and older BS2RU_v5. RMModLoader 2.4–2.6 adapter preserves game/translation data and restores owned Loader settings on removal. Changed objects use current database properties instead of stale reference prose. Installation failures roll back changes; updates from 1.0/1.01 retain settings.

## 1.01 — 2026-11-05

Compatibility release: recognize both verified English restoration archives and Larry base/1.06; preserve the exact original archive on removal; explain external-loader and known translation conflicts; retain 1.0 settings during updates.

# Version history

[Русский](docs/CHANGELOG-RU.md) · [Home](README.md)

Entries follow the actual development order. These identifiers are historical, not standard semantic-version arithmetic: 0.92-dev and 0.9.2-alpha are different builds. Early previews were not all published as GitHub releases. Each entry describes that build; later entries may supersede its features.

Early releases were reconstructed from retained archives and their READMEs, changelogs and reports. BS2QoL and BS2Modules initially developed separately; their version numbers belong to different branches merged in 0.5. Before numbered releases, database research and a mod foundation existed without a custom in-game interface.

## 1.0 — Modular feature selection and bilingual installer

- The public Windows ZIP bundles an isolated, checksum-verified Python runtime for offline installation, updates and diagnostic collection; no separate Python installation or pip packages are needed. The Russian guide is now on the repository landing page.
- The pack is now named **BLACK SOULS II — QoL Pack**; the repository URL and version 1.0 are retained.
- 20 choices in seven sections. Everything defaults on except Advanced Legacy, automatic support and diagnostics.
- V/B/M/N and Advanced Legacy work separately or together; support is independent, and macros no longer require equipment loadouts.
- Highlighting and Ctrl acceleration are separate choices; reference/effects and basic conveniences are grouped appropriately.
- Shared instant-action rules are independent of automation, including priority and tempo handling.
- Within the same 1.0 release, the installer uses three columns: all 20 choices fit a 920×580 window without scrolling, with mouse and keyboard descriptions.
- Supports preview-setting migration, verified-file checks and rollback after update failures.

## 0.99995-dev — Complete English interface

- Added the complete English mod interface with native English names while retaining Russian.
- The installer selects the game language and supports the original English Game.rgss3a without unpacking, with original restoration.
- Accounts for English database differences and removes obsolete Russian summaries from English cards.

## 0.99994-dev — Meaningful HUD text and per-target fallback

- Restored action meaning, formulas and recovery effects in menus and target selection.
- Clarified extra commands, Weakness, weapon properties and equivalent bonuses.
- The first-hit fallback isolates one recipient so another enemy’s counter cannot hide an available preview.

## 0.99993-dev — Focused mechanics and manual automation opt-in

- Restored original lore descriptions; F7 and HD focus on mechanics.
- Shows all ten group entries and defers/reuses forecasts while navigating.
- Each battle starts with automatic items off, enabled per row with D; removed the spending-settings screen and custom defeat/retry flow.

## 0.99992-dev — Complete mechanics cards

- Integrated the RU/EN mechanics catalog into native help, F7 and HD panels.
- Keeps complete properties and drawbacks scrollable, with formulas before numeric estimates.
- Separates percentage recovery and derives hit counts from the actual sequence.

## 0.99991-dev — Percentage damage and useful partial previews

- Fixed omitted percentage HP/MP effects in forecasts.
- Keeps resources and individual targets separate; an available first-hit preview is not presented as a certified full sequence.
- Added numeric forecast context and known target parameters to opt-in diagnostics.

## 0.9999-dev — Cleanses and spending controls

- Added seven cleansing items and the native once-per-battle use of Hlanith wine.
- Cleanses respect actual states, native use restrictions and intentional madness.
- This historical build introduced reserves and spending caps; their separate settings screen was later removed in 0.99993-dev.

## 0.9998-dev — Resins and pollen in automatic support

- Added automatic fire resin and Tinker Bell pollen support.
- Preserves the resin’s native frostbite removal; pollen respects its scope and living companions.
- Checks eligible items independently of the automation whitelist.

## 0.9997-dev — Whole-pack consistency audit

- Corrected mechanics explanations, learned-book information, TP, effect sources and actual ATB counters.
- Refined loadouts, cleanup previews, failed weapon upgrades and batch soul use.
- Hints respect remapped keys; expanded gameplay checks and isolated-fixture preparation.

## 0.9996-dev — Both protagonists and current Gun Break availability

- Automatic items support both protagonist records: actors 1 and 2.
- Unavailable Gun Breaks are hidden from current lists without discarding saved assignments.
- Verified actual item spending, maximum attack buff and preservation of paid action slots.

## 0.9995-dev — Stable selection in persistent menus

- A depleted item cannot refresh into a different consumable.
- Temporary rows stay scoped to their group; refused actions keep their menu open.
- Services support at safe input boundaries and fixes malformed diagnostic-string logging.

## 0.9994-dev — Repeatable battle menus

- Native lists and V/B/M/N retain selection after actions and resume at the same actor’s next input.
- Fixed return from multi-target selection and physical double-Esc handling.
- Added direct group/C navigation and favorite/filter hints in ordinary lists.

## 0.9993-dev — Action ownership and consistent forecasts

- Failed automatic items do not gain new retry periods from queue cancellation or regeneration.
- Selected-action inspection preserves preparation, finishing steps, source, executor and target.
- Removed conflicting nested caches; clearing an action releases its macro attachments.

## 0.9992-dev — Action continuations and interaction highlighting

- Removed obsolete forecast barriers for repeated attacks and supported effect-driven continuations.
- Esc cancels an uncommitted normal attack or guard.
- Holding Alt marks useful available interactions on the current map without exposing hidden event pages.

## 0.9991-dev — Native forecasting audit

- Audited first-hit formulas, counters, reflection, probability-weighted means and state transitions.
- F7 and short estimates share the queued-action context.
- Unsupported continuations and script-dependent outcomes carry explicit limitations instead of invented exact totals.

## 0.999-dev — Grouped macros and sequence forecasts

- Expanded macros to four groups of eight, with numbered editing and MP/cooldown summaries.
- Added preset-local execution weapons, Space confirmation and double-Esc queue reset.
- Improved preparation, random-attack and repeated-effect forecasts; older macros migrate into group one.

## 0.998-dev — Macros without optional inspection modules

- The macro picker and editor work without Effects, Reference Cards or key remapping.
- Guarded accesses to absent inspection helpers in reduced configurations.

## 0.997-dev — Queues, map capture and initial macros

- Instant items resume the same unpaid slot; final weapons arm at the native turn boundary.
- Added eight named macros of up to six steps and Shift attack variants in N.
- Refined starting weapons, repeated map-event logging and heat-effect preparation.

## 0.996-dev — Ring preservation

- Excluded every ring copy and upgrade tier from automatic equipment cleanup.
- Preserved normal equipping and loadout resolution; refined records for other equipment cleanup.

## 0.995-dev — Bounded performance diagnostics

- Added local five-second frame-time and phase summaries.
- Measures scenes, windows, HD, forecasts, logging and numeric resource counters without per-frame writes.
- Separates known waits; adding diagnostics alone is not a claimed slowdown fix.

## 0.994-dev — Hold-Ctrl battle presentation acceleration

- Holding Ctrl shortens animations, pauses, transitions, damage popups and window opening.
- Commands and targets remain manual; AP, costs, effects and rewards use the native pipeline.
- Separates cosmetic shake randomness from combat random rolls.

## 0.993-dev — Graphics-resource lifetime fix

- Replaced full-screen buffers for narrow gauges with correctly sized images and explicit disposal.
- Collects temporary objects after completed battle teardown and adds numeric resource counters.
- Verified that repeated battles, including HD, do not retain those gauge buffers.

## 0.992-dev — Tempo stars and persistent preferences

- Moved tempo hints to enemy gauges, accounting for supported speed changes and effect expiry.
- Fixed late-registered settings being lost; tempo and usage priorities now default on.
- Hides depleted B items, shows remaining cooldowns and adds progression/soul information to save headers.

## 0.991-dev — Responsive groups and priorities

- Added group caching and deferred forecasts during navigation; inspection keeps cosmetic animation running.
- Added remappable WASZ navigation, plain G and optional usage-history priorities.
- Combined area-attack summaries and removed redundant commands and the separate field-skill hotkey.

## 0.92-dev — Nested references and display controls

- Fixed navigation between F4, H and nested F7 views.
- Refined F10 display toggling, size restoration, crisp HD and DPI-aware startup.
- Expanded target comparisons, clock selection in B and access to Gear of Madness.

## 0.91-dev — Public repository preparation

- Named the project Looking Glass and imported the 0.9.8-alpha baseline.
- Prepared bilingual materials, audited assets, reversible installation and package checks.

## 0.9.8-alpha — Verified factual references

- Added a separate factual data view for mechanics cards.
- Separated static properties from current-state forecasts; this build became the public repository baseline.

## 0.9.7-alpha — Execution-weapon validation

- Refined ownership, switch restrictions and final-action eligibility checks.
- Aligned projected and actual execution checks; unavailable nominated weapons are not arbitrarily replaced.

## 0.9.6-alpha — Single-technique source weapon

- A single weapon technique keeps its source weapon when an execution weapon is nominated.
- Uses the original action-queue size rather than only its remaining portion.

## 0.9.5-alpha — Independent starting weapon

- Added a saved weapon preference for the beginning of an actor input period.
- Separated the starting weapon from the battle-local final-action weapon; updated hints and forecasts.

## 0.9.4-alpha — Contextual effects and equipment

- Expanded contextual effect inspection, references and equipment comparisons.
- Added armor-family handling and refined loadouts, menus and return from nested windows.

## 0.9.3-alpha — Curated arsenal and automatic support

- Added curated weapon groups and additional concise explanations.
- Introduced upkeep for selected items and Gun Break, respecting availability and source equipment.

## 0.9.2-alpha — Battle journal and contextual HD panel

- Added a journal of observed battle actions.
- Expanded contextual HD presentation, battle interface integration and graphics support.

## 0.9.1-alpha — Weapon families and navigation

- Added equipment-family handling and shared window navigation.
- Refined how optional modules and the HD interface load together.

## 0.9.0-preview — First HD preview

- Added custom high-resolution output and a separate HD interface on top of 0.8.2: actor resources, weapon, commands, queue, effects, V/B/M/N and F7.
- Added windowed/full-screen presets, crisp/smoothed rendering, HD text scaling and timed display-mode confirmation with automatic fallback.
- This began the HD branch; the unified modular package already existed in 0.5, and not every screen had been ported in this preview.

## 0.8.2-alpha — Curated weapon shelves

- N1 became a short list of frequent switches, N2 a separate final-action selection, and N3 onward additional manual shelves.
- The authored profiles retain early alternatives differently; addresses stay fixed during battle and layout migration requires confirmation.
- The editor gained explicit “Switch now” / “Final action” modes while preserving existing custom-group behavior; F7 explains weapon roles and limitations.

## 0.8.1-alpha — Steam overlay and restart

- The Steam bridge recognizes the redirected graphics context of a real Steam launch; the overlay refreshes during pauses, accepts mouse input and returns focus on closing.
- With the bridge enabled, F12 restarts the same Game.exe in a new process instead of re-executing scripts in the existing Ruby process.
- Removed the hard-coded F12 screenshot binding so Steam controls the shortcut; graphics-window system commands are forwarded to the main game window.

## 0.8.0-alpha — Soul batches, equipped upgrades and Steam bridge

- Added confirmed batch use of eligible souls with currency-cap checks, and native recipe upgrades of equipped weapons with rollback on failure.
- Made authored V/B/M positions sequential and persisted acknowledged layouts outside saves; expanded N1, F7 references, loadout comparisons and compact H battle effects.
- Added an optional Steam/OpenGL bridge and opt-in acceleration of ordinary item presentation. Full visual overlay operation was not yet confirmed at this stage.

## 0.7.1-alpha — Map return and diagnostic overhead

- Fixed access to a disposed notification window after returning from menus to the map by recreating it for the new scene lifetime.
- Aggregated repeated diagnostic condition checks into counted summaries, removed empty inventory/currency changes and added update-rate and long-gap measurements.
- Expanded map-return, diagnostic-overhead and 0.6 / 0.7.0 upgrade checks; this was not a claim to eliminate every possible slowdown.

## 0.7.0-alpha — V/B/M/N groups and separate Legacy

- Introduced V/B/M groups and N weapon selection; moved the old Shift/Ctrl shortcuts into Advanced Legacy, disabled by default. Favorites remained separate.
- Added two evolving authored profiles and custom-group editing with copying, renaming, F6 assignments and up to ten groups of ten entries.
- N1 switches immediately while N2 onward nominate a final-action weapon; F7 shows the queue and weapon comparison, with supported between-slot forecast transitions.
- Added encounter tracking outside saves with a configurable threshold for exact enemy information; the installer offered 18 selectable modules.

## 0.6.0-alpha — Weapon bindings and quick saves

- Added independent Ctrl bindings for weapon techniques and Ctrl+Shift source-weapon switching with technique selection, using actual upgrade chains for weapon families.
- Expanded F7 to equipment and battle targets and F4 to current enemies; refined mechanics cards, ring explanations and forecasts.
- F3 saves on the map to five separate quick slots, 101–105, respecting native restrictions; D on Hidden Body optionally enables paid recasting.

## 0.5.1-alpha — Hidden skills and malformed data

- Hidden skills stay hidden in mod lists and direct slots; malformed UTF-8 settings safely fall back to defaults.
- Hardened save-header and body validation, restoration of the previous live world after load failure, and damaged-slot skipping when finding the latest save.
- Temporary-save cleanup failures no longer interrupt play and successful operations clear stale errors; diagnostic JSON handles malformed strings.

## 0.5.0-alpha — First unified modular package

- Combined BS2QoL 0.4 and the separate BS2Modules 0.1 effects/loadouts into one bootstrap, shared input and an installer with 16 selectable features.
- Added learned-book markers, field skills, 100 labelled manual saves with verified writes, a defeat screen, bounded battle retry and battle statistics.
- Added integer scaling, control remapping, run modes, separate volume controls and opt-in local diagnostics while preserving existing favorites, bindings and loadouts.

## BS2Modules 0.1.0-alpha — Separate effects and loadouts branch

- A standalone package of two independently selectable modules developed before the 0.5 merge. Its 0.1.0 identifier belongs to BS2Modules, separately from BS2QoL.
- Shows states, buffs, cooldowns, instant-use limits and equipment contributions, preserving the current queue during battle inspection.
- Provides named full defensive loadouts per actor with preview, availability and lock checks, and rollback on failure; coexistence with BS2QoL 0.2 was checked.

## BS2QoL 0.4.0-alpha — Numeric forecasts for current targets

- Added per-current-target estimates using stats, equipment, states, resistances, pre-formula costs, variance, criticals, reflection and substitution.
- Distinguishes raw damage from actual HP/MP loss and labels complex changing sequences as first-hit estimates; inspection neither executes arbitrary formulas nor consumes combat random rolls.

## BS2QoL 0.3.0-alpha — Bilingual cards and offline references

- F7 opens detailed technique, magic and item cards and F8 switches Russian/English, with effects, formulas and special-mechanic rules.
- Added separate searchable RU/EN HTML references; exact numeric forecasts for the current target followed in 0.4.

## BS2QoL 0.2.0-alpha — Shortcuts in native lists

- Moved quick access into the native battle interface: commands 1–6, Shift weapon/context slots and shared direct Ctrl slots.
- F6 assigns the highlighted item, skill or weapon, with technique profiles per weapon; favorites move to the top of native lists and the separate battle Favorites category is removed.

## BS2QoL 0.1.2-alpha — Esc return to categories

- Fixed Esc returning from a favorites list to its categories, with button-driven verification during demo capture.

## BS2QoL 0.1.1-alpha — Favorite sound and capacity

- Removed the duplicate sound when toggling with Enter; at the 64-entry limit, adding is disabled while removal remains available.
- Expanded full-battle, save/load, settings-write-failure and repeated large-inventory checks.

## BS2QoL 0.1.0-alpha — First working favorites and queue

- Added persistent favorite weapons, skills and consumables in menus and battle, A/S filtering and a compact view of actual action slots.
- Uses native targets, costs and restrictions while keeping unavailable entries visible; added checked installation with exact script-table restoration.
