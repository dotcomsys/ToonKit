local addonName, ns = ...
local G,J=ns.Gear,ns.Journey
-- Evidence describes what is known, without treating cached stats as a drop observation.
function G.DataEvidence(item)
    if item.classic then return "Classic reference; Forever availability unverified" end
    if item.capEquipped or item.source=="Currently equipped" or item.source=="In your bags" then return "Owned item | Live client stats" end
    if item.catalog and item.corroborated then return "Corroborated Forever catalogs | Drop not observed" end
    if item.sourceKnown or item.capSourceKnown then return "Source-listed acquisition | Live client stats" end
    return "Reference | Acquisition unverified"
end
function G.SourceConditions(r)
    if r.faction and r.faction~="both" and r.faction:lower()~=(ns.State.faction or ""):lower() then return false end
    for _,entry in ipairs({{r.classes,ns.State.classID,ns.State.class},{r.races,ns.State.raceID,ns.State.raceToken}}) do
        if type(entry[1])=="table" and #entry[1]>0 then
            local matches=false;for _,value in ipairs(entry[1]) do if value==entry[2] or tostring(value):lower():gsub("[^%w]","")==tostring(entry[3]):lower():gsub("[^%w]","") then matches=true end end
            if not matches then return false end
        end
    end
    return true
end
function G.HuntProfile(tree,role,level)
    tree=tree or ns.char.gearTree or "auto"
    local planName=type(tree)=="string" and tree:match("^plan:(.+)$")
    local plan=planName and ns.char.builds and ns.char.builds[planName]
    local ranks,valid
    local resolved=tree=="auto" and ns.Talents.specKey or tree
    if planName then
        valid=false
        if plan and plan.class==ns.State.class and type(plan.ranks)=="table" then
            local ok,legal=pcall(ns.Talents.Valid,plan.ranks,level or ns.Rules.Cap());valid=ok and legal==true
        end
        if valid then
            ranks=ns.Copy(plan.ranks);local totals={0,0,0}
            for key,rank in pairs(ranks) do local index=tonumber(key:match("^(%d+):"));if index and totals[index] then totals[index]=totals[index]+rank end end
            local top=1;for index=2,3 do if totals[index]>totals[top] then top=index end end
            resolved=tostring(top)
        else resolved="unresolved" end
    end
    local definition=ns.Talents.Definitions()[tonumber(resolved)]
    role=role or ns.char.gearRole or "auto"
    local selected=role~="auto" and role or definition and (ns.Data.treeRoles[ns.State.class] or {})[tonumber(resolved)] or ns.State.role
    if role=="auto" and tree=="auto" and ns.char.playstyle~="auto" and ns.Data.priorities[ns.char.playstyle] then selected=ns.char.playstyle end
    local signature={}
    for key,rank in pairs(ranks or {}) do signature[#signature+1]=key.."="..rank end;table.sort(signature)
    return {tree=resolved,role=selected or "unknown",name=planName or definition and definition.name or ns.Talents.detected,
        plan=planName,ranks=ranks,valid=valid,level=level or ns.State.level,rankSignature=table.concat(signature,","),
        live=not planName and resolved==ns.Talents.specKey and selected==ns.State.role and ns.Talents.available and ns.Talents.mismatches==0}
end
function G.IsCurrentUpgrade(item,slot)
    local comparison=item and item.capComparison
    local delta=comparison and ns.Safe(comparison.delta)
    if item and item.info and item.info.classID==2 and (ns.State.role=="melee" or ns.State.role=="ranged") then
        local equipped=slot and ns.State.equipment[slot]
        if equipped and equipped.id then
            local current=equipped.link and G.Facts(equipped.link)
            if not current or type(current.dps)~="number" or type(item.capDPS)~="number" or item.capDPS<current.dps then return false end
            local off=ns.State.equipment[17]
            if item.info.equip=="INVTYPE_2HWEAPON" and off and off.id then
                if not off.info or off.info.classID==2 then return false end
            end
        end
    end
    return item and not item.classic and not item.capEquipped and item.capUsable==true and item.capEquipAllowed==true
        and item.capSourceKnown==true and not item.capIncomplete and not item.capFuture
        and math.max(item.required or 1,item.info and item.info.required or 1)<=ns.State.level
        and type(delta)=="number" and delta==delta and delta<math.huge and delta>0
        and not (comparison.loadout and comparison.loadout.partial) or false
end
function G.HuntSummary(data,profile)
    local sum,count,recommendations=0,0,{}
    for slot,list in pairs(data) do
        local best=list.ranked[1];local equipped=ns.State.equipment[slot]
        local current=equipped and G.Evaluate(equipped.link,profile,slot)
        if best and best.capScore and best.capScore>0 and current then
            local ratio=current.score/best.capScore
            if best.info.classID==2 and (profile.role=="melee" or profile.role=="ranged") and best.capDPS and best.capDPS>0 and equipped and equipped.link then
                local facts=G.Facts(equipped.link);if facts.dps then ratio=facts.dps/best.capDPS end
            end
            sum=sum+math.max(0,math.min(100,ratio*100));count=count+1
        end
        local r
        for _,candidate in ipairs(list.ranked or {}) do
            if G.IsCurrentUpgrade(candidate,slot) and (ns.State.owned[candidate.id] or 0)==0
                and (not r or candidate.capComparison.delta>r.capComparison.delta or candidate.capComparison.delta==r.capComparison.delta and candidate.id<r.id) then r=candidate end
        end
        if G.IsCurrentUpgrade(r,slot) and (ns.State.owned[r.id] or 0)==0 then
            recommendations[#recommendations+1]={slot=slot,rank=1,item=r}
        end
    end
    table.sort(recommendations,function(a,b)
        if a.rank~=b.rank then return a.rank<b.rank end
        local ad=a.item.capComparison and a.item.capComparison.delta or 0
        local bd=b.item.capComparison and b.item.capComparison.delta or 0
        if ad~=bd then return ad>bd end
        return a.slot<b.slot
    end)
    return count>0 and sum/count or nil,recommendations,count
end
function G.PlanReference(r)
    if not r or not r.info or r.classic or r.referenceOnly or not G.SourceConditions(r) or ns.API.ItemEligibility(r.id,r.info)~=true then return false end
    ns.char.farming[r.id]={id=r.id,source=r.source,quest=r.quest,dungeon=r.dungeon,boss=r.boss,
        bossKey=r.bossKey or r.encounter and r.encounter.id,reference=not (r.capSourceKnown or r.sourceKnown or r.foreverLive),sourceKind=r.sourceKind,
        map=r.map,x=r.x,y=r.y,locations=ns.Copy(r.locations),requirements=r.requirements,provenance=r.provenance,
        obtained=(ns.State.owned[r.id] or 0)>0,planned=true,
        sourceKnown=r.sourceKnown,capSourceKnown=r.capSourceKnown,foreverLive=r.foreverLive}
    if ns.char.gearRemovedTargets then ns.char.gearRemovedTargets[r.id]=nil end
    ns.Emit("STATE_CHANGED");return true
end
-- Reuse exact source actions for navigation. No coordinates are inferred from
-- a boss name, item name, quest title or a cached item's existence.
function G.HuntSourceGoal(quest,wanted)
    local routes=J.RouteSource()
    if G.sourceRoutes~=routes then
        G.sourceRoutes=routes;G.sourceGoals={}
        for _,route in ipairs(routes) do for _,step in ipairs(route.steps or {}) do for _,goal in ipairs(step.goals or {}) do
            if goal.quest then
                local list=G.sourceGoals[goal.quest] or {};G.sourceGoals[goal.quest]=list
                list[#list+1]={route=route,step=step,goal=goal}
            end
        end end end
    end
    for _,entry in ipairs(G.sourceGoals[quest] or {}) do
        local route,step,g=entry.route,entry.step,entry.goal
        if J.Applies({classes=route.classes,races=route.races,factions=route.faction and {route.faction}}) and J.Applies(step.only) and J.Applies(g.only)
            and (g.t==wanted or wanted=="objective" and (g.t=="kill" or g.t=="collect" or g.t=="complete" or g.t=="interact") and not J.GoalDone(g)) then return g end
    end
end
function G.HuntGoal(id,record)
    local target=record or ns.char.farming[id];if not target then return end
    local info=ns.API.Item(id);local source
    local stored=ns.Storage and ns.Storage.PersonalLocation(id)
    if stored and (ns.State.owned[id] or 0)==0 then
        return {id="hunt:"..id..":retrieve",t="hunt",item=id,hunt=id,title=info and info.name or "Item #"..id,
            text="Retrieve "..(info and info.name or "Item #"..id),
            note="Recorded "..stored.count.." in "..stored.label..". Check that storage before farming another copy. This snapshot may have changed; completion waits until the item is carried or equipped."}
    end
    local notes={target.source or "Recorded source"}
    if target.requirements then notes[#notes+1]=target.requirements end
    if target.required and target.required>ns.State.level then notes[#notes+1]="Planned for level "..target.required.."; not an equip-now recommendation." end
    if target.reference then notes[#notes+1]="Source-listed reference; availability is unconfirmed." end
    if target.quest then
        local quest=target.quest;local phase=J.QuestDone(quest) and "turnin" or J.OnQuest(quest) and (ns.Safe(ns.API.Call("C_QuestLog","IsComplete",quest)) and "turnin" or "objective") or "accept"
        local find=G.HuntSourceGoal
        source=find(quest,phase)
        local seen={}
        while source and phase=="accept" and not seen[quest] do
            seen[quest]=true;local missing=J.MissingPrerequisites(source)
            if #missing==0 then break end
            local prior=type(missing[1])=="table" and (missing[1].id or missing[1].quest) or missing[1]
            if type(prior)~="number" then break end
            quest=prior;phase=J.OnQuest(quest) and (ns.Safe(ns.API.Call("C_QuestLog","IsComplete",quest)) and "turnin" or "objective") or "accept";source=find(quest,phase)
        end
        notes[#notes+1]=source and J.GoalText(source) or "Open the quest details for its native objectives and prerequisite information."
    end
    local point=source and ns.Navigation.FinalLocation(source)
    if not point and (target.map and target.x and target.y or target.locations) then
        point=ns.Navigation.FinalLocation({id="hunt-source:"..id,map=target.map,x=target.x,y=target.y,locations=target.locations})
        notes[#notes+1]=target.sourceKind=="world" and "Source-listed drop area; no spawn or drop is guaranteed." or "Source-listed NPC area; current presence and stock are unconfirmed."
    end
    if target.requirements then notes[#notes+1]=target.requirements end
    if not point and target.dungeon then
        local dungeon=ns.Journal.Get(target.dungeon)
        if dungeon and dungeon.entrance then point=dungeon.entrance;notes[#notes+1]="Waypoint: dungeon entrance. Follow the boss source inside." end
    end
    if not point then notes[#notes+1]="No exact sourced waypoint is available for this phase." end
    local blocked=source and J.Blocked(source)
    local goal={id="hunt:"..id..":obtain",t="hunt",item=id,title=info and info.name or "Item #"..id,
        text="Obtain "..(info and info.name or "Item #"..id),note=table.concat(notes,"\n"),hunt=id,huntBlock=blocked}
    if point then goal.map=point.map;goal.x=point.x;goal.y=point.y end
    return goal
end
function G.HuntMarkers()
    local key=table.concat({ns.stateEpoch or 0,ns.State.itemRevision or 0,ns.State.revision or 0},":")
    if G.markerKey==key then return G.markers end
    local ids,rows={},{}
    for id,target in pairs(ns.char.farming or {}) do
        if not target.obtained and (ns.State.owned[id] or 0)==0 then ids[#ids+1]=id end
    end
    table.sort(ids)
    for _,id in ipairs(ids) do
        local target=ns.char.farming[id];local goal=G.HuntGoal(id,target)
        if goal and goal.map and goal.x and goal.y then
            rows[#rows+1]={id=id,name=goal.title,map=goal.map,x=goal.x,y=goal.y,
                source=target.source,reference=target.reference==true,blocked=goal.huntBlock,active=ns.char.activeHunt==id}
        end
    end
    G.markerKey=key;G.markers=rows;return rows
end
local routes=J.Routes
function J.Routes()
    local list=routes()
    if G.buildingRoute or not ns.char or not ns.char.activeHunt or not ns.char.farming[ns.char.activeHunt] then return list end
    local id=ns.char.activeHunt
    local key=tostring(ns.State.revision)..":"..id
    if G.routeKey~=key then
        G.buildingRoute=true
        local ok,goal=pcall(G.HuntGoal,id);G.buildingRoute=nil
        if not ok then error(goal) end
        G.huntRoute={id="gear-hunt:"..id,name="Gear hunt: "..goal.title,category="Gear",min=1,max=ns.Rules.Cap(),steps={{id="hunt:"..id,text=goal.text,detail=goal.note,goals={goal}}}}
        G.routeKey=key
    end
    local out={};for _,route in ipairs(list) do out[#out+1]=route end;out[#out+1]=G.huntRoute;return out
end
local goalDone,goalText,automatic,progress,blocked=J.GoalDone,J.GoalText,J.AutomaticGoal,J.Progress,J.Blocked
function J.Blocked(goal) if goal and goal.t=="hunt" then return goal.huntBlock end;return blocked(goal) end
function J.GoalDone(goal)
    if goal and goal.t=="hunt" then return (ns.State.owned[goal.item] or 0)>0 or (ns.char.farming[goal.item] or {}).obtained==true,"native-item-acquisition" end
    return goalDone(goal)
end
function J.GoalText(goal) if goal and goal.t=="hunt" then return goal.text end;return goalText(goal) end
function J.AutomaticGoal(goal) if goal and goal.t=="hunt" then return true end;return automatic(goal) end
function J.Progress(goal) if goal and goal.t=="hunt" then return (ns.State.owned[goal.item] or 0).." / 1 obtained" end;return progress(goal) end
function G.FollowHunt(id)
    local target=ns.char.farming[id];if not target or target.obtained or (ns.State.owned[id] or 0)>0 then return false end
    local previous=J.Selected()
    if previous.id=="gear-hunt:"..id then return true end
    local saved=previous.category=="Gear" and ns.Copy(ns.char.routeReturn) or {id=previous.id,mode=ns.char.routeMode,parent=ns.Copy(ns.char.routeReturn)}
    ns.char.activeHunt=id;G.routeKey=nil
    if J.Select("gear-hunt:"..id,"manual") then ns.char.routeReturn=saved;ns.Emit("STATE_CHANGED");return true end
    return false
end
function G.StopFollowing()
    if ns.char.route=="gear-hunt:"..tostring(ns.char.activeHunt) then J.Return() end
    ns.char.activeHunt=nil;G.routeKey=nil;ns.Emit("STATE_CHANGED")
end
function G.UntrackHunt(id)
    if ns.char.activeHunt==id then G.StopFollowing() end
    if ns.char.farming[id] then
        ns.char.gearRemovedTargets=ns.char.gearRemovedTargets or {}
        ns.char.gearRemovedTargets[id]=ns.Copy(ns.char.farming[id])
    end
    ns.char.farming[id]=nil;ns.Emit("STATE_CHANGED")
end
function G.RefreshHuntRanks(profile)
    if not ns.char or not ns.db.settings.modules.gear then return end
    local key=tostring(ns.State.inventoryRevision)..":"..tostring(ns.State.itemRevision or 0)..":"..tostring(ns.Talents.revision or 0)..":"..G.ScoringKey(profile)..":"..ns.State.level..":"..ns.Rules.Cap()
    if G.rankInput==key then return end
    local data=G.CapTargets(ns.State.level,profile);local ranks={}
    for slot,list in pairs(data) do for rank,r in ipairs(list.ranked) do
        ranks[r.id]=ranks[r.id] or {};ranks[r.id][#ranks[r.id]+1]={slot=slot,rank=rank,total=#list.ranked,delta=r.capComparison and r.capComparison.delta}
    end end
    G.huntRanks=ranks;G.rankInput=key
end
ns.Listen("STATE_CHANGED",function(kind)
    if not ns.Changed(kind,"inventory","quests","identity","talents","journey") then return end
    G.routeKey=nil
    local flags=type(kind)=="table" and kind or {[kind or "manual"]=true}
    if flags.all or flags.inventory or flags.identity or flags.talents or flags.manual then G.huntRanks=nil;G.rankInput=nil end
end)
ns.Listen("SETTINGS_CHANGED",function() G.routeKey=nil;G.huntRanks=nil;G.rankInput=nil end)
