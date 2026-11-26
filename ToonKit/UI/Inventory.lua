local addonName, ns = ...

local U=ns.UI

local B={width=460,height=360,buttons={},headers={},proxies={},originals={},query="",filter="All"}; ns.Inventory=B

local I=ns.InventoryRules

function B.Category(item) return I.Category(item) end
function B.ViewData()
    if B.offlineKey then local view=I.Recorded(B.offlineKey);if view then return view end;B.offlineKey=nil end
    return ns.State
end
function B.HasCategory(id,categories)
    for _,g in ipairs(categories) do if g.id==id then return true end end;return false
end
function B.CategoryName(id)
    for _,g in ipairs(B.view and B.view.groups or I.Groups()) do if g.id==id then return g.name end end
    return I.Name(id)
end
function B.SelectCharacter(key)
    B.offlineKey=key~="current" and key or nil;B.bagFilter=nil;B.filter="All";B.assignMode=false;B.inlineAssignment=nil
    B.characterOpen=false;B.query="";B.search:SetText("");B.Render()
end
function B.AnnotateCell(cell,item,size)
    cell.tkLevel=cell.tkLevel or U.Label(cell,"",2,0,size-4,"GameFontNormalSmall")
    cell.tkLevel:ClearAllPoints();cell.tkLevel:SetPoint("BOTTOMLEFT",2,2);cell.tkLevel:SetWidth(size-4)
    local info=item.info;local equipment=info and ns.Data.equipSlots[info.equip]
    local level=item.itemLevel
    cell.tkLevel:SetText(type(level)=="number" and level>0 and tostring(level) or "")
    cell.tkLevel:SetShown(item.id~=nil and equipment~=nil and type(level)=="number" and level>0 and ns.db.settings.bagItemLevel~=false)
    cell.tkBinding=cell.tkBinding or U.Label(cell,"BoE",2,-2,size-4,"GameFontNormalSmall")
    cell.tkBinding:SetWidth(size-4)
    local onEquip=Enum and Enum.ItemBind and Enum.ItemBind.OnEquip
    local new=not item.recorded and ns.db.settings.bagNewMarkers and I.IsNew(item)
    local badgeFits=not cell.tkAdvice or not cell.tkAdvice:IsShown() or size>=40
    cell.tkBinding:SetShown(item.id~=nil and ns.db.settings.bagBindingLabels~=false and not new and badgeFits and onEquip~=nil and info~=nil and info.bind==onEquip and item.boundKnown==true and item.bound==false)
end
function B.PaintRecorded(item,size,x,y)
    B.recordedButtons=B.recordedButtons or {};local key=item.bag..":"..item.slot;local cell=B.recordedButtons[key]
    if not cell then
        cell=CreateFrame("Button",nil,B.content,"BackdropTemplate");B.recordedButtons[key]=cell
        cell:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8})
        cell.icon=cell:CreateTexture(nil,"ARTWORK");cell.icon:SetPoint("TOPLEFT",2,-2);cell.icon:SetPoint("BOTTOMRIGHT",-2,2)
        cell.count=U.Label(cell,"",2,-2,30,"NumberFontNormal");cell.count:ClearAllPoints();cell.count:SetPoint("BOTTOMRIGHT",-3,3);cell.count:SetJustifyH("RIGHT")
        cell:SetScript("OnClick",function(self) if self.item and self.item.link and HandleModifiedItemClick then HandleModifiedItemClick(self.item.link) end end)
    end
    cell.item=item;cell:SetSize(size,size);cell:ClearAllPoints();cell:SetPoint("TOPLEFT",x,y)
    cell.icon:SetTexture(item.icon or item.info and item.info.icon);cell.count:SetText(item.count and item.count>1 and item.count or "")
    cell:SetBackdropColor(.06,.045,.025,1);cell:SetBackdropBorderColor(.4,.34,.2,1)
    cell:SetAlpha(I.Search(item,B.query,B.Category(item)) and 1 or .22)
    U.Tooltip(cell,item.info and item.info.name or "Recorded slot",{"Recorded inventory. Item movement and use require logging into this character."},item.link)
    B.AnnotateCell(cell,item,size);if ns.BagIntegrations then ns.BagIntegrations.Paint(cell,item,size) end;cell:Show()
end

function B.IsPlayerBag(id)

    if type(id)~="number" then return false end

    for _,bag in ipairs(ns.API.Bags()) do if id==bag then return true end end

    return false

end

function B.Enabled() return ns.char and ns.db.settings.inventory and not B.nativeSession and B.supported end
function B.IsNativePlayerFrame(frame)
    if frame==ContainerFrameCombinedBags then return true end
    local id=frame.GetBagID and ns.Safe(frame:GetBagID())
    if type(id)~="number" then id=ns.Safe(frame:GetID()) end
    return B.IsPlayerBag(id)
end
local maskedNativeBags={}
local function unmaskNativeBag(frame)
    local alpha=maskedNativeBags[frame]
    if alpha==nil then return end
    maskedNativeBags[frame]=nil
    frame:SetAlpha(alpha)
end
local function maskNativeBag(frame)
    if maskedNativeBags[frame]~=nil or InCombatLockdown() or not B.Enabled() or not B.IsNativePlayerFrame(frame) then return end
    local alpha=ns.Safe(frame:GetAlpha())
    if type(alpha)=="number" then maskedNativeBags[frame]=alpha;frame:SetAlpha(0) end
end

function B.AnyNativePlayerBagShown()

    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then return true end

    for i=1,(NUM_CONTAINER_FRAMES or 20) do

        local frame=_G["ContainerFrame"..i]

        if frame and frame:IsShown() then

            if B.IsNativePlayerFrame(frame) then return true end

        end

    end

    return false

end

