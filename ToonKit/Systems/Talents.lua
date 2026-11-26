local addonName, ns = ...
local T={ actual={}, nodes={}, totals={0,0,0} }; ns.Talents=T
function T.Definitions() local class=(ns.Data.talents or {})[ns.State.class]; return class and class.trees or {} end
function T.Key(tree,index) return tree..":"..index end
function T.Definition(key)
    if type(key)~="string" then return end
    local t,i=key:match("^(%d+):(%d+)$"); t,i=tonumber(t),tonumber(i)
    local tree=t and T.Definitions()[t]; return tree and tree.talents[i],t,i
end
function T.BuildStamp()
    local version,build=GetBuildInfo()
    return tostring(ns.Safe(version,"unknown"))..":"..tostring(ns.Safe(build,"unknown"))
end
function T.Display(key)
    local definition=T.Definition(key); local node=T.nodes[key]
    if not definition then return {} end
    local description=node and node.spell and ns.Safe(ns.API.Call("C_Spell","GetSpellDescription",node.spell))
    return {name=node and node.name or definition.name,icon=node and node.icon or "Interface\\Icons\\"..definition.icon,description=description,match=node and node.match}
end
function T.Read()
    T.revision=(T.revision or 0)+1
    T.actual,T.nodes,T.totals,T.live,T.unmatched={},{},{0,0,0},{},{}; T.available=false; T.mismatches=0
    local byName,bySpell,definitions={},{},{}
    local function add(index,value,record)
        if not value or value=="" then return end
        index[value]=index[value] or {}
        for _,existing in ipairs(index[value]) do if existing.key==record.key then return end end
        index[value][#index[value]+1]=record
    end
    for ti,tree in ipairs(T.Definitions()) do for i,d in ipairs(tree.talents) do
        local record={key=T.Key(ti,i),tree=ti,def=d}; definitions[record.key]=record
        add(byName,d.name,record)
        for _,id in ipairs(((ns.Data.talentSpells or {})[ns.State.class] or {})[d.name] or {}) do
            add(bySpell,id,record)
            local spell=ns.API.Call("C_Spell","GetSpellInfo",id)
            if spell then add(byName,ns.Safe(spell.name),record) end
        end
        -- Native name lookup may resolve a source name on localized clients. No icon/position guesses.
        local spell=ns.API.Call("C_Spell","GetSpellInfo",d.name)
        if spell then add(byName,ns.Safe(spell.name),record); add(bySpell,ns.Safe(spell.spellID),record) end
    end end
    local config=T.NativeConfig and T.NativeConfig() or ns.API.Call("C_ClassTalents","GetActiveConfigID")
    local info=config and ns.API.Call("C_Traits","GetConfigInfo",config)
    local bindings=(ns.char.talentBindings or {})[ns.State.class] or {}
    local stamp=T.BuildStamp(); local used={}; local found=0
    for _,treeID in ipairs(info and info.treeIDs or {}) do
        for _,nodeID in ipairs(ns.API.Call("C_Traits","GetTreeNodes",treeID) or {}) do
            local node=ns.API.Call("C_Traits","GetNodeInfo",config,nodeID)
            if node then
                local entryID=node.activeEntry and node.activeEntry.entryID or (node.entryIDs and node.entryIDs[1])
                local entry=entryID and ns.API.Call("C_Traits","GetEntryInfo",config,entryID)
                local def=entry and entry.definitionID and ns.API.Call("C_Traits","GetDefinitionInfo",entry.definitionID)
                local spellID=def and ns.Safe(def.spellID)
                local spell=spellID and ns.API.Call("C_Spell","GetSpellInfo",spellID)
                local name=def and ns.Safe(def.overrideName)
                if not name or name=="" then name=spell and ns.Safe(spell.name) end
                if spellID and not spell then ns.API.Call("C_Spell","RequestLoadSpellData",spellID) end
                local rank=ns.Safe(node.activeRank,ns.Safe(node.currentRank,ns.Safe(node.ranksPurchased,0)))
                local maximum=ns.Safe(node.maxRanks,entry and ns.Safe(entry.maxRanks,0) or 0)
                local live={id=nodeID,spell=spellID,definition=entry and entry.definitionID,name=name or ("Node #"..nodeID),rank=rank,max=maximum,
                    icon=def and ns.Safe(def.overrideIcon) or spell and ns.Safe(spell.iconID),available=ns.Safe(node.isAvailable,false),canPurchase=ns.Safe(node.canPurchaseRank,false)}
                if maximum>0 and def and ns.Safe(node.isVisible,true) then T.live[#T.live+1]=live end
                local overridden=def and ns.Safe(def.overriddenSpellID)
                local matches=spellID and bySpell[spellID] or overridden and bySpell[overridden]
                local method="spell identity"
                if not matches or #matches~=1 then matches=name and byName[name]; method="native name" end
                local match=matches and #matches==1 and matches[1]
                if not match then for key,binding in pairs(bindings) do
                    if binding.build==stamp and binding.node==nodeID and binding.spell==spellID and binding.definition==live.definition then match=definitions[key];method="manual identity";break end
                end end
                if match and not used[match.key] then
                    used[match.key]=true; T.actual[match.key]=rank; live.match=method; T.nodes[match.key]=live
                    T.totals[match.tree]=T.totals[match.tree]+rank; found=found+1
                    if maximum~=match.def.max then T.mismatches=T.mismatches+1 end
                else
                    if maximum>0 and def and ns.Safe(node.isVisible,true) then T.unmatched[#T.unmatched+1]=live end
                    if rank>0 then T.mismatches=T.mismatches+1 end
                end
            end
        end
    end
    T.available=found>0; T.Detect(); ns.State.talents=T.actual
end
function T.Bind(key,nodeID)
    local definition=T.Definition(key); local chosen
    for _,node in ipairs(T.live or {}) do if node.id==nodeID then chosen=node;break end end
    if not definition or not chosen or not chosen.spell then return false,"Select a source talent and a live talent." end
    if chosen.max~=definition.max then return false,"Rank caps differ. This node cannot safely use the bundled plan definition." end
    for other,node in pairs(T.nodes) do if other~=key and node.id==nodeID then return false,"This live talent is already matched to "..T.Display(other).name end end
    ns.char.talentBindings=ns.char.talentBindings or {};ns.char.talentBindings[ns.State.class]=ns.char.talentBindings[ns.State.class] or {}
    ns.char.talentBindings[ns.State.class][key]={node=nodeID,spell=chosen.spell,definition=chosen.definition,build=T.BuildStamp()}
    T.Read();ns.Emit("STATE_CHANGED");return true
end
function T.Detect()
    local order={1,2,3}; table.sort(order,function(a,b) return T.totals[a]>T.totals[b] end)
    local top,second=order[1],order[2]; local total=T.totals[1]+T.totals[2]+T.totals[3]
    T.hybrid=total>0 and T.totals[second]>0 and (T.totals[top]-T.totals[second]<=5 or T.totals[second]/total>=.35)
    local tree=T.Definitions()[top]
    T.detected=not T.available and "Allocation unavailable" or total==0 and "Unallocated" or T.hybrid and "Hybrid allocation" or ((tree and tree.name or "Unknown").." leaning")
    local roles=ns.Data.treeRoles[ns.State.class] or {}
    local tied=total>0 and T.totals[top]==T.totals[second]
    local mixedTie=tied and roles[top]~=roles[second]
    T.uncertain=ns.char.playstyle=="auto" and (not T.available or total==0 or mixedTie or T.mismatches>0)
    local manual=ns.char.playstyle~="auto" and ns.Data.priorities[ns.char.playstyle] and ns.char.playstyle or nil
    T.role=manual or ns.char.playstyle=="auto" and not T.uncertain and roles[top] or "unknown"
    if not ns.Data.priorities[T.role] then T.role="unknown" end
    T.specKey=T.available and total>0 and not mixedTie and T.mismatches==0 and tostring(top) or "unresolved"
    ns.State.spec=T.specKey~="unresolved" and tree and (tree.name..(T.hybrid and " (hybrid allocation)" or "")) or "Unresolved specialization"
    ns.State.role=T.role
end
function T.Total(ranks) local n=0;if type(ranks)~="table" then return n end; for _,v in pairs(ranks) do if type(v)=="number" and v==v and v~=math.huge and v~=-math.huge then n=n+v end end; return n end
function T.Budget(level) return math.max(0, math.min(level or ns.Rules.Cap(),ns.Rules.Cap())-9) end
function T.Valid(ranks,level)
    if type(ranks)~="table" then return false,"Invalid allocation" end
    for key,rank in pairs(ranks) do
        local d=T.Definition(key)
        if not d or type(rank)~="number" or rank~=rank or rank<0 or rank>d.max or rank~=math.floor(rank) then return false,"Invalid rank" end
    end
    if T.Total(ranks)>T.Budget(level) then return false,"Point budget exceeded" end
    for key,rank in pairs(ranks) do
        local d,ti=T.Definition(key)
        if rank>0 then
            local spent,prereq=0,not d.req
            for i,other in ipairs(T.Definitions()[ti].talents) do
                local r=ranks[T.Key(ti,i)] or 0
                if other.row<d.row then spent=spent+r end
                if other.name==d.req then prereq=r>=other.max end
            end
            if spent<(d.row-1)*5 then return false,"Spend more points in earlier tiers" end
            if not prereq then return false,"Requires "..d.req end
        end
    end
    return true
end
function T.Edit(key,delta)
    local definition=T.Definition(key)
    if not definition then return false,"Select a talent first." end
    local plan=ns.char.draft or {}; local next=ns.Copy(plan); next[key]=math.max(0,(next[key] or 0)+delta)
    if next[key]==(plan[key] or 0) then return false,"There are no planned points to remove." end
    local valid,reason=T.Valid(next,ns.char.previewLevel or ns.Rules.Cap())
    if not valid then return false,reason end
    ns.char.draft=next; ns.char.draftOrder=ns.char.draftOrder or {}
    ns.char.draftOrderOrigin="Personal planned purchase order"
    if delta>0 then table.insert(ns.char.draftOrder,key) else
        for i=#ns.char.draftOrder,1,-1 do if ns.char.draftOrder[i]==key then table.remove(ns.char.draftOrder,i); break end end
    end
    ns.Emit("STATE_CHANGED"); return true
end
function T.Save(name)
    name=(name or ""):match("^%s*(.-)%s*$"); if name=="" then ns.Message("Enter a build name."); return false end
    local ranks=ns.Copy(ns.char.draft or {}); local ok,reason=T.Valid(ranks,ns.char.previewLevel or ns.Rules.Cap())
    if not ok then ns.Message(reason); return false end
    local order=ns.Copy(ns.char.draftOrder or {});local origin=ns.char.draftOrderOrigin or "Planned purchase order"
    if not T.OrderValid(ranks,order) then
        order,reason=T.GenerateOrder(ranks)
        if not order then ns.Message(reason);return false end
        origin="Generated preview order; native purchase requirements still apply"
        ns.char.draftOrder=ns.Copy(order);ns.char.draftOrderOrigin=origin
    end
    ns.char.builds[name]={ranks=ranks,order=order,orderOrigin=origin,class=ns.State.class,source="Personal plan",level=ns.char.previewLevel or ns.Rules.Cap()}
    ns.char.activeBuild=name; ns.char.recommendationTitle=nil; ns.Message("Saved plan: "..name); ns.Emit("STATE_CHANGED"); return true
end
function T.OrderValid(ranks,order)
    if type(ranks)~="table" or type(order)~="table" then return false,"Invalid planned point order" end
    local prefix={}
    for i,key in ipairs(order or {}) do
        if not T.Definition(key) then return false,"Unknown talent in point order" end
        prefix[key]=(prefix[key] or 0)+1
        if prefix[key]>(ranks[key] or 0) then return false,"Point order exceeds the planned rank" end
        local ok,reason=T.Valid(prefix,i+9); if not ok then return false,"Level "..(i+9)..": "..reason end
    end
    if T.Total(prefix)~=T.Total(ranks) then return false,"Point order does not cover every planned rank" end
    return true
end
function T.FollowBuild(name)
    local build=ns.char.builds[name]
    if not build or build.class~=ns.State.class then return false,"Choose a saved build for this class." end
    local level=math.min(build.level or ns.Rules.Cap(),ns.Rules.Cap())
    local valid,reason=T.Valid(build.ranks or {},level)
    if not valid then return false,reason end
    local ordered,orderReason=T.OrderValid(build.ranks or {},build.order or {})
    if not ordered then return false,orderReason end
    ns.char.activeBuild=name;ns.char.draft=ns.Copy(build.ranks);ns.char.draftOrder=ns.Copy(build.order)
    ns.char.draftOrderOrigin=build.orderOrigin;ns.char.previewLevel=level
    ns.Emit("STATE_CHANGED");return true
end
function T.StopFollowing()
    ns.char.activeBuild=nil;ns.Emit("STATE_CHANGED")
end
function T.GenerateOrder(ranks)
    local ok,reason=T.Valid(ranks,ns.Rules.Cap()); if not ok then return nil,reason end
    local keys={};for key,rank in pairs(ranks) do if rank>0 then keys[#keys+1]=key end end
    table.sort(keys,function(a,b)
        local ad,at=T.Definition(a);local bd,bt=T.Definition(b)
        if ad.row~=bd.row then return ad.row<bd.row end
        if at~=bt then return at<bt end
        return ad.col<bd.col
    end)
    local prefix,order={},{}
    while #order<T.Total(ranks) do
        local added=false
        for _,key in ipairs(keys) do if (prefix[key] or 0)<ranks[key] then
            local next=ns.Copy(prefix);next[key]=(next[key] or 0)+1
            if T.Valid(next,#order+10) then prefix=next;order[#order+1]=key;added=true;break end
        end end
        if not added then return nil,"No legal point order reaches this allocation under the current snapshot." end
    end
    return order
end
function T.MovePoint(index,delta)
    local order=ns.Copy(ns.char.draftOrder or {});local other=index+delta
    if not order[index] or not order[other] then return false,"That point is already at the end." end
    order[index],order[other]=order[other],order[index]
    local ok,reason=T.OrderValid(ns.char.draft or {},order);if not ok then return false,reason end
    ns.char.draftOrder=order;ns.Emit("STATE_CHANGED");return true
end
function T.Differences(left,right)
    local differences={}
    for ti,tree in ipairs(T.Definitions()) do for i in ipairs(tree.talents) do
        local key=T.Key(ti,i);local a,b=left[key] or 0,right[key] or 0
        if a~=b then differences[#differences+1]={key=key,name=T.Display(key).name,left=a,right=b} end
    end end
    return differences
end
function T.Export(ranks,order,level)
    local records={}
    for key,value in pairs(ranks or {}) do if value>0 then records[#records+1]=key.."="..value end end;table.sort(records)
    local valid=T.OrderValid(ranks or {},order or {})
    return "TK1|"..ns.State.class.."|"..math.min(level or ns.Rules.Cap(),ns.Rules.Cap()).."|"..table.concat(records,",").."|"..(valid and table.concat(order or {},",") or "")
end
function T.Import(code)
    if type(code)~="string" or #code>4096 then return false,"Build code is too long." end
    code=code:match("^%s*(.-)%s*$")
    local class,level,allocation,sequence=code:match("^TK1|([A-Z]+)|(%d+)|([%d:,=]*)|([%d:,]*)$")
    level=tonumber(level)
    if not class or class~=ns.State.class then return false,"Use a ToonKit build code for this class." end
    if not level or level<10 or level>ns.Rules.Cap() then return false,"Build level exceeds the active content rules." end
    local ranks,order={},{}
    for record in (allocation..","):gmatch("(.-),") do if record~="" then
        local key,value=record:match("^(%d+:%d+)=(%d+)$");value=tonumber(value)
        if not key or ranks[key]~=nil or not T.Definition(key) then return false,"Invalid or duplicated talent allocation." end
        ranks[key]=value
    end end
    local ok,reason=T.Valid(ranks,level);if not ok then return false,reason end
    if sequence~="" then
        for key in (sequence..","):gmatch("(.-),") do if not key:match("^%d+:%d+$") then return false,"Invalid point order." end;order[#order+1]=key end
        ok,reason=T.OrderValid(ranks,order);if not ok then return false,reason end
    end
    ns.char.draft=ranks;ns.char.draftOrder=order;ns.char.previewLevel=level;ns.char.recommendationTitle="Imported plan"
    ns.char.draftOrderOrigin=#order>0 and "Imported planned purchase order; not purchase history" or "Imported allocation without a point order"
    ns.Emit("STATE_CHANGED");return true
end
function T.Recommendations()
    local cacheKey=ns.State.class..":"..ns.Rules.Cap()
    T.recommendationCache=T.recommendationCache or {}
    if T.recommendationCache[cacheKey] then return T.recommendationCache[cacheKey] end
    local result={}; local seen={}
    for _,guide in ipairs((ns.Data.referenceBuilds or {})[ns.State.class] or {}) do
        if not seen[guide.id] and (guide.from or 1)<=ns.Rules.Cap() and T.DecodeRecommendation(guide) then result[#result+1]=guide; seen[guide.id]=true end
    end
    T.recommendationCache[cacheKey]=result
    return result
end
function T.DecodeRecommendation(guide)
    local sourceTrees=(ns.Data.referenceTalents or {})[ns.State.class]
    if not sourceTrees then return end
    local alphabet="0123456789abcdefghijklmnopqrstuvwxyz"; local ranks,order={},{}
    for offset=1,#guide.order-1,2 do
        if #order>=T.Budget(ns.Rules.Cap()) then break end
        local tree=tonumber(guide.order:sub(offset,offset)); tree=tree and tree+1
        local position=alphabet:find(guide.order:sub(offset+1,offset+1),1,true)
        local source=tree and sourceTrees[tree] and sourceTrees[tree][position]
        local key
        if source then for i,def in ipairs(T.Definitions()[tree].talents) do if def.name==source[1] then key=T.Key(tree,i); break end end end
        if not key then return nil,nil,"Build no longer matches the bundled tree." end
        ranks[key]=(ranks[key] or 0)+1; order[#order+1]=key
        local valid,reason=T.Valid(ranks,ns.Rules.Cap())
        if not valid then return nil,nil,reason end
    end
    return ranks,order
end
function T.LoadRecommendation(guide)
    local ranks,order,reason=T.DecodeRecommendation(guide)
    if not ranks then ns.Message(reason or "Build is unavailable."); return end
    ns.char.draft=ranks; ns.char.draftOrder=order; ns.char.previewLevel=ns.Rules.Cap()
    ns.char.draftOrderOrigin="Source build's planned purchase order; not purchase history"
    ns.char.recommendationTitle=guide.title; ns.Emit("STATE_CHANGED")
end
function T.Next()
    local b=ns.char.builds[ns.char.activeBuild or ""]
    if not b then return nil,"Select a saved build to receive point suggestions." end
    if not T.available or T.mismatches>0 then return nil,"Live allocation could not be fully matched; compare your plan manually." end
    if b.class~=ns.State.class then return nil,"Choose a saved build for this character's class." end
    local valid,reason=T.Valid(b.ranks or {},ns.Rules.Cap())
    if not valid then return nil,"Review this build under the current content rules: "..reason.."." end
    local ordered,orderReason=T.OrderValid(b.ranks or {},b.order or {})
    if not ordered then return nil,"Review and save the build's point order: "..orderReason.."." end
    for key,rank in pairs(T.actual) do
        if rank>((b.ranks or {})[key] or 0) then return nil,"Your learned allocation differs from this build at "..(T.Display(key).name or key)..". Update the plan or choose a matching build." end
    end
    if T.Total(T.actual)>=T.Budget(ns.State.level) then
        return nil,ns.State.level>=ns.Rules.Cap() and "All points at the active level cap are allocated." or ("Your next talent point is available at level "..math.max(10,ns.State.level+1)..".")
    end
    if #(b.order or {})==0 then return nil,"This plan has no purchase order. Compare learned and planned ranks in Plan." end
    local desired={}
    for index,key in ipairs(b.order or {}) do
        desired[key]=(desired[key] or 0)+1
        if (T.actual[key] or 0)<desired[key] then
            local d=T.Definition(key); local preview=ns.Copy(T.actual); preview[key]=(preview[key] or 0)+1
            local ok,reason=T.Valid(preview,ns.State.level)
            if not ok then return nil,"The next planned point is blocked: "..reason..". Review your learned allocation against the plan." end
            local node=T.nodes[key]
            if not node or node.available~=true or node.canPurchase~=true then return nil,(d and d.name or key).." is next in your plan. Check the native talent window; the client has not confirmed that you can learn it." end
            return key,(d and d.name or key).." rank "..desired[key].." (planned at level "..(9+index)..")."
        end
    end
    return nil,"Planned allocation reached."
end
function T.PointAdvice()
    if not ns.char or not T.available or T.mismatches>0 then return end
    local points=T.Budget(ns.State.level)-T.Total(T.actual)
    if points<=0 then return end
    local key,text=T.Next();local definition=key and T.Definition(key)
    return {points=points,key=key,text=text,name=definition and definition.name,
        page=ns.char.activeBuild and "Guide" or "Builds"}
end
ns.Listen("STATE_CHANGED",function(kind)
    if not ns.Changed(kind,"talents","identity") then return end
    if not ns.db.settings.talentPointReminder or not ns.db.settings.modules.talents then T.pointNotice=nil;return end
    local advice=T.PointAdvice()
    if not advice then T.pointNotice=nil;return end
    local signature=table.concat({ns.char.activeBuild or "",advice.points,advice.text or ""},":")
    if signature==T.pointNotice then return end
    T.pointNotice=signature
    ns.Message(advice.points..(advice.points==1 and " talent point available. " or " talent points available. ")..(advice.text or "Choose a talent build.").." /tk talents")
end)
