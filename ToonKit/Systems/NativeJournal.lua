local addonName, ns = ...
local D=ns.Journal
local function plain(value) value=ns.Safe(value);return type(value)=="string" and value or nil end
local function identity(name) return (plain(name) or ""):lower():gsub("^the ",""):gsub("[^%w]","") end
local function integer(value) value=ns.Safe(value);return type(value)=="number" and value>0 and value==math.floor(value) and value or nil end
local function encounter(id)
    if type(EJ_GetEncounterInfo)~="function" then return end
    local ok,name,description,_,root=pcall(EJ_GetEncounterInfo,id)
    if ok and plain(name) then return {id=id,name=plain(name),description=plain(description),root=integer(root)} end
end
function D.UIMapForInstance(gameMap)
    gameMap=integer(gameMap);if not gameMap or type(EJ_GetInstanceInfo)~="function" then return end
    local journal=integer(ns.API.Call("C_EncounterJournal","GetInstanceForGameMap",gameMap))
    if not journal then return end
    local ok,_,_,_,_,_,_,uiMap=pcall(EJ_GetInstanceInfo,journal)
    uiMap=ok and integer(uiMap)
    if uiMap and ns.API.Call("C_Map","GetMapInfo",uiMap) then return uiMap end
end
local mapNameIndex,mapHierarchyRead={},{}
local function namedDungeonMaps(d)
    local mapType=Enum and Enum.UIMapType and Enum.UIMapType.Dungeon
    if not mapType then return {} end
    local roots={};local rootSeen={}
    local function root(id) id=integer(id);if id and not rootSeen[id] then rootSeen[id]=true;roots[#roots+1]=id end end
    root(ns.API.Call("C_Map","GetFallbackWorldMapID"))
    local zone=d.zoneMap or d.entrance and d.entrance.map
    for depth=1,8 do
        if not integer(zone) or rootSeen[zone] then break end
        root(zone);local info=ns.API.Call("C_Map","GetMapInfo",zone);zone=info and integer(info.parentMapID)
    end
    for _,id in ipairs(roots) do if not mapHierarchyRead[id] then
        local children=ns.API.Call("C_Map","GetMapChildrenInfo",id,mapType,true)
        if type(children)=="table" and #children>0 then
            mapHierarchyRead[id]=true
            for _,info in ipairs(children) do
                local uiMap=integer(info.mapID);local name=identity(info.name)
                if uiMap and name~="" and ns.Safe(info.mapType)==mapType then
                    mapNameIndex[name]=mapNameIndex[name] or {};mapNameIndex[name][uiMap]=true
                end
            end
        end
    end end
    local rows,seen={},{}
    local function match(name)
        for id in pairs(mapNameIndex[identity(name)] or {}) do if not seen[id] then seen[id]=true;rows[#rows+1]=id end end
    end
    match(d.name);for _,wing in ipairs(d.maps or {}) do match(wing.name) end
    table.sort(rows);return rows
end
function D.NativeMaps(d)
    local maps,seen={},{}
    local function add(id) if integer(id) and not seen[id] and ns.API.Call("C_Map","GetMapInfo",id) then seen[id]=true;maps[#maps+1]=id end end
    local _,instanceType,_,_,_,_,_,currentInstance
    if type(GetInstanceInfo)=="function" then
        _,instanceType,_,_,_,_,_,currentInstance=GetInstanceInfo()
        instanceType=plain(instanceType)
        currentInstance=integer(currentInstance)
    end
    local instances={}
    local function addInstance(gameMap)
        gameMap=integer(gameMap)
        if not gameMap or instances[gameMap] then return end
        instances[gameMap]=true
        if currentInstance==gameMap and (instanceType=="party" or instanceType=="raid") then
            local id=integer(ns.API.Call("C_Map","GetBestMapForUnit","player"))
            local info=id and ns.API.Call("C_Map","GetMapInfo",id)
            local mapType=info and ns.Safe(info.mapType)
            local types=Enum and Enum.UIMapType
            if types and mapType and (mapType==types.Dungeon or mapType==types.Micro) then add(id) end
        end
        local uiMap=D.UIMapForInstance(gameMap)
        if uiMap then add(uiMap) end
        -- These are separately sourced Forever UI floor identities, never raw
        -- GameMap IDs. Native info must still exist for every fallback floor.
        for _,record in ipairs(ns.Data.nativeJournalMaps or {}) do
            if record.instanceID==gameMap then for _,id in ipairs(record.floors or {}) do add(id) end end
        end
    end
    addInstance(d.instanceID)
    for _,wing in ipairs(d.maps or {}) do addInstance(wing.instanceID) end
    for _,boss in ipairs(d.encounters or {}) do addInstance(boss.instanceID) end
    if #maps==0 then for _,id in ipairs(namedDungeonMaps(d)) do add(id) end end
    return maps,d.instanceID
end
function D.NativeMapEncounters(map)
    local rows={};local data=ns.API.Call("C_EncounterJournal","GetEncountersOnMap",map)
    for _,entry in ipairs(type(data)=="table" and data or {}) do
        local id=integer(entry.encounterID);local x,y=ns.Safe(entry.mapX),ns.Safe(entry.mapY)
        local record=id and encounter(id)
        if record and type(x)=="number" and type(y)=="number" and x>=0 and x<=1 and y>=0 and y<=1 then record.x=x;record.y=y;rows[#rows+1]=record end
    end
    return rows
end
function D.NativeDifficulties(d,chosen)
    if type(InCombatLockdown)~="function" or InCombatLockdown() then return nil,"Choose a journal difficulty after combat." end
    if type(EJ_SelectInstance)~="function" or type(EJ_IsValidInstanceDifficulty)~="function" or type(EJ_SetDifficulty)~="function" then return nil,"Native difficulty controls are unavailable." end
    local _,gameMap=D.NativeMaps(d)
    gameMap=gameMap or d.instanceID
    local journal=gameMap and integer(ns.API.Call("C_EncounterJournal","GetInstanceForGameMap",gameMap))
    if not journal then return nil,"The client has not supplied a journal identity for this instance." end
    -- Called only from an explicit user action, never while rendering a page.
    EJ_SelectInstance(journal)
    local choices={};local seen={}
    local function add(id)
        id=integer(id);if not id or id>256 or seen[id] then return end;seen[id]=true
        local ok,valid=pcall(EJ_IsValidInstanceDifficulty,id)
        if not ok or ns.Safe(valid)~=true then return end
        if C_EncounterJournal and type(C_EncounterJournal.InstanceHasDifficultyID)=="function" then
            if ns.Safe(ns.API.Call("C_EncounterJournal","InstanceHasDifficultyID",id))~=true then return end
        elseif id>=64 then return end
        local name
        if type(GetDifficultyInfo)=="function" then local readable,value=pcall(GetDifficultyInfo,id);if readable then name=plain(value) end end
        choices[#choices+1]={value=id,label=(name or "Native difficulty").." (#"..id..")"}
    end
    for id=1,63 do add(id) end
    for _,id in pairs(Enum and Enum.Difficulty or {}) do add(id) end
    table.sort(choices,function(a,b) return a.value<b.value end)
    if #choices==0 then return nil,"The client has not supplied available difficulties for this instance." end
    if chosen then
        local valid=false;for _,row in ipairs(choices) do if row.value==chosen then valid=true end end
        if not valid then return nil,"This difficulty is no longer available for the selected instance." end
        EJ_SetDifficulty(chosen)
    end
    return choices
end
function D.NativeDetails(d,boss)
    if not boss or type(EJ_GetEncounterInfo)~="function" then return end
    local matched
    for _,map in ipairs(D.NativeMaps(d)) do
        for _,record in ipairs(D.NativeMapEncounters(map)) do if identity(record.name)==identity(boss.name) then matched=record;break end end
        if matched then break end
    end
    if not matched and d.instanceID and type(EJ_GetEncounterInfoByIndex)=="function" then
        local journal=integer(ns.API.Call("C_EncounterJournal","GetInstanceForGameMap",d.instanceID))
        if journal then
            for index=1,128 do
                local ok,name,_,id,_,_,instance=pcall(EJ_GetEncounterInfoByIndex,index,journal)
                if not ok or not plain(name) then break end
                if integer(instance)~=journal then break end
                if identity(name)==identity(boss.name) then matched=integer(id) and encounter(id);break end
            end
        end
    end
    if not matched then return end
    local seen,sections={},{}
    local function visit(id,depth,path)
        id=integer(id);if not id or seen[id] or depth>16 or #sections>=256 then return end
        seen[id]=true
        local info=ns.API.Call("C_EncounterJournal","GetSectionInfo",id)
        if type(info)~="table" then return end
        local title=plain(info.title) or "Encounter section"
        local route=path~="" and path.." / "..title or title
        if ns.Safe(info.filteredByDifficulty)~=true then
            local flags={};local raw=ns.API.Call("C_EncounterJournal","GetSectionIconFlags",id)
            for _,flag in ipairs(type(raw)=="table" and raw or {}) do local value=ns.Safe(flag);if type(value)=="number" and value>=0 and value<=64 and value==math.floor(value) then flags[#flags+1]=value end end
            sections[#sections+1]={id=id,title=title,path=route,description=plain(info.description),spell=integer(info.spellID),icon=integer(info.abilityIcon),depth=depth,flags=flags}
            visit(info.firstChildSectionID,depth+1,route)
        end
        visit(info.siblingSectionID,depth,path)
    end
    visit(matched.root,0,"");matched.sections=sections
    if type(EJ_GetDifficulty)=="function" then
        local ok,difficulty=pcall(EJ_GetDifficulty);matched.difficulty=ok and integer(difficulty) or nil
    end
    return matched
end
