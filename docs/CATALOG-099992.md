# Catalog integration — 0.99992-dev

The reviewed catalog-v1 input supplies 2,401 records: 999 skills, 390 items, 500 weapons, 260 armors and 252 states, including technical records with blank names. It contains 648 formula ASTs, 4,452 relations and 310 recipes. Its 29-file integrity manifest and nine original game inputs were verified locally; the independent source validator passes 40,229 checks. The original bundle is unchanged. Only the runtime reader and compact compiled catalogs are distributed, not the raw JSON, game tables or local logs.

## Reading

Native item, skill and equipment help expands to six physical lines. Full text is retained with wrapping and a reading position. Hold the remappable A modifier (default Shift) and Up/Down to scroll; the selected entry stays unchanged. The footer shows the actual assigned keys and visible range. HD side panels retain the full wrapped stream with the same reading control. Native palettes retain all ten digit entries in a six-row scrolling list, with a separate description below. Returning to group selection clears stale descriptions; closing the palette disposes the extra window.

F7 equipment and usable-item cards receive the complete mechanical description. State cards include the catalog sections and an applicable live duration. Existing book information, automatic-item reserves/limits and field upkeep status remain available. Independently multiplied physical-type and Physical-element traits receive a conditional combined explanation derived from the actual item features; this preserves the old x0.64 example without treating it as universal resistance. Catalog data is loaded before interactive menus and recursively immutable; UI preview caches are bounded.

## Formulas and forecasts

Readable formulas precede existing battle estimates. They preserve parentheses, integer division and current versus maximum resources. Negative recovery effects remain separate signed HP/MP terms with REC/PHA conditions. Weapon catalog metadata describes an intrinsic neutral attack; battle panels instead resolve the actual action variant from the existing forecast context and obtain hit attempts from that live sequence. Additional active sources can therefore change twelve attempts to fourteen without rewriting catalog metadata.

The catalog never executes a formula, grants an action, spends an item or overrides knowledge restrictions. Unknown transitions retain the existing forecast limitations. The numerical forecast, queue and percentage-effect correction modules are unchanged from 0.99991-dev; this update changes their presentation. A per-hit formula alone is not a confirmed sequence total. See [forecast limits](FORECAST-099991.md).

## Verification and limits

The imported native parity suite verifies every entry, formulas, effects, links, translations and immutability. Native UI tests cover descriptions without ellipses, last-line access, remapped reading keys, source variants, mixed and percentage formulas, live hit counts, knowledge restrictions, palette lifecycle and state/RNG preservation. Optional module combinations and previous numerical, support and menu regressions are rerun; final counts are recorded in [QA](QA.md).

Ordinary reference windows are inspected from the isolated game's own RGSS canvas. HD layout checks use the text accepted by the native renderer and its measured bounds; the saved HD layout images reproduce that accepted text on an owned bitmap and are not screenshots of the final compositor. They do not prove every display configuration. The historical F12 restart crash remains unresolved.
