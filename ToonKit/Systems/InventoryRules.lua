local addonName, ns = ...
local I={base={"Equipment","Consumables","Quest items","Materials","Trade goods","Miscellaneous","Sellable Gear","Junk","Reagent bag","Empty"},facts={}};ns.InventoryRules=I
local names={["Sellable Gear"]="Gear to review",["Junk"]="Poor quality"}
function I.IsReagentBag(item)
    if item.recorded then return item.reagentBag==true or item.category=="Reagent bag" end
    local bag=Enum and Enum.BagIndex and ns.Safe(Enum.BagIndex.ReagentBag)
    return type(bag)=="number" and bag>=0 and item.bag==bag or false
end
function I.Groups()
    local groups={}
    for _,group in ipairs(ns.db.settings.bagGroups) do groups[#groups+1]={id=group.id,name=group.name} end
    for _,id in ipairs(I.base) do groups[#groups+1]={id=id,name=names[id] or id} end
    return groups
end
function I.Name(id)
    for _,group in ipairs(ns.db.settings.bagGroups) do if group.id==id then return group.name end end
    return names[id] or id
end
function I.Exists(id)
    for _,group in ipairs(I.Groups()) do if group.id==id then return true end end
    return false
end
function I.SellableGear(item)
    if not item or not item.id or item.recorded then return false end
    local info=item.info
    if not info or not ns.Data.equipSlots[info.equip] then return false end
    if info.classID==12 or item.quest and (ns.Safe(item.quest.isQuestItem,false) or ns.Safe(item.quest.questID)) then return false end
    if ns.char.farming[item.id] or (ns.char.itemGroups or {})[item.id] then return false end
    if ns.QuestSupplies and #ns.QuestSupplies.ForItem(item.id)>0 then return false end
    if ns.TripPlanning and #ns.TripPlanning.KeepLines(item.id)>0 then return false end
    -- Level locks are temporary. Never mistake them for a class/proficiency restriction.
    if type(info.required)~="number" or info.required>(ns.State.level or 0) then return false end
    if info.sellPriceKnown~=true or type(info.sellPrice)~="number" or info.sellPrice<=0 then return false end
    local usable=ns.API.ItemEligibility(item.id,info)
    if usable==false then return true,"The client reports this character cannot use this item now. Future or other-character use is unconfirmed." end
    return false
end
function I.Basic(item)
    if not item.id then return "Empty" end
    if item.id==2251 and ns.TripPlanning and #ns.TripPlanning.KeepLines(item.id)>0 then return "Quest items" end
    local info=item.info
    if item.quest and (ns.Safe(item.quest.isQuestItem,false) or ns.Safe(item.quest.questID)) then return "Quest items" end
    if (item.quality or info and info.quality)==0 then
        if ns.QuestSupplies and #ns.QuestSupplies.ForItem(item.id)>0 then return "Quest items" end
        return "Junk"
    end
    if I.SellableGear(item) then return "Sellable Gear" end
    if ns.QuestSupplies and #ns.QuestSupplies.ForItem(item.id)>0 then return "Quest items" end
    if info and ns.Data.equipSlots[info.equip] then return "Equipment" end
    if info and info.classID==0 then return "Consumables" end
    if info and info.classID==12 then return "Quest items" end
    if info and (info.classID==7 or info.reagent) then return "Materials" end
    if info and (info.classID==5 or info.classID==9 or info.classID==19) then return "Trade goods" end
    return "Miscellaneous"
end
function I.Upgrade(item)
    if not ns.ItemComparison then return false end
    local advice=ns.ItemComparison.Cached(item.id,item.link)
    return advice and advice.kind=="upgrade" or false
end
function I.RuleMatches(rule,item)
    if rule.enabled==false or not item.id then return false end
    local info=item.info or {};local kind,value=rule.kind,rule.value
    if kind=="item" then return item.id==tonumber(value)
    elseif kind=="quality" then return item.quality==tonumber(value)
    elseif kind=="class" then return info.classID==tonumber(value)
    elseif kind=="name" then return (info.name or ""):lower():find(tostring(value):lower(),1,true)~=nil
    elseif kind=="search" then return I.Search(item,tostring(value),I.Basic(item))
    elseif kind=="equipment" then return ns.Data.equipSlots[info.equip]~=nil
    elseif kind=="quest" then return I.Basic(item)=="Quest items"
    elseif kind=="reagent" then return info.reagent or info.classID==7
    elseif kind=="upgrade" then return I.Upgrade(item)
    elseif kind=="unusable" then return ns.Data.equipSlots[info.equip]~=nil and ns.API.ItemEligibility(item.id,item.info)==false
    elseif kind=="new" then return I.IsNew(item)
    elseif kind=="tracked" then return ns.char.farming[item.id]~=nil
    elseif kind=="required" then return info.required~=nil and info.required<=tonumber(value) end
    return false
end
function I.Category(item)
    if I.IsReagentBag(item) then return "Reagent bag" end
    if not item.id then return "Empty" end
    local manual=(ns.char.itemGroups or {})[item.id]
    if manual and manual~="Reagent bag" and I.Exists(manual) then return manual end
    for _,rule in ipairs(ns.db.settings.bagRules) do if rule.group~="Reagent bag" and I.Exists(rule.group) and I.RuleMatches(rule,item) then return rule.group end end
    return I.Basic(item)
end
function I.CreateGroup(name)
    name=tostring(name or ""):match("^%s*(.-)%s*$")
    if #name<1 or #name>40 then return false,"Use a group name from 1 to 40 characters." end
    for _,group in ipairs(I.Groups()) do if group.name:lower()==name:lower() then return false,"That group name is already in use." end end
    if #ns.db.settings.bagGroups>=32 then return false,"The maximum is 32 custom groups." end
    local id="group:"..ns.db.settings.nextBagGroup;ns.db.settings.nextBagGroup=ns.db.settings.nextBagGroup+1
    ns.db.settings.bagGroups[#ns.db.settings.bagGroups+1]={id=id,name=name};ns.Emit("SETTINGS_CHANGED");ns.Emit("STATE_CHANGED");return id
end
function I.DeleteGroup(id)
    ns.db.settings.bagHiddenGroups[id]=nil
    for i,group in ipairs(ns.db.settings.bagGroups) do if group.id==id then table.remove(ns.db.settings.bagGroups,i);break end end
    for i=#ns.db.settings.bagRules,1,-1 do if ns.db.settings.bagRules[i].group==id then table.remove(ns.db.settings.bagRules,i) end end
    for _,character in pairs(ns.db.characters) do for item,group in pairs(character.itemGroups or {}) do if group==id then character.itemGroups[item]=nil end end end
    for item,group in pairs(ns.char.itemGroups or {}) do if group==id then ns.char.itemGroups[item]=nil end end
    ns.db.settings.bagCollapsed[id]=nil;ns.db.settings.bagGroupSort[id]=nil
    ns.Emit("SETTINGS_CHANGED");ns.Emit("STATE_CHANGED")
end
function I.AddRule(group,kind,value)
    local known={search=true,item=true,quality=true,class=true,name=true,equipment=true,quest=true,reagent=true,upgrade=true,unusable=true,new=true,tracked=true,required=true}
    if not I.Exists(group) or not known[kind] then return false,"Choose a group and rule type." end
    if #ns.db.settings.bagRules>=64 then return false,"The maximum is 64 rules." end
    if kind=="item" or kind=="quality" or kind=="class" or kind=="required" then
        value=tonumber(value)
        if not value or value~=math.floor(value) or value<0 or (kind=="quality" and value>8) or (kind=="required" and value>ns.Rules.Cap()) or (kind=="item" and value<1) then return false,"Enter a valid number for this rule." end
    elseif (kind=="name" or kind=="search") and (type(value)~="string" or #value>200 or value:match("^%s*$")) then return false,"Enter up to 200 characters for this rule." end
    ns.db.settings.bagRules[#ns.db.settings.bagRules+1]={group=group,kind=kind,value=value,enabled=true}
    ns.Emit("STATE_CHANGED");return true
end
local qualities={poor=0,common=1,uncommon=2,rare=3,epic=4,legendary=5,artifact=6,heirloom=7}
local function numberMatch(number,value)
    if number==nil then return false end
    local low,high=value:match("^(%d+)%-(%d+)$")
    if low then return number>=tonumber(low) and number<=tonumber(high) end
    local op,target=value:match("^([<>=]*)(%d+)$");target=tonumber(target)
    if not target then return false end
    if op==">=" then return number>=target elseif op=="<=" then return number<=target elseif op==">" then return number>target elseif op=="<" then return number<target end
    return number==target
end
function I.Term(item,term,category)
    local invert=term:sub(1,1)=="!";if invert then term=term:sub(2) end
    local key,value=term:match("^([%w_]+):(.+)$");local info=item.info or {};local match=false
    if key=="id" then match=numberMatch(item.id,value)
    elseif key=="q" or key=="quality" then local quality=tonumber(value) or qualities[value];match=quality~=nil and item.quality==quality
    elseif key=="level" then match=numberMatch(info.required,value)
    elseif key=="ilvl" then match=numberMatch(item.itemLevel,value)
    elseif key=="bag" then match=numberMatch(item.bag,value)
    elseif key=="type" then match=((info.class or "").." "..(info.sub or "")):lower():find(value,1,true)~=nil
    elseif key=="slot" then match=(info.equip or ""):lower():find(value,1,true)~=nil
    elseif key=="group" then match=I.Name(category):lower():find(value,1,true)~=nil
    elseif term=="new" then match=I.IsNew(item)
    elseif term=="tracked" then match=item.id and ns.char.farming[item.id]~=nil
    elseif term=="keep" then match=item.id and ns.QuestSupplies and #ns.QuestSupplies.ForItem(item.id)>0
    elseif term=="upgrade" then match=I.Upgrade(item)
    elseif term=="bound" then match=item.bound==true
    elseif term=="boe" then local bind=Enum and Enum.ItemBind and Enum.ItemBind.OnEquip;match=bind~=nil and info.bind==bind and item.boundKnown==true and item.bound==false
    else match=((info.name or "").." "..(info.sub or "").." "..tostring(item.id or "").." "..I.Name(category)):lower():find(term,1,true)~=nil end
    if invert then return not match end
    return match and true or false
end
function I.Search(item,query,category)
    if not query or query=="" then return true end
    query=query:lower()
    local tokens,token,quoted={},"",false
    for i=1,#query do
        local char=query:sub(i,i)
        if char=='"' then quoted=not quoted
        elseif not quoted and (char:match("%s") or char=="|") then
            if token~="" then tokens[#tokens+1]=token;token="" end
            if char=="|" then tokens[#tokens+1]="|" end
        else token=token..char end
    end
    if token~="" then tokens[#tokens+1]=token end
    local all=true
    for _,term in ipairs(tokens) do
        if term=="|" then if all then return true end;all=true
        elseif not I.Term(item,term,category) then all=false end
    end
    return all
end
function I.IsNew(item)
    if not item.id then return false end
    local marked=(ns.char.bagNew or {})[item.id]
    local native=ns.Safe(ns.API.Call("C_NewItems","IsNewItem",item.bag,item.slot),false)
    return marked~=nil or native
end
function I.MarkSeen()
    ns.char.bagNew={}
    for _,item in ipairs(ns.State.bags) do if item.id then ns.API.Call("C_NewItems","RemoveNewItem",item.bag,item.slot) end end
    ns.Emit("STATE_CHANGED")
end
function I.Snapshot()
    if not ns.char or ns.State.capacity==0 then return end
    local previous=ns.char.bagSnapshot;local items,counts={},{}
    for _,item in ipairs(ns.State.bags) do if item.id then
        local key=item.link or tostring(item.id);local record=items[key]
        if not record then record={id=item.id,link=item.link,name=item.info and item.info.name or item.name,icon=item.icon,quality=item.quality,count=0};items[key]=record end
        record.count=record.count+(item.count or 1);counts[item.id]=(counts[item.id] or 0)+(item.count or 1)
    end end
    local now=type(GetServerTime)=="function" and ns.Safe(GetServerTime(),0) or 0
    ns.char.bagNew=ns.char.bagNew or {}
    if previous then for id,count in pairs(counts) do if count>((previous.counts or {})[id] or 0) then ns.char.bagNew[id]=now end end end
    ns.char.bagSnapshot={items=items,counts=counts,recorded=now,capacity=ns.State.capacity,free=ns.State.free}
    ns.char.identity={name=ns.State.name,class=ns.State.class,level=ns.State.level,faction=ns.State.faction,realm=ns.Safe(GetRealmName(),"Realm")}
end
ns.Listen("STATE_CHANGED",function(kind) if ns.Changed(kind,"inventory","quests","identity","talents") then I.facts={} end end)
ns.Listen("SETTINGS_CHANGED",function() I.facts={} end)

function I.Ownership(id)
    local rows={}
    local carried=ns.State.owned[id] or 0
    if carried>0 then rows[#rows+1]={name=ns.State.name or "This character",realm=ns.Safe(GetRealmName(),"Realm"),count=carried,current=true,recorded=0} end
    for _,character in pairs(ns.db.characters or {}) do
        local snapshot=character.bagSnapshot;local identity=character.identity
        local count=character==ns.char and (ns.State.owned[id] or 0) or snapshot and snapshot.counts and snapshot.counts[id] or 0
        if character~=ns.char and snapshot then for _,item in pairs(snapshot.equipped or {}) do if item.id==id then count=count+1 end end end
        if character~=ns.char and count>0 and identity then
            rows[#rows+1]={name=identity.name or "Character",realm=identity.realm or "Realm",count=count,current=character==ns.char,recorded=snapshot and snapshot.recorded or 0}
        end
    end
    table.sort(rows,function(a,b) if a.current~=b.current then return a.current end;if a.name~=b.name then return a.name<b.name end;return a.realm<b.realm end)
    return rows
end
function I.AppendOwnershipTooltip(tooltip,id)
    if not tooltip or tooltip.tkBagOwnership==id then return end
    tooltip.tkBagOwnership=id
    for _,record in ipairs(I.Ownership(id)) do
        tooltip:AddLine(record.name.." - "..record.realm..": "..record.count..(record.current and " carried/equipped" or " in recorded bags/equipment"),.8,.8,.72,true)
    end
end
