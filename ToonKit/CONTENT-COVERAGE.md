# Current snapshot — November 17, 2026

Current imported coverage: 4,766 quest metadata records; 132 Forever dungeon quest records with 235 explicit Classic fallbacks excluded; 38 loot catalogs, 342 encounters and 2,752 boss/item links (1,056 corroborated); 3,319 outdoor/vendor/rare gear source relationships; 2,149 leveling gear facts; 153 casual/class guides and 68 solo segments. Exact input revisions/hashes are in SOURCE-MANIFEST.json. Current catalogs are source records, not proof of witnessed drops or complete launch coverage. The older Aegis loot merge is disabled because the repository was unavailable. Previous hand-tuned numeric route reorders are limited to their original snapshot. Game behavior, performance and route timing remain unverified in-client. Older sections below are historical evidence.

# Content coverage - 2026-10-17

## Solo campaign, November 11, 2026

Speedrun adds a separately pinned and saved solo campaign: 65 segments, ten starting paths, 3,685 stable step slots, 9,168 retained goals and 74 sourced outdoor XP checkpoints. It excludes 618 dungeon, group, profession, invalid-racial and dependent actions from the newer snapshot. Ten on-the-way collection objectives are batched at their original hand-in deadlines. These are content counts, not verified optimal or live-completed actions. Casual identities and progress are retained.

Every starting path links to a level-60 endpoint without cross-faction or wrong-starter links. The structural audit evaluates nine class filters for each of ten starts, including combinations that are not necessarily playable. It reports zero unresolved mandatory pickup/prerequisite order candidates after source-specific corrections. Conditional/optional rejoin actions are reviewed separately. Native APIs and owner client review remain authoritative.

The newer upstream snapshot still discloses incomplete data for new 30-60 areas such as Riverglades, Shen'dralas and Mount Hyjal. The campaign follows sourced zones rather than inventing routes through those areas. No XP/hour target, universal fastest-route claim, road geometry or live launch verification is supplied. The dungeon journal remains available independently of solo leveling.

## 2026-10-21 merged coverage update

The original tables below describe the earlier Spyglass/ATT snapshot. The current merged journal contains 343 encounter/rare entries and 1,937 boss/item relationships; individual source counts must not be added together without deduplicating boss/item identities. The new Aegis factual input includes 30 dungeons, 276 boss identities and 1,988 loot relationships, with native floor IDs where present. Additional leveling drops come from the new licensed progression dataset. Beta still requires the original two-catalog corroboration for an actionable dungeon farm.

The gear progression dataset adds 27 class/spec profiles across nine classes, 77 optional level bands, 2,149 factual item records, 3,734 acquisition records and 1,088 source quest records. Authored priorities are the default; source bands and original role priorities are explicit options. Native item facts and usability remain authoritative for comparisons. Source percentages, school priorities, unpublished server effects and class rotations are not invented or silently converted.

No new leveling route or saved step/goal identity was inserted or reordered by this update. Source-author exclusions and unknown positions remain intact. No source loot is supplied for Demon Fall Canyon, Karazhan Crypts or The Searing Basin; announced-only instances retain their existing status.

These counts describe pinned licensed source data, not live-client validation. Sources and hashes are in SOURCE-MANIFEST.json.

## Leveling and class routes

57 outdoor leveling segments cover all eight original race starts plus both Skyborne factions and continue through level 60 for Alliance and Horde. Another 66 class routes cover the supported classes. Total: 123 segments, 2,899 grouped steps, 8,729 goals. All 55 declared next-segment links resolve. Beta hides segments whose starting level exceeds 30; Launch supports the complete source chain.

## Journal coverage

| Entry | Encounter/rare entries | Boss/item links | Source loot populated |
| --- | ---: | ---: | --- |
| Ragefire Chasm | 4 | 25 | Yes |
| The Hall of Thanes | 4 | 13 | Yes |
| Ruins of Lordaeron | 7 | 23 | Yes |
| Wailing Caverns | 9 | 34 | Yes |
| Deadmines | 12 | 72 | Yes |
| Shadowfang Keep | 11 | 56 | Yes |
| Blackfathom Deeps | 8 | 78 | Yes |
| Stormwind Stockade | 6 | 48 | Yes |
| Excavation Site: Wetlands | 4 | 14 | Yes |
| City of Dalaran | 10 | 29 | Yes |
| Gnomeregan | 7 | 39 | Yes |
| Razorfen Kraul | 9 | 50 | Yes |
| Scarlet Monastery: Graveyard | 5 | 23 | Yes |
| Scarlet Monastery: Library | 2 | 9 | Yes |
| Scarlet Monastery: Armory | 2 | 5 | Yes |
| Razorfen Downs | 6 | 19 | Yes |
| Scarlet Monastery: Cathedral | 3 | 11 | Yes |
| Uldaman | 12 | 30 | Yes |
| Zul'Farrak | 13 | 36 | Yes |
| Maraudon | 9 | 36 | Yes |
| Stratholme | 26 | 136 | Yes |
| Sunken Temple | 12 | 33 | Yes |
| Blackrock Depths | 30 | 125 | Yes |
| Dire Maul: East | 7 | 37 | Yes |
| Blackrock Spire: Lower | 17 | 81 | Yes |
| Dire Maul: North | 7 | 30 | Yes |
| Dire Maul: West | 7 | 40 | Yes |
| Scholomance | 18 | 89 | Yes |
| Blackrock Spire: Upper | 9 | 90 | Yes |
| Demon Fall Canyon | 7 | 0 | No |
| Karazhan Crypts | 11 | 0 | No |
| Onyxia's Lair | 1 | 4 | Yes |
| The Searing Basin | 1 | 0 | No |

