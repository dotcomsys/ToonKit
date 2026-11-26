# ToonKit sources

## Journey and travel

`Data/OriginalRoutes.lua` and `Data/OriginalCircuits.lua` contain ToonKit's own circuits and planning rules. Quest IDs, contacts, prerequisites, rewards, and instance flags come from the pinned EverythingQuests Forever and AllTheThings Forever MIT datasets. `tools/Import-DungeonPreparation.py` reproduces the contact and classification table. Outdoor only filters known instance quests. Questing + dungeons uses ToonKit's prerequisite and pickup grouping with the Forever dungeon quest catalog.

The optional Polestar guide source adapts the Polestar authors' pinned Forever leveling, class and outdoor speedrun guides under GPL-3.0-only. ToonKit restored the adapters on November 25, 2026. It converts source steps and positions to ToonKit goals and uses native quest progress. The source archive includes the pinned guide inputs, the editable adapters and upstream notices. Polestar's guide-pack exception does not cover copies of its own guides. See `Licenses/Polestar*`.

Live quest state supplies objective counters and completion. Native client map art is used when available. Travel uses native destinations, known flight nodes, and player observations.

For floors without native map art, ToonKit uses Forever Dungeon Routes' MIT-licensed tile placement metadata by Checkov23, revision `7d81bce917e79b32d6343d8a396b6b8c2756bcb9`. Tile images load from the game client. The upstream `maps/` artwork is outside this distribution. The rebuild tool and MIT notice are included.

The transport map layer uses individual dock and tower location facts from the [Forever transport survey](https://www.wowhead.com/forever/guide/flight-points-zeppelins-and-ships). The pins do not supply pathing or departure times.

The catalog has starter and midlevel entry points and routes up to level 60. Level-band XP continuity, every class chain, and live quest offers require in-game verification.

The Theramore contact corrections use the source-listed phases for [Our Man in Theramore](https://www.wowhead.com/forever/quest=95194/our-man-in-theramore), [Watch Yer Back](https://www.wowhead.com/forever/quest=95196/watch-yer-back), and the [Alcaz Prison quest list](https://www.wowhead.com/forever/guide/alcaz-prison-dungeon-overview-location-rewards). These are contact locations. Interior progress comes from the active client quest log.

## Other datasets

- **Dungeons and loot** use Forever catalog facts from Spyglass, AllTheThings, WoW Forever Builds, ForeverDungeons and Aegis. See the respective MIT notices in `Licenses/`.
- **Books** use the adapted Sixty Forever CC BY 4.0 data and MIT data from Library Guide Forever, Librarian and AllTheThings. Sixty Forever also requests credit to Talents Forever. The bundled notices link to the originals and describe changes.
- **Talents and builds** use native client data and retain the Talents Forever CC BY 4.0 and WoW Forever Builds MIT notices for packaged reference inputs.
- **Equipment and reagents** use live item and recipe names. The current item-effect facts are numeric build 70959 projections from Wago Tools with observed rates credited to WoWSims Forever. The reagent index records recipe IDs, profession headings, ranks and item relationships. Raw DB2 exports and retired snapshots are development research.
- **Artwork** includes an original ToonKit journal icon. The source companion includes its editable branding assets. WoW artwork used by the interface is referenced from the installed client.

See [SOURCE-MANIFEST.json](SOURCE-MANIFEST.json) for exact inputs and hashes and [Licenses](Licenses/) for copyright and permission notices.
