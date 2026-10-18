# Development

[English home](../README.md) · [Русский](RU.md#разработка)

| Path | Contents |
|---|---|
| `mod/BS2Suite` | External Ruby modules. Legacy internal names stay stable for settings/upgrades. |
| `native/steam_bridge` | Own x86 helper and MinHook sources/licenses. |
| `tools` | Installer, updater, local audit, packager and isolated QA preparation. |
| `tests` | Synthetic tests; no game runtime or personal fixtures. |
| `build_profile.json` | Compatibility fingerprints, not game files. |
| `runtime-assets.json` | Explicit allowlist and hashes for distributed runtime assets. |

Before staging: `python tools/repo_audit.py`. Before upload: `python tools/repo_audit.py --staged`. This checks paths, privacy patterns, encodings, relative documentation links, hashes and forbidden binaries. It is a gate, not proof against every possible future secret.

Game-free checks: `python -m unittest discover -s tests -p test_repository.py`. Package with `python tools/package.py --output <outside-repository.zip>`; it audits, writes an archive manifest and verifies it. It does not create a GitHub release.

Build the DLL from an **x86 Native Tools Command Prompt for Visual Studio**, with Windows SDK, using `native/steam_bridge/build.cmd`. Preserve MinHook notices. Review a rebuilt DLL and explicitly update `runtime-assets.json` before packaging. Never distribute or replace Game.exe, RGSS301.dll or steam_api.dll.

Native QA needs a separately owned compatible runtime and synthetic fixtures. Use only the hardened `tools/run_private_test.ps1`: verified silent harness, private desktop, timeout/job isolation, exit code 0 and `result=PASS`. Never test against a live player game. `tools/prepare_test.py` can prepare local fixtures; original assets and local fixture paths are absent from Git.

The baseline tests include reference/journal, action execution, 105 weapon scenarios, menus and installer/updater recovery. Repository-specific changes receive separate validation; see [QA](QA.md). No local logs or screenshots are uploaded. CI runs game-free checks only and has no publishing permission.

`reference098.rvdata2` is an array-only generated Marshal view of factual mechanics, not a save or original RPG database. English aliases contain names only; original English descriptions were removed. The complete research database, maps and event-command dumps are not published. `tools/build_reference098.py` accepts a separately prepared research database and local game, validates seven table hashes and regenerates the UI view without executing formulas or reading saves.

Keep static facts separate from live cost/weapon forecasts. Do not turn original descriptions into mechanical evidence or reveal unknown enemy parameters through previews.
