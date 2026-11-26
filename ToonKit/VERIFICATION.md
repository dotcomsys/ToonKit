# Local verification - 2026-10-17, 1.6.0-beta.1

- All 36 TOC-listed Lua files compile using Lua 5.1; all listed files exist and begin with the addon namespace. Interface remains 16001 and storage declarations remain stable.
- Loaded actual content tables locally: 123 routes, 2,899 steps, 8,729 goals; 33 source journal records, 296 encounter/rare entries, 1,315 drop relationships, 300 corroborated source relationships; 40 books, 37 located books, 38 map points, 30 explicit donation associations.
- All 55 declared next-segment links resolve. Eight starting-route segments (including shared Dwarf/Gnome and Orc/Troll starts) each connect to level 60. Recommendation selection matches all ten faction/race start combinations, including Alliance and Horde Skyborne.
- Route IDs and per-goal IDs are stable and unique; route coordinates and book coordinates are normalized. Unknown book positions have no marker. There are no duplicate encounter identities within catalog entries or duplicate journal keys.
- Stratholme's Live and Undead quest records join its populated loot entry; old farming-source wing aliases still resolve to it. Quest and boss reward sources remain distinct.
- Focused Lua state probes checked persistent book possession history after bag removal, manual completion/undo, and separation of manual goal evidence from automatic confirmation. These used small API stubs, not a game client or a committed test suite.
- Beta source gates keep single-source drops, admission levels above the cap and unlisted beta modules from becoming actionable. Explicit source class restrictions and item level requirements are checked after item data arrives. Native source unavailable flags excluded 13 nodes and 11 items.
- Source inputs have pinned revisions/URLs and SHA-256 hashes; all original guide text and import/build scripts are included in the source archive. Full GPL, MIT and CC BY notices are retained.

The 1.2.0 UI pass also used small local API stubs to exercise bag scanning and fallback item IDs, equipment/bag ownership, native button initialization, grouped/flat inventory and empty search, Journey manual confirmation/undo, talent budget edits/save, the redesigned page branches, a minimap click and selection-menu callbacks. These checks detect Lua control-flow errors; they do not simulate native templates, layout, protected interactions or actual client inventory. No test suite was added.

For 1.3.0, route selection was checked across ten faction/race filters, nine class filters and levels 1-30 in Beta plus 1-60 in Launch (8,100 combinations). These are filter combinations, not claims that every race/class character can be created. Focused probes covered stale starter migration, manual override, an active-quest join without false prior completion, next-zone transition, optional omission, class-detour return, cap blocking, item usability, listener error isolation, automatic waypoint without map opening, measured same-map direction/distance, preservation of a player-replaced waypoint, owned-point cleanup, position-only movement updates, cache invalidation and uncertain talent advice. The probes used actual Lua modules and small API stubs, without generating a test suite.

No in-game session, screenshot review, install, publish, commit or push was performed. Native templates, live quest/drop availability, safe travel, taint/combat behavior, drag/split/use interactions, saved-data persistence in the installed client and visual layout remain for the user's review. Parser/state/source checks do not establish those outcomes. No automated test suite was created.

The installable ZIP contains only the addon source, datasets, licenses and documentation. Development Python dependencies and research downloads are excluded. The separate source ZIP contains precisely the licensed inputs needed by the importer and the development scripts; no proprietary research source is included.


## 1.4.0 focused checks

All 31 Lua files compile with Lua 5.1, begin with the addon namespace line, and load in TOC order. Inline probes exercised all talent subpages, inventory organizer pages, item comparison pages, dungeon sections, settings sections, Journey and book views using native API stubs. No test suite was generated.

The route matrix was rerun for nine classes, ten original-race/Skyborne faction filters, levels 1-30 in Beta and 1-60 in Launch: 8,100 combinations. These are filter combinations, not character-creation claims.

Additional focused probes checked valid/invalid TK1 imports, complete legal generated point orders, generated-order provenance, beta spell ID matching of a localized node, explicit build-pinned matching of an unknown node, search AND/OR/exclusions/quotes/ranges, manual-assignment precedence, group deletion fallback, increased-stack new-item marking, Seen clearing and preservation of a prior snapshot during zero-capacity loading. The imported runtime tables contain the expected 86 talent identities and 13 effect rules. Native-tooltip fixtures checked weapon damage, speed, DPS, effect text, set names and socket gems. Equipped fixtures checked set-piece counts, unique-equipped conflicts and two-hand off-hand removal. Arrow fixtures checked north/east bearings and player-facing rotation.

