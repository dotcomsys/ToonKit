local addonName, ns = ...
local P={};ns.TripPlanning=P
-- Aegis Forever's authored Lyn note documents the object chain. Native item
-- identities: wowhead.com/forever/item=276561 and item=275989. No guessed pins.
function P.CollectionGoals(slug)
    local d=ns.Journal.Get(slug);if not d then return {} end
    local sfk=ns.Journal.Get("shadowfang-keep");local dalaran=ns.Journal.Get("dalaran")
    local black=(ns.State.owned[276561] or 0)>0;local tome=(ns.State.owned[275989] or 0)>0
    if sfk and d.slug==sfk.slug and not tome then
        return {{item=276561,name="Black Tome / Tome of Dalaran",ready=true,have=black,
            text=black and "Already carrying Black Tome; convert it at Ambermill" or "Before leaving SFK: collect Black Tome after Arugal",
            note="Check the table in Archmage Arugal's room after his defeat. Use Black Tome beside Ambermill's Leyline Focus to make Tome of Dalaran."}}
    elseif dalaran and d.slug==dalaran.slug and not tome then
        return {{item=275989,name="Tome of Dalaran",ready=black,have=false,
            text=black and "Convert your Black Tome at Ambermill before Dalaran" or "Optional boss preparation: obtain Black Tome in SFK first",
            note="The transformed tome is used at the small sewer summoning circle for Lyn the Ignored. No source-supported waypoint is supplied here."}}
    end
    return {}
end
function P.KeepLines(id)
    if id==4371 and ns.Journey.OnQuest(174) and not ns.Journey.QuestDone(174) then return {"Keep one Bronze Tube for Viktori's Look To The Stars handoff before the shared Blind Mary / Ghost Hair Thread visit."} end
    if id==2251 and ns.State.faction=="Alliance" and not ns.Journey.QuestDone(93) then
        local map=ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"))
        if map==1431 or ns.Journey.OnQuest(5) or ns.Journey.OnQuest(93) then return {"Keep 6 Gooey Spider Legs for Chef Grual's Dusky Crab Cakes. Future preparation is not quest completion."} end
    end
    if ns.Journey.OnQuest(116) then
        if id==1274 and (ns.State.owned[1262] or 0)==0 then return {"Keep five Hops: exchange them with Grimbooze Thunderbrew in Westfall for the Keg of Thunderbrew needed by Dry Times."} end
        if id==1262 or id==1939 or id==1941 or id==1942 then return {"Keep one for Dry Times. Deliver the four different drinks to Barkeep Daniels in Lakeshire."} end
    end
    if id==276561 then return {"Keep: Black Tome becomes Tome of Dalaran at Ambermill's Leyline Focus. Optional Dalaran boss preparation."} end
    if id==275989 then return {"Keep: Tome of Dalaran is used for Lyn the Ignored in the City of Dalaran sewers."} end
    return {}
