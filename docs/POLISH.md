# 0.9997-dev: whole-pack audit

This is a development candidate. The audit includes references, effects, automation, equipment, economy, saves, map interaction, controls, audio and rendering lifecycle. It does not certify a full playthrough or every reachable story condition.

## Corrections

- Preserve reviewed explanations of story rings, map stealth, movement speed and conditional actions when the compiled reference supplies only a short summary.
- Show on-hit TP gains, with the native TCR multiplier, and the selected actor's learned status in book references.
- Use English procedural mechanics when EN is selected. Keep translated delayed/follow-up rules and native formulas; Russian interface panels remain Russian.
- Keep effect-source identity rather than matching an equipment name against arbitrary actor/class rows.
- Show actual ATB counters in H, consistently with the detailed effects view. Frame states without automatic removal show infinity. Counts are internal counters, not a promise of full controllable turns.
- Preserve the global inventory-cleanup state while previewing a loadout and after a failed upgrade. Existing rollback of items, equipment and souls is retained.
- Explain unchanged primary parameters in a loadout comparison and point to the property reference.
- Permit currency-soul batching without a selected stat-soul recipient. Keep currency overflow atomic.
- Match the original colored-soul events' displayed-stat variables as well as real parameters, SEN and stock.
- Repair public QA suite routing, including live09996, and accept a verified installed loader through the normal read-only compatibility check. Test preparation uses its verified original script backup, not an unrecognised altered script table.

No game formula, original database, game executable or native renderer binary is changed by this candidate. Eight existing own-module files change. Settings and player saves are preserved by the updater. Effects, support and loadout hints follow reassigned controls; unavailable reference controls are not advertised.

## Current native suites

- `polish_content`: RU/EN content, every skill-book learned state, TP rewards, storage rules, effect-source collisions, real state expiry and H counters.
- `polish_support`: all 14 eligible items for both protagonist records; stock 0/1/refill; bounded maintenance; multiple targets; failed debuffs; manual opposing-debuff decisions; field stealth payment and renewal.
- `polish_gunbreak`: four real equipment-supplied interrupts; native instant execution/cooldown, explicit noninstant proposal, loss of equipment and unavailable follow-up service IDs.
- `polish_inventory`: native equipment/loadout operations, ring multiplicity, locked/missing slots, exact quantities, preview purity, failure rollback and real dialogs.
- `polish_economy`: real common-event interpreter oracle for ten colored/black soul types and currency; full upgrade rollback. Only dialog answers/quantity are supplied by the QA interpreter.
- `polish_system`: controls and focus, four audio channels, running, five quick slots, rotation, write failure and game save restrictions.
- `module_boot`: load and actual menus with individual/reduced module profiles. Successful startup does not prove every behavior in every profile.

Use `tools/prepare_test.py` with a separate test folder and one of the suite names above, followed by `tools/run_private_test.ps1`. The prepared fixture is silent and Steam-free; personal saves and authentication files are excluded. Historical suites with superseded version, input or forecast contracts remain historical evidence rather than being counted as current passes.

## Remaining scope

- The previously reported RGSS301.dll access violation around F12 remains open. Two live fresh-process title-screen restarts and normal exit completed with exit code zero during this audit. That does not establish the cause of the earlier crash. The renderer and restart implementation are unchanged.
- The reference and numerical corpora cover many records and controlled situations. They do not establish every multi-action distribution, scripted battle threshold or later story state.
- The map-page corpus classifies the controlled initial environment. Current-page and selected conditional gates have focused tests; all reachable event outcomes are not proven.
- Equipment cleanup intentionally removes surplus non-ring spares and obsolete linear ancestors. It preserves all ring copies/tiers and equipped items. Disabling the module does not restore previously removed inventory.
- No new claim is made about every GPU/DPI/display combination, Steam Recording or every third-party mod.
