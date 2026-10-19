# Controls and execution

[English home](../README.md) · [Русский](RU.md#управление-и-оружие)

V/B/M/N open curated techniques, items, magic and weapons. Groups grow as useful choices accumulate, never exceed ten entries, and do not repeat the full inventory. Favorites and optional legacy shortcuts remain independent.

Repeat the active letter to go back one level; Esc exits. Q/E change groups. Inside F7 opened from V/B/M/N, Q/E change the object within the same group. Digits select eligible targets directly, including the hero and allies. A sole eligible hero target needs no extra confirmation.

## Three weapon decisions

| Decision | Control | Behavior |
|---|---|---|
| Equip now | Digit / Enter in N | Immediately change the live weapon when legal. |
| Starting weapon | D in equipment / Items → Weapons | Apply at the beginning of a turn. Repeat D clears it; existing action slots are not recalculated. |
| Final executor | D on an N entry | Nominate the last action's platform. Repeat D or N N clears it. |

With one original slot, a V equipment technique uses its granting source; the final nomination does not override it. Magic and non-instant items may use the final weapon on the last action. Instant actions do not trigger that final swap.

With multiple original slots, the final nomination remains eligible when only the last slot is left. Without a valid nomination, execution uses the live weapon. An action keeps its selected ID; a later weapon selection can change an earlier queued action's stats. Stats are not frozen, and the mod does not silently re-equip the old source before every action.

Equipment locks, forced actions, missing weapons or unaffordable costs may prevent a nominated swap. Normal-attack extra repeats require the selected ID to equal the current normal attack. Equipping Hans's Machine Gun does not turn an unrelated skill into its burst.

F7 uses the corresponding platform, resolved variant and current cost. Journal cards show the observed action's mechanics, without inventing a historical forecast using today's hero.

D support is available only on individually eligible items and Gun Break in the appropriate list. It is not a global battle-command toggle and does not apply to arbitrary magic or techniques.

## New battle controls

**Shift+Enter** in N attacks with the highlighted weapon. **Shift+digit** attacks with that numbered weapon. Ordinary selection still equips without attacking; D independently nominates the final executor. Native targeting, normal-attack skill IDs and final-weapon rules apply.

**C → group → preset** opens named six-step macros: four groups, eight presets each. Filled battle entries show paid actions, MP and cooldown. Configure them under **Macros**, immediately below **Loadouts**. Double Esc at battle commands resets an uncommitted queue; Space additionally confirms without replacing Enter. The hotkey is remappable. See [macros](MACROS.md).

D in equipment or Items → Weapons nominates a weapon for the **first controllable input of the battle**, once. It does not re-equip it on later turns.

## Display and map shortcuts

**F10** toggles the original window and your preferred HD mode. With fresh preferences, the HD target is the monitor's resolution. Choosing and confirming another size remembers that size. A smaller HD preset returns to its configured window size; the monitor-size preset uses borderless fullscreen. This does not change Windows display settings.

Fresh installations start windowed. **Fullscreen on startup** in Display settings controls automatic HD startup independently of F10. Existing fullscreen preferences are preserved when updating. Every HD mode forces the sharp pixel filter; DPI-aware startup is required even if the old crisp preference was disabled. If Windows virtualizes the initial window, the existing safe title-screen restart prepares the DPI-aware child before loading a save. F10 itself never restarts an active game.

Field skills remain in the normal menu. Their map hotkey, including Shift+F10, has been removed.

**G** uses the Gear of Madness on the map by reserving the original item's common event. Its SEN selection dialog remains manual. The shortcut requires the item and does not interrupt messages, events, transfers, movement, menus or battle. Rebind it in Controls if desired.

Rabbit's Pocket Watch is included in manual B groups under special items when owned. It remains excluded from automatic support.

## Compact damage numbers

Before choosing a single enemy, N weapons, V techniques and M spells compare the mean damage against the available enemies. Two enemies show up to two values; three or more show minimum, arithmetic mean and maximum. Nearly identical values collapse. These are alternative targets, not a combined attack. Selecting a target shows its individual forecast.

All-target attacks combine the minimum and maximum expected per-target damage with **Σ~, the sum of mean damage** over the actual targets. Random targeting retains its probability-weighted estimate. Unsupported chains are marked, and unknown enemy information remains hidden. Miss, critical, Guard and the valid execution weapon are included by the existing forecast model; multi-hit state changes can leave only the first hit predictable.

F4, H and their F7 details are nested inspections. Esc returns to the previous controller. Opening H from F4 must not leave the enemy chooser deactivated with an unresponsive top window.


## Alternative movement and inspection

W/A/S/Z duplicate Up/Left/Down/Right on the map, in battle and in menus with the controls module enabled. Each letter is checked against the functions actually reserved in that context. In a native item/skill list A/S remain favorites/filter; W/Z still navigate. Remapping favorites/filter frees A/S there too. B palettes do not use favorites/filter input and can use all four directions. D stays assigned to equipment/support until that assignment is moved; after moving it the navigation editor can support WASD. Collection and save-list A/S commands are preserved. Other global/confirm/cancel bindings are never stolen. The alternative can be disabled or rebound under mod settings.

F5 opens the combat journal; its redundant left-side battle command is removed. Cosmetic battle updates continue under V/B/M/N, F4, H and F7. Battle AP, state timers, actions and troop events stay paused. Modal visual random draws use their own stream.

Palette costs/descriptions are cached until relevant state changes. A new inline damage estimate waits about 120 ms of settled selection. Tempo hover previews wait about 100 ms and yield to held navigation; pending marks use `?`. Cached choices and explicit model/reference calculations are immediate. Zero-stock items disappear from B without removing their saved membership; acquiring them restores them. Remaining native skill cooldowns appear as `КД n` in palette rows, including HD.

The Gear of Madness's original SEN dialog also accepts **1 / 2 / 3** for its three displayed choices. No other game dialog receives these keys. New saves include progression (the game's progression counter, not NG+ loops) and currency souls alongside the hero's level. Older headers remain readable; missing metadata is not guessed or recovered from save bodies.

