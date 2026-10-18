# Looking Glass for BLACK SOULS II

[![Русский](docs/assets/ru.svg)](docs/RU.md)

**See your options. Keep your choices.**

An unofficial, modular collection of combat controls, practical reference cards and interface improvements for BLACK SOULS II.

**Development build: `0.994-dev`. No stable release.** Based on the locally tested `0.9.8-alpha` preview. This is a development repository, without release tags or automatic release publishing.

## Features

| Area | What it adds |
|---|---|
| Combat | Growing V/B/M/N groups, favorites, keyboard target selection and optional legacy controls. |
| Equipment | Immediate weapon selection, independent starting/final weapons, named loadouts and detailed comparisons. |
| Reference | F7 cards with actual formulas, effects, costs and supported forecasts. Inspect observed enemy attacks from the combat journal. |
| Support | Optional maintenance for explicitly eligible items and Gun Break; healing, cleansing and excluded actions remain manual. |
| Presentation | OpenGL output, resolution presets up to 4K and ultrawide, sharp HD text and a contextual side panel. The original world frame remains scaled. |
| Convenience | Batch souls, upgrading equipped weapons, equipment-family cleanup, save labels, running and item-speed settings. |

Reference coverage: 990 named skills/attacks, 246 items, 371 weapons, 241 armor/ring entries and 230 named states. Static facts and live forecasts remain separate. Unknown enemy parameters stay behind the knowledge setting; the journal does not list a boss's future moves.

## Before installing

- Windows and a legally obtained copy of BLACK SOULS II.
- **Only the exact loose-data build in `build_profile.json` is currently supported.** An encrypted archive, another translation or modified scripts can be rejected. Do not bypass that check.
- Python 3.12 available as `python`, plus Windows PowerShell 5.1. Installation requires no Python packages.
- Back up your saves and close the game before installing, updating or removing modules.

Documentation and the installer default to English, with a Russian switch. **The in-game UI is still predominantly Russian, including the newly verified reference explanations.** English documentation does not imply complete in-game English localization.

## Install

1. Use **Code → Download ZIP**, or clone this repository. Extract it outside the game folder.
2. Run `Install.cmd`, choose the folder containing `Game.exe`, then click **Check**.
3. Select modules and click **Install / change**. Everything defaults on except legacy controls and diagnostics.
4. Launch the game normally. Configure controls, modules and display from the mod settings.

Existing verified previews through `0.992-dev` can use `Update.cmd` with the game closed. **First installation adds an external bootstrap to `Data/Scripts.rvdata2` and preserves its original backup.** Module-only updates replace verified mod files and installation metadata. They do not replace the game executable, engine DLLs or saves. See [installation and recovery](docs/INSTALL.md).

## Essential controls

| Key | Purpose |
|---|---|
| V / B / M / N | Techniques / items / magic / weapons: group, then entry; at most 10 entries per group. |
| Repeat the active letter | Back one level. Esc closes the menu. |
| Q / E | Adjacent groups; inside a V/B/M/N F7 card, adjacent entries in that group. |
| F7 | Contextual details, including observed attacks in the journal. |
| H | Participants and effects; Enter/F7 opens the selected participant. |
| F5 | Combat journal. |
| D on an N weapon | Nominate the final weapon; repeat D or N N clears it. |
| D in equipment / Items → Weapons | Assign a separate weapon for the beginning of a turn; repeat D clears it. |
| F12 | Clean return-to-title restart with the bridge enabled. Pick another screenshot key in Steam. |

A technique with one original action uses its source weapon. Magic and action-consuming items can use a nominated final weapon. Instant actions and invalid swaps have separate rules: [controls and execution](docs/CONTROLS.md).

## Guides

- [Install, update, remove and recover](docs/INSTALL.md)
- [Controls and weapon execution](docs/CONTROLS.md)
- [Modules and optional automation](docs/MODULES.md)
- [Compatibility and troubleshooting](docs/TROUBLESHOOTING.md)
- [Development and verification](docs/DEVELOPMENT.md)
- [Version policy](CHANGELOG.md)
- [Privacy and bug reports](SECURITY.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)

Steam overlay visibility and screenshots were confirmed in the development setup. Recording was observed, but playback/export and every HD/Steam combination were not validated. No universal recording guarantee is made.

Included runtime assets are the project's x86 helper and a generated factual reference view. The game, RGSS engine, Steam API library, original game description prose, personal saves, local logs and conversation exports are excluded. Original-code licensing has not been selected; third-party licenses are preserved.

## 0.992-dev changes

Enemy tempo uses AP-gauge stars instead of a text panel, with queued/hovered speed effects and supported existing-control expiry. Tempo and usage priorities default on; history defaults to 20 battles. Fixed late option registration losing saved settings across restarts. Navigation exclusions now follow actual key conflicts. B hides exhausted items; palettes show remaining cooldowns; new save headers include progression/souls; Gear choices accept 1/2/3. Automatic acceleration of supposedly weak enemies is deferred until boss/spirit classification and timing-safe behavior can be verified. See [controls](docs/CONTROLS.md) and [local verification](docs/QA.md).

## 0.993-dev native-resource fix

Enemy gauge buffers are six pixels high instead of full-screen, and their private bitmaps are explicitly released at teardown. Native temporary render allocations are collected after a completed battle teardown, outside input and AP updates. Enabled diagnostics now record this process's private memory, working set and graphics/handle counters without reading memory contents.

The old gauge-lifetime defect was reproduced in the reported area's battles: eight transitions retained 56.25 MiB of gauge pixels. With the fix, forty cycles retain none; the actual 2560×1440 HD test has stable warmed memory and graphics handles. This fixes a demonstrated allocation defect; no native stack was available to prove it was the only contributor to the reported C++ termination. Steam bridge/engine binaries are unchanged. See [verification](docs/QA.md). This build includes the 0.992-dev changes above.

## 0.994-dev: instant battle presentation with Ctrl

Hold **Ctrl** to remove combat animation/log pauses and shorten battle entry/exit transitions to zero or one displayed frame. It also finishes active hit/collapse animations, removes lingering damage popups, opens battle windows immediately and settles battle screen/picture effects. The **Ctrl in battle** option is enabled by default; disable it to retain the original Ctrl behavior. Releasing Ctrl restores normal presentation. Choices and command/target selection remain manual; AP progression, action application, costs and rewards use the native pipeline. Resource loading and the actual game calculations still take time.

Native hit-shake randomness now uses the existing separate visual stream in both modes, so skipped shake effects do not shift combat random rolls. Four controlled full battles match in actions, effects, final state/rewards and RNG tails. This build includes the 0.992/0.993 fixes. See [controls](docs/CONTROLS.md) and [verification](docs/QA.md).
