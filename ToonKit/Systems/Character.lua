local addonName, ns = ...
local S={ equipment={}, bags={}, owned={}, quests={}, talents={} }; ns.State=S
function S.Identity()
    S.name=ns.Safe(UnitName("player"),"Adventurer")
    local label,class,classID=UnitClass("player"); S.class=ns.Safe(class,"UNKNOWN"); S.className=ns.Safe(label,"Unknown"); S.classID=ns.Safe(classID)
    local race,raceToken,raceID=UnitRace("player");S.raceID=ns.Safe(raceID)
    S.race=ns.Safe(race,"Unknown"); S.raceToken=ns.Safe(raceToken,S.race); S.faction=ns.Safe(UnitFactionGroup("player"),"Neutral")
    S.level=ns.Safe(UnitLevel("player"),1)
end
function S.Inventory()
    S.equipment,S.bags,S.owned={},{},{};S.inventoryItemIDs={};S.bagLookup={};
    for _,slot in ipairs(ns.Data.slots) do
        local id,link,icon=ns.API.Equipped(slot[1])
        S.equipment[slot[1]]={id=id,link=link,icon=icon,info=(link or id) and ns.API.Item(link or id)}
        if id then S.owned[id]=(S.owned[id] or 0)+1;S.inventoryItemIDs[id]=true end
    end
    S.free,S.capacity=0,0;S.bagSlots={};S.bagFree={}
    for _,bag in ipairs(ns.API.Bags()) do
        local slots=ns.Safe(ns.API.Call("C_Container","GetContainerNumSlots",bag),0)
        local free=ns.Safe(ns.API.Call("C_Container","GetContainerNumFreeSlots",bag),0)
        S.bagSlots[bag]=slots;S.bagFree[bag]=free
        S.capacity=S.capacity+slots; S.free=S.free+free
        for slot=1,slots do
            local raw=ns.API.Call("C_Container","GetContainerItemInfo",bag,slot)
            local id=type(raw)=="table" and ns.Safe(raw.itemID) or ns.Safe(ns.API.Call("C_Container","GetContainerItemID",bag,slot))
            local link=type(raw)=="table" and ns.Safe(raw.hyperlink) or id and ns.Safe(ns.API.Call("C_Container","GetContainerItemLink",bag,slot))
            local item={bag=bag,slot=slot,id=id,link=link}
            if type(raw)=="table" then
                item.id=ns.Safe(raw.itemID) or item.id
                item.link=ns.Safe(raw.hyperlink) or item.link
                item.count=ns.Safe(raw.stackCount,1); item.quality=ns.Safe(raw.quality)
                item.locked=ns.Safe(raw.isLocked,false); item.icon=ns.Safe(raw.iconFileID)
                item.readable=ns.Safe(raw.isReadable,ns.Safe(raw.IsReadable,false))
                local binding=ns.Safe(raw.isBound)
                item.boundKnown=type(binding)=="boolean";item.bound=binding;item.name=ns.Safe(raw.itemName)
            end
            if not item.id and type(item.link)=="string" then item.id=tonumber(item.link:match("item:(%d+)")) end
            if item.id or item.link then
                item.info=ns.API.Item(item.link or item.id)
                item.itemLevel=ns.API.BagItemLevel(bag,slot,item.link,item.info)
                item.quality=item.quality or (item.info and item.info.quality)
                item.icon=item.icon or (item.info and item.info.icon) or ns.Safe(ns.API.Call("C_Item","GetItemIconByID",item.id or item.link))
                item.quest=ns.API.Call("C_Container","GetContainerItemQuestInfo",bag,slot)
                if item.id then S.owned[item.id]=(S.owned[item.id] or 0)+(item.count or 1);S.inventoryItemIDs[item.id]=true end
            end
            S.bags[#S.bags+1]=item;S.bagLookup[bag..":"..slot]=item
        end
    end
    local parts={tostring(S.level),tostring(S.free),tostring(S.capacity)}
    local function add(value) parts[#parts+1]=tostring(ns.Safe(value)) end
    for _,slot in ipairs(ns.Data.slots) do local item=S.equipment[slot[1]];add(item.id);add(item.link);add(item.icon);add(item.info) end
    for _,bag in ipairs(ns.API.Bags()) do add(S.bagSlots[bag]);add(S.bagFree[bag]) end
    for _,item in ipairs(S.bags) do
        add(item.bag);add(item.slot);add(item.id);add(item.link);add(item.count);add(item.quality);add(item.locked);add(item.bound);add(item.readable);add(item.icon);add(item.info);add(item.itemLevel)
        local quest=item.quest;if type(quest)=="table" then add(quest.questID);add(quest.isQuestItem);add(quest.isActive) else add(false) end
    end
    local signature=table.concat(parts,"\031")
    if S.inventorySignature==signature then return false end
    S.inventorySignature=signature;S.inventoryRevision=(S.inventoryRevision or 0)+1
    -- Advisory metadata must not abort a successful native bag enumeration.
    if ns.InventoryRules then ns.Invoke("inventorySnapshot",ns.InventoryRules.Snapshot) end
    if ns.Gear then ns.Invoke("inventoryFarming",ns.Gear.UpdateFarming) end
    return true
end
function S.Quests()
    S.quests={}
    local count=ns.Safe(ns.API.Call("C_QuestLog","GetNumQuestLogEntries"),0)
    local seen,header={}
    for i=1,count do
        local q=ns.API.Call("C_QuestLog","GetInfo",i)
        local id=q and ns.Safe(q.questID)
        if q and ns.Safe(q.isHeader)==true then
            header=ns.Safe(q.title)
        elseif type(id)=="number" and id>0 and not seen[id]
            and not ns.Safe(q.isHidden,false) and not ns.Safe(q.isTask,false) then
            seen[id]=true
            local objectives=ns.API.Call("C_QuestLog","GetQuestObjectives",id) or {}
            S.quests[#S.quests+1]={ id=id,title=ns.Safe(q.title,"Quest"),level=ns.Safe(q.level,0),index=i,header=header,
                complete=ns.Safe(ns.API.Call("C_QuestLog","IsComplete",id),false),objectives=objectives,
                map=ns.Safe(ns.API.Call("C_QuestLog","GetNextWaypoint",id)),live=true }
        end
    end
    table.sort(S.quests,function(a,b)
        if a.complete~=b.complete then return a.complete end
        if a.level~=b.level then return a.level<b.level end
        return a.index<b.index
    end)
    local parts={tostring(#S.quests)}
    local function add(value) parts[#parts+1]=tostring(ns.Safe(value)) end
    for _,q in ipairs(S.quests) do
        add(#(q.objectives or {}))
        add(q.id);add(q.title);add(q.level);add(q.index);add(q.header);add(q.complete);add(q.map)
        for _,o in ipairs(q.objectives or {}) do add(o.text);add(o.finished);add(o.numFulfilled);add(o.numRequired);add(o.type) end
    end
    local signature=table.concat(parts,"\031")
    if S.questSignature==signature then return false end
    S.questSignature=signature;S.questRevision=(S.questRevision or 0)+1
    -- Diagnostic snapshot only. Progression always queries the current native
    -- log; this saved copy must never become completion or acceptance evidence.
    if ns.char then
        local snapshot={level=S.level,recorded=type(GetServerTime)=="function" and ns.Safe(GetServerTime()) or nil,quests={}}
        for _,q in ipairs(S.quests) do
            local record={id=q.id,title=q.title,level=q.level,complete=q.complete,map=q.map,objectives={}}
            for _,o in ipairs(q.objectives or {}) do
                record.objectives[#record.objectives+1]={text=ns.Safe(o.text),finished=ns.Safe(o.finished),numFulfilled=ns.Safe(o.numFulfilled),numRequired=ns.Safe(o.numRequired)}
            end
            snapshot.quests[#snapshot.quests+1]=record
        end
        ns.char.questSnapshot=snapshot
    end
    return true
end
function S.Refresh(kind)
    if not ns.char then return end
    local flags=type(kind)=="table" and kind or {[kind or "all"]=true}
    local changed={}
    if flags.all or flags.identity then S.Identity();changed.identity=true end
    if flags.all or flags.inventory or flags.identity then if S.Inventory() then changed.inventory=true end end
    if flags.questEvidence then S.questEvidenceRevision=(S.questEvidenceRevision or 0)+1 end
    if flags.all or flags.quests then if S.Quests() or flags.questEvidence then changed.quests=true end end
    if (flags.all or flags.talents or flags.identity) and ns.Talents then ns.Talents.Read();changed.talents=true end
    if flags.all then changed.all=true end
    if not next(changed) then return end
    S.revision=(S.revision or 0)+1;S.refreshCount=(S.refreshCount or 0)+1
    if ns.Journey then ns.Journey.Advance() end
    ns.Emit("STATE_CHANGED",changed)
end
function S.QueueRefresh(kind,force)
    S.pendingRefresh=S.pendingRefresh or {};S.pendingRefresh[kind]=true
    if force then S.pendingRefresh.questEvidence=true end
    ns.After("characterRefresh",function() local flags=S.pendingRefresh;S.pendingRefresh=nil;if flags then S.Refresh(flags) end end,0.25)
end
local eventKinds={ PLAYER_LEVEL_UP="identity", PLAYER_EQUIPMENT_CHANGED="inventory", BAG_UPDATE_DELAYED="inventory",
    QUEST_LOG_UPDATE="quests", QUEST_WATCH_UPDATE="quests", QUEST_ACCEPTED="quests", QUEST_REMOVED="quests", QUEST_DATA_LOAD_RESULT="quests", PLAYER_TALENT_UPDATE="talents",
    TRAIT_CONFIG_UPDATED="talents", TRAIT_CONFIG_CREATED="talents", ACTIVE_TALENT_GROUP_CHANGED="talents", PLAYER_SPECIALIZATION_CHANGED="talents", TRAIT_CONFIG_CHANGED="talents", TRAIT_CONFIG_LIST_UPDATED="talents", SPELLS_CHANGED="talents", ZONE_CHANGED_NEW_AREA="quests" }
for event,kind in pairs(eventKinds) do
    local refreshKind=kind
    local force=event=="QUEST_ACCEPTED" or event=="QUEST_REMOVED" or event=="QUEST_DATA_LOAD_RESULT"
    ns.On(event,function() S.QueueRefresh(refreshKind,force) end)
end
for _,event in ipairs({"PLAYER_ENTERING_WORLD","BAG_UPDATE","BAG_CONTAINER_UPDATE","PLAYERBANKSLOTS_CHANGED"}) do
    local refreshKind=event=="PLAYER_ENTERING_WORLD" and "all" or "inventory"
    ns.On(event,function() S.QueueRefresh(refreshKind) end)
end
ns.On("ITEM_DATA_LOAD_RESULT",function(id,success)
    ns.API.ItemLoaded(id,success)
    if ns.Safe(success,false) then
        id=ns.Safe(id);if type(id)~="number" or id<=0 or id~=math.floor(id) then return end
        S.itemRevision=(S.itemRevision or 0)+1
        if S.inventoryItemIDs and S.inventoryItemIDs[id] then S.QueueRefresh("inventory") end
        S.readyItems=S.readyItems or {};S.readyItems[id]=true
        ns.After("catalogItems",function() local ready=S.readyItems;S.readyItems=nil;ns.Emit("ITEM_DATA_READY",ready) end)
    end
end)
ns.On("SPELL_DATA_LOAD_RESULT",function(_,success) if ns.Safe(success,false) then S.QueueRefresh("talents") end end)
function S.RecordQuest(kind,id)
    id=ns.Safe(id);if not ns.char or type(id)~="number" or id<=0 then return end
    local map,x,y=ns.API.Position()
    local now=type(GetServerTime)=="function" and ns.Safe(GetServerTime()) or nil
    ns.char.questHistory=ns.char.questHistory or {}
    local history=ns.char.questHistory
    local last=history[#history]
    if last and last.kind==kind and last.id==id and last.time==now then return end
    local xp=type(UnitXP)=="function" and ns.Safe(UnitXP("player")) or nil
    local maximum=type(UnitXPMax)=="function" and ns.Safe(UnitXPMax("player")) or nil
    local session=type(GetTime)=="function" and ns.Safe(GetTime()) or nil
    history[#history+1]={kind=kind,id=id,time=now,level=S.level,map=map,x=x,y=y,xp=xp,xpMax=maximum,sessionTime=session}
    if #history>2000 then table.remove(history,1) end
end
ns.On("QUEST_TURNED_IN",function(id)
    id=ns.Safe(id)
    if ns.char and type(id)=="number" then S.RecordQuest("turnedIn",id);ns.char.turnedIn[id]=true; S.QueueRefresh("quests",true) end
end)

-- Repeatable live quests get fresh manual objective state when accepted again.
ns.On("QUEST_ACCEPTED",function(first,second)
    local id=ns.Safe(second) or ns.Safe(first);if not ns.char or not id then return end
    S.RecordQuest("accepted",id)
    local prefix="live:"..id..":"
    for key in pairs(ns.char.goalProgress or {}) do if key:sub(1,#prefix)==prefix then ns.char.goalProgress[key]=nil end end
    if ns.char.liveHidden then ns.char.liveHidden[id]=nil end
end)

ns.On("ITEM_LOCK_CHANGED",function(bag,slot)
    bag,slot=ns.Safe(bag),ns.Safe(slot)
    if type(bag)~="number" or type(slot)~="number" then return end
    local item=S.bagLookup and S.bagLookup[bag..":"..slot];if not item then return end
    local raw=ns.API.Call("C_Container","GetContainerItemInfo",bag,slot)
    if type(raw)=="table" then item.locked=ns.Safe(raw.isLocked,false);ns.Emit("BAG_LOCK_CHANGED",bag,slot,item.locked) end
end)
