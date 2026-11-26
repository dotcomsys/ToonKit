local addonName, ns = ...
ns.Rules = {}
function ns.Rules.Cap() return 60 end
function ns.Rules.CampaignCap() return 60 end
function ns.Rules.MaskAllows(mask,id)
    return not mask or mask==0 or type(id)=="number" and id>0 and math.floor(mask/2^(id-1))%2==1
end
function ns.Rules.QuestFaction(mask)
    return mask==77 and "alliance" or mask==178 and "horde" or nil
end
function ns.Rules.QuestRaceAllowed(mask)
    local state=ns.State
    local faction=ns.Rules.QuestFaction(mask)
    -- The pinned quest metadata uses the original faction-wide race masks.
    -- Authored Skyborne routes list quests under these same masks.
    if faction and (state.raceToken or ""):lower()=="skyborne" then return (state.faction or ""):lower()==faction end
    return ns.Rules.MaskAllows(mask,state.raceID)
end
function ns.Rules.Available(record, actionable, contentCap)
    if not record then return false,"Missing data" end
    if record.class and ns.State and record.class~=ns.State.class then return false,"Other class" end
    if record.only and ns.State and record.only:upper()~=ns.State.class then return false,"Other class" end
    if type(record.classes)=="table" and #record.classes>0 then
        local allowed=false
        for _,class in ipairs(record.classes) do if class==ns.State.classID or type(class)=="string" and class:upper()==ns.State.class then allowed=true end end
        if not allowed then return false,"Other class" end
    end
    local side=record.faction or record.side
    if side and side~="both" and ns.State and string.lower(ns.State.faction or "")~=string.lower(side) then return false,"Other faction" end
    if record.classic then return false,"Classic fallback, unverified in Forever" end
    if (record.min or record.required or record.req or 1)>(contentCap or ns.Rules.Cap()) then return false,"Above active content cap" end
    if actionable and record.availability~="confirmed" and not record.live then return false,"Availability unverified" end
    if actionable and ns.State and (record.required or record.req or record.min or 1)>ns.State.level then return false,"Requires a higher level" end
    return true
end
function ns.Rules.RouteAvailable(record)
    return ns.Rules.Available(record,false,record and record.category=="Leveling" and ns.Rules.CampaignCap() or ns.Rules.Cap())
end
-- Advisory defaults, not simulated BiS scores. Users can override each stat weight.
ns.Data.priorities = {
    melee={ ITEM_MOD_STRENGTH_SHORT=2,ITEM_MOD_AGILITY_SHORT=1.6,ITEM_MOD_ATTACK_POWER_SHORT=1,ITEM_MOD_CRIT_RATING_SHORT=1.5,ITEM_MOD_HIT_RATING_SHORT=1.8,ITEM_MOD_STAMINA_SHORT=.35 },
    ranged={ ITEM_MOD_AGILITY_SHORT=2.4,ITEM_MOD_ATTACK_POWER_SHORT=1,ITEM_MOD_CRIT_RATING_SHORT=1.8,ITEM_MOD_HIT_RATING_SHORT=2,ITEM_MOD_STAMINA_SHORT=.3 },
    caster={ ITEM_MOD_INTELLECT_SHORT=1.6,ITEM_MOD_SPELL_POWER_SHORT=2,ITEM_MOD_SPIRIT_SHORT=.5,ITEM_MOD_CRIT_RATING_SHORT=1,ITEM_MOD_HIT_RATING_SHORT=1.7,ITEM_MOD_STAMINA_SHORT=.3 },
    healer={ ITEM_MOD_INTELLECT_SHORT=1.8,ITEM_MOD_SPIRIT_SHORT=1.6,ITEM_MOD_SPELL_POWER_SHORT=1.7,ITEM_MOD_MANA_REGENERATION_SHORT=3,ITEM_MOD_STAMINA_SHORT=.3 },
    tank={ ITEM_MOD_STAMINA_SHORT=2,ITEM_MOD_STRENGTH_SHORT=.8,ITEM_MOD_AGILITY_SHORT=1,RESISTANCE0_NAME=.08,ITEM_MOD_DEFENSE_SKILL_RATING_SHORT=2,ITEM_MOD_DODGE_RATING_SHORT=1.5,ITEM_MOD_PARRY_RATING_SHORT=1.5 },
}
ns.Data.treeRoles = {
    WARRIOR={"melee","melee","tank"}, PALADIN={"healer","tank","melee"}, HUNTER={"ranged","ranged","ranged"},
    ROGUE={"melee","melee","melee"}, PRIEST={"healer","healer","caster"}, SHAMAN={"caster","melee","healer"},
    MAGE={"caster","caster","caster"}, WARLOCK={"caster","caster","caster"}, DRUID={"caster","melee","healer"},
}
ns.Data.slots = { {1,"Head"},{2,"Neck"},{3,"Shoulder"},{5,"Chest"},{6,"Waist"},{7,"Legs"},{8,"Feet"},{9,"Wrist"},{10,"Hands"},{11,"Finger"},{12,"Finger"},{13,"Trinket"},{14,"Trinket"},{15,"Back"},{16,"Main hand"},{17,"Off hand"},{18,"Ranged"} }
ns.Data.equipSlots = { INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_CHEST={5},INVTYPE_ROBE={5},INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},INVTYPE_WEAPON={16,17},INVTYPE_2HWEAPON={16},INVTYPE_WEAPONMAINHAND={16},INVTYPE_WEAPONOFFHAND={17},INVTYPE_SHIELD={17},INVTYPE_HOLDABLE={17},INVTYPE_RANGED={18},INVTYPE_RANGEDRIGHT={18},INVTYPE_THROWN={18} }

-- Original source fact: Wowhead Forever quest 78093 / item 277205, checked
-- 2026-10-19. Stats and usability are always read from the native client.
ns.Data.gear[#ns.Data.gear+1]={id=277205,quest=78093,class="PALADIN",faction="Alliance",required=22,
    source="Return to Delgren: Cloak of the Divine Storm",sourceKind="quest",sourceKnown=true,
    provenance="https://www.wowhead.com/forever/quest=78093/return-to-delgren"}