end
function P.Dungeon(slug)
    local d=ns.Journal.Get(slug);local rows={};if not d then return rows end

    for _,row in ipairs(P.CollectionGoals(slug)) do rows[#rows+1]=row end
    for _,q in ipairs(d.questSource or {}) do
        if ns.Journal.QuestAccess(q) and not ns.Journey.QuestDone(q.id) then
            local active=ns.Journey.OnQuest(q.id)
            local blocked=ns.Journey.Blocked({t="accept",quest=q.id,pre=q.needsId and {q.needsId} or nil,minLevel=q.req})
            rows[#rows+1]={quest=q.id,name=q.title,ready=active,blocked=blocked,
                text=(active and "In quest log: " or blocked and "Unlock first: " or "Pick up before departure: ")..q.title,
                note=blocked or q.startAt and (q.startAt.place or q.startAt.zone) or "Pickup location not supplied",classic=d.questSource.classic}
        end
    end
    return rows
end
-- Blizzard's Forever raid overview, October 20, 2026, news/24303009.
-- Quest IDs and the two listed minimum levels are from bundled Forever metadata.
local onyxia={
    Alliance={
        {"Dragonkin Menace",4182,"At level 48, speak with Helendis Riverhorn at Morgan's Vigil in Burning Steppes."},
        {"The True Masters",{4183,4184,4185,4186,4223,4224},"Follow the six handoffs and return to Marshal Maxwell at Morgan's Vigil."},
        {"Marshal Windsor",4241,"Find Windsor in Blackrock Depths. Bring his Abandoned Hope report back to Maxwell."},
        {"The Crumpled Note and Jail Break",nil,"In Blackrock Depths, loot the note from enemies and bring it to Windsor. Recover his papers from Argelmach and Angerforge, escort Windsor out, and report to Maxwell."},
        {"Stormwind Rendezvous",6402,"Speak with Squire Rowe at the Stormwind gates. Bring allies for The Great Masquerade and speak with Bolvar afterward."},
        {"The Dragon's Eye",6501,"Take Bolvar's fragment to Haleh at Mazthoril in Winterspring."},
        {"Drakefire Amulet",6502,"Accept Haleh's quest before going to Upper Blackrock Spire. Loot the blood from General Drakkisath and return to Haleh for the amulet."},
    },
    Horde={
        {"Blood and Thunder",nil,"Start with Warlord Goretooth in Kargath, Badlands. This leads to Warlord's Command."},
        {"Warlord's Command",4903,"The bundled data lists level 55 for Warlord's Command. Complete its objectives in Lower Blackrock Spire."},
        {"Eitrigg's Wisdom",4941,"Report to Eitrigg in Orgrimmar and speak with Thrall."},
        {"For the Horde!",4974,"Bring Rend Blackhand's head to Thrall."},
        {"Thrall and Rexxar",{6566,6567,6568},"Hear Thrall's account, find Rexxar in Desolace and bring his testament to Myranda in Western Plaguelands."},
        {"Oculus Illusions and Emberstrife",{6569,6570},"Collect Black Dragonspawn Eyes for Myranda. Use her disguise to approach Emberstrife in Dustwallow Marsh."},
        {"The Test of Skulls",{6582,6583,6584,6585},"Hunt Scryer, Somnus, Chronalis and Axtroz as directed by Emberstrife."},
        {"Ascension",6601,"Take the unfinished amulet to Rexxar."},
        {"Blood of the Black Dragon Champion",6602,"Get the blood from General Drakkisath in Upper Blackrock Spire and return to Rexxar for the amulet."},
    },
}
function P.Onyxia()
    local rows,active={},nil
    for _,stage in ipairs(onyxia[ns.State.faction] or {}) do
        local ids=type(stage[2])=="number" and {stage[2]} or stage[2]
        local done=ids~=nil
        local quest
        for _,id in ipairs(ids or {}) do
            if not ns.Journey.QuestDone(id) then done=false end
            if ns.Journey.OnQuest(id) then quest=id end
        end
        rows[#rows+1]={name=stage[1],note=stage[3],done=done,quest=quest,reference=ids==nil}
        if quest then active=#rows end
    end
    local carried=false
    for _,item in ipairs(ns.State.bags or {}) do if item.id==16309 then carried=true;break end end
    return rows,active,carried
end
function P.RelevantDungeons()
    local rows={}
    for _,d in ipairs(ns.Journal.Entries()) do
        if d.min<=ns.State.level+5 and d.max>=ns.State.level-2 and (d.required or d.min)<=ns.Rules.Cap() then
            local quests=P.Dungeon(d.slug)
            if #quests>0 then
                local active=0
                for _,quest in ipairs(quests) do if quest.ready then active=active+1 end end
                rows[#rows+1]={dungeon=d,quests=quests,active=active,
                    distance=math.abs(ns.State.level-(d.min+d.max)/2)}
            end
        end
    end
    table.sort(rows,function(a,b)
        if a.active~=b.active then return a.active>b.active end
        if a.distance~=b.distance then return a.distance<b.distance end
        return a.dungeon.name<b.dungeon.name
    end)
    return rows
end
function P.Reminder(route)
    local slug=P.instanceSlug or route.planSlug or (route.category=="Dungeon" and route.id:gsub("^dungeon:","") or nil)
    if not slug then return end
    local text={};for _,row in ipairs(P.CollectionGoals(slug)) do if not row.have or row.item==276561 then text[#text+1]=row.text..". "..row.note end end
    return #text>0 and table.concat(text,"\n") or nil
end
function P.ZoneGaps(route)
    local map=ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"));local rows={}
    local cached=P.zoneGaps
    if cached and cached.route==route and cached.map==map and cached.level==ns.State.level and cached.epoch==ns.stateEpoch then return cached.rows end
    local covered=ns.Journey.QuestIndex(route)
    for id,m in pairs(ns.Data.questSupport.meta) do
        local localQuest=false;for _,area in ipairs(m.maps or {}) do if area==map then localQuest=true;break end end
        local q=ns.Data.questSupport.quests[id]
        if localQuest and not covered[id] and not (q and q.repeatable) and not ns.Journey.QuestDone(id) and not ns.Journey.OnQuest(id)
            and (m.level or 0)>=ns.State.level-4 and (m.level or 0)<=ns.State.level+3 and ns.QuestSupplies.Eligible(id) then
            rows[#rows+1]={id=id,name=m.name,level=m.level}
        end
    end
    table.sort(rows,function(a,b) if a.level~=b.level then return a.level<b.level end;return a.id<b.id end)
    P.zoneGaps={route=route,map=map,level=ns.State.level,epoch=ns.stateEpoch,rows=rows}
    return rows
end

-- Entering an instance must surface class preparation even on a leveling route.
function P.RefreshInstance()
    if not ns.char or not ns.Journal.Current then return end
    local dungeon=ns.Journal.Current();local slug=dungeon and dungeon.slug
    local changed=P.instanceSlug~=slug
    if ns.char.preferredDungeonTrip and ns.char.preferredDungeonTrip==slug then ns.char.preferredDungeonEntered=true
    elseif changed and ns.char.preferredDungeonEntered then ns.char.preferredDungeonTrip=nil;ns.char.preferredDungeonEntered=nil end
    P.instanceSlug=slug
    if changed and dungeon then
        local text={}

        for _,row in ipairs(P.CollectionGoals(slug)) do if not row.have then text[#text+1]=row.text..". "..row.note end end
        if #text>0 then ns.Message("Dungeon preparation: "..table.concat(text," ")) end
    end
    if changed then ns.Emit("STATE_CHANGED") end
end
for _,event in ipairs({"PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA"}) do
    ns.On(event,function() ns.After("classDungeonPreparation",P.RefreshInstance) end)
end
