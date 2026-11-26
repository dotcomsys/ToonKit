local addonName, ns = ...
local J={}; ns.Journey=J
function J.Speedrunning() return ns.char and ns.char.journeyGoal=="speedrun" end
function J.SetGoal(goal)
    if goal~="casual" and goal~="speedrun" then return end
    if (ns.char.journeyGoal or "casual")==goal then return end
    if ns.RouteTiming then ns.RouteTiming.Finish("goal changed") end
    ns.char.journeyGoalRoutes=ns.char.journeyGoalRoutes or {}
    ns.char.journeyGoalRoutes[ns.char.journeyGoal or "casual"]={id=ns.char.route,mode=ns.char.routeMode,returnRoute=ns.Copy(ns.char.routeReturn)}
    ns.char.journeyGoal=goal
    if goal=="speedrun" and ns.DungeonJourney and ns.DungeonJourney.prompt then ns.DungeonJourney.prompt:Hide() end
    ns.char.autoClassRoute=nil;ns.char.zoneVisit=nil
    ns.char.routeReturn=nil;ns.char.itinerary=nil;J.focusGoal=nil
    local saved=ns.char.journeyGoalRoutes[goal]
    local route=saved and J.Get(saved.id)
    if route and (route.min or 1)<=ns.State.level then
        ns.char.routeReturn=ns.Copy(saved.returnRoute)
        if J.Select(saved.id,saved.mode) then return end
    end
    J.Automatic()
