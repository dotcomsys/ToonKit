local addonName, ns = ...
local K={}; ns.MinimapButton=K
function K.Position()
    if not K.button or not Minimap then return end
    local angle=math.rad(ns.db.settings.minimapAngle or 225)
    local radius=Minimap:GetWidth()/2+7
    K.button:ClearAllPoints(); K.button:SetPoint("CENTER",Minimap,"CENTER",math.cos(angle)*radius,math.sin(angle)*radius)
end
function K.Create()
    if K.button or not Minimap then return end
    local b=CreateFrame("Button",nil,Minimap); K.button=b
    b:SetSize(32,32); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(Minimap:GetFrameLevel()+8)
    b.icon=b:CreateTexture(nil,"BACKGROUND"); b.icon:SetSize(21,21); b.icon:SetPoint("CENTER"); b.icon:SetTexture(ns.Brand.icon)
    b.icon:SetTexCoord(.08,.92,.08,.92)
    local border=b:CreateTexture(nil,"OVERLAY"); border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); border:SetSize(54,54); border:SetPoint("TOPLEFT")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b:RegisterForClicks("LeftButtonUp","RightButtonUp"); b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick",function(_,button)
        if K.dragged then K.dragged=nil; return end
        if button=="RightButton" then ns.Inventory.Toggle()
        elseif IsShiftKeyDown() then ns.SetSetting("guide",not ns.db.settings.guide)
        else ns.Main.Toggle() end
    end)
    b:SetScript("OnDragStart",function(self)
        if ns.db.settings.locked then return end
        K.dragged=true
        self:SetScript("OnUpdate",function()
            local x,y=GetCursorPosition(); local cx,cy=Minimap:GetCenter(); local scale=Minimap:GetEffectiveScale()
            if cx and cy and scale>0 then ns.db.settings.minimapAngle=math.deg(math.atan2(y/scale-cy,x/scale-cx)); K.Position() end
        end)
    end)
    b:SetScript("OnDragStop",function(self) self:SetScript("OnUpdate",nil); C_Timer.After(0,function() K.dragged=nil end) end)
    ns.UI.Tooltip(b,ns.Brand.displayName,{"Left-click: open your journal","Right-click: open inventory","Shift-click: show or hide Journey guide","Drag: move around the minimap"})
    K.Position(); b:SetShown(ns.db.settings.minimap)
end
ns.Listen("SETTINGS_CHANGED",function()
    if K.button then K.button:SetShown(ns.db.settings.minimap); K.Position() end
end)
