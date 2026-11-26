local addonName, ns = ...
local M,U,G=ns.Main,ns.UI,ns.Gear
local E={weightRevision=0};ns.EquipmentView=E
local function slotLabel(slot)
    local id,name=slot[1],slot[2]
    return id>=11 and id<=14 and (name.." "..(id%2==1 and "1" or "2")) or name
end
local function visible() return U.main and U.main:IsShown() and M.tab=="Character" and M.sub=="Equipment" end
local function available() return visible() and not M.gearRequirementRecord and not M.showWeights and (not E.scope or E.scope=="available") end
local function refresh(immediate)
    if not visible() then return end
    ns.After("equipmentResults",function()
        if not visible() then return end
        if M.Editing() then M.pendingRefresh=true else M.Render() end
    end,immediate and .05 or .45)
end
local function fresh(job)
    return job and not job.interrupted and job.slot==(E.slot or 16) and job.inventory==ns.State.inventoryRevision
        and job.talents==ns.Talents.revision and job.quests==ns.State.questRevision and job.level==ns.State.level
        and job.focus==E.sourceFocus and job.inspection==E.inspection and job.role==ns.char.playstyle
        and job.weights==ns.db.settings.weights and job.weightRevision==E.weightRevision
end
local function sources()
    if E.sourceFocus then coroutine.yield(E.sourceFocus) end
    for _,item in ipairs(ns.State.bags) do if item.id then coroutine.yield({id=item.id,link=item.link,source="In your bags",owned=true}) end end
    for _,item in ipairs(ns.Data.gearSources or {}) do coroutine.yield(item) end
    for _,d in ipairs(ns.Data.journals or {}) do
        for _,boss in ipairs(d.encounters or {}) do for _,item in ipairs(boss.loot or {}) do
            coroutine.yield({id=item.id,source=d.name..": "..boss.name,dungeon=d.key,classes=item.classes,
                boss=boss.name,bossKey=boss.id,referenceOnly=item.referenceOnly,
                foreverLive=d.foreverLive==true,sourceKnown=d.foreverLive==true and not item.referenceOnly})
        end end
    end
end
local function sourcePriority(raw)
    if raw.source=="In your bags" then return 3 end
    if raw.referenceOnly or raw.sourceKnown==false or raw.quest and ns.API.QuestDone(raw.quest) then return 0 end
    return (raw.sourceKnown or raw.foreverLive or raw.capSourceKnown) and 2 or 1
end
local function better(a,b)
    if a.usable~=b.usable then return a.usable==true end
    if not not a.upgrade~=not not b.upgrade then return not not a.upgrade end
    if (a.weaponDelta or 0)~=(b.weaponDelta or 0) then return (a.weaponDelta or 0)>(b.weaponDelta or 0) end
    if (a.delta or -math.huge)~=(b.delta or -math.huge) then return (a.delta or -math.huge)>(b.delta or -math.huge) end
    return a.id<b.id
