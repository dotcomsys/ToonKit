local addonName, ns = ...
local D=ns.Journal
local groups={
 ["ragefire-chasm"]="RagefireChasm",["wailing-caverns"]="WailingCaverns",["the-deadmines"]="TheDeadmines",["deadmines"]="TheDeadmines",
 ["shadowfang-keep"]="ShadowfangKeep",["blackfathom-deeps"]="BlackfathomDeeps",["excavation-site"]="ExcavationSiteWetlands",
 ["hall-of-thanes"]="HallOfThanes",["the-stockade"]="TheStockade",["gnomeregan"]="Gnomeregan",["razorfen-kraul"]="RazorfenKraul",
 ["ruins-of-lordaeron"]="RuinsOfLordaeron",["dalaran"]="CityOfDalaran",["city-of-dalaran"]="CityOfDalaran",
 ["scarlet-monastery-graveyard"]="ScarletMonasteryGraveyard",["scarlet-monastery-library"]="ScarletMonasteryLibrary",
 ["scarlet-monastery-armory"]="ScarletMonasteryArmory",["scarlet-monastery-cathedral"]="ScarletMonasteryCathedral",
}
local function normalized(name) return (name or ""):gsub(" <.*$",""):lower():gsub("[^%w]","") end
function D.Mechanics(d,encounter)
    for _,record in ipairs((ns.Data.encounterAbilities or {})[d.journalKey or groups[d.slug]] or {}) do
        if record.npc and encounter.npc and record.npc==encounter.npc or (not record.npc or not encounter.npc) and normalized(record.name)==normalized(encounter.name) then return record end
    end
end
function D.Current()
    if type(GetInstanceInfo)~="function" then return end
    local _,kind,_,_,_,_,_,id=GetInstanceInfo()
    kind=ns.Safe(kind);id=ns.Safe(id)
    if type(id)~="number" or (kind~="party" and kind~="raid") then return end
    for _,d in ipairs(D.Entries()) do
        if d.instanceID==id then return d end
        for _,wing in ipairs(d.maps or {}) do if wing.instanceID==id then return d end end
        for _,encounter in ipairs(d.encounters or {}) do if encounter.instanceID==id then return d end end
        for _,record in ipairs((ns.Data.encounterAbilities or {})[d.journalKey or groups[d.slug]] or {}) do if record.instanceID==id then return d end end
    end
end
function D.Suggested()
    local current=D.Current();if current then return current end
    local best,score;local map=ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"))
    for _,d in ipairs(D.Entries()) do if D.SourceAllowed(d) then
        local candidate=-math.abs(ns.State.level-d.min)+(d.entrance and d.entrance.map==map and 100 or 0)
        if not best or candidate>score then best,score=d,candidate end
    end end
    return best
end
function D.KnownEncounter(id)
    for _,d in ipairs(D.Entries()) do for _,e in ipairs(d.encounters or {}) do
        local record=D.Mechanics(d,e)
        if record and record.encounterID==id then return d,e end
    end end
end
function D.History()
    local rows={};for id,record in pairs(ns.char.encounters or {}) do rows[#rows+1]={id=id,record=record} end
    table.sort(rows,function(a,b) if a.record.updated~=b.record.updated then return a.record.updated>b.record.updated end;return a.id<b.id end)
    return rows
end
local function now() return type(GetServerTime)=="function" and ns.Safe(GetServerTime(),0) or 0 end
local function record(id,name)
    id,name=ns.Safe(id),ns.Safe(name)
    if not ns.char or type(id)~="number" or id<1 then return end
    ns.char.encounters=ns.char.encounters or {}
    local r=ns.char.encounters[id]
    if not r then
        local rows=D.History()
        if #rows>=500 then ns.char.encounters[rows[#rows].id]=nil end
        r={name=type(name)=="string" and name or "Encounter #"..id,kills=0,wipes=0,loot={},updated=0};ns.char.encounters[id]=r
    end
    if type(name)=="string" and name~="" then r.name=name end
    r.updated=now();return r
end
function D.RecordEnd(id,name,difficulty,size,success)
    success=ns.Safe(success);if success~=0 and success~=1 then return end
    local r=record(id,name);if not r then return end
    local stamp=now();difficulty=ns.Safe(difficulty)
    -- A duplicated end event in the same second is not a second kill.
    if stamp>0 and r.lastEnd==stamp and r.lastDifficulty==difficulty then return end
    r.lastEnd=stamp;r.lastDifficulty=difficulty
    if success==1 then r.kills=r.kills+1 else r.wipes=r.wipes+1 end
    ns.After("encounterHistory",function() ns.Emit("STATE_CHANGED","encounters") end)
end
function D.RecordLoot(id,itemID,link,quantity)
    itemID,link,quantity=ns.Safe(itemID),ns.Safe(link),ns.Safe(quantity)
    if type(itemID)~="number" or itemID<1 or type(link)~="string" or type(quantity)~="number" or quantity<1 then return end
    local r=record(id);if not r then return end
    local key=link;local item=r.loot[key]
    if not item then
        local count=0;for _ in pairs(r.loot) do count=count+1 end
        if count>=80 then return end
        item={id=itemID,link=link,count=0};r.loot[key]=item
    end
    item.count=item.count+quantity;item.observed=now()
    -- This event may report group loot. It never proves that this player owns the item.
    ns.After("encounterHistory",function() ns.Emit("STATE_CHANGED","encounters") end)
end
function D.Note(d,e,text)
    ns.char.encounterNotes=ns.char.encounterNotes or {}
    local key=d.slug..":"..e.id
    if text~=nil then ns.char.encounterNotes[key]=text~="" and text:sub(1,1500) or nil end
    return ns.char.encounterNotes[key]
end
ns.On("ENCOUNTER_END",D.RecordEnd)
ns.On("ENCOUNTER_LOOT_RECEIVED",D.RecordLoot)
