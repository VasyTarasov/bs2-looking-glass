# Looking Glass for BLACK SOULS II

[![Русский](docs/assets/ru.svg)](docs/RU.md)

**See your options. Keep your choices.**

An unofficial, modular collection of combat controls, practical reference cards and interface improvements for BLACK SOULS II.

**Development build: `0.92-dev`. No stable release.** Based on the locally tested `0.9.8-alpha` preview. This is a development repository, without release tags or automatic release publishing.

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

Existing verified previews through `0.9.8-alpha` can use `Update.cmd` with the game closed. **First installation adds an external bootstrap to `Data/Scripts.rvdata2` and preserves its original backup.** Module-only updates replace verified mod files and installation metadata. They do not replace the game executable, engine DLLs or saves. See [installation and recovery](docs/INSTALL.md).

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
