local addonName, ns = ...
local G=ns.Gear
function G.CapTargets(level,profile)
    local cap=math.max(1,math.min(ns.Rules.Cap(),tonumber(level) or ns.Rules.Cap()));local key=table.concat({ns.State.inventoryRevision or 0,ns.State.questRevision or 0,ns.State.itemRevision or 0,ns.Talents.revision or 0,cap,ns.State.class,G.ScoringKey(profile),ns.Simulation and ns.Simulation.modelRevision or 0},":")
    if G.capKey==key then return G.capTargets end
    local roleKnown=G.RoleKnown(profile)
    local role=profile and profile.role or ns.State.role
    local physicalWeapon=role=="melee" or role=="ranged"
    local slots={};for _,s in ipairs(ns.Data.slots) do slots[s[1]]={ranked={},references={}} end
    for slot,equipped in pairs(ns.State.equipment) do if slots[slot] and equipped.id then
        local info=equipped.info or ns.API.Item(equipped.link or equipped.id)
        local evaluation=info and G.Evaluate(equipped.link or info.link,profile,slot)
        if info and evaluation and roleKnown then
            local facts=info.classID==2 and G.Facts(equipped.link or info.link)
            slots[slot].ranked[#slots[slot].ranked+1]={id=equipped.id,info=info,link=equipped.link or info.link,source="Currently equipped",capUsable=true,capSourceKnown=true,capScore=evaluation.score,capDPS=facts and facts.dps,capModeled=evaluation.simulationEffects~=nil,capEquipped=true}
        end
    end end
    for _,r in ipairs(G.Candidates()) do
        if r.info and (not G.SourceConditions or G.SourceConditions(r)) and math.max(r.info.required or 1,r.required or 1)<=cap and r.reason~="Other class" and (not r.class or r.class==ns.State.class) then
            local native=ns.Safe(ns.API.Call("C_PlayerInfo","CanUseItem",r.id))
            local evaluation=G.Evaluate(r.link,profile)
            local known=not r.classic and (r.actionable==true or r.live==true or r.sourceKnown==true)
            if not r.classic and r.catalog and r.corroborated and r.dungeon then
                local d=ns.Journal.Get(r.dungeon)
                known=d and d.required<=cap and d.foreverLive==true or false
            end
            for _,slot in ipairs(ns.Data.equipSlots[r.info.equip] or {}) do
                -- Retribution's two-handed target remains separate from a
                -- one-hand/off-hand build. Never apply this to another role.
                local fits=not (ns.State.class=="PALADIN" and role=="melee" and slot==16 and r.info.equip~="INVTYPE_2HWEAPON")
                if fits and slots[slot] then
                    local copy=ns.Copy(r);copy.capUsable=native==true and roleKnown and G.ArmorAppropriate(r.info,profile);copy.capSourceKnown=known;copy.capScore=evaluation and evaluation.score
                    copy.capArmorAllowed=G.ArmorAppropriate(r.info,profile)
                    copy.capModeled=evaluation and evaluation.simulationEffects~=nil
                    copy.capIncomplete=evaluation and (evaluation.simulationIncomplete or 0)>0
                    copy.capComparison=G.Compare(copy,slot,profile)
                    if copy.capComparison and copy.capComparison.loadout and copy.capComparison.loadout.partial then copy.capIncomplete=true end
                    if copy.capComparison and type(copy.capComparison.baseline)=="number" then copy.capScore=copy.capComparison.baseline+copy.capComparison.delta end
                    if r.info.classID==2 then local facts=G.Facts(r.link);copy.capDPS=facts and facts.dps end
                    local slotAllowed=G.EquipCheck(copy,slot)==true
                    copy.capEquipAllowed=slotAllowed
                    local needsDPS=physicalWeapon
                    local ranked=native==true and G.ArmorAppropriate(r.info,profile) and known and evaluation and roleKnown and slotAllowed and (r.info.classID~=2 or not needsDPS or copy.capDPS~=nil)
                    local list=ranked and slots[slot].ranked or slots[slot].references;list[#list+1]=copy
                end
            end
        end
    end
    for _,data in pairs(slots) do
        local function sort(a,b)
            if physicalWeapon and a.info.classID==2 and b.info.classID==2 and (a.capModeled or b.capModeled) then
                local weight=ns.db.settings.simulation.weaponWeight
                local left=(a.capScore or -math.huge)+(a.capDPS or 0)*weight
                local right=(b.capScore or -math.huge)+(b.capDPS or 0)*weight
                if left~=right then return left>right end
            end
            if physicalWeapon and a.info.classID==2 and b.info.classID==2 and a.capDPS and b.capDPS and a.capDPS~=b.capDPS then return a.capDPS>b.capDPS end
            if (a.capScore or -math.huge)~=(b.capScore or -math.huge) then return (a.capScore or -math.huge)>(b.capScore or -math.huge) end
            if a.id~=b.id then return a.id<b.id end;return (a.source or "")<(b.source or "")
        end
        table.sort(data.ranked,sort);table.sort(data.references,sort)
        local seen={}
        for _,name in ipairs({"ranked","references"}) do local unique={}
            for _,r in ipairs(data[name]) do
                local existing=seen[r.id]
                if existing then
                    local found=false;for _,source in ipairs(existing.acquisitions) do if source.source==r.source and source.quest==r.quest and source.dungeon==r.dungeon then found=true end end
                    if not found then existing.acquisitions[#existing.acquisitions+1]=ns.Copy(r) end
                else
                    local source=ns.Copy(r);r.acquisitions={source};seen[r.id]=r;unique[#unique+1]=r
                end
            end
            data[name]=unique
        end
    end
    -- Keep selected farming goals visible at the planning level even while
    -- native equip checks reject them today. They never become equip advice.
    do
        for _,fact in ipairs(G.SelectedTargets(cap,profile)) do if fact.required<=cap then
            local list=slots[fact.slot];local selected
            for _,kind in ipairs({"ranked","references"}) do for _,r in ipairs(list[kind]) do
                if r.id==fact.id then selected=r;break end
            end end
            if not selected then
                local info=ns.API.Item(fact.id,true)
                selected=ns.Copy(fact);selected.link=info and info.link or "item:"..fact.id
                selected.info=info or {name=fact.name,icon="Interface\\Icons\\INV_Misc_QuestionMark",required=fact.required,equip=fact.equip,classID=4,subID=fact.armor}
                selected.capPending=not info;selected.capSourceKnown=false;selected.capUsable=false;selected.capEquipAllowed=false
                selected.acquisitions={ns.Copy(selected)};list.references[#list.references+1]=selected
            end
            local known=selected.capSourceKnown==true
            local source=ns.Copy(fact);source.capSourceKnown=false;source.capEquipped=selected.capEquipped
            selected.acquisitions=selected.acquisitions or {};table.insert(selected.acquisitions,1,source)
            selected.capPreferred=true;selected.capArmorAllowed=true;selected.capSourceKnown=known
            if not known then
                selected.source=fact.source;selected.sourceKind=fact.sourceKind;selected.dungeon=fact.dungeon;selected.boss=fact.boss
                selected.requirements=fact.requirements;selected.provenance=fact.provenance
            end
            selected.required=math.max(selected.required or 1,fact.required)
            selected.capFuture=selected.required>ns.State.level
            -- The chosen BiS target is the primary target even if scalar stat
            -- weights favor an alternative. Retain actual scores for comparison.
            for i,r in ipairs(list.ranked) do if r==selected then table.insert(list.ranked,1,table.remove(list.ranked,i));break end end
        end end
    end
    local pairLimits={}
    local function uniqueLimit(r)
        if not pairLimits[r.id] then
            local category,maximum=ns.API.Call("C_Item","GetItemUniqueness",r.link or r.id)
            pairLimits[r.id]={ns.Safe(category),ns.Safe(maximum)}
        end
        return pairLimits[r.id][1],pairLimits[r.id][2]
    end
    local function compatible(a,b)
        if a.id==b.id then return false end
        local category,maximum=uniqueLimit(a)
        local other=uniqueLimit(b)
        return not (type(category)=="number" and category~=0 and category==other and (type(maximum)~="number" or maximum<2))
    end
    for _,pair in ipairs({{11,12},{13,14}}) do
        for side=1,2 do
            local anchor=G.SlotTarget(slots[pair[side]])
            if anchor and anchor.capPreferred then
                local partner=slots[pair[3-side]]
                for _,kind in ipairs({"ranked","references"}) do
                    local legal={};for _,candidate in ipairs(partner[kind]) do if compatible(anchor,candidate) then legal[#legal+1]=candidate end end
                    partner[kind]=legal
                end
            end
        end
        local left,right=slots[pair[1]].ranked,slots[pair[2]].ranked
        local best,aIndex,bIndex
        for ai=1,math.min(50,#left) do for bi=1,math.min(50,#right) do
            local a,b=left[ai],right[bi]
            if compatible(a,b) then
                local value=(a.capScore or 0)+(b.capScore or 0)
                if not best or value>best then best,aIndex,bIndex=value,ai,bi end
            end
        end end
        if aIndex then
            table.insert(left,1,table.remove(left,aIndex));table.insert(right,1,table.remove(right,bIndex))
            left[1].capPaired=true;right[1].capPaired=true
        elseif left[1] and right[1] then
            -- No legal pair: show one target, never two conflicting items.
            slots[pair[2]].ranked={};right=slots[pair[2]].ranked
        end
        local chosenLeft=left[1] or slots[pair[1]].references[1]
        if chosenLeft then
            local references={}
            for _,r in ipairs(slots[pair[2]].references) do if compatible(chosenLeft,r) then references[#references+1]=r end end
            slots[pair[2]].references=references
        end
        if right[1] and not left[1] then
            local references={}
            for _,r in ipairs(slots[pair[1]].references) do if compatible(right[1],r) then references[#references+1]=r end end
            slots[pair[1]].references=references
        end
    end
    G.capKey=key;G.capTargets=slots;return slots
end
function G.SlotTarget(list)
    for _,kind in ipairs({"ranked","references"}) do for _,r in ipairs(list[kind] or {}) do if r.capPreferred then return r end end end
    if list.ranked[1] then return list.ranked[1] end
    for _,r in ipairs(list.references) do if r.capArmorAllowed~=false then return r end end
end
function G.PlanSelectedTarget(r)
    if not r or not r.capPreferred then return false end
    ns.char.farming[r.id]={id=r.id,source=r.source,quest=r.quest,dungeon=r.dungeon,boss=r.boss,
        planned=true,reference=true,required=r.required,requirements=r.requirements,provenance=r.provenance,
        map=r.map,x=r.x,y=r.y,sourceKind=r.sourceKind,obtained=(ns.State.owned[r.id] or 0)>0}
    ns.Emit("STATE_CHANGED");return true
end
function G.PlanTarget(r)
    if not r or not r.capUsable or not r.capSourceKnown or r.capEquipAllowed==false then return false end
    ns.char.farming[r.id]={id=r.id,source=r.source,quest=r.quest,dungeon=r.dungeon,boss=r.boss,
        bossKey=r.encounter and r.encounter.id,catalog=r.catalog,planned=true,required=r.required,
        obtained=(ns.State.owned[r.id] or 0)>0}
    ns.Emit("STATE_CHANGED");return true
end
function G.ItemAdvice(id,link,container)
    if not ns.char or not id then return end
    local info=ns.API.Item(link or id);if not info then return end
    local quest=container and container.quest
    if info.classID==12 or type(quest)=="table" and (ns.Safe(quest.isQuestItem,false) or ns.Safe(quest.questID)) then
        return {kind="keep",icon="Interface\\GossipFrame\\AvailableQuestIcon",text="Keep: quest item"}
    end
    if ns.QuestSupplies and #ns.QuestSupplies.Lines(id)>0 then return {kind="keep",icon="Interface\\GossipFrame\\AvailableQuestIcon",text="Keep: known quest requirement"} end
    if ns.char.farming[id] or (ns.char.itemGroups or {})[id] then return {kind="keep",icon="Interface\\Icons\\INV_Misc_Bag_08",text="Keep: tracked or assigned item"} end
    if container and ns.InventoryRules then
        local sellable,reason=ns.InventoryRules.SellableGear(container)
        if sellable then return {kind="sell",icon="Interface\\Icons\\INV_Misc_Coin_01",text="Sellable gear: cannot use on this character",reason=reason} end
    end
    if info.quality==0 and info.sellPrice>0 then return {kind="sell",icon="Interface\\Icons\\INV_Misc_Coin_01",text="Poor-quality item: review before selling"} end
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(tooltip,data)
        if tooltip~=GameTooltip or not ns.db or not ns.char or ns.db.settings.gearItemAdvice==false then return end
        if ns.QuestRewards and ns.QuestRewards.TooltipOwner(tooltip) then return end
        local id=ns.Safe(data and data.id);if type(id)~="number" or tooltip.tkGearAdvice==id then return end
        tooltip.tkGearAdvice=id
        local link
        if type(tooltip.GetItem)=="function" then local _,value=tooltip:GetItem();link=ns.Safe(value) end
        if ns.ItemComparison and type(link)=="string" and tonumber(link:match("item:(%d+)"))==id then
            ns.ItemComparison.Append(tooltip,id,link)
        end
        local advice=G.ItemAdvice(id,link)
        if advice then tooltip:AddLine("|T"..advice.icon..":14|t "..advice.text,.8,.9,.65,true);if advice.reason then tooltip:AddLine(advice.reason,.8,.8,.7,true) end end
    end)
end
if GameTooltip and GameTooltip.HookScript then GameTooltip:HookScript("OnTooltipCleared",function(self) self.tkGearAdvice=nil end) end
ns.Listen("SETTINGS_CHANGED",function() G.capKey=nil end)
