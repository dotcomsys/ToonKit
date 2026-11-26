local addonName, ns = ...
local D={}; ns.Journal=D
local aliases={
    ["lower-blackrock-spire"]="blackrock-spire",["upper-blackrock-spire"]="blackrock-spire",
    ["scarlet-monastery-graveyard"]="scarlet-monastery",["scarlet-monastery-library"]="scarlet-monastery",
    ["scarlet-monastery-armory"]="scarlet-monastery",["scarlet-monastery-cathedral"]="scarlet-monastery",
    ["dire-maul-east"]="dire-maul",["dire-maul-north"]="dire-maul",["dire-maul-west"]="dire-maul",
    ["the-hall-of-thanes"]="hall-of-thanes", ["stormwind-stockade"]="the-stockade",
    ["city-of-dalaran"]="dalaran", ["excavation-site-wetlands"]="excavation-site",
    ["blackrock-spire-lower"]="lower-blackrock-spire", ["blackrock-spire-upper"]="upper-blackrock-spire",
    ["sunken-temple"]="the-temple-of-atal-hakkar", ["zulfarrak"]="zul-farrak",
}
local function normalized(name) return (name or ""):lower():gsub("^the ",""):gsub("[^%w]","") end
local questClasses={"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST",false,"SHAMAN","MAGE","WARLOCK",false,"DRUID"}
function D.QuestRestrictions(quest)
    local meta=ns.Data.questSupport and ns.Data.questSupport.meta[quest.id]
    local faction=quest.faction or quest.side
    if type(faction)=="string" then faction=faction:lower() end
    if faction~="alliance" and faction~="horde" then faction=meta and ns.Rules.QuestFaction(meta.races) end
    local classes={}
    if type(quest.class)=="string" then classes[1]=quest.class:upper()
    elseif type(quest.classes)=="table" and #quest.classes>0 then
        for _,class in ipairs(quest.classes) do
            local token=type(class)=="number" and questClasses[class] or type(class)=="string" and class:upper()
            if token then classes[#classes+1]=token end
        end
    elseif meta and (meta.classes or 0)>0 then
        for id,token in ipairs(questClasses) do if token and ns.Rules.MaskAllows(meta.classes,id) then classes[#classes+1]=token end end
    end
    return faction,classes,meta
end
function D.QuestAccess(quest)
    local allowed,reason=ns.Rules.QuestCharacterAllows(quest.id)
    if not allowed then return false,reason end
    return ns.Rules.Available(quest,false)
end
function D.Entries()
    if D.entries then return D.entries end
    local questDungeons=ns.Data.dungeons or {}
    local entries,used={},{}
    for _,catalog in ipairs(ns.Data.journals or {}) do
        local d=ns.Copy(catalog); d.slug=aliases[d.key] or d.key
        local questSource
        if d.key=="stratholme" then
            local merged={slug="stratholme",name=d.name,min=d.min,max=d.max,classic=true,alliance={},horde={}}
            local seen={}
            for _,q in ipairs(questDungeons) do if q.slug=="stratholme-live" or q.slug=="stratholme-undead" then
                used[q.slug]=true
                for _,entry in ipairs(q) do if not seen[entry.id] then seen[entry.id]=true; merged[#merged+1]=entry end end
                for _,side in ipairs({"alliance","horde"}) do for _,note in ipairs(q[side] or {}) do merged[side][#merged[side]+1]=note end end
                if not q.classic then merged.classic=false end
            end end
            if #merged>0 then questSource=merged end
        end
        for _,q in ipairs(questDungeons) do
            if not questSource and (q.slug==d.slug or normalized(q.name)==normalized(d.name)) then questSource=q; break end
        end
        if questSource then
            d.slug=questSource.slug; d.questSource=questSource; used[questSource.slug]=true
            d.min=d.min or questSource.min; d.max=d.max or questSource.max; d.zone=questSource.zone
        end
        d.min=d.min or d.required or 60; d.max=d.max or 60; d.required=d.required or d.min
        if not d.zone and d.zoneMap then local m=ns.API.Call("C_Map","GetMapInfo",d.zoneMap); d.zone=m and m.name end
        d.hasLoot=false; for _,e in ipairs(d.encounters or {}) do if #e.loot>0 then d.hasLoot=true; break end end
        entries[#entries+1]=d
    end
    for _,q in ipairs(questDungeons) do if not used[q.slug] then
        entries[#entries+1]={slug=q.slug,name=q.name,min=q.min,max=q.max,required=q.min,zone=q.zone,questSource=q,
            encounters={},hasLoot=false,betaListed=false,source="WoW Forever Builds quest reference (MIT)"}
    end end
    table.sort(entries,function(a,b) if a.min~=b.min then return a.min<b.min end; return a.name<b.name end)
    D.entries=entries; return entries
end
function D.Get(slug)
    if type(slug)~="string" then return end
    if slug=="stratholme-live" or slug=="stratholme-undead" then slug="stratholme" end
    local target=aliases[slug] or slug
    for _,d in ipairs(D.Entries()) do if d.slug==target or d.key==slug or aliases[d.key]==target then return d end end
end
function D.SourceAllowed(d,item)
    if d.announcement or d.nativeOnly then return false,"Journal details are not available for this entry" end
    if d.foreverLive~=true then return false,"Forever acquisition not confirmed" end
    if d.required>ns.Rules.Cap() then return false,"Above active content cap" end
    if d.required>ns.State.level then return false,"Requires level "..d.required end
    if item and item.referenceOnly then return false,"Reference source only" end
    if item then return ns.Rules.CharacterAllows(item) end
    return true
end
function D.Drops(d,query,encounter)
    local drops={}; query=(query or ""):lower()
    for _,e in ipairs(d.encounters or {}) do
        for _,item in ipairs((not encounter or encounter==e) and e.loot or {}) do
            local info=ns.API.Item(item.id,encounter==nil)
            local name=(info and info.name) or item.name or ("Item #"..item.id)
            if query=="" or (name.." "..e.name.." "..item.id):lower():find(query,1,true) then
                local allowed,reason=D.SourceAllowed(d,item)
                if not info then allowed=false; reason="Item data not yet available" end
                if info and info.required>math.min(ns.State.level,ns.Rules.Cap()) then allowed=false; reason="Requires level "..info.required end
                if info and ns.Data.equipSlots[info.equip] then
                    local usable,eligibility=ns.API.ItemEligibility(item.id,info)
                    if usable~=true then allowed=false; reason=eligibility end
                end
                drops[#drops+1]={id=item.id,info=info,name=name,link=info and info.link,source=d.name..": "..e.name,
                    dungeon=d.slug,boss=e.name,encounter=e,classes=item.classes,class=item.class,
                    faction=item.faction or item.side,races=item.races,actionable=allowed,reason=reason,corroborated=item.corroborated,
                    required=info and info.required or d.required,catalog=true,live=(ns.State.owned[item.id] or 0)>0,
                    foreverLive=d.foreverLive==true,sourceKnown=d.foreverLive==true and not item.referenceOnly,
                    referenceOnly=item.referenceOnly or d.foreverLive~=true}
            end
        end
    end
    return drops
end
function D.GearCandidates()
    local out={}
    for _,d in ipairs(D.Entries()) do
        if d.required<=ns.Rules.Cap() then
            for _,r in ipairs(D.Drops(d)) do if r.info and ns.Data.equipSlots[r.info.equip] then out[#out+1]=r end end
        end
    end
    return out
end
function D.HuntCount(d)
    local count=0
    for id,target in pairs(ns.char.farming or {}) do
        local source=target.dungeon and D.Get(target.dungeon)
        if source and source.slug==d.slug and not target.obtained and (ns.State.owned[id] or 0)==0 then count=count+1 end
    end
    return count
end
local function searchDungeon(d,query,add,includeQuests)
    local number=tonumber(query)
    local function matches(name,id)
        if number then return number==id end
        return type(name)=="string" and name:lower():find(query,1,true)~=nil
    end
    if matches(d.name.." "..(d.zone or "")) and add({kind="dungeon",name=d.name}) then return end
    if includeQuests then
        for _,quest in ipairs(d.questSource or {}) do
            if not quest.classic and matches(quest.title,quest.id)
                and add({kind="quest",name=quest.title,quest=quest.id,record=quest}) then return end
        end
    end
    for index,boss in ipairs(d.encounters or {}) do
        if matches(boss.name) and add({kind="boss",name=boss.name,boss=index}) then return end
        for _,item in ipairs(boss.loot or {}) do
            local cached=ns.API.itemCache and ns.API.itemCache[item.id]
            local name=cached and cached.info and cached.info.name or item.name or ""
            if (matches(name,item.id) or not number and matches(item.name))
                and add({kind="item",name=name~="" and name or "Item #"..item.id,boss=index,item=item.id,bossName=boss.name}) then return end
        end
    end
end
function D.SearchMatch(d,query)
    local result
    searchDungeon(d,(query or ""):lower(),function(match) result=match;return true end,false)
    return result
end
function D.Search(query,limit)
    local rows,total={},0
    limit=limit or 100
    query=(query or ""):lower():match("^%s*(.-)%s*$")
    if query=="" then return rows,total end
    local itemID,questID=query:match("item:(%d+)"),query:match("quest:(%d+)")
    query=itemID or questID or query
    for _,d in ipairs(D.Entries()) do
        searchDungeon(d,query,function(match)
            if itemID and match.kind~="item" or questID and match.kind~="quest" then return end
            total=total+1
            if #rows<limit then match.dungeon=d;rows[#rows+1]=match end
        end,true)
    end
    return rows,total
end

-- Filtering is presentation only; it never promotes a reference drop to an
-- actionable acquisition or hides uncached items from the default catalog.
function D.MatchesLoot(record,filter)
    filter=filter or {}
    if filter.usable and (not record.info or ns.API.ItemEligibility(record.id,record.info)~=true) then return false end
    if filter.slot then
        local matches=false
        for _,slot in ipairs(record.info and ns.Data.equipSlots[record.info.equip] or {}) do if slot==filter.slot then matches=true end end
        if not matches then return false end
    end
    local owned=(ns.State.owned[record.id] or 0)>0
    if filter.ownership=="missing" and owned or filter.ownership=="owned" and not owned then return false end
    if filter.ownership=="tracked" and not ns.char.farming[record.id] then return false end
    return true
end
