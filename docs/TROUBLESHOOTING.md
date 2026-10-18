# Compatibility and troubleshooting

[English home](../README.md) · [Русский](RU.md#неполадки-и-ограничения)

**Unsupported build:** check edition and `build_profile.json`. Only the recorded loose-data game is validated. Do not disable integrity checks for another translation.

**No Python:** install Python 3.12 and make `python --version` work in a new terminal. The installer does not automatically download executables.

**Update refused:** close the game. Preserve manual changes before investigating. Do not delete the original backup to silence an error.

**HD:** select a display preset in mod settings and confirm that it works. OpenGL scales the original frame and renders the side panel separately; it does not replace every old game screen with a new native-resolution layout. Windows DPI, drivers and monitor combinations can affect clarity.

**Steam:** launch through Steam and inspect bridge status. Overlay and screenshots were confirmed in development. Recording was seen, but playback/export and all HD combinations were not fully verified. Steam chooses the screenshot key; keep plain F12 for the return-to-title workflow through a clean restart.

**Missing forecast:** hidden target knowledge, unsupported formulas, scripted events or a conditional chain can prevent a complete number. The UI must indicate this instead of inventing a total. Base MP cost is not necessarily the current cost with your equipment.

**Diagnostics:** opt in only when needed. `Collect-debug.cmd` creates a local archive, without uploading it. Labels, profiles and local paths can be included; review it before sharing. Never attach your entire game folder, saves or credentials.
