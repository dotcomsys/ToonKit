local addonName, ns = ...
local J=ns.Journey
local zones={[1433]="Redridge",[1431]="Duskwood",[1437]="Wetlands"}
local function liveQuest(id)
    for _,q in ipairs(ns.State.quests or {}) do if q.id==id then return q end end
end
function J.ZoneVisitEligible(g,map)
    if g.preparationFor==93 and g.item==2251 and g.map==map and map==1431 then
        return not J.QuestDone(93) and not J.GoalDone(g) and not J.OptionalDeferred(g)
    end
    if not g.quest or g.map~=map or not J.Applies(g.only) or J.GoalDone(g) then return false end
    local q=liveQuest(g.quest)
    if not q then
        -- Include source-listed pickups, so a new zone visit can start before
        -- its quests are in the log. Preserve item-start and prerequisite gates.
        if g.t~="accept" or J.OptionalDeferred(g) or not ns.QuestSupplies or not ns.QuestSupplies.Eligible(g.quest) then return false end
        local m=ns.Data.questSupport.meta[g.quest]
        q={level=g.qlvl or m and m.level}
    end
    -- Returning an already finished quest does not require fighting its elite.
    if q.complete and J.ReadyToTurnIn(g.quest) then return g.t=="turnin" end
    if g.t=="turnin" then return false end
    if g.duskwoodBatch and g.t=="turnin" then return false end
    local level=q.level
    if not level or level<=0 then local m=ns.Data.questSupport.meta[g.quest];level=m and m.level end
    local ceiling=map==1433 and ns.State.level<25 and 24 or math.min(ns.State.level+2,ns.Rules.Cap())
    -- Grouping nearby objectives does not make higher-level combat manageable.
    if type(level)~="number" or level>ceiling and not (map==1433 and g.blackrockPass and g.quest==95999 and level<=ns.Rules.Cap() or map==1431 and g.darkenedBankPass and g.quest==96137 and level<=ns.Rules.Cap() or map==1431 and g.darkshirePair and (g.quest==174 or g.quest==175 or g.quest==177 and g.t=="accept") and level<=ns.Rules.Cap()) then return false end
    local elite=ns.Safe(ns.API.Call("C_QuestLog","IsEliteQuest",g.quest))
    local group=ns.Safe(ns.API.Call("C_QuestLog","GetSuggestedGroupSize",g.quest))
    if elite~=false or type(group)=="number" and group>1 then return false end
    return (g.t~="accept" or not liveQuest(g.quest)) and not J.Blocked(g)
end
local function visitGoals(route,index,step)
    local status=J.Status(route,index)
    if not status then return step.goals or {} end
    if status=="skipped" then return {} end
    -- Recover newly added shared-contact handoffs without replaying the old
    -- town hearth or treating a whole previously saved step as unfinished.
    local goals={}
    for _,g in ipairs(step.goals or {}) do
        if g.darkshirePair and g.id and g.id:find("^toonkit:duskwood:") then goals[#goals+1]=g end
    end
    return goals
end
local function work(route,map)
    local count=0
    for i,s in ipairs(route.steps or {}) do if J.Applies(s.only) then
        for _,g in ipairs(visitGoals(route,i,s)) do if J.ZoneVisitEligible(g,map) then count=count+1 end end
    end end
    return count
end
local choices={}
function J.ZoneVisitChoice(map)
    local epoch=tostring(ns.State.revision or 0)..":"..tostring(ns.stateEpoch or 0)
    if J.zoneChoiceEpoch~=epoch then choices={};J.zoneChoiceEpoch=epoch end
    local key=table.concat({ns.State.revision or 0,ns.State.class or "",ns.State.level,ns.Rules.Cap(),map},":")
    if choices[key]~=nil then return choices[key] or nil end
    local best,score
    for _,r in ipairs(J.Routes()) do if r.category=="Leveling" and (r.min or 1)<=ns.Rules.Cap() then
        local count=work(r,map)
        if count>0 and (not best or count>score or count==score and r.id<best.id) then best,score=r,count end
    end end
    choices[key]=best or false
    return best
end
ns.Listen("SETTINGS_CHANGED",function() choices={} end)
local selected=J.Selected
function J.Selected()
    local r=selected()
    if ns.State.level>=30 then ns.char.zoneVisit=nil;return r end
    if ns.State.faction~="Alliance" or ns.char.journeyPaused or r.planSlug or r.category=="Class" then return r end
    if ns.char.routeMode~="auto" then return r end
    local visit=ns.char.zoneVisit
    local map=ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"))
    -- Finish accepted manageable Redridge work before the authored Darkshore
    -- link. Once it is exhausted, choose logged work in the current/next zone.
    local area=visit and visit.map
    local choice=area and J.ZoneVisitChoice(area)
    -- At 23-24, take the Wetlands interlude before later Duskwood combat.
    -- Re-evaluate saved visits too; this changes selection, never quest progress.
    local wetlandsInterlude=ns.State.level>=23 and ns.State.level<25 and J.ZoneVisitChoice(1437)
    if wetlandsInterlude then area=1437;choice=wetlandsInterlude end
    local paladinInterlude=ns.State.class=="PALADIN" and ns.State.level<24 and J.OnQuest(1654) and (ns.State.owned[6994] or 0)>0
    if paladinInterlude and area~=1431 and area~=1437 then
        area=1431;choice=J.ZoneVisitChoice(area)
        if not choice then area=1437;choice=J.ZoneVisitChoice(area) end
    end
    if not choice then
        area=1433;choice=J.ZoneVisitChoice(area)
        if not choice then area=zones[map] and map;choice=area and J.ZoneVisitChoice(area) end
        if not choice then area=1431;choice=J.ZoneVisitChoice(area) end
        if not choice then area=1437;choice=J.ZoneVisitChoice(area) end
    end
    if not choice then ns.char.zoneVisit=nil;return r end
    ns.char.zoneVisit={map=area,route=choice.id}
    ns.char.route=choice.id
    J.ReconcileRoute(choice)
    return choice
end
local current=J.Current
function J.Current()
    local r=J.Selected();local visit=ns.char.zoneVisit
    if visit and ns.char.routeMode=="auto" and r.id==visit.route then
        local firstQuest
        for i,s in ipairs(r.steps or {}) do if J.Applies(s.only) then
            for _,g in ipairs(visitGoals(r,i,s)) do if J.ZoneVisitEligible(g,visit.map) then firstQuest=i;break end end
            if firstQuest then break end
        end end
        local service={getfp=true,sethome=true,hearth=true,vendor=true,train=true,goto=true}
        for i,s in ipairs(r.steps or {}) do if J.Applies(s.only) then
            local goals={};local sameArea=false
            for _,g in ipairs(s.goals or {}) do if g.map==visit.map then sameArea=true;break end end
            for _,g in ipairs(visitGoals(r,i,s)) do
                local preparation=not g.quest and service[g.t] and firstQuest and i<=firstQuest
                    and (g.map==visit.map or not g.map and sameArea)
                    and J.Applies(g.only) and not J.GoalDone(g) and not J.Blocked(g)
                if J.ZoneVisitEligible(g,visit.map) or preparation then goals[#goals+1]=g end
            end
            if #goals>0 then
                local copy={};for k,v in pairs(s) do copy[k]=v end;copy.goals=goals
                return copy,i
            end
        end end
    end
    return current()
end
local select=J.Select
function J.Select(...) ns.char.zoneVisit=nil;return select(...) end
