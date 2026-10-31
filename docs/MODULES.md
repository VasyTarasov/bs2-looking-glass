# Modules and descriptions — 1.0

[Home](../README.md) · [Русский](MODULES-RU.md)

All choices default on except Advanced Legacy, automatic battle support and diagnostics. Hover or keyboard focus shows the description. Enabling macros also enables groups; disabling groups also disables macros. Selection changes apply after restarting the game.

## Display and Steam

**HD interface (recommended)** (`hd_display`)

Crisp text, resolution settings and a contextual side panel. Current mod features are designed primarily for this interface.

**Steam integration** (`steam_bridge`)

Enables Steam overlay and screenshot integration. Shares the graphics backend with the HD interface.

## Battle controls

**V/B/M/N combat groups** (`semantic_groups`)

Groups techniques, items, magic and weapons for selection with letters and numbers. Works on its own or alongside Advanced Legacy.

**Advanced Legacy: keyboard shortcuts** (`legacy_shortcuts`)

Assigns actions to Shift/Ctrl and number combinations. Can be used on its own or alongside V/B/M/N groups.

**Battle-list favorites** (`combat_shortcuts`)

Mark skills and items as favorites for quick access in battle lists. Supports native controls, combat groups and Advanced Legacy.

**Action queue display** (`action_queue`)

Displays prepared and executing actor actions. Helps track command order and remaining actions.

**Action macros** (`macros`)

Save sequences of up to six steps and trigger them manually. Supports skills, items and weapons; requires V/B/M/N groups, but not equipment loadouts.

## Battle assistance

**Automatic battle support** (`battle_support`)

Maintains selected item effects, cleanses and Gun Break when appropriate. Each battle starts with no active rules; enable individual actions during battle.

**Hold Ctrl to speed up battle** (`battle_speed`)

Hold Ctrl to shorten battle animations, pauses and transitions. Commands and targets are still selected manually.

## Information

**Reference, effects and forecasts** (`reference_cards`)

Detailed F7 cards, H participant/effect inspection and action forecasts. When an outcome cannot be reliably calculated, its forecasting limitation is shown.

**Battle journal and statistics** (`battle_stats`)

Records observed actions and results for the battle journal and summary. Enemy attacks appear as they are observed.

## Equipment

**Equipment loadouts** (`loadouts`)

Save named equipment sets and apply them manually. Missing items and equipment-change restrictions are respected.

**Upgrade equipped weapons** (`equipped_upgrade`)

Upgrade currently equipped weapons without removing them first. The game determines upgrade costs and conditions.

**Automatic obsolete-equipment cleanup** (`weapon_family_cleanup`)

Removes lower equipment variants when corresponding upgrades are owned. Changes inventory; disabling it does not restore items already removed.

## Exploration and conveniences

**Interaction highlighting** (`map_highlight`)

Hold Alt to highlight available useful interactions on the current map. Helps find objects that still have something to offer.

**Field skills** (`field_skills`)

Provides a separate menu for skills available outside battle. Supported stealth can be renewed automatically at its normal MP cost.

**Batch soul consumption** (`soul_batch`)

Consume eligible souls in a chosen quantity. Key and story items are excluded.

**Convenient saves** (`saves`)

Adds 100 slots, sorting, labels and quick-save access. Save lists show additional progression information.

**Basic conveniences** (`basic_qol`)

Key remapping, volume controls, running options and learned-book markers. Individual settings are available in the game.

## Additional

**Diagnostics** (`debug`)

Keeps local error logs and performance information. Reports are not sent automatically.

Automatic support must first be installed/enabled as a module, then opted into per row during each battle with D. Shared services are selected automatically and have no extra installer checkboxes. Steam integration and HD use one native backend, but enabling HD does not enable Steam integration.
