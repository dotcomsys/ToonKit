local addonName, ns = ...
local P,J=ns.DungeonJourney,ns.Journey
local function family(r)
    -- Town errands share a visit, not an invented common quest chain.
    return r.planSlug
end
local function handoff(g) return g.t=="accept" or g.t=="turnin" or g.t=="buy" end
local function nearby(a,b)
    if not a.map or a.map~=b.map then return false end
    if a.npc and a.npc==b.npc then return true end
    if type(a.x)~="number" or type(a.y)~="number" or type(b.x)~="number" or type(b.y)~="number" then return false end
    -- A bounded map cluster, never a road distance or travel-time estimate.
    return (a.x-b.x)^2+(a.y-b.y)^2<=.06^2
end
local function ordered(a,b)
    if a.score~=b.score then return a.score<b.score end
    return a.route.id<b.route.id
end
function P.CommitTrip(r)
    local g=P.Goal(r)
    if not g then return end
    ns.char.itinerary={family=family(r),map=g.map,route=r.id,returnRoute=ns.char.routeReturn and ns.char.routeReturn.id}
end
function P.ChooseTrip(candidates,map)
    table.sort(candidates,ordered)
    local chosen=candidates[1]
    if not chosen then P.tripPreview=nil;return end
    local lock=ns.char.itinerary
    local current
    for _,c in ipairs(candidates) do if c.route.id==ns.char.route then current=c;break end end
    -- Only continue a commitment while that automatic detour is still active.
    -- A manual route selection never inherits an unrelated saved commitment.
    local committed=lock and (ns.char.route==lock.route or ns.char.route==lock.returnRoute)
    if committed and (not P.DueTrip(chosen.route) or family(chosen.route)==lock.family) then
        local sameStop,sameTrip
        for _,c in ipairs(candidates) do if family(c.route)==lock.family then
            if not sameTrip then sameTrip=c end
            if c.goal.map==lock.map and not sameStop then sameStop=c end
        end end
        -- A saved Darkshire return must not pin the Stockades trip away
        -- from the requested Stormwind returns and Unsent Letter followups.
        local cityStockade=chosen.route.planSlug=="the-stockade" and (chosen.route.planStockadeFollowup
            or chosen.goal.t=="turnin" and chosen.goal.map==1453)
        local aftermath=chosen.route.planRedridge or P.StockadeAftermathReady() and chosen.route.planSlug=="the-stockade"
            and (chosen.goal.quest==377 or chosen.goal.quest==386)
        chosen=(cityStockade or aftermath) and chosen or sameStop or sameTrip or chosen
    end
    -- Before departure, finish eligible pickups/returns at the same known
    -- contact/coordinate cluster as the current stop. Do not pull in arbitrary
    -- work from elsewhere in the zone or a not-yet-unlocked future quest.
    if current and current.goal.map==map and chosen.goal.map and chosen.goal.map~=map then
        for _,c in ipairs(candidates) do
            local related=family(c.route)==family(chosen.route) or family(c.route)==family(current.route)
            if related and handoff(c.goal) and nearby(c.goal,current.goal)
                and (not P.DueTrip(chosen.route) or family(c.route)==family(chosen.route)) then
                chosen=c;break
            end
        end
    end
    -- A sourced dungeon trip collects its unlocked pickups before starting
    -- objectives. Preserve special chains and never send players back out
    -- of a dungeon they have already entered.
    local dungeon=chosen.route.planSlug
    local inside=ns.TripPlanning and ns.TripPlanning.instanceSlug==dungeon
    if not inside and chosen.route.planMinimum and chosen.goal.t=="complete"
        and chosen.goal.quest==chosen.route.planQuest and not chosen.route.planRedridge then
        local pickup
        for _,candidate in ipairs(candidates) do
            if family(candidate.route)==dungeon and candidate.goal.t=="accept" and candidate.goal.map then
                if not pickup then pickup=candidate end
                if candidate.goal.map==map then pickup=candidate;break end
            end
        end
        if pickup then chosen=pickup end
    end
    local stops,seen={},{}
    for _,c in ipairs(candidates) do if family(c.route)==family(chosen.route) then
        local key=tostring(c.goal.quest)..":"..c.goal.t
        if not seen[key] then
            seen[key]=true
            if #stops<6 and c.route.id~=chosen.route.id and c.goal.t==chosen.goal.t then
                local text=J.GoalText(c.goal)
                if c.goal.npcName then text=text.." · "..c.goal.npcName end
                stops[#stops+1]=text
            end
        end
    end end
    P.tripPreview={route=chosen.route.id,family=family(chosen.route),stops=stops,
        reason=chosen.goal.map and chosen.goal.map~=map and "Continue the prepared trip to the next source-listed area."
            or "Finish the eligible work for this visit before changing areas."}
    return chosen.route,chosen.score
end
function P.SwitchTrip(current,candidate,score,map)
    if candidate.id==current.id then return false end
    if P.DueTrip(candidate) then return true end
    local lock=ns.char.itinerary
    if lock and family(current)==lock.family and family(candidate)==lock.family
        and P.tripPreview and P.tripPreview.route==candidate.id then return true end
    return score<P.Priority(current,map)
end
function P.TripHint(route)
    local preview=P.tripPreview
    if not preview or preview.route~=route.id then return end
    local g=P.Goal(route)
    if not g then P.tripPreview=nil;return end
    local text=preview.reason
    local phase=g.t
    if #preview.stops>0 then
        local heading=phase=="accept" and "Other pickups for this trip" or phase=="complete" and "Other objectives for this trip" or "Other ready returns"
        text=text.."\n"..heading..":\n"..table.concat(preview.stops,"\n")
    end
    local support=ns.Data.questSupport
    local requirements=g and g.quest and support and support.quests[g.quest]
    local ids={}
    for id,count in pairs(requirements and requirements.items or {}) do
        if type(count)=="number" and count>0 and (ns.State.owned[id] or 0)<count then ids[#ids+1]=id end
    end
    table.sort(ids)
    local supplies={}
    for i=1,math.min(3,#ids) do
        local id=ids[i];local info=ns.API.Item(id)
        supplies[#supplies+1]=requirements.items[id].." "..(info and info.name or "Item #"..id).." (have "..(ns.State.owned[id] or 0)..")"
    end
    if #supplies>0 then text=text.."\nQuest supplies: "..table.concat(supplies,", ") end
    return text
end
-- Explicit route choices cancel a previous automatic commitment.
local select=J.Select
if select then function J.Select(...) ns.char.itinerary=nil;P.tripPreview=nil;return select(...) end end
local automatic=J.Automatic
if automatic then function J.Automatic(...) ns.char.itinerary=nil;P.tripPreview=nil;return automatic(...) end end
ns.Listen("SETTINGS_CHANGED",function() P.tripPreview=nil end)
