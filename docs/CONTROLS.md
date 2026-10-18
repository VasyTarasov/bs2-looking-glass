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

W/A/S/Z duplicate Up/Left/Down/Right on the map and in battle, with the controls module enabled. D retains weapon/support assignments. Item lists and B item palettes keep their original controls, so favorites and filtering remain available there. In other menus A/S retain their existing assignments. The alternative is on by default and can be disabled or rebound under mod settings. Existing custom global bindings are not stolen; a conflicting alternative letter is ignored.

F5 still opens the combat journal; its redundant left-side battle command is removed. Cosmetic battle updates continue under V/B/M/N, F4, H and F7: breathing, mist, animations and screen effects. Battle AP, state timers, actions and troop events stay paused. Modal visual random draws have their own stream.

Palette descriptions and costs are cached until relevant state changes. A previously unseen damage estimate waits for about 120 ms of settled selection and yields to held navigation; a temporary ≈ … indicates calculation is pending. Explicit model/reference calculations are not delayed. Returning to a cached choice is immediate.

## Experimental usage priorities

Off by default. This changes only row order inside existing automatic V/M/N groups. It does not change membership, create groups, include excluded weapons or alter custom profiles/B items. Digits are reassigned consecutively to match visible positions. Disabling the option returns the author's order.

History uses completed battles recorded while the option is enabled. The default window is 20, selectable as 5/10/20/30; up to 30 battles are retained when changing windows. Actual skill/magic uses and the weapon executing non-instant skills are counted. Browsing, nominating a weapon and item use do not count. A weapon/skill contributes at most five uses per battle, limiting one long fight's influence.

A challenger needs at least 50% more capped uses and at least three extra uses. At least three battles must be observed; the candidate must occur in three battles, or two for the five-battle window. After reordering a group rests for three completed battles. Ordering is committed at battle end, never during selection. Changes appear through the existing layout notification, with old/new addresses.

## Optional enemy tempo hint

Off by default. The sidebar, or a compact classic battle panel, lists enemies whose first gauge readiness precedes the hero's next gauge by the current native AP rates. Ally turns are omitted. The calculation uses the engine's AP gain and refresh quantum, existing enemy gauge progress, and the applicable final/source weapon for the selected last action. Random post-action AP is treated as a range.

This is a conditional current-tempo aid, not a simulation of the future battle. New/expiring effects, deaths, incomplete queues, allies' future actions and enemies' repeated turns can change it. Channeled actions can remain unconfirmed. It does not inspect enemy AI, and unknown enemy mechanics remain behind the knowledge boundary. Actual AP/RNG is never advanced to make the prediction.
