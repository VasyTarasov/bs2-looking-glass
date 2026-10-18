# Modules and support

[English home](../README.md) · [Русский](RU.md#модули)

`modules.json` defines the installer options. Everything defaults on except `legacy_shortcuts` and `debug`. Retry requires the defeat screen; the installer keeps that dependency consistent.

| Modules | Purpose |
|---|---|
| `semantic_groups`, `combat_shortcuts`, `legacy_shortcuts` | Curated groups, favorites/native commands and optional advanced legacy controls. |
| `reference_cards`, `action_queue`, `effects`, `battle_stats` | F7/forecast, multiple-action display, effect inspection and journal/statistics. |
| `loadouts`, `equipped_upgrade`, `weapon_family_cleanup` | Named manual sets, equipped upgrades and automatic removal of lower spare family variants. Review cleanup before playing. |
| `soul_batch` | Explicit batch menus for eligible stat and currency souls, excluding key/quest items. |
| `field_skills`, `learned_books` | Field actions and learned-book status. |
| `saves`, `defeat`, `retry` | Save organization, defeat handling and retry. |
| `controls`, `run_toggle`, `sound` | Binding, running/item-speed and volume settings. |
| `steam_bridge`, `hd_display` | Native graphics/Steam integration and HD presentation. |
| `debug` | Opt-in local diagnostics, without automatic upload. |

Support is optional. Only explicitly eligible instant items and Gun Break can be armed. The default mode restores the highest applicable buff/debuff level when reduced, expiring or gone; it does not predict future target tempo. Buffs target the hero; debuffs are maintained separately for eligible enemies.

Healing, cleansing and excluded actions such as Rabbit's Pocket Watch are not automated. Tempo-reserve renewal is a separate experimental setting, off by default. Support does not create free normal-action slots. Equipment sets remain the player's named choices rather than automatic build solving.
