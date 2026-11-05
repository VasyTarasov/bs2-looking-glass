# Compatibility in 1.02

[Home](../README.md) · [Installation and recovery](INSTALL.md)

The installer recognizes BLACK SOULS II by its script structure, stable database mechanics and original RGSS301 engine. Exact archive bytes, script compression, script labels and translated names are not build identifiers. The mod UI supports Russian and English. Other translation names are retained from the installed database; installing the pack does not translate the game or restore missing game content.

Test inputs checked on 5 November 2026:

| Game or loader | Coverage |
| --- | --- |
| Larry translation, base 1.01 and fixes 1.06 | Install, reconfigure, remove and reinstall; native gameplay checks on 1.06 |
| Older BS2RU_v5 | Install lifecycle and native reference/battle checks |
| Original saved English restoration archive and current official English patch | Install lifecycle; native checks on current patch |
| Clean English Steam installation | Install lifecycle and native reference/battle checks; this is not a replacement for the restoration patch |
| Official RMModLoader 2.4, 2.5 and 2.6 | Install lifecycle and native Loader startup/reference/battle checks |
| Forge translation layout | Installer checks using its actual translation overlay and extra scripts; individual third-party features are not certified |
| Localized names, different script ids/compression, added harmless script and archive padding | Synthetic variations built from the real game inputs |

With RMModLoader, the pack reads the active `mod_loader/Data` overlay and installs a late bootstrap. Continue launching through `Loader.exe`. Game archives, databases and translation scripts are left intact. Competing Loader display/input options are disabled only while their QoL counterparts are selected, then restored on removal. Later unrelated Loader settings are retained.

If an object's mechanics differ from the reference catalog, its old explanatory entry is hidden and the card uses current game properties. Translated names come from the installed database. This reduces stale documentation; it cannot prove compatibility with arbitrary gameplay scripts or content overhauls.

DisplayMod is excluded. A replaced engine, damaged database, missing required game classes, or changed files belonging to an active QoL installation can still prevent installation. These checks protect native display/input hooks and recoverability. Apply translations and game patches before QoL Pack. Do not delete installation records or backups to force an update.

The test harness uses isolated copies, disables Steam calls and audio for tests, and creates its own game state. It does not copy player saves. Passing these tests does not certify every operating system, GPU, Steam overlay, third-party script or playthrough route.

## Real Steam launch follow-up

Six genuine Steam launches (clean English, both restoration archives, Larry before/after fixes, BS2RU_v5) and three Loader launches with Steam running passed startup, HD presentation and battle-reference checks. Game audio and Input remained active. These are controlled scenarios, not complete playthroughs.

A background-start bug was fixed: the bridge now finds this process's RGSS window instead of assuming it is the active window. Loader installations create `steam_appid.txt` only if the game's Steam API is present and no app-id file exists. Existing files and later user edits are preserved; uninstall removes only an unchanged file created by the pack. API and overlay attachment were separately confirmed with Loader 2.6. The first English test fixture omitted `steam_api.dll`; including that file from the complete official patch resolved the pre-mod startup failure. Always install the complete patch.

Automatic restart through Game.exe is blocked while ModLoader.dll is loaded, because it would discard the loader and its mods. This includes F12 and the HD DPI-restart button. Exit normally and launch Loader.exe again. The blocked F12 path retained the running modded game and passed its battle-reference checks.

Interactive Shift+Tab open/close remains unconfirmed. No experimental overlay-keyboard routing changes are included. The original Steam files and all 99 player save files were restored unchanged. Update from the initial 1.02 archive is supported without resetting module selection or macros.
