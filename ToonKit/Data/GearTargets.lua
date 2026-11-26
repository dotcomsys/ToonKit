local addonName, ns = ...
-- User-selected level-30 Retribution farming goals, not universal BiS claims.
-- Item stats always come from the client. Required levels/source facts checked
-- 2026-10-20; research links are retained outside the runtime in QA/.
local targets={
    {id=277205,name="Cloak of the Divine Storm",slot=15,required=22,equip="INVTYPE_CLOAK",armor=1,sourceKind="quest",quest=78093,
        source="Return to Delgren: Cloak of the Divine Storm",requirements="Your selected level-30 Retribution BiS cloak. Complete Return to Delgren; keep this target ahead of Wolfmaster Cape.",
        provenance="https://www.wowhead.com/forever/quest=78093/return-to-delgren"},
    {id=250556,name="Officer's Belt",slot=6,required=30,equip="INVTYPE_WAIST",armor=3,sourceKind="crafted",recipe=251408,
        source="Blacksmithing: Officer's Belt",requirements="Blacksmithing (150); bind-on-pickup craft. Plans: Officer's Belt (251408). Craft it yourself; inspect native recipe requirements.",
        provenance="https://www.wowhead.com/forever/item=250556/officers-belt"},
    {id=250523,name="Veteran's Silvered Chain Leggings",slot=7,required=25,equip="INVTYPE_LEGS",armor=3,sourceKind="crafted",recipe=251375,map=1433,
        source="Blacksmithing: Veteran's Silvered Chain Leggings; plans from Stondry Darkhammer in Redridge",
        requirements="Blacksmithing (125); bind-on-pickup craft. Plans: Veteran's Silvered Chain Leggings (251375), sold by Stondry Darkhammer at Three Corners, Redridge. Check native vendor stock and costs.",
        provenance="https://www.wowhead.com/forever/spell=1252272/veterans-silvered-chain-leggings"},
    {id=274068,name="Thermaplugg Medal of Honor",slot=2,required=29,equip="INVTYPE_NECK",armor=0,sourceKind="dungeon",dungeon="gnomeregan",boss="Crowd Pummeler 9-60",
        source="Gnomeregan: Crowd Pummeler 9-60 - Thermaplugg Medal of Honor",requirements="Requires level 29 to equip. Source-listed drop; no guaranteed drop or drop-rate estimate.",
        provenance="https://www.wowhead.com/forever/item=274068/thermaplugg-medal-of-honor"},
}
ns.Data.personalGearTargets=targets
for _,t in ipairs(targets) do
    local r=ns.Copy(t);r.class="PALADIN";r.faction="Alliance";r.sourceKnown=true
    ns.Data.gear[#ns.Data.gear+1]=r
end
