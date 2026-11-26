local addonName, ns = ...
-- ATT Forever Elwynn/Stormwind/Westfall vendors and quest 116/117 costs.
-- Moonshine's Darkshire town is named by quest 116; no vendor pin is inferred.
ns.Data.townErrands={
    {key="dry-pickup",root=116,t="accept",quest=116},
    {key="shoes-pickup",root=118,t="accept",quest=118},
    {key="shoes-goldshire",root=118,t="turnin",quest=118},
    {key="verner-pickup",root=119,t="accept",quest=119},
    {key="verner-return",root=119,t="turnin",quest=119},
    {key="sweet-rum",root=116,t="buy",quest=116,item=1939,itemName="Skin of Sweet Rum",count=1,map=1429,x=.438,y=.658,npc=465,npcName="Barkeep Dobbins",town="Goldshire",note="Buy one Skin of Sweet Rum from Barkeep Dobbins in Goldshire while handling Smith Argus's horseshoe errand. Keep it for Dry Times."},
    {key="merlot",root=116,t="buy",quest=116,item=1941,itemName="Cask of Merlot",count=1,map=1453,x=.594,y=.772,npc=277,npcName="Roberto Pupellyverbos",town="Stormwind",note="Buy one Cask of Merlot from Roberto Pupellyverbos during the Stormwind courier visit. Keep it for Dry Times."},
    {key="hops",root=116,t="collect",item=1274,itemName="Hops",count=5,map=1436,town="Westfall",note="Keep five Hops from Harvest Golems, Harvest Watchers or Harvest Reapers while doing the Westfall farm objectives. Trade them to Grimbooze for one Keg of Thunderbrew; no extra keg is needed."},
    {key="thunderbrew",root=116,t="collect",item=1262,itemName="Keg of Thunderbrew",count=1,map=1436,x=.446,y=.802,npc=239,npcName="Grimbooze Thunderbrew",town="Westfall",note="Give Grimbooze Thunderbrew five Hops through Thunderbrew (quest 117) to obtain one Keg of Thunderbrew. This is a quest exchange, not a vendor purchase. Keep the keg for Dry Times."},
    {key="moonshine",root=116,t="buy",quest=116,item=1942,itemName="Bottle of Moonshine",count=1,map=1431,town="Darkshire",note="Obtain one Bottle of Moonshine in Darkshire when your route visits Duskwood. Quest 116 names this town; a verified vendor coordinate is not supplied. Keep it for Dry Times."},
    {key="dry-return",root=116,t="turnin",quest=116},
}

