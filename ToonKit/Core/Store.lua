local addonName, ns = ...
ns.Defaults = {
    scale=1, locked=false, guide=true, guideCollapsed=false, autoAdvance=true,
    notifications=true, collections=true, mapPins=true, nearby=false, inventory=true,
    bagColumns=12, bagSpacing=2, bagSort="category", showEmpty=false, showOwned=false,
    modules={ journey=true, talents=true, gear=true, dungeons=true, world=true },
    guideHideInteraction=true,questKeepAdvice=true, bagGrouped=true, minimap=true, minimapAngle=225,discoveryMinimap=true,
    weights={}, positions={},effectOverrides={},
    bagOrder={},bagEquipmentSets=true,bagCategoryCounts=true,bagGroups={},bagRules={},nextBagGroup=1,bagCollapsed={},bagGroupSort={},bagHiddenGroups={},bagSearchMode="dim",bookMissingOnly=true,
}
local function defaults(target, source)
    for k,v in pairs(source) do
        if target[k] == nil then target[k] = ns.Copy(v)
        elseif type(v)~=type(target[k]) then target[k]=ns.Copy(v)
        elseif type(v)=="table" then
            if type(target[k])~="table" then target[k]=ns.Copy(v) else defaults(target[k],v) end
        end
    end
end
function ns.LoadStore()
    local id=ns.Identity; local db=_G[id.savedVariable]
    if type(db)~="table" then
        for _, old in ipairs(id.legacy) do if type(_G[old])=="table" then db=ns.Copy(_G[old]); break end end
    end
    db=type(db)=="table" and db or {}; _G[id.savedVariable]=db
    db.settings=type(db.settings)=="table" and db.settings or {}
    db.characters=type(db.characters)=="table" and db.characters or {}
    defaults(db.settings,ns.Defaults)
    if db.settings.foreverIntegration~=1 then
        db.integrationArchive=db.integrationArchive or {}
        db.integrationArchive.contentMode=db.settings.mode
        db.settings.mode=nil;db.settings.gearUseModels=false;db.settings.foreverIntegration=1
        db.settings.questTrackerWidth=db.settings.questTrackerWidth or 320
        db.settings.questTrackerHeight=db.settings.questTrackerHeight or 480
        db.settings.questTrackerScroll=false
    end
    db.schema=id.schema; ns.db=db
end
function ns.LoadCharacterStore()
    local guid=ns.Safe(UnitGUID("player"))
    local name=ns.Safe(UnitName("player"))
    local realm=ns.Safe(GetRealmName(),"realm")
    if guid or name then
        local key=guid or (realm..":"..name)
        if not ns.db.characters[key] then
            local named=name and ns.db.characters[realm..":"..name]
            local fallback=_G[ns.Identity.characterVariable]
            if type(fallback)=="table" then
                local identity=fallback.identity
                local _,currentClass=UnitClass("player");currentClass=ns.Safe(currentClass)
                if not identity or identity.name~=name or identity.realm~=realm or not currentClass or identity.class~=currentClass then fallback=nil end
            end
            ns.db.characters[key]=ns.Copy(named or (type(fallback)=="table" and fallback) or {})
        end
        ns.char=ns.db.characters[key]
    else
        -- Never merge several redacted characters under a shared fallback name.
        local variable=ns.Identity.characterVariable
        _G[variable]=type(_G[variable])=="table" and _G[variable] or {}
        ns.char=_G[variable]
    end
    defaults(ns.char,{ routes={}, collections={}, farming={}, builds={}, playstyle="auto", turnedIn={}, personalDiscoveries={} })
    if ns.char.foreverIntegration~=1 then
        local archived={routes={},goals={},route=ns.char.route,returnRoute=ns.Copy(ns.char.routeReturn)}
        for id,value in pairs(ns.char.routes) do if type(id)=="string" and id:match("^dungeon:") then archived.routes[id]=ns.Copy(value);ns.char.routes[id]=nil end end
        for id,value in pairs(ns.char.goalProgress or {}) do if type(id)=="string" and id:match("^dungeon:") then archived.goals[id]=ns.Copy(value);ns.char.goalProgress[id]=nil end end
        ns.char.foreverProgressArchive=archived
        if type(ns.char.route)=="string" and ns.char.route:match("^dungeon:") then ns.char.route="live";ns.char.routeReturn=nil end
        ns.char.foreverIntegration=1
    end
end
function ns.SetSetting(key,value)
    ns.db.settings[key]=value; ns.Emit("SETTINGS_CHANGED",key,value); ns.Emit("STATE_CHANGED")
end
