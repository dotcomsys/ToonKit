local addonName, ns = ...
local I=ns.InventoryRules
local originalGroups,originalName,originalCategory,originalSnapshot=I.Groups,I.Name,I.Category,I.Snapshot
function I.RefreshSets()
    I.setGroups={};I.itemSets={}
    if ns.db.settings.bagEquipmentSets==false then return end
    for _,id in ipairs(ns.API.Call("C_EquipmentSet","GetEquipmentSetIDs") or {}) do
        id=ns.Safe(id)
        if type(id)=="number" then
            local name=ns.Safe(ns.API.Call("C_EquipmentSet","GetEquipmentSetInfo",id))
            local items=ns.API.Call("C_EquipmentSet","GetItemIDs",id)
            if type(name)=="string" and type(items)=="table" then
                local key="set:"..id;I.setGroups[#I.setGroups+1]={id=key,name=name}
                for _,item in pairs(items) do item=ns.Safe(item);if type(item)=="number" and item>0 then
                    I.itemSets[item]=I.itemSets[item] or {};I.itemSets[item][#I.itemSets[item]+1]=key
                end end
            end
        end
    end
    table.sort(I.setGroups,function(a,b) return a.name<b.name end)
end
function I.Groups()
    local rows=originalGroups();for _,g in ipairs(I.setGroups or {}) do rows[#rows+1]=g end
    local order={};for n,id in ipairs(ns.db.settings.bagOrder or {}) do order[id]=n end
    local defaults={};for n,g in ipairs(rows) do defaults[g.id]=n end
    table.sort(rows,function(a,b)
        local x,y=order[a.id] or 1000+defaults[a.id],order[b.id] or 1000+defaults[b.id]
        return x<y
    end)
    return rows
end
function I.Name(id)
    for _,g in ipairs(I.setGroups or {}) do if g.id==id then return g.name end end
    return originalName(id)
end
function I.MoveGroup(id,delta)
    local rows=I.Groups();local index
    for n,g in ipairs(rows) do if g.id==id then index=n end end
    if not index then return end
    local other=math.max(1,math.min(#rows,index+delta));rows[index],rows[other]=rows[other],rows[index]
    ns.db.settings.bagOrder={};for _,g in ipairs(rows) do ns.db.settings.bagOrder[#ns.db.settings.bagOrder+1]=g.id end
    ns.Emit("STATE_CHANGED")
end
function I.Category(item)
    if I.IsReagentBag(item) then return "Reagent bag" end
    if item.recorded then return item.category or "Miscellaneous" end
    local category=originalCategory(item)
    if category==I.Basic(item) and not (ns.char.itemGroups or {})[item.id] then
        -- Explicit matching rules retain priority over equipment sets.
        for _,rule in ipairs(ns.db.settings.bagRules) do if I.Exists(rule.group) and I.RuleMatches(rule,item) then return category end end
        local sets=I.itemSets and I.itemSets[item.id]
        if sets and sets[1] then return sets[1] end
    end
    return category
end
function I.Snapshot()
    I.facts={};I.RefreshSets();originalSnapshot()
    local snapshot=ns.char and ns.char.bagSnapshot
    if not snapshot or ns.State.capacity==0 then return end
    snapshot.slots={};snapshot.groups=ns.Copy(I.Groups());snapshot.money=ns.API.Money()
    for _,item in ipairs(ns.State.bags) do
        local record={bag=item.bag,slot=item.slot,id=item.id,link=item.link,count=item.count,icon=item.icon,quality=item.quality,
            info=item.info and ns.Copy(item.info),itemLevel=item.itemLevel,bound=item.bound,boundKnown=item.boundKnown,category=I.Category(item),reagentBag=I.IsReagentBag(item),recorded=true}
        snapshot.slots[#snapshot.slots+1]=record
    end
    snapshot.equipped={}
    for slot,item in pairs(ns.State.equipment) do if item.id then snapshot.equipped[slot]={id=item.id,link=item.link} end end
end
function I.Recorded(key)
    local character=ns.db.characters[key];local snapshot=character and character.bagSnapshot
    if not snapshot then return end
    local slots=ns.Copy(snapshot.slots or {})
    if #slots==0 then
        for _,item in pairs(snapshot.items or {}) do
            local copy=ns.Copy(item);copy.bag=0;copy.slot=#slots+1;copy.recorded=true
            copy.info=ns.API.Item(item.link or item.id);copy.category="Miscellaneous";slots[#slots+1]=copy
        end
    end
    local names={};for _,g in ipairs(snapshot.groups or {}) do names[g.id]=g.name end
    for _,item in ipairs(slots) do if item.id then item.info=ns.API.Item(item.link or item.id) or item.info end;item.categoryName=names[item.category] or item.category end
    return {bags=slots,capacity=snapshot.capacity or #slots,free=snapshot.free or 0,
        name=character.identity and character.identity.name or "Recorded character",level=character.identity and character.identity.level,
        money=snapshot.money or "Money not recorded",
        groups=snapshot.groups or originalGroups(),recorded=snapshot.recorded,offline=true}
end
-- Search grammar: quoted phrases, implicit/explicit AND, OR, NOT and parentheses.
-- Compilation is bounded and cached; native tooltip text is cached per inventory revision.
local function compile(query)
    local tokens,word={},"";local quoted=false
    local function flush() if word~="" then tokens[#tokens+1]=word;word="" end end
    for n=1,#query do
        local c=query:sub(n,n)
        if c=='"' then quoted=not quoted
        elseif not quoted and c:match("%s") then flush()
        elseif not quoted and (c=="&" or c=="|" or c=="(" or c==")" or c=="!" or c=="~") then flush();tokens[#tokens+1]=c
        else word=word..c end
    end
    flush();if quoted then return nil,"Close the quoted phrase." end
    if #tokens>128 then return nil,"Search is too long." end
    local cursor,depth=1,0;local parseOr
    local function atom()
        local token=tokens[cursor];cursor=cursor+1
        if token=="!" or token=="~" then local value=atom();return value and {op="not",value=value} end
        if token=="(" then
            depth=depth+1;if depth>16 then return end
            local value=parseOr();if tokens[cursor]~=")" then return end
            cursor=cursor+1;depth=depth-1;return value
        end
        if not token or token==")" or token=="|" or token=="&" then return end
        return {term=token}
    end
    local function parseAnd()
        local value=atom();if not value then return end
        while tokens[cursor] and tokens[cursor]~="|" and tokens[cursor]~=")" do
            if tokens[cursor]=="&" then cursor=cursor+1 end
            local right=atom();if not right then return end;value={op="and",left=value,right=right}
        end
        return value
    end
    parseOr=function()
        local value=parseAnd();if not value then return end
        while tokens[cursor]=="|" do cursor=cursor+1;local right=parseAnd();if not right then return end;value={op="or",left=value,right=right} end
        return value
    end
    local tree=parseOr();if not tree or cursor<=#tokens then return nil,"Check parentheses and search operators." end
    return tree
end
local term=I.Term
local slotNames={neck="INVTYPE_NECK",back="INVTYPE_CLOAK",cloak="INVTYPE_CLOAK",shoulder="INVTYPE_SHOULDER",shoulders="INVTYPE_SHOULDER",wrist="INVTYPE_WRIST",bracers="INVTYPE_WRIST",hands="INVTYPE_HAND",gloves="INVTYPE_HAND",waist="INVTYPE_WAIST",belt="INVTYPE_WAIST",legs="INVTYPE_LEGS",feet="INVTYPE_FEET",boots="INVTYPE_FEET",ring="INVTYPE_FINGER",trinket="INVTYPE_TRINKET",head="INVTYPE_HEAD"}
function I.Term(item,value,category)
    local slot=value:match("^slot:(.+)$")
    if slot and slotNames[slot] then return item.info and item.info.equip==slotNames[slot] or false end
    if value=="junk" then return item.id~=nil and (item.quality or item.info and item.info.quality)==0 end
    if value=="equipment" then return item.info~=nil and ns.Data.equipSlots[item.info.equip]~=nil end
    if value=="quest" then return category=="Quest items" end
    if item.recorded and value:sub(1,6)=="group:" then return (item.categoryName or category or ""):lower():find(value:sub(7),1,true)~=nil end
    if item.recorded and item.categoryName and not value:find(":",1,true) and item.categoryName:lower():find(value,1,true) then return true end
    local numeric=value:match("^[<>=]*%d+$") or value:match("^%d+%-%d+$")
    if numeric then return term(item,"ilvl:"..value,category) end
    if item.recorded and (value=="upgrade" or value=="new" or value=="tracked" or value=="keep") then return false end
    if term(item,value,category) then return true end
    if value:find(":",1,true) or not item.id then return false end
    if not I.tooltipCache or I.tooltipRevision~=ns.State.revision then I.tooltipCache={};I.tooltipRevision=ns.State.revision end
    local key=item.link or item.id;local text=I.tooltipCache[key]
    if text==nil then
        local parts={};local data=ns.API.Call("C_TooltipInfo","GetHyperlink",item.link or "item:"..item.id)
        for _,line in ipairs(data and ns.Safe(data.lines,{}) or {}) do
            parts[#parts+1]=ns.Safe(line.leftText,"");parts[#parts+1]=ns.Safe(line.rightText,"")
        end
        text=table.concat(parts," "):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):lower();I.tooltipCache[key]=text
    end
    return text:find(value,1,true)~=nil
end
function I.Search(item,query,category)
    if not query or query:match("^%s*$") then I.searchError=nil;return true end
    query=query:lower();I.searchCache=I.searchCache or {};local compiled=I.searchCache[query]
    if not compiled then
        if (I.searchCount or 0)>=32 then I.searchCache={};I.searchCount=0 end
        local tree,error=compile(query);compiled={tree=tree,error=error};I.searchCache[query]=compiled;I.searchCount=(I.searchCount or 0)+1
    end
    I.searchError=compiled.error;if not compiled.tree then return false end
    local function evaluate(node)
        if node.term then return I.Term(item,node.term,category) end
        if node.op=="not" then return not evaluate(node.value) end
        if node.op=="and" then return evaluate(node.left) and evaluate(node.right) end
        return evaluate(node.left) or evaluate(node.right)
    end
    return evaluate(compiled.tree)
end
ns.On("EQUIPMENT_SETS_CHANGED",function() if ns.char then I.RefreshSets();ns.Emit("STATE_CHANGED") end end)

local isNew=I.IsNew
function I.IsNew(item) if item.recorded then return false end;return isNew(item) end

ns.Listen("SETTINGS_CHANGED",function() if ns.char then I.RefreshSets();I.facts={} end end)
