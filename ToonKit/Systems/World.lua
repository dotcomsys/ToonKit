local addonName, ns = ...

local W={ mapNames={}, pins={}, notices={} }; ns.World=W

function W.MapForZone(zone)

    if type(zone)~="string" or zone=="" then return end
    if W.mapNames[zone] then return W.mapNames[zone] end
    local function insensitive()
        local wanted=zone:lower()
        for name,id in pairs(W.mapNames) do if name:lower()==wanted then return id end end
    end
    local cached=insensitive()
    if cached then return cached end

    if not C_Map or not C_Map.GetMapChildrenInfo then return end

    local function scan(root)

        for _,m in ipairs(ns.API.Call("C_Map","GetMapChildrenInfo",root,nil,true) or {}) do W.mapNames[m.name]=m.mapID end

    end

    local current=ns.API.Call("C_Map","GetBestMapForUnit","player")

    if current then

        local root=current; local visited={}

        while root and not visited[root] do

            visited[root]=true

            local m=ns.API.Call("C_Map","GetMapInfo",root)

            if not m then break end

            W.mapNames[m.name]=m.mapID

            if not m.parentMapID or m.parentMapID==0 then break end

            root=m.parentMapID

        end

        scan(root)

    end

    return W.mapNames[zone] or insensitive()

end

