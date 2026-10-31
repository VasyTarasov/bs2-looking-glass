# Version history

[Русский](docs/CHANGELOG-RU.md) · [Home](README.md)

Entries follow the actual development order. These identifiers are historical, not standard semantic-version arithmetic: 0.92-dev and 0.9.2-alpha are different builds. Early previews were not all published as GitHub releases. Each entry describes that build; later entries may supersede its features.

## 1.0 — Modular feature selection and bilingual installer

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

## 0.9.0-preview — First modular preview

- First recorded preview combining combat controls, action-queue display, reference cards and effect inspection.
- Brought together loadouts, save conveniences, command groups and Steam/HD presentation.
