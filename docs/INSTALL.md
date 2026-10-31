# Installation and recovery

[Home](../README.md) · [English / Русский details](LOCALIZATION-099995.md)

Use Windows 10/11 and Windows PowerShell 5.1. Download the full release ZIP and extract it completely: CPython and its standard-library dependencies are included and checked automatically. Installation works offline, does not install Python system-wide and needs no pip packages. The bundled Python and native game helper are x86 and work on 32-bit or 64-bit Windows. GitHub's automatic source-only archives require a separately installed Python 3.12 or newer; use the release asset for normal installation.

1. Extract the mod separately and close the game.
2. Run `Install.cmd`, select the folder containing `Game.exe`, and choose **Check**.
3. Choose **English game**, **Russian game**, or **Auto-detect**. This is the installed game language, independent of the installer interface button.
4. Hover over a choice or focus it with Tab to read its description. Everything defaults on except Advanced Legacy, automatic battle support and diagnostics. Select modules and choose **Install / change selection**. Launch the game normally.

The installer recognizes the exact Russian loose-data profile and original English archive/matching loose data. It refuses unsupported active scripts, wrong language selections and incompatible previous installation records. Loose base Data alongside a verified English archive are preserved; the engine uses the archive. It does not translate the base game.

For English `Game.rgss3a`, no unpacking is required. The verified original is kept at `BS2Suite/Game.original.rgss3a`. A staged copy appends the bootstrap script table and redirects only that archive directory entry; all other encrypted assets remain byte-identical. Allow about 1.1 GB additional free space for the backup and temporary copy. Keep the original backup with that installation.

For loose data, the original script table is kept in `BS2Suite/Scripts.original.rvdata2`; the external loader is inserted into `Data/Scripts.rvdata2`. Engine binaries and game database entries are not replaced. Mod code is in `Mods/BS2Suite`; settings and locale are in `BS2Suite`.

**Update:** close the game and use `Update.cmd` or **Install / change selection**. Recorded development versions through 0.99995-dev are supported. Known mod files are verified, settings retained and a local rollback created. Unknown changes are refused.

**Remove:** choose **Remove modpack**. Packed installations restore the byte-identical original archive; loose installations restore original scripts. Saves, settings, loadouts and journals remain local. Removal cannot reverse inventory/progression changes already saved during play.

If game files were replaced after installation, restore the matching files or use a clean copy. Do not delete backups to bypass verification. Separate game folders are recommended for English and Russian installations.
