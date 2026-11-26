local addonName, ns = ...
local N={}; ns.Navigation=N
local function validPoint(p)
    return type(p)=="table" and type(ns.Safe(p.map))=="number" and p.map>0 and type(ns.Safe(p.x))=="number" and type(ns.Safe(p.y))=="number"
        and p.x>=0 and p.x<=1 and p.y>=0 and p.y<=1
end
function N.QuestLocation(id)
    local map,x,y=ns.API.Call("C_QuestLog","GetNextWaypoint",id)
    local point={map=ns.Safe(map),x=ns.Safe(x),y=ns.Safe(y),native=true}
    if validPoint(point) then return point end
    map=ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"))
    if type(map)=="number" and map>0 then
        x,y=ns.API.Call("C_QuestLog","GetNextWaypointForMap",id,map)
        point={map=map,x=ns.Safe(x),y=ns.Safe(y),native=true}
        if validPoint(point) then return point end
        local pois=ns.Safe(ns.API.Call("C_QuestLog","GetQuestsOnMap",map))
        if type(pois)=="table" then
            for _,poi in ipairs(pois) do
                if ns.Safe(poi.questID)==id then
                    point={map=map,x=ns.Safe(poi.x),y=ns.Safe(poi.y),native=true}
                    if validPoint(point) then return point end
                end
            end
        end
    end
