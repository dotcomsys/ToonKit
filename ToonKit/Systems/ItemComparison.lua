local addonName, ns = ...
local I={};ns.ItemComparison=I
function I.Badge(texture,kind)
    texture:SetVertexColor(1,1,1)
    texture:SetTexCoord(0,1,0,1)
    if kind=="upgrade" then
        if ns.API.Call("C_Texture","GetAtlasInfo","bags-greenarrow") then
            texture:SetAtlas("bags-greenarrow",false)
        else
            texture:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
            texture:SetVertexColor(.35,1,.4)
        end
    else
        texture:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    end
    texture:Show()
end
function I.Profile()
    return ns.SpecItemAdvice.Profile()
end
function I.Compare(id,link,wantedSlot)
    local info=ns.API.Item(link or id)
    if not info then return {kind="pending",text="Loading item data"} end
    local slots=ns.Data.equipSlots[info.equip]
    if not slots then return end
    if type(info.required)=="number" and info.required>(ns.State.level or 0) then
        return {kind="manual",text="KEEP FOR REVIEW: requires level "..info.required,reason="A future level requirement is not evidence that this item should be sold."}
    end
    local eligible,eligibility=ns.API.ItemEligibility(id,info)
    if eligible~=true then return {kind=eligible==false and "unusable" or "pending",text=eligible==false and "Cannot equip now" or "Item usability unknown",reason=eligibility} end
    return ns.SpecItemAdvice.Compare(id,link,wantedSlot,I.Profile())
end

-- Tooltips and visible item badges cache exact variants
-- within the current character/build/item revisions, including manual settings.
function I.Cached(id,link,slot)
    if not id or not ns.char then return end
    local revision=table.concat({ns.State.inventoryRevision or 0,ns.State.itemRevision or 0,ns.State.revision or 0,ns.Talents.revision or 0,ns.State.spec or "",ns.char.playstyle or ""},":")
    if I.cacheRevision~=revision then I.cache={};I.cacheRevision=revision end
    I.cache=I.cache or {};local key=tostring(link or id)..":"..tostring(slot or "")
    if I.cache[key] then return I.cache[key] end
    local advice=I.Compare(id,link,slot)
    if advice and advice.kind~="pending" and not advice.retry then I.cache[key]=advice end
    return advice
end
function I.StatusText(advice,upgrade)
    if not advice then return end
    if upgrade then return advice.specName and "Upgrade for "..advice.specName or "Upgrade" end
    if advice.kind=="noUpgrade" then return advice.text or "Keep equipped for current build" end
    if advice.kind=="unusable" then return advice.text or "Cannot equip now" end
    if advice.kind=="pending" then return "Comparison pending" end
    if advice.tradeoff then return "Trade-off for "..advice.specName.." · review before replacing" end
    if advice.effectsUnresolved and advice.statDelta then
        if advice.statDelta>0 then return "Better stats · compare effects" end
        if advice.statDelta<0 then return "Effects unresolved · review before replacing or selling" end
        return "Even stats · compare effects"
    end
    return advice.text or "Comparison unavailable"
end
function I.ItemDecision(id,link,info,slot)
    if not info then return "Loading item data" end
    if not ns.Data.equipSlots[info.equip] then return end
    local advice=I.Cached(id,link or info.link,slot)
    return I.StatusText(advice,advice and advice.kind=="upgrade"),advice
end
function I.VendorValue(info,quantity)
    local price=info and ns.Safe(info.sellPrice)
    if not info or info.sellPriceKnown~=true or type(price)~="number" or price<0 or price>1000000000000
        or price~=math.floor(price) or type(quantity)~="number" or quantity<1 or quantity>1000000
        or quantity~=math.floor(quantity) or price*quantity>9007199254740991 then return end
    return price*quantity
end
function I.AppendStatus(tooltip,advice,upgrade)
    local text=I.StatusText(advice,upgrade)
    if not text then return end
    tooltip:AddLine(text,upgrade and .3 or .9,upgrade and 1 or .85,upgrade and .3 or .65,true)
end
function I.Append(tooltip,id,link)
    if not tooltip or not ns.char or ns.db.settings.gearItemAdvice==false or ns.db.settings.modules.gear==false then return end
    local key=link or id
    if tooltip.tkBuildComparison==key then return end
    if ns.QuestRewards and ns.QuestRewards.TooltipOwner(tooltip) then return end
    local advice=I.Cached(id,link)
    if not advice then return end
    tooltip.tkBuildComparison=key
    I.AppendStatus(tooltip,advice,advice.kind=="upgrade")
    if advice.reason and type(IsShiftKeyDown)=="function" and IsShiftKeyDown() then
        tooltip:AddLine(advice.reason,.8,.8,.7,true)
    end
end
ns.Listen("SETTINGS_CHANGED",function() I.cache=nil;I.cacheRevision=nil end)
if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipCleared",function(self) self.tkBuildComparison=nil end)
end
