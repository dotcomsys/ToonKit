local addonName, ns = ...
local R={};ns.QuestRewards=R
local function integer(value,min,max)
    value=ns.Safe(value)
    return type(value)=="number" and value==value and value>=min and value<=max and value==math.floor(value) and value or nil
end
function R.Read(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b,c,d,e,f,g,h=pcall(fn,...)
    if ok then return ns.Safe(a),ns.Safe(b),ns.Safe(c),ns.Safe(d),ns.Safe(e),ns.Safe(f),ns.Safe(g),ns.Safe(h) end
end
local function rewardIdentity(id,link)
    local nativeID=integer(id,1,2147483647)
    local linkedID=type(link)=="string" and integer(tonumber(link:match("item:(%d+)")),1,2147483647)
    if nativeID and linkedID and nativeID~=linkedID then return nil,nil end
    return nativeID or linkedID,linkedID and link or nil
end
function R.TooltipOwner(tooltip)
    local owner=tooltip and type(tooltip.GetOwner)=="function" and tooltip:GetOwner()
    if not owner or ns.Safe(owner.objectType)~="item" then return end
    local rewardType=ns.Safe(owner.type)
    if (rewardType=="choice" or rewardType=="reward") and type(ns.Safe(owner.questID))=="number" then return owner end
end
function R.Items(log,quest)
    local count
    if log then count=integer(R.Read(GetNumQuestLogChoices,quest,true),0,100)
    else count=integer(R.Read(GetNumQuestChoices),0,100) end
    local rows={};local complete=count~=nil;local itemIndex=0
    for index=1,count or 0 do
        local loot
        if log then loot=R.Read(GetQuestLogChoiceInfoLootType,index)
        else loot=R.Read(GetQuestItemInfoLootType,"choice",index) end
        if loot==0 then
            itemIndex=itemIndex+1
            local _,_,quantity,_,usable,id
            if log then _,_,quantity,_,usable,id=R.Read(GetQuestLogChoiceInfo,index)
            else _,_,quantity,_,usable,id=R.Read(GetQuestItemInfo,"choice",index) end
            local link
            if log then link=R.Read(GetQuestLogItemLink,"choice",itemIndex)
            else link=R.Read(GetQuestItemLink,"choice",index) end
            id,link=rewardIdentity(id,link)
            if not id then complete=false end
            rows[#rows+1]={type="choice",index=log and itemIndex or index,id=id,link=link,quantity=integer(quantity,1,1000000),usable=usable}
        else
            -- Currency and unknown loot types cannot be valued as vendor items.
            complete=false
        end
    end
    local fixedCount
    if log then fixedCount=integer(R.Read(GetNumQuestLogRewards),0,100)
    else fixedCount=integer(R.Read(GetNumQuestRewards),0,100) end
    for index=1,fixedCount or 0 do
        local _,_,quantity,_,usable,id
        if log then _,_,quantity,_,usable,id=R.Read(GetQuestLogRewardInfo,index)
        else _,_,quantity,_,usable,id=R.Read(GetQuestItemInfo,"reward",index) end
        local link
        if log then link=R.Read(GetQuestLogItemLink,"reward",index)
        else link=R.Read(GetQuestItemLink,"reward",index) end
        id,link=rewardIdentity(id,link)
        rows[#rows+1]={type="reward",index=index,id=id,link=link,
            quantity=integer(quantity,1,1000000),usable=usable}
    end
    return rows,complete
end
function R.Analyze(rows,complete,yieldRow)
    local result={rows={},buttons={choice={},reward={}},complete=complete~=false};local maximum=0
    for _,row in ipairs(rows) do
        local entry=ns.Copy(row);local info=row.id and ns.API.Item(row.link or row.id)
        entry.info=info
        entry.vendor=ns.ItemComparison.VendorValue(info,row.quantity)
        if entry.vendor~=nil then
            if row.type=="choice" then maximum=math.max(maximum,entry.vendor) end
        elseif row.type=="choice" then result.complete=false end
        if info then
            if type(info.required)=="number" and info.required>(ns.State.level or 0) then
                entry.advice={kind="manual",text="Requires level "..info.required}
            elseif row.usable==false then entry.advice={kind="unusable",text="Cannot equip this quest reward"}
            elseif not ns.ItemComparison then entry.advice={kind="manual",text="Gear comparison unavailable"}
            else
                local ok,advice=pcall(ns.ItemComparison.Cached,row.id,row.link or info.link)
                if ok then entry.advice=advice else
                    ns.errors.questRewardItem=tostring(row.id)..": "..tostring(advice)
                    entry.advice={kind="manual"}
                end
            end
        end
        entry.upgrade=entry.advice and entry.advice.kind=="upgrade" and row.usable~=false and info and ns.API.ItemEligibility(row.id,info)==true or false
        result.rows[#result.rows+1]=entry;result.buttons[row.type][row.index]=entry
        if yieldRow then yieldRow(entry) end
    end
    if result.complete and maximum>0 then
        result.maximum=maximum;result.ties=0
        local sellOnly=true
        for _,entry in ipairs(result.rows) do
            if entry.type=="choice" and entry.info and ns.Data.equipSlots[entry.info.equip]
                and (not entry.advice or entry.advice.kind~="noUpgrade" and entry.advice.kind~="unusable") then sellOnly=false end
        end
        for _,entry in ipairs(result.rows) do
            if entry.type=="choice" and entry.vendor==maximum then
                entry.bestVendor=true;entry.sellChoice=sellOnly;result.ties=result.ties+1
            end
        end
    end
    return result
end
