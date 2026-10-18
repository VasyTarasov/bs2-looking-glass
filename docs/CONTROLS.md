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