function B.SuppressNative()

    if not B.Enabled() or InCombatLockdown() then return end

    local frames={}

    if ContainerFrameCombinedBags then frames[#frames+1]=ContainerFrameCombinedBags end

    for i=1,(NUM_CONTAINER_FRAMES or 20) do if _G["ContainerFrame"..i] then frames[#frames+1]=_G["ContainerFrame"..i] end end

    for _,frame in ipairs(frames) do

        if frame:IsShown() and B.IsNativePlayerFrame(frame) then frame:Hide() end

    end

end

function B.Show()

    if InCombatLockdown() then ns.OutOfCombat("bags",B.Show); return end

    if ns.db and not ns.db.settings.inventory then

        B.OpenNative();return

    end

    B.nativeSession=false;B.offlineKey=nil

    if not B.frame then B.Create() end

    if not B.Enabled() then ns.Message("Inventory unavailable. Use /tk refresh, or open Blizzard bags."); return end

    ns.OutOfCombat("bags",function()

        local ok,err=pcall(ns.State.Refresh,"inventory")

        if ok then ns.errors.inventoryRefresh=nil else ns.errors.inventoryRefresh=tostring(err) end

        B.SuppressNative();B.frame:Show()

    end)

end

function B.Hide()
    B.assignMode=false
    ns.OutOfCombat("bags",function() if B.frame then B.frame:Hide() end end)
end

function B.Toggle() if B.frame and B.frame:IsShown() then B.Hide() else B.Show() end end

function B.Button(item)

    local key=item.bag..":"..item.slot; local b=B.buttons[key]

    if b and b.tkReady then return b end

    local proxy=B.proxies[item.bag]

    if not proxy then

        proxy=CreateFrame("Frame",nil,B.content); proxy:SetID(item.bag); proxy:SetAllPoints(B.content)
        proxy:EnableMouse(false)

        proxy.IsCombinedBagContainer=function() return true end

        proxy.GetBagID=function(self) return self:GetID() end

        B.proxies[item.bag]=proxy

    end

    -- Use Blizzard's actual item button, preserving tooltip, modified clicks,

    -- stack splitting, cursor interaction and contextual merchant/mail/trade handling.

    if not b then b=CreateFrame("ItemButton",nil,proxy,"ContainerFrameItemButtonTemplate");B.buttons[key]=b end

    -- Each button stays with one bag parent and one live slot. The native
    -- GetBagID already falls back to that parent's ID.
    b:SetID(item.slot)
    b:EnableMouse(true)

    -- Leave the native XML OnClick, drag and modified-click handlers untouched.

    -- Calling a saved native click function from addon Lua taints protected use.

    b:HookScript("OnEnter",function(self)

        local item=self.item

        if item and item.id and ns.QuestSupplies and GameTooltip:IsShown() then

            ns.QuestSupplies.AppendTooltip(GameTooltip,item.id)

        end

        if item and item.id and GameTooltip:IsShown() then

            local sellable,reason=I.SellableGear(item)

            if sellable then
                local value=item.info.sellPrice*(item.count or 1)
                GameTooltip:AddLine("Verified vendor value · "..ns.Gold.Format(value).." total",.85,.75,.45,true)
                GameTooltip:AddLine(reason,.85,.8,.7,true)
            end

            if ns.ItemComparison then ns.ItemComparison.Append(GameTooltip,item.id,item.link) end
            if ns.GearRequirements then ns.GearRequirements.AppendReagentUses(GameTooltip,item) end
            I.AppendOwnershipTooltip(GameTooltip,item.id)

            GameTooltip:Show()

        end

        -- Native item hover/Shift comparison owns equipment advice.

    end)

    b.tkReady=true; return b

end

function B.GroupItem(item)

    if item and item.id then ns.InventoryOrganizer.Assign(item) end

end

function B.Paint(item,size,px,py)

    local b=B.Button(item); b.item=item

    -- The native XML fixes frameLevel=10. A raised opaque window can

    -- cover that level; explicitly place cells above their live parent.

    local proxy=b:GetParent();proxy:SetFrameLevel(B.content:GetFrameLevel()+1)

    b:SetFrameLevel(proxy:GetFrameLevel()+1)

    proxy:SetFrameStrata(B.frame:GetFrameStrata());b:SetFrameStrata(B.frame:GetFrameStrata())

    b:SetSize(size,size); b:ClearAllPoints()

    b:SetPoint("TOPLEFT",B.content,"TOPLEFT",px,py)

    local occupied=item.id~=nil or item.link~=nil
    local texture=occupied and (item.icon or (item.info and item.info.icon) or 134400) or nil

    -- Own presentation layer: native cells still own all interactions.

    b.tkIcon=b.tkIcon or b:CreateTexture(nil,"ARTWORK",nil,1);b.tkIcon:SetPoint("TOPLEFT",2,-2);b.tkIcon:SetPoint("BOTTOMRIGHT",-2,2)

    b.tkIcon:SetTexture(texture);b.tkIcon:SetShown(texture~=nil);b.tkIcon:SetDesaturated(item.locked or false)

    if b.SetHasItem then b:SetHasItem(texture) end

    if b.SetReadable then b:SetReadable(item.readable or false) end

    b:Show()
    ns.Invoke("bagCellDecorations",B.Decorate,b,item,size,texture)
    ns.Invoke("bagCellAssignment",B.PaintAssignment,b,item,size,px,py)
end

function B.Decorate(b,item,size,texture)
    if b.SetItemButtonTexture then b:SetItemButtonTexture(texture) elseif SetItemButtonTexture then SetItemButtonTexture(b,texture) end
    if b.SetItemButtonCount then b:SetItemButtonCount(item.count or 0) elseif SetItemButtonCount then SetItemButtonCount(b,item.count or 0) end
    local quality=texture and ns.db.settings.bagQuality and item.quality or nil
    if b.SetItemButtonQuality then b:SetItemButtonQuality(quality,item.link) elseif SetItemButtonQuality then SetItemButtonQuality(b,quality,item.link) end
    if SetItemButtonDesaturated then SetItemButtonDesaturated(b,item.locked or false) end
    if b.UpdateQuestItem and b.IconQuestTexture then
        local quest=item.quest
        b:UpdateQuestItem(quest and ns.Safe(quest.isQuestItem,false),quest and ns.Safe(quest.questID),quest and ns.Safe(quest.isActive,false))
    end
    if b.UpdateCooldown then b:UpdateCooldown(texture) end
    local match=I.Search(item,B.query,B.Category(item))

    b:SetAlpha(match and 1 or .22)

    -- The template's store highlight is visible by default unless its owner

    -- updates it. Our custom renderer owns presentation, including empty slots.

    for _,key in ipairs({"flashAnim","newitemglowAnim"}) do local animation=b[key];if animation and animation.Stop then animation:Stop() end end

    for _,key in ipairs({"BattlepayItemTexture","NewItemTexture","BagIndicator","flash","searchGlow"}) do local region=b[key];if region then region:Hide() end end

    if b.SetMatchesSearch then b:SetMatchesSearch(match) end

    b.tkNew=b.tkNew or U.Label(b,"",2,-2,size-4,"GameFontNormalSmall")

    b.tkNew:SetText("New");b.tkNew:SetShown(item.id~=nil and ns.db.settings.bagNewMarkers and I.IsNew(item) and true or false)
    b.tkAdvice=b.tkAdvice or b:CreateTexture(nil,"OVERLAY",nil,7)
    b.tkAdvice:SetSize(18,18);b.tkAdvice:ClearAllPoints();b.tkAdvice:SetPoint("TOPRIGHT",-1,-1)
    local advice=item.id and ns.db.settings.gearItemAdvice~=false and ns.Gear.ItemAdvice(item.id,item.link,item)
    b.tkAdviceKind=advice and advice.kind
    b.tkAdvice:SetVertexColor(1,1,1);b.tkAdvice:SetTexCoord(0,1,0,1)
    b.tkAdvice:SetShown(type(advice)=="table")
    if advice then b.tkAdvice:SetTexture(advice.icon) end
    B.AnnotateCell(b,item,size)
    if ns.BagIntegrations then ns.BagIntegrations.Paint(b,item,size) end
    if B.adviceQueue and item.link and item.info and ns.Data.equipSlots[item.info.equip] and not b.tkAdviceKind
        and not (b.tkExternalUpgrade and b.tkExternalUpgrade:IsShown()) then
        B.adviceQueue[#B.adviceQueue+1]={button=b,item=item}
    end

end

function B.PaintAssignment(b,item,size,px,py)
    B.assignButtons=B.assignButtons or {}

    local key=item.bag..":"..item.slot;local assign=B.assignButtons[key]

    if B.assignMode and item.id and not I.IsReagentBag(item) and not assign then

        assign=CreateFrame("Button",nil,B.content,"BackdropTemplate");B.assignButtons[key]=assign

        assign:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8});assign:SetBackdropColor(.45,.28,.06,.5)

        assign:SetScript("OnClick",function(self) B.GroupItem(self.item) end)

        U.Tooltip(assign,"Assign category",{"Category editing mode. Choose Done assigning to restore normal item interaction."})

    end

    if assign then

        assign.item=item;assign:SetSize(size,size);assign:ClearAllPoints();assign:SetPoint("TOPLEFT",B.content,"TOPLEFT",px,py)

        assign:SetFrameStrata(B.frame:GetFrameStrata());assign:SetFrameLevel(b:GetFrameLevel()+2);assign:SetShown(B.assignMode and item.id~=nil and not I.IsReagentBag(item))

    end

end

function B.FailedCell(item,size,x,y,reason)

    B.fallbacks=B.fallbacks or {};local key=item.bag..":"..item.slot;local cell=B.fallbacks[key]

    if not cell then

        cell=CreateFrame("Button",nil,B.content);cell.icon=cell:CreateTexture(nil,"ARTWORK");cell.icon:SetAllPoints();cell.count=U.Label(cell,"",2,-2,50,"GameFontHighlightSmall")

        cell:SetScript("OnClick",B.OpenNative);B.fallbacks[key]=cell

    end

    cell:ClearAllPoints();cell:SetPoint("TOPLEFT",x,y);cell:SetSize(size,size);cell:SetFrameLevel(B.content:GetFrameLevel()+3)

    local occupied=item.id~=nil or item.link~=nil
    if occupied then cell.icon:SetTexture(item.icon or item.info and item.info.icon or 134400)
    else cell.icon:SetAtlas("bags-item-slot64") end
    cell.count:SetText(occupied and item.count and item.count>1 and tostring(item.count) or "")

    local name=item.info and item.info.name or item.name or item.id and ("Item #"..item.id) or ("Bag "..item.bag..", slot "..item.slot)
    U.Tooltip(cell,name,{"Click to open the native bags and interact with this slot.",reason:sub(1,180)},item.link)

    cell:Show()

end

function B.DrawBagBar()

    B.bagButtons=B.bagButtons or {}

    for i,bag in ipairs(ns.API.Bags()) do

        local button=B.bagButtons[i]

        if not button then

            button=CreateFrame("Button",nil,B.frame,"BackdropTemplate");button:SetSize(28,28)

            button:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10});button:SetBackdropColor(.035,.035,.025,1)

            button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetPoint("TOPLEFT",3,-3);button.icon:SetPoint("BOTTOMRIGHT",-3,3)

            button.free=U.Label(button,"",3,-14,24,"GameFontHighlightSmall");B.bagButtons[i]=button

            button:RegisterForClicks("LeftButtonUp","RightButtonUp")

            button:SetScript("OnClick",function(self,key) if key=="RightButton" then ns.InventoryOrganizer.BagPreferences(self.bag) else B.bagFilter=B.bagFilter~=self.bag and self.bag or nil;B.Render() end end)

        end

        button.bag=bag;button:ClearAllPoints();button:SetPoint("BOTTOMLEFT",12+(i-1)*30,36)

        local icon

        if bag>0 then local slot=ns.Safe(ns.API.Call("C_Container","ContainerIDToInventoryID",bag));if slot then local _,_,texture=ns.API.Equipped(slot);icon=texture end end

        button.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_Bag_08");button.free:SetText(tostring((ns.State.bagFree or {})[bag] or 0))

        button:SetBackdropBorderColor(B.bagFilter==bag and 1 or .45,B.bagFilter==bag and .85 or .4,.18,1)

        button:SetShown(not B.offlineKey and not B.characterOpen and (bag==0 or ((ns.State.bagSlots or {})[bag] or 0)>0))

        U.Tooltip(button,bag==0 and "Backpack" or "Bag "..bag,{"Click to filter. Right-click to choose what this bag holds.",tostring((ns.State.bagFree or {})[bag] or 0).." free / "..tostring((ns.State.bagSlots or {})[bag] or 0).." slots"})

    end

