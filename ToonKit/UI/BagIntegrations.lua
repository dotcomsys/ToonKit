local addonName, ns = ...
local P={cells={},cache={},revision=0};ns.BagIntegrations=P
ns.Defaults.bagMasque=true;ns.Defaults.bagPawn=true;ns.Defaults.bagAppearances=true
local function combat() return type(InCombatLockdown)~="function" or InCombatLockdown() end
function P.Refresh()
    P.revision=P.revision+1;P.cache={};P.retries=0
    if combat() then ns.deferred.bagIntegrations=P.Refresh;return end
    local bags=ns.Inventory
    if bags and bags.frame and bags.frame:IsShown() then ns.After("bagIntegrationPaint",bags.Render) end
    local bank=ns.Bank
    if bank and bank.frame and bank.frame:IsShown() then ns.After("bankIntegrationPaint",bank.Render) end
end
function P.Discover()
    if not P.masque and LibStub and type(LibStub.GetLibrary)=="function" then
        local ok,lib=pcall(LibStub.GetLibrary,LibStub,"Masque",true)
        if ok and lib and type(lib.Group)=="function" then
            local ready,group=pcall(lib.Group,lib,ns.Brand.displayName,"Inventory")
            if ready and group and type(group.AddButton)=="function" and type(group.ReSkin)=="function" and type(group.RemoveButton)=="function" then P.masque=group end
        end
    end
    if not P.pawnHook and type(PawnResetBags)=="function" and type(hooksecurefunc)=="function" then
        hooksecurefunc("PawnResetBags",P.Refresh);P.pawnHook=true
    end
    if not P.appearanceHook and type(CanIMogIt)=="table" and type(CanIMogIt.ResetCache)=="function" and type(hooksecurefunc)=="function" then
        hooksecurefunc(CanIMogIt,"ResetCache",P.Refresh);P.appearanceHook=true
    end
end
function P.Query(item)
    local key=item.link..":"..tostring(item.bag)..":"..tostring(item.slot)
    local cached=P.cache[key];if cached then return cached end
    local result={};P.cache[key]=result
    if ns.db.settings.bagPawn~=false and type(PawnShouldItemLinkHaveUpgradeArrow)=="function" and type(PawnPlayerFullName)=="string" and type(PawnCommon)=="table" and type(PawnCommon.Scales)=="table" and type(PawnOptions)=="table" then
        local ok,value=pcall(PawnShouldItemLinkHaveUpgradeArrow,item.link,true)
        if ok then value=ns.Safe(value);if type(value)=="boolean" then result.upgrade=value else result.pending=true end end
    end
    if ns.db.settings.bagAppearances~=false and type(CanIMogIt)=="table" and type(CanIMogIt.GetTooltipText)=="function" then
        local ok,_,status=pcall(CanIMogIt.GetTooltipText,CanIMogIt,item.link,item.bag,item.slot)
        status=ns.Safe(status)
        if ok and type(status)=="string" and type(CanIMogIt.tooltipOverlayIcons)=="table" then
            local icon=ns.Safe(CanIMogIt.tooltipOverlayIcons[status]);if type(icon)=="string" then result.appearance=icon end
        elseif ok then result.pending=true end
    end
    if result.pending and not P.retryTimer and (P.retries or 0)<6 then
        P.retryTimer=true
        C_Timer.After(.3,function()
            P.retryTimer=nil;P.retries=(P.retries or 0)+1;P.cache={}
            local bags=ns.Inventory
            if not combat() and bags and bags.frame and bags.frame:IsShown() then ns.After("bagIntegrationPaint",bags.Render) end
        end)
    end
    return result
end
function P.Paint(cell,item,size)
    if combat() then return end
    P.Discover()
    local registered=P.cells[cell]
    if P.masque and not P.skinFailed then
        -- Fault isolation for an optional cosmetic library, outside combat.
        -- An incompatible installed skin must not replace native item cells.
        local ok,reason=pcall(function()
            if ns.db.settings.bagMasque~=false then
                if not registered then
                    P.masque:AddButton(cell,{Icon=cell.tkIcon or cell.icon or cell.Icon,Count=cell.Count or cell.count,Cooldown=cell.Cooldown,Border=cell.IconBorder},"Item",true)
                    P.cells[cell]=true
                else P.masque:ReSkin(cell) end
            elseif registered then P.masque:RemoveButton(cell);P.cells[cell]=nil end
        end)
        if not ok then P.skinFailed=true;ns.errors.bagMasque=tostring(reason) end
    end
    cell.tkExternalUpgrade=cell.tkExternalUpgrade or cell:CreateTexture(nil,"OVERLAY",nil,5)
    cell.tkExternalUpgrade:SetSize(14,14);cell.tkExternalUpgrade:SetPoint("TOPRIGHT",-1,-1)
    cell.tkExternalUpgrade:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
    cell.tkAppearance=cell.tkAppearance or cell:CreateTexture(nil,"OVERLAY",nil,5)
    cell.tkAppearance:SetSize(14,14);cell.tkAppearance:SetPoint("BOTTOMRIGHT",-1,1)
    local advice=item.id and type(item.link)=="string" and not item.recorded and P.Query(item) or {}
    cell.tkExternalUpgrade:SetShown(advice.upgrade==true)
    cell.tkAppearance:SetTexture(advice.appearance)
    cell.tkAppearance:SetShown(advice.appearance~=nil and type(item.count)=="number" and item.count<=1)
    if advice.upgrade and cell.tkAdvice then cell.tkAdvice:Hide() end
    if advice.upgrade and size<40 and cell.tkBinding then cell.tkBinding:Hide() end
end
for _,event in ipairs({"ADDON_LOADED","BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED","PLAYER_EQUIPMENT_CHANGED","PLAYER_SPECIALIZATION_CHANGED"}) do ns.On(event,P.Refresh) end
ns.Listen("SETTINGS_CHANGED",P.Refresh)
