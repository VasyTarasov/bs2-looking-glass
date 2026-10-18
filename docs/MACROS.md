# Battle macros

[Русский](RU.md#изменения-0997-dev)

Open **Macros / Связки** immediately below **Loadouts / Комплекты** in the main menu. This feature requires Semantic Groups and Loadouts. It has the same eight preset slots as equipment sets. Each preset has a name, a unique digit from 0–9, and up to six ordered action rows. Empty presets initially use consecutive digits.

Select a row, then V/B/M/N. Choose an existing semantic group or the full available list of that type. Lists contain at most ten choices per page. Q/E or Left/Right change pages. F7 inspects the highlighted action. A technique records its weapon source; an N row records that weapon's normal attack, including special normal-attack IDs. Guard is a separate row choice. Ally-targeted rows default to the acting hero; change the target in the row menu. Rename, change the preset's digit, then **Save**. Leaving without saving discards the draft.

Press **C** during battle command selection. Choose a preset by its displayed digit or Enter. C/Esc closes the picker; H still opens participant effects. The key is configurable in Controls. If an older custom binding already uses C, the new command receives an unused binding without resetting existing controls.

The picker displays the number of actions that spend a slot. A preset is disabled when this exceeds the actor's remaining actions. Instant items do not inflate that count. One target selection is shared by single-target hostile rows when several enemies are present. Area/random actions retain native targeting; ally targets come from each row.

Paid rows enter the normal action queue. Instant rows execute at their specified positions, including between paid rows or after the last one. They are not all applied early during input. A preset containing only instant rows executes once without spending a paid slot. Native costs, cooldowns, item stock, per-turn limits, effects, targeting and RNG remain in force. Actual availability is checked again when a row executes; if it fails, remaining rows from that preset stop. Already completed effects are retained. Other manually selected actions remain independent.

The final N nomination still follows the ordinary executor policy. A sole weapon technique uses its own source; final magic and eligible items can use the nominated weapon. Normal attacks preserve their selected skill ID. A macro is a manually chosen finite sequence, not an expansion of automatic item support or enemy AI prediction.

Profiles are bounded text in the local mod settings directory. Updating modules preserves them. They contain action references and names, not copies of game saves.
