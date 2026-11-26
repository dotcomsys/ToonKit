# Development instructions

This is an original Lua 5.1 Forever addon. The user owns in-game gameplay testing and visual inspection. Do not generate test suites, perform screenshot review, install into a game client, or claim runtime proof from a parser. Complete related changes together. Keep work local unless the user authorizes release actions.

## Loading and architecture

`ToonKit.toc` is the module loader. Every Lua file starts `local addonName, ns = ...`. No require, filesystem, network, executables or runtime dependencies. Do not create addon globals except declared SavedVariables and slash registration entries.

- Brand.lua: sole visible identity configuration; stable storage identity is separate.
- Core/Runtime.lua: shared event dispatcher, debounced refreshes, signals, secret guards, combat queue.
- Core/API.lua: capability-checked modern API calls, item loads, maps, normal bag enumeration.
- Data/: licensed snapshots, advisory rules and extension registry, separate from logic/UI.
- Core/Store.lua: ADDON_LOADED persistence initialization and non-destructive legacy migration.
- Systems/Experience.lua: capability-checked native XP/rested values, session gains and localized kill-XP / quest-reward samples. No fixed reward assumptions or combat-log access.
- Systems/Gold.lua: event-driven wallet ledger, online session rates, tracked lifetime flows and recorded alt balances. Never invent pre-tracking earnings, count offline/loading time or label wallet transfers loot-only profit.
- Data/ReagentUses.lua and Systems/GearRequirements.lua: pinned Forever 70959 reagent uses and recipe rank rows, plus native read-only acquisition preparation. For a crafted item, only an explicit spell and a matching native output schematic establish material requirements. Historical create-item snapshots are development inputs. Preserve any/all, parent-in-log and exclusion semantics. Recipe items are not recipe spell IDs; optional/alternative reagents are not all mandatory. Unknown native counts stay unknown.
- Systems/Character.lua: shared identity, equipment, ownership, quests and event refreshes. Saved quest snapshots are diagnostics only and must never drive runtime acceptance or completion.
- Systems/Talents.lua: live allocation, uncertainty, manual role, legal independent plans and ordered guide decoding.
- Systems/Catalog.lua: all-source catalog visibility, fact-only announced names and batched native activity discovery, distinct from loot eligibility.
- Systems/Journal.lua: merged dungeon catalog, source corroboration, per-item/class/cap gating and shared loot candidates.
- Systems/Encounters.lua: sourced ability joins, bounded native-event history and separate personal notes. No combat-log reader.
- Systems/Journey.lua: live quests, prerequisite-ordered dungeon pickup/objective/turn-in phases, leveling return and confirmed progression.
- Systems/TripPlanning.lua: source-linked dungeon/class-part preparation, Black Tome conversion reminders and honest zone coverage gaps; never infer pickup locations or optimal travel.
- Systems/ActionEvidence.lua: current-action native trainer, binding, hearth-cast/arrival and taxi-arrival observations; no protected actions and no inferred boat completion.
- Systems/Services.lua: source-listed vendor/hearth instructions, native bind/cooldown/durability and bag-space reminders; never auto-sell, auto-repair or infer a service NPC.
- Systems/RouteProgress.lua: distinguish committed automatic trips from explicit manual selections, normalize duplicate return contexts with archival, and prevent return-stack growth.
- Systems/Travel.lua: character-scoped native flight nodes, native map connections and continuous nearby ground-crossing observations; bounded cross-zone connection routing. Label observations, disclose missing links, preserve explicit transports. Never infer road geometry, flight edges, boat schedules or walkable paths.
- Systems/Navigation.lua: current-action waypoint ownership, map direction/distance, position/facing-only ticker while the guide is expanded.
- Systems/WetlandsCircuit.lua: ordered Wetlands fieldwork, opportunistic Fen Creepers, harbor return batch and Bloom-to-BFD handoff. Preserve source IDs, explicit manual choices and incomplete native objectives. Keep field/Bloom/departure phases and route review consistent; proximity changes use coalesced stop events, never catalog movement scans.
- Data/WetlandsPreparation.lua: licensed Bloom quest linkage/objective and paladin BFD pickup; leave unsourced handoff coordinates unknown.
- Systems/JourneyView.lua: shared current-action presentation, pause and bounded manual undo.
- Systems/QuestRewards.lua and UI/QuestRewards.lua: read-only native reward-choice annotations. Compare total vendor price times confirmed reward quantity, preserve ties and unknown prices, separate item/currency indexes and quest-log/dialogue contexts. Never select or claim a reward, equip or sell automatically. Reuse badges and native hover scripts; no polling or native click replacement.
- Systems/QuestSupplies.lua: source-backed requirement/reward chains and conservative scoped keep advice; no automatic sales, item locking or invented quantities.
- Systems/Gear.lua: transparent stat estimates, source gating, slot comparisons and farming ownership.
- Systems/Simulation.lua: explicit encounter scenarios, sourced/personal effect models, constrained time-sliced loadout search and atomic target application. Never invent proc parameters, hide incomplete coverage or call scenario points measured character DPS.
- Data/EffectCoverage.lua, Systems/EffectTimeline.lua and Systems/EffectMath.lua: exact-build numeric client snapshots and bounded expected-effect calculations. Preserve input hashes and offline reproduction. Resolve shared-use contention chronologically; compound activations share one cast. Preserve same-time model ordering, refresh unions and unresolved proc correlation/periodic snapshot rules. Distinguish fixed-event and Poisson assumptions, non-gear inputs, flat native loadout scaling, periodic timing, unresolved scripts and actual class rotations. Incomplete candidate/baseline coverage must not silently become automatic BiS targets.
- Systems/StorageActions.lua: bank interaction/capability guards and explicit supported bank money transfers. No inbox, sending, collection or other mail integration.
- Systems/World.lua: readable confirmations, observed notes, completion provenance and map pins.
- UI/Widgets.lua: native assets/widgets, measured inline choices, bounded searchable rosters, reusable render pools and advanced journal child-page navigation. Keep utility pages inside the main journal; bags and tracker are the explicit play windows. Catalog selectors show full named choices with name search; never use letter-only indexes, numbered pages or scrolling menus. Preserve readable font sizes; never shrink content to hide overflow.
- UI/Experience.lua: independent top-centered text-only XP display; no window backdrop, guide parent, mouse capture or progress bar.
- UI/Main.lua: one contextual journal and compact guide.
- UI/Simple.lua: one current Journey action; retain visible one-click Skip task and put lengthy explanations on hover. UI/EquipmentSimple.lua supplies the working slot/item/source/compare workflow with explicit chunked searches, no passive scans or loadout simulations. Do not replace it with a character-sheet-only shortcut. UI/DungeonSimple.lua supplies the consistent dungeon/boss/loot selection surface.
- UI/Journey.lua: measured single-action guide, labeled footer controls, temporary interaction hiding and optional route review.
- UI/FeatureScreens.lua: simultaneous three-tree talent home/planner, source-based dungeon browser cards and shared framed panels.
- UI/DungeonWorkspace.lua: zone-first Books journal selection and sourced milestone rewards, retained dungeon references and source-identity native boss previews. UI/Books.lua is the optional native-map browser.
- UI/Workspaces.lua: shared scoped panes and retained detailed renderers. Default equipment uses EquipmentSimple.lua with native item tooltips and explicit chunked catalog searches; do not reactivate the old paper doll or synchronous all-slot ranking as the default. Native tiled location maps remain.
- UI/InventoryLayout.lua: complete natural-size inventory canvas planning, optimizing the footprint without shrinking item cells or using overflow pages; never lose or duplicate bag/slot identities.
- UI/Bank.lua: Blizzard bank entry point only. Do not create or automatically open a separate bank workspace; native bank owns tabs, item interaction, deposits and withdrawals. Recorded storage remains read-only evidence.
- UI/Inventory.lua: player bags only, native item cells, category/search/sort controls and one capacity-sized canvas without scrolling or page controls; drag category assignments preserve native item interaction. Native entry observation must exclude bank frames, respect explicit native sessions and defer handoff during combat.
- UI/Workflow.lua: adjacent Journey action/preparation panes; keep common tasks on their working surfaces and preserve context.
- UI/Diagnostics.lua: copyable local report; no automatic transmission.
- Core/Bootstrap.lua: lifecycle, commands and optional native Settings registration.

