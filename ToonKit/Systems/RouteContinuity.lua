local addonName, ns = ...
local C={};ns.RouteContinuity=C
local J=ns.Journey
function C.Key()
    local ids={};for _,q in ipairs(ns.State.quests or {}) do ids[#ids+1]=q.id end;table.sort(ids)
    return table.concat(ids,":")
end
function C.Append(expanded,base)
    local covered={}
    for _,r in ipairs(base) do if r.category=="Leveling" then
        for _,s in ipairs(r.steps or {}) do if J.Applies(s.only) then for _,g in ipairs(s.goals or {}) do
            if g.quest and J.Applies(g.only) then
                covered[g.quest]=true
                local m=(ns.Data.questSupport.meta or {})[g.quest]
                if m and m.chain then covered[m.chain]=true end
            end
        end end end
    end end
    for _,q in ipairs(ns.State.quests or {}) do if covered[q.id] or q.id==92745 then
        local facts=(ns.Data.dungeonPreparation or {})[q.id];local p=facts and facts.turnin and facts.turnin[1]
        if p then
            local m=ns.Data.questSupport.meta[q.id] or {}
            local g={id="journey-handoff:"..q.id..":turnin",t="turnin",quest=q.id,title=q.title or m.name or "Quest #"..q.id,
                map=p.map,x=p.x,y=p.y,locations=ns.Copy(facts.turnin),minLevel=m.min,
                note=p.kind>=5 and "Source point is the entrance; the turn-in is inside the dungeon." or "Turn in this completed quest while visiting its source-listed contact. Native quest completion is required."}
            if p.kind==1 then g.npc=p.provider end
            expanded[#expanded+1]={id="plan:"..g.id,name=g.title,category="Dungeon action",min=1,max=60,
                steps={{id=g.id,text="Turn in: "..g.title,goals={g}}},planSlug="route-handoffs",planQuest=q.id,
                planTarget=m.min or 1,planContinuity=true,source="EverythingQuests Forever MIT: pickup/return data"}
        end
    end end
end
function C.LocalReturn(r,map)
    local g=r.steps[1].goals[1]
    -- Reuse the authored order across zones; recover a ready handoff when
    -- actually near its contact instead of inventing another return journey.
    if g.map~=map then return false end
    local current,x,y=ns.API.Position()
    return current==map and type(x)=="number" and type(y)=="number" and type(g.x)=="number" and type(g.y)=="number"
        and (x-g.x)^2+(y-g.y)^2<=.06^2
end
function C.CanInterrupt(route,candidate)
    -- A due, opted-in trip can leave ordinary outdoor objective work.
    -- Do not let the recovery circuit immediately steal that trip back.
    local planner=ns.DungeonJourney
    if planner and planner.DueTrip then
        if planner.DueTrip(candidate) then return true end
        if planner.DueTrip(route) and candidate and candidate.planWestfall then return false end
    end
    if candidate and candidate.planWestfall and not route.planWestfall then return true end
    if candidate and ns.TripPlanning and ns.TripPlanning.instanceSlug==candidate.planSlug then return true end
    if not route or route.live then return true end
    local entry=(ns.char.routeEntries or {})[route.id]
    for i=entry and entry.index or 1,#(route.steps or {}) do
        local step=route.steps[i]
        if not J.Status(route,i) and J.Applies(step.only) then
            for _,g in ipairs(step.goals or {}) do if J.Applies(g.only) and not J.OptionalDeferred(g) and not J.GoalDone(g) then
                if J.Blocked(g) then return true end
                return g.t~="kill" and g.t~="collect" and g.t~="complete" and g.t~="interact"
            end end
        end
    end
    return true
end
function C.Followup(goal)
    if not goal or goal.t~="turnin" or not goal.quest then return end
    local m=ns.Data.questSupport.meta[goal.quest]
    local child=m and m.chain and ns.Data.questSupport.meta[m.chain]
    if not child or J.QuestDone(m.chain) or J.OnQuest(m.chain) then return end
    if not ns.Rules.MaskAllows(child.classes,ns.State.classID) or not ns.Rules.QuestRaceAllowed(child.races) then return end
    if child.skill or child.minRep or child.maxRep or (child.min or 1)>ns.State.level then return end
    return "After this return: "..child.name..". Its source lists a follow-up; check the quest giver."
end
function C.Supplies(goal)
    if not goal or not goal.quest or (goal.t~="accept" and goal.t~="turnin") then return end
    local record=ns.Data.questSupport.quests[goal.quest];if not record then return end
    local ids={};for id,count in pairs(record.items or {}) do if count>0 and (ns.State.owned[id] or 0)<count then ids[#ids+1]=id end end
    table.sort(ids);local parts={}
    for _,id in ipairs(ids) do
        local item=ns.API.Item(id);parts[#parts+1]=record.items[id].." "..(item and item.name or "Item #"..id)
    end
    if #parts>0 then return "Bring: "..table.concat(parts,", ") end
end
