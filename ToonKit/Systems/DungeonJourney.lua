local addonName, ns = ...
local J=ns.Journey
local P={};ns.DungeonJourney=P
-- Requested trip targets, not quest minimums or measured optimal levels.
local targets={["hall-of-thanes"]=15,["the-deadmines"]=20,["shadowfang-keep"]=23,["blackfathom-deeps"]=25}
local function meta(id) return (ns.Data.questSupport or {}).meta and ns.Data.questSupport.meta[id] end
local function identity(id)
    local m=meta(id);if not m then return true end
    return ns.Rules.MaskAllows(m.classes,ns.State.classID) and ns.Rules.QuestRaceAllowed(m.races)
end
local function locate(goal)
    if goal.map then return end
    local alcaz=(ns.Data.alcazContacts or {})[goal.quest]
    local contact=alcaz and alcaz[goal.t]
    if contact then
        goal.map=contact.map
        if contact.x and contact.y then goal.x,goal.y=contact.x/100,contact.y/100 end
        if contact.place then goal.note=contact.place..". "..(goal.note or "") end
        return
    end
    local facts=(ns.Data.dungeonPreparation or {})[goal.quest]
    local points=facts and (goal.t=="accept" and facts.pickup or goal.t=="turnin" and facts.turnin)
    if not points or not points[1] then return end
    local p=points[1];goal.map=p.map;goal.x=p.x;goal.y=p.y;goal.locations=ns.Copy(points)
    if p.kind==1 then goal.npc=p.provider elseif p.kind==2 then goal.fromKind="object";goal.fromId=p.provider end
    if p.kind==3 then goal.note=(goal.note or "").."\nSource point is a quest-starting item drop area, not a quest giver. Skip this pickup if you choose not to farm the drop." end
    if p.kind==5 or p.kind==6 then goal.note=(goal.note or "").."\nThis source point marks the dungeon entrance; the actual turn-in is inside." end
end
function P.Needed(root,wanted,seen)
    if root==wanted then return true end
    if J.OnQuest(root) or J.QuestDone(root) then return false end
    seen=seen or {};if seen[root] then return false end;seen[root]=true
    local m=meta(root);if not m then return false end
    for _,id in ipairs(m.preAll or {}) do if not J.QuestDone(id) and P.Needed(id,wanted,seen) then return true end end
    local any=false;for _,id in ipairs(m.pre or {}) do if J.QuestDone(id) then any=true end end
    if not any then
        local branch
        for _,id in ipairs(m.pre or {}) do if identity(id) and (not branch or J.OnQuest(id)) then branch=id;if J.OnQuest(id) then break end end end
        if branch and P.Needed(branch,wanted,seen) then return true end
    end
    return false
end
function P.Target(slug,min) return targets[slug] or min or 1 end
function P.BrewPass()
    for _,q in ipairs({92745,13}) do
        if J.OnQuest(q) and ns.Safe(ns.API.Call("C_QuestLog","IsComplete",q))~=true then return false end
    end
    return J.OnQuest(14) or J.QuestDone(14) or not J.QuestDone(12) and not J.QuestDone(13)
end
-- Keep started explosive preparation ahead of ordinary errands, without
-- preventing a due, included dungeon trip. This does not force dungeon opt-in.
local explosiveQuests={92748,92749,92750,92751,92752,92753}
function P.ExplosivePreparation()
    if J.OnQuest(92753) or J.QuestDone(92753) then return false end
    for _,id in ipairs(explosiveQuests) do
        if J.OnQuest(id) then return true end
    end
    return J.QuestDone(92748) and not J.QuestDone(92752)
        or J.QuestDone(92752) and not J.QuestDone(92753)
end
local function explosiveQuest(id)
    for _,q in ipairs(explosiveQuests) do if id==q then return true end end
    return false
end
function P.Included(slug,quest)
    local plan=ns.char.dungeonJourney or {};local overrides=plan.quests or {}
    local key=slug..":"..quest
    if overrides[key]~=nil then return overrides[key] end
    return plan.enabled==true
end
function P.Configure(enabled,quiet)
    ns.char.dungeonJourney=ns.char.dungeonJourney or {}
    ns.char.dungeonJourney.enabled=enabled;ns.char.dungeonJourney.asked=true
    if P.prompt then P.prompt:Hide() end
    if not quiet then ns.Emit("STATE_CHANGED") end