`STATE_CHANGED` links systems to visible UI. `SETTINGS_CHANGED` updates configuration-dependent behavior. Avoid OnUpdate scans; debounce event bursts. UI pools must be reused because WoW frames are not garbage collected. Do not overwrite live talent allocation when editing a plan.

Automatic leveling respects character filters, active level/cap and linked zone continuity. Explicit manual routes remain manual until resumed. Joining from an active quest uses a separate route-entry cursor; never label earlier steps as completed. Optional actions omitted because their source condition is absent remain distinct from confirmations. Class/dungeon detours preserve a leveling return route. Navigation never scans route/item catalogs on its movement ticker and clears only a still-matching waypoint it owns. Gear actionability requires an affirmative native item-usability result; missing capability remains a reference, not permission to recommend unusable equipment.

## API and protection rules

Target interface 16001 and C_Spell/C_Item/C_QuestLog/C_Container/C_Traits/C_ClassTalents/C_Map. The exported API reference is build 70170; presence alone is not runtime evidence. Do not infer Classic behavior from the world's setting or WOW_PROJECT_ID. Do not use GetTalentInfo/GetNumTalentTabs or other missing legacy globals. Missing item and spell data is asynchronous.

Guard secret values before comparing, sorting, printing or branching. Do not read the combat log or infer secret combat state. Protected calls are not made safe by pcall. Do not use secure snippets or protected supertracking. Map points use UiMapPoint and C_Map.SetUserWaypoint only.