end
function J.RouteSource()
    if ns.char and ns.char.journeyGuideSource=="polestar" then
        if J.Speedrunning() and ns.SoloRoutes then return ns.SoloRoutes.Routes() end
        return ns.Data.polestarRoutes
    end
    local key=table.concat({tostring(ns.State.classID),tostring(ns.State.raceID),tostring(ns.State.raceToken),tostring(ns.State.faction)},":")
    if J.originalSourceKey~=key or J.originalExtensionCount~=#ns.Data.routes then
        J.originalSourceKey=key
        J.originalExtensionCount=#ns.Data.routes
        local routes={}
        for _,source in ipairs({ns.Data.originalRoutes,ns.Data.BuildOriginalCatalog(),ns.Data.routes}) do
            for _,route in ipairs(source) do routes[#routes+1]=route end
        end
        J.originalSource=routes
    end
    return J.originalSource
end
function J.SetGuideSource(source)
    if source~="toonkit" and source~="polestar" then return end
    if (ns.char.journeyGuideSource or "toonkit")==source then return end
    if ns.RouteTiming then ns.RouteTiming.Finish("guide source changed") end
    ns.char.journeyGuideSource=source
    ns.char.journeyGoalRoutes={}
    ns.char.route,ns.char.routeReturn,ns.char.itinerary=nil,nil,nil
    ns.char.autoClassRoute,ns.char.zoneVisit,J.focusGoal=nil,nil,nil
    J.Automatic()
end
local function token(v) return tostring(v or ""):lower():gsub("[^%w]","") end
local function inList(values,value)
    if type(values)~="table" or next(values)==nil then return true end
    for _,v in pairs(values) do if token(v)==token(value) then return true end end; return false
end
function J.Applies(only)
    if not only then return true end
    return inList(only.classes,ns.State.class) and inList(only.races,ns.State.raceToken or ns.State.race) and inList(only.factions,ns.State.faction)
end
function J.DungeonSteps(d)
    local pending,order={},{}
    for _,q in ipairs(d) do if ns.Journal.QuestAccess(q) and not pending[q.id] then pending[q.id]=q;order[#order+1]=q end end
    local steps={}
    while next(pending) do
        local stage={}
        for _,q in ipairs(order) do
            local waiting=false
            for _,id in ipairs(q.prerequisites or (q.needsId and {q.needsId}) or {}) do
                if id~=q.id and pending[id] then waiting=true;break end
            end
            if pending[q.id] and not waiting then stage[#stage+1]=q end
        end
        -- Retain unresolved/cyclic source prerequisites as blocked pickups.
        if #stage==0 then for _,q in ipairs(order) do if pending[q.id] then stage[#stage+1]=q end end end
        for _,phase in ipairs({"accept","complete","turnin"}) do for _,q in ipairs(stage) do
            local id="dungeon:"..d.slug..":"..q.id..":"..phase
            local point=phase=="accept" and q.startAt or phase=="turnin" and q.turnInAt or phase=="complete" and q.objectiveAt
            local goal={id=id,t=phase,quest=q.id,title=q.title,dungeon=true}
            if phase=="accept" then
                goal.minLevel=q.req;goal.pre=q.prerequisites or (q.needsId and {q.needsId} or nil)
                goal.npcName=q.from;goal.note=point and point.place
            elseif phase=="turnin" then
                goal.npcName=q.turnIn;goal.note=point and point.place
                goal.interior=point and not point.map and point.place and point.place:find("^Inside ")~=nil
            else
                local note=(q.goal or "")..(q.note and "\n"..q.note or "")
                goal.note=point and point.place and (point.place..". "..note) or note~="" and note or nil
            end
            if point then
                goal.map=point.map or point.zone and ns.World.MapForZone(point.zone)
                if point.x and point.y then goal.x=point.x/100;goal.y=point.y/100 end
            end
            steps[#steps+1]={id=id,text=(phase=="accept" and "Pick up: " or phase=="turnin" and "Turn in: " or "Objectives: ")..q.title,goals={goal},questData=q,source=d.name}
        end end
        for _,q in ipairs(stage) do pending[q.id]=nil end
    end
    return steps
end
function J.DungeonSuggestion()
    local best,score
    for _,r in ipairs(J.Routes()) do if r.category=="Dungeon" then
        local matches=0;local index=J.QuestIndex(r)
        for _,q in ipairs(ns.State.quests) do if index[q.id] then matches=matches+1 end end
        local priority=matches+(r.classRecovery and 1000 or 0)
        if matches>0 and not (ns.char.declinedClassRoutes or {})[r.id] and (not best or priority>score or priority==score and r.id<best.id) then best,score=r,priority end
    end end
    return best,score
end
function J.PrepareDungeon(slug)
    if J.Speedrunning() then ns.Message("Choose Questing + dungeons to follow this dungeon guide.");return false end
    local route=J.Get("dungeon:"..slug);if not route then return false end
    -- J.Select preserves the current class/leveling context; do not replace it
    -- with a fresh recommendation before preparing a dungeon.
    return J.Select(route.id)
end
function J.Routes()
    if not ns.State.class or ns.State.class=="UNKNOWN" or not ns.State.classID then return {{id="live",name="Current quest log",live=true}} end
    local dungeonsEnabled=not J.Speedrunning() and (ns.char.dungeonJourney or {}).enabled==true
    local key=ns.State.class..":"..(ns.State.raceToken or ns.State.race)..":"..ns.State.faction..":"..ns.Rules.Cap()..":"..(ns.char.journeyGoal or "casual")..":"..(ns.char.journeyGuideSource or "toonkit")..":"..tostring(dungeonsEnabled)..":"..#ns.Data.routes
    if J.cacheKey==key then return J.routes end
    local routes={{id="live",name="Current quest log",live=true}}
    for _,route in ipairs(J.RouteSource()) do
            if (not route.requiresDungeon or dungeonsEnabled) and ns.Rules.RouteAvailable(route)
                and inList(route.classes,ns.State.class) and inList(route.races,ns.State.raceToken or ns.State.race) then routes[#routes+1]=route end
    end
    for _,d in ipairs(not J.Speedrunning() and ns.Data.dungeons or {}) do
        if ns.Rules.Available({min=d.min,classic=d.classic},false) then
            local id="dungeon:"..d.slug
            if ns.char and not ns.char.dungeonRouteSchema then
                ns.char.legacyDungeonRoutes=ns.char.legacyDungeonRoutes or {}
                if ns.char.routes[id] then ns.char.legacyDungeonRoutes[id]=ns.Copy(ns.char.routes[id]);ns.char.routes[id]=nil end
            end
            local steps=J.DungeonSteps(d)
            if #steps>0 then routes[#routes+1]={id=id,name=d.name.." quests",category="Dungeon",steps=steps,min=d.min,max=d.max,source="Current Forever authored quests; source-listed prerequisite stages"} end
        end
    end
    if ns.char then ns.char.dungeonRouteSchema=1 end
    J.cacheKey,J.routes=key,routes; return routes
end
function J.Get(id)
    for _,r in ipairs(J.Routes()) do if r.id==id then return r end end
end
function J.Finished(route)
    local saved=ns.char.routes[route.id] or {}; local entry=(ns.char.routeEntries or {})[route.id]
    for i=entry and entry.index or 1,#(route.steps or {}) do if not saved[i] then return false end end
    return #(route.steps or {})>0
end
function J.QuestIndex(route)
    if J.questIndexContext~=J.cacheKey then J.questIndices={}; J.questIndexContext=J.cacheKey end
    J.questIndices=J.questIndices or {}
    if J.questIndices[route.id] then return J.questIndices[route.id] end
    local quests={}
    for i,step in ipairs(route.steps or {}) do if J.Applies(step.only) then
        for _,g in ipairs(step.goals or {}) do if g.quest and J.Applies(g.only) then
            quests[g.quest]=quests[g.quest] or {}; quests[g.quest][#quests[g.quest]+1]={step=i,goal=g}
        end end
    end end
    J.questIndices[route.id]=quests; return quests
end
local function activeRouteWork(route,map,readiness)
    if #ns.State.quests==0 then return 0,0 end
    local quests=J.QuestIndex(route)
    local active,localWork,entry=0,0,nil
    for _,quest in ipairs(ns.State.quests) do
        local records=quests[quest.id]
        local ready=readiness[quest.id]
        if records and ready==nil then
            ready=quest.complete==true and J.ReadyToTurnIn(quest.id)
            readiness[quest.id]=ready
        end
        local matched,nearby=false,false
        for _,record in ipairs(records or {}) do
            local goal=record.goal
            local relevant=ready and goal.t=="turnin"
                or not ready and (goal.t=="complete" or goal.t=="kill" or goal.t=="collect" or goal.t=="interact")
            if relevant and not J.GoalDone(goal) and not J.OptionalDeferred(goal) and not J.Blocked(goal) then
                matched=true
                if map and (goal.map==map or not goal.map and route.zone==map) then nearby=true end
                entry=math.min(entry or record.step,record.step)
            end
        end
        if matched then active=active+(ready and 2 or 1) end
        if nearby then localWork=localWork+(ready and 2 or 1) end
    end
    return active,localWork,entry
end
function J.NextID(route)
    return route.next
end
function J.Campaign()
    local routes=J.Routes()
    if J.campaignSource==routes then return J.campaign,J.campaignIndex end
    local path,index={},{}
    for _,route in ipairs(routes) do
        if route.category=="Leveling" then
            path[#path+1]=route
        end
    end
    table.sort(path,function(a,b)
        if a.min~=b.min then return a.min<b.min end
        if a.catalogBatch~=b.catalogBatch then return not a.catalogBatch end
        return a.name<b.name or a.name==b.name and a.id<b.id
    end)
    for i,route in ipairs(path) do index[route.id]=i end
    J.campaignSource,J.campaign,J.campaignIndex=routes,path,index
    return path,index
end
function J.CampaignNext(route)
    local nextID=J.NextID(route)
    if not nextID then return end
    local seen={[route.id]=true}
    local following=J.Get(nextID)
    while following and following.category=="Leveling" and not seen[following.id] do
        if not J.Finished(following) and following.max>=ns.State.level then return following end
        seen[following.id]=true
        nextID=J.NextID(following)
        following=nextID and J.Get(nextID)
    end
end
function J.Recommended(excluded)
    local best,score; local level=math.min(ns.State.level,ns.Rules.Cap())
    local map=ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"))
    local readiness={}
    local completed={}
    for _,r in ipairs(J.Routes()) do if r~=excluded and r.category=="Leveling" and r.min<=level and not J.Finished(r) then
        local fits=level<=r.max
        local active,localWork=activeRouteWork(r,map,readiness)
        local s=(fits and 100000 or 0)-math.abs(level-r.min)*100
            +(map and r.zone==map and 1000 or 0)+math.min(active,8)*850+math.min(localWork,8)*650
            +(r.races and 80 or 0)
        if r.original and not r.catalogBatch and fits and (r.zone==map or active>0) then s=s+1800 end
        if (fits or active>0) and (not best or s>score or (s==score and r.id<best.id)) then
            local unfinished=active>0
            if not unfinished then
                for id,records in pairs(J.QuestIndex(r)) do
                    if completed[id]==nil then completed[id]=J.QuestDone(id) end
                    if not completed[id] then
                        if not r.catalogBatch or J.OnQuest(id) then unfinished=true;break end
                        for _,entry in ipairs(records) do
                            if entry.goal.t=="accept" and not J.Blocked(entry.goal) then unfinished=true;break end
                        end
                        if unfinished then break end
                    end
                end
            end
            if unfinished then best,score=r,s end
        end
    end end
    return best or (not excluded and J.Routes()[1] or nil)
end
function J.Join(route, catchUp)
    if not route or route.category~="Leveling" then return end
    ns.char.routeEntries=ns.char.routeEntries or {}
    local previous=ns.char.routeEntries[route.id]
    if previous then
        -- Repair only automatic join cursors, never explicit skips or manual reopens.
        if previous.pickupSchema==1 or not (previous.reason or ""):find("Joined from active quests",1,true) then return end
        previous.pickupSchema=1
        for i=1,previous.index-1 do if not J.Status(route,i) then
            for _,g in ipairs(route.steps[i].goals or {}) do
                if J.Applies(route.steps[i].only) and J.Applies(g.only) and g.t=="accept" and not g.optional
                    and (not g.minLevel or g.minLevel<=ns.State.level) and (not g.qlvl or g.qlvl+5>=ns.State.level)
                    and not J.GoalDone(g) then previous.index=i;return end
            end
        end end
        return
    end
    if next(ns.char.routes[route.id] or {}) then return end
    J.joinRevisions=J.joinRevisions or {}
    local context=(J.cacheKey or "")..":"..(ns.State.revision or 0)..":"..tostring(catchUp==true)
    if J.joinRevisions[route.id]==context then return end
    J.joinRevisions[route.id]=context
    -- An active quest is an evidence-backed join anchor, not proof of earlier completion.
    local entry; local quests=J.QuestIndex(route)
    if catchUp then
        local map=ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"))
        local _,_,anchor=activeRouteWork(route,map,{})
        entry=anchor
    else
        for _,q in ipairs(ns.State.quests) do
            for _,record in ipairs(quests[q.id] or {}) do
                if record.goal.t~="accept" and not J.GoalDone(record.goal) then entry=math.min(entry or record.step,record.step) end
            end
        end
    end
    if entry and entry>1 then
        -- Include known, unfinished prerequisite pickups before that anchor.
        for i=1,entry do for _,g in ipairs(route.steps[i].goals or {}) do if J.Applies(g.only) and g.pre then
            for _,id in pairs(g.pre) do if not J.QuestDone(id) and not J.OnQuest(id) then
                for _,record in ipairs(quests[id] or {}) do if record.goal.t=="accept" then entry=math.min(entry,record.step) end end
            end end
        end end end
        -- An active quest is not evidence that parallel pickups were accepted.
        -- Keep level-relevant mandatory pickups before the join anchor in view.
        if route.original or not catchUp then for i=1,entry do if J.Applies(route.steps[i].only) then
            for _,g in ipairs(route.steps[i].goals or {}) do
                if g.t=="accept" and J.Applies(g.only) and not g.optional
                    and (not g.minLevel or g.minLevel<=ns.State.level) and (not g.qlvl or g.qlvl+5>=ns.State.level)
                    and not J.GoalDone(g) then entry=math.min(entry,i) end
            end
        end end end
    end
    if entry then ns.char.routeEntries[route.id]={index=entry,level=ns.State.level,pickupSchema=1,reason="Joined from active quests; earlier steps remain unconfirmed"} end
end
function J.ReconcileRoute(route)
    if route.live then return end
    local saved=ns.char.routes[route.id] or {};ns.char.routes[route.id]=saved
    J.reconciled=J.reconciled or {};local revision=tostring(ns.State.revision or 0)..":"..tostring(ns.stateEpoch or 0)
    if J.reconciled[route.id]==revision then return end;J.reconciled[route.id]=revision
    if route.bankRevision and (ns.char.bankRouteRevisions or {})[route.id]~=route.bankRevision then
        ns.char.bankRouteRevisions=ns.char.bankRouteRevisions or {}
        ns.char.bankRouteArchive=ns.char.bankRouteArchive or {}
        ns.char.bankRouteArchive[route.id]={steps=ns.Copy(saved),revision=route.bankRevision}
        ns.char.goalProgress=ns.char.goalProgress or {}
        for index,ids in pairs(route.bankOriginalGoals) do
            if saved[index]=="skipped" then for _,id in ipairs(ids) do ns.char.goalProgress[id]=ns.char.goalProgress[id] or "skipped" end end
            saved[index]=nil
        end
        local entry=(ns.char.routeEntries or {})[route.id];if entry then entry.index=math.min(entry.index,5) end
        for _,undo in ipairs(ns.char.journeyUndo or {}) do if undo.route==route.id and undo.steps then
            for index in pairs(route.bankOriginalGoals) do undo.steps[index]=nil end
        end end
        ns.char.bankRouteRevisions[route.id]=route.bankRevision
    end
    if route.undeadRevision and (ns.char.undeadRouteRevisions or {})[route.id]~=route.undeadRevision then
        ns.char.undeadRouteRevisions=ns.char.undeadRouteRevisions or {};ns.char.undeadRouteArchive=ns.char.undeadRouteArchive or {}
        ns.char.undeadRouteArchive[route.id]={steps=ns.Copy(saved),revision=route.undeadRevision}
        ns.char.goalProgress=ns.char.goalProgress or {}
        for index,ids in pairs(route.undeadOriginalGoals) do
            if saved[index]=="skipped" then for _,id in ipairs(ids) do ns.char.goalProgress[id]=ns.char.goalProgress[id] or "skipped" end end
            saved[index]=nil
        end
        for _,undo in ipairs(ns.char.journeyUndo or {}) do if undo.route==route.id and undo.steps then for index in pairs(route.undeadOriginalGoals) do undo.steps[index]=nil end end end
        local entry=(ns.char.routeEntries or {})[route.id];if entry then entry.index=math.min(entry.index,3) end
        ns.char.undeadRouteRevisions[route.id]=route.undeadRevision
    end
    ns.char.classTripRevisions=ns.char.classTripRevisions or {}
    if route.tripRevision and ns.char.classTripRevisions[route.id]~=route.tripRevision then
        ns.char.classTripArchive=ns.char.classTripArchive or {}
        ns.char.classTripArchive[route.id]={steps=ns.Copy(saved),revision=route.tripRevision}
        ns.char.goalProgress=ns.char.goalProgress or {}
        local previousGoals=route.tripPreviousGoals and route.tripPreviousGoals[ns.char.classTripRevisions[route.id]] or route.tripOriginalGoals
        for index,ids in pairs(previousGoals) do
            if saved[index]=="skipped" then for _,id in ipairs(ids) do ns.char.goalProgress[id]=ns.char.goalProgress[id] or "skipped" end end
            saved[index]=nil
        end
        for _,undo in ipairs(ns.char.journeyUndo or {}) do if undo.route==route.id and undo.steps then
            for index in pairs(previousGoals) do undo.steps[index]=nil end
        end end
        local entry=(ns.char.routeEntries or {})[route.id];if entry then entry.index=math.min(entry.index,6) end
        ns.char.classTripRevisions[route.id]=route.tripRevision
    end
    ns.char.westfallRouteRevisions=ns.char.westfallRouteRevisions or {}
    if route.westfallRevision and ns.char.westfallRouteRevisions[route.id]~=route.westfallRevision then
        ns.char.westfallRouteArchive=ns.char.westfallRouteArchive or {}
        ns.char.westfallRouteArchive[route.id]={revision=route.westfallRevision,steps=ns.Copy(saved)}
        ns.char.goalProgress=ns.char.goalProgress or {}
        for index,ids in pairs(route.westfallOriginalGoals) do
            if saved[index]=="skipped" then for _,id in ipairs(ids) do
                if not ns.char.goalProgress[id] then ns.char.goalProgress[id]="skipped" end
            end end
            saved[index]=nil
        end
        for _,undo in ipairs(ns.char.journeyUndo or {}) do if undo.route==route.id and undo.steps then
            for index in pairs(route.westfallOriginalGoals) do undo.steps[index]=nil end
        end end
        local entry=(ns.char.routeEntries or {})[route.id];if entry then entry.index=math.min(entry.index,route.westfallStart) end
        ns.char.westfallRouteRevisions[route.id]=route.westfallRevision
    end
    ns.char.lakeRouteRevisions=ns.char.lakeRouteRevisions or {}
    if route.lakeRevision and ns.char.lakeRouteRevisions[route.id]~=route.lakeRevision then
        ns.char.lakeRouteArchive=ns.char.lakeRouteArchive or {}
        ns.char.lakeRouteArchive[route.id]={revision=route.lakeRevision,steps=ns.Copy(saved)}
        ns.char.goalProgress=ns.char.goalProgress or {}
        for index,ids in pairs(route.lakeOriginalGoals) do
            if saved[index]=="skipped" then
                for _,id in ipairs(ids) do if not ns.char.goalProgress[id] then ns.char.goalProgress[id]="skipped" end end
            end
            saved[index]=nil
        end
        for _,undo in ipairs(ns.char.journeyUndo or {}) do if undo.route==route.id and undo.steps then
            for index in pairs(route.lakeOriginalGoals) do undo.steps[index]=nil end
        end end
        local entry=(ns.char.routeEntries or {})[route.id]
        if entry then entry.index=math.min(entry.index,route.lakeStart) end
        ns.char.lakeRouteRevisions[route.id]=route.lakeRevision
    end
    ns.char.eastRouteRevisions=ns.char.eastRouteRevisions or {}
    if route.eastRevision and ns.char.eastRouteRevisions[route.id]~=route.eastRevision then
        ns.char.eastRouteArchive=ns.char.eastRouteArchive or {}
        ns.char.eastRouteArchive[route.id]={revision=route.eastRevision,steps=ns.Copy(saved)}
        for index,ids in pairs(route.eastOriginalGoals) do
            if saved[index]=="skipped" then
                ns.char.goalProgress=ns.char.goalProgress or {}
                for _,id in ipairs(ids) do if not ns.char.goalProgress[id] then ns.char.goalProgress[id]="skipped" end end
            end
            saved[index]=nil
        end
        for _,undo in ipairs(ns.char.journeyUndo or {}) do if undo.route==route.id and undo.steps then
            for index in pairs(route.eastOriginalGoals) do undo.steps[index]=nil end
        end end
        local entry=(ns.char.routeEntries or {})[route.id];if entry then entry.index=math.min(entry.index,route.eastStart) end
        ns.char.eastRouteRevisions[route.id]=route.eastRevision
    end
    ns.char.routeBatchRevisions=ns.char.routeBatchRevisions or {}
    if route.batchRevision and ns.char.routeBatchRevisions[route.id]~=route.batchRevision then
        ns.char.routeRevisionArchive=ns.char.routeRevisionArchive or {}
        ns.char.routeRevisionArchive[route.id]=ns.Copy(saved)
        for index,ids in pairs(route.batchOriginalGoals or {}) do
            if saved[index]=="skipped" then
                ns.char.goalProgress=ns.char.goalProgress or {}
                for _,id in ipairs(ids) do if not ns.char.goalProgress[id] then ns.char.goalProgress[id]="skipped" end end
            end
            saved[index]=nil
        end
        for _,record in ipairs(ns.char.journeyUndo or {}) do if record.route==route.id and record.steps then
            for index in pairs(route.batchOriginalGoals or {}) do record.steps[index]=nil end
        end end
        local entry=(ns.char.routeEntries or {})[route.id]
        if entry then entry.index=math.min(entry.index,route.batchStart) end
        ns.char.routeBatchRevisions[route.id]=route.batchRevision
    end
    if route.coverageRevision then
        ns.char.routeCoverageArchive=ns.char.routeCoverageArchive or {}
        local archives=ns.char.routeCoverageArchive[route.id] or {};ns.char.routeCoverageArchive[route.id]=archives
        local active=false
        for _,q in ipairs(ns.State.quests) do if route.coverageQuests[q.id] then active=true;break end end
        if active or ns.State.level<=route.max+5 then
            for index,step in ipairs(route.steps) do
                for _,goal in ipairs(step.goals or {}) do
                    if route.coverageQuests[goal.quest] and J.Applies(step.only) and J.Applies(goal.only) and not J.GoalDone(goal)
                        and (goal.t=="accept" and not J.Blocked(goal) or J.OnQuest(goal.quest)) then
                        local status=saved[index]
                        if status==true or status=="confirmed" or status=="optional omitted" then
                            archives[index]=archives[index] or {status=status,revision=route.coverageRevision};saved[index]=nil
                        end
                        -- Coverage recovery preserves explicit declines; normal live-quest
                        -- reconciliation below may still invalidate a false manual completion.
                        if not saved[index] then
                            local entry=(ns.char.routeEntries or {})[route.id]
                            if entry then entry.index=math.min(entry.index,index) end
                        end
                    end
                end
            end
        end
    end
    local active={};for _,quest in ipairs(ns.State.quests) do active[quest.id]=true end
    for index,step in ipairs(route.steps or {}) do
        if saved[index]~="skipped" then
            for _,goal in ipairs(step.goals or {}) do
                if goal.quest and active[goal.quest] and J.Applies(step.only) and J.Applies(goal.only) and not J.GoalDone(goal) then
                    local status=saved[index]
                    if status=="confirmed" or status==true or status=="manual" or status=="optional omitted" or status=="not applicable" or status=="source condition absent" and not J.OptionalDeferred(goal) then
                        ns.char.progressRecoveryArchive=ns.char.progressRecoveryArchive or {}
                        local archive=ns.char.progressRecoveryArchive[route.id] or {};ns.char.progressRecoveryArchive[route.id]=archive
                        archive[index]=archive[index] or {status=status,entry=(ns.char.routeEntries or {})[route.id] and ns.char.routeEntries[route.id].index}
                        saved[index]=nil
                    end
                    -- A join cursor is not evidence that an accepted, unfinished
                    -- earlier quest was completed. Explicit skips stay intact.
                    local entry=(ns.char.routeEntries or {})[route.id]
                    if not saved[index] and entry then entry.index=math.min(entry.index,index) end
                    break
                end
            end
        end
    end
end
function J.Selected()
    J.NormalizeReturns()
    J.UpgradeEvidence()
    local route=J.Get(ns.char.route)
    local catchUp
    if route and ns.State.level<(route.min or 1) then route=nil end
    if not ns.char.routeMode then ns.char.routeMode=route and not route.live and route.category~="Leveling" and "manual" or "auto" end
    if ns.char.routeMode=="auto" then
        local classRoute=J.ActiveClassRoute()
        if classRoute and not (ns.char.declinedClassRoutes or {})[classRoute.id] then
            if not ns.char.routeReturn then
                local base=route and route.category=="Leveling" and route or J.Recommended()
                if base and base.category=="Leveling" then ns.char.routeReturn={id=base.id,mode="auto"} end
            end
            ns.char.autoClassRoute=classRoute.id;ns.char.route=classRoute.id
            J.ReconcileRoute(classRoute)
            return classRoute
        elseif ns.char.autoClassRoute then
            route=ns.char.routeReturn and J.Get(ns.char.routeReturn.id) or nil
            ns.char.autoClassRoute=nil;ns.char.routeReturn=nil
        end
        local level=math.min(ns.State.level,ns.Rules.Cap())
        if not route or route.category~="Leveling" or level<route.min then
            route=J.Recommended()
            catchUp=true
        elseif J.Finished(route) then
            local following=J.CampaignNext(route)
            if following then
                if following.min<=level then route=following end
            else
                local recommended=J.Recommended(route)
                if recommended then route=recommended;catchUp=true
                elseif level<ns.Rules.Cap() then route=J.Get("live") end
            end
        elseif level>route.max then
            local quests=J.QuestIndex(route)
            local hasActiveQuest=false
            for _,quest in ipairs(ns.State.quests) do
                if quests[quest.id] then hasActiveQuest=true;break end
            end
            if not hasActiveQuest then
                local recommended=J.CampaignNext(route)
                if not recommended or recommended.min>level then recommended=J.Recommended(route) end
                if recommended then route=recommended;catchUp=true else route=J.Get("live") end
            end
        end
    elseif not route then ns.char.routeMode="auto";route=J.Recommended();catchUp=true end
    route=route or J.Routes()[1]
    if ns.char.route~=route.id then ns.char.route=route.id end
    J.ReconcileRoute(route)
    J.Join(route,catchUp)
    ns.char.optionalPickupRepair=ns.char.optionalPickupRepair or {}
    if not route.live and not ns.char.optionalPickupRepair[route.id] then
        ns.char.optionalPickupRepair[route.id]=true
        for index,step in ipairs(route.steps or {}) do
            if J.Status(route,index)=="optional omitted" and J.Applies(step.only) then
                for _,g in ipairs(step.goals or {}) do
                    if g.t=="accept" and g.optional and J.Applies(g.only) and not J.OptionalDeferred(g)
                        and (not g.qlvl or g.qlvl+5>=ns.State.level) and not J.GoalDone(g) then
                        ns.char.routes[route.id][index]=nil
                        local entry=(ns.char.routeEntries or {})[route.id]
                        if entry and entry.index>index then entry.index=index end
                    end
                end
            end
        end
    end
    return route
end
function J.Select(id,mode,catchUp)
    local route=J.Get(id)
    if not route then return false end
    if (route.min or 1)>ns.Rules.Cap() then ns.Message("This guide is retained for the 1-60 campaign. Active progression currently stops at level "..ns.Rules.Cap()..".");return false end
    if ns.State.level<(route.min or 1) then ns.Message("This route begins at level "..route.min..".");return false end
    local previous=J.Get(ns.char.route)
    if previous and previous.id~=route.id and previous.category=="Class" and route.category=="Dungeon" then
        J.PushReturn(previous.id,ns.char.routeMode or "manual")
    elseif mode~="auto" and previous and previous.category=="Leveling" and route.category~="Leveling" then
        ns.char.routeReturn={id=previous.id,mode=ns.char.routeMode or "auto"}
    end
    if route.category=="Dungeon" and not ns.char.routeReturn then local base=J.Recommended();if base then ns.char.routeReturn={id=base.id,mode="auto"} end end
    ns.char.journeyPaused=false;ns.char.route=id; ns.char.routeMode=mode or "manual"; J.Join(route,catchUp)
    J.Advance(); ns.Emit("STATE_CHANGED"); return true
end
function J.ActiveClassRoute()
    local best,score
    for _,r in ipairs(J.ClassRoutes()) do
        local matches=0;local index=J.QuestIndex(r)
        for _,q in ipairs(ns.State.quests) do
            for _,entry in ipairs(index[q.id] or {}) do
                local goal=entry.goal
                if goal.t~="accept" and not J.GoalDone(goal) and not J.Blocked(goal) then
                    matches=matches+1;break
                end
            end
        end
        if matches>0 and (not J.ClassPlanReady or J.ClassPlanReady(r)) and (not best or matches>score or matches==score and r.id<best.id) then best,score=r,matches end
    end
    return best
end
function J.Automatic(routeID)
    local route=type(routeID)=="string" and J.Get(routeID) or J.Recommended()
    if not route then return false end
    ns.char.declinedClassRoutes=nil
    ns.char.routeReturn=nil
    ns.char.autoClassRoute=nil
    return J.Select(route.id,"auto",true)
end
function J.Return()
    if ns.char.autoClassRoute and ns.char.autoClassRoute==ns.char.route then
        ns.char.declinedClassRoutes=ns.char.declinedClassRoutes or {};ns.char.declinedClassRoutes[ns.char.autoClassRoute]=true;ns.char.autoClassRoute=nil
    end
    local saved=ns.char.routeReturn; ns.char.routeReturn=saved and saved.parent or nil
    local route=saved and J.Get(saved.id)
    if route and ns.State.level>=(route.min or 1) and ns.State.level<=(route.max or ns.Rules.CampaignCap()) then return J.Select(route.id,saved.mode) end
    if route and route.category=="Leveling" and saved.mode=="auto" then
        local following=J.CampaignNext(route)
        if following and following.min<=ns.State.level then return J.Select(following.id,"auto",true) end
    end
    return J.Select(J.Recommended().id,"auto")
end
function J.ClassRoutes()
    local choices={}
    for _,route in ipairs(J.Routes()) do
        if route.category=="Class" then
            local active=false;local index=J.QuestIndex(route)
            for _,q in ipairs(ns.State.quests or {}) do if index[q.id] then active=true;break end end
            -- A suggested source level range is not an expiry date for an active class quest.
            if active or ns.State.level>=route.min and route.min<=ns.Rules.Cap() then
                J.ReconcileRoute(route)
                local final=route.finalQuest
                if not final then for _,step in ipairs(route.steps or {}) do for _,g in ipairs(step.goals or {}) do
                    if g.t=="turnin" and g.quest and J.Applies(g.only) then final=g.quest end
                end end end
                if not J.Finished(route) and (not final or not J.QuestDone(final)) then choices[#choices+1]=route end
            end
        end
    end
    table.sort(choices,function(a,b)
        if a.classRecovery~=b.classRecovery then return a.classRecovery==true end
        if a.min~=b.min then return a.min>b.min end;return a.id<b.id
    end)
    return choices
end
-- Visible pickup opportunity, including unaccepted starting-zone class chains.
function J.ClassOpportunity()
    for _,route in ipairs(J.ClassRoutes()) do if not (ns.char.declinedClassRoutes or {})[route.id] then
        for _,step in ipairs(route.steps or {}) do if J.Applies(step.only) then for _,g in ipairs(step.goals or {}) do
            if g.t=="accept" and J.Applies(g.only) and not J.GoalDone(g) and not J.OptionalDeferred(g) and not J.Blocked(g) then return route,g end
        end end end
    end end
end
function J.ClassRoute() return J.ClassRoutes()[1] end
function J.OnQuest(id)
    if J.questLookupSource~=ns.State.quests then
        J.questLookup={};J.questLookupSource=ns.State.quests
        for _,q in ipairs(ns.State.quests or {}) do J.questLookup[q.id]=q end
    end
    local quest=J.questLookup[id];return quest~=nil or ns.Safe(ns.API.Call("C_QuestLog","IsOnQuest",id),false)==true,quest
end
-- Turn-in advice requires native readiness, not the authored step index or a
-- previous manual confirmation. Explicit unfinished objectives win over a
-- contradictory/stale complete flag.
function J.ReadyToTurnIn(id)
    local on,quest=J.OnQuest(id);if not on then return false end
    local complete=ns.Safe(ns.API.Call("C_QuestLog","IsComplete",id))
    if complete==nil then complete=quest and quest.complete end
    if complete~=true then return false end
    local objectives=ns.API.Call("C_QuestLog","GetQuestObjectives",id) or quest and quest.objectives or {}
    for _,objective in ipairs(objectives) do
        if ns.Safe(objective.finished)==false then return false end
        local have,need=ns.Safe(objective.numFulfilled),ns.Safe(objective.numRequired)
        if type(have)=="number" and type(need)=="number" and need>0 and have<need then return false end
    end
    return true
end
function J.QuestsOutsideRoute(route)
    if not route or route.live then return {} end
    local contexts={route};local missing={}
    if route.planSlug then
        local saved=ns.char.routeReturn;local seen={[route.id]=true};local depth=0
        while saved and depth<8 do
            local parent=not seen[saved.id] and J.Get(saved.id)
            if parent then contexts[#contexts+1]=parent;seen[parent.id]=true end
            saved=saved.parent;depth=depth+1
        end
    end
    for _,quest in ipairs(ns.State.quests) do
        local covered=false
        for _,context in ipairs(contexts) do
            local entry=(ns.char.routeEntries or {})[context.id]
            for _,record in ipairs(J.QuestIndex(context)[quest.id] or {}) do
                if record.goal.t~="accept" and record.step>=(entry and entry.index or 1)
                    and not J.Status(context,record.step) and not J.GoalDone(record.goal) then covered=true;break end
            end
            if covered then break end
        end
        if not covered and not J.QuestDone(quest.id) then missing[#missing+1]=quest end
    end
    return missing
end
function J.MissingPrerequisites(g)
    local meta=g.quest and ns.Data.questSupport and ns.Data.questSupport.meta[g.quest]
    local all,any=g.pre or {},{}
    if meta and (#(meta.preAll or {})>0 or #(meta.pre or {})>0) then all=meta.preAll or {};any=meta.pre or {} end
    local missing={}
    for _,id in ipairs(all) do if not J.QuestDone(id) then missing[#missing+1]=id end end
    if #any>0 then
        local satisfied=false;for _,id in ipairs(any) do if J.QuestDone(id) then satisfied=true;break end end
        if not satisfied then for _,id in ipairs(any) do missing[#missing+1]=id end end
    end
    return missing
end
function J.OptionalDeferred(g)
    if not g.optional then return false end
    if g.quest and (J.OnQuest(g.quest) or J.QuestDone(g.quest)) or g.item and (ns.State.owned[g.item] or 0)>0 then return false end
    if g.t=="accept" then
        for item,count in pairs(g.optionalSupplies or {}) do if (ns.State.owned[item] or 0)<count then return true end end
        if g.minLevel and g.minLevel>ns.State.level then return true end
        if g.item and (ns.State.owned[g.item] or 0)==0 then return true end
        if #J.MissingPrerequisites(g)>0 then return true end
        -- A source-optional pickup is a player choice, not an automatic omission.
        return false
    end
    return true
end
function J.Blocked(g)
    if g.routeBlockReason then return g.routeBlockReason end
    if g.t=="turnin" and g.quest and J.OnQuest(g.quest) and not J.QuestDone(g.quest) and not J.ReadyToTurnIn(g.quest) then
        return "Finish the remaining native quest objectives before this turn-in. If quest data is still loading, wait for the quest log to update."
    end
    if g.batchAfterQuest and not J.QuestDone(g.batchAfterQuest) then
        return "Finish Sven's Revenge at the mound by the old stump before this grouped skeleton pass. This objective remains unfinished."
    end
    if g.batchActiveQuest and not J.OnQuest(g.batchActiveQuest) and not J.QuestDone(g.batchActiveQuest) then
        return "Prepare the shared Duskwood pass first: accept "..(ns.Data.questSupport.meta[g.batchActiveQuest] and ns.Data.questSupport.meta[g.batchActiveQuest].name or "quest #"..g.batchActiveQuest)..". This objective remains unfinished."
    end
    if ns.State.class=="PALADIN" and ns.State.level<24 and (g.quest==1442 or g.item==6995 or g.item==7083) then
        return "Paladin BFD / Kor Gem trip is planned for level 24. Continue Duskwood/Wetlands leveling first."
    end
    if g.routeMinLevel and ns.State.level<g.routeMinLevel then return "Planned for level "..g.routeMinLevel.." or later, after the Eastvale and Lost Guards pass. Elite encounters may still require a group." end
    if g.minLevel and g.minLevel>ns.Rules.Cap() or g.t=="level" and (g.level or 60)>ns.Rules.Cap() then return "Beyond the active level cap" end
    if g.minLevel and g.minLevel>ns.State.level then return "Requires level "..g.minLevel end
    if g.t=="accept" then
        if g.catalogQuest and not J.OnQuest(g.quest) then
            local record=ns.Data.questSupport.meta[g.quest]
            if record.parent and not J.OnQuest(record.parent) then return "Accept the parent quest before this pickup" end
            for _,id in ipairs(record.excl or {}) do
                if J.OnQuest(id) or J.QuestDone(id) then return "An alternative quest branch was selected" end
            end
        end
        local missing=J.MissingPrerequisites(g)
        if missing[1] then
            local meta=ns.Data.questSupport and ns.Data.questSupport.meta[missing[1]]
            return "Complete "..(meta and meta.name or "prerequisite quest #"..missing[1]).." before this pickup"
        end
    end
    if g.t=="collect" and J.ItemSourceConflict(g) then return "Source item identity conflicts with the client. Check the native quest log; this action will not advance or navigate automatically." end
    if g.t=="collect" and g.quest and g.item and not J.PreparationCount(g) and not J.QuestDone(g.quest) then
        if not J.OnQuest(g.quest) then return "Accept the quest before following this collection objective" end
        if not J.ItemObjective(g) then return "Live quest item objective is not matched yet. Check the native quest log; no numbered counter will be guessed." end
    end
    if g.quest and not g.direct and (g.t=="turnin" or g.t=="complete" or g.t=="kill" or g.t=="interact")
        and not J.OnQuest(g.quest) and not J.QuestDone(g.quest) then return "Quest is not in your log; check its pickup instructions" end
end
function J.Prerequisite(g)
    if not g or not g.quest or g.direct then return end
    local ids=g.t=="accept" and J.MissingPrerequisites(g) or (not J.OnQuest(g.quest) and not J.QuestDone(g.quest) and {g.quest})
    if not ids or not ids[1] then return end
    local routes=J.Routes()
    local current=J.Get(ns.char.route)
    local map=ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"))
    local seen,budget={},32
    local function actionFor(id,depth)
        if seen[id] or depth>8 or budget==0 or J.QuestDone(id) then return end
        seen[id]=true;budget=budget-1
        local on=J.OnQuest(id)
        local ready=on and J.ReadyToTurnIn(id)
        local best,bestScore,needs
        for _,route in ipairs(routes) do
            if not route.planSlug and (route.min or 1)<=ns.State.level then
                for _,entry in ipairs(J.QuestIndex(route)[id] or {}) do
                    local goal=entry.goal
                    local matches=not on and goal.t=="accept" or ready and goal.t=="turnin"
                        or on and not ready and (goal.t=="complete" or goal.t=="kill" or goal.t=="collect" or goal.t=="interact")
                    if matches and not J.GoalDone(goal) and not J.OptionalDeferred(goal)
                        and J.Status(route,entry.step)~="skipped" then
                        if not J.Blocked(goal) then
                            local score=(route==current and 4 or 0)+(goal.map and goal.x and goal.y and 2 or 0)+(map and goal.map==map and 4 or 0)
                            if not best or score>bestScore then best={route,entry.step,goal};bestScore=score end
                        elseif goal.t=="accept" and not needs then
                            local missing=J.MissingPrerequisites(goal)
                            if #missing>0 then needs=missing end
                        end
                    end
                end
            end
        end
        if best then return best end
        if not on and ns.QuestSupplies and ns.QuestSupplies.Eligible(id,ns.State.level) then
            local facts=(ns.Data.dungeonPreparation or {})[id]
            local point
            for _,candidate in ipairs(facts and facts.pickup or {}) do
                if (candidate.kind==1 or candidate.kind==2) and candidate.map and candidate.x and candidate.y then
                    point=point or candidate
                    if candidate.map==map then point=candidate;break end
                end
            end
            if point then
                return {current,0,{id="pickup-reference:"..id,t="accept",quest=id,title=ns.QuestSupplies.Name(id),
                    map=point.map,x=point.x,y=point.y,note="Source-listed pickup to prepare the current guide action."}}
            end
        end
        if not on and not needs then needs=J.MissingPrerequisites({quest=id}) end
        for _,idNeeded in ipairs(needs or {}) do
            local prior=actionFor(idNeeded,depth+1);if prior then return prior end
        end
    end
    for _,id in ipairs(ids) do
        local action=actionFor(id,1)
        if action then return action[1],action[2],action[3] end
    end
end
function J.Action()
    local step,index=J.Current(); local first
    local focus=J.focusGoal
    if focus and focus.route==ns.char.route and focus.index==index then
        for _,g in ipairs(step and step.goals or {}) do
            if g.id==focus.id and J.Applies(g.only) and not J.OptionalDeferred(g) and not J.GoalDone(g) and not J.Blocked(g) then
                if ns.ActionEvidence then ns.ActionEvidence.Watch(g) end;return g,step,index
            end
        end
        J.focusGoal=nil
    end
    for _,g in ipairs(step and step.goals or {}) do
        if J.Applies(g.only) and not J.GoalDone(g) and not J.OptionalDeferred(g) then
            first=first or g
            if not J.Blocked(g) then if ns.ActionEvidence then ns.ActionEvidence.Watch(g) end;return g,step,index end
        end
    end
    if not first and step and step.quest and not step.goals and not J.QuestDone(step.quest) then first=J.QuestAction(step) end
    if ns.ActionEvidence then ns.ActionEvidence.Watch(first) end
    return first,step,index
end
function J.QuestAction(step)
    local on,quest=J.OnQuest(step.quest)
    local kind=not on and "accept" or quest and quest.complete and "turnin" or "complete"
    local goal={id="quest-route:"..step.quest..":"..kind,t=kind,quest=step.quest,title=step.text,note=step.detail}
    if kind=="accept" and step.prereq then goal.pre={step.prereq} end
    if kind=="complete" and quest then for i,o in ipairs(quest.objectives or {}) do if not ns.Safe(o.finished,false) then
        goal.oi=i;goal.id=goal.id..":objective:"..i;goal.title=ns.Safe(o.text,step.text);goal.nativeText=true;break
    end end end
    local point=kind=="accept" and step.pickup or kind=="turnin" and step.turnin
    if kind~="complete" then
        goal.npcName=point and point.npcName
        goal.note=point and point.place
    end
    if point and (point.map or point.zone) and point.x and point.y then
        goal.map=point.map or ns.World.MapForZone(point.zone);goal.x=point.x/100;goal.y=point.y/100
    end
    return goal
end
-- Objective order is not item identity. The native client can reorder the live list.
local function objectiveName(text)
    if type(text)~="string" then return "" end
    text=text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|H.-|h(.-)|h","%1")
    return text:lower():gsub("%d+%s*/%s*%d+",""):gsub("[%p]"," "):gsub("%s+"," "):match("^%s*(.-)%s*$")
end
local function includesName(text,name)
    if name=="" then return false end
    return (" "..text.." "):find(" "..name.." ",1,true)~=nil or (" "..text.." "):find(" "..name.."s ",1,true)~=nil
end
function J.ItemSourceConflict(g)
    if not g or not g.quest or not g.item then return false end
    local item=ns.API.Item(g.item);local native=objectiveName(item and item.name)
    if native=="" then return false end
    if J.sourceItemNamesFor~=J.RouteSource() then
        J.sourceItemNamesFor=J.RouteSource();J.sourceItemNames={}
        for _,route in ipairs(J.RouteSource() or {}) do for _,step in ipairs(route.steps or {}) do for _,goal in ipairs(step.goals or {}) do
            if goal.t=="collect" and goal.quest and goal.item and goal.itemName then
                local names=J.sourceItemNames[goal.quest] or {};J.sourceItemNames[goal.quest]=names
                names[goal.item]=names[goal.item] or {};names[goal.item][objectiveName(goal.itemName)]=true
            end
        end end end
    end
    local names=J.sourceItemNames[g.quest] or {}
    if names[g.item] and names[g.item][native] then return false end
    for id,aliases in pairs(names) do if id~=g.item and aliases[native] then return true end end
    return false
end
function J.PreparationCount(g)
    local costs=ns.Data.questSupport and ns.Data.questSupport.costItems
    local count=costs and costs[g.quest] and costs[g.quest][g.item]
    return type(count)=="number" and count>0 and count or nil
end
function J.ItemObjective(g)
    if not g or not g.quest or not g.item or not J.OnQuest(g.quest) then return end
    local objectives=ns.API.Call("C_QuestLog","GetQuestObjectives",g.quest)
    if type(objectives)~="table" then return end
    local info=ns.API.Item(g.item)
    local name=objectiveName(info and info.name or g.itemName)
    if name=="" then return end
    local found,index
    for i,o in ipairs(objectives) do
        local text=ns.Safe(o.text);local normalized=objectiveName(text)
        local linked=type(text)=="string" and tonumber(text:match("|Hitem:(%d+)")) or nil
        local objectName=objectiveName(g.fromKind=="object" and g.from or g.objName)
        local matches=linked and linked==g.item or not linked and (includesName(normalized,name) or includesName(normalized,objectName))
        if matches and not linked then
            -- Do not bind a short name to a different, longer item name.
            for item in pairs(ns.Data.questSupport and ns.Data.questSupport.quests[g.quest] and ns.Data.questSupport.quests[g.quest].items or {}) do
                if item~=g.item then
                    local other=ns.API.Item(item);local otherName=objectiveName(other and other.name)
                    if otherName==name or includesName(normalized,otherName) and (#otherName>#name or not includesName(name,otherName)) then matches=false;break end
                end
            end
        end
        if matches then if found then return nil,"ambiguous" end;found,index=o,i end
    end
    return found,index
end
function J.ItemName(g)
    local item=g.item and ns.API.Item(g.item)
    return item and item.name or g.itemName or (g.item and "Item #"..g.item)
end
function J.Progress(g)
    if not g or g.nativeText then return end
    if g.t=="collect" and J.ItemSourceConflict(g) then return "Item identity conflict; check the native quest log" end
    local preparation=g.t=="collect" and g.item and J.PreparationCount(g)
    if preparation then return math.min(ns.State.owned[g.item] or 0,preparation).." / "..preparation.." preparation supplies" end
    if g.quest then
        local objectives=ns.API.Call("C_QuestLog","GetQuestObjectives",g.quest) or {}
        local o=g.t=="collect" and g.item and J.ItemObjective(g) or not (g.t=="collect" and g.item) and g.oi and objectives[g.oi]
        if not o and g.t=="complete" then for _,objective in ipairs(objectives) do if not ns.Safe(objective.finished,false) then o=objective; break end end end
        if o then
            if g.dungeon and g.t=="complete" and ns.Safe(o.text) then return ns.Safe(o.text) end
            local have,need=ns.Safe(o.numFulfilled),ns.Safe(o.numRequired)
            if have and need and need>0 then return have.." / "..need end
            return ns.Safe(o.text)
        end
        if g.t=="collect" and g.item then return "Waiting for matching item objective" end
    end
    if g.item then local count=J.CollectionRequired(g);if count then return math.min(ns.State.owned[g.item] or 0,count).." / "..count end end
end
function J.Status(route,index) return (ns.char.routes[route.id] or {})[index] end
function J.Steps()
    local route=J.Selected()
    if not route.live then return route.steps or {} end
    local steps={}
    local dungeonQuests={}
    if J.Speedrunning() then
        for _,dungeon in ipairs(ns.Data.dungeons or {}) do
            for _,quest in ipairs(dungeon) do dungeonQuests[quest.id]=true end
        end
    end
    for _,q in ipairs(ns.State.quests) do if not dungeonQuests[q.id] and (not J.Speedrunning() or not ns.Data.InstanceQuest(q.id)) then
        local goals={}
        if q.complete then goals[1]={id="live:"..q.id..":turnin",t="turnin",live=true,quest=q.id,title=q.title}
        else
            for oi,o in ipairs(q.objectives or {}) do
                local goal={id="live:"..q.id..":objective:"..oi,t="complete",live=true,quest=q.id,oi=oi,title=ns.Safe(o.text,"Complete quest objective"),nativeText=true}
                -- Forever quest 2882 / item 9275 (client quest data and Forever NPC drop references).
                if q.id==2882 and goal.title:lower():find("key",1,true) then
                    goal.title="Loot Cuergo's Key from the treasure pirates"
                end
                goals[#goals+1]=goal
            end
            if #goals==0 then goals[1]={id="live:"..q.id..":complete",t="complete",live=true,quest=q.id,title=q.title} end
        end
        steps[#steps+1]={quest=q.id,text=q.title,detail=q.complete and "Return for your reward." or nil,goals=goals,live=true,map=q.map,level=q.level}
    end end
    return steps
end
function J.QuestDone(id)
    if not id or J.OnQuest(id) then return false end
    return ns.char.turnedIn[id]==true or ns.API.QuestDone(id)==true
end
-- Exact source item -> quest-start links, not guessed book names or quest IDs.
function J.ItemStartedQuest(item)
    if J.itemStartSource~=J.RouteSource() then
        J.itemStartSource=J.RouteSource();J.itemStartQuests={}
        for _,route in ipairs(J.RouteSource() or {}) do for _,step in ipairs(route.steps or {}) do
            for _,goal in ipairs(step.goals or {}) do if goal.t=="accept" and goal.item and goal.quest then
                J.itemStartQuests[goal.item]=J.itemStartQuests[goal.item] or {}
                J.itemStartQuests[goal.item][goal.quest]=true
            end end
        end end
    end
    for quest in pairs(J.itemStartQuests[item] or {}) do if J.OnQuest(quest) or J.QuestDone(quest) then return true end end
    return false
end
function J.CollectionRequired(g)
    if g.t=="collect" and J.ItemSourceConflict(g) then return end
    local preparation=g.t=="collect" and g.item and J.PreparationCount(g)
    if preparation then return preparation end
    if g.quest and g.item and g.t=="collect" and J.OnQuest(g.quest) then
        local objective=J.ItemObjective(g);local count=objective and ns.Safe(objective.numRequired)
        return type(count)=="number" and count>0 and count or nil
    end
    if g.quest and g.oi and J.OnQuest(g.quest) then
        local objectives=ns.API.Call("C_QuestLog","GetQuestObjectives",g.quest)
        local objective=type(objectives)=="table" and objectives[g.oi]
        local count=objective and ns.Safe(objective.numRequired)
        if type(count)=="number" and count>0 then return count end
    end
    if type(g.count)=="number" and g.count>0 then return g.count end
    if not g.quest then return 1 end
end
function J.UpgradeEvidence()
    if ns.char.collectionEvidenceSchema==2 then return end
    ns.char.legacyCollectionEvidence=ns.char.legacyCollectionEvidence or {}
    for id,value in pairs(ns.char.goalProgress or {}) do
        if value=="observed-item" or value=="item-started-quest" then
            ns.char.legacyCollectionEvidence[id]=value;ns.char.goalProgress[id]=nil
        end
    end
    ns.char.collectionEvidenceSchema=2
end
function J.RecordCollection(g,reason)
    if g.id then ns.char.goalProgress=ns.char.goalProgress or {};ns.char.goalProgress[g.id]=reason end
    return true,reason
end
function J.GoalDone(g)
    if not J.Applies(g.only) then return true,"not applicable" end
    if g.sourceGoal and (ns.char.goalProgress or {})[g.sourceGoal]=="skipped" then return true,"skipped" end
    if g.id and ns.char.goalProgress and ns.char.goalProgress[g.id] then
        local evidence=ns.char.goalProgress[g.id]
        local nativeQuest=g.quest and (g.t=="accept" or g.t=="turnin" or g.t=="complete" or g.t=="collect" or g.t=="kill" or g.t=="interact" or g.oi)
        if nativeQuest then
            if evidence=="skipped" then return true,evidence end
        elseif evidence~="observed-item" and evidence~="item-started-quest" then return true,evidence end
    end
    if g.minLevel and g.minLevel>ns.Rules.Cap() then return false,"Above active content cap" end
    if g.quest and not (g.live and J.OnQuest(g.quest)) and J.QuestDone(g.quest) then return true end
    if ns.ActionEvidence then local done,reason=ns.ActionEvidence.Done(g);if done then return true,reason end end
    if g.t=="getfp" and ns.Travel then
        if g.node and ns.Travel.Known(g.node)==true or not g.node and ns.Travel.KnownLocation(g) then return true,"native-flight-path" end
    end
    if g.quest and (g.t=="kill" or g.t=="collect" or g.t=="complete" or g.t=="interact") and J.ReadyToTurnIn(g.quest) then return true,"native-quest-ready" end
    if g.t=="collect" and g.item then
        if g.quest and J.ItemSourceConflict(g) then return false,"source-item-identity-conflict" end
        -- Live quest objective evidence wins over inventory, source defaults and
        -- old completion caches. One carried item never proves an unknown count.
        if g.quest then
            local preparation=J.PreparationCount(g)
            if preparation then return (ns.State.owned[g.item] or 0)>=preparation,"current-preparation-supplies" end
            if not J.OnQuest(g.quest) then return false,"Accept the quest first" end
            local objective=J.ItemObjective(g)
            return objective and ns.Safe(objective.finished,false)==true or false,"matched-native-item-objective"
        end
        -- Only exact item-start links may survive item consumption. Other
        -- supplies are rechecked from current inventory, not latched globally.
        if (g.count or 1)==1 and J.ItemStartedQuest(g.item) then return J.RecordCollection(g,"item-started-quest-v2") end
        local count=J.CollectionRequired(g)
        if count and (ns.State.owned[g.item] or 0)>=count then
            if (g.count or 1)==1 and J.itemStartQuests and J.itemStartQuests[g.item] then return J.RecordCollection(g,"quest-starter-collected-v2") end
            return true,"current-inventory"
        end
        return false
    end
    if g.t=="accept" then return J.OnQuest(g.quest)
    elseif g.t=="turnin" then return false
    elseif g.t=="level" then return ns.State.level>=(g.level or 60)
    elseif g.quest and g.oi then
        local objectives=ns.API.Call("C_QuestLog","GetQuestObjectives",g.quest)
        if objectives and objectives[g.oi] then return ns.Safe(objectives[g.oi].finished,false)==true,"native-objective" end
    elseif g.t=="complete" then return ns.Safe(ns.API.Call("C_QuestLog","IsComplete",g.quest),false)==true,"native-quest-objectives" end
    if g.t=="buy" and g.item then local count=J.CollectionRequired(g);return count~=nil and (ns.State.owned[g.item] or 0)>=count or false end
    if g.t=="goto" and g.map and g.x and g.y then
        local map,x,y=ns.API.Position()
        return map==g.map and x and y and (x-g.x)^2+(y-g.y)^2<.000009 or false
    end
    if g.t=="learn" and g.spell then return ns.Safe(ns.API.Call("C_SpellBook","IsSpellKnown",g.spell),false) end
    return false,"Confirm this action manually"
end
function J.GoalText(g)
    if g.nativeText then return g.title or "Complete the quest objective" end
    local kind=g.t
    local names={accept=g.title,turnin=g.title,kill=g.target or g.npcName or g.title,collect=J.ItemName(g) or g.objName or g.title,
        buy=g.itemName or g.title,use=g.itemName or g.title,interact=g.objName or g.target or g.title,talk=g.npcName or g.title,
        learn=g.spellName or g.title,complete=g.title}
    if kind=="note" then return g.text or g.note or "Read the route instructions" end
    if kind=="goto" and g.text then return g.text end
    if kind=="train" then return "Train your class abilities" end
    if kind=="vendor" then return "Vendor stop: sell unneeded items and check repairs" end
    local verbs={accept="Accept",turnin="Turn in",kill="Defeat",collect="Collect",complete="Complete",goto="Travel to",level="Reach level",interact="Interact with",use="Use",learn="Learn",buy="Buy",talk="Speak to",getfp="Learn the flight path at",fly="Fly to",hearth="Use your hearthstone to return to",sethome="Make this inn your home:"}
    local name=kind=="level" and tostring(g.level or 60) or names[kind] or g.location or g.text or ""
    local text=(verbs[kind] or kind)..(name~="" and " "..name or "")
    local count=kind=="collect" and J.CollectionRequired(g) or g.count
    if count and count>1 and (kind=="kill" or kind=="collect" or kind=="buy") then text=text.." x"..count end
    return text
end
function J.StepDone(step)
    if step.superseded then return true,"rebatched" end
    if not J.Applies(step.only) then return true,"not applicable" end
    if step.quest then return J.QuestDone(step.quest) end
    if not step.goals or #step.goals==0 then return false end
    local manual,deferred=false,false
    for _,g in ipairs(step.goals) do if J.Applies(g.only) then
        local done,reason=J.GoalDone(g)
        if not done then if J.OptionalDeferred(g) then deferred=true else return false end end
        if reason=="manual" or reason=="skipped" then manual=true end
    end end
    return true,manual and "manual" or deferred and "optional omitted" or nil
end
function J.MarkGoal(g,status)
    if not g.id then return end
    if status=="manual" and J.AutomaticGoal and J.AutomaticGoal(g) and not J.GoalDone(g) then
        ns.Message("This action waits for native completion. Finish it in game, or use Skip to leave it for later.");return false
    end
    if status and J.Remember then J.Remember("goal",g.id,J.GoalText(g)) end
    ns.char.goalProgress=ns.char.goalProgress or {}; ns.char.goalProgress[g.id]=status
    -- Re-open the current segment from this goal if a manual confirmation is undone.
    if not status then
        local route=J.Selected(); ns.char.routes[route.id]=ns.char.routes[route.id] or {}
        for index,step in ipairs(route.steps or {}) do for _,goal in ipairs(step.goals or {}) do
            if goal.id==g.id then
                ns.char.routes[route.id][index]=nil
                local entry=(ns.char.routeEntries or {})[route.id]
                if entry and index<entry.index then entry.index=index; entry.reason="Reopened manually; earlier steps remain unconfirmed" end
            end
        end end
    end
    J.Advance(); ns.Emit("STATE_CHANGED")
end
function J.Current()
    local route=J.Selected()
    local entry=(ns.char.routeEntries or {})[route.id]
    for index,step in ipairs(J.Steps()) do
        local status=not route.live and J.Status(route,index)
        local hidden=route.live and ns.char.liveHidden and ns.char.liveHidden[step.quest]
        if index>=(entry and entry.index or 1) and J.Applies(step.only) and not status and not hidden then return step,index end
    end
end
function J.Mark(index,status)
    local route=J.Selected()
    if status=="manual" or status=="confirmed" or status==true then
        local step=J.Steps()[index]
        for _,g in ipairs(step and step.goals or {}) do
            if J.AutomaticGoal and J.AutomaticGoal(g) and J.Applies(g.only) and not J.OptionalDeferred(g) and not J.GoalDone(g) then
                ns.Message("This step still has an unfinished native action. Finish it in game, or explicitly skip the action.");return false
            end
        end
    end
    ns.char.routes[route.id]=ns.char.routes[route.id] or {}
    if status and J.Remember then J.Remember("step",index,(J.Steps()[index] or {}).text) end
    if route.live then
        local step=J.Steps()[index]; if step then ns.char.liveHidden=ns.char.liveHidden or {}; ns.char.liveHidden[step.quest]=status end
    else ns.char.routes[route.id][index]=status end
    J.Advance(); ns.Emit("STATE_CHANGED")
end
local function advanceRoute()
    local visited={}
    while true do
        local route=J.Selected()
        if route.live or route.instanceHold or (route.min or 1)>ns.Rules.Cap() or visited[route.id] then break end
        visited[route.id]=true
        -- Preserve consumed quest starters only. Never pre-complete future
        -- quest objectives from unrelated inventory items.
        J.starterCandidates=J.starterCandidates or setmetatable({},{__mode="k"})
        local candidates=J.starterCandidates[route]
        if not candidates then
            candidates={};J.starterCandidates[route]=candidates
            for _,step in ipairs(route.steps or {}) do for _,goal in ipairs(step.goals or {}) do
                if goal.t=="collect" and goal.item and not goal.quest then candidates[#candidates+1]={step=step,goal=goal} end
            end end
        end
        for _,candidate in ipairs(candidates) do
            if J.Applies(candidate.step.only) and J.Applies(candidate.goal.only) then J.GoalDone(candidate.goal) end
        end
        ns.char.routes[route.id]=ns.char.routes[route.id] or {}; local saved=ns.char.routes[route.id]
        local entry=(ns.char.routeEntries or {})[route.id]
        for i=entry and entry.index or 1,#(route.steps or {}) do
            if not saved[i] then
                local done,reason=J.StepDone(route.steps[i])
                if done then saved[i]=reason or "confirmed" else break end
            end
        end
        local finished=J.Finished(route)
        if finished and ns.char.routeReturn and route.category~="Leveling" then
            local savedReturn=ns.char.routeReturn; ns.char.routeReturn=savedReturn.parent
            local previous=J.Get(savedReturn.id)
            if previous and previous.category=="Leveling" and savedReturn.mode=="auto" and ns.State.level>previous.max then
                local following=J.CampaignNext(previous)
                if following and following.min<=ns.State.level then previous=following end
            end
            if previous and (previous.min or 1)<=ns.State.level and (previous.max or ns.Rules.CampaignCap())>=ns.State.level then ns.char.route=previous.id; ns.char.routeMode=savedReturn.mode
            else ns.char.routeMode="auto"; ns.char.route=J.Recommended().id end
        elseif ns.char.routeMode~="auto" or not finished or route.category~="Leveling" then break end
    end
end
function J.Advance()
    if not ns.db.settings.autoAdvance or ns.char.journeyPaused or J.advancing then return end
    J.advancing=true
    local ok,err=pcall(advanceRoute)
    J.advancing=false
    if not ok then ns.errors.journeyAdvance=tostring(err);return false end
    ns.errors.journeyAdvance=nil;return true
end
function J.NextRoute()
    local r=J.Selected()
    local following=J.CampaignNext(r) or J.Recommended(r)
    if following and following.min>ns.State.level then ns.Message("The next route begins at level "..following.min.."."); return end
    if following and J.Select(following.id,ns.char.routeMode) then return end
    ns.Message("No further route segment is available under this character and content ruleset.")
end
function J.GoalWaypoint(g)
    if not J.Applies(g.only) or J.Blocked(g) then return false end
    local point=ns.Navigation.Location(g)
    if point and ns.Navigation.ShowDestination(point) then return true end
    if g.quest and g.t~="accept" and J.OnQuest(g.quest) and type(QuestMapFrame_OpenToQuestDetails)=="function" then
        QuestMapFrame_OpenToQuestDetails(g.quest)
        return true
    end
    if point then return ns.API.OpenMap(point.map) end
    return false
end
function J.Waypoint(step)
    local chosen
    for _,g in ipairs(step.goals or {}) do if J.Applies(g.only) and not J.GoalDone(g) and not J.OptionalDeferred(g) and not J.Blocked(g) then chosen=g; break end end
    if chosen then
        if J.GoalWaypoint(chosen) then return end
        if chosen.quest and QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(chosen.quest); return end
        ns.Message("This action has no sourced waypoint. Follow its written instructions."); return
    end
    local p=step.pickup
    if p and p.zone and type(OpenWorldMap)=="function" then local map=ns.World.MapForZone(p.zone); if map then OpenWorldMap(map);return end end
    if step.quest and QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(step.quest); return end
    ns.Message("This action has no sourced waypoint. Follow its instructions and confirm it manually.")
end
ns.On("PLAYER_STOPPED_MOVING",function()
    if not ns.char then return end
    ns.After("routeArrival",function()
        local previous=ns.Navigation and ns.Navigation.goal
        if previous and (previous.t~="goto" or not J.GoalDone(previous)) then return end
        J.Advance();local current=J.Action()
        if not previous or not current or previous.id~=current.id then ns.Emit("STATE_CHANGED","journey") end
    end)
end)