end

function B.Draw()

    if not B.frame or not B.frame:IsShown() or not B.Enabled() then return end

    if InCombatLockdown() then ns.deferred.bagRender=B.Render; return end

    local view=B.ViewData();B.view=view
    local capacity=view.capacity or 0

    if capacity~=B.layoutCapacity then

        B.layoutCapacity=capacity

        B.width=ns.db.settings.bagWidth;B.height=ns.db.settings.bagHeight

    end

    B.frame:SetSize(B.width,B.height)

    -- ToonKit materials on the shared category-column layout.

    U.Skin(B.frame)
    local theme=U.themes[ns.db.settings.theme] or U.themes.forever
    B.frame.header:SetColorTexture(theme[1]*1.5,theme[2]*1.5,theme[3]*1.5,1)
    B.frame.divider:SetColorTexture(.45,.34,.16,1)

    local characterLabel=view.name..(type(view.level)=="number" and " · Level "..view.level or "")
    if view.offline then
        local when=view.recorded and view.recorded>0 and type(date)=="function" and date("%Y-%m-%d %H:%M",view.recorded) or "unknown time"
        U.Tooltip(B.character,characterLabel,{"Recorded bags · "..when,"Read-only. Select your live character to move or use items."})
    else U.Tooltip(B.character,characterLabel,{"Browse character bags."}) end

    B.frame.title:SetText(B.assignMode and "Assign categories" or "Inventory")

    B.doneAssign:Hide()

    B.drawn=0;B.cellErrors=0

    for _,cell in pairs(B.fallbacks or {}) do cell:Hide() end

    local spacing=ns.db.settings.bagSpacing

    local size=ns.db.settings.bagIconSize or 36

    B.scroll:SetFrameLevel(B.frame:GetFrameLevel()+1);B.content:SetFrameLevel(B.scroll:GetFrameLevel()+1)

    local columns=math.max(4,math.min(ns.db.settings.bagColumns,math.floor((B.frame:GetWidth()-48)/(size+spacing))))

    local step=size+spacing

    B.content:SetWidth(columns*step+6)

    U.Fit(B.frame)

    B.frame.title:SetText(B.assignMode and "Assign categories - click an item" or view.name..(view.offline and " - Recorded bags" or " - Bags"));B.frame.title:SetWidth(B.frame:GetWidth()-190);B.frame.title:ClearAllPoints();B.frame.title:SetPoint("TOPLEFT",42,-10);B.frame.title:SetTextColor(.94,.82,.57,1)

    B.search:SetWidth(math.max(100,B.frame:GetWidth()-48));B.space:SetWidth(B.frame:GetWidth()-40)

    if B.assignMode then B.space:SetWidth(B.frame:GetWidth()-155) end

    B.space:SetText(view.free.." free / "..view.capacity.." slots  |  "..ns.API.Money())

    for category,button in pairs(B.filterButtons or {}) do button.icon:SetDesaturated(B.filter~="All" and B.filter~=category);button:SetAlpha(B.filter==category and 1 or .8) end

    for _,b in pairs(B.buttons) do b:Hide() end
    for _,cell in pairs(B.recordedButtons or {}) do cell:Hide() end

    for _,b in pairs(B.assignButtons or {}) do b:Hide() end

    for _,h in ipairs(B.headers) do h:Hide() end

    local categories=view.groups or I.Groups()
    B.categoryCounts={}
    for _,item in ipairs(view.bags) do
        if (B.bagFilter==nil or B.bagFilter==item.bag) and item.id then
            local id=B.Category(item)
            if I.Search(item,B.query,id) then B.categoryCounts[id]=(B.categoryCounts[id] or 0)+1 end
        end
    end

    local groups={};for _,category in ipairs(categories) do groups[category.id]={} end

    if B.filter~="All" and not B.HasCategory(B.filter,categories) then B.filter="All" end

    local emptyAdded={};B.visibleFree=0;B.reagentFree=0;B.reagentUsed=0
    B.assignMode=not view.offline and B.assignMode or false

    for _,item in ipairs(view.bags) do if B.bagFilter==nil or B.bagFilter==item.bag then
        if I.IsReagentBag(item) then
            if item.id then B.reagentUsed=B.reagentUsed+1 else B.reagentFree=B.reagentFree+1 end
        elseif not item.id then B.visibleFree=B.visibleFree+1 end
    end end

    for _,item in ipairs(view.bags) do

        local emptyGroup=I.IsReagentBag(item) and "Reagent bag" or "Empty"
        local compactEmpty=not item.id and not ns.db.settings.showEmpty and not emptyAdded[emptyGroup] and (B.query=="" or ns.db.settings.bagSearchMode=="dim")

        if (item.id or ns.db.settings.showEmpty or compactEmpty) and (B.bagFilter==nil or B.bagFilter==item.bag) then

            local category=B.Category(item)

            local name=item.info and item.info.name or ""

            local match=I.Search(item,B.query,category)

            if (match or ns.db.settings.bagSearchMode=="dim") and (B.filter=="All" or B.filter==category) then

                local group=(ns.db.settings.bagGrouped or category=="Reagent bag") and category or "Miscellaneous"

                if not groups[group] then group="Miscellaneous" end

                groups[group][#groups[group]+1]=item

                if not item.id then emptyAdded[emptyGroup]=true end

            end

        end

    end

    for _,group in ipairs(categories) do

        local category=group.id;local items=groups[category]

            local sort=ns.db.settings.bagGroupSort[category] or ns.db.settings.bagSort

            table.sort(items,function(a,b)

                if sort=="new" and I.IsNew(a)~=I.IsNew(b) then return I.IsNew(a) end

                if sort=="level" and (a.itemLevel or 0)~=(b.itemLevel or 0) then return (a.itemLevel or 0)>(b.itemLevel or 0) end

                if sort=="value" and (a.info and a.info.sellPrice or 0)~=(b.info and b.info.sellPrice or 0) then return (a.info and a.info.sellPrice or 0)>(b.info and b.info.sellPrice or 0) end

                if sort=="quality" and (a.quality or 0)~=(b.quality or 0) then return (a.quality or 0)>(b.quality or 0) end

                if sort~="bag" then

                    local an=a.info and a.info.name or ""; local bn=b.info and b.info.name or ""

                    if an~=bn then return an<bn end

                end

                if a.bag~=b.bag then return a.bag<b.bag end; return a.slot<b.slot

            end)

    end

    B.measure=B.measure or U.Label(B.frame,"",0,0,800,"GameFontNormal");B.measure:Hide()

    local function title(category,count,continued,collapsed)
        if category=="Reagent bag" then return (collapsed and "+ " or "").."Reagent bag ("..B.reagentUsed.." used, "..B.reagentFree.." free)" end

        return (ns.db.settings.bagGrouped and (collapsed and "+ " or "")..B.CategoryName(category) or "Your bags")..(ns.db.settings.bagCategoryCounts~=false and " ("..(category=="Empty" and B.visibleFree or count)..")" or "")..(continued and " - continued" or "")

    end

    local currencies=not view.offline and ns.API.BackpackCurrencies() or {}

    B.currencyButtons=B.currencyButtons or {}

    for _,button in ipairs(B.currencyButtons) do button:Hide() end

    local currencyWidth=#currencies>0 and math.floor(184/#currencies) or 0

    for index,currency in ipairs(currencies) do

        local button=B.currencyButtons[index]

        if not button then

            button=CreateFrame("Button",nil,B.frame)

            button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetSize(14,14);button.icon:SetPoint("LEFT",0,0)

            button.count=U.Label(button,"",17,-3,44,"GameFontHighlightSmall")

            B.currencyButtons[index]=button

        end

        button:SetSize(currencyWidth,20);button.count:SetWidth(currencyWidth-18)

        button:ClearAllPoints();button:SetPoint("BOTTOMLEFT",104+(index-1)*currencyWidth,10)

        button.icon:SetTexture(currency.icon or "Interface\\Icons\\INV_Misc_Coin_01")

        local count=currency.quantity>=1000000 and string.format("%.1fm",currency.quantity/1000000) or currency.quantity>=10000 and string.format("%.1fk",currency.quantity/1000) or tostring(currency.quantity)

        button.count:SetText(count);U.Tooltip(button,currency.name,{tostring(currency.quantity),"Selected with Show on Backpack in the native currency panel."});button:Show()

    end

    B.space:SetText(view.free.." / "..view.capacity.." free");B.space:SetWidth(86)

    B.money=B.money or U.Label(B.frame,"",0,0,150,"GameFontHighlightSmall")

    B.money:ClearAllPoints();B.money:SetPoint("BOTTOMRIGHT",-14,14);B.money:SetJustifyH("RIGHT");B.money:SetText(view.offline and view.money or ns.API.Money())

    local controls=B.QuickControls()
    B.DrawBagBar()
    local chrome=146+controls
    local available=B.height-chrome

    B.scroll:ClearAllPoints();B.scroll:SetPoint("TOPLEFT",14,-80-controls);B.scroll:SetPoint("BOTTOMRIGHT",-14,66)

    local order={};for _,category in ipairs(categories) do order[#order+1]=tostring(category.id) end
    local laneKey=(B.offlineKey or "current")..":"..tostring(ns.db.settings.bagCategoryColumns)..":"..tostring(ns.db.settings.bagGrouped)..":"..table.concat(order,",")
    if B.laneKey~=laneKey then B.laneKey=laneKey;B.laneAssignments={} end
    local measurements={}
    local options={assignments=B.laneAssignments,width=B.width-32,height=available,step=step,preferredColumns=ns.db.settings.bagColumns,grouped=ns.db.settings.bagGrouped,packed=ns.db.settings.bagPacked,stable=ns.db.settings.bagStableLayout,lanes=ns.db.settings.bagCategoryColumns,

        title=title,measure=function(text,width)
            local key=width..":"..text
            if not measurements[key] then
                B.measure:SetWidth(width);B.measure:SetWordWrap(true);B.measure:SetText(text)
                measurements[key]=math.max(19,math.ceil(B.measure:GetStringHeight())+4)
            end
            return measurements[key]
        end,

        visible=function(category) return category=="Reagent bag" or not ns.db.settings.bagHiddenGroups[category] or B.showHidden or B.filter==category or B.query~="" and ns.db.settings.bagSearchMode~="dim" end,

        collapsed=function(category) return (B.query=="" or ns.db.settings.bagSearchMode=="dim") and ns.db.settings.bagGrouped and ns.db.settings.bagCollapsed[category] end}

    local layout=ns.InventoryLayout.Single(groups,categories,options)
    local scale=U.PreferredScale(B.frame)
    local maxWidth,maxHeight=(UIParent:GetWidth()-24)/scale,(UIParent:GetHeight()-24)/scale
    local function fit(candidate)
        return math.min(1,maxWidth/(candidate.width+32),maxHeight/(candidate.height+chrome))
    end
    if maxWidth>64 and maxHeight>chrome and fit(layout)<.999 then
        -- Try the current viewport before shrinking an overflowing bag window.
        -- Leave the player's stable-lane assignments available for larger views.
        options.width=maxWidth-32;options.height=maxHeight-chrome
        options.stable=false;options.packed=true;options.assignments=nil
        local packed=ns.InventoryLayout.Single(groups,categories,options)
        if fit(packed)>fit(layout)+.01 then layout=packed end
    end
    if maxWidth>=320 then B.width=math.min(B.width,maxWidth) end
    if maxHeight>=180 then B.height=math.min(B.height,maxHeight) end

    B.layout=layout;B.content:SetScale(1)
    if ns.db.settings.bagAutoHeight then
        local preferred=maxWidth>=320 and math.min(ns.db.settings.bagWidth,maxWidth) or ns.db.settings.bagWidth
        B.width=math.max(preferred,math.ceil(layout.width+32))
        B.height=math.max(180,math.ceil(layout.height+chrome));B.frame:SetSize(B.width,B.height)
    end

    B.width=math.max(B.width,math.ceil(layout.width+32));B.height=math.max(B.height,math.ceil(layout.height+chrome))
    B.frame:SetSize(B.width,B.height)

    B.content:SetSize(layout.width,layout.height);B.search:SetWidth(math.max(100,B.width-48));B.frame.title:SetWidth(B.width-190);U.Fit(B.frame)

    B.pageCount=1;B.pageNumber=1

    for index,entry in ipairs(layout.entries) do

        local h=B.headers[index]

        if not h then

            h=CreateFrame("Button",nil,B.content);h.text=U.Label(h,"",2,-2,300,"GameFontNormal")

            h.line=h:CreateTexture(nil,"BACKGROUND");h.line:SetColorTexture(.45,.34,.16,.7);h.line:SetPoint("BOTTOMLEFT",0,0);h.line:SetPoint("BOTTOMRIGHT",0,0);h.line:SetHeight(1)

            B.headers[index]=h

        end

        h.category=entry.category;h:SetFrameLevel(B.content:GetFrameLevel()+1);h:ClearAllPoints();h:SetPoint("TOPLEFT",entry.x+2,-entry.y);h:SetSize(entry.width,entry.heading)

        h.text:SetWidth(entry.width-6);h.text:SetHeight(entry.heading);h.text:SetWordWrap(true);h.text:SetText(entry.title);h.text:SetTextColor(1,.82,.33,1);h:Show()

        h:RegisterForClicks("LeftButtonUp","RightButtonUp")

        h:SetScript("OnClick",function(self,button)

            if button=="RightButton" and not B.offlineKey and self.category~="Reagent bag" then B.CategoryEditMenu(self.category,self)

            elseif ns.db.settings.bagGrouped then ns.db.settings.bagCollapsed[self.category]=not ns.db.settings.bagCollapsed[self.category];B.Render() end

        end)

        h:SetScript("OnReceiveDrag",function(self)

            if B.offlineKey or InCombatLockdown() or not GetCursorInfo then return end

            local kind,id=GetCursorInfo();kind,id=ns.Safe(kind),ns.Safe(id)

            if kind=="item" and type(id)=="number" and I.Exists(self.category) and self.category~="Empty" and self.category~="Reagent bag" then

                ns.char.itemGroups=ns.char.itemGroups or {};ns.char.itemGroups[id]=self.category

                if ClearCursor then ClearCursor() end;ns.Emit("STATE_CHANGED")

            end

        end)

        U.Tooltip(h,I.Name(entry.category),entry.category=="Reagent bag" and {"Items physically stored in your reagent bag. Use normal item dragging to move them; category rules do not move items."} or {"Drop an item here to assign its category. Click to collapse or expand. Right-click to customize."})

        if not entry.collapsed then for i=entry.first,entry.last do

            local item=entry.items[i];local offset=i-entry.first;local px=entry.x+(offset%entry.cells)*step;local py=-entry.y-entry.heading-3-math.floor(offset/entry.cells)*step

            local key=item.bag..":"..item.slot;local ok,err=pcall(view.offline and B.PaintRecorded or B.Paint,item,size,px,py)

            if ok then ns.errors["bagcell:"..key]=nil;B.drawn=B.drawn+1 else

                B.cellErrors=B.cellErrors+1;ns.errors["bagcell:"..key]=tostring(err);if B.buttons[key] then B.buttons[key]:Hide() end

                B.FailedCell(item,size,px,py,tostring(err))

            end

        end end

    end

    B.noMatches=#layout.entries==0

    if B.noMatches then

        B.recovery:SetText(view.capacity==0 and "Waiting for player bag data." or I.searchError or "No items match this view.");B.recovery:Show()

    end

    B.scroll:SetVerticalScroll(0)



end

local function paintGearBadges(queue)
    local index=1
    local function step()
        if B.adviceQueue~=queue or not B.frame:IsShown() or InCombatLockdown() then return end
        local started=debugprofilestop and debugprofilestop()
        for _=1,4 do
            local row=queue[index]
            if not row then return end
            index=index+1
            local button,item=row.button,row.item
            if button.item==item and button:IsShown() then
                local advice=ns.ItemComparison.Cached(item.id,item.link)
                if advice and advice.kind=="upgrade" then
                    ns.ItemComparison.Badge(button.tkAdvice,"upgrade")
                end
            end
            if started and debugprofilestop()-started>=1 then break end
        end
        if queue[index] then C_Timer.After(.02,function() ns.Invoke("bagGearBadges",step) end) end
    end
    if queue[1] then C_Timer.After(.02,function() ns.Invoke("bagGearBadges",step) end) end
end

function B.Render()

    if not B.frame or not B.frame:IsShown() then return end

    if InCombatLockdown() then ns.deferred.bagRender=B.Render;return end

    if B.rendering then ns.After("bagRedraw",B.Render);return end

    B.rendering=true
    B.adviceQueue=ns.ItemComparison and ns.db.settings.gearItemAdvice~=false and ns.db.settings.modules.gear~=false and {} or nil

    local ok,err=pcall(B.Draw)

    B.rendering=nil

    if ok then
        if B.adviceQueue then paintGearBadges(B.adviceQueue) end

        ns.errors.inventory=nil;B.recoveryAttempted=nil

        if B.recovery then

            local empty=(B.view and B.view.capacity or ns.State.capacity)==0

            B.recovery:SetWidth(B.frame:GetWidth()-36);B.recovery:SetShown(empty or B.noMatches);B.native:SetShown(empty or (B.cellErrors or 0)>0)

            if (B.cellErrors or 0)>0 then B.space:SetText(B.cellErrors.." unavailable slots | "..ns.State.free.." free");B.space:SetWidth(B.frame:GetWidth()-165) end

            if empty or (B.cellErrors or 0)>0 then B.doneAssign:Hide() end

            if empty then for _,header in ipairs(B.headers) do header:Hide() end;B.recovery:SetText("No player bag slots were returned by the client. Use Blizzard bags below, or Refresh inventory under Tools.") end

        end

    else

        ns.errors.inventory=tostring(err);ns.errors.inventoryLastFailure="Last draw failure: "..tostring(err)

        if not B.recoveryAttempted then

            B.recoveryAttempted=true

            ns.After("bagRecovery",function() ns.OutOfCombat("bagRecovery",function()

                if B.frame and B.frame:IsShown() then

                    local refreshed,refreshError=pcall(ns.State.Inventory)

                    if not refreshed then ns.errors.inventoryRefresh=tostring(refreshError) end

                    B.Render()

                end

            end) end)

        end

        -- An error must never leave an unexplained blank bag window.

        for _,button in pairs(B.buttons) do if not InCombatLockdown() then button:Hide() end end

        for _,header in ipairs(B.headers) do header:Hide() end

        for _,button in pairs(B.assignButtons or {}) do button:Hide() end

        for _,cell in pairs(B.fallbacks or {}) do cell:Hide() end

        if not InCombatLockdown() then B.frame:SetSize(B.width,B.height);U.Fit(B.frame) end

        B.recovery:SetWidth(B.frame:GetWidth()-36)

        B.recovery:SetText("Inventory could not be drawn. Open Blizzard bags below; Settings > About has the error.")

        B.recovery:Show();B.native:Show()

    end

end

local function releaseNativeSession()
    if B.nativeSession and not B.AnyNativePlayerBagShown() then B.nativeSession=nil end
end
function B.OpenNative()

    if InCombatLockdown() then ns.OutOfCombat("nativeBags",B.OpenNative);return end

    -- Keep native ownership until the last native player bag closes.

    B.nativeSession=true;B.Hide()

    local ok,err=pcall(function()

        local open=B.originals.OpenAllBags or OpenAllBags

        local single=B.originals.OpenBag or OpenBag

        if not open and not single then error("Native bag entry points are unavailable") end

        if open then open(nil,true) end

        -- OpenAllBags may return early when any other bag is already open.

        if single then for _,bag in ipairs(ns.API.Bags()) do single(bag,true) end end

    end)

    ns.After("nativeBagSession",releaseNativeSession,0)
    if not ok then ns.errors.nativeBags=tostring(err);ns.Message("Blizzard bags could not be opened. See Settings > About.") else ns.errors.nativeBags=nil end

end



-- Mask the paint during the deferred handoff. The native operation still
-- finishes, and the previous alpha is restored if the handoff cannot run.

local actionPriority={toggle=3,toggleBag=3,open=2,openAll=2,openBag=2,close=1,closeAll=1,closeBag=1}
function B.MergeBagAction(pending,action)
    if not pending or actionPriority[action]>actionPriority[pending] then return action end
    return pending
end
function B.QueueNative(action)

    if not B.Enabled() or B.bypass or InCombatLockdown() then return end
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then maskNativeBag(ContainerFrameCombinedBags) end
    for i=1,(NUM_CONTAINER_FRAMES or 20) do
        local frame=_G["ContainerFrame"..i]
        if frame and frame:IsShown() then maskNativeBag(frame) end
    end

    if action then B.pendingNativeAction=B.MergeBagAction(B.pendingNativeAction,action) end

    if B.nativeHandoffQueued then return end

    B.nativeHandoffQueued=true

    local function handoff()

        B.nativeHandoffQueued=nil

        local pending=B.pendingNativeAction;B.pendingNativeAction=nil

        if B.Enabled() and not InCombatLockdown() and (pending or B.AnyNativePlayerBagShown()) then
            ns.Invoke("nativeBagHandoff",function()
                B.WatchNative()
                local shown=B.frame and B.frame:IsShown()
                local toggle=pending=="toggle" or pending=="toggleBag"
                if (toggle and shown) or (pending and actionPriority[pending]==1) then
                    B.SuppressNative()
                    B.Hide()
                else B.Show() end
            end)
        end
        for frame in pairs(maskedNativeBags) do unmaskNativeBag(frame) end

    end

    if C_Timer and C_Timer.After then C_Timer.After(0,handoff) else handoff() end

end

function B.InstallHooks()

    -- Secure post-observation preserves native function identity and execution.

    -- Never replace Blizzard bag globals or invoke originals from addon wrappers.

    local specs={ToggleBackpack="toggle",ToggleAllBags="toggle",ToggleBag="toggleBag",OpenBackpack="open",OpenAllBags="openAll",OpenBag="openBag",CloseBackpack="close",CloseAllBags="closeAll",CloseBag="closeBag"}

    for name,action in pairs(specs) do

        if type(_G[name])=="function" and not B.originals[name] and type(hooksecurefunc)=="function" then

            B.originals[name]=_G[name];local behavior=action

            hooksecurefunc(name,function(...)

                if B.nativeSession then ns.After("nativeBagSession",releaseNativeSession,0);return end
                if not B.Enabled() or B.bypass then return end

                local id=select(1,...)

                -- Closing a native equipment bag can be part of replacing it.
                -- Only backpack and whole-window requests close the combined inventory.
                if behavior=="closeBag" and id~=0 then return end
                if (behavior=="toggleBag" or behavior=="openBag") and not B.IsPlayerBag(id) then return end

                if InCombatLockdown() then if B.QueueCombat then B.QueueCombat(behavior) end;return end
                B.QueueNative(behavior)

            end)

        end

    end

    B.WatchNative()

end

function B.WatchNative()

    local frames={}

    if ContainerFrameCombinedBags then frames[#frames+1]=ContainerFrameCombinedBags end

    for i=1,(NUM_CONTAINER_FRAMES or 20) do if _G["ContainerFrame"..i] then frames[#frames+1]=_G["ContainerFrame"..i] end end

    for _,frame in ipairs(frames) do if not frame.toonKitObserved then

        frame.toonKitObserved=true

        frame:HookScript("OnShow",function(self)

            if not B.Enabled() or B.bypass or InCombatLockdown() then return end

            if B.IsNativePlayerFrame(self) then B.QueueNative() end

        end)
        frame:HookScript("OnHide",function(self)
            unmaskNativeBag(self)
            if B.nativeSession and B.IsNativePlayerFrame(self) then ns.After("nativeBagSession",releaseNativeSession,0) end
        end)

    end end

end

function B.Create()

    if B.frame then return end

    if not ContainerFrameItemButtonMixin and C_AddOns and C_AddOns.LoadAddOn and not InCombatLockdown() then

        -- Do not ask the client to load a module absent from this build.

        local info=ns.Safe(ns.API.Call("C_AddOns","GetAddOnInfo","Blizzard_ContainerUI"))

        if type(info)=="string" or type(info)=="table" then

            local ok,loaded,reason=pcall(C_AddOns.LoadAddOn,"Blizzard_ContainerUI")

            loaded=ns.Safe(loaded,false);reason=ns.Safe(reason,"No reason returned")

            if not ok or not loaded then ns.errors.inventoryDependency="Blizzard_ContainerUI: "..tostring(ok and reason or loaded) end

        else ns.errors.inventoryDependency="Native bag module is not listed by this client; no load request was issued." end

    end

    B.supported=ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.GetBagID and true or false

    if not B.supported then ns.Message("Native bag controls are not ready. Blizzard bags remain available; retry Open bags or see About diagnostics."); return end

    ns.errors.inventoryDependency=nil

    B.frame=U.Window(B.width,B.height,"Inventory","bags");U.CompactChrome(B.frame);B.frame:SetResizable(false)

    B.character=U.IconButton(B.frame,"Interface\\Icons\\INV_Misc_GroupLooking","Browse character bags",function(self) B.CharacterMenu(self) end,24);B.character:SetPoint("TOPLEFT",12,-5)
    local filters={{"Equipment","INV_Chest_Plate16"},{"Consumables","INV_Potion_51"},{"Quest items","INV_Misc_Note_01"}}

    B.filterButtons={}

    for i,entry in ipairs(filters) do local category=entry[1]

        local action=U.IconButton(B.frame,"Interface\\Icons\\"..entry[2],category.." - click again for all items",function() B.filter=B.filter==category and "All" or category;B.scroll:SetVerticalScroll(0);B.Render() end,22)

        action:SetPoint("TOPLEFT",10+(i-1)*24,-5);action:Hide();B.filterButtons[category]=action

    end

    local organize=U.IconButton(B.frame,"Interface\\Icons\\Trade_Engineering","Edit categories",function() ns.InventoryOrganizer.Show("Groups") end,22);organize:SetPoint("TOPRIGHT",-30,-5)

    local tidy=U.IconButton(B.frame,"Interface\\Icons\\INV_Misc_Bag_10","Clean up physical bags",function() if B.offlineKey then ns.Message("Select your live bags to clean up.") elseif InCombatLockdown() then ns.Message("Clean up after combat.") else ns.API.Call("C_Container","SortBags") end end,22);tidy:SetPoint("TOPRIGHT",-54,-5)


    B.search=U.Edit(B.frame,230,"",nil);B.search:SetPoint("TOPLEFT",24,-37);B.search:SetMaxLetters(200);U.Placeholder(B.search,"Search your bags")

    B.search:SetScript("OnTextChanged",function(self) B.query=self:GetText():lower();ns.After("bagSearch",B.Render) end)
    B.search:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)

    U.Tooltip(B.search,"Search inventory",{"Names, quoted phrases, categories and item filters. Dim search keeps item positions; click a collapsed heading to open it.","Press Escape to clear search. Search help is under Options."})
    B.search:SetScript("OnEscapePressed",function(self) self:SetText("");self:ClearFocus() end)

    B.tools=U.IconButton(B.frame,"Interface\\Buttons\\UI-OptionsButton","Inventory options",function(self)
        ns.QuestWorkspace.Menu(self,{
            {"Item size: "..ns.db.settings.bagIconSize.." px",function()
                local sizes={}
                for _,size in ipairs({32,40,48,56}) do
                    local pixels=size
                    sizes[#sizes+1]={pixels.." px",function() ns.Preferences.Set("bagIconSize",pixels) end}
                end
                ns.QuestWorkspace.Menu(B.tools,sizes)
            end},
            {"Display sort",function() B.SortMenu(B.tools) end},
            {"Filter categories",function() B.CategoryMenu(B.tools) end},
            {"Assign categories",function() if not B.offlineKey then B.assignMode=not B.assignMode;B.inlineAssignment=nil;B.Render() end end},
            {"Clear search and filters",function() B.query="";B.filter="All";B.bagFilter=nil;B.search:SetText("");B.Render() end},
            {"Categories and rules",function() ns.InventoryOrganizer.Show("Groups") end},
            {"Quest supplies",function() ns.InventoryOrganizer.Show("Supplies") end},
            {"Show free slots",function() ns.SetSetting("showEmpty",not ns.db.settings.showEmpty) end},
            {"More tools",function() B.MoreTools() end},
            {"Search help",function() ns.InventoryOrganizer.Show("Search") end},
        })
    end,22);B.tools:SetPoint("TOPRIGHT",-78,-5);B.tools:SetSize(22,22)

    B.scroll=CreateFrame("ScrollFrame",nil,B.frame); B.scroll:SetPoint("TOPLEFT",14,-73); B.scroll:SetPoint("BOTTOMRIGHT",-32,34)

    if B.scroll.EnableMouseWheel then B.scroll:EnableMouseWheel(false) end

    B.content=CreateFrame("Frame",nil,B.scroll); B.content:SetSize(500,800); B.scroll:SetScrollChild(B.content)

    B.space=U.Label(B.frame,"",14,-10,340,"GameFontHighlightSmall");B.space:ClearAllPoints();B.space:SetPoint("BOTTOMLEFT",14,14)

    B.doneAssign=U.Button(B.frame,"Done assigning",120,function() B.assignMode=false;B.Render() end);B.doneAssign:SetPoint("BOTTOMRIGHT",-24,8);B.doneAssign:Hide()

    B.recovery=U.Label(B.frame,"",18,-80,280,"GameFontHighlight");B.recovery:Hide()

    B.native=U.Button(B.frame,"Blizzard bags",115,B.OpenNative);B.native:SetPoint("BOTTOMRIGHT",-25,8);B.native:Hide()

    B.frame:SetScript("OnShow",B.Render)

    B.InstallHooks()

end

ns.Listen("STATE_CHANGED",function(kind)
    if B.frame and B.frame:IsShown() and ns.Changed(kind,"inventory","quests","identity","talents","storage") then ns.After("bagRedraw",B.Render,0.25) end
end)

ns.Listen("SETTINGS_CHANGED",function()

    if not B.frame then return end

    ns.OutOfCombat("bagPreferences",function()
        B.width=ns.db.settings.bagWidth;B.height=ns.db.settings.bagHeight
        B.frame:SetSize(B.width,B.height)

        if ns.db.settings.inventory then B.InstallHooks(); B.Render() else B.Hide() end

    end)

end)

ns.On("BAG_SLOT_FLAGS_UPDATED",function() ns.After("bagFlags",function() if ns.InventoryOrganizer.bagFrame and ns.InventoryOrganizer.bagFrame:IsShown() then ns.InventoryOrganizer.BagPreferences() end;B.Render() end) end)
for _,event in ipairs({"DISPLAY_SIZE_CHANGED","UI_SCALE_CHANGED"}) do
    ns.On(event,function() if B.frame and B.frame:IsShown() then ns.After("bagViewport",B.Render) end end)
end

function B.RefreshCooldowns()
    if not B.frame or not B.frame:IsShown() or B.offlineKey or InCombatLockdown() then return end
    for key,button in pairs(B.buttons or {}) do
        local item=ns.State.bagLookup and ns.State.bagLookup[key]
        if item and button:IsShown() and button.UpdateCooldown then button:UpdateCooldown(item.icon) end
    end
end
ns.On("BAG_UPDATE_COOLDOWN",function() if B.frame and B.frame:IsShown() then ns.After("bagCooldown",B.RefreshCooldowns) end end)

ns.On("PLAYER_MONEY",function()
    if B.frame and B.frame:IsShown() and not B.offlineKey then ns.After("bagMoney",function() if B.money then B.money:SetText(ns.API.Money()) end end) end
end)

ns.On("ADDON_LOADED",function(name)

    if name=="Blizzard_ContainerUI" and ns.char and not B.frame then ns.After("containerUI",B.Create) end

end)



ns.On("CURRENCY_DISPLAY_UPDATE",function() ns.After("bagCurrency",B.Render) end)

ns.On("PLAYER_ENTERING_WORLD",function() ns.After("bagCurrency",B.Render) end)



for _,event in ipairs({"ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN"}) do

    local kind=event

    ns.On(event,function(offender,action)

        offender,action=ns.Safe(offender),ns.Safe(action)

        if offender==addonName then ns.errors.inventoryBlockedAction=kind..": "..tostring(action or "Unknown function") end

    end)

end



-- Advisory only: keep deletion on the native item interaction path.
function B.RoomCandidates()
    local candidates={}
    for _,item in ipairs(ns.State.bags or {}) do
        local info=item.info;local q=item.quest
        local questKnown=type(q)=="table" and ns.Safe(q.isQuestItem)==false and ns.Safe(q.questID)==nil
        local recipes=ns.Data.reagentRecipeIndex
        if item.id and info and item.quality==0 and info.quality==0 and not item.locked
            and questKnown and info.equip=="" and info.reagent==false
            and not (recipes and recipes.items[item.id])
            and type(info.classID)=="number" and info.classID==15
            and info.sellPriceKnown==true and type(info.sellPrice)=="number" and info.sellPrice>0
            and type(item.count)=="number" and item.count>0
            and not ns.InventoryActions.KeepReason(item) then
            candidates[#candidates+1]={item=item,value=info.sellPrice*item.count}
        end
    end
    table.sort(candidates,function(a,b)
        if a.value~=b.value then return a.value<b.value end
        if a.item.bag~=b.item.bag then return a.item.bag<b.item.bag end
        return a.item.slot<b.item.slot
    end)
    return candidates
end
function B.MakeRoom()
    if not ns.char then return end
    if not B.room then B.room=U.Window(700,330,"Make room","makeRoom");B.room.body=CreateFrame("Frame",nil,B.room);B.room.body._managed=true;B.room.body:SetPoint("TOPLEFT",22,-66) end
    local page=B.room;U.Release(page.body)
    local candidates=B.RoomCandidates();local candidate=candidates[1]
    U.Label(page.body,"Lowest vendor value among review candidates",0,0,640,"GameFontNormalLarge")
    if candidate then
        local item=candidate.item
        U.Item(page.body,item.id,0,-40,40,item.link)
        U.Label(page.body,(item.link or item.info.name).."  x"..item.count,54,-42,560,"GameFontNormal")
        U.Label(page.body,"Verified vendor value "..ns.Gold.Format(candidate.value).." · Bag "..item.bag..", slot "..item.slot,0,-96,640,"GameFontHighlight")
        U.Label(page.body,"Review this stack in your bags. Its future use is unknown. To make room, use the native item controls and review the game's confirmation.",0,-133,640,"GameFontHighlight")
        local show=U.Button(page.body,"Find this item in bags",230,function() B.query=item.info.name:lower();B.Show();if B.search then B.search:SetText(item.info.name) end;B.Render() end);show:SetPoint("TOPLEFT",0,-212)
    else
        U.Label(page.body,"No poor-quality stacks with confirmed vendor value passed the review filters.",0,-44,640,"GameFontHighlight")
    end
    local refresh=U.Button(page.body,"Refresh recommendation",230,function() B.MakeRoom() end);refresh:SetPoint("TOPLEFT",260,-212)
    page:Show()
end
ns.On("LOOT_OPENED",function()
    if not ns.char or not ns.db.settings.inventory or (ns.State.free or 1)>0 then return end
    local lowest=B.RoomCandidates()[1]
    if lowest then ns.Message("Bags full. Review "..(lowest.item.info.name or "item").." x"..lowest.item.count.." in Bags > Options > Make room.") end
end)

function B.MoreTools()
    ns.QuestWorkspace.Menu(B.tools,{
        {"Grouped / grid",function() ns.SetSetting("bagGrouped",not ns.db.settings.bagGrouped) end},
        {"Show hidden categories",function() B.showHidden=not B.showHidden;B.Render() end},
        {"Make room",B.MakeRoom},
        {"Refresh bags",function() ns.State.Refresh("inventory") end},
        {"Blizzard bags",B.OpenNative},
        {"Bag destinations",function() ns.InventoryOrganizer.BagPreferences(B.bagFilter or 0) end},
        {"Mark items seen",function() I.MarkSeen() end},
        {"Review matching sales",function() ns.InventoryActionView.Show("sell",{query=B.query,bag=B.bagFilter,group=B.filter,recorded=B.offlineKey~=nil}) end},
        {"Deposit matching items",function()
            local kind=BankFrame and BankFrame.GetActiveBankType and ns.Safe(BankFrame:GetActiveBankType())
            ns.InventoryActionView.Show("deposit",{query=B.query,bag=B.bagFilter,group=B.filter,recorded=B.offlineKey~=nil,bankType=kind})
        end},
    })
end
function B.CharacterMenu(anchor)
    local rows={{value="current",label=ns.State.name.." (live)"}}
    for key,character in pairs(ns.db.characters) do if character~=ns.char and character.bagSnapshot then
        local identity=character.identity or {};rows[#rows+1]={value=key,label=(identity.name or "Character").." - "..(identity.realm or "Realm").." (recorded)"}
    end end
    table.sort(rows,function(a,b) if a.value=="current" then return true elseif b.value=="current" then return false end;return a.label<b.label end)
    local menu={};for _,entry in ipairs(rows) do local row=entry;menu[#menu+1]={row.label,function() B.SelectCharacter(row.value) end} end
    ns.QuestWorkspace.Menu(anchor,menu,320)
end
function B.SortMenu(anchor)
    local menu={}
    for _,entry in ipairs({{"category","Name"},{"quality","Quality"},{"new","New first"},{"level","Item level"},{"value","Sell value"},{"bag","Bag / slot"}}) do local row=entry
        menu[#menu+1]={row[2]..(ns.db.settings.bagSort==row[1] and " (selected)" or ""),function() ns.SetSetting("bagSort",row[1]) end}
    end
    ns.QuestWorkspace.Menu(anchor,menu)
end
function B.CategoryMenu(anchor)
    local menu={{"All categories",function() B.filter="All";B.Render() end}}
    for _,group in ipairs(B.view and B.view.groups or I.Groups()) do local category=group
        local count=(B.categoryCounts or {})[category.id] or 0
        if count>0 or B.filter==category.id then menu[#menu+1]={category.name.." ("..count..")",function() B.filter=category.id;B.Render() end} end
    end
    ns.QuestWorkspace.Menu(anchor,menu,300)
end
function B.CategoryEditMenu(id,anchor)
    ns.QuestWorkspace.Menu(anchor,{
        {"Move earlier",function() I.MoveGroup(id,-1);B.Render() end},
        {"Move later",function() I.MoveGroup(id,1);B.Render() end},
        {ns.db.settings.bagHiddenGroups[id] and "Show category" or "Hide category",function() ns.db.settings.bagHiddenGroups[id]=not ns.db.settings.bagHiddenGroups[id];ns.Emit("STATE_CHANGED") end},
        {"Matching rules",function() ns.InventoryOrganizer.group=id;ns.InventoryOrganizer.Show("Groups") end},
    })
end
function B.AssignmentMenu(item)
    if not B.assignMode or B.offlineKey or not item.id then return end
    local function assign(value)
        if B.offlineKey or not B.assignMode then return end
        ns.char.itemGroups=ns.char.itemGroups or {};ns.char.itemGroups[item.id]=value;ns.Emit("STATE_CHANGED")
    end
    local menu={{"Automatic category",function() assign(nil) end},{"Keep this item",function()
        local keep;for _,group in ipairs(I.Groups()) do if I.Name(group.id)=="Keep" then keep=group.id;break end end
        keep=keep or I.CreateGroup("Keep");if keep then assign(keep) end
    end}}
    for _,group in ipairs(I.Groups()) do local category=group
        if category.id~="Empty" and category.id~="Reagent bag" then menu[#menu+1]={I.Name(category.id),function() assign(category.id) end} end
    end
    ns.QuestWorkspace.Menu(B.tools,menu,300)
end
function B.QuickControls()
    if not B.quick then B.quick=CreateFrame("Frame",nil,B.frame);B.quick._managed=true end
    B.quick:ClearAllPoints();B.quick:SetPoint("TOPLEFT",14,-64);B.quick:SetSize(B.frame:GetWidth()-28,16);U.Release(B.quick)
    B.optionsOpen=false;B.categoriesOpen=false;B.sortOpen=false;B.characterOpen=false;B.editCategory=nil
    local parts={}
    if B.filter~="All" then parts[#parts+1]=B.CategoryName(B.filter) else parts[#parts+1]="All categories" end
    if B.bagFilter~=nil then parts[#parts+1]=B.bagFilter==0 and "Backpack" or "Bag "..B.bagFilter end
    if B.offlineKey then parts[#parts+1]="Recorded inventory" end
    if B.assignMode then parts[#parts+1]="Assign mode" end
    U.Label(B.quick,table.concat(parts,"  |  "),0,0,B.quick:GetWidth(),"GameFontHighlightSmall")
    if B.inlineAssignment then local item=B.inlineAssignment;B.inlineAssignment=nil
        ns.After("bagAssignmentMenu",function() if B.frame:IsShown() then B.AssignmentMenu(item) end end)
    end
    return 0
end

ns.Listen("BAG_LOCK_CHANGED",function(bag,slot,locked)
    if B.offlineKey or not B.frame or not B.frame:IsShown() then return end
    local button=B.buttons[bag..":"..slot]
    if button then
        if button.tkIcon then button.tkIcon:SetDesaturated(locked) end
        if SetItemButtonDesaturated then SetItemButtonDesaturated(button,locked) end
    end
end)
