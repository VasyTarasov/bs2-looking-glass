# 0.9999-dev: automatic cleansing and item spending

This implements the first proposed expansion: seven narrow cleanses, optional fire-resin thawing and Hlanith wine. Healing thresholds, cooldown watches, immortality and Necronomicon automation remain deferred. Pollen retains the previously documented solo-protagonist gate.

| Item | Native objective |
|---|---|
| Antidote herb (4) | Remove poison (2) or deadly poison (3) |
| Blood stopper (5) | Remove bleeding (26) |
| Sedative (6) | Remove unwanted madness (28) |
| Water (53) | Remove oil (5) or burning (29) |
| Viagra (54) | Remove weakness (55) |
| Smouldering candle (76) | Remove fear (56) |
| Mermaid voice (94) | Remove silence (17) |
| Hlanith wine (107) | Native bonus-action state (222), at most one use per battle |

All items require explicit activation. Use the configured automation key on the item (D by default), or **Mods / options → Automatic items: rules and spending**. The settings screen lists all 24 accepted item records, permits individual activation and stores per-protagonist rules. Enter opens actions; left/right changes reserve/limit/thaw, Escape returns. Right from the item list opens the scrollable description.

Consumable rules include a protected stock reserve and a battle spending limit. New cleansing items default to reserve 0 and limit 3. Existing buffs default to reserve 0 and no limit. A limit of 0 means unlimited. The cap applies to automatic consumptions only; manual item use is not intercepted or prohibited. Pausing or reconfiguring support does not reset battle spending. Every actual battle resets its counters. Settings are bounded plain text in `battle_support_rules.ini`; a failed write preserves the previous in-memory values.

Cleansing is due only when a removable state is currently present. It is prioritized before ordinary upkeep, requires a native usable item and existing input opportunity, and uses the original quick-item executor. No target resistance or future enemy action is read. Each selected cleanse can be attempted only once in a real protagonist input period, even if the state immediately returns. A failed attempt waits for a later real period and remains bounded by the spending cap. Missing stock or reaching the reserve does not silently disable the saved activation.

Madness is protected when its automatic upkeep is configured, when the native Necronomicon state is present, or when an actor deliberately applied a friendly madness effect. The intentional marker is cleared when madness is removed or states are cleared; later hostile madness does not inherit it. Support waits under native input/item restrictions rather than acting through sleep or other inability to use an item.

Fire resin's original mode remains the default. Its separate thaw option also makes frostbite a due objective while the fire buff is fresh. The native item still applies both real effects. It shares that item's reserve and spending limit and is bounded to one cleansing attempt per input period.

Wine is not consumed and never forces action-list recreation. Its native state determines the actual bonus. Native manual use also marks it used for the battle, so automatic support does not reapply it even if its state later disappears. It can be used again in the next battle.

The independent native `cleanse09999` suite covers both protagonist records, all native removal targets, absent/combined states, stock refill, reserve/cap behavior, repeated states, injected removal refusal, intentional-madness provenance, thaw modes, native wine and manual use, restrictions, settings windows and persistence. The existing 16-item upkeep matrix and resin/UI, menu, Gun Break and control regressions remain separate checks.
