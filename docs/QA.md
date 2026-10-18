# Verification of 0.91-dev

Repository preparation was checked locally on Windows. This is a development preview, not a stable release or a claim of remote CI success.

| Check | Result | Assertions |
|---|---|---:|
| reference_classic | PASS | 7562 |
| reference_hd | PASS | 7565 |
| weapons | PASS | 1077 |
| modules | PASS | 69 |
| minimal | PASS | 22 |
| installer | PASS | 55 |
| updater | PASS | 151 |
| Game-free repository tests | PASS | 18 |
| Windows PowerShell 5.1 parsing / BOM | PASS | 3 scripts |
| Installer headless language check | PASS | English default, Russian switch, 22 modules |

The native runs used the documented preparer and hardened private-desktop launcher, requiring exit code 0 and result=PASS. They included every named reference card, journal F7, unnamed service actions, active HD rendering, 105 weapon scenarios, module combinations and a minimal setup. Synthetic installation/update checks included failure rollback, file-integrity refusal, preservation of synthetic settings/saves and 0.9.8-alpha → 0.91-dev.

The player's installed game was not changed and personal saves were not used. All original runtime assets remained in local fixtures outside the repository. Logs, private paths and screenshots were excluded. Original description prose was removed from 2,602 English alias entries; short names remain. The two shipped runtime assets have an explicit hash allowlist, with source/third-party notices.

The publication audit checks file paths, source credential patterns, encodings, relative documentation links, binary hashes and staged index bytes. It reports rule names rather than matching credential values. This is not a guarantee against every possible future secret or malicious change.

Steam recording playback/export and all driver/DPI/monitor combinations were not retested. Scripted events can remain partial forecasts. New reference explanations remain Russian. GitHub Actions has not run before the first upload.