end
function P.Toggle(slug,quest)
    local included=P.Included(slug,quest)
    ns.char.dungeonJourney=ns.char.dungeonJourney or {asked=true}
    local plan=ns.char.dungeonJourney;plan.quests=plan.quests or {};plan.quests[slug..":"..quest]=not included
    ns.Emit("STATE_CHANGED")
end
function P.IncludeDungeon(source)
    ns.char.dungeonJourney=ns.char.dungeonJourney or {asked=true}
    local plan=ns.char.dungeonJourney;plan.quests=plan.quests or {}
    for _,q in ipairs(source) do if ns.Rules.Available(q,false) then plan.quests[source.slug..":"..q.id]=true end end
    ns.Emit("STATE_CHANGED")
end
local routes=J.Routes
function J.Routes()
    local all=routes()
    if J.Speedrunning() then return all end
    local activeKey=ns.RouteContinuity and ns.RouteContinuity.Key()
    if P.base==all and P.activeKey==activeKey then return P.routes end
    local expanded={}
    for _,r in ipairs(all) do
        expanded[#expanded+1]=r
    end
    local function append(r,slug,root,step)
        expanded[#expanded+1]={id="plan:"..slug..":"..root..":"..step.id,name=r.name..": "..step.text,category="Dungeon action",
            min=1,max=60,steps={step},planSlug=slug,planQuest=root,planMinimum=r.min,planMaximum=r.max,
            planTarget=P.Target(slug,r.min),source=r.source}
    end
    for _,r in ipairs(all) do if r.category=="Dungeon" then
        local slug=r.id:gsub("^dungeon:","")
        for _,step in ipairs(r.steps) do
            local g=step.goals[1]
            local action=ns.Copy(step);locate(action.goals[1])
            if g.t=="accept" then
                local seen={[g.quest]=true}
                local function prerequisites(id)
                    local m=meta(id);if not m then return end
                    for _,list in ipairs({m.preAll or {},m.pre or {}}) do for _,q in ipairs(list) do if not seen[q] then
                        seen[q]=true;prerequisites(q)
                        local fact=meta(q)
                        if fact then for _,phase in ipairs({"accept","complete","turnin"}) do
                            local goal={id="dungeon-preparation:"..q..":"..phase,t=phase,quest=q,title=fact.name,minLevel=fact.min,dungeon=true,
                                note="Prerequisite preparation for "..g.title..". Follow the native quest objectives; unknown objective locations are not guessed."}
                            locate(goal)
                            if q==92749 and phase=="complete" then
                                goal.note="Obtain 10 Rough Dynamite for A Dynamite Plan. You can check the Auction House as planned; listings and prices are not known to ToonKit. Then finish this handoff and the Detonation at a Distance branch before taking Destruction in Deadmines. Native quest completion is required."
                            end
                            append(r,slug,g.quest,{id=goal.id,text=(phase=="accept" and "Pick up: " or phase=="turnin" and "Return: " or "Objectives: ")..fact.name,goals={goal}})
                        end end
                    end end end
                end
                prerequisites(g.quest)
            end
            append(r,slug,g.quest,action)
        end
    end end
    -- Continue the sourced Unsent Letter chain after The Stockade Riots.
    -- Separate phase IDs preserve all existing dungeon actions and saved skips.
    for order,q in ipairs({392,393,350,2745,2746,434}) do
        local m=meta(q)
        if m then for _,phase in ipairs({"accept","complete","turnin"}) do
            local g={id="stockade-followup:"..q..":"..phase,t=phase,quest=q,title=m.name,minLevel=m.min,
                pre=phase=="accept" and ns.Copy(m.pre) or nil,
                note="Continue The Unsent Letter chain in Stormwind after The Stockade Riots. Follow the native quest objectives; complete this handoff before leaving for distant Stockades returns."}
            if q==434 then g.note="Optional group opportunity after Items of Some Consequence: find a group for The Attack! if possible. If no group is available, choose Later (30), or Skip beside the task, to defer it until level 30. Follow the native quest objectives; group availability and success are not inferred." end
            locate(g)
            expanded[#expanded+1]={id="plan:"..g.id,name=m.name,category="Dungeon action",min=1,max=60,
                steps={{id=g.id,text=(phase=="accept" and "Pick up: " or phase=="turnin" and "Turn in: " or "Objectives: ")..m.name,goals={g}}},
                planSlug="the-stockade",planQuest=q,planTarget=m.min or 16,planStockadeFollowup=order,planAttack=q==434,
                planMaximum=math.max(31,(m.level or 26)+5),
                source="EverythingQuests Forever MIT: prerequisites, pickups and returns"}
        end end
    end
    -- Post-Stockades Redridge pickup and return facts.
    local redSeen={}
    for order,root in ipairs({19,169,180,95999,115,94,248,249,91,124,126,219,128,178}) do
        local function appendQuest(q)
            if redSeen[q] then return end;redSeen[q]=true
            local m=meta(q);if not m then return end
            for _,list in ipairs({m.preAll or {},m.pre or {}}) do for _,pre in ipairs(list) do appendQuest(pre) end end
            for _,phase in ipairs({"accept","complete","turnin"}) do
                local id="stockade-redridge:"..root..":"..q..":"..phase
                local goal={id=id,t=phase,quest=q,title=m.name,minLevel=m.min,
                    pre=phase=="accept" and ns.Copy(m.pre) or nil,preAll=phase=="accept" and ns.Copy(m.preAll) or nil,
                    note="Finish the remaining Redridge quests after the Stockades returns. Use the native objectives and group for difficult targets when needed."}
                locate(goal)
                expanded[#expanded+1]={id="plan:"..id,name=m.name,category="Dungeon action",min=1,max=60,
                    steps={{id=id,text=(phase=="accept" and "Pick up: " or phase=="turnin" and "Turn in: " or "Objectives: ")..m.name,goals={goal}}},
                    planSlug="the-stockade",planQuest=root,planTarget=26,planRedridge=order,
                    planMaximum=math.max(31,(m.level or 26)+5),
                    source="EverythingQuests Forever MIT prerequisites and contacts"}
            end
        end
        appendQuest(root)
    end
    -- Batch an already accepted Redridge courier quest with the Stormwind
    -- visit. Its return pickup stays local; never force another Redridge trip.
    for _,record in ipairs({{120,"turnin"},{121,"accept"},{121,"turnin"}}) do
        local q,phase=record[1],record[2];local m=meta(q)
        if m then
            local goal={id="journey-courier:"..q..":"..phase,t=phase,quest=q,title=m.name,minLevel=m.min,
                note="Finish this accepted courier handoff on the connected Redridge / Westfall / Stormwind journey. The return to Redridge is deferred until you are back there."}
            locate(goal)
            expanded[#expanded+1]={id="plan:"..goal.id,name=m.name,category="Dungeon action",min=1,max=60,
                steps={{id=goal.id,text=(phase=="accept" and "Pick up: " or "Turn in: ")..m.name,goals={goal}}},
                planSlug="courier-handoffs",planQuest=q,planTarget=14,planHandoff=true,source="EverythingQuests Forever MIT: quest 120/121 pickups and returns"}
        end
    end
    for _,record in ipairs(ns.Data.townErrands or {}) do
        local g=ns.Copy(record);g.id="town-errand:"..g.key;g.title=(meta(g.root) or {}).name;g.minLevel=(meta(g.root) or {}).min;locate(g)
        expanded[#expanded+1]={id="plan:"..g.id,name=g.title,category="Dungeon action",min=1,max=60,
            steps={{id=g.id,text=g.note or ((g.t=="accept" and "Pick up: " or "Turn in: ")..g.title),goals={g}}},
            planSlug="town-errands",planQuest=g.root,planTarget=(meta(g.root) or {}).min or 1,planErrand=g.key,source="ATT / EverythingQuests Forever MIT; Dry Times quest text"}
    end
    local westfallGoals={}
    for _,quest in ipairs({92745,13}) do
        local record=meta(quest)
        if record and J.OnQuest(quest) then
            westfallGoals[#westfallGoals+1]={id="toonkit:westfall:fieldwork:"..quest,t="complete",quest=quest,
                title=record.name,map=1436,note="Finish the listed mine and militia objectives while working through Westfall. Check the live counters before returning."}
        end
    end
    if #westfallGoals>0 then
        expanded[#expanded+1]={id="plan:toonkit:westfall:fieldwork",name="Westfall: Mine and militia fieldwork",
            category="Dungeon action",min=1,max=60,
            steps={{id="toonkit:westfall:fieldwork",text="Finish the active Westfall objectives",goals=westfallGoals}},
            planSlug="westfall-fieldwork",planQuest=westfallGoals[1].quest,planTarget=1,planWestfall=true,
            source="ToonKit fieldwork and live quest objectives"}
    end
    if ns.RouteContinuity then ns.RouteContinuity.Append(expanded,all) end
    P.base=all;P.activeKey=activeKey;P.routes=expanded;J.questIndices=nil;return expanded
end
-- Fieldwork keeps stable step slots even when only Militia is active.
-- A slot can therefore be empty; completed circuits have no next action.
function P.Goal(r)
    for _,step in ipairs(r.steps or {}) do
        for _,g in ipairs(step.goals or {}) do
            if not (r.planWestfall or r.planRedridge) or not J.GoalDone(g) then return g end
        end
    end
end
local function pendingReturn(q)
    return J.OnQuest(q) and not J.QuestDone(q) and (ns.char.goalProgress or {})["dungeon:the-stockade:"..q..":turnin"]~="skipped"
end
function P.StockadeAftermathReady()
    local progress=ns.char.goalProgress or {}
    return J.QuestDone(2746) and (J.QuestDone(434) or ns.char.stockadeAttackDeferred
        or progress["stockade-followup:434:accept"]=="skipped" or progress["stockade-followup:434:complete"]=="skipped"
        or progress["stockade-followup:434:turnin"]=="skipped")
end
function P.Enabled(r)
    local goal=P.Goal(r);if not goal then return false end
    local plan=ns.char.dungeonJourney or {}
    local explicit=(plan.quests or {})[r.planSlug..":"..r.planQuest]==true
    if r.planMaximum and ns.State.level>r.planMaximum and not explicit
        and not J.OnQuest(r.planQuest) and not J.OnQuest(goal.quest) then return false end
    local minimum=goal.minLevel or (meta(goal.quest) or {}).min or r.planTarget
    if ns.State.level<math.max(minimum,r.planMinimum or 1) then return false end
    if r.planRedridge then
        return P.StockadeAftermathReady() and not pendingReturn(377) and not pendingReturn(386)
            and (r.planQuest~=178 or J.OnQuest(178))
    end
    if r.planSlug=="the-stockade" and r.planQuest==386 and P.StockadeAftermathReady() and pendingReturn(377) then return false end
    if r.planAttack and ns.char.stockadeAttackDeferred and ns.State.level<30 and not J.ReadyToTurnIn(434) then return false end
    if r.planStockadeFollowup then
        if J.OnQuest(r.planQuest) then return true end
        local m=meta(r.planQuest) or {}
        for _,q in ipairs(m.pre or {}) do if J.QuestDone(q) then return true end end
        return false
    end
    if r.planWestfall then return J.OnQuest(92745) or J.OnQuest(13) end
    if r.planContinuity then return J.OnQuest(r.planQuest) end
    if r.planErrand then
        local g=P.Goal(r)
        if (r.planErrand=="hops" or r.planErrand=="thunderbrew") and not P.BrewPass() then return false end
        if r.planQuest==119 then return J.OnQuest(119) or J.QuestDone(118) and not J.QuestDone(119) end
        return J.OnQuest(r.planQuest) or g.t=="accept" and not J.QuestDone(r.planQuest)
    end
    if r.planHandoff then return r.planQuest==120 and J.OnQuest(120) or r.planQuest==121 and (J.OnQuest(121) or J.QuestDone(120)) end
    local q=goal.quest
    if r.planQuest==166 and (q==65 or q==132 or q==135 or q==141) then
        if J.QuestDone(65) or J.OnQuest(65) or J.OnQuest(132) or J.OnQuest(135) or J.OnQuest(141) then return true end
    end
    return P.Included(r.planSlug,r.planQuest)
end
function P.DeferAttack(view)
    local g=view.goal
    if not g or g.quest~=434 or ns.State.level>=30 or J.QuestDone(434) or J.ReadyToTurnIn(434) then return false end
    J.Remember("deferAttack",g.id,"The Attack! deferred until level 30")
    ns.char.stockadeAttackDeferred=true
    J.Advance();ns.Emit("STATE_CHANGED")
    ns.Message("The Attack! deferred until level 30. Continue leveling; Undo restores this opportunity.")
    return true
end
function P.DueTrip(r)
    return r and r.planSlug=="hall-of-thanes" and ns.State.level>=P.Target("hall-of-thanes")
        and P.Enabled(r)
end
function P.Priority(r,map)
    local g=P.Goal(r);if not g then return math.huge end;local localPoint=g.map==map
    if r.planRedridge then
        local phase=g.t=="accept" and 0 or g.t=="turnin" and 20 or 10
        return -4400+phase+r.planRedridge/100
    end
    if r.planSlug=="the-stockade" then
        if P.StockadeAftermathReady() and g.quest==377 then return -4550 end
        if P.StockadeAftermathReady() and g.quest==386 then return -4540 end
        -- Finish the requested city returns/chain before Darkshire or Wetlands.
        if g.t=="turnin" and g.quest==388 then return -4900 end
        if g.t=="turnin" and g.quest==391 then return -4800 end
        if r.planStockadeFollowup then return -4600+r.planStockadeFollowup end
        if not J.QuestDone(2746) and g.t=="turnin" and g.map==1453 and map==1453 then return -4700 end
    end
    if r.planSlug~="the-stockade" and ns.char.preferredDungeonTrip==r.planSlug and J.AutomaticContext() then return -6000 end
    if P.DueTrip(r) then return g.t=="turnin" and -5700 or g.t=="accept" and -5600 or -5500 end
    if P.ExplosivePreparation() and explosiveQuest(g.quest) then return g.t=="turnin" and -5300 or g.t=="accept" and -5200 or -5100 end
    if r.planContinuity then return -4000 end
    if r.planWestfall then return -3450 end
    if r.planErrand then
        if (r.planErrand=="hops" or r.planErrand=="thunderbrew") and J.OnQuest(14) then
            local m,_,y=ns.API.Position()
            if m==1436 and type(y)=="number" and y>=.6 then return -4400 end
        end
        if g.t=="turnin" then return localPoint and -4100 or -3600 end
        if g.t=="accept" then return -3400 end
        return -3300
    end
    -- A completed run should surface its reward before unrelated new pickups.
    if g.t=="turnin" and not r.planHandoff then return localPoint and -2100 or -2000 end
    local score=(g.t=="turnin" and 0 or g.t=="accept" and 100 or 200)+r.planTarget*10+(localPoint and 0 or 20)
    if r.planHandoff then return -2900-(localPoint and 200 or 0) end
    if g.quest~=r.planQuest and J.OnQuest(g.quest) then return -3000-(localPoint and g.t=="turnin" and 1200 or localPoint and 200 or 0) end
    if g.t=="accept" then
        local m=meta(g.quest) or {};local connected=false
        for _,list in ipairs({m.preAll or {},m.pre or {}}) do for _,id in ipairs(list) do if J.QuestDone(id) then connected=true end end end
        if connected then return -2500-(localPoint and 1000 or 0) end
    end
    return score
end
function P.Next(inside)
    local candidates={}
    local best,score
    local map=ns.API.Call("C_Map","GetBestMapForUnit","player")
    local choices=(ns.char.dungeonJourney or {}).quests or {}
    for _,r in ipairs(J.Routes()) do if r.planSlug and identity(r.planQuest) then
        local g=P.Goal(r)
        local inRun=inside and g and r.planSlug==inside and g.quest==r.planQuest and J.OnQuest(g.quest)
            and (g.t=="complete" and not g.map or g.t=="turnin" and g.interior)
            and choices[r.planSlug..":"..r.planQuest]~=false
        if inRun or not inside and P.Enabled(r) then
            local active=g.quest and J.OnQuest(g.quest)
            local ready=identity(g.quest) and (r.planErrand or r.planContinuity or r.planWestfall or P.Needed(r.planQuest,g.quest)) and not J.GoalDone(g) and not J.Blocked(g)
            if g.t=="accept" and ns.QuestSupplies and not ns.QuestSupplies.Eligible(g.quest) then ready=false end
            local due=ns.State.level>=r.planTarget
            -- Prepare nearby pickups ahead of the trip; do not drag a low-level
            -- character across the world for every future dungeon.
            local minimum=g.minLevel or (meta(g.quest) or {}).min or 1
            local eligible=inRun or g.t=="accept" and (due or g.map==map and ns.State.level>=minimum and not g.enrouteDestination)
                or g.t=="complete" and active and (due or g.quest~=r.planQuest)
                or g.t=="turnin" and active and J.ReadyToTurnIn(g.quest)
            if r.planSlug=="alcaz-prison" and g.t=="accept" and (not g.map or g.map~=map)
                and ns.char.preferredDungeonTrip~="alcaz-prison" then eligible=false end
            if r.planRedridge and g.t~="accept" and g.t~="turnin" then eligible=active end
            if r.planHandoff and g.quest==121 and g.map~=map then eligible=false end
            if r.planContinuity and not ns.RouteContinuity.LocalReturn(r,map) then eligible=false end
            if r.planWestfall then eligible=map==1436 and J.OnQuest(g.quest) end
            if r.planErrand then
                if g.t=="accept" then eligible=g.map==map
                elseif g.t=="turnin" then eligible=active and J.ReadyToTurnIn(g.quest)
                    and (g.quest==118 or g.map==map)
                else eligible=g.map==map and J.OnQuest(116) end
                if r.planErrand=="hops" then eligible=eligible and (ns.State.owned[1262] or 0)==0 end
                if r.planErrand=="thunderbrew" then eligible=eligible and (ns.State.owned[1274] or 0)>=5 end
            end
            if ready and eligible then
                if r.planErrand and g.item then
                    local saved=ns.char.routes[r.id]
                    if saved and (saved[1]=="confirmed" or saved[1]==true) then saved[1]=nil end
                end
                J.ReconcileRoute(r)
                if not J.Finished(r) then
                    local s=P.Priority(r,map)
                    candidates[#candidates+1]={route=r,goal=g,score=s}
                    if not best or s<score or s==score and r.id<best.id then best,score=r,s end
                end
            end
        end
    end end
    if P.ChooseTrip then return P.ChooseTrip(candidates,map) end
    return best,score
end
local selected=J.Selected
function J.Selected()
    local r=selected()
    if J.Speedrunning() then return r end
    local dungeon=ns.Journal.Current and ns.Journal.Current()
    local inside=dungeon and dungeon.slug
    local committedRun=inside and ns.char.itinerary and ns.char.itinerary.family==inside
        and ns.char.itinerary.route==r.id
    if inside and not ns.char.journeyPaused and (J.AutomaticContext() or committedRun or r.id=="dungeon:"..inside) then
        local candidate=P.Next(inside)
        if candidate then
            if candidate.id~=r.id then
                if not r.planSlug then J.PushReturn(r.id,ns.char.routeMode) end
                ns.char.route=candidate.id;ns.char.routeMode="manual"
                if P.CommitTrip then P.CommitTrip(candidate) end
            end
            return candidate
        end
        return {id="instance-hold:"..inside,name=dungeon.name,category="Dungeon action",steps={},planSlug=inside,instanceHold=true}
    end
    local map=ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"))
    local committed=ns.char.itinerary and ns.char.itinerary.route==r.id
    local awayReturn=r.planContinuity and committed
        and ns.RouteContinuity and not ns.RouteContinuity.LocalReturn(r,map)
    if r.planSlug and committed and (not P.Enabled(r) or awayReturn) and ns.char.routeReturn then
        local previous=ns.char.routeReturn;ns.char.routeReturn=previous.parent
        ns.char.route=previous.id;ns.char.routeMode=previous.mode;r=selected()
        committed=ns.char.itinerary and ns.char.itinerary.route==r.id
    end
    if r.planSlug and committed and not ns.char.journeyPaused and ns.char.routeReturn then
        local candidate,priority=P.Next()
        local map=ns.API.Call("C_Map","GetBestMapForUnit","player")
        local inside=ns.TripPlanning and ns.TripPlanning.instanceSlug==r.planSlug
        if candidate and not inside and (not ns.RouteContinuity or ns.RouteContinuity.CanInterrupt(r,candidate)) and (P.SwitchTrip and P.SwitchTrip(r,candidate,priority,map) or not P.SwitchTrip and priority<P.Priority(r,map)) then
            ns.char.route=candidate.id;if P.CommitTrip then P.CommitTrip(candidate) end;return candidate
        end
    end
    if r.planSlug or ns.char.journeyPaused or ns.char.routeMode~="auto" or (r.category~="Leveling" and r.category~="Class") then return r end
    local nextRoute=P.Next()
    if not nextRoute then return r end
    if ns.RouteContinuity and not ns.RouteContinuity.CanInterrupt(r,nextRoute) then return r end
    -- One source-backed phase at a time; preserve the exact class/leveling
    -- context and its existing parent return instead of replacing it.
    J.PushReturn(r.id,ns.char.routeMode)
    ns.char.route=nextRoute.id;ns.char.routeMode="manual"
    if P.CommitTrip then P.CommitTrip(nextRoute) end
    return nextRoute
end
function J.ClassPlanReady(route)
    for i,step in ipairs(route.steps or {}) do if not J.Status(route,i) and J.Applies(step.only) then
        for _,g in ipairs(step.goals or {}) do if J.Applies(g.only) and not J.GoalDone(g) then
            return not step.tripLevel or ns.State.level>=step.tripLevel
        end end
    end end
    return true
end