These checks establish the exercised logic only. They do not establish native template interactions, live API behavior, minimap projection in every zone, combat safety, visual polish, complete route execution or equivalence to the reference addons. The user handles those reviews.


## 1.5.0 focused checks

All 34 modules compile in Lua 5.1 and load in TOC order. The 8,100 route-filter combinations were rerun. Every one of the 84 new ability identities joins the existing catalog; all 84 ability pages were exercised with API stubs. Counts remain 179 source spell links and 37 measured links on 19 encounters. Unknown native spell text stays unavailable rather than receiving invented descriptions.

Focused state probes checked native objective completion before whole-quest completion, live objective actions, native quest waypoint fallback, reacceptance cleanup and separation from historical turn-ins; native encounter result deduplication, failed-attempt counting, reported-loot capture without fabricated ownership; personal notes; copyable diagnostics; off-hand dual-wield/main-hand gates; and the two reference points remaining outside pickup locations. Existing talent, inventory, native item fact and page-branch probes passed after the changes.

Import source hashes, addon archive byte equality, ZIP CRC and SHA-256 sidecars are checked at packaging. These are focused local checks, not client gameplay, interaction, taint, visual or full reference-addon parity proof. No test suite was created.


## 1.6.0 focused checks

The 36 Lua modules compile and load in TOC order. The prior focused state/page checks, 8,100 filter combinations and 84 encounter ability joins/pages still pass. Additional inline probes record full surface corner anchors, edge-only backdrop configuration and texture UV changes after resizing. Guide collapse updates its surface to 44 units; expansion and secondary controls restore the corresponding height. These checks are geometry assertions, not rendered visual proof.

New state probes cover single-action source wording, explicit manual/automatic actions, pause blocking advancement/navigation, bounded undo restoring prior manual context, optional review/route selection, direct sidebar selection, a primary Journey page below the mocked viewport bound, and a bounded four-row farming view with 25 targets. Separate weight editing and the existing inventory/talent/item-comparison pages load through the common window skin. No test suite or screenshot review was created.


## 1.57.0 objective, hunt and bag pass

All 66 Lua files compile as Lua 5.1. TOC paths, namespace declarations and relevant dependency ordering pass focused static checks. Existing inventory classification/layout and imported route data are unchanged. The local installable and corresponding-source archives were rebuilt and checked. Grouped task progress, native objective completion, equipment interactions and inventory visual matching have not been verified in game. No test suite, installation or screenshot review was performed. Gear hunts still use the existing class/role/profile estimates and sourced catalog, not GearQuest curated spec ranks or its simulator.


## 1.58.0 reference-workflow pass

All 71 TOC modules compile as Lua 5.1 and initialize in TOC order with an inert event frame. Inline focused checks exercise search precedence, grouping, invalid expressions and recorded categories; category-column plans for 0/1/12/80/200/500 slot identities; and an actual sourced hunt's selection, ownership completion and return to the preceding manual guide. These are local logic/data checks, not native frame, visual or game-client proof. No test suite was generated. The outdoor importer reads literal pinned MIT data through an AST without executing upstream addon Lua. All pinned inputs and corresponding-source packaging are verified separately.

Client acceptance remains the user's: objective events and skips, source navigation, acquisition notices, saved inventories, native item interactions, taint/combat and visual layout. The code retains player-bag scope, source-listed availability boundaries and transparent scoring rather than proprietary curated rank/effect data.


## 1.59.0 focused checks - 2026-10-19

- All 72 TOC modules compile and initialize in Lua 5.1 with inert frame/timer stubs.
- A limited state probe using the real source actions checked accepted Wetlands ordering (276, 98282, 470, 294, 484), current-action presentation, deferral of the distant Menethil turn-in and release after fieldwork. No source step/goal IDs or saved completion records were rewritten.
- A limited event probe delivered 100 catalog item arrivals and an item-lock event: none queued a character refresh; notifications coalesced. An owned-item arrival did queue the required inventory refresh. This is control-flow evidence, not an FPS measurement.
- Sida's objective item 3349 and reward item 3352 were checked against the pinned MIT AllTheThings Wetlands source. Reward capacity is not independently asserted here.
- No game-client performance, protected interaction, combat, visual or gameplay review was performed. Those remain user-run checks. No automated test suite was created.


