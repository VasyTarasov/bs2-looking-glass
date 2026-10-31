# 0.9998-dev: automatic item correction

Fire resin (item 32) was missing from the authored whitelist. Its native frostbite removal was also rejected by the blanket cleanse filter. The old support matrix iterated that same whitelist, so it could not detect an omitted item. This was a coverage gap in the 0.9997 audit.

The correction permits the exact native frostbite-removal effect on fire resin. It does not discard or emulate the effect: normal game execution still applies the fire buff and removes frostbite. Only the fire buff is tracked for maintenance; fresh fire is not recast merely to cleanse frostbite. Extra cleansing effects on a modified resin remain rejected.

Tinker Bell pollen (item 102) was another missing routine buff. It now follows the existing protagonist-only policy: party-wide automatic use waits while another living party member would be affected. The native scope is unchanged.

There are 16 supported item records: 22, 32, 33, 34, 56, 57, 58, 59, 60, 61, 97, 100, 101, 102, 104, 105. Explicit configuration is still required. Recovery and cleansing, Rabbit Pocket Watch events, immortality, extra-action wine, damaging items and Necronomicon's tactical effects remain manual.

`auto_items09998` compares the accepted set against the entire item database using a separate expected catalog, checks boundaries of the thaw exception, and executes all four resins through the native instant-action path for both protagonist records. It covers real countdown/expiry boundaries, renewal, no waste, empty stock/refill, paid-slot preservation, standard item-window configuration, persisted definitions and pollen's companion gate. `polish_support` uses the independent catalog too and executes all 16 records for both protagonists and multiple hostile targets.

The update changes the own support module and version marker. It does not change the game database, native renderer, save files or saved automatic-item selections. New items can be enabled with the configured automation key (D by default).
