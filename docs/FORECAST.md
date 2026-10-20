# Forecast scope and evidence

[Русский](RU.md#проверка-расчётов-09991-dev)

A development preview is not a proof of every game state. The old “605 checks” figure counted the whole suite (controls, equipment, installation-related interactions, etc.); it did not mean 605 independently verified damage mechanics. The two reported sequences were regression examples, not exceptions patched by their IDs. Version 0.9991-dev broadens the oracle tests and fixes common calculation paths.

## What changed

- **Counters:** this installed game applies the incoming hit before the counter. A counter therefore does not remove its damage. Reflection is checked only in the non-counter branch. Outgoing hit probability uses that ordering; the counter's response damage is not silently propagated into subsequent steps.
- **Means:** critical chance, Guard bypass, miss/evasion/cancellation and healing void/inversion use their probabilities. Small integer-variance distributions are summed with native triangular weights. Large linear distributions retain an approximate midpoint with less than one point of per-hit rounding error; large nonlinear survival/MP cases decline a mean.
- **Transitions:** resistance/luck is read again after each earlier effect, including successive states inside a normal-attack state list. Restriction cleanup and same-hit removed-state rules match the engine. Read-only actor copies retain their actual party index.
- **Resources:** a preceding hit on an enemy does not make the caster's unchanged HP/MP unknown. Unsupported residual victim HP/MP/TP dependencies, survival checks and possible bodyguard redirects are stopped instead of using the original resources again.
- **One context:** battle F7 Targets, execution MP cost, weapon source and short V/B/M/N damage use the selected sequence's supported state branches. An in-progress sequence no longer presents isolated current-state numbers as its execution result. A first-slot recovery component may still use the explicitly labelled standalone first-hit view; queued recovery under unsupported modes stays unknown.
- **Selected variants:** a state-dependent skill ID is resolved once at selection. Selecting its target does not transform that ID a second time. F7 resolves the variant before projecting the final weapon, which may remove the state that enabled the selection.
- **Honest scope:** direct damage plus an unmodelled event is labelled as a partial action. Known unsupported repeated responses, drains/resource conversion, late state-dependent instant-skill IDs and uncertain death/retargeting cannot produce an unqualified whole-action/series total. A late exception clears the current partial number.

## Independent native evidence

The oracle is the installed engine's own formula/effect/targeting code in synthetic, Steam-free private-desktop fixtures. Preview code never calls arbitrary Ruby formula eval, native item application or RNG; those are used only by the isolated test oracle.

| Check | Coverage | What it establishes |
|---|---:|---|
| Actual database formula expressions | 824 comparisons | All 206 unique expressions in four HP/MP/state contexts agree with native eval |
| Database classification | 1,389 skill/item records | All rows are classified; 648 contain formula damage/recovery |
| Native first-hit corpus | 15,552 applications | Each of those 648 records × hero/buffed hero/enemy user × 8 seeds |
| Landed first-hit corpus | 13,268 range comparisons | All observed formula-damage/recovery results fit the corresponding conditional normal/critical range; 2,284 other applications missed or did not invoke damage |
| Enemy construction | 524 named records × physical/magical | Predictor builds for the complete named-enemy table in the controlled context; this is not an oracle execution against every possible boss phase |
| Normal-attack platform changes | 500 weapon records, 24 normal IDs, 3,494 contexts | Native `make_targets`/repeat counts agree after source → executor changes; this checks targeting/repetition, not every damage distribution with every equipment combination |
| Counter/reflection | Exact 100% counter case + 2,000 native invokes | Incoming hit remains; combined 50% counter and 50% reflection yields 75% incoming-hit availability |
| Combined weighted mean | 3,000 native applications | Crit, Guard bypass, resistance, evasion and skill cancellation agree within declared sampling tolerance |
| Recovery modes | 2,000 native applications | 25% void plus 25% inversion gives a weighted signed mean of −37.5 for 100-point recovery, not the range midpoint |
| Probabilistic debuff → damage | 2,000 native two-step sequences | Following damage includes the weighted debuff outcomes |
| Progression difficulty | All 20 settings | Actual scaled stats/critical damage match predictions |
| State-dependent skill selection | All 33 database rules + chained synthetic variants | Fresh choices resolve once; selected IDs survive target selection and a state-removing final weapon |
| Prior regression pairs | 400 executions each | Self-flagellation → Triple Shot and Jubjub → Two-Handed Sword remain covered |

The generated mechanism matrix also checks all eight parameter buffs, resistance changes between effects, restriction-based state removal, same-hit removal/reapplication, projection identity, friendly instant healing before HP scaling, shared F7/short estimates, scheduled skill transformation, explicit failure/partial/conditional labels, state and RNG immutability. These are specified cases, not an exhaustive enumeration of all combinations. Sampling tests have declared tolerances; an individual hit is not expected to equal a mean.

## Meaning of the UI

- **`≈ number` / `~number`:** expected direct damage before target HP caps, in the supported current model. It includes the tested hit/critical probabilities and preceding supported effects; it is not a guaranteed roll.
- **`direct damage; total ?`:** the direct component is shown; an additional event/effect is not included in the full result.
- **`conditional`:** HP-dependent battle-event pages may change the state during execution. Their presence qualifies later numbers; the mod does not read their thresholds or command bodies to predict hidden boss behavior. A certified whole-series total is withheld.
- **`?` plus reason:** a required transition is unverified or the finite branch budget (64) is exceeded. A previous value or a first hit is not reused as a whole result.

Remaining limitations include counter/reflection responses between hits, arbitrary battle/common-event scripts, some repeated drain/conversion and nonlinear survival/resource cases, uncertain death/retargeting/bodyguard transitions, recovery-mode propagation, and late instant-skill ID transformations. Unsupported contexts can be extended with separately verified adapters. Unknown mechanisms outside the tested build/contexts are not claimed to be solved. Existing target-knowledge restrictions remain; no hidden enemy AI/drop tables or player saves are distributed.


## 0.9992-dev continuation fixes

The sequence model already propagated TP and on-hit effects, but an older blanket stop still rejected a repeated action with both. That obsolete stop is removed; native fractional TP gain is retained and verified against a subsequent TP-based action. A default `-1`/missing living target follows the native smooth-target fallback instead of being treated as an impossible preceding action.

Endure does not make a distribution nonlinear when every possible hit is safely below remaining HP. The mean and repeated-hit continuation now check that boundary. A possible activation after uncertain prior damage still declines an unverified result. MP clipping likewise requires an actual threshold crossing to force a large nonlinear distribution into the unsupported path. Self-flagellation → Triple Shot is also exercised across four physical weapons and four difficulty settings, including a safe Endure case. These checks broaden confidence; they are not a proof of every player build.

A stopped continuation carries the preceding specific reason instead of losing it behind a generic “sequence not calculated” message. Diagnostic context is described in [troubleshooting](TROUBLESHOOTING.md).
