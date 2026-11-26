local addonName, ns = ...
local G=ns.Gear
function G.TalentAdjustments(stats,profile)
    local adjusted,notes={},{}
    for stat,value in pairs(stats) do local safe=ns.Safe(value);if type(safe)=="number" then adjusted[stat]=safe end end
    local T=ns.Talents
    local ranks=profile and profile.ranks and profile.valid and profile.ranks or T.actual
    if not (profile and profile.ranks and profile.valid) and (not T.available or T.mismatches>0) then return adjusted,notes end
    local conversions={}
    for _,rule in ipairs((ns.Data.talentEffects or {})[ns.State.class] or {}) do
        local definition=T.Definition(rule.key);local rank=ranks[rule.key] or 0
        local percent=rule.percent[rank]
        if definition and definition.name==rule.name and percent and rank<=definition.max then
            local value=adjusted[rule.stat] or 0
            if rule.kind=="multiply" and value~=0 then
                adjusted[rule.stat]=value*(1+percent/100)
                notes[#notes+1]=rule.name..": +"..percent.."% "..(_G[rule.stat] or definition.name).." (source-based talent adjustment)"
            elseif rule.kind=="intellectArmor" then conversions[#conversions+1]={name=rule.name,percent=percent} end
        end
    end
    for _,rule in ipairs(conversions) do
        local armor=(adjusted.ITEM_MOD_INTELLECT_SHORT or 0)*rule.percent/100
        if armor~=0 then adjusted.RESISTANCE0_NAME=(adjusted.RESISTANCE0_NAME or 0)+armor;notes[#notes+1]=rule.name..": +"..string.format("%.1f",armor).." armor from item Intellect (source-based)" end
    end
    return adjusted,notes
end
local function plain(text)
    if type(text)~="string" then return "" end
    return text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|T.-|t","")
end
function G.Facts(link)
    if not link then return {lines={},effects={},gems={},sockets=0} end
    local info=ns.API.Item(link)
    if not info then return {lines={},effects={},gems={},sockets=0,pending=true} end
    G.factCache=G.factCache or {};local key=tostring(ns.State.inventoryRevision or 0)..":"..tostring(ns.State.itemRevision or 0)..":"..link
    if G.factCache[key] then return G.factCache[key] end
    if G.factRevision~=ns.State.inventoryRevision then G.factCache={};G.factRevision=ns.State.inventoryRevision end
    local data=ns.API.Call("C_TooltipInfo","GetHyperlink",link)
    local facts={lines={},effects={},gems={},setID=info.setID}
    local locale=type(GetLocale)=="function" and GetLocale() or "enUS"
    local english=locale=="enUS" or locale=="enGB"
    for index,line in ipairs(data and ns.Safe(data.lines,{}) or {}) do
        local left=plain(ns.Safe(line.leftText));local right=plain(ns.Safe(line.rightText))
        if left~="" or right~="" then facts.lines[#facts.lines+1]=left..(right~="" and "  |  "..right or "") end
        local color=ns.Safe(line.leftColor);local red,green
        if color then
            if color.GetRGB then red,green=color:GetRGB() else red,green=color.r,color.g end
            red,green=ns.Safe(red),ns.Safe(green)
        end
        if english then
            local low,high=left:match("^%s*(%d+%.?%d*)%s*%-%s*(%d+%.?%d*)%s+Damage")
            if low and high and not facts.minimum then facts.minimum=tonumber(low);facts.maximum=tonumber(high);facts.damageText=left end
            local speed=right:match("Speed%s+(%d+%.?%d*)") or left:match("^Speed%s+(%d+%.?%d*)")
            if speed then facts.speed=tonumber(speed);facts.speedText=right~="" and right or left end
            local dps=left:match("(%d+%.?%d*)%s+damage per second")
            if dps then facts.dps=tonumber(dps) end
        end
        -- Item quality colors the title green too; the title is never an effect.
        if index>1 and ((english and (left:match("^Equip:") or left:match("^Use:") or left:match("^Chance on hit:") or left:find("Set:",1,true))) or (red and green and green>.7 and green>red*1.3)) then
            facts.effects[#facts.effects+1]=left..(right~="" and "  "..right or "")
        end
    end
    local stats=ns.API.Call("C_Item","GetItemStats",link)
    facts.dps=facts.dps or stats and ns.Safe(stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT)
    facts.useName,facts.useSpell=ns.API.Call("C_Item","GetItemSpell",link)
    facts.useName,facts.useSpell=ns.Safe(facts.useName),ns.Safe(facts.useSpell)
    if facts.useSpell then facts.useDescription=ns.Safe(ns.API.Call("C_Spell","GetSpellDescription",facts.useSpell)) end
    if facts.setID then facts.setName=ns.Safe(ns.API.Call("C_Item","GetItemSetInfo",facts.setID)) end
    facts.sockets=ns.Safe(ns.API.Call("C_Item","GetItemNumSockets",link),0)
    for i=1,math.min(8,facts.sockets) do
        local name,gem=ns.API.Call("C_Item","GetItemGem",link,i)
        facts.gems[#facts.gems+1]=ns.Safe(gem) or ns.Safe(name) or "Empty socket"
    end
    if not data then facts.pending=true end
    if not facts.pending then G.factCache[key]=facts end;return facts
end
function G.SetCounts(candidate,slot)
    local set=candidate.info and candidate.info.setID
    if not set then return end
    local before,after=0,1
    for _,entry in ipairs(ns.Data.slots) do
        local equipped=ns.State.equipment[entry[1]];local info=equipped and (equipped.info or equipped.link and ns.API.Item(equipped.link))
        if info and info.setID==set then
            before=before+1
            if entry[1]~=slot and not (candidate.info.equip=="INVTYPE_2HWEAPON" and entry[1]==17) then after=after+1 end
        end
    end
    return before,after
end
function G.EquipCheck(candidate,slot)
    local usable,reason=ns.API.ItemEligibility(candidate.id,candidate.info)
    if usable~=true then return false,reason end
    local fits=false
    for _,allowed in ipairs(ns.Data.equipSlots[candidate.info.equip] or {}) do if allowed==slot then fits=true;break end end
    if not fits then return false,"This item does not fit the selected slot" end
    if slot==17 then
        if candidate.info.equip=="INVTYPE_WEAPON" or candidate.info.equip=="INVTYPE_WEAPONOFFHAND" then
            local dual=type(CanDualWield)=="function" and ns.Safe(CanDualWield())
            if dual~=true then return false,dual==false and "Your character cannot dual wield" or "Client dual-wield eligibility is unavailable" end
        end
        local main=ns.State.equipment[16]
        if main and main.id and not main.info then return false,"Waiting for main-hand item data" end
        if main and main.info and main.info.equip=="INVTYPE_2HWEAPON" then return false,"Equip a compatible main-hand weapon before comparing this off-hand" end
    end
    local category,maximum=ns.API.Call("C_Item","GetItemUniqueness",candidate.link or candidate.id)
    category,maximum=ns.Safe(category),ns.Safe(maximum)
    maximum=maximum and maximum>0 and maximum or 1
    local unique=ns.Safe(ns.API.Call("C_Item","GetItemUniquenessByID",candidate.id),false)
    local count=0
    for equippedSlot,item in pairs(ns.State.equipment) do
        if item.id and equippedSlot~=slot and not (candidate.info.equip=="INVTYPE_2HWEAPON" and equippedSlot==17) then
            local same=unique and item.id==candidate.id
            if category and category~=0 then local other=ns.Safe(ns.API.Call("C_Item","GetItemUniqueness",item.link or item.id));same=other==category end
            if same then count=count+1 end
        end
    end
    if (category and category~=0 or unique) and count>=(maximum or 1) then return false,"Unique-equipped conflict with another equipped slot" end
    return true
end
function G.StatDeltas(candidate,slot)
    local current=ns.State.equipment[slot];local before=current and current.link and ns.API.Call("C_Item","GetItemStats",current.link) or {}
    local after=ns.API.Call("C_Item","GetItemStats",candidate.link);if type(after)~="table" then return {} end
    local keys={};for key in pairs(before or {}) do keys[key]=true end;for key in pairs(after) do keys[key]=true end
    local off=candidate.info.equip=="INVTYPE_2HWEAPON" and ns.State.equipment[17]
    local lost=off and off.link and ns.API.Call("C_Item","GetItemStats",off.link) or {}
    for key in pairs(lost or {}) do keys[key]=true end
    local rows={}
    for key in pairs(keys) do
        local old=ns.Safe(before and before[key],0)+ns.Safe(lost and lost[key],0);local new=ns.Safe(after[key],0)
        if old~=new then rows[#rows+1]={key=key,name=_G[key] or key:gsub("ITEM_MOD_",""):gsub("_SHORT",""):gsub("_"," "),before=old,after=new,delta=new-old} end
    end
    table.sort(rows,function(a,b) return a.name<b.name end);return rows
end