end
local function score(job,raw)
    local inspection=raw.id==job.inspection
    if type(raw.id)~="number" or raw.classic or not inspection and
        (raw.required and raw.required>ns.State.level or not G.SourceConditions(raw)) then return end
    local existing=job.byID[raw.id]
    local variant=existing and raw.source=="In your bags" and existing.source==raw.source and raw.link and raw.link~=existing.link
    if existing and not variant and sourcePriority(raw)<=existing.priority then
        if raw.source and existing.source~=raw.source then
            existing.alternatives=existing.alternatives or {};existing.alternatives[raw.source]=raw
        end
        return
    end
    if not inspection then
        local itemID,_,_,equip,_,classID=ns.API.Call("C_Item","GetItemInfoInstant",raw.link or raw.id)
        itemID,equip,classID=ns.Safe(itemID),ns.Safe(equip),ns.Safe(classID)
        if itemID==raw.id and type(equip)=="string" then
            local slots=ns.Data.equipSlots[equip]
            local knownNonEquipment=equip=="" and type(classID)=="number" and classID~=2 and classID~=4
            if knownNonEquipment then return end
            if slots then
                local fits=false
                for _,slot in ipairs(slots) do if slot==job.slot then fits=true;break end end
                if not fits then return end
            end
        end
    end
    local info=ns.API.Item(raw.link or raw.id,true)
    if not info then
        if ns.API.failed[raw.id] or not ns.API.queued[raw.id] and not ns.API.requested[raw.id] then
            job.unavailable[raw.id]=true;return
        end
        local pending=job.pending[raw.id] or {}
        pending[#pending+1]=raw;job.pending[raw.id]=pending
        return
    end
    local fits=false;for _,slot in ipairs(ns.Data.equipSlots[info.equip] or {}) do if slot==job.slot then fits=true end end
    if not fits or not inspection and info.required>ns.State.level then return end
    local record={}
    for key,value in pairs(raw) do if key~="alternatives" then record[key]=value end end
    record.info=info;record.link=raw.link or info.link
    record.referenceOnly=raw.referenceOnly or raw.sourceKnown==false or inspection and not G.SourceConditions(raw)
        or raw.quest and not raw.owned and ns.API.QuestDone(raw.quest)
    local eligible,reason=G.EquipCheck(record,job.slot)
    local usable=eligible==true
    local comparison=usable and ns.ItemComparison.Compare(record.id,record.link,job.slot)
    if not usable and not inspection and not raw.owned then return end
    record.priority=sourcePriority(raw)
    record.usable=usable;record.eligibilityReason=reason;record.delta=comparison and comparison.delta;record.weaponDelta=comparison and comparison.weaponDelta
    record.decision=ns.ItemComparison.StatusText(comparison,comparison and comparison.kind=="upgrade")
    record.upgrade=usable and not record.referenceOnly and comparison and comparison.kind=="upgrade"
    record.owned=(ns.State.owned[raw.id] or 0)>0
    if variant and not better(record,existing) then return end
    if existing then
        record.rowIndex=existing.rowIndex;record.alternatives=existing.alternatives or {}
        if existing.source and existing.source~=record.source then record.alternatives[existing.source]=existing end
        if record.source then record.alternatives[record.source]=nil end
        existing.alternatives=nil
    else record.rowIndex=#job.rows+1 end
    job.rows[record.rowIndex]=record;job.byID[record.id]=record;job.sortedRows=nil
end
local function evaluate(job,raw)
    local ok,err=pcall(score,job,raw)
    if not ok then
        job.error=tostring(err);ns.errors.equipmentScan=job.error;job.running=false
    end
    return ok
end
function E.Start()
    if E.job and E.job.running then E.job.running=false end
    ns.errors.equipmentScan=nil
    E.job={slot=E.slot or 16,rows={},pending={},unavailable={},byID={},iterator=coroutine.create(sources),running=true,
        inventory=ns.State.inventoryRevision,talents=ns.Talents.revision,quests=ns.State.questRevision,level=ns.State.level,
        focus=E.sourceFocus,inspection=E.inspection,role=ns.char.playstyle,weights=ns.db.settings.weights,weightRevision=E.weightRevision}
    E.jobs=E.jobs or {};E.jobs[E.job.slot]=E.job
    local job=E.job
    local firstTick=true
    local function tick()
        if E.job~=job or not job.running then return end
        if not available() or not fresh(job) then
            job.running=false;job.interrupted=true;refresh(true);return
        end
        local started=type(debugprofilestop)=="function" and debugprofilestop()
        local previousCount,previousSort=#job.rows,job.sortedRows
        for index=1,12 do
            local ok,raw=coroutine.resume(job.iterator)
            if not ok then job.error=tostring(raw);ns.errors.equipmentScan=job.error;job.running=false;break end
            if not raw then job.running=false;break end
            if not evaluate(job,raw) then break end
            if started and debugprofilestop()-started>=2 then break end
        end
        if firstTick or not job.running or #job.rows~=previousCount or job.sortedRows~=previousSort then refresh(not job.running) end
        firstTick=false
        if job.running then C_Timer.After(.03,tick) end
    end
    tick()
end
local function resolveWaitingSlot()
    if not E.waitingSlot then return false end
    local id=E.waitingSlot
    local info=ns.API.Item(E.sourceFocus and E.sourceFocus.id==id and E.sourceFocus.link or id)
    local slots=info and ns.Data.equipSlots[info.equip]
    if slots then
        E.slot=slots[1];E.waitingSlot=nil;return true
    end
    if info or not ns.API.queued[id] and not ns.API.requested[id] then
        E.wanted=nil;E.waitingSlot=nil;return true
    end
    return false
end
local function itemReady()
    if visible() and M.gearRequirementRecord then refresh();return end
    if visible() and E.scope and E.scope~="available" then refresh() end
    if resolveWaitingSlot() then refresh(true) end
    local job=E.job;if not available() or not fresh(job) or job.error or not next(job.pending) then return end
    local count=0;local started=type(debugprofilestop)=="function" and debugprofilestop()
    for id,items in pairs(job.pending) do
        if ns.API.itemCache[items[1].link or id] or not ns.API.queued[id] and not ns.API.requested[id] then
            job.pending[id]=nil
            if ns.API.failed[id] then job.unavailable[id]=true
            else for _,raw in ipairs(items) do if not evaluate(job,raw) then refresh(true);return end end end
            count=count+1
            if count>=12 or started and debugprofilestop()-started>=2 then break end
        end
    end
    if count>0 and next(job.pending) then ns.After("equipmentItemDrain",itemReady) end
    refresh()
end
ns.Listen("ITEM_DATA_READY",itemReady)
ns.Listen("EQUIPMENT_WEIGHTS_CHANGED",function() E.weightRevision=E.weightRevision+1 end)
ns.Listen("ITEM_DATA_UNAVAILABLE",function(id)
    local affected
    if E.job and E.job.pending[id] then
        E.job.pending[id]=nil;E.job.unavailable[id]=true;affected=true
    end
    if E.waitingSlot==id then E.waitingSlot=nil;E.wanted=nil;affected=true end
    if affected then refresh(true) end
end)
local function targetRows(completed,removed)
    local rows={}
    for id,target in pairs(removed and ns.char.gearRemovedTargets or ns.char.farming) do
        local done=target.obtained or (ns.State.owned[id] or 0)>0
        if removed or not not done==completed then
            local info=ns.API.Item(id,true)
            local slots=info and ns.Data.equipSlots[info.equip]
            if slots and slots[1] then local record=ns.Copy(target);record.id=id;record.info=info;record.link=info.link;record.owned=done;record.slot=slots[1];rows[#rows+1]=record end
        end
    end
    table.sort(rows,function(a,b) if a.slot~=b.slot then return a.slot<b.slot end;return a.info.name<b.info.name end);return rows
end
local function sourceRecord(selected)
    if not E.sourceChoice or E.sourceChoice.id~=selected.id then return selected end
    local item=ns.Copy(E.sourceChoice)
    item.info=ns.API.Item(item.link or item.id,true)
    item.link=item.link or item.info and item.info.link;item.slot=selected.slot;item.owned=selected.owned
    item.referenceOnly=item.referenceOnly or item.sourceKnown==false or item.quest and not item.owned and ns.API.QuestDone(item.quest)
    return item
end
function M.Equipment()
    if M.showWeights then return M.GearWeights() end
    if M.gearRequirementRecord then return M.GearRequirementsView() end
    resolveWaitingSlot()
    local C=ns.Connected
    if E.job and E.job.slot~=(E.slot or 16) then
        if E.job.running then E.job.running=false;E.job.interrupted=true end
        E.job=E.jobs and E.jobs[E.slot or 16]
        if E.job and next(E.job.pending) then ns.After("equipmentItemDrain",itemReady) end
    end
    ns.char.gearRemovedTargets=ns.char.gearRemovedTargets or {}
    local slotName="Main hand"
    for _,slot in ipairs(ns.Data.slots) do
        if slot[1]==(E.slot or 16) then slotName=slotLabel(slot) end
    end
    local profile=ns.ItemComparison.Profile()
    local allocation=table.concat(ns.Talents.totals or {0,0,0}," / ")
    local detected=U.Label(M.body,"Auto: "..(profile.valid and (profile.name.." ("..allocation..")") or (ns.Talents.readReason or ns.Talents.detected or "Waiting for native talents")),8,M.y-8,math.max(160,M.width-380),"GameFontNormal")
    local find=U.Button(M.body,E.job and E.job.running and "Searching…" or "Refresh hunts",145,function()
        for id in pairs(E.job and E.job.unavailable or {}) do ns.API.failed[id]=nil end
        E.scope="available";E.Start();M.Render()
    end)
    find:SetPoint("TOPLEFT",M.width-355,M.y);find:SetEnabled(not E.job or not E.job.running)
    local search=U.Edit(M.body,190,E.query or "",function(value) E.query=value:lower();E.selected=nil;M.Render() end)
    search:SetPoint("TOPLEFT",M.width-200,M.y);U.Placeholder(search,"Search loaded items; Enter to filter")
    search:SetScript("OnEscapePressed",function(self) self:ClearFocus();E.query="";M.Render() end)
    M.y=M.y-36
    local tabs=U.Options(M.body,{{value="available",label="Upgrades"},{value="active",label="Tracked"},{value="completed",label="Completed"},{value="removed",label="Removed"}},E.scope or "available",math.min(600,M.width-16),function(value) E.scope=value;E.selected=nil;E.sourceChoice=nil;M.Render() end,4)
    if (E.scope or "available")=="available" then
        local browse=U.Button(M.body,E.browse and "Show upgrades only" or "Browse all gear",160,function()
            E.browse=not E.browse;E.selected=nil;E.sourceChoice=nil;E.wanted=nil;E.inspection=nil;E.sourceFocus=nil;M.Render()
        end)
        browse:SetPoint("LEFT",tabs,"RIGHT",8,0)
    end
    tabs:SetPoint("TOPLEFT",8,M.y);M.y=M.y-tabs:GetHeight()-8
    local plans=U.Button(M.body,"Talent plans",135,function() M.OpenPage("Talents") end)
    plans:SetPoint("TOPRIGHT",M.body,"TOPRIGHT",-8,M.y+tabs:GetHeight()+8)
    local top=M.y;local height=math.max(240,M.scroll:GetHeight()+top-32)
    local railWidth=204;local leftWidth=math.floor((M.width-railWidth-32)*.46)
    local rail=C.Pane(M.body,railWidth,height,8,top,"gearSlots")
    local railRowWidth=rail.content:GetWidth()
    for index,slot in ipairs(ns.Data.slots) do
        local slotID=slot[1];local equipped=ns.State.equipment[slotID]
        local button=U.New("Button",rail.content,"BackdropTemplate","gearSlotPicker")
        button:SetPoint("TOPLEFT",0,-(index-1)*44);button:SetSize(railRowWidth,41)
        button:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8})
        button:SetBackdropColor(.12,.08,.035,.85);button:SetBackdropBorderColor(slotID==(E.slot or 16) and 1 or .4,.65,.18,1)
        button.icon=button.icon or button:CreateTexture(nil,"ARTWORK");button.icon:SetSize(28,28);button.icon:SetPoint("LEFT",6,0)
        button.icon:SetTexture(equipped and (equipped.icon or equipped.info and equipped.info.icon) or "Interface\\Icons\\INV_Misc_QuestionMark")
        local name=slotLabel(slot)
        U.Label(button,name,41,-4,railRowWidth-46,"GameFontNormalSmall")
        local current=U.Label(button,equipped and equipped.info and equipped.info.name or (equipped and equipped.id and "Loading item" or "Empty"),41,-20,railRowWidth-46,"GameFontHighlightSmall")
        current:SetWordWrap(false)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
        button:SetScript("OnClick",function()
            if E.job and E.job.running then E.job.running=false;E.job.interrupted=true end
            E.slot=slotID;E.scope="available";E.selected=nil;E.wanted=nil;E.sourceChoice=nil;E.sourceFocus=nil;E.inspection=nil;E.job=E.jobs and E.jobs[slotID]
            M.Render()
        end)
        button:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(slot[2])
            if equipped and equipped.link then GameTooltip:SetHyperlink(equipped.link) end;GameTooltip:Show()
        end)
        button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    rail.content:SetHeight(#ns.Data.slots*44);C.UpdateScroll(rail)
    local candidates=C.Pane(M.body,leftWidth,height,railWidth+16,top,"gearCandidates")
    local details=C.Pane(M.body,M.width-leftWidth-railWidth-32,height,leftWidth+railWidth+24,top,"gearDetails",true)
    if (E.scope or "available")=="available" and not E.waitingSlot and not fresh(E.job) and not (E.job and E.job.running) then
        ns.After("equipmentAutoHunts",function()
            if available() and not E.waitingSlot and not fresh(E.job) and not (E.job and E.job.running) then E.Start() end
        end)
    end
    local job=E.job;local scope=E.scope or "available";local rows={}
    local pending,unavailable=0,0
    if job then
        for _ in pairs(job.pending) do pending=pending+1 end
        for _ in pairs(job.unavailable) do unavailable=unavailable+1 end
    end
    local listKey=scope..":"..tostring(E.slot or 16)..":"..(E.query or "")..":"..tostring(E.browse)
    if candidates.context~=listKey then candidates.scroll:SetVerticalScroll(0);candidates.context=listKey end
    if scope=="available" and job then
        if not job.sortedRows then
            job.sortedRows={};for _,item in ipairs(job.rows) do job.sortedRows[#job.sortedRows+1]=item end
            table.sort(job.sortedRows,better)
        end
        if E.browse then rows=job.sortedRows
        else
            for _,item in ipairs(job.sortedRows) do
                if item.id==E.inspection or fresh(job) and item.upgrade then rows[#rows+1]=item end
            end
        end
    elseif scope~="available" then rows=targetRows(scope=="completed",scope=="removed") end
    local total=#rows
    if E.query and E.query~="" then
        local filtered={};for _,item in ipairs(rows) do
            if ((item.info.name or "").." "..(item.source or "")):lower():find(E.query,1,true) then filtered[#filtered+1]=item end
        end
        rows=filtered
    end
    local selected,list=nil,{}
    for _,item in ipairs(rows) do
        if item.id==(E.wanted or E.selected) then selected=item end
        local ownership=item.owned and "Owned" or ns.char.farming[item.id] and "Tracked"
        local state=not fresh(job) and scope=="available" and "Updating"
            or item.usable==false and "Check requirements" or item.referenceOnly and "Source reference" or item.decision
        if ownership then state=state and (state.." · "..ownership) or ownership end
        local section=slotName
        if item.slot then for _,slot in ipairs(ns.Data.slots) do if slot[1]==item.slot then section=slot[2];break end end end
        local source=item.source or "Source unavailable"
        list[#list+1]={value=item.id,label=item.info.link or item.info.name,icon=item.info.icon,iconSize=32,link=item.link,section=section,subtitle=state and (state.." · "..source) or source}
    end
    if not selected and not E.wanted then selected=rows[1] end
    E.selected=selected and selected.id
    local reveal=selected and selected.id==E.wanted
    if reveal then E.wanted=nil end
    if #list>0 then C.ScrollJournalList(candidates,list,E.selected,function(id) E.selected=id;E.wanted=nil;E.sourceChoice=nil;M.Render() end,reveal)
    else C.Read(candidates,function()
        M.Line(slotName,"GameFontNormal")
        if scope=="available" and E.waitingSlot then M.Line("Waiting for the requested item’s details.")
        elseif scope=="available" and job and job.error then M.Line("Search stopped. Use Refresh hunts to retry.")
        elseif scope=="available" and (not fresh(job) or job.running) then M.Line("Searching Forever sources for this slot…")
        elseif scope=="available" and pending>0 then M.Line("Waiting for "..pending.." item details from the client.")
        elseif total>0 then
            M.Line("No items match this filter.")
            M.Action("Clear filter",function() E.query="";M.Render() end,140)
        elseif scope=="available" and not E.browse then
            M.Line("No confirmed upgrades found for this slot.")
            M.Action("Browse all gear",function() E.browse=true;M.Render() end,160)
            if unavailable>0 then M.Line("Some item details remain unavailable.","GameFontHighlightSmall") end
        elseif scope=="available" and unavailable>0 then M.Line("No eligible results among the loaded items. Use Refresh hunts to retry missing item details.")
        elseif scope=="available" then M.Line("No eligible items found for this slot.")
        else M.Line("No items in this list.") end
    end,scope..":"..(E.slot or 16)) end
    C.Read(details,function()
        if scope=="available" and job and not fresh(job) then M.Line("Updating recommendations for your current equipment and talents.","GameFontHighlightSmall") end
        if job and scope=="available" then
            if job.error then M.Line("Search stopped; see local diagnostics.") end
            if pending>0 and not job.error then M.Line("Loading item details: "..pending,"GameFontHighlightSmall") end
            if unavailable>0 then M.Line("Item details unavailable: "..unavailable,"GameFontHighlightSmall") end
        end
        if not selected then
            if E.wanted then
                local loading=E.waitingSlot or job and (job.running or job.pending[E.wanted])
                M.Line(loading and "Looking up the requested item…" or "The requested item is unavailable for this slot. You can choose another item from the list.")
            else M.Line("Select an item to see where it comes from and compare it with your equipment.") end
            return
        end
        local item=sourceRecord(selected)
        local itemSlot=selected.slot or E.slot or 16;local itemSlotName=slotName
        for _,slot in ipairs(ns.Data.slots) do if slot[1]==itemSlot then itemSlotName=slotLabel(slot);break end end
        M.Line(itemSlotName,"GameFontNormal")
        C.ItemTiles({item},function(record) ns.ItemCompare.Show(record) end)
        local canEquip,eligibility
        if item.info then canEquip,eligibility=G.EquipCheck(item,itemSlot) end
        local decision,advice=ns.ItemComparison.ItemDecision(item.id,item.link,item.info,itemSlot)
        if decision then M.Line(decision,"GameFontNormal") end
        if not canEquip and eligibility then M.Line(eligibility,"GameFontHighlightSmall") end
        local value=ns.ItemComparison.VendorValue(item.info,1)
        if value~=nil then M.Line("Verified vendor value · "..ns.Gold.Format(value),"GameFontHighlightSmall") end
        M.Heading("Acquisition")
        M.Line(item.source or "No confirmed acquisition instructions available.")
        if item.requirements then M.Line(item.requirements) end
        if item.referenceOnly or item.reference then M.Line("Source reference; current acquisition is unconfirmed.","GameFontHighlightSmall") end
        if item.quest then M.Line("Quest: "..(ns.Safe(ns.API.Call("C_QuestLog","GetTitleForQuestID",item.quest)) or item.quest),"GameFontHighlightSmall") end
        if item.dungeon then local dungeon=ns.Journal.Get(item.dungeon);if dungeon then M.Line(dungeon.name,"GameFontHighlightSmall") end end
        M.Heading("Compared with equipped")
        local current=ns.State.equipment[itemSlot]
        if current and current.id then
            C.ItemTiles({current},function(record) ns.ItemCompare.Show(record) end)
        else M.Line("Nothing equipped in this slot.","GameFontHighlightSmall") end
        if advice then
            if advice.reason and advice.reason~=eligibility then M.Line(advice.reason,"GameFontHighlightSmall") end
        end
    end,"gear:"..tostring(E.selected)..":"..scope..":"..tostring(E.sourceChoice and E.sourceChoice.source))
    if selected then
        local item=sourceRecord(selected)
        local target=ns.char.farming[item.id]
        local actions={{label="Compare",run=function() ns.ItemCompare.Show(item) end}}
        if not target then actions[#actions+1]={label=scope=="removed" and "Restore" or "Track",run=function()
            if G.PlanReference(item) then ns.char.gearRemovedTargets[item.id]=nil;M.Render() else ns.Message("Load current usable item data before tracking.") end
        end,enabled=item.info~=nil and selected.usable~=false and not item.referenceOnly and not item.reference}
        else
            if ns.char.activeHunt==item.id then actions[#actions+1]={label="Return",run=G.StopFollowing}
            elseif not target.obtained and not item.owned then actions[#actions+1]={label="Start hunt",run=function() if not G.FollowHunt(item.id) then ns.Message("This hunt has no actionable current route yet.") end end} end
            actions[#actions+1]={label="Remove",run=function() G.UntrackHunt(item.id);M.Render() end}
        end
        local point=E.sourceChoice and E.sourceChoice.id==item.id and E.sourceChoice or item
        if point.map and point.x and point.y then actions[#actions+1]={label="Map",run=function() C.Map(point) end} end
        local sources={}
        if item.quest or item.recipeSpell or item.sourceKind=="crafted" then
            sources[#sources+1]={"Acquisition requirements",function() M.OpenGearRequirements(item) end}
        end
        if item.quest and ns.Journey.OnQuest(item.quest) then sources[#sources+1]={"Quest details",function() ns.QuestWorkspace.Details({id=item.quest}) end} end
        if item.dungeon then sources[#sources+1]={"Dungeon journal",function()
            local dungeon=ns.Journal.Get(item.dungeon)
            if not dungeon then ns.Message("No matching Forever dungeon entry.");return end
            M.OpenDungeonSource(dungeon,item)
        end} end
        if selected.alternatives then
            sources[#sources+1]={selected.source or "Original source",function() E.sourceChoice=nil;M.Render() end}
            local labels={}
            for label in pairs(selected.alternatives) do labels[#labels+1]=label end
            table.sort(labels)
            for _,label in ipairs(labels) do
                local alternative=selected.alternatives[label]
                sources[#sources+1]={label,function() E.sourceChoice=alternative;M.Render() end}
            end
        end
        if #sources>0 then actions[#actions+1]={label="Source",run=function(self) ns.QuestWorkspace.Menu(self,sources,340) end} end
        C.Footer(details,actions)
    else C.Footer(details,{}) end
    M.y=top-height-8
end
function M.OpenQuickGear(slot)
    if not slot then return M.OpenPage("Equipment") end
    return M.OpenPage("Equipment",function()
        E.slot=slot;E.scope="available";E.selected=nil;E.wanted=nil;E.waitingSlot=nil
        E.sourceChoice=nil;E.sourceFocus=nil;E.inspection=nil;E.query=""
    end)
end
function M.OpenGearCandidate(slot,id,source)
    if not id then return M.OpenQuickGear(slot) end
    return M.OpenPage("Equipment",function()
        E.waitingSlot=nil
        if not slot then
            local info=ns.API.Item(source and source.link or id)
            local slots=info and ns.Data.equipSlots[info.equip]
            if slots then slot=slots[1]
            elseif not info and (ns.API.queued[id] or ns.API.requested[id]) then E.waitingSlot=id end
        end
        E.slot=slot or E.slot or 16;E.selected=id;E.wanted=id;E.scope="available";E.sourceChoice=nil;E.query=""
        E.inspection=id;E.sourceFocus=source or {id=id,source="Requested item",referenceOnly=true}
        if E.job and id and not E.job.byID[id] then
            E.job.running=false;E.job.interrupted=true
        end
    end)
end