There are 33 journal entries. The merged loot catalog itself has 33 records, 296 encounters/rares, and 1,315 boss/item links, including 300 corroborated relationships. Source removal flags excluded 13 nodes and 11 items. Empty tables are not actionable beta sources.

Unpopulated source records: Demon Fall Canyon; Karazhan Crypts; The Searing Basin.

## Library coverage

All 40 source library identities are bundled. 37 have sourced pickup map points; one alternate position gives 38 markers. 30 have explicit Forever donation associations. Ten do not borrow a speculative Season of Discovery donation ID.

| Book with unresolved waypoint | Source caveat |
| --- | --- |
| Stonewrought Design | Tomb altar beside Franclorn Forgewright; newer source also cites Center Vault, about 48.6, 64.2 on its interior map. No verified UiMapID; no pickup pin. |
| The Liminal and the Arcane | Newer Librarian catalog marks this unavailable in Forever: its SoD location required the Nightmare Incursions portal. No Forever pickup is established. |
| Magma or Lava? | Platform before the Blackrock Depths entrance, outside the instance; newer source cites 48.4, 63.6 on the Blackrock Mountain map. No verified UiMapID; no pickup pin. |

Stonewrought Design and Magma or Lava? describe interior approaches without a reliable map point. The sourced Burning Steppes point is offered only as an explicitly labeled mountain reference; it is not substituted for a pickup point or emitted as a book pin. Secrets of the Dreamers uses the sourced Barrens cave entrance, explicitly labeled, with interior directions in its notes.

Ataeric now uses the newer MIT Librarian player report: Silverpine Forest, 43.4, 41.2, downstairs beside Sebastian Meloche. The older disputed status is retained as a historical caution. See SOURCES.md for evidence and license details. Local research notes are outside the installable addon.

## Evidence and runtime boundaries

Routes, object directions and loot records inherit source confidence. No source audit here establishes current drops, safe travel, hotfix behavior or a globally complete launch catalog. Unresolved records stay visible with their caveats. Gameplay, native UI, taint/combat behavior and visual inspection are left to the user.


## Encounter abilities and personal history

Aegis revision ec156b0a051611dc627e568c4f0adbe42960d256 supplies MIT spell identities and role flags: 179 boss/spell links on 84 encounters across 16 dungeon groups. Its generated recorded-run dataset supplies 37 spell links on 19 encounters across four groups. Those measurements are labeled observations, never fixed damage or live timers. All 84 source identities join the existing catalog through explicit NPC IDs or conservative name matches when a source NPC ID is absent. Guide prose and artwork are excluded.

Readable native encounter-end and encounter-loot events build per-character history. Reported group loot, personal possession, source-listed relationships and corroborated relationships remain distinct. Personal history never fills an empty published loot table or upgrades its confidence.


## Numeric effect snapshots (1.70)

Build 70170: 621 item-effect records. Build 70450: 619. Each snapshot contains 43 items with modeled components and 155 set definitions, including unsupported entries with reasons. Across both snapshots, 470 supported item/set components validate. These are numeric client records, not an obtainability database or 27 completed spec simulations. Class/spec compatible counts appear in Equipment > BiS / effect simulation > Effect inputs / coverage. Combined gear ranking still includes advisory stat weights; full class rotations and unresolved scripted effects remain incomplete.


## Acquisition preparation and gold (1.71)

Crafting snapshots cover 2,278 created items in build 70170 and 2,277 in 70450, totaling 4,565 recipe variants. Numeric relationships are distinct from acquisition and native profession eligibility. Equipment displays sourced quest alternatives, parent/exclusion/skill/reputation gates and separate class-guide preparation. Gold tracks observed session/lifetime wallet flows and recorded alt balances. ToonKit mail integration has been removed completely; old inbox snapshots are excluded from all storage/hunting views. Full class rotations, pets/forms and scripted effect simulation remain incomplete.
