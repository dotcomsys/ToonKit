local addonName, ns = ...
local U,G,M=ns.UI,ns.Gear,ns.Main
-- One reusable toast; rapid multi-item acquisitions queue without allocating frames.
local queue={}
local function showNext()
    if #queue==0 then return end
    local id=table.remove(queue,1);local info=ns.API.Item(id)
    if not G.toast then
        local f=CreateFrame("Button",nil,UIParent,"BackdropTemplate");G.toast=f
        f:SetPoint("TOP",0,-230);f:SetSize(340,76);f:SetFrameStrata("HIGH");f:EnableMouse(true)
        f.icon=f:CreateTexture(nil,"ARTWORK");f.icon:SetPoint("LEFT",12,0);f.icon:SetSize(42,42)
        f.label=U.Label(f,"",64,-12,260,"GameFontNormal");f.item=U.Label(f,"",64,-34,260,"GameFontHighlight")
        f:SetScript("OnClick",function(self)
            M.farmingSelection=self.itemID;M.tab="Character";M.sub="Farming";U.main:Show();M.Render();self:Hide()
        end)
    end
    local f=G.toast;f.itemID=id;f.serial=(f.serial or 0)+1;local serial=f.serial
    U.Skin(f);f.icon:SetTexture(info and info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    f.label:SetText("Gear hunt complete");f.item:SetText(info and info.link or "Item #"..id);f:Show()
    C_Timer.After(5,function() if f.serial==serial then f:Hide();showNext() end end)
end
ns.Listen("GEAR_HUNT_OBTAINED",function(id)
    if not ns.db.settings.notifications then return end
    queue[#queue+1]=id;if not G.toast or not G.toast:IsShown() then showNext() end
end)
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(tooltip,data)
        if tooltip~=GameTooltip or not ns.char or not ns.db.settings.modules.gear or ns.db.settings.gearItemAdvice==false then return end
        if ns.QuestRewards.TooltipOwner(tooltip) then return end
        local id=ns.Safe(data and data.id);if type(id)~="number" or tooltip.tkHuntRank==id then return end
        tooltip.tkHuntRank=id
        for _,rank in ipairs(G.huntRanks and G.huntRanks[id] or {}) do
            local name="Slot";for _,slot in ipairs(ns.Data.slots) do if slot[1]==rank.slot then name=slot[2] end end
            tooltip:AddLine(name..": catalog rank #"..rank.rank.." / "..rank.total..(rank.delta and string.format("  (%+.1f stats)",rank.delta) or ""),.86,.77,.5,true)
        end
        local tracked=ns.char.farming[id]
        if tracked then tooltip:AddLine(tracked.obtained and "Gear hunt completed" or "Tracked gear hunt",.5,.9,.5,true) end
    end)
end
if GameTooltip and GameTooltip.HookScript then GameTooltip:HookScript("OnTooltipCleared",function(self) self.tkHuntRank=nil end) end

ns.Listen("ITEM_DATA_READY",function()
    if not ns.API.CatalogVisible() then return end
    if M.Editing() then M.pendingRefresh=true else ns.After("catalogRender",M.Render) end
end)

-- Fast access uses the same catalog, eligibility, targets and hunt lifecycle as
-- Equipment. It never owns native equipment clicks or equips an item.
function M.QuickGear()
    M.Heading("Quick upgrades")
    local slots={};local slot=M.quickGearSlot or 16
    for _,record in ipairs(ns.Data.slots) do slots[#slots+1]={value=record[1],label=record[2]} end
    local choose=U.Cycle(M.body,slots,slot,M.width-16,function(value) M.quickGearSlot=value;M.Render() end,"Equipment slot: ")
    choose:SetPoint("TOPLEFT",8,M.y);M.y=M.y-choose:GetHeight()-10
    local profile=G.HuntProfile("auto","auto",ns.State.level)
    local data=G.CapTargets(ns.State.level,profile);local list=data[slot] or {ranked={},references={}}
    G.RefreshHuntRanks(profile)
    M.Line((profile.name or "Live talents").." | "..(profile.role or "unknown").." | Level "..ns.State.level,"GameFontNormal")
    M.Line("Estimated improvements over what you are wearing now. Items already in your bags come first. Compare the details before changing equipment.","GameFontHighlightSmall")
    local upgrades={}
    for _,item in ipairs(list.ranked) do
        if G.IsCurrentUpgrade(item,slot) and not (ns.Journey.Speedrunning() and item.dungeon) then upgrades[#upgrades+1]=item end
    end
    table.sort(upgrades,function(a,b)
        local ao,bo=(ns.State.owned[a.id] or 0)>0,(ns.State.owned[b.id] or 0)>0
        if ao~=bo then return ao end
        if a.capComparison.delta~=b.capComparison.delta then return a.capComparison.delta>b.capComparison.delta end
        return a.id<b.id
    end)
    local shown=0
    for index=1,math.min(3,#upgrades) do
        local record=upgrades[index];local item=record
        local owned=(ns.State.owned[item.id] or 0)>0
        local width=M.width-16;local top=M.y
        local card=U.Panel(M.body,width,100,8,top,"quickUpgrade")
        U.Item(card,item.id,12,-12,36,item.link)
        local title=U.Label(card,"#"..index.." "..(item.info.name or "Item #"..item.id)..(item.capEquipped and " (equipped)" or owned and " (owned)" or ""),60,-12,width-76,"GameFontNormal")
        local y=20+title:GetStringHeight()
        local detail=U.Label(card,G.DataEvidence(item).."\n"..(item.source or "Recorded source")..(item.capComparison and string.format(" | Estimated improvement: %+.1f points",item.capComparison.delta) or "")..
            (item.capIncomplete and " | Partial effect coverage" or ""),60,-y,width-76,"GameFontHighlightSmall")
        y=y+detail:GetStringHeight()+12
        local bw=math.floor((width-40)/3)
        local details=U.Button(card,"Details / sources",bw,function() M.OpenGearCandidate(slot,item.id) end);details:SetPoint("TOPLEFT",12,-y)
        local compare=U.Button(card,"Compare",bw,function() ns.ItemCompare.Show(item,slot) end);compare:SetPoint("TOPLEFT",20+bw,-y)
        local tracked=ns.char.farming[item.id]
        local follow=U.Button(card,owned and "Already owned" or tracked and "Follow hunt" or "Track & guide",bw,function()
            local ok=true
            if not ns.char.farming[item.id] then ok=G.PlanReference(item) end
            if ok and G.FollowHunt(item.id) then ns.SetSetting("guide",true);M.OpenPage("Journey")
            else ns.Message("This source cannot be followed yet. Open Details to review eligibility and requirements.") end
        end);follow:SetPoint("TOPLEFT",28+bw*2,-y);follow:SetEnabled(not owned)
        local height=y+math.max(details:GetHeight(),compare:GetHeight(),follow:GetHeight())+12
        card:SetHeight(height);M.y=top-height-8;shown=shown+1
    end
    if shown==0 then
        M.Line(G.RoleKnown(profile) and "No clear upgrade is available in the loaded data for this slot. Keep your current item; Browse shows other options and items still waiting for data." or "Choose your role before using upgrade advice.")
        if not G.RoleKnown(profile) then M.Action("Choose character role",function() M.settingsPage="Character";M.OpenPage("Settings") end,240) end
    end
    M.Action("Browse every candidate and source",function() M.OpenGearCandidate(slot) end,300)
    M.Action("Tracked hunts",function() M.farmingDungeon=nil;M.farmingQuery="";M.OpenPage("Farming") end,200)
end

-- Equipment uses the native character sheet; no extra character-window button.
