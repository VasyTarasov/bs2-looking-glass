# Forecast repair in 0.99991-dev

The original game implements many percentage attacks as **negative HP recovery effects**, applied after formula damage. The previous sequence forecast changed projected resources for these effects but omitted them from its displayed damage accumulator. Element immunity could therefore produce a forecast of zero while a separate percentage effect still removed substantial HP.

The repaired sequence adds every supported recovery effect to its own HP or MP row in native effect order, using the current maximum resource, REC and, for items, the user's PHA. Formula element resistance, physical/magical damage rates and critical multipliers do not multiply this separate percentage component. Earlier supported state changes can change the maximum or REC used by a later effect.

For example, skill 491 against the original Lindamea template with dark immunity used to show zero. The native executor removes **163,350 HP** from its separate 3% effect; the repaired forecast includes that amount. Skill 896 also has a separate 5% HP effect. This correction covers the mechanism, including player and enemy database entries, rather than special-casing boss or skill names.

## Reading the result

- Negative recovery effects are described as HP/MP loss, including their independence from the main formula resistance.
- HP and MP changes remain separate. The compact HP estimate never adds MP damage to HP damage.
- In a single-target selection with several enemies, compact previews identify their targets by name. F7 → Targets contains the detailed ranges.
- A mean includes supported hit and critical probabilities. A range is a bound on the direct displayed damage, before target HP caps; it is not a guaranteed roll or a complete prediction of scripted battle events.
- If counters, uncertain survival or an earlier unsupported action prevent a full sequence calculation, an available fallback is labelled **current state, first hit**. It excludes preceding queued actions and subsequent repeats. It is not a full-action or queue total.
- Unknown target information remains hidden. Effects after possible death, boss scripts, additional actions and unmodelled resource transfers retain explicit limitations.

## Verification and historical limits

The audit accounts for all **18,488 historical forecast records**, deduplicated into 18,402 numerical contexts. The old records do not contain displayed predicted damage, exact transformed enemy identities or enemy parameters, final-N nominations, or complete initial variables. Consequently this is a reconstruction and comparison with the original game executor under the same reconstructed conditions, not an exact replay of every historical screen or fight. A complete queue is inspected for calculability; each damage comparison executes a sampled action from the reconstructed current state, not the entire historical combat sequence.

The native executor builds its own target selections, repeats, critical rolls, counter and reflection branches. Identical seeded trials are used before and after repair. Missing target snapshots, refused calculations and inconsistent original-template resources are reported separately, never counted as verified arithmetic. Passing seeded trials checks numerical bounds, not every possible roll or the exact mean of every historical action. Native quick-use counter initialization was restored in a 215-context supplement; historical spent counts were not recorded and are assumed fresh for these reconstructions. This removes adapter initialization failures without claiming those old counters were recovered.

The independent percentage suite enumerates all 89 database records containing negative HP/MP effects, isolates their 95 individual effects at several REC values, and tests unmodified techniques on the original Florence, Lindamea, Prince, Unis and Gran Guignol troop templates. Separate contracts cover mixed HP/MP rows, effect ordering, possible death, first-hit labels, knowledge restrictions and preservation of game state and RNG. See [verification](QA.md).

## Better evidence for future problems

Opt-in forecast diagnostics now record numeric result rows, known live enemy IDs and parameters, actor level/class/learned skills, action execution context and numeric formula variables. Target changes are part of the deduplication key, so a boss phase change is not suppressed just because the queue stayed the same. Current-state first-hit previews are labelled in the trace as well.

The forecast diagnostic payload excludes notes, event scripts, unknown enemies and string-variable contents. This describes the forecast payload; the existing optional general diagnostic recorder has its own broader gameplay events. Logs remain local and must be reviewed before sharing. This is still a development build; the earlier native F12 crash has not been established as fixed.
