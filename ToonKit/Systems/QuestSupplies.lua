local addonName, ns = ...
local Q={advice={},dirty=true};ns.QuestSupplies=Q
local data=ns.Data.questSupport or {quests={},meta={}}
local producers,recipients={},{}
local sourceCounts,sourceRequirements={},{}
for _,route in ipairs(ns.Data.originalRoutes) do for _,step in ipairs(route.steps or {}) do for _,goal in ipairs(step.goals or {}) do
    if goal.t=="collect" and goal.quest and goal.item then
        sourceRequirements[goal.quest]=sourceRequirements[goal.quest] or {};sourceRequirements[goal.quest][goal.item]=true
    end
    if goal.t=="collect" and goal.quest and goal.item and type(goal.count)=="number" and goal.count>0 then
        local key=goal.quest..":"..goal.item
        if sourceCounts[key]==nil then sourceCounts[key]=goal.count elseif sourceCounts[key]~=goal.count then sourceCounts[key]=false end
    end
end end end
for id,q in pairs(data.quests) do
    for _,item in ipairs(q.rewards or {}) do producers[item]=producers[item] or {};producers[item][#producers[item]+1]=id end
    for item in pairs(q.items or {}) do recipients[item]=recipients[item] or {};recipients[item][#recipients[item]+1]=id end
end
for quest,items in pairs(sourceRequirements) do for item in pairs(items) do
    recipients[item]=recipients[item] or {};local found=false
    for _,id in ipairs(recipients[item]) do if id==quest then found=true;break end end
    if not found then recipients[item][#recipients[item]+1]=quest end
end end
function Q.Name(id) local m=data.meta[id];local q=data.quests[id];return m and m.name or q and q.name or "Quest #"..id end
local function done(id) return ns.Journey and ns.Journey.QuestDone(id) or not ns.Journey and (ns.char.turnedIn[id] or ns.API.QuestDone(id)) end
local function bitAllowed(mask,id) return mask==0 or type(id)=="number" and math.floor(mask/2^(id-1))%2==1 end
function Q.Eligible(id,levelCeiling)
    local m=data.meta[id];if not m then return false end
    -- Unread skill/reputation requirements cannot establish a future suggestion.
    if m.skill or m.minRep or m.maxRep then return false end
    if m.parent and not ns.Journey.OnQuest(m.parent) then return false end
    if m.chain and (done(m.chain) or ns.Journey.OnQuest(m.chain)) then return false end
    if not bitAllowed(m.classes or 0,ns.State.classID) or not ns.Rules.QuestRaceAllowed(m.races) then return false end
    if (m.min or 0)>math.min(ns.Rules.Cap(),levelCeiling or ns.State.level+4) then return false end
    for _,q in ipairs(m.preAll or {}) do if not done(q) then return false end end
    if #(m.pre or {})>0 then local any=false;for _,q in ipairs(m.pre) do if done(q) then any=true;break end end;if not any then return false end end
    for _,q in ipairs(m.excl or {}) do if done(q) or ns.Journey.OnQuest(q) then return false end end
    return true
end
local function localSource(id,map)
    for _,area in ipairs(data.meta[id] and data.meta[id].maps or {}) do if area==map then return true end end
    for item in pairs(data.quests[id] and data.quests[id].items or {}) do
        for _,producer in ipairs(producers[item] or {}) do for _,area in ipairs(data.meta[producer] and data.meta[producer].maps or {}) do if area==map then return true end end end
    end
    return false
end
function Q.Plan(id,scope)
    local out,seen={},{}
    local function visit(quest,via,depth)
        if depth>4 or seen[quest] then return end;seen[quest]=true
        local requirements={}
        for item,count in pairs(data.quests[quest] and data.quests[quest].items or {}) do requirements[item]=count end
        for item in pairs(sourceRequirements[quest] or {}) do if requirements[item]==nil then requirements[item]=0 end end
        for item,count in pairs(requirements) do
            local required=count>0 and count or sourceCounts[quest..":"..item]
            if ns.Journey.ItemObjective and ns.Journey.OnQuest(quest) and not (data.costItems and data.costItems[quest] and data.costItems[quest][item]) then
                local objective=ns.Journey.ItemObjective({t="collect",quest=quest,item=item})
                required=objective and ns.Safe(objective.numRequired) or nil
            end
            out[#out+1]={id=item,count=required or nil,quest=id,via=quest~=id and quest or nil,scope=scope,have=ns.State.owned[item] or 0}
            -- A single required reward can trace one source quest. Missing reward
            -- quantities cannot establish how many repeats a larger order needs.
            if count==1 and (ns.State.owned[item] or 0)<1 and #(producers[item] or {})==1 then
                local producer=producers[item][1]
                if data.quests[producer].repeatable or not done(producer) then visit(producer,item,depth+1) end
            end
        end
    end
    visit(id,nil,0)
    table.sort(out,function(a,b) if (a.via or 0)~=(b.via or 0) then return (a.via or 0)<(b.via or 0) end;return a.id<b.id end)
    return out
end
function Q.Refresh()
    if not ns.char then return end
    Q.advice={};Q.dirty=false
    if not ns.db.settings.questKeepAdvice then return end
    local roots={}
    for _,q in ipairs(ns.State.quests) do roots[q.id]="Quest log" end
    for id in pairs(ns.char.questKeep or {}) do roots[id]="Your quest plan" end
    local route=ns.Journey.Selected() or {};local _,_,index=ns.Journey.Action()
    for i=index or 1,math.min(#(route.steps or {}),(index or 1)+20) do
        for _,g in ipairs(route.steps[i].goals or {}) do if g.quest and ns.Journey.Applies(g.only) then roots[g.quest]=roots[g.quest] or "Upcoming guide" end end
    end
    local candidates={};local map=ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"))
    for _,item in ipairs(ns.State.bags) do if item.id then
        for _,id in ipairs(recipients[item.id] or {}) do candidates[id]=true
            for _,reward in ipairs(data.quests[id] and data.quests[id].rewards or {}) do for _,consumer in ipairs(recipients[reward] or {}) do candidates[consumer]=true end end
        end
    end end
    for id in pairs(candidates) do local m=data.meta[id]
        if not roots[id] and not (data.quests[id] and data.quests[id].repeatable) and m and (m.level or 0)>=ns.State.level-5 and Q.Eligible(id) and localSource(id,map) then roots[id]="Nearby future quest" end
    end
    local ordered={};for id,scope in pairs(roots) do ordered[#ordered+1]={id=id,scope=scope} end;table.sort(ordered,function(a,b) return a.id<b.id end)
    for _,root in ipairs(ordered) do if not done(root.id) or root.scope=="Quest log" and data.quests[root.id] and data.quests[root.id].repeatable then
        for _,r in ipairs(Q.Plan(root.id,root.scope)) do
            Q.advice[r.id]=Q.advice[r.id] or {};local list=Q.advice[r.id]
            if #list<6 then list[#list+1]=r end
        end
    end end
end
function Q.ForItem(id) if Q.dirty then Q.Refresh() end;return Q.advice[id] or {} end
function Q.Lines(id)
    local lines=ns.TripPlanning and ns.TripPlanning.KeepLines(id) or {}
    for _,r in ipairs(Q.ForItem(id)) do
        lines[#lines+1]=(r.count and "Keep "..r.count or "Quest supply").." for "..Q.Name(r.quest)..(r.via and " via "..Q.Name(r.via) or "").." ("..r.scope..")"
    end
    if #lines==0 then
        for _,quest in ipairs(recipients[id] or {}) do
            local m=data.meta[quest]
            if m and bitAllowed(m.classes or 0,ns.State.classID) and ns.Rules.QuestRaceAllowed(m.races) then
                local required=sourceCounts[quest..":"..id]
                lines[#lines+1]="Quest use: "..Q.Name(quest)..(required and " — "..required.." required" or "")..(done(quest) and " (completed)" or " (reference; not currently planned)")
                if #lines>=4 then break end
            end
        end
    end
    if #lines>0 then lines[#lines+1]="Source-listed quest requirements. No items are sold, locked or moved automatically." end
    return lines
end
function Q.AppendTooltip(tooltip,id)
    id=ns.Safe(id)
    if not ns.char or type(id)~="number" or tooltip.tkQuestItem==id then return end
    local lines=Q.Lines(id)
    if #lines==0 then return end
    tooltip.tkQuestItem=id
    tooltip:AddLine(ns.Brand.shortName.." — Quest supplies",1,.82,.42)
    for _,line in ipairs(lines) do tooltip:AddLine(line,1,.82,.42,true) end
    tooltip:Show()
end
-- Native item tooltips can be populated after OnEnter (including async item loads).
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(tooltip,data)
        if tooltip==GameTooltip then Q.AppendTooltip(tooltip,data and data.id) end
    end)
end
if GameTooltip and GameTooltip.HookScript then GameTooltip:HookScript("OnTooltipCleared",function(self) self.tkQuestItem=nil end) end
function Q.Pin(id,value)
    if not data.meta[id] and not data.quests[id] then return false end
    ns.char.questKeep=ns.char.questKeep or {};ns.char.questKeep[id]=value and true or nil;Q.dirty=true;ns.Emit("STATE_CHANGED");return true
end
ns.Listen("STATE_CHANGED",function(kind) if ns.Changed(kind,"inventory","quests","identity","journey") then Q.dirty=true end end)
ns.Listen("SETTINGS_CHANGED",function() Q.dirty=true end)
