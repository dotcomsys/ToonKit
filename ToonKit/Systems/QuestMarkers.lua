local addonName, ns = ...
local Q={};ns.QuestMarkers=Q
local objectives={kill=true,collect=true,complete=true,interact=true}
-- Only visible consumers schedule work. Large source/projection walks run in
-- small cooperative slices; combat/loot events never restart the static index.
local function repaint()
    if ns.World then ns.World.RefreshPins() end
    if ns.DiscoveryPins then ns.DiscoveryPins.Refresh() end
end
function Q.ScheduleWork()
    if Q.workScheduled then return end
    Q.workScheduled=true;C_Timer.After(.04,Q.Work)
end
local function routeMatches(route)
    return ns.Rules.RouteAvailable(route) and ns.Journey.Applies({classes=route.classes,races=route.races,factions=route.faction and {route.faction}})
end
function Q.Index()
    local profile=table.concat({ns.State.class or "",ns.State.raceToken or "",ns.State.faction or "",ns.Rules.Cap()},":")
    local source=ns.Journey.RouteSource()
    if Q.source==source and Q.profile==profile then
        if Q.indexJob then Q.ScheduleWork() end
        return
    end
    Q.source=source;Q.profile=profile
    Q.quests={};Q.flights={};Q.pickups={};Q.projections={};Q.projectionQueue={};Q.cacheSlots={};Q.cacheOrder={};Q.projectionOrder={}
    Q.indexReady=false
    local routes=Q.source
    Q.indexJob={index=true,iterator=coroutine.create(function()
        for _,route in ipairs(routes) do
            if routeMatches(route) then for _,step in ipairs(route.steps or {}) do
                if ns.Journey.Applies(step.only) then for _,goal in ipairs(step.goals or {}) do
                    if ns.Journey.Applies(goal.only) then
                        local entry={route=route,step=step,goal=goal}
                        if goal.quest then
                            Q.quests[goal.quest]=Q.quests[goal.quest] or {};Q.quests[goal.quest][#Q.quests[goal.quest]+1]=entry
                            if goal.t=="accept" and not goal.item and not goal.enrouteDestination then Q.pickups[#Q.pickups+1]=entry end
                        elseif goal.t=="getfp" then Q.flights[#Q.flights+1]=entry end
                    end
                    coroutine.yield()
                end end
                coroutine.yield()
            end end
            coroutine.yield()
        end
    end)}
    Q.ScheduleWork()
end
function Q.Work()
    Q.workScheduled=false
    if not ns.char or not ns.db.settings.modules.journey then return end
    local world=WorldMapFrame and WorldMapFrame:IsShown() and ns.db.settings.mapPins
    local mini=Minimap and Minimap:IsShown() and ns.db.settings.journeyMinimap
    if not world and not mini then return end
    local worldMap=world and WorldMapFrame:GetMapID()
    local worldStitched=world and ns.MapWorkspace and ns.MapWorkspace.Stitched() or false
    local miniMap=mini and ns.DiscoveryPins and ns.DiscoveryPins.map
    for i=#(Q.projectionQueue or {}),1,-1 do
        local pending=Q.projectionQueue[i]
        if not (world and pending.map==worldMap and pending.stitched==worldStitched)
            and not (mini and pending.map==miniMap and not pending.stitched) then
            table.remove(Q.projectionQueue,i);pending.queued=false
        end
    end
    local job=Q.indexJob or Q.projectionQueue and Q.projectionQueue[1]
    if not job then return end
    local clock=type(debugprofilestop)=="function" and debugprofilestop()
    for n=1,(job.index and 128 or 32) do
        local ok,err=coroutine.resume(job.iterator)
        if not ok then ns.errors.questMarkerWork=tostring(err);job.failed=true;break end
        if coroutine.status(job.iterator)=="dead" then break end
        if clock and debugprofilestop()-clock>=.8 then break end
    end
    local finished=job.failed or coroutine.status(job.iterator)=="dead"
    if finished then
        if job.index then Q.indexJob=nil;Q.indexReady=not job.failed
        else table.remove(Q.projectionQueue,1);job.queued=false;job.ready=true end
        Q.revision=(Q.revision or 0)+1;ns.After("questMarkers",repaint)
    elseif not job.index and #Q.projectionQueue>1 then
        table.remove(Q.projectionQueue,1);Q.projectionQueue[#Q.projectionQueue+1]=job
    end
    if Q.indexJob or Q.projectionQueue and #Q.projectionQueue>0 then Q.ScheduleWork() end
end
function Q.Projected(map,stitched)
    if type(map)~="number" or map<=0 then return end
    stitched=stitched==true
    if not Q.indexReady then if Q.indexJob then Q.ScheduleWork() end;return end
    local scope=tostring(map)..":"..tostring(stitched)
    local cached=Q.projections[scope]
    if cached then
        if not cached.ready then
            if not cached.queued then cached.queued=true;Q.projectionQueue[#Q.projectionQueue+1]=cached end
            Q.ScheduleWork()
        end
        return cached.ready and cached or nil
    end
    -- Two visible consumers normally need two maps; retain a small bounded set.
    if #Q.projectionOrder>=6 then
        local old=table.remove(Q.projectionOrder,1);local removed=Q.projections[old];Q.projections[old]=nil
        for i=#Q.projectionQueue,1,-1 do if Q.projectionQueue[i]==removed then table.remove(Q.projectionQueue,i) end end
    end
    local job={pickups={},flights={},map=map,stitched=stitched,queued=true};Q.projections[scope]=job;Q.projectionOrder[#Q.projectionOrder+1]=scope
    job.iterator=coroutine.create(function()
        local known={}
        local function project(point)
            if type(point.map)~="number" or type(point.x)~="number" or type(point.y)~="number" then return end
            local key=point.map..":"..point.x..":"..point.y
            if known[key]~=nil then return known[key] or nil end
            local p=stitched and point or ns.Travel.Project(point,map)
            known[key]=p or false;return p
        end
        for _,list in ipairs({Q.pickups,Q.flights}) do for _,entry in ipairs(list) do
            local goal=entry.goal;local points={}
            if not goal.enrouteDestination then
                if goal.map and goal.x and goal.y then local point=project(goal);if point then points[#points+1]=point end;coroutine.yield() end
                if not goal.fixedNavigation then for _,point in ipairs(goal.locations or {}) do
                    if ns.Journey.Applies(point.only) then local p=project(point);if p then points[#points+1]=p end end
                    coroutine.yield()
                end end
            end
            if #points>0 then local target=goal.t=="getfp" and job.flights or job.pickups;target[#target+1]={entry=entry,points=points} end
            coroutine.yield()
        end end
    end)
    Q.projectionQueue[#Q.projectionQueue+1]=job;Q.ScheduleWork()
end
local function applies(entry)
    local r=entry.route
    return ns.Rules.RouteAvailable(r) and ns.Journey.Applies({classes=r.classes,races=r.races,factions=r.faction and {r.faction}})
        and ns.Journey.Applies(entry.step.only) and ns.Journey.Applies(entry.goal.only)
end
local function valid(p)
    return p and type(p.map)=="number" and type(p.x)=="number" and type(p.y)=="number"
        and p.map>0 and p.x>=0 and p.x<=1 and p.y>=0 and p.y<=1
end
function Q.Icon(goal)
    if ns.Main and ns.Main.JourneyIcon then return ns.Main.JourneyIcon(goal) end
    return "Interface\\GossipFrame\\IncompleteQuestIcon"
end
function Q.PickupEligible(goal)
    local level=math.min(ns.State.level,ns.Rules.Cap())
    local id=goal.quest
    if not id or ns.Journey.OnQuest(id) or ns.Journey.QuestDone(id) then return false end
    local meta=ns.Data.questSupport.meta[id]
    if meta and not ns.QuestSupplies.Eligible(id,level) then return false end
    local minimum=goal.minLevel or (meta and meta.min and meta.min>0 and meta.min) or goal.qlvl
    return (not minimum or minimum<=level) and not ns.Journey.Blocked(goal)
end
function Q.Contact(goal)
    return goal.quest and (goal.t=="accept" or goal.t=="turnin")
end
function Q.NearContact(a,b)
    return a.map==b.map and (a.x-b.x)^2+(a.y-b.y)^2<=.0025^2
end
function Q.Markers(map,stitched)
    stitched=stitched==true
    if not ns.char or not ns.db.settings.modules.journey then return {} end
    Q.Index()
    local projected=Q.Projected(map,stitched)
    local scope=tostring(map)..":"..tostring(stitched)
    local key=table.concat({Q.revision or 0,Q.rulesRevision or 0,ns.State.questRevision or 0,ns.State.questEvidenceRevision or 0,ns.State.inventoryRevision or 0,ns.Talents.revision or 0,
        ns.State.class or "",ns.State.raceToken or "",ns.State.faction or "",ns.State.level or 0,ns.Rules.Cap(),ns.Travel.nodeRevision or 0,map or 0,
        tostring(ns.db.settings.questMapPins),tostring(ns.db.settings.questPickupPins),tostring(ns.db.settings.flightMapPins),tostring(stitched)},":")
    local cache=Q.cacheSlots[scope]
    if cache and cache.key==key then return cache.rows end
    local rows,seen,contacts={},{},{}
    local function add(goal,point,title,source)
        if not valid(point) then return end
        local p=stitched and point or ns.Travel.Project(point,map);if not valid(p) then return end
        local id=table.concat({goal.quest or "flight",goal.t,p.map,string.format("%.5f",p.x),string.format("%.5f",p.y)},":")
        if seen[id] then return end;seen[id]=true
        if Q.Contact(goal) then
            local key=goal.quest..":"..goal.t
            local points=contacts[key] or {};contacts[key]=points
            for _,prior in ipairs(points) do if Q.NearContact(prior,p) then return end end
            points[#points+1]=p
        end
        rows[#rows+1]={goal=goal,point=p,name=title,source=source,icon=Q.Icon(goal)}
    end
    local function sourced(entry,title,points)
        local goal=entry.goal
        -- Travel detours and en-route handoffs are not surveyed objective positions.
        if goal.enrouteDestination then return end
        local source=(goal.t=="accept" and "Source-listed pickup; availability must be checked with the quest giver. " or "Authored reference location; not a spawn boundary or NPC patrol. ")..(entry.route.source or "Licensed route")
        if points then for _,point in ipairs(points) do add(goal,point,title,source) end;return end
        if valid(goal) then add(goal,goal,title,source) end
        if not goal.fixedNavigation then for _,p in ipairs(goal.locations or {}) do
            if ns.Journey.Applies(p.only) then add(goal,p,title,source) end
        end end
    end
    if ns.db.settings.questMapPins~=false or ns.db.settings.questPickupPins~=false then
        if ns.db.settings.questMapPins~=false then
        for _,quest in ipairs(ns.State.quests or {}) do
            local ready=ns.Journey.ReadyToTurnIn(quest.id)
            local phase=ready and "turnin" or "complete"
            local native={t=phase,quest=quest.id,nativeQuestNavigation=true}
            local point=ns.Navigation.FinalLocation(native)
            if point then add(native,point,quest.title,ready and "Native quest return destination." or "Native quest destination; may cover several objectives.") end
            -- A native return marker supersedes source-listed contacts.
            if not ready or not point then for _,entry in ipairs(Q.quests[quest.id] or {}) do
                local g=entry.goal
                if applies(entry) and (ready and g.t=="turnin" or not ready and objectives[g.t]) then
                    local objective=g.oi and quest.objectives and quest.objectives[g.oi]
                    if g.t=="collect" and g.item then objective=ns.Journey.ItemObjective(g) end
                    if not (objective and ns.Safe(objective.finished)==true) and not ns.Journey.Blocked(g) then
                        sourced(entry,quest.title..": "..ns.Journey.GoalText(g))
                    end
                end
            end end
        end
        end
        if ns.db.settings.questPickupPins~=false then
            local nativeStarts={}
            local starts=map and ns.Safe(ns.API.Call("C_QuestLine","GetAvailableQuestLines",map))
            if type(starts)=="table" then
                for _,start in ipairs(starts) do
                    local id=ns.Safe(start.questID)
                    if type(id)=="number" and id>0 and ns.Safe(start.isQuestStart)==true
                        and ns.Safe(start.isHidden)==false and ns.Safe(start.inProgress)==false
                        and not ns.Journey.OnQuest(id) and not ns.Journey.QuestDone(id) then
                        local point={map=map,x=ns.Safe(start.x),y=ns.Safe(start.y)}
                        if valid(point) then
                            add({t="accept",quest=id},point,"Pick up: "..ns.Safe(start.questName,"Quest #"..id),"Blizzard quest start.")
                            nativeStarts[id]=true
                        end
                    end
                end
            end
            for _,record in ipairs(projected and projected.pickups or {}) do
                local entry=record.entry;local g=entry.goal
                if not nativeStarts[g.quest] and applies(entry) and Q.PickupEligible(g) then
                    sourced(entry,"Pick up: "..(g.title or "Quest #"..g.quest),record.points)
                end
            end
        end
    end
    if ns.db.settings.flightMapPins~=false then
        for _,node in pairs(ns.char.travelNodes or {}) do
            local p=not stitched and ns.Travel.NodePoint(node,map)
            if p then add({t="getfp"},p,node.name or "Flight master",node.known and "Native recorded flight node: known." or "Native recorded flight node: undiscovered.") end
            if stitched then for _,point in pairs(node.points or {}) do
                add({t="getfp"},point,node.name or "Flight master",node.known and "Native recorded flight node: known." or "Native recorded flight node: undiscovered.")
            end end
        end
        for _,record in ipairs(projected and projected.flights or {}) do local entry=record.entry
            if applies(entry) then sourced(entry,"Flight master: "..(entry.goal.npcName or entry.goal.title or entry.route.name),record.points) end
        end
    end
    if not Q.cacheSlots[scope] then
        if #Q.cacheOrder>=6 then Q.cacheSlots[table.remove(Q.cacheOrder,1)]=nil end
        Q.cacheOrder[#Q.cacheOrder+1]=scope
    end
    Q.cacheSlots[scope]={key=key,rows=rows};return rows
end
ns.On("QUEST_POI_UPDATE",function()
    Q.revision=(Q.revision or 0)+1
    ns.After("questMarkers",function() ns.World.RefreshPins();if ns.DiscoveryPins then ns.DiscoveryPins.Refresh() end end)
end)

ns.Listen("STATE_CHANGED",function(kind)
    if ns.Changed(kind,"journey") then Q.rulesRevision=(Q.rulesRevision or 0)+1 end
end)
ns.Listen("SETTINGS_CHANGED",function() Q.rulesRevision=(Q.rulesRevision or 0)+1 end)
ns.Listen("ITEM_DATA_READY",function(ids)
    if type(ids)~="table" then return end
    for _,quest in ipairs(ns.State.quests or {}) do for _,entry in ipairs(Q.quests and Q.quests[quest.id] or {}) do
        if entry.goal.item and ids[entry.goal.item] then Q.revision=(Q.revision or 0)+1;ns.After("questMarkers",repaint);return end
    end end
end)
