local addonName, ns = ...
local R=ns.QuestRewards
local annotations={};local hooked={}
local function enabled()
    return ns.db and ns.char and ns.db.settings.gearItemAdvice~=false and ns.db.settings.modules.gear~=false
end
local function clear()
    for _,overlay in pairs(annotations) do
        overlay.upgrade:Hide();overlay.entry=nil
    end
end
local function appendStatus(button, itemID)
    local overlay=annotations[button];local entry=overlay and overlay.entry
    if not enabled() or not entry or not GameTooltip or not GameTooltip:IsOwned(button)
        or ns.Safe(button.questID)~=overlay.quest or itemID and itemID~=entry.id or GameTooltip.tkRewardStatus==entry then return end
    GameTooltip.tkRewardStatus=entry
    if entry.advice then
        if entry.takeUpgrade then GameTooltip:AddLine("Take for upgrade",.3,.9,.35,true)
        else ns.ItemComparison.AppendStatus(GameTooltip,entry.advice,entry.upgrade) end
        if entry.advice.reason and type(IsShiftKeyDown)=="function" and IsShiftKeyDown() then
            GameTooltip:AddLine(entry.advice.reason,.8,.8,.7,true)
        end
    else
        GameTooltip:AddLine("Item comparison unavailable",.8,.8,.7,true)
    end
    if entry.vendor~=nil then
        local label=entry.bestVendor and (entry.vendorTie and "Tied for highest verified vendor value" or "Highest verified vendor value") or "Verified vendor value"
        if entry.sellChoice and not entry.vendorTie then label="Take for vendor value" end
        GameTooltip:AddLine(label.." · "..ns.Gold.Format(entry.vendor).." total",.9,.8,.55,true)
    else
        GameTooltip:AddLine("Vendor value unknown",.8,.8,.7,true)
    end
    return true
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(tooltip,data)
        if tooltip~=GameTooltip then return end
        local owner=R.TooltipOwner(tooltip)
        if owner then appendStatus(owner,ns.Safe(data and data.id)) end
    end)
end
if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipCleared",function(self) self.tkRewardStatus=nil end)
end
local function annotate(button,entry,quest)
    local overlay=annotations[button]
    if not overlay then
        overlay={};annotations[button]=overlay
        overlay.upgrade=button:CreateTexture(nil,"OVERLAY",nil,7);overlay.upgrade:SetSize(14,14)
        button:HookScript("OnEnter",function(self)
            local _,link=R.Read(GameTooltip and GameTooltip.GetItem,GameTooltip)
            local id=type(link)=="string" and tonumber(link:match("item:(%d+)"))
            if id and appendStatus(self,id) then GameTooltip:Show() end
        end)
        button:HookScript("OnHide",function()
            overlay.upgrade:Hide();overlay.entry=nil
        end)
    end
    overlay.entry=entry;overlay.quest=quest
    local icon=button.Icon or button.icon or button.IconTexture
    local anchor=(type(icon)=="table" or type(icon)=="userdata") and icon.GetObjectType and icon or button
    overlay.upgrade:ClearAllPoints()
    overlay.upgrade:SetPoint("TOPLEFT",anchor,"TOPLEFT",1,-1)
    if entry.upgrade then ns.ItemComparison.Badge(overlay.upgrade,"upgrade")
    elseif entry.bestVendor then ns.ItemComparison.Badge(overlay.upgrade,"vendor") end
end
local function context()
    return table.concat({ns.State.inventoryRevision or 0,ns.State.itemRevision or 0,ns.State.questRevision or 0,ns.Talents.revision or 0,ns.State.level or 0,R.settingsRevision or 0,R.auraRevision or 0},":")
end
local function shownQuest(log)
    local frame=QuestInfoFrame and QuestInfoFrame.rewardsFrame
    if not enabled() or not frame or not frame:IsVisible() then return end
    if type(InCombatLockdown)=="function" and InCombatLockdown() then return end
    if (ns.Safe(QuestInfoFrame.questLog)==true)~=log then return end
    if log then return ns.Safe(ns.API.Call("C_QuestLog","GetSelectedQuest")) end
    return ns.Safe(R.Read(GetQuestID))
end
local function bind(frame,quest,result)
    R.lastVolatile=false
    for _,entry in ipairs(result.rows) do
        if entry.advice and entry.advice.retry then R.lastVolatile=true end
        entry.vendorTie=entry.bestVendor and result.ties>1
    end
    for _,button in ipairs(frame.RewardButtons) do
        local rows=result.buttons[ns.Safe(button.type)]
        if rows and button:IsVisible() and ns.Safe(button.objectType)=="item" and ns.Safe(button.questID)==quest then
            local index=ns.Safe(button:GetID());local entry=type(index)=="number" and rows[index]
            local nativeID=ns.Safe(button.itemID)
            if entry and entry.id and (type(nativeID)~="number" or nativeID==entry.id) then annotate(button,entry,quest) end
        end
    end
