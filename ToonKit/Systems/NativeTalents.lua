local addonName, ns = ...
local T=ns.Talents
function T.Key(tree,index)
    local definition=T.Definitions()[tree] and T.Definitions()[tree].talents[index]
    return tree..":"..tostring(definition and definition.node or index)
end
function T.Definition(key)
    if type(key)~="string" then return end
    local tree,node=key:match("^(%d+):(%d+)$");tree=tonumber(tree);node=tonumber(node)
    local group=tree and T.Definitions()[tree]
    for index,definition in ipairs(group and group.talents or {}) do
        if definition.node==node then return definition,tree,index end
    end
end
function T.NativeConfig()
    local group=ns.Safe(ns.API.Call("C_SpecializationInfo","GetActiveSpecGroup"))
    local candidates={}
    local grouped=group and ns.Safe(ns.API.Call("C_SpecializationInfo","GetCombatConfigIDForSpecGroup",group))
    local active=ns.Safe(ns.API.Call("C_ClassTalents","GetActiveConfigID"))
    if type(grouped)=="number" and grouped>0 then candidates[#candidates+1]=grouped end
    if type(active)=="number" and active>0 and active~=grouped then candidates[#candidates+1]=active end
    for _,id in ipairs(candidates) do
        local info=ns.API.Call("C_Traits","GetConfigInfo",id)
        if info and type(info.treeIDs)=="table" and #info.treeIDs>0 then return id end
    end
end
function T.NativeRank(node)
    local rank=0
    for _,field in ipairs({"ranksPurchased","currentRank","activeRank"}) do
        local value=ns.Safe(node[field]);if type(value)=="number" and value>=0 then rank=math.max(rank,value) end
    end
    local entry=node.activeEntry and ns.Safe(node.activeEntry.rank)
    if type(entry)=="number" and entry>=0 then rank=math.max(rank,entry) end
    return rank
end
function T.Read()
    if not ns.char then return end
    local config=T.NativeConfig();local info=config and ns.API.Call("C_Traits","GetConfigInfo",config)
    local groups,byGroup={},{}
    for _,treeID in ipairs(info and info.treeIDs or {}) do
        for _,g in ipairs(ns.API.Call("C_Traits","GetGroupDisplayInfoByTreeID",treeID) or {}) do
            local id=ns.Safe(g.groupID)
            if type(id)=="number" and not byGroup[id] then
                local record={id=id,name=ns.Safe(g.displayName,"Talent tree"),order=ns.Safe(g.orderIndex,0),nodes={}}
                groups[#groups+1]=record;byGroup[id]=record
            end
        end
        for _,id in ipairs(ns.API.Call("C_Traits","GetTreeNodes",treeID) or {}) do
            local node=ns.API.Call("C_Traits","GetNodeInfo",config,id)
            if node and ns.Safe(node.isVisible,true) then
                local group
                for _,groupID in ipairs(node.groupIDs or {}) do if byGroup[ns.Safe(groupID)] then group=byGroup[ns.Safe(groupID)];break end end
                local entryID=node.activeEntry and ns.Safe(node.activeEntry.entryID) or node.entryIDs and ns.Safe(node.entryIDs[1])
                local entry=entryID and ns.API.Call("C_Traits","GetEntryInfo",config,entryID)
                local def=entry and entry.definitionID and ns.API.Call("C_Traits","GetDefinitionInfo",entry.definitionID)
                local spellID=def and ns.Safe(def.spellID)
                local spell=spellID and ns.API.Call("C_Spell","GetSpellInfo",spellID)
                local name=def and ns.Safe(def.overrideName) or spell and ns.Safe(spell.name)
                if name=="" then name=spell and ns.Safe(spell.name) end
                if spellID and not spell then ns.API.Call("C_Spell","RequestLoadSpellData",spellID) end
                local maximum=math.max(ns.Safe(node.maxRanks,0),entry and ns.Safe(entry.maxRanks,0) or 0)
                if group and name and spellID and maximum>0 then
                    group.nodes[#group.nodes+1]={node=id,name=name,spellID=spellID,max=maximum,x=ns.Safe(node.posX,0),y=ns.Safe(node.posY,0),icon="INV_Misc_QuestionMark",rank=T.NativeRank(node),nativeIcon=spell and ns.Safe(spell.iconID),entryID=entryID,available=ns.Safe(node.isAvailable,false)}
                end
            end
        end
    end
    table.sort(groups,function(a,b) if a.order~=b.order then return a.order<b.order end;return a.id<b.id end)
    local trees,spells={},{}
    for _,g in ipairs(groups) do
        if #g.nodes>0 and #trees<3 then
            local ti=#trees+1
            local xs,ys,xseen,yseen={},{},{},{}
            for _,d in ipairs(g.nodes) do if not xseen[d.x] then xs[#xs+1]=d.x;xseen[d.x]=true end;if not yseen[d.y] then ys[#ys+1]=d.y;yseen[d.y]=true end end
            table.sort(xs);table.sort(ys)
            local xindex,yindex={},{};for i,v in ipairs(xs) do xindex[v]=i end;for i,v in ipairs(ys) do yindex[v]=i end
            table.sort(g.nodes,function(a,b) if a.y~=b.y then return a.y<b.y end;return a.x<b.x end)
            local definitions={}
            for _,d in ipairs(g.nodes) do d.col=xindex[d.x];d.row=yindex[d.y];d.native=true;definitions[#definitions+1]=d;spells[d.name]={d.spellID} end
            trees[ti]={name=g.name,icon="INV_Misc_Book_09",talents=definitions,native=true}
        end
    end
    if #trees==3 then
        local stamp=T.BuildStamp()
        if ns.char.nativeTalentStamp~=stamp then
            ns.char.legacyTalentPlans=ns.char.legacyTalentPlans or {}
            if next(ns.char.builds or {}) then ns.char.legacyTalentPlans[#ns.char.legacyTalentPlans+1]={build=ns.char.nativeTalentStamp or "historical",builds=ns.Copy(ns.char.builds),draft=ns.Copy(ns.char.draft),active=ns.char.activeBuild} end
            ns.char.builds={};ns.char.draft={};ns.char.draftOrder={};ns.char.activeBuild=nil;ns.char.nativeTalentStamp=stamp
        end
        ns.Data.talents=ns.Data.talents or {}
        ns.Data.talentSpells=ns.Data.talentSpells or {}
        ns.Data.talents[ns.State.class]={trees=trees,source="Native Forever tree — "..stamp}
        ns.Data.talentSpells[ns.State.class]=spells;T.nativeDefinitions=true
    end
    if #trees~=3 then
        T.available=false;T.nativeDefinitions=false;T.actual={};T.totals={0,0,0};T.live={};T.nodes={};T.mismatches=0
        T.revision=(T.revision or 0)+1;T.readReason=config and "Native talent groups are not ready" or "Active native talent configuration is not ready"
        T.Detect();ns.State.talents=T.actual
        if not T.retryScheduled and (T.retryCount or 0)<3 then
            T.retryCount=(T.retryCount or 0)+1;T.retryScheduled=true
            C_Timer.After(T.retryCount,function() T.retryScheduled=false;if ns.State then ns.State.QueueRefresh("talents") end end)
        end
        return
    end
    -- Definitions and allocation came from the same live node: no name/rank-spell rematching.
    T.revision=(T.revision or 0)+1;T.actual={};T.totals={0,0,0};T.nodes={};T.live={};T.unmatched={};T.mismatches=0
    for ti,tree in ipairs(trees) do for index,d in ipairs(tree.talents) do
        local key=T.Key(ti,index);local rank=math.min(d.max,d.rank or 0)
        T.actual[key]=rank;T.totals[ti]=T.totals[ti]+rank
        local node={id=d.node,spell=d.spellID,name=d.name,rank=rank,max=d.max,icon=d.nativeIcon,available=d.available,match="native node identity"}
        T.nodes[key]=node;T.live[#T.live+1]=node
    end end
    T.available=true;T.nativeDefinitions=true;T.readReason=nil;T.retryCount=0
    T.Detect();ns.State.talents=T.actual
end
local valid=T.Valid
function T.Valid(ranks,level)
    if not T.nativeDefinitions then return false,"Current native Forever talent definitions are unavailable." end
    if type(ranks)~="table" then return false,"Invalid plan" end
    for key,rank in pairs(ranks) do
        local d=T.Definition(key)
        if not d or type(rank)~="number" or rank~=rank or rank~=math.floor(rank) or rank<0 or rank>d.max then return false,"Rank or native talent identity is unavailable." end
    end
    if T.Total(ranks)>T.Budget(level) then return false,"Point budget exceeded" end
    -- Preview is user intent, not a claim of native purchasability or allocation.
    return true
end
