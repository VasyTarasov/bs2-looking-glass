# Installation and recovery

[Home](../README.md) · [English / Русский details](LOCALIZATION-099995.md)

Use Windows 10/11 and Windows PowerShell 5.1. Download the full release ZIP and extract it completely: CPython and its standard-library dependencies are included and checked automatically. Installation works offline, does not install Python system-wide and needs no pip packages. The bundled Python and native game helper are x86 and work on 32-bit or 64-bit Windows. GitHub's automatic source-only archives require a separately installed Python 3.12 or newer; use the release asset for normal installation.

1. Extract the mod separately and close the game.
2. Run `Install.cmd`, select the folder containing `Game.exe`, and choose **Check**.
3. Choose the **Mod language**: **English**, **Russian**, or **Auto-detect**. This selects the mod interface and reference language, independently of the installer interface button; it does not translate the base game.
4. Hover over a choice or focus it with Tab to read its description. Everything defaults on except Advanced Legacy, automatic battle support and diagnostics. Select modules and choose **Install / change selection**. Launch the game normally.

The installer checks BLACK SOULS II structure, core mechanics and the original RGSS301 engine instead of an exact archive hash or language whitelist. Translation, script labels, compression and added scripts are not automatic conflicts. Known conflicts, a replaced engine, damaged data, and modifications to an active QoL installation still produce specific refusals. Extra mods can change behavior even when installation succeeds. Install game patches and translations before QoL Pack.

For `Game.rgss3a`, no unpacking is required. The verified original is kept at `BS2Suite/Game.original.rgss3a`. A staged copy appends the bootstrap script table and redirects only that archive directory entry; all other encrypted assets remain byte-identical. Allow about 1.1 GB additional free space for the backup and temporary copy. Keep the original backup with that installation.

For loose data, the original script table is kept in `BS2Suite/Scripts.original.rvdata2`; the external loader is inserted into `Data/Scripts.rvdata2`. Engine binaries and game database entries are not replaced. Mod code is in `Mods/BS2Suite`; settings and locale are in `BS2Suite`.

**Update:** close the game and use `Update.cmd` or **Install / change selection**. Verified 1.0, 1.01 and recorded development versions through 0.99995-dev are supported. Known mod files are verified, settings retained and a local rollback created. Unknown changes are refused.

With **RMModLoader 2.4–2.6**, launch through `Loader.exe`. The adapter reads `mod_loader/Data` before the base archive, adds `mod_loader/scripts/999999999 - BS2Suite.rb`, and leaves game/translation data unchanged. Loader HRFix/fast-render options are disabled while QoL HD is selected; its controls override is disabled with basic QoL controls. Removal restores the original settings while retaining later unrelated user edits. DisplayMod is not supported.

**Remove:** choose **Remove modpack**. Packed installations restore the byte-identical original archive; loose installations restore original scripts. Saves, settings, loadouts and journals remain local. Removal cannot reverse inventory/progression changes already saved during play.

If game files were replaced after installation, restore the matching files or use a clean copy. Do not delete backups to bypass verification. Separate game folders are recommended for English and Russian installations.