function W.Records()

    local all={}

    for _,r in ipairs(ns.Data.collections) do all[#all+1]=r end

    if ns.char then for _,r in pairs(ns.char.personalDiscoveries) do all[#all+1]=r end end

    table.sort(all,function(a,b) return a.name<b.name end); return all

end

function W.Status(record)

    if record.quest and ns.API.QuestDone(record.quest) then return "donated" end

    local recorded=ns.char.collections[record.id]
    if recorded=="donated" then return recorded end

    if record.item and (ns.State.owned[record.item] or 0)>0 then return "collected" end

    return recorded

end

function W.StatusLabel(record)

    local status=W.Status(record)

    return ({donated="Donated",collected="Collected",read="Read in game",manual="Marked found by you"})[status] or (status and "Found" or "Not found")

end

function W.Sync()

    if not ns.char then return end

    for _,r in ipairs(ns.Data.collections) do

        if r.quest and ns.API.QuestDone(r.quest) then ns.char.collections[r.id]="donated"

        elseif r.item and (ns.State.owned[r.item] or 0)>0 then

            if ns.char.collections[r.id]~="donated" then ns.char.collections[r.id]="collected" end

        end

        if not ns.char.collections[r.id] then

            for id,p in pairs(ns.char.personalDiscoveries) do

                if p.name==r.name and ns.char.collections[id]=="read" then ns.char.collections[r.id]="read"; break end

            end

        end

    end

end

function W.Locations(record)

    if record.referenceOnly then return {} end

    if record.locations and #record.locations>0 then return record.locations end

    if record.map and record.x and record.y then return {{map=record.map,x=record.x,y=record.y}} end

    return {}

end

function W.Waypoint(record,location)

    local p=location or W.Locations(record)[1]

    if p then ns.API.MapPoint(p.map,p.x,p.y) else ns.Message("This record has no sourced waypoint.") end

end

function W.Mark(record)

    local status=W.Status(record)

    if status and status~="manual" then ns.Message("This record has automatic collection evidence."); return end

    if status then ns.char.collections[record.id]=nil else ns.char.collections[record.id]="manual" end

    ns.Emit("STATE_CHANGED")

end

function W.Capture()

    if not ns.char or not ns.db.settings.collections then return end

    local title=type(ItemTextGetItem)=="function" and ns.Safe(ItemTextGetItem())

    if not title or title=="" then return end

    for _,r in ipairs(ns.Data.collections) do

        local item=r.item and ns.API.Item(r.item)

        if r.name==title or item and item.name==title then

            if not W.Status(r) then ns.char.collections[r.id]="read" end

            ns.Emit("STATE_CHANGED"); return

        end

    end

    local map,x,y=ns.API.Position()

    -- Reading confirms interaction. Player coordinates are observed location, not surveyed object coordinates.

    local id="read:"..title..":"..tostring(map or 0)

    ns.char.personalDiscoveries[id]={id=id,name=title,map=map,x=x,y=y,source="Read in this client; marker records player position",observed=true}

    ns.char.collections[id]="read"; W.latest=id

    ns.Emit("STATE_CHANGED")

end

function W.Register(name)

    if not ns.char or type(name)~="string" then return end
    name=name:match("^%s*(.-)%s*$")
    if name=="" then ns.Message("Enter a discovery title.");return end

    local map,x,y=ns.API.Position()
    if not map or type(x)~="number" or type(y)~="number" then ns.Message("Current map location is unavailable."); return end

    local id="note:"..name..":"..map

    ns.char.personalDiscoveries[id]={id=id,name=name,map=map,x=x,y=y,source="Player-recorded location",observed=true}

    ns.Emit("STATE_CHANGED","books")
    return true

end

function W.DrawPins()

    for _,p in ipairs(W.pins) do p:Hide() end

    if not ns.char or not ns.db.settings.mapPins then return end

    local mapFrame=WorldMapFrame

    local canvas=mapFrame and mapFrame.GetCanvas and mapFrame:GetCanvas()

    if not canvas or not mapFrame:IsShown() then return end

    local map=mapFrame:GetMapID(); local n=0
    local at={};local questContacts={}
    local workspace=ns.MapWorkspace
    local stitched=workspace and workspace.Stitched()
    if stitched and (not ns.db.settings.openMapIntegration or not workspace.Supported()) then return end
    local function project(point,target) return workspace and workspace.Project(point,target) or ns.Travel.Project(point,target) end

    local function pin(name,source,p,icon,callback,contact)

        if not p.x or not p.y then return end
        local x,y
        if workspace then x,y=workspace.CanvasPoint(p,map)
        elseif p.map==map then x,y=p.x,p.y end
        if type(x)~="number" or type(y)~="number" then return end
        local key=string.format("%.4f:%.4f",x,y)
        local entry={title=name,source=source or "",action=callback,icon=icon}
        local existing=at[key]
        if contact and not existing then
            for _,prior in ipairs(questContacts) do
                if contact==prior.phase and (x-prior.x)^2+(y-prior.y)^2<=.0025^2 then
                    existing=prior.button;break
                end
            end
        end
        if existing then existing.entries[#existing.entries+1]=entry;return true end

        n=n+1; local button=W.pins[n]

        if not button then

            button=CreateFrame("Button",nil,canvas); button:SetSize(20,20)

            button.icon=button:CreateTexture(nil,"ARTWORK"); button.icon:SetAllPoints()

            button:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(self.title)
                GameTooltip:AddLine(self.source,1,.82,.4,true)
                if #self.entries>1 then
                    for i=1,math.min(8,#self.entries) do GameTooltip:AddLine(self.entries[i].title,.85,.85,.75,true) end
                    if #self.entries>8 then GameTooltip:AddLine((#self.entries-8).." more at this location.",.85,.85,.75) end
                    GameTooltip:AddLine("Right-click: cycle markers. Left-click: selected destination.",1,.82,.4,true)
                end
                GameTooltip:Show()
            end)

            button:SetScript("OnLeave",function() GameTooltip:Hide() end)

            button:RegisterForClicks("LeftButtonUp","RightButtonUp")
            button:SetScript("OnClick",function(self,mouse)
                if mouse=="RightButton" and #self.entries>1 then
                    self.entryIndex=self.entryIndex%#self.entries+1;local selected=self.entries[self.entryIndex]
                    self.title=selected.title;self.source=selected.source;self.action=selected.action;self.icon:SetTexture(selected.icon)
                    self:GetScript("OnEnter")(self)
                elseif mouse=="LeftButton" then self.action() end
            end)

            W.pins[n]=button

        end

        button.title=name; button.source=source or ""; button.action=callback; button.icon:SetTexture(icon)
        button.entries={entry};button.entryIndex=1;at[key]=button
        if contact then questContacts[#questContacts+1]={phase=contact,x=x,y=y,button=button} end
        local level=canvas:GetFrameLevel()+10
        if stitched then local art=ns.Safe(workspace.Provider().ArtTopLevel());if type(art)=="number" then level=math.max(level,art+10) end end
        button:SetFrameLevel(level)

        button:ClearAllPoints(); button:SetPoint("CENTER",canvas,"TOPLEFT",x*canvas:GetWidth(),-y*canvas:GetHeight()); button:Show()
        return true

    end

    for _,waypoint in ipairs(ns.char.manualWaypoints or {}) do
        local point=stitched and waypoint or project(waypoint,map)
        if point then
            pin(waypoint.label or "Saved waypoint","Click to follow this waypoint.",point,
                "Interface\\Icons\\INV_Misc_Map_01",function() ns.Navigation.SelectWaypoint(waypoint) end)
        end
    end

    if ns.db.settings.modules.world and ns.db.settings.mapBookPins~=false then

        for _,r in ipairs(W.Records()) do if not W.Status(r) then

            for _,p in ipairs(W.Locations(r)) do local point=p; pin(r.name,r.source,p,"Interface\\Icons\\INV_Misc_Book_09",function() W.Waypoint(r,point) end) end

        end end

    end

    if ns.Travel and ns.db.settings.mapTransportPins~=false then

        for _,r in ipairs(ns.Travel.Markers()) do if not r.faction or r.faction==ns.State.faction then

            local point=project(r,map)

            if point then local p=point;pin(r.name,r.description~="" and r.description or "Source-listed transport boarding location",p,"Interface\\Icons\\INV_Misc_Map_01",function() ns.API.MapPoint(p.map,p.x,p.y) end) end

        end end


    end

    if ns.db.settings.modules.gear and ns.db.settings.gearHuntPins~=false and ns.Gear.HuntMarkers then
        for _,record in ipairs(ns.Gear.HuntMarkers()) do
            local marker=record;local point=project(marker,map)
            if point then
                local p=point
                pin(marker.name,(marker.active and "Following this hunt. " or "Tracked hunt. ")..(marker.source or "Recorded source")..
                    (marker.reference and " Availability unconfirmed." or "")..(marker.blocked and " "..tostring(marker.blocked) or "")..
                    " Click: waypoint. Shift-click: hunt details.",p,"Interface\\Icons\\INV_Misc_Coin_01",function()
                        if type(IsShiftKeyDown)=="function" and IsShiftKeyDown() then
                            ns.Main.OpenHunt(marker.id)
                        else ns.API.MapPoint(p.map,p.x,p.y) end
                    end)
            end
        end
    end

    if ns.db.settings.modules.dungeons and ns.db.settings.mapDungeonPins~=false then

        for _,d in ipairs(ns.Data.journals or {}) do if d.entrance then

            local point=project(d.entrance,map)

            if point then local p=point;pin(d.name,"Dungeon entrance. Source-listed level range "..(d.min or "?").."-"..(d.max or "?")..".",p,"Interface\\LFGFrame\\LFGIcon-Dungeon",function() ns.API.MapPoint(p.map,p.x,p.y) end) end

        end end

    end

    if ns.db.settings.modules.journey and ns.Journey then

        local markers=ns.QuestMarkers
        local native={}
        if map and not stitched then
            local pois=ns.Safe(ns.API.Call("C_QuestLog","GetQuestsOnMap",map))
            if type(pois)=="table" then
                for _,poi in ipairs(pois) do
                    local id,x,y=ns.Safe(poi.questID),ns.Safe(poi.x),ns.Safe(poi.y)
                    if type(id)=="number" and type(x)=="number" and type(y)=="number" then
                        native[id]={map=map,x=x,y=y}
                    end
                end
            end
        end
        local function covered(goal,point)
            local existing=goal.t=="turnin" and native[goal.quest]
            return existing and markers.NearContact(existing,point)
        end
        local goal,step=ns.Journey.Action()
        local point=goal and (goal.t=="accept" and markers.PickupEligible(goal) or goal.t~="accept" and not ns.Journey.Blocked(goal)) and ns.Navigation.Location(goal)
        local guidePoint=point and (stitched and point or project(point,map))
        local guideShown
        if guidePoint and ns.db.settings.mapGuidePins~=false and not covered(goal,guidePoint) then
            local title=point.connection and "Travel via "..(point.label or ns.Journey.GoalText(goal)) or ns.Journey.GoalText(goal)
            guideShown=pin(title,"Next route action",guidePoint,markers.Icon(goal),
                function() ns.Journey.GoalWaypoint(goal) end,markers.Contact(goal) and goal.t)
        end
        if goal and not ns.char.journeyPaused and ns.db.settings.mapGuidePins~=false then
            local count=0
            for _,action in ipairs(step and step.goals or {}) do
                if action.t=="accept" or action.t=="turnin" then
                    local eligible=action.t=="accept" and markers.PickupEligible(action)
                        or action.t=="turnin" and ns.Journey.ReadyToTurnIn(action.quest) and not ns.Journey.Blocked(action)
                    local location=eligible and ns.Journey.Applies(action.only) and ns.Navigation.FinalLocation(action)
                    local p=location and (stitched and location or project(location,map))
                    if p and not covered(action,p) and not (action==goal and guideShown and markers.NearContact(guidePoint,p)) then
                        local text=action.npcName and "Speak with "..action.npcName or "Quest contact in the current route group"
                        pin(ns.Journey.GoalText(action),text,p,markers.Icon(action),function()
                            ns.Navigation.ShowDestination(location)
                        end,action.t)
                        count=count+1
                        if count>=8 then break end
                    end
                end
            end
        end
        for _,marker in ipairs(markers.Markers(map,stitched)) do
            local action=marker.goal
            local sameGuide=guideShown and markers.Contact(action) and goal.quest==action.quest
                and goal.t==action.t and markers.NearContact(guidePoint,marker.point)
            if not sameGuide and not covered(action,marker.point) then
                pin(marker.name,marker.source.." Click: waypoint.",marker.point,marker.icon,function() ns.API.MapPoint(marker.point.map,marker.point.x,marker.point.y) end,markers.Contact(action) and action.t)
            end
        end

    end

end

function W.RefreshPins()
    if WorldMapFrame and WorldMapFrame:IsShown() then ns.After("worldMapPins",W.DrawPins,0.25) end
end

function W.Nearby()

    if not ns.char or not ns.db.settings.nearby or not ns.db.settings.modules.world then return end

    local map,x,y=ns.API.Position(); if not map then return end

    for _,r in ipairs(W.Records()) do if not W.Status(r) and not W.notices[r.id] then

        for _,p in ipairs(W.Locations(r)) do

            if p.map==map and (x-p.x)^2+(y-p.y)^2<.0004 then

                W.notices[r.id]=true; ns.Message("Discovery in this map area: "..r.name); break

            end

        end

    end end

end

ns.On("ITEM_TEXT_READY",W.Capture)

ns.On("ZONE_CHANGED_NEW_AREA",W.Nearby)

ns.On("PLAYER_STOPPED_MOVING",W.Nearby)

ns.Listen("STATE_CHANGED",function(kind)
    if ns.Changed(kind,"inventory","quests","identity","books") then W.Sync() end
    if ns.Changed(kind,"inventory","quests","identity","journey","books","talents") then W.RefreshPins() end
end)
ns.Listen("SETTINGS_CHANGED",W.RefreshPins)


-- Disputed source identities enter this character's discoveries only on native evidence.
local function discoveredBooks()
    if not ns.char then return end
    for quest,item in pairs({[79953]=215824,[81951]=220347}) do
        if ns.API.QuestDone(quest) then
            local key="library:"..item
            local info=ns.API.Item(item)
            ns.char.personalDiscoveries[key]={id=key,item=item,quest=quest,name=info and info.name or ns.Safe(ns.API.Call("C_QuestLog","GetTitleForQuestID",quest),"Native confirmed library donation"),source="This character's native completed quest",referenceOnly=true,availability="native-character-confirmed"}
        end
    end
end
ns.On("PLAYER_LOGIN",function() ns.After("nativeLibraryDiscoveries",discoveredBooks) end)
ns.On("QUEST_TURNED_IN",function(id) if id==79953 or id==81951 then ns.After("nativeLibraryDiscoveries",function() discoveredBooks();ns.Emit("STATE_CHANGED") end) end end)