end
function R.Refresh()
    clear()
    if not enabled() or not QuestInfoFrame then R.work=nil;return end
    if type(InCombatLockdown)=="function" and InCombatLockdown() then R.work=nil;return end
    local frame=QuestInfoFrame.rewardsFrame
    if not frame or not frame:IsShown() or type(frame.RewardButtons)~="table" then R.work=nil;return end
    local log=ns.Safe(QuestInfoFrame.questLog)==true;local quest=shownQuest(log)
    if type(quest)~="number" then R.work=nil;return end
    local rows,complete=R.Items(log,quest);local stamp=context()
    local keys={quest,tostring(log),stamp,tostring(complete)}
    for _,row in ipairs(rows) do keys[#keys+1]=table.concat({row.type,row.index,row.id or 0,row.link or "",row.quantity or 0,tostring(row.usable),(ns.API.itemVersions or {})[row.id] or 0},":") end
    local key=table.concat(keys,"|")
    if R.resultCache and R.resultCache.key==key then bind(frame,quest,R.resultCache.result);return end
    if R.work and R.work.key==key then return end
    local job={key=key};R.work=job
    job.iterator=coroutine.create(function() return R.Analyze(rows,complete,function(entry)
        if entry.advice and entry.advice.retry then job.volatile=true end
        if not entry.info or entry.advice and entry.advice.kind=="pending" then job.incomplete=true end
        coroutine.yield()
    end) end)
    local function step()
        if R.work~=job then return end
        if shownQuest(log)~=quest or QuestInfoFrame.rewardsFrame~=frame or not frame:IsShown() then R.work=nil;return end
        if context()~=stamp then R.work=nil;ns.After("questRewardAdvice",R.Refresh);return end
        local start=type(debugprofilestop)=="function" and debugprofilestop()
        for i=1,2 do
            local ok,result=coroutine.resume(job.iterator)
            if not ok then ns.errors.questRewardAdvice=tostring(result);R.work=nil;return end
            if coroutine.status(job.iterator)=="dead" then
                R.work=nil
                if not job.incomplete and not job.volatile and result.complete then R.resultCache={key=key,result=result} end
                bind(frame,quest,result);return
            end
            if start and debugprofilestop()-start>=.8 then break end
        end
        C_Timer.After(.02,step)
    end
    step()
end
local function refresh()
    local frame=QuestInfoFrame and QuestInfoFrame.rewardsFrame
    if enabled() and frame and frame:IsVisible() then ns.After("questRewardAdvice",R.Refresh) end
end
local function install()
    if type(hooksecurefunc)~="function" then return end
    for _,name in ipairs({"QuestInfo_ShowRewards","QuestInfo_Display"}) do
        if not hooked[name] and type(_G[name])=="function" then
            hooksecurefunc(name,refresh);hooked[name]=true
        end
    end
    for _,name in ipairs({"QuestInfoRewardsFrame","MapQuestInfoRewardsFrame"}) do
        local frame=_G[name]
        if frame and not hooked[name] then
            frame:HookScript("OnShow",refresh)
            hooked[name]=true
        end
    end
end
ns.On("ADDON_LOADED",function() install() end)
for _,event in ipairs({"QUEST_DETAIL","QUEST_COMPLETE","QUEST_LOG_UPDATE","ITEM_DATA_LOAD_RESULT","PLAYER_REGEN_ENABLED"}) do ns.On(event,refresh) end
ns.On("QUEST_FINISHED",function() clear();R.work=nil;R.resultCache=nil;R.lastVolatile=false end)
ns.On("PLAYER_REGEN_DISABLED",function() clear();R.work=nil;R.resultCache=nil end)
ns.Listen("SETTINGS_CHANGED",function() R.settingsRevision=(R.settingsRevision or 0)+1;refresh() end)
ns.Listen("ITEM_DATA_READY",refresh)
ns.Listen("STATE_CHANGED",function(kind) if ns.Changed(kind,"inventory","identity","talents","quests") then refresh() end end)
install()

ns.On("UNIT_AURA",function(unit)
    if ns.Safe(unit)~="player" or not (R.lastVolatile or R.work and R.work.volatile) then return end
    local frame=QuestInfoFrame and QuestInfoFrame.rewardsFrame
    if not enabled() or not frame or not frame:IsVisible() then return end
    if type(InCombatLockdown)=="function" and InCombatLockdown() then return end
    R.auraRevision=(R.auraRevision or 0)+1;refresh()
end)
