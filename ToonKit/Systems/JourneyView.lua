local addonName, ns = ...
local J=ns.Journey
-- Present exact route item/object identities. Names never imply a live spawn.
function J.ObjectiveDetail(goal)
    local detail={};if not goal then return detail end
    if goal.item then
        local item=ns.API.Item(goal.item)
        detail.item=goal.item;detail.name=item and item.name or goal.itemName or "Item #"..goal.item
        detail.icon=item and item.icon or ns.Safe(ns.API.Call("C_Item","GetItemIconByID",goal.item))
        detail.link=item and item.link or "item:"..goal.item
    end
    if goal.from then
        detail.source=(goal.fromKind=="object" and "World object: " or "Loot from: ")..goal.from
        if goal.fromAlso then detail.source=detail.source.." / "..goal.fromAlso end
    elseif goal.objName then detail.source="World object: "..goal.objName end
    if goal.quest and goal.t=="collect" and J.OnQuest(goal.quest) and not J.PreparationCount(goal) and not J.ItemObjective(goal) then
        detail.unmatched=true
        detail.source="Live item objective not matched yet. Check the native quest log; this action cannot auto-complete from a numbered counter."
    end
    if goal.t=="collect" and goal.item and J.PreparationCount(goal) then detail.source="Preparation supply; not a numbered quest objective. "..(detail.source or "") end
    if goal.t=="collect" and J.ItemSourceConflict(goal) then
        detail.unmatched=true;detail.source="Item identity conflict between source and client. Source location advice is withheld; check the native quest log."
    end
    if detail.source and goal.spread and not detail.unmatched then detail.source=detail.source..". Search around the marked area." end
    if detail.item and not goal.itemName and (goal.t=="collect" or goal.t=="use" or goal.t=="buy") then detail.source="Item: "..detail.name..(detail.source and ". "..detail.source or "") end
    return detail
end
function J.Remember(kind,key,title)
    local route=J.Selected();local _,cursor=J.Current();local old=kind=="goal" and (ns.char.goalProgress or {})[key]
    ns.char.journeyUndo=ns.char.journeyUndo or {}
    local history=ns.char.journeyUndo
    history[#history+1]={kind=kind,key=key,title=title,old=old,cursor=cursor,route=route.id,mode=ns.char.routeMode,
        steps=ns.Copy(ns.char.routes[route.id] or {}),entry=ns.Copy((ns.char.routeEntries or {})[route.id]),live=ns.Copy(ns.char.liveHidden or {}),returnRoute=ns.Copy(ns.char.routeReturn),routingSnapshot=true,wetlandsProgress=ns.Copy(ns.char.wetlandsProgress),
        preferredDungeonTrip=ns.char.preferredDungeonTrip,stockadeAttackDeferred=ns.char.stockadeAttackDeferred}
    if #history>20 then table.remove(history,1) end
end
function J.Undo()
    local history=ns.char.journeyUndo or {};local record=table.remove(history)
    if not record then ns.Message("There is no manual action to undo.");return false end
    if record.kind=="skipBatch" then
        ns.char.goalProgress=ns.char.goalProgress or {}
        for id,old in pairs(record.goals or {}) do ns.char.goalProgress[id]=old~=false and old or nil end
    end
    if record.kind=="goal" then ns.char.goalProgress=ns.char.goalProgress or {};ns.char.goalProgress[record.key]=record.old end
    ns.char.routes[record.route]=record.steps;ns.char.routeEntries=ns.char.routeEntries or {};ns.char.routeEntries[record.route]=record.entry or (record.cursor and {index=record.cursor,level=ns.State.level,reason="Returned to your last action; earlier progress is unchanged"})
    ns.char.liveHidden=record.live;ns.char.route=record.route;ns.char.routeMode=record.mode;ns.char.routeReturn=record.returnRoute
    if record.routingSnapshot then ns.char.wetlandsProgress=record.wetlandsProgress;ns.char.preferredDungeonTrip=record.preferredDungeonTrip;ns.char.stockadeAttackDeferred=record.stockadeAttackDeferred end
    ns.Emit("STATE_CHANGED");return true
