local addonName, ns = ...
local B,U=ns.Inventory,ns.UI
local C={buttons={},proxies={}};B.combat=C
local function free(frame)
    return frame and type(frame.IsProtected)=="function" and ns.Safe(frame:IsProtected())==false
end
local function ready()
    if not free(C.frame) then return false end
    for _,button in pairs(C.buttons) do if button.active and not free(button) then return false end end
    return true
end
local function nativeFrames()
    local frames={}
    if ContainerFrameCombinedBags then frames[#frames+1]=ContainerFrameCombinedBags end
    for i=1,(NUM_CONTAINER_FRAMES or 20) do
        local f=_G["ContainerFrame"..i]
        if f and f:IsShown() and B.IsNativePlayerFrame(f) then frames[#frames+1]=f end
    end
    return frames
end
function C.Refresh()
    if not C.frame or not C.frame:IsShown() then return end
    for _,b in pairs(C.buttons) do if b.active then
        local item=ns.Safe(ns.API.Call("C_Container","GetContainerItemInfo",b.bag,b.slot))
        if type(item)~="table" then item=nil end
        local occupied=item and (ns.Safe(item.itemID) or ns.Safe(item.hyperlink))
        local icon=occupied and (ns.Safe(item.iconFileID) or 134400) or nil
        local count=occupied and ns.Safe(item.stackCount)
        if b.SetHasItem then b:SetHasItem(icon) end
        b.icon:SetTexture(icon);b.icon:SetDesaturated(item and ns.Safe(item.isLocked,false) or false)
        b.Count:SetText(type(count)=="number" and count>1 and count or "");b.Count:SetShown(type(count)=="number" and count>1)
        if b.Cooldown and b.Cooldown.SetCooldown then
            local start,duration=ns.API.Call("C_Container","GetContainerItemCooldown",b.bag,b.slot)
            start,duration=ns.Safe(start),ns.Safe(duration)
            if type(start)=="number" and type(duration)=="number" then
                if duration>0 then b.Cooldown:SetCooldown(start,duration) elseif b.Cooldown.Clear then b.Cooldown:Clear() end
            end
        end
    end end
    C.note:SetText((ns.State.free or 0).." free / "..(ns.State.capacity or 0).." slots | Combat: fixed slots; categories resume afterward")
end
function C.Prepare()
    if InCombatLockdown() then ns.deferred.combatInventory=C.Prepare;return end
    if not B.frame or not B.supported or not ns.char then return end
    local size=ns.db.settings.bagIconSize or 32;local step=size+2;local capacity=ns.State.capacity or 0
    if capacity==0 then return end
    local rows=math.max(1,math.floor((UIParent:GetHeight()-140)/step))
    local columns=math.max(12,math.ceil(capacity/rows));local width=columns*step+32
    if width>UIParent:GetWidth()-24 then C.ready=false;return end
    if not C.frame then
        C.frame=U.Window(width,220,"Inventory - Combat","combatBags");U.CompactChrome(C.frame)
        C.content=CreateFrame("Frame",nil,C.frame);C.content:SetPoint("TOPLEFT",16,-40)
        C.note=U.Label(C.frame,"",16,-10,width-32,"GameFontHighlightSmall");C.note:ClearAllPoints();C.note:SetPoint("BOTTOMLEFT",16,12)
        C.frame:SetScript("OnShow",C.Refresh)
    end
    local signature=capacity..":"..size..":"..columns
    for _,bag in ipairs(ns.API.Bags()) do signature=signature..":"..bag.."/"..((ns.State.bagSlots or {})[bag] or 0) end
    local function align()
        if InCombatLockdown() then return end
        local point,relative,relativePoint,x,y=B.frame:GetPoint()
        if point then C.frame:ClearAllPoints();C.frame:SetPoint(point,relative or UIParent,relativePoint,x,y) end
        C.frame:SetScale(B.frame:GetScale())
    end
    align()
    if not C.dragObserved then B.frame:HookScript("OnDragStop",align);C.dragObserved=true end
    if C.signature==signature then C.ready=ready();return end
    C.frame:SetSize(width,math.ceil(capacity/columns)*step+82);C.note:SetWidth(width-32)
    C.content:SetSize(columns*step,math.ceil(capacity/columns)*step)
    for _,b in pairs(C.buttons) do b.active=false;b:Hide() end
    local index=0
    for _,bag in ipairs(ns.API.Bags()) do
        if not C.proxies[bag] then
            local proxy=CreateFrame("Frame",nil,C.content);proxy:SetID(bag);proxy:SetAllPoints(C.content)
            proxy:EnableMouse(false)
            proxy.GetBagID=function(self) return self:GetID() end
            proxy.IsCombinedBagContainer=function() return true end
            C.proxies[bag]=proxy
        end
        for slot=1,(ns.State.bagSlots or {})[bag] or 0 do
            local key=bag..":"..slot;local b=C.buttons[key]
            if not b then
                b=CreateFrame("ItemButton",nil,C.proxies[bag],"ContainerFrameItemButtonTemplate")
                b:SetID(slot)
                b:EnableMouse(true)
                b.bag=bag;b.slot=slot;C.buttons[key]=b
            end
            b.active=true;b:SetSize(size,size);b:ClearAllPoints();b:SetPoint("TOPLEFT",C.content,"TOPLEFT",(index%columns)*step,-math.floor(index/columns)*step)
            b:Show();index=index+1
        end
    end
    C.signature=signature;C.ready=ready()
end
function B.CombatHandle(action)
    if not B.Enabled() or not C.ready or not ready() or not free(B.frame) then return false end
    local frames=nativeFrames()
    for _,f in ipairs(frames) do if f:IsShown() and not free(f) then return false end end
    local visible=C.frame:IsShown() or B.frame:IsShown()
    local show=action=="toggle" or action=="toggleBag"
    if show then show=not visible else show=action=="open" or action=="openAll" or action=="openBag" end
    for _,f in ipairs(frames) do if f:IsShown() then f:Hide() end end
    B.frame:Hide();C.frame:SetShown(show);if show then C.Refresh() end
    return true
end
function B.QueueCombat(action)
    C.pending=B.MergeBagAction(C.pending,action);if C.queued then return end;C.queued=true
    C_Timer.After(0,function()
        C.queued=nil;local pending=C.pending;C.pending=nil
        if pending and InCombatLockdown() then
            C.nativeFallback=not B.CombatHandle(pending) and B.Enabled() and B.AnyNativePlayerBagShown()
        end
    end)
end
local show,hide,toggle=B.Show,B.Hide,B.Toggle
function B.Show() if InCombatLockdown() and B.CombatHandle("open") then return end;return show() end
function B.Toggle() if InCombatLockdown() and B.CombatHandle("toggle") then return end;return toggle() end
function B.Hide() if InCombatLockdown() and B.CombatHandle("close") then return end;return hide() end
ns.Listen("STATE_CHANGED",function(kind)
    if not ns.Changed(kind,"inventory","identity") then return end
    if InCombatLockdown() then ns.After("combatInventoryContents",C.Refresh) else ns.After("combatInventory",C.Prepare) end
end)
ns.Listen("SETTINGS_CHANGED",function() C.signature=nil;ns.After("combatInventory",C.Prepare) end)
ns.On("PLAYER_LOGIN",function() ns.After("combatInventory",C.Prepare) end)
ns.On("PLAYER_REGEN_ENABLED",function()
    local shown=C.frame and C.frame:IsShown()
    local fallback=C.nativeFallback and B.Enabled() and B.AnyNativePlayerBagShown()
    C.nativeFallback=nil
    if C.frame then C.frame:Hide() end
    ns.After("combatInventory",C.Prepare)
    if shown or fallback then ns.After("combatInventoryReturn",function()
        if B.Enabled() and (shown or B.AnyNativePlayerBagShown()) then B.Show() end
    end) end
end)
for _,event in ipairs({"BAG_UPDATE_DELAYED","ITEM_LOCK_CHANGED","BAG_UPDATE_COOLDOWN"}) do ns.On(event,function() if InCombatLockdown() then ns.After("combatInventoryContents",C.Refresh) end end) end