end
function N.FinalLocation(goal)
    if not goal or goal.t=="hearth" then return end
    -- An en-route collection may point at its next handoff, explicitly labeled
    -- in the task. This is a travel destination, never a claimed mob position.
    if validPoint(goal.enrouteDestination) then
        local p=goal.enrouteDestination
        return {map=p.map,x=p.x,y=p.y,handoff=true}
    end
    -- A ready quest's native return marker takes precedence over old source
    -- contacts. Collection objectives still need their own identity/location.
    if goal.t=="turnin" and goal.quest and ns.Journey.ReadyToTurnIn(goal.quest) then
        local point=N.QuestLocation(goal.quest)
        if point then return point end
    end
    local map,x,y=ns.API.Position();local points={};local signatures={tostring(goal.id),tostring(map),tostring(ns.State.class),tostring(ns.State.raceToken),tostring(ns.State.faction)}
    if validPoint(goal) then points[#points+1]=goal end
    if not goal.fixedNavigation then for _,p in ipairs(goal.locations or {}) do
        if ns.Journey.Applies(p.only) and validPoint(p) then points[#points+1]=p end
    end end
    for _,p in ipairs(points) do signatures[#signatures+1]=p.map..":"..p.x..":"..p.y end
    local key=table.concat(signatures,"|")
    if #points>0 then
        if N.targetCache and N.targetCache.key==key then return N.targetCache.point end
        local best,distance
        for _,p in ipairs(points) do
            local d=map==p.map and type(x)=="number" and type(y)=="number" and ((p.x-x)^2+(p.y-y)^2) or math.huge
            if not best or d<distance then best,distance=p,d end
        end
        N.targetCache={key=key,point=best};return best
    end
    N.targetCache=nil
    if ns.Travel and (goal.t=="fly" or goal.t=="getfp") then local p=ns.Travel.Point(goal);if p then return p end end
    -- Quest-wide POIs can refer to another objective.
    if goal.nativeQuestNavigation and goal.t~="turnin" and goal.quest and ns.Journey.OnQuest(goal.quest) then
        return N.QuestLocation(goal.quest)
    end
end
function N.Destination(goal)
    if goal.quest and goal.t~="accept" and not goal.direct then
        if not ns.Journey.OnQuest(goal.quest) then return end
        -- A quest-wide POI may refer to a different objective in this quest.
        return N.FinalLocation(goal) or N.QuestLocation(goal.quest)
    end
    return N.FinalLocation(goal)
end
function N.Location(goal)
    local destination=N.Destination(goal)
    if not destination then return end
    local current=ns.API.Position()
    local kind=goal.t
    if not ns.Travel or not current or current==destination.map or kind=="fly" or kind=="boat"
        or kind=="zeppelin" or kind=="portal" then return destination end
    local directions=ns.Travel.Directions(destination,current)
    if directions then
        local departure=directions.kind~="hearth" and validPoint(directions.point) and directions.point.map==current
        if departure then return directions.point,directions.text end
        return destination,directions.text
    end
    return ns.Travel.Connection(destination,goal)
end
local function activePoint()
    if ns.char and validPoint(ns.char.customWaypoint) then return ns.char.customWaypoint end
    if ns.Guide and ns.Guide:IsShown() and ns.db.settings.guide and ns.db.settings.guideArrow
        and ns.db.settings.modules.journey then return N.point end
end
local function navigationText(f,text)
    if f.lastNavigationText==text then return end
    f.lastNavigationText=text
    f.navigation:SetText(text);f.navigation:SetHeight(0)
    local height=math.max(18,f.navigation:GetStringHeight()+4)
    f.navigation:SetHeight(height);f:SetHeight(74+height)
end
function N.Display()
    if N.frame then return N.frame end
    if not ns.UI or not ns.db then return end
    local f=CreateFrame("Frame",nil,UIParent);N.frame=f
    f:SetSize(320,108);f:SetPoint("TOP",UIParent,"TOP",0,-120);f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton");f:SetFrameStrata("MEDIUM")
    local p=ns.db.settings.positions.navigation
    if p then f:ClearAllPoints();f:SetPoint(p.point,UIParent,p.relative,p.x,p.y) end
    f:SetScript("OnDragStart",function(self) if not ns.db.settings.locked then self:StartMoving() end end)
    f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing();local point,_,relative,x,y=self:GetPoint();ns.db.settings.positions.navigation={point=point,relative=relative,x=x,y=y} end)
    f.arrow=f:CreateTexture(nil,"ARTWORK");f.arrow:SetSize(48,48);f.arrow:SetPoint("TOP",0,0);f.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    f.arrowCaption=ns.UI.Label(f,"",0,0,320,"GameFontHighlightSmall");f.arrowCaption:ClearAllPoints();f.arrowCaption:SetPoint("TOP",0,-51);f.arrowCaption:SetJustifyH("CENTER")
    f.navigation=ns.UI.Label(f,"",0,0,320,"GameFontNormal");f.navigation:ClearAllPoints();f.navigation:SetPoint("TOP",0,-72);f.navigation:SetJustifyH("CENTER")
    ns.UI.Tooltip(f,"Journey navigation",{"Drag to move independently of the field guide. Position locks follow Appearance settings.","Arrow points toward the map destination; it does not establish a walkable path."})
    return f
end
function N.Pulse()
    if ns.Travel and ns.Travel.ObserveCrossing and N.moving~=false then
        local now=GetTime()
        if not N.crossingAt or now-N.crossingAt>=.25 then N.crossingAt=now;ns.Travel.ObserveCrossing() end
    end
    local f=N.Display();local p=activePoint()
    if not f then return end
    f:SetShown(p~=nil)
    if not p then return end
    f.arrow:Hide()
    f.arrowCaption:SetText("")
    if N.displayMap~=p.map or not N.displayMapInfo or not N.displayMapWidth or not N.displayMapHeight then
        N.displayMap=p.map;N.displayMapInfo=ns.API.Call("C_Map","GetMapInfo",p.map)
        N.displayMapWidth,N.displayMapHeight=ns.API.Call("C_Map","GetMapWorldSize",p.map)
        N.displayMapWidth,N.displayMapHeight=ns.Safe(N.displayMapWidth),ns.Safe(N.displayMapHeight)
    end
    local info=N.displayMapInfo
    local text=(p==ns.char.customWaypoint and ((p.label or "Waypoint")..": ") or p.connection and "Via: " or p.handoff and "Travel handoff: " or p.native and "Quest area: " or "")..(info and ns.Safe(info.name) or "Map #"..p.map)..string.format("  %.1f, %.1f",p.x*100,p.y*100)
    local pos=ns.Safe(ns.API.Call("C_Map","GetPlayerMapPosition",p.map,"player"))
    local x,y
    if pos then x,y=pos:GetXY();x,y=ns.Safe(x),ns.Safe(y) end
    local map=p.map
    if x and y and x>=0 and x<=1 and y>=0 and y<=1 then
        local dx,dy=p.x-x,p.y-y
        local w,h=N.displayMapWidth,N.displayMapHeight
        if w and h and w>0 and h>0 then
            local yards=math.sqrt((dx*w)^2+(dy*h)^2)
            local directions={"N","NE","E","SE","S","SW","W","NW"}
            local direction=directions[(math.floor(math.atan2(dx*w,-dy*h)*4/math.pi+.5)%8)+1]
            text=math.floor(yards+.5).." yd  "..direction.." on map  |  "..text
            if f.arrow then
                local facing=type(GetPlayerFacing)=="function" and ns.Safe(GetPlayerFacing())
                local bearing=math.atan2(-dx*w,-dy*h)
                f.arrow:SetRotation(bearing-(facing or 0));f.arrow:Show()
                f.arrow:SetVertexColor(yards<12 and .25 or 1,yards<12 and 1 or .8,.25,1)
                if f.arrowCaption then f.arrowCaption:SetText(facing and "Facing" or "Map north") end
            end
        end
    end
    navigationText(f,text)
end
function N.Stop()
    if N.ticker then N.ticker:Cancel(); N.ticker=nil end
end
function N.UpdateTicker()
    if not activePoint() then N.Stop();return end
    if not N.ticker and C_Timer.NewTicker then N.ticker=C_Timer.NewTicker(.1,N.Pulse) end
end
local function matchesWaypoint(pin,point)
    if type(pin)~="table" or not point or ns.Safe(pin.uiMapID)~=point.map then return false end
    local position=ns.Safe(pin.position)
    if not position or type(position.GetXY)~="function" then return false end
    local x,y=position:GetXY();x,y=ns.Safe(x),ns.Safe(y)
    return type(x)=="number" and type(y)=="number" and math.abs(x-point.x)<.00001 and math.abs(y-point.y)<.00001
end
function N.ShowDestination(point)
    local pin=ns.Safe(ns.API.Call("C_Map","GetUserWaypoint"))
    if C_Map and type(C_Map.GetUserWaypoint)=="function" and (not pin or matchesWaypoint(pin,N.guidePin)) then
        if ns.API.MapPoint(point.map,point.x,point.y,true) then
            N.guidePin={map=point.map,x=point.x,y=point.y,goal=N.goal and N.goal.id};return true
        end
    end
    return ns.API.OpenMap(point.map)
end
function N.Refresh()
    if not ns.char then return end
    local goal=ns.Journey.Action();N.goal=goal
    if N.manualPin and N.manualPin~=ns.char.customWaypoint then
        if matchesWaypoint(ns.Safe(ns.API.Call("C_Map","GetUserWaypoint")),N.manualPin) and C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
        N.manualPin=nil
    end
    if N.guidePin and N.guidePin.goal~=(goal and goal.id) then
        if matchesWaypoint(ns.Safe(ns.API.Call("C_Map","GetUserWaypoint")),N.guidePin) and C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
        N.guidePin=nil
    end
    -- A taxi arrival point is useful on the map, but it is not a walking target.
    N.point=not ns.char.journeyPaused and goal and goal.t~="fly"
        and not ns.Journey.Blocked(goal) and N.Location(goal) or nil
    N.Pulse();N.UpdateTicker()
end
ns.On("PLAYER_STARTED_MOVING",function() N.moving=true; N.Refresh() end)
ns.On("PLAYER_STOPPED_MOVING",function() N.moving=false; N.Pulse(); N.UpdateTicker() end)
ns.Listen("STATE_CHANGED",function(kind)
    if ns.Changed(kind,"inventory","quests","identity","talents","journey") then ns.After("navigationRefresh",N.Refresh) end
end)
ns.Listen("SETTINGS_CHANGED",function() ns.After("navigationRefresh",N.Refresh) end)
ns.On("PLAYER_ENTERING_WORLD",function() N.displayMap=nil;N.displayMapInfo=nil end)

local function selectWaypoint(point)
    ns.char.customWaypoint=point;ns.char.questFocus=nil
    if point and C_Map and type(C_Map.GetUserWaypoint)=="function" then
        local pin=ns.Safe(ns.API.Call("C_Map","GetUserWaypoint"))
        if not pin or matchesWaypoint(pin,N.manualPin) or matchesWaypoint(pin,N.guidePin) then
            if ns.API.MapPoint(point.map,point.x,point.y,false) then N.manualPin=point end
        end
    end
    N.Refresh()
    ns.Emit("STATE_CHANGED","journey")
end
function N.SelectWaypoint(point)
    if validPoint(point) then selectWaypoint(point) end
end
local function selected(point)
    local current=ns.char.customWaypoint
    return current==point or current and point.waypointID and current.waypointID==point.waypointID
end
local function waypointCommand(message)
    if not ns.char then return end
    message=message:match("^%s*(.-)%s*$")
    local command=message:lower()
    local points=ns.char.manualWaypoints or {}
    ns.char.manualWaypoints=points
    if command=="closest" then
        local map,x,y=ns.API.Position()
        local closest,distance
        if type(x)=="number" and type(y)=="number" then
            for _,point in ipairs(points) do
                if validPoint(point) and point.map==map then
                    local delta=(point.x-x)^2+(point.y-y)^2
                    if not distance or delta<distance then closest,distance=point,delta end
                end
            end
        end
        if closest then selectWaypoint(closest) else ns.Message("No saved waypoint in your current zone.") end
        return
    end
    if command=="clear" or command=="reset" or command=="reset all" then
        for index=#points,1,-1 do
            if command=="reset all" or selected(points[index]) then table.remove(points,index) end
        end
        selectWaypoint(nil)
        ns.Message(command=="reset all" and "Cleared all saved waypoints." or "Cleared the active waypoint.")
        return
    end
    if command=="next" or command=="list" then
        if #points==0 then ns.Message("No saved waypoints.");return end
        if command=="next" then
            local index=0
            for i,point in ipairs(points) do
                if selected(point) then index=i;break end
            end
            selectWaypoint(points[index%#points+1])
        else
            for i,point in ipairs(points) do
                local info=ns.API.Call("C_Map","GetMapInfo",point.map)
                ns.Message(string.format("%d. %s %.1f %.1f %s%s",i,info and ns.Safe(info.name) or "Map #"..point.map,
                    point.x*100,point.y*100,point.label or "",selected(point) and " (active)" or ""))
            end
        end
        return
    end
    local coords="(%d+%.?%d*)%s*[, ]%s*(%d+%.?%d*)"
    local function coordinates(input)
        local x,y,label=input:match("^"..coords.."%s+(.+)$")
        if not x then x,y=input:match("^"..coords.."$") end
        return x,y,label
    end
    local first,remainder=message:match("^(%d+)%s+(.+)$")
    local numericMap=first and tonumber(first)>100 and tonumber(first) or nil
    local x,y,label=coordinates(numericMap and remainder or message)
    local zone,map
    if x then
        map=numericMap or ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"))
    else
        local remaining
        zone,remaining=message:match("^(.-)%s+(%d.*)$")
        if zone then
            x,y,label=coordinates(remaining)
            map=tonumber(zone:match("^#(%d+)$")) or ns.World.MapForZone(zone)
        end
    end
    if not x then
        ns.Message("Use /tkway 45.2 61.8 Label, /tkway Zone Name 45.2 61.8 Label, or /tkway #1446 45.2 61.8 Label. Commands: list, next, closest, reset, reset all.")
        return
    end
    local point={map=map,x=tonumber(x)/100,y=tonumber(y)/100}
    if not validPoint(point) then
        ns.Message("Use a known zone name or map ID and coordinates from 0 to 100.")
        return
    end
    local info=ns.API.Call("C_Map","GetMapInfo",map)
    if not info then
        ns.Message("No map found for that waypoint.")
        return
    end
    point.label=label and label:gsub("|",""):sub(1,80)
    ns.char.manualWaypointSerial=(ns.char.manualWaypointSerial or 0)+1
    point.waypointID=ns.char.manualWaypointSerial
    if #points>=50 then table.remove(points,1) end
    points[#points+1]=point
    selectWaypoint(point)
    ns.Message(string.format("Waypoint set in %s at %.1f, %.1f.",ns.Safe(info.name,"Map #"..map),point.x*100,point.y*100))
end
local function registerWaypointCommand()
    SLASH_TOONKITWAY1="/tkway"
    SlashCmdList.TOONKITWAY=waypointCommand
end
ns.On("PLAYER_LOGIN",registerWaypointCommand)

ns.On("QUEST_POI_UPDATE",function() ns.After("navigationRefresh",N.Refresh,0.25) end)
