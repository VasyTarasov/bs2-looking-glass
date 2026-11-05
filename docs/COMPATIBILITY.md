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
