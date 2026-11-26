local addonName, ns = ...
local P={buttons={},points={}};ns.DiscoveryPins=P
function P.Stop()
    P.lastX=nil
    if P.ticker then P.ticker:Cancel();P.ticker=nil end
    for _,button in ipairs(P.buttons) do button:Hide() end
end
function P.Pulse()
    if not Minimap or not Minimap:IsShown() or not ns.char or not (ns.db.settings.discoveryMinimap or ns.db.settings.journeyMinimap) then P.Stop();return end
    local map,x,y=ns.API.Position()
    local radius=ns.Safe(ns.API.Call("C_Minimap","GetViewRadius"))
    local w,h
    if map then
        if P.worldMap~=map or not P.worldWidth or not P.worldHeight then
            P.worldMap=map;P.worldWidth,P.worldHeight=ns.API.Call("C_Map","GetMapWorldSize",map)
            P.worldWidth,P.worldHeight=ns.Safe(P.worldWidth),ns.Safe(P.worldHeight)
        end
        w,h=P.worldWidth,P.worldHeight
    end
    w,h=ns.Safe(w),ns.Safe(h)
    local rotate=ns.Safe(ns.API.Call("C_CVar","GetCVarBool","rotateMinimap"),false)
    local facing=0
    if rotate then facing=type(GetPlayerFacing)=="function" and ns.Safe(GetPlayerFacing()) or nil end
    if not map or not x or not y or not radius or radius<=0 or not w or not h or w<=0 or h<=0 or rotate and facing==nil then
        P.lastX=nil;for _,button in ipairs(P.buttons) do button:Hide() end;return
    end
    local pixels=math.min(Minimap:GetWidth(),Minimap:GetHeight())*.5
    if P.lastMap==map and P.lastX==x and P.lastY==y and P.lastFacing==facing and P.lastRadius==radius and P.lastPixels==pixels then return end
    P.lastMap,P.lastX,P.lastY,P.lastFacing,P.lastRadius,P.lastPixels=map,x,y,facing,radius,pixels
    local cosine,sine=math.cos(facing),math.sin(facing)
    for i,entry in ipairs(P.points) do
        local button=P.buttons[i];local point=entry.point
        if point.map==map then
            local dx,dy=(point.x-x)*w,-(point.y-y)*h
            local px=(dx*cosine+dy*sine)/radius*pixels
            local py=(-dx*sine+dy*cosine)/radius*pixels
            -- Never clamp an off-map point onto the edge as though its position were exact.
            if px*px+py*py<(pixels-10)^2 then button:ClearAllPoints();button:SetPoint("CENTER",Minimap,"CENTER",px,py);button:Show()
            else button:Hide() end
        else button:Hide() end
    end
end
function P.Rebuild()
    P.Stop();P.points={};P.lastX=nil
    if not ns.char or not (ns.db.settings.discoveryMinimap or ns.db.settings.journeyMinimap) or not Minimap or not Minimap:IsShown() or not C_Minimap or type(C_Minimap.GetViewRadius)~="function" then return end
    local map=ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"));P.map=map
    if ns.db.settings.discoveryMinimap and ns.db.settings.modules.world then
    for _,record in ipairs(ns.World.Records()) do if not ns.World.Status(record) then
        for _,point in ipairs(ns.World.Locations(record)) do if point.map==map then P.points[#P.points+1]={record=record,point=point} end end
    end end
    end
    if ns.db.settings.journeyMinimap and map then
        for _,marker in ipairs(ns.QuestMarkers.Markers(map)) do
            if marker.point.map==map and not ns.QuestMarkers.Contact(marker.goal) then
                P.points[#P.points+1]={record={name=marker.name,detail=marker.source},point=marker.point,icon=marker.icon,journey=true}
            end
        end
    end
    for i,entry in ipairs(P.points) do
        local button=P.buttons[i]
        if not button then
            button=CreateFrame("Button",nil,Minimap);button:SetSize(18,18);button:SetFrameLevel(Minimap:GetFrameLevel()+4)
            button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetAllPoints();button.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
            button:SetScript("OnEnter",function(self)
                local e=self.entry;GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:SetText(e.record.name)
                GameTooltip:AddLine(e.record.detail or "Library book",1,.82,.5,true)
                GameTooltip:AddLine(e.journey and "Click: waypoint" or "Click: location   |   Shift-click: book details",.8,.8,.8,true);GameTooltip:Show()
            end)
            button:SetScript("OnLeave",function() GameTooltip:Hide() end)
            button:SetScript("OnClick",function(self)
                if self.entry.journey then
                    local p=self.entry.point;ns.API.MapPoint(p.map,p.x,p.y)
                elseif IsShiftKeyDown() then
                    ns.Main.tab="Adventure";ns.Main.sub="World";ns.Main.bookSelection=self.entry.record.id;ns.Main.query="";ns.Main.zoneOnly=false;ns.Main.hideDone=false
                    ns.UI.main:Show();ns.Main.Render()
                else ns.World.Waypoint(self.entry.record,self.entry.point) end
            end)
            P.buttons[i]=button
        end
        button.entry=entry
        button.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_Book_09")
    end
    P.Pulse()
    if #P.points>0 and C_Timer.NewTicker then P.ticker=C_Timer.NewTicker(.2,P.Pulse) end
end
function P.Refresh()
    ns.After("discoveryPinsRefresh",P.Rebuild,0.25)
end
function P.Create()
    if P.hooked or not Minimap then return end
    P.hooked=true;Minimap:HookScript("OnShow",P.Refresh);Minimap:HookScript("OnHide",P.Stop);P.Refresh()
end
ns.Listen("STATE_CHANGED",function(kind) if ns.Changed(kind,"inventory","quests","identity","journey","books") then P.Refresh() end end)
ns.Listen("SETTINGS_CHANGED",P.Refresh)
ns.On("MINIMAP_UPDATE_ZOOM",P.Pulse)
ns.On("ZONE_CHANGED",P.Refresh)
