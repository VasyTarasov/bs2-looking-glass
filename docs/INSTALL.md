# Installation and recovery

[English home](../README.md) · [Русский](RU.md#установка)

## Compatibility and requirements

Use Windows, Python 3.12 on PATH (`python --version`) and Windows PowerShell 5.1. The Python installer uses the standard library. The own native helper is x86, matching RGSS3.

Only the recorded loose-data profile in `build_profile.json` is supported. An encrypted `Game.rgss3a`, another translation or unrelated script edits can be rejected. Do not replace the profile to silence a failed check.

## First installation

1. Back up saves yourself, close the game, and extract the mod separately.
2. Run `Install.cmd`, select the game's folder and use **Check**.
3. Select modules, then **Install / change**. Use **Русский** to switch installer language.
4. Launch through Steam normally when using Steam features.

The installer preserves the original script table and inserts an external bootstrap into `Data/Scripts.rvdata2`. Own code goes to `Mods/BS2Suite`; settings are in `BS2Suite`, with historical settings in `BS2QoL` / `BS2Modules`. Engine binaries and personal save contents are not edited by the installer.

## Update

Close the game and run `Update.cmd`. It explicitly recognizes the recorded previous previews through `0.9.8-alpha` and `0.91-dev`, checks script/mod integrity, keeps settings and creates `BS2Suite/rollback-*` before writing. Partial writes roll back. A running target or foreign edit causes refusal.

New development labels are explicit identifiers, not numerical upgrade comparisons. If you edited files manually, preserve and compare them; do not force the updater to overwrite unknown code.

## Removal and recovery

Use **Remove modules** with the game closed. The recorded original script table is verified before restoration. Settings, named loadouts, logs and saves remain local. Removal cannot undo inventory/progression changes already saved during play, including consumed souls or family cleanup.

Keep the original backup, install record and matching package. A damaged/mismatched backup is refused. Do not replace scripts while the game runs, or use another player's backup.