Do not restyle unrelated Blizzard interfaces. Player-bag windows and bag-global hooks exclude bank/account/guild IDs. Separate bank controls retain verified native bank-type context and revalidate access and combat. The user removed all ToonKit mail integration in 1.71; do not reintroduce it. Inventory uses native item templates and defers layout and attribute changes during combat. Preserve normal modified-click/drag behavior. Observe only the explicitly enumerated normal-bag functions with secure post-hooks; never replace bag globals or call native item OnClick from addon Lua. Preserve native combat fallback and non-player-bag dispatch. Category assignment uses a separate overlay only in explicit edit mode. Verify source before changing native interaction paths.

## Data integrity and licenses

Never fabricate quests, chains, boss drops, availability, coordinates, talent ranks, mechanics, drop rates or effect values. Keep Classic fallback markers and source notes. Cached item existence is not proof of obtainability. One live Forever ruleset is supported; historical content modes are retired. Source freshness is not availability proof. User-observed readable locations are player coordinates, not surveyed object positions.

Talent snapshot: talentsforever.com, CC BY 4.0. Source build references and dungeon quests: WoW Forever Builds, MIT. Keep notices and attribution. NaowhForever/GearQuest/RestedXP source is not licensed for reuse here. Do not bundle it. Unlicensed research downloads and API tooling remain outside the installable folder and ZIP.

Journey itineraries and grouping rules are authored in ToonKit. Use independently sourced Forever quest facts for pickup, objectives and return locations. Preserve stable IDs. Keep the combined distribution GPL-3.0-only and preserve the bundled dataset notices and source companion. The optional Polestar route source and Forever Dungeon Routes map metadata are licensed exceptions. Keep their pinned inputs and notices. Do not bundle third-party map artwork or retired gear profiles.

Routes have grouped goals and character conditions. Goal IDs and segment IDs are persistent. Preserve class/race/faction restrictions, optional flags, prerequisites, cave-entrance labels and unknown-location status. Manual acknowledgments must stay distinguishable from automatic evidence. Live quest objectives take precedence over carried items, manual quest flags and old caches; missing quantities must never default to one for a quest objective. Archive derived progress before revalidating route revisions. Do not auto-confirm training, vendor, hearth, flight or note steps without evidence. Route pages are bounded and pooled; never render the entire 1-60 campaign at once.

Current runtime dungeon/library facts come from Data/LiveForever.lua and Data/ForeverPolicy.lua, reproduced by tools/Import-LiveForever.py. Only the source-backed live family roster is registered. Current native item usability remains mandatory for equip-ready advice. Historical snapshots are retained outside the installable runtime; do not reactivate mode gates or unsupported old-build scoring.

Extensions call `ns.Registry.Add("routes"|"collections"|"gear", record)` after Registry.lua. Require stable ID and source; confirmed availability requires verifiedBuild. Map coordinates are normalized. Routes use `steps` containing text, quest and optional pickup records with a zone and percentage coordinates. Collections use id/name/map/x/y and optional completion quest. Gear records use the actual item ID as id, source, required level, class/faction conditions, availability and verifiedBuild. Do not ship sample fictional records. Curated gear-effect rules live in ns.Data.effects and need real source evidence; absent effects remain disclosed limitations.

Rebranding changes Brand.lua; keep neutral services and SavedVariables stable. Synchronize static TOC metadata with tools/Sync-Brand.ps1. Installation identity migrations also require moving the WoW-named SavedVariables file, as documented in README.

The owner currently requests no tests, previews or automated parsing checks. Do not run them unless that instruction changes. Source review does not establish client, taint, combat, bag-interaction or visual behavior. Document data boundaries honestly; do not call this full Baganator or RestedXP parity.