end
function J.Retrack()
    local route=J.Selected()
    local steps=J.Steps()
    local record
    local function remember()
        if not record then
            J.Remember("skipBatch",nil,"Retrack current guide")
            record=ns.char.journeyUndo[#ns.char.journeyUndo]
            record.goals={}
        end
    end
    local saved=ns.char.routes[route.id] or {}
    local progress=ns.char.goalProgress or {}
    local first
    local function restore(id)
        if not id then return end
        if record and record.goals[id] then return true end
        if progress[id]=="skipped" then
            remember()
            record.goals[id]=progress[id]
            progress[id]=nil
            return true
        end
    end
    for i,step in ipairs(steps) do
        local changed=saved[i]=="skipped"
        if route.live and ns.char.liveHidden and ns.char.liveHidden[step.quest] then
            remember()
            ns.char.liveHidden[step.quest]=nil
            changed=true
        end
        for _,goal in ipairs(step.goals or {}) do
            local own,source=restore(goal.id),restore(goal.sourceGoal)
            changed=changed or own or source
        end
        if changed then
            remember()
            first=first or i
            if saved[i]=="skipped" or saved[i] and not J.StepDone(step) then saved[i]=nil end
        end
    end
    local entry=(ns.char.routeEntries or {})[route.id]
    if first and entry and first<entry.index then entry.index=first end
    ns.char.journeyPaused=false
    J.focusGoal=nil
    ns.SetSetting("guide",true)
    J.Advance()
    ns.Emit("STATE_CHANGED")
    ns.Message(first and "Skipped actions are tracked again for this guide." or "Journey is tracking the current guide.")
end
function J.Pause()
    ns.char.journeyPaused=not ns.char.journeyPaused
    if not ns.char.journeyPaused then J.Advance() end
    ns.Emit("STATE_CHANGED")
end
function J.AutomaticGoal(g)
    if not g then return false end
    if g.t=="learn" then return C_SpellBook and type(C_SpellBook.IsSpellKnown)=="function" end
    return g.t=="accept" or g.t=="turnin" or g.t=="level" or g.t=="goto" and g.map and g.x and g.y
        or g.quest and g.oi or g.t=="complete" or (g.t=="collect" or g.t=="buy") and g.item
end
-- Accepted pickups remain distinct from their later collection/kill/turn-in stops.
function J.ScheduledLater(route,index,current)
    if not route or route.live or not index then return {} end
    local pickups={}
    for i=1,index do local step=route.steps[i]
        if step and J.Applies(step.only) then for order,g in ipairs(step.goals or {}) do
            if g.t=="accept" and g.quest and J.Applies(g.only) and J.OnQuest(g.quest)
                and not J.QuestDone(g.quest) and (not current or current.quest~=g.quest) then
                pickups[g.quest]={pickup=i,order=order,title=g.title}
            end
        end end
    end
    local rows={}
    for i=index+1,#(route.steps or {}) do local step=route.steps[i]
        if J.Applies(step.only) then for _,g in ipairs(step.goals or {}) do
            local pickup=pickups[g.quest]
            if pickup and not pickup.found and g.t~="accept" and J.Applies(g.only)
                and not J.OptionalDeferred(g) and not J.GoalDone(g) then
                pickup.found=true
                rows[#rows+1]={quest=g.quest,goal=g,step=i,place=step.text,pickup=pickup.pickup,order=pickup.order,
                    objective=g.t~="turnin",text="In quest log - later: "..J.GoalText(g).." at "..step.text}
            end
        end end
    end
    table.sort(rows,function(a,b)
        if a.pickup~=b.pickup then return a.pickup>b.pickup end
        if a.objective~=b.objective then return a.objective end
        if a.order~=b.order then return a.order>b.order end
        if a.step~=b.step then return a.step<b.step end
        return a.quest<b.quest
    end)
    return rows
end
-- A route stop is one task with independent native counters. Group only the
-- uninterrupted objective run containing the current action; travel, pickups,
-- turn-ins and explicit instructions remain ordered boundaries.
function J.TaskBundle(step,current)
    if not step or not current then return end
    local function objective(g)
        return g and g.quest and (g.t=="kill" or g.t=="collect" or g.t=="complete" or g.t=="interact")
    end
    if not objective(current) then return end
    local run={};local contains=false
    for _,g in ipairs(step.goals or {}) do
        if J.Applies(g.only) and not J.OptionalDeferred(g) then
            if objective(g) then
                run[#run+1]=g;if g.id==current.id then contains=true end
            else
                if contains then break end
                run={}
            end
        end
    end
    if not contains then return end
    if #run==1 and current.t=="complete" and not current.oi then
        local native=ns.API.Call("C_QuestLog","GetQuestObjectives",current.quest)
        if type(native)=="table" and #native>1 then
            run={}
            for oi,o in ipairs(native) do
                local copy=ns.Copy(current);copy.oi=oi;copy.nativeText=true;copy.title=ns.Safe(o.text,"Quest objective")
                -- These are presentation identities, never new saved progress keys.
                copy.id=nil;copy.sourceGoal=nil;run[#run+1]=copy
            end
        end
    end
    if #run<2 then return end
    local lines,details={},{};local finished=0
    for _,g in ipairs(run) do
        local done,evidence=J.GoalDone(g)
        if done then finished=finished+1 end
        local caption=J.GoalText(g)
        local progress=not g.nativeText and J.Progress(g)
        -- Only remove the source quantity when a readable live counter replaces it.
        if progress and progress:match("%d+%s*/%s*%d+") then caption=caption:gsub(" x%d+$","") end
        local detail=J.ObjectiveDetail(g)
        if detail.source then details[#details+1]=caption..": "..detail.source end
        if g.note then details[#details+1]=g.note end
        lines[#lines+1]=(done and (evidence=="skipped" and "Skipped: " or "Done: ") or "")..caption..(progress and "  "..progress or "")
    end
    return {goal=current,current=true,text=(step.text or "Complete this stop").."\n"..table.concat(lines,"\n"),
        taskTitle=step.text or "Complete this stop",members=run,details=details,bundled=true,finished=finished,total=#run}
end
local function nearbyQuestWork(steps,index,current)
    if not index or not current or not current.quest or not current.map
        or type(current.x)~="number" or type(current.y)~="number" then return end
    local function phase(g)
        if g.t=="accept" or g.t=="turnin" then return g.t end
        if g.t=="complete" or g.t=="kill" or g.t=="collect" or g.t=="interact" then return "objective" end
    end
    local kind=phase(current)
    if not kind then return end
    local rows,seen,started={},{[current.quest]=true},false
    for i=index,math.min(#steps,index+4) do
        local step=steps[i]
        if J.Applies(step.only) then
            for _,g in ipairs(step.goals or {}) do
                if g==current or (g.id and g.id==current.id) then started=true
                elseif started and J.Applies(g.only) and not J.OptionalDeferred(g) and not J.GoalDone(g) then
                    if phase(g)~=kind or not g.quest or g.map~=current.map or type(g.x)~="number" or type(g.y)~="number"
                        or (g.x-current.x)^2+(g.y-current.y)^2>.025^2 or J.Blocked(g) then return rows end
                    if not seen[g.quest] then
                        seen[g.quest]=true
                        rows[#rows+1]=J.GoalText(g)..(g.npcName and (" · "..g.npcName) or "")
                        if #rows==6 then return rows end
                    end
                end
            end
        end
    end
    return rows
end
function J.View()
    local route=J.Selected();local goal,step,index=J.Action();local steps=J.Steps()
    local view={route=route,goal=goal,step=step,index=index,total=#steps,paused=ns.char.journeyPaused,
        title=goal and (J.GoalText(goal)) or step and step.text or "Route complete",status="",hint="",nextTitle="",count=0,ordinal=0}
    view.context=(route.live and "Quest log" or route.planErrand and "Town errand" or (route.planHandoff or route.planContinuity) and "Journey handoff" or route.planSlug and "Dungeon preparation" or route.category=="Class" and "Class quest detour" or route.category=="Dungeon" and "Dungeon quest route" or ns.char.routeMode=="auto" and "Automatic leveling" or "Selected route").."  |  "..route.name
    if step then
        for _,g in ipairs(step.goals or {}) do if J.Applies(g.only) and not J.OptionalDeferred(g) then
            view.count=view.count+1;if goal and g.id==goal.id then view.ordinal=view.count end
        end end
        if view.count==0 and goal then view.count=1;view.ordinal=1 end
    end
    view.progress=index and ("Step "..index.." of "..#steps..(view.count>1 and (goal and "  |  Action "..view.ordinal.." of "..view.count or "  |  "..view.count.." actions complete") or "")) or "This route segment is finished"
    if not step and route.category=="Leveling" then
        local following=J.CampaignNext(route)
        if following then
            view.nextTitle=following.name
            if following.min>ns.State.level then
                view.waitingForLevel=following.min
                view.title="Reach level "..following.min
            elseif ns.char.routeMode=="manual" then view.manualNext=true end
        end
    end
    if goal then
        view.blocked=J.Blocked(goal);view.note=goal.t=="note" and (goal.text or goal.note or step and step.detail) or goal.note or step and step.detail
        if route.live then
            view.quest=step and step.text
            if goal.quest==2882 then
                if goal.t=="turnin" then
                    view.note="Use Cuergo's Key on the treasure chest at the flag in southern Tanaris."
                elseif goal.title and goal.title:find("Cuergo's Key",1,true) then
                    view.note="Click the Inconspicuous Landmark on the southern Tanaris coast. Loot the key from the treasure pirates, then open the chest."
                end
            end
        end
        if goal.npcName and (goal.t=="accept" or goal.t=="turnin") then
            view.contact=(goal.dungeon and (goal.t=="accept" and "Pickup: " or "Turn in to ") or "Speak with ")..goal.npcName
        end
        if goal.title and (goal.t=="kill" or goal.t=="collect" or goal.t=="interact") then view.quest="Quest: "..goal.title end
        view.amount=J.Progress(goal);view.manual=not J.AutomaticGoal(goal)
        local travel={fly="Flight",getfp="Flight path",hearth="Hearthstone",sethome="Set home",boat="Boat",zeppelin="Zeppelin",portal="Portal"}
        view.travel=travel[goal.t]
        if not view.travel and goal.t=="note" then
            local instruction=(goal.text or goal.note or ""):lower()
            if instruction:find("boat",1,true) then view.travel="Boat instructions"
            elseif instruction:find("zeppelin",1,true) then view.travel="Zeppelin instructions" end
        end
        if view.travel then
            view.contact=goal.npcName and ("Speak with "..goal.npcName) or nil
            view.travelInstructions=goal.note or step and step.detail or goal.text
            local travelHint=ns.Travel and ns.Travel.Hint(goal)
            if travelHint then view.travelInstructions=(view.travelInstructions and view.travelInstructions.."\n" or "")..travelHint end
            if goal.t=="note" then view.note=nil end
        end
        local serviceHint=ns.Services and ns.Services.Hint(goal)
        if serviceHint then
            if goal.t=="vendor" then view.contact=goal.npcName and ("Speak with "..goal.npcName) or nil end
            if view.travel then view.travelInstructions=serviceHint..(view.travelInstructions and "\n"..view.travelInstructions or "")
            else view.note=serviceHint..(view.note and "\n"..view.note or "") end
            view.service=true
        end
        if not view.blocked then
            view.point,view.connectionHint=ns.Navigation.Location(goal)
            local destination=view.point and ns.Navigation.FinalLocation(goal)
            if destination and view.point.map~=destination.map and view.point.map==ns.API.Position() then
                local name=view.point.label or view.point.npcName or view.point.name
                view.travelStop=name and ("First: "..name) or "First: follow the travel waypoint"
            end
        end
        if goal.t=="vendor" and not view.contact and view.point and view.point.npcName then view.contact="Speak with "..view.point.npcName end
        if view.blocked then view.status="Needs attention";view.hint=view.blocked
        elseif view.manual then view.status=goal.t=="note" and "Read, then continue" or "Confirm after doing this";view.hint=goal.t=="note" and "Read the instructions, then choose Done, next." or "Complete this action in game, then choose Done, next."
        else view.status="Tracking automatically";view.hint=ns.db.settings.autoAdvance and "Do this in game. Journey advances when completion is detected." or "Completion updates from the game. Choose Next step when the group is finished." end
        if view.travel and not view.blocked then
            view.hint="Follow the route's travel instructions. Confirm only after reaching the destination."
        end
        local actionHint=ns.ActionEvidence and ns.ActionEvidence.Hint(goal)
        if actionHint and not view.blocked then view.status="Watching native actions";view.hint=actionHint end
        if goal.optional and goal.t=="accept" and not view.blocked then
            view.hint="Optional quest available here. Accept it, or click Skip beside the action to decline it."
            view.note=(view.note and view.note.."\n" or "")..view.hint
        end
        view.actionNote=view.note
        local visit=ns.char.zoneVisit
        if visit and visit.route==route.id and ns.char.routeMode=="auto" then
            view.note=(view.note and view.note.."\n" or "").."Finish the manageable accepted quests for this zone visit. Elite/group work is deferred; Redridge level-25+ work waits until later. Deferred quests remain unfinished."
        end
        local tripHint=ns.DungeonJourney and ns.DungeonJourney.TripHint and ns.DungeonJourney.TripHint(route)
        if tripHint then
            view.tripChecklist=tripHint
            view.note=(view.note and view.note.."\n" or "")..tripHint
        end
        view.prerequisite,view.prerequisiteStep,view.pickup=J.Prerequisite(goal)
    elseif step then
        view.manual=true;view.confirmStep=not J.StepDone(step)
        view.status=view.confirmStep and "Confirm after doing this" or "Ready to continue"
        view.hint=view.confirmStep and "Follow these instructions, then choose Done, next." or "This group is finished. Choose Next step to continue."
    else
        local nextRoute=route.category=="Leveling" and J.CampaignNext(route)
        if view.waitingForLevel then
            view.status="Waiting for XP"
            view.hint=ns.char.routeMode=="manual" and "Finish open quests or earn outdoor XP. Choose Next guide after it unlocks."
                or "Finish open quests or earn outdoor XP. Journey resumes when this guide unlocks."
        else
            view.status="Segment complete"
            view.hint=nextRoute and ("The next route is "..nextRoute.name..". It starts at level "..nextRoute.min..".") or "Choose automatic leveling to find the next route for your character."
        end
    end
    if view.waitingForLevel or goal and goal.t=="level" then
        local xp=ns.Experience
        if xp and xp.level==ns.State.level and type(xp.xp)=="number" and type(xp.maximum)=="number" and xp.maximum>0 then
            local target=goal and goal.level==xp.level and goal.frac and math.ceil(xp.maximum*goal.frac) or xp.maximum
            if target>xp.xp then
                view.amount=(target-xp.xp).." XP remaining"..(target==xp.maximum and " to level "..(xp.level+1) or "")
            end
        end
    end
    -- Preview only a bounded part of the current route. Never imply future completion.
    local passed=not goal
    for n=index or (#steps+1),math.min(#steps,(index or #steps)+5) do
        if (n==index or not J.Status(route,n)) and J.Applies(steps[n].only) then for _,g in ipairs(steps[n].goals or {}) do
            if n==index and goal and g.id==goal.id then passed=true
            elseif passed and J.Applies(g.only) and not J.GoalDone(g) and not J.OptionalDeferred(g) then view.nextTitle=J.GoalText(g);break end
        end end
        if view.nextTitle~="" then break end
    end
    if route.instanceHold then
        view.title="Continue "..route.name;view.status="Dungeon in progress"
        view.hint="No unfinished in-instance quest is confirmed. Continue with your group. Journey resumes your route when you leave."
    elseif not step and route.live then
        local xp=ns.Experience
        view.title="No route tasks available";view.status="Waiting for quest work"
        view.hint="Open Leveling campaign for another zone, or accept a quest to follow it here."
        if ns.State.level<ns.Rules.Cap() and xp and xp.level==ns.State.level
            and type(xp.xp)=="number" and type(xp.maximum)=="number" and xp.maximum>xp.xp then
            view.amount=(xp.maximum-xp.xp).." XP to level "..(ns.State.level+1)
        end
    end
    if not step and route.category=="Leveling" and ns.State.level>=ns.Rules.Cap() then
        view.atCap=true;view.status="Active level cap reached";view.hint="The active planning limit is level "..ns.Rules.Cap()..". Your completed steps remain available in route review."
    end
    if (route.min or 1)>ns.Rules.Cap() then
        view.atCap=true;view.blocked="Above the active level-"..ns.Rules.Cap().." cap"
        view.status="Future campaign segment";view.hint="The 1-60 campaign is retained. Resume an eligible guide to continue within the current cap."
    end
    view.scheduledLater=J.ScheduledLater(route,index,goal)
    view.followup=ns.RouteContinuity and ns.RouteContinuity.Followup(goal)
    view.supplySummary=ns.RouteContinuity and ns.RouteContinuity.Supplies(goal)
    view.outsideCount=#J.QuestsOutsideRoute(route)
    local opportunity,pickup
    if not route.instanceHold and not (route.planSlug and ns.TripPlanning and route.planSlug==ns.TripPlanning.instanceSlug) then
        opportunity,pickup=J.ClassOpportunity()
    end
    if opportunity and opportunity.id~=route.id then
        view.classRoute=opportunity;view.classPickup=pickup
        view.classReminder="Class quest available: "..opportunity.name..". "..J.GoalText(pickup)
    end
    view.tripReminder=ns.TripPlanning and ns.TripPlanning.Reminder(route)
    view.stopPreview=nearbyQuestWork(steps,index,goal)
    view.serviceReminder=ns.Services and ns.Services.Reminder()
    -- Travel is a presentation phase of the real action, never a confirmation
    -- of its quest. Zone changes reveal the next leg without writing progress.
    if goal and not view.blocked and (not view.travel or goal.t=="getfp" or goal.t=="sethome") then
        local destination=ns.Navigation.FinalLocation(goal) or type(goal.map)=="number" and {map=goal.map}
        local map=ns.API.Position()
        local localTransport=destination and map==destination.map and ns.Travel and ns.Travel.Transport(destination,map)
        if destination and map and (map~=destination.map or localTransport) then
            local directions=localTransport or ns.Travel and ns.Travel.Directions(destination,map)
            local info=ns.API.Call("C_Map","GetMapInfo",destination.map)
            local name=type(info)=="table" and ns.Safe(info.name) or "Map #"..destination.map
            view.approach=true;view.travel=directions and ({hearth="Hearthstone",fly="Flight",boat="Boat",zeppelin="Zeppelin",tram="Tram"})[directions.kind] or "Travel";view.manual=false
            local purpose=goal.t=="accept" and "Pickup" or goal.t=="turnin" and "Turn-in" or "Destination"
            view.approachCaption=purpose.." · "..name
            view.travelInstructions=view.connectionHint or directions and directions.text or ("Quest destination: "..name..".")
            if directions and directions.itinerary~=directions.text then view.travelItinerary=directions.itinerary end
            if step and step.detail then view.travelInstructions=view.travelInstructions.."\nAt the destination: "..step.detail end
            view.status="On the way"
            view.hint="Use the map for the destination and open directions if you need them."
            local row={goal=goal,current=true,text=view.title,amount=view.amount}
            view.stepObjectives={row};view.objectives={row}
        end
    end
    if view.paused then view.status="Paused";view.hint="Resume Journey when you are ready. Your progress is saved.";view.point=nil end
    view.stepObjectives=view.approach and view.stepObjectives or {}
    local firstObjective=1
    for i,g in ipairs(step and step.goals or {}) do if goal and goal.id==g.id then firstObjective=math.max(1,i-2);break end end
    for i,g in ipairs(step and step.goals or {}) do
        if not view.approach and i>=firstObjective and #view.stepObjectives<20 and J.Applies(g.only) and not J.OptionalDeferred(g) then
            local done,evidence=J.GoalDone(g)
            local caption=J.GoalText(g)
            if done and evidence~="skipped" and g.t=="accept" and J.OnQuest(g.quest) then caption="Accepted: "..(g.title or "Quest");evidence="native-accepted" end
            view.stepObjectives[#view.stepObjectives+1]={goal=g,current=goal and goal.id==g.id,done=done==true,evidence=done and evidence or nil,
                text=caption,amount=not done and J.Progress(g) or nil}
        end
    end
    view.objectives=view.approach and view.objectives or {}
    if step and not view.approach then
        local started=not goal
        for _,g in ipairs(step.goals or {}) do
            if goal and g.id==goal.id then started=true end
            if started and #view.objectives<5 and J.Applies(g.only) and not J.OptionalDeferred(g) and not J.GoalDone(g) then
                view.objectives[#view.objectives+1]={goal=g,current=goal and g.id==goal.id,text=J.GoalText(g),amount=J.Progress(g)}
            end
        end
    end
    local bundle=not view.approach and J.TaskBundle(step,goal)
    if bundle then
        view.bundle=bundle;view.title=step.text or "Complete this stop"
        view.stepObjectives={bundle};view.objectives={bundle}
        view.progress="Step "..index.." of "..#steps.."  |  "..bundle.finished.." / "..bundle.total.." objectives finished"
        view.amount=nil
        view.nextTitle="" -- A member of this task is never presented as a later task.
    end
    if step and step.routeNextTitle and not view.approach then view.nextTitle=step.routeNextTitle end
    if step and step.circuitOrdinal then
        view.displayIndex=step.circuitOrdinal;view.displayTotal=step.circuitTotal
        view.progress=step.circuitPhase.." "..view.displayIndex.." of "..view.displayTotal
        if view.bundle then view.progress=view.progress.."  |  "..view.bundle.finished.." / "..view.bundle.total.." objectives finished" end
    end
    return view
end
-- One click declines an unavailable pickup and its explicit route dependents.
-- Store goal skips, never quest-completion flags, and undo the batch as one action.
function J.Skip(view,wholeTask)
    view=view or J.View()
    if view.paused or not view.goal then return end
    if ns.DungeonJourney and ns.DungeonJourney.DeferAttack(view) then return end
    local g=view.goal;local route=view.route or J.Selected();local quests={}
    if g.quest and not J.OnQuest(g.quest) and not J.QuestDone(g.quest) then quests[g.quest]=true end
    if g.t=="collect" and g.item and not g.quest then
        for _,step in ipairs(route.steps or {}) do for _,goal in ipairs(step.goals or {}) do
            if goal.t=="accept" and goal.item==g.item and goal.quest and not J.OnQuest(goal.quest) and not J.QuestDone(goal.quest) then quests[goal.quest]=true end
        end end
    end
    local changed=true
    while changed do
        changed=false
        for _,step in ipairs(route.steps or {}) do for _,goal in ipairs(step.goals or {}) do
            if goal.quest and not quests[goal.quest] and not J.OnQuest(goal.quest) and not J.QuestDone(goal.quest) then
                for _,pre in pairs(goal.pre or {}) do if quests[pre] then quests[goal.quest]=true;changed=true;break end end
            end
        end end
    end
    J.Remember("skipBatch",g.id,J.GoalText(g))
    local record=ns.char.journeyUndo[#ns.char.journeyUndo];record.goals={}
    ns.char.goalProgress=ns.char.goalProgress or {}
    local function skip(goal)
        if goal.id and ns.char.goalProgress[goal.id]~="skipped" then
            record.goals[goal.id]=ns.char.goalProgress[goal.id] or false
            ns.char.goalProgress[goal.id]="skipped"
            if goal.sourceGoal and goal.sourceGoal~=goal.id and ns.char.goalProgress[goal.sourceGoal]~="skipped" then
                record.goals[goal.sourceGoal]=ns.char.goalProgress[goal.sourceGoal] or false
                ns.char.goalProgress[goal.sourceGoal]="skipped"
            end
        end
    end
    skip(g)
    local bundle=wholeTask~=false and (view.bundle or J.TaskBundle(view.step,g))
    if bundle then for _,member in ipairs(bundle.members or {}) do if not J.GoalDone(member) then skip(member) end end end
    for _,step in ipairs(route.steps or {}) do for _,goal in ipairs(step.goals or {}) do
        if quests[goal.quest] then skip(goal) end
    end end
    J.Advance();ns.Emit("STATE_CHANGED")
end
function J.SkipLabel(view)
    if view.goal and view.goal.quest==434 and ns.State.level<30 and not J.ReadyToTurnIn(434) then return "Later (30)" end
    return "Skip task"
end
function J.SkipControl(view)
    return view.goal and (not view.manual or view.blocked or view.approach) and true or false
end
function J.Act(view)
    view=view or J.View()
    if view.paused then J.Pause() elseif J.SkipControl(view) then J.Skip(view) else J.Confirm(view) end
end
function J.Confirm(view)
    view=view or J.View()
    if view.paused or view.blocked or view.atCap or view.waitingForLevel then return end
    if view.goal and not view.manual then ns.Message("This action uses live quest evidence. Complete it in game, or click Skip beside it.");return end
    if view.goal then J.MarkGoal(view.goal,"manual") elseif view.index then
        local done,reason=J.StepDone(view.step);J.Mark(view.index,done and (reason or "confirmed") or "manual")
    elseif view.manualNext then J.NextRoute()
    else J.Automatic() end
end
function J.Destination(view)
    view=view or J.View()
    if view.paused then return end
    local goal=view.pickup or view.goal
    if goal and J.GoalWaypoint(goal) then return true end
    if goal and goal.quest and QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(goal.quest);return true end
    if goal then
        ns.Message("This action has no sourced waypoint. Follow its written instructions.")
    elseif view.step then
        J.Waypoint(view.step)
    end
end
