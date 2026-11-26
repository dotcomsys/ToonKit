# Library research audit - 8 November 2026

## Implemented evidence

The installed QuestieDB **Forever 1.0.12** is the primary source for the new quest mappings. Its baked `QuestieDB_Forever.toc` stores CBOR/base64 records. Decoded Quest fields 1 (name), 10 (required item) and 3 (finisher) establish the relationships below; `src/meta/questMeta.lua` defines those fields. `src/corrections/Forever/foreverQuestFixes.lua` independently supplies faction-specific destinations within the same addon (not an independent source). No addon code or artwork was copied.

| Item | Quest | Book | Hand-in |
| --- | --- | --- | --- |
| 210177 | 79096 | Ataeric: On Arcane Curiosities | Normal librarian |
| 215824 | 79953 | A Luddite's Guide to Caring for Your Demonic Pet | Normal librarian |
| 228132 | 84395 | Undead Potatoes | Jennea / Oran |
| 228133 | 84396 | Magma or Lava? | Jennea / Oran |
| 228134 | 84397 | Northern Kalimdor - A Comprehensive Guide | Jennea / Oran |
| 228135 | 84398 | A Study of the Light | Jennea / Oran |
| 228136 | 84399 | Ka-Boom! | Jennea / Oran |
| 228138 | 84400 | The Knight and the Lady | Jennea / Oran |
| 228140 | 84401 | Scourge: Undead Menace or Misunderstood? | Jennea / Oran |
| 228141 | 84402 | Necromancy 101 | Jennea / Oran |

NPC records 5497 and 7825 provide Jennea Cannon at Stormwind 49.56, 85.8 and Oran Snakewrithe at Undercity 73.06, 32.85. The eight quests list both NPCs as finishers; the faction corrections agree. The new Hand-in NPC button selects the appropriate destination. These are database-backed directions, not locally observed server turn-ins.

The existing persistence model safely accepts newly recognized completed flags and events without replacing saved character data. Each item counts once. Manual marks are not confirmed progress. All 40 entries remain; 39 have a tracked quest, with 36 Alliance route candidates. Ataeric remains off Route because its exact pickup is disputed. The Liminal and the Arcane remains untracked: quest 81951 has the expected item objective but no baked finisher, and public pickup reports remain conflicting.

## Other addons reviewed

- [Books on Map Forever 2.2.3, 7 November](https://www.curseforge.com/wow/addons/books-on-map-forever/files/9500018): author release notes restrict Sepulcher/Ataeric and Brill/Apothecary pickups to Horde. Applied Ataeric's restriction; Brill was already restricted. Its catalogue advertises 38 books. Author descriptions and release notes were reviewed; the ZIP download returned HTTP 403, so its implementation was not inspected.
- [Books Forever](https://www.curseforge.com/wow/addons/books-forever): compares per-character ownership and quest restoration, localization, resizing and TomTom support. Its 40-entry count is not evidence that every pickup is available.
- [Forever Library Books](https://www.curseforge.com/wow/addons/forever-library-books): compares zone alerts, collection counts and navigation. Its distinction between discovery and donation reinforces retaining this journal's separate ownership/donation states.

## Websites and conflicts

- [Method's photographed pickup guide](https://www.method.gg/wow-forever/wow-forever-all-library-books-locations-and-rewards): existing late-game directions still agree with the visible guide. Retained the precise existing pickups rather than making cosmetic coordinate changes. Blackrock books remain direction-only because a surface-zone pin does not establish the interior floor.
- [However's library guide](https://however.quest/en/guide/library-books): corroborates the Fallow Sanctuary pickup and explicitly notes alternate capital NPCs for the eight late books. Its broad all-factions claim conflicts with its own table and the newer author-reported pickup restrictions; not adopted wholesale.
- [Wowhead Forever: Undead Potatoes](https://www.wowhead.com/forever/quest=84395/undead-potatoes): page exists, but the accessible text is dominated by generic community comments and does not establish the current finisher. The local database, not those comments, determines the implemented NPC.
- [wow4ever's 5 November checklist](https://wow4ever.quest/en/library-books): still calls Ataeric unlocated and gives a conflicting Scourge position. This conflicts with newer addon release notes and Method's photographed directions. Exact Ataeric coordinates remain withheld; Scourge retains its existing location with no claim of local verification.
- [Warcraft Tavern](https://www.warcrafttavern.com/forever/guides/library-books/): explicitly warns that some positions derive from Season of Discovery. Not sufficient to resolve Forever-only disputes.

The baked quest catalogue now lists both regular librarians for Antonidas, Rumi, Ta'zo and the Apothecary's Primer without a race-mask field. This is evidence about quest data, not proof of cross-faction object lootability. Earlier conservative route restrictions for these entries remain pending direct pickup/turn-in evidence; Antonidas keeps its explicit Horde conflict warning. Ataeric's new restriction is an author-reported pickup restriction, not a claim about the quest race mask.

## Verification

Lua 5.1 syntax and mocked behavior checks cover bag/bank/history states, deduplication, manual marks, all eight restored late donations, new turn-in events, both factions' NPC selection, unresolved route exclusions and character isolation. Packaging checks every ZIP member against source. No live game UI, waypoint, pickup or turn-in was tested.

After `/reload`, open `/library`: check a previously donated late book, select its Hand-in NPC, verify a normal book still targets the librarian, and complete a real donation to check persistence. On Horde, check Ataeric's warning and route exclusion.

## Local evidence fingerprint

- Source: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\QuestieDB\QuestieDB_Forever.toc`
- SHA256: `d605067dcba3ea23f665756fd13d31a01a2bdb7a238dad705ca563da8171aa7f`
- Extracted audit: `tmp/library-research-20261108/questie-evidence.txt` in the workspace (not packaged).