## Usage priorities

Enabled by default with a 20-battle window. Explicit saved choices remain respected. This changes only row order inside existing automatic V/M/N groups; membership, custom profiles and B items are unchanged. Digits match visible positions. Disabling it restores the authored order.

History counts completed battles while enabled. Choose 5/10/20/30; up to 30 battles are retained. Actual skill/magic use and the weapon executing non-instant skills count, capped at five uses per token per battle. Browsing, equipping/nominating and items do not count.

A challenger needs at least 50% more capped uses and three extra uses, observed across several battles. After reordering the group rests for three completed battles. Order commits at battle end; a notification gives changed addresses.

## Enemy tempo stars

Enabled by default, configurable in mod settings. No permanent text panel and no order numbers. A filled star beside an enemy's AP gauge identifies the first enemy before the hero. A hollow star marks another enemy that can also act before the next hero turn. `?` means a possible or unconfirmed outcome. No mark means that enemy is not ahead in the supported forecast; if every visible enemy has no mark, the hero is next **with the option enabled and a supported forecast**. Ally turns are not listed.

Forecasts use current AP and native refresh quanta; live item effects already applied; selected actions in the remaining queue; hovered V/B/M/N or native-list actions; source/final weapon policy; AGI buffs/debuffs, speed states and their supported expiry; and random retained AP as a range. A hovered single-target effect without a selected target considers alternative targets. Choosing the target narrows that preview. N hover previews equipping the weapon, without inventing an attack.

Proposed stuns, AP interruption and chant cancellation are deliberately ignored, even when guaranteed. Already applied restrictions are evaluated through their actual remaining skipped owner turns or frame duration. A stun does not hide a star if the enemy recovers before the hero. Native before-action removal and completed-chant precedence are respected.

This is a conditional tempo forecast, not future enemy AI/damage simulation. Up to 32 outcome worlds are considered. Unsupported common events, channels, later global-turn expiry, frame regeneration, damage-dependent control removal or excess branches show `?`; they never silently imply a hero turn. Future deaths, enemy/ally actions and new choices may change the result. Unknown enemy mechanics retain the knowledge boundary. No live AP, resources or combat RNG is advanced by a preview.

Options are registered before bootstrap reads preferences. Tempo, priority settings and navigation now survive an actual process restart, rather than only an in-memory reload. Final N nomination remains battle-local by design; starting-weapon assignments and user bindings remain separate persistent settings.

## Ctrl battle speed

Mod settings → **Ctrl в бою: мгновенные анимации** is enabled by default. Hold Ctrl before entering a battle and during actions/results to skip presentation delays, including the entry wipe, combat animations, hit/collapse effects, popup durations and exit fades. Battle windows open/close immediately. Active animations are disposed safely when acceleration takes over. Release Ctrl for ordinary presentation; disable the setting for the original Ctrl behavior.

The mode applies to all battles while held, including bosses and spirits. It does not infer enemy strength. It does not select commands/targets, confirm choices, apply extra actions or change AP/chant/state-update formulas. Existing Ctrl text skipping still applies. Scripted timed battle waits retain one cooperative yield; conditional waits for choices/forced actions remain native. Map/menu presentation outside battle entry/return is unchanged. Loading assets and executing game logic cannot be made literally instantaneous.

## Performance tracing

Enable the optional Diagnostics module, then restart the game. **Диагностика производительности** in mod settings toggles five-second local timing summaries without disabling the ordinary journal. It defaults on when Diagnostics is loaded; with Diagnostics disabled, the profiler is not loaded. No hotkey is consumed. This option cannot attach new code to an already running game.

Use the performance records to compare scene/map/modal/focus contexts, ordinary FPS and FPS excluding >1-second gaps, frame-time bounds/slow-frame counts, engine/mod/diagnostic phases, GC/resource counters and known transition/load/overlay waits. Phase times overlap and are not additive; the graphics phase includes native presentation/pacing. No automatic log uploads occur.