## 1.60.0 focused checks - 2026-10-19

- All 73 TOC-listed modules compile and initialize in Lua 5.1 with inert native frames and timers; all begin with the addon namespace.
- A limited fixture using the actual quest/objective matching, prerequisite gates and current-action functions exercised Tramping Paws, Alchemical Hazards, en-route skins, the Greenwarden return, Fire Taboo acceptance and its source nine-flint objective, Sida's oozes, Fire Taboo return, Blisters acceptance, opportunistic creeps, Ormer's first revenge quest, remaining skins, Claws, Spoils and the harbor turn-in batch.
- Moving the fixture outside the Fen Creeper area deferred that objective without completing it; returning to its source area restored it. The skin travel point was the existing Greenwarden contact and did not claim a crocolisk spawn there.
- The same fixture continued through Bloom 98208 acceptance, Nord'el, native return, Bloom 98209 acceptance, Darkshore objectives and return, the eligible paladin Kor Gem pickup and the BFD queue reminder. Existing 1653 completion was supplied as prerequisite evidence; accepting 1654 was not used to invent that completion.
- Automatic dungeon selection did not preempt the active sequence. Explicit manual mode bypassed it. All bundled source-route goal IDs remained unique; existing source steps and saved completion identities were retained.
- Bloom's Nord'el location and quest linkage come from the pinned MIT ATT Wetlands file; pickup comes from the pinned EverythingQuests data. Missing exact Bloom turn-in/Darkshore coordinates remain unknown and use native quest guidance. Level 25 is a planning target, not an asserted XP outcome or finder eligibility.
- No game session, installation, screenshot review, FPS measurement, protected queue action or automated test suite was performed. The user owns gameplay, performance and visual review.


## 1.60.1 focused checks - 2026-10-19

- All 73 TOC modules compile and initialize in Lua 5.1 with inert native frames/timers.
- A limited fixture using actual goal completion, prerequisite and current-action functions reproduced a manually selected source guide with old step 42 confirmed and Ormer ready. It selected the missing Tramping Paws pickup at the Greenwarden, then its native kill stage after acceptance. An accepted/ready Greenwarden courier handoff preceded that pickup.
- With earlier circuit work actually turned in and one native raptor objective unfinished, it returned to step 42 despite the old step confirmation. A contradictory complete flag did not allow the turn-in. Native completion of both objectives allowed step 43 afterward.
- Manual mode, selection of another manual guide, pause and the existing saved step confirmation remained intact. No installed SavedVariables were edited.
- No game-client, screenshot, combat, taint or performance review was performed. No automated test suite was created. These checks establish local control flow only.


## 1.61.0 focused audit - 2026-10-19

- All 74 TOC modules initialize in Lua 5.1 with inert frame/timer stubs. Data checks cover all 57 leveling source routes, resolving acyclic links from eight starts to 60, unique goal IDs, nine source classes and 27 talent trees. A representative class/faction/level filter audit passed 1,440 cases across the two planning caps.
- Read an actual installed paladin save without writing it. A limited fixture replayed its routing, completion, skip, cursor and return-stack state, using explicitly simulated native quests/objectives/position/race. The old save has no complete live objective snapshot; history was not treated as native completion proof.
- The replay covered the full requested Wetlands order, suspended automatic-trip recovery, 25-to-4 return-stack normalization with archival, eight-versus-nine Flint, missing/remaining skins, additional accepted quests, deferred Fen Creepers and later return, Bloom, existing Kor Gem acceptance and the BFD queue preference. Source/native state stayed authoritative over derived markers.
- Checks rejected manual completion of unfinished native actions and whole steps, recovered optional omissions and cursors, preserved explicit skips/pause/manual route selection, aligned review phases, and deferred dependent unaccepted pickups after explicit declines.
- The structural source audit corrected conditional carried supplies for three quests and one missing wanted-quest return. The remaining 96 linked-follow-up candidates include authored fast-path omissions, not verified missing live actions.
- Runtime native objective snapshots are diagnostic only. No installed save was edited, no suite was generated, and no game session, FPS measurement, visual review, host interaction or release action was performed. These checks do not prove a fastest or perfect 1-60 guide for every spec.
