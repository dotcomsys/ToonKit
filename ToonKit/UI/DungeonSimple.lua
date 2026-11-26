local addonName, ns = ...
local M,U,D,C=ns.Main,ns.UI,ns.Journal,ns.Connected
local V={maps={},preloaded={}};ns.DungeonView=V
local function section(text)
    M.y=M.y-10;M.Line(text,"GameFontNormal")
end
local footer=C.Footer
local function prerequisites(q)
    if q.prerequisites or q.needsId then return q.prerequisites or {q.needsId},{} end
    local meta=ns.Data.questSupport and ns.Data.questSupport.meta[q.id]
    return meta and meta.preAll or {},meta and meta.pre or {},meta and meta.parent
end
local function questBadges(q)
    local faction,classes,meta=D.QuestRestrictions(q)
    local icons,names={},{}
    if faction then
        names[#names+1]=faction=="alliance" and "Alliance" or "Horde"
        local atlas="communities-icon-faction-"..faction
        if ns.API.Call("C_Texture","GetAtlasInfo",atlas) then
            icons[#icons+1]={atlas=atlas}
        else
            icons[#icons+1]={texture="Interface\\PVPFrame\\PVP-Currency-"..names[#names]}
        end
    end
    for _,class in ipairs(classes) do
        local name=LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
        names[#names+1]=name
        local coords=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
        local atlas="classicon-"..class:lower()
        if ns.API.Call("C_Texture","GetAtlasInfo",atlas) then
            icons[#icons+1]={atlas=atlas}
        elseif coords then
            icons[#icons+1]={texture="Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes",coords=coords}
        else icons[#icons+1]={texture="Interface\\Icons\\ClassIcon_"..class} end
    end
    local races=meta and meta.races
    if type(races)=="number" and races>0 and not ns.Rules.QuestFaction(races) then
        for id=1,32 do
            if ns.Rules.MaskAllows(races,id) then
                local info=ns.API.Call("C_CreatureInfo","GetRaceInfo",id)
                local name=type(info)=="table" and ns.Safe(info.raceName)
                if type(name)=="string" then names[#names+1]=name end
            end
        end
    end
    return icons,table.concat(names," · ")
end
local questGroups={
    {name="Turn in",icon="Interface\\GossipFrame\\ActiveQuestIcon"},
    {name="In progress",icon="Interface\\GossipFrame\\ActiveQuestIcon"},
    {name="Pick up",icon="Interface\\GossipFrame\\AvailableQuestIcon"},
    {name="Locked",icon="Interface\\GossipFrame\\UnavailableQuestIcon"},
    {name="Completed",icon="Interface\\Buttons\\UI-CheckBox-Check"},
    {name="Other characters",icon="Interface\\GossipFrame\\UnavailableQuestIcon"},
}
local function questState(q)
    local allowed,reason=D.QuestAccess(q)
    if not allowed then return 6,reason end
    if ns.Journey.QuestDone(q.id) then return 5 end
    if ns.Journey.OnQuest(q.id) then
        return ns.Journey.ReadyToTurnIn(q.id) and 1 or 2
    end
    if q.req and q.req>ns.State.level then return 4,"Requires level "..q.req end
    local all,any,parent=prerequisites(q)
    if parent and not ns.Journey.OnQuest(parent) then return 4,"Parent quest must be in your log" end
    for _,id in ipairs(all) do if not ns.Journey.QuestDone(id) then return 4,"Prerequisite required" end end
    if #any>0 then
        for _,id in ipairs(any) do if ns.Journey.QuestDone(id) then return 3 end end
        return 4,"Complete one of the prerequisites"
    end
    return 3
end
local function questLocation(title,npc,point,action)
    local place=point and (point.place or point.zone)
    local text=npc or place or "Location unavailable"
    if npc and place and npc~=place then text=text.."\n"..place end
    section(title)
    if point and point.map and point.x and point.y then
        M.Line(text)
        M.Action(action,function() C.Map(point) end,140)
    else
        M.Line(text)
    end
end
-- Source roots are instance/GameMap IDs. NativeMaps converts them to UIMap
-- roots before group/floor lookup; entrance zones never stand in for interiors.
function V.MapPages(d)
    local current=D.Current and D.Current()
    local floor=current and current.slug==d.slug and ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"))
    if V.mapFloor~=floor then
        V.mapFloor=floor;V.maps={};V.artChecked=false
        if not V.mapChosen and type(floor)=="number" then V.mapID=floor end
    end
    if V.maps[d.slug] then return V.maps[d.slug] end
    local pages,seen={},{}
    local function add(id,name)
        id=ns.Safe(id);if type(id)~="number" or id<=0 or seen[id] then return end
        seen[id]=true;local info=ns.API.Call("C_Map","GetMapInfo",id)
        pages[#pages+1]={id=id,name=type(name)=="string" and name or info and ns.Safe(info.name) or d.name}
    end
    local roots={}
    for _,id in ipairs(D.NativeMaps(d)) do roots[#roots+1]={id=id} end
    for _,root in ipairs(roots) do
        if type(ns.Safe(root.id))=="number" then
        add(root.id,root.name)
        local group=ns.Safe(ns.API.Call("C_Map","GetMapGroupID",root.id))
        local members=group and ns.API.Call("C_Map","GetMapGroupMembersInfo",group)
        if type(members)=="table" and #members>0 then
            local ordered={};for _,member in ipairs(members) do ordered[#ordered+1]=member end
            table.sort(ordered,function(a,b) return (ns.Safe(a.relativeHeightIndex,0))<(ns.Safe(b.relativeHeightIndex,0)) end)
            for _,member in ipairs(ordered) do add(member.mapID,ns.Safe(member.name)) end
        end
        local types=Enum and Enum.UIMapType
        local children=types and ns.API.Call("C_Map","GetMapChildrenInfo",root.id,nil,false)
        if type(children)=="table" then for _,child in ipairs(children) do
            local kind=ns.Safe(child.mapType)
            if #pages<64 and kind and (kind==types.Dungeon or kind==types.Micro) then add(child.mapID,ns.Safe(child.name)) end
        end end
        end
    end
    local minimapFloors=ns.Data.dungeonMinimapFloors
    local mappedInstances={}
    local function addMinimapFloors(id,wingName)
        if type(id)~="number" or mappedInstances[id] then return end
        mappedInstances[id]=true
        local floors=minimapFloors[id] or {}
        for index,floor in ipairs(floors) do
            local uiMapID=floor<1000000 and floor or nil
            local floorArt=ns.Data.dungeonFloorArt[floor]
            if uiMapID and U.MapArtwork(uiMapID) then
                add(uiMapID)
            else
                local label=floorArt and floorArt.name or (#floors>1 and (wingName.." · Floor "..index) or wingName)
                local minimap=ns.Data.dungeonMinimapTiles[floor]
                local tiles=minimap or floorArt and floorArt.tiles
                if tiles then
                    local key="client:"..floor
                    if not seen[key] then
                        seen[key]=true
                        pages[#pages+1]={id=key,name=label,tiles=tiles,floor=floor,
                            minimap=minimap~=nil,nativeFloor=uiMapID}
                    end
                elseif uiMapID and ns.API.Call("C_Map","GetMapInfo",uiMapID) then add(uiMapID) end
            end
        end
    end
    for _,wing in ipairs(d.maps or {}) do addMinimapFloors(wing.instanceID,wing.name or d.name) end
    addMinimapFloors(d.instanceID,d.name)
    for _,boss in ipairs(d.encounters or {}) do addMinimapFloors(boss.instanceID,d.name) end
    if #pages>0 then V.maps[d.slug]=pages end
    return pages
end
local function clientTiles(parent,tiles,width,height)
    local panel=U.Panel(parent,width,height,0,0,"dungeonClientTiles")
    panel.tiles=panel.tiles or {}
    local scale=math.min((width-12)/1002,(height-12)/668)
    local x,y=(width-1002*scale)/2,(height-668*scale)/2
    local loaded=0
    for index,tile in ipairs(tiles) do
        local image=panel.tiles[index] or panel:CreateTexture(nil,"ARTWORK")
        panel.tiles[index]=image
        image:ClearAllPoints()
        image:SetSize(tile[4]*scale,tile[5]*scale)
        image:SetPoint("TOPLEFT",x+tile[2]*scale,-y-tile[3]*scale)
        image:SetDrawLayer("ARTWORK",math.max(-8,math.min(7,tile[14])))
        local applied=image:SetTexture(tile[1],"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE","TRILINEAR")
        image:SetTexCoord(unpack(tile,6,13))
        image:SetShown(applied~=false)
        if applied~=false then loaded=loaded+1 end
    end
    for index=#tiles+1,#panel.tiles do panel.tiles[index]:Hide() end
    panel.mapArea=loaded>0 and {x=x,y=y,width=1002*scale,height=668*scale} or nil
    if loaded<#tiles then
        U.Label(panel,loaded==0 and "The client could not load this floor’s tiles." or "Some map tiles are unavailable in this client.",16,-20,width-32,"GameFontHighlight")
    end
    return panel
end
local function bossMapPins(d,page)
    local function key(name) return name:lower():gsub("[^%w]","") end
    local floor=page.floor or page.id
    local bosses,rows,seen={},{},{}
    for index,boss in ipairs(d.encounters or {}) do
        bosses[key(boss.name)]=index
    end
    local function add(pins,source,keepUnmatched)
        for _,pin in ipairs(pins or {}) do
            local name=key(pin.name)
            if not seen[name] and (bosses[name] or keepUnmatched) then
                seen[name]=true
                rows[#rows+1]={index=bosses[name],name=pin.name,x=pin.x,y=pin.y,source=source}
            end
        end
    end
    -- Client minimap mosaics use the pinned floor's coordinate space.
    local native=page.nativeFloor or (not page.tiles and page.id)
    if native and not page.minimap then add(D.NativeMapEncounters(native),"Native encounter location") end
    add((ns.Data.dungeonBossPins or {})[floor],"Source-listed Forever boss location",true)
    return rows
end
local function mapView(d,top,height)
    local pages=V.MapPages(d);local lookup,rows={},{}
    for _,page in ipairs(pages) do
        lookup[page.id]=page;rows[#rows+1]={value=page.id,label=page.name,icon="Interface\\Icons\\INV_Misc_Map_01"}
    end
    local selected=lookup[V.mapID] or pages[1]
    if selected and not V.mapChosen and not V.artChecked then
        V.artChecked=true
        if not selected.tiles and not U.MapArtwork(selected.id) then
            for _,page in ipairs(pages) do if page.tiles or U.MapArtwork(page.id) then selected=page;break end end
        end
    end
    V.mapID=selected and selected.id
    local leftWidth=214
    local left=C.Pane(M.body,leftWidth,height,8,top,"dungeonFloors")
    left.scroll:ClearAllPoints();left.scroll:SetPoint("TOPLEFT",12,-42);left.scroll:SetPoint("BOTTOMRIGHT",-30,12)
    U.Label(left,"Dungeon maps",12,-12,leftWidth-40,"GameFontNormal")
    if left.context~=d.slug then left.scroll:SetVerticalScroll(0);left.context=d.slug end
    C.JournalList(left,rows,V.mapID,function(id) V.mapID=id;V.mapChosen=true;V.zoom=1;V.panX=0;V.panY=0;M.Render() end)
    local panel=U.Panel(M.body,M.width-leftWidth-24,height,leftWidth+16,top,"dungeonMapPanel")
    U.Label(panel,selected and selected.name or d.name,16,-14,panel:GetWidth()-225,"GameFontNormalLarge")
    local function zoom(delta)
        V.zoom=math.max(1,math.min(3,(V.zoom or 1)+delta));M.Render()
    end
    local minus=U.Button(panel,"-",28,function() zoom(-.25) end);minus:SetPoint("TOPRIGHT",-111,-10)
    local plus=U.Button(panel,"+",28,function() zoom(.25) end);plus:SetPoint("TOPRIGHT",-77,-10)
    local fit=U.Button(panel,"Fit",55,function() V.zoom=1;V.panX=0;V.panY=0;M.Render() end);fit:SetPoint("TOPRIGHT",-16,-10)
    local viewport=U.New("ScrollFrame",panel,nil,"dungeonMapViewport")
    viewport:SetPoint("TOPLEFT",12,-47);viewport:SetPoint("BOTTOMRIGHT",-12,50)
    viewport:EnableMouse(true);viewport:EnableMouseWheel(true)
    local vw,vh=panel:GetWidth()-24,height-97
    local factor=V.zoom or 1
    if selected then
        if not selected.tiles and not V.preloaded[selected.id] then
            V.preloaded[selected.id]=true;ns.API.Call("C_Map","RequestPreloadMap",selected.id)
            for attempt=1,2 do local expected=selected.id
                C_Timer.After(attempt*.4,function()
                    if U.main and U.main:IsShown() and M.tab=="Adventure" and M.sub=="Dungeons" and (V.tab or "map")=="map" and V.mapID==expected then V.maps[d.slug]=nil;V.artChecked=false;M.Render() end
                end)
            end
        end
        local art=selected.tiles and clientTiles(viewport,selected.tiles,vw*factor,vh*factor) or U.LocationMap(viewport,selected.id,vw*factor,vh*factor)
        art:ClearAllPoints();viewport:SetScrollChild(art);art:SetPoint("TOPLEFT",0,0)
        local area=art.mapArea
        if area then
            for _,boss in ipairs(bossMapPins(d,selected)) do
                local pin=U.IconButton(art,"Interface\\TargetingFrame\\UI-TargetingFrame-Skull",boss.name,function()
                    if boss.index then V.boss=boss.index;V.item=nil;V.tab="loot";M.Render() end
                end,26)
                U.Tooltip(pin,boss.name,boss.index and {boss.source,"Click to see loot."} or {boss.source})
                pin:SetPoint("CENTER",art,"TOPLEFT",area.x+boss.x*area.width,-area.y-boss.y*area.height)
            end
        end
        viewport:SetHorizontalScroll(math.max(0,math.min(V.panX or 0,vw*(factor-1))))
        viewport:SetVerticalScroll(math.max(0,math.min(V.panY or 0,vh*(factor-1))))
        viewport:SetScript("OnMouseWheel",function(_,delta) zoom(delta>0 and .25 or -.25) end)
        viewport:SetScript("OnMouseDown",function(self,button)
            if button~="LeftButton" or (V.zoom or 1)<=1 then return end
            local x,y=GetCursorPosition();local sx,sy=self:GetHorizontalScroll(),self:GetVerticalScroll();local scale=self:GetEffectiveScale()
            self:SetScript("OnUpdate",function(frame)
                if not IsMouseButtonDown("LeftButton") then frame:SetScript("OnUpdate",nil);return end
                local cx,cy=GetCursorPosition()
                V.panX=math.max(0,math.min(vw*((V.zoom or 1)-1),sx+(x-cx)/scale))
                V.panY=math.max(0,math.min(vh*((V.zoom or 1)-1),sy+(cy-y)/scale))
                frame:SetHorizontalScroll(V.panX);frame:SetVerticalScroll(V.panY)
            end)
        end)
        viewport:SetScript("OnMouseUp",function(self) self:SetScript("OnUpdate",nil) end)
        viewport:SetScript("OnHide",function(self) self:SetScript("OnUpdate",nil) end)
        if selected.tiles then
            U.Label(panel,"Forever client map tiles",16,-height+30,panel:GetWidth()-190,"GameFontHighlightSmall")
        else
            local open=U.Button(panel,"Open full map",155,function()
                if not ns.API.OpenMap(selected.id) then ns.Message("The client could not open this dungeon map.") end
            end)
            open:SetPoint("BOTTOMLEFT",14,12)
        end
    else
        minus:Disable();plus:Disable();fit:Disable()
        local entrance=d.entrance
        if entrance and entrance.map then
            local art=U.LocationMap(viewport,entrance.map,vw,vh,entrance)
            art:ClearAllPoints();viewport:SetScrollChild(art);art:SetPoint("TOPLEFT",0,0)
            U.Label(panel,"Entrance map · interior preview unavailable",16,-height+37,panel:GetWidth()-36,"GameFontHighlightSmall")
        else
            U.Label(panel,"No interior preview or entrance map is available.",18,-65,panel:GetWidth()-36,"GameFontHighlight")
        end
        if type(V.mapFloor)=="number" then
            local currentMap=V.mapFloor
            local open=U.Button(panel,"Open current map",155,function()
                if not ns.API.OpenMap(currentMap) then ns.Message("The client could not open the current map.") end
            end)
            open:SetPoint("BOTTOMLEFT",14,12)
        end
    end
    if d.entrance then local entrance=U.Button(panel,"Entrance area",155,function() C.Map(d.entrance) end);entrance:SetPoint("BOTTOMRIGHT",-14,12) end
    M.y=top-height-8
end
-- Retained journal callers use the same interior-first map surface too.
function M.DungeonMap(d,height)
    V.dungeon=d.slug;V.tab="map"
    mapView(d,M.y,height or math.max(200,M.scroll:GetHeight()+M.y-32))
end
local function questView(d,left,right)
    local rows,lookup={},{}
    local grouped={{},{},{},{},{},{}}
    local states,reasons={},{}
    for _,q in ipairs(d.questSource or {}) do if not q.classic then
        local state,reason=questState(q)
        lookup[q.id]=q;states[q.id]=state;reasons[q.id]=reason
        grouped[state][#grouped[state]+1]=q
    end end
    for state,quests in ipairs(grouped) do
        local group=questGroups[state]
        for _,q in ipairs(quests) do
            local badges,restrictions=questBadges(q)
            local subtitle=restrictions~="" and (restrictions..(reasons[q.id] and " · "..reasons[q.id] or "")) or reasons[q.id]
            rows[#rows+1]={value=q.id,label=q.title,badges=badges,subtitle=subtitle,section=group.name,icon=group.icon}
        end
    end
    local q=lookup[V.quest] or rows[1] and lookup[rows[1].value];V.quest=q and q.id
    U.Label(left,#rows.." quests",12,-12,left:GetWidth()-40,"GameFontNormal")
    C.JournalList(left,rows,V.quest,function(id) V.quest=id;M.Render() end,V.reveal)
    V.reveal=nil
    C.Read(right,function()
        if not q then M.Line("No sourced Forever quests for this dungeon.");return end
        local state=states[q.id]
        M.Line(q.title,"GameFontNormalLarge")
        local badges,restrictions=questBadges(q)
        if restrictions~="" then
            local strip=U.New("Frame",M.body,nil,"questRestrictionIcons")
            strip:SetPoint("TOPLEFT",8,M.y)
            strip:SetSize(M.width-16,C.Badges(strip,badges,0,0,M.width-16))
            M.y=M.y-strip:GetHeight()
            M.Line(restrictions,"GameFontHighlightSmall")
        end
        M.Line(questGroups[state].name..(q.req and " · Level "..q.req.." required" or ""),"GameFontHighlightSmall")
        if reasons[q.id] and (state==4 or state==6) then M.Line(reasons[q.id],"GameFontHighlightSmall") end
        if state==1 then questLocation("Turn-in",q.turnIn,q.turnInAt,"Show turn-in") end
        local all,any,parent=prerequisites(q)
        if state==3 or state==4 then
            local function showRequirement(id)
                local previous=lookup[id]
                local title=previous and previous.title or ns.Safe(ns.API.Call("C_QuestLog","GetTitleForQuestID",id)) or ns.QuestSupplies.Name(id)
                local progress=ns.Journey.QuestDone(id) and "Completed" or ns.Journey.OnQuest(id) and "In quest log" or "Required"
                M.Line(title.." · "..progress)
                if previous and previous.id~=q.id then
                    M.Action("Open prerequisite",function() M.OpenPage("Dungeons",function() V.quest=id;V.reveal=true end) end,155)
                end
            end
            if parent then section("Must be in your quest log");showRequirement(parent) end
            if #all>0 then section("Complete before pickup");for _,id in ipairs(all) do showRequirement(id) end end
            if #any>0 then section("Complete any one");for _,id in ipairs(any) do showRequirement(id) end end
        end
        if state==3 or state==4 then questLocation("Pickup",q.from,q.startAt,"Show pickup") end
        section("Dungeon objectives")
        local shown=false
        if state==1 or state==2 then
            local objectives=ns.API.Call("C_QuestLog","GetQuestObjectives",q.id)
            for _,objective in ipairs(type(objectives)=="table" and objectives or {}) do
                local text=ns.Safe(objective.text)
                if type(text)=="string" and text~="" then
                    M.Line((ns.Safe(objective.finished)==true and "Completed · " or "")..text);shown=true
                end
            end
        end
        if not shown then M.Line(q.goal or "Objective details unavailable.") end
        if q.note and q.note~=q.goal then M.Line(q.note,"GameFontHighlightSmall") end
        if state~=1 then questLocation("Turn-in",q.turnIn,q.turnInAt,"Show turn-in") end
        local rewards={}
        for _,r in ipairs(q.choice or {}) do
            rewards[#rewards+1]={id=r.id,name=r.name,quest=q.id,dungeon=d.slug,source=d.name..": "..q.title,
                class=q.class,classes=q.classes,races=q.races,faction=q.faction or q.side,required=q.req,
                sourceKnown=true,foreverLive=q.foreverLive==true,referenceOnly=q.rewardLayoutUnknown==true or state>=4}
        end
        local listedFallback=#rewards==0
        local support=listedFallback and ns.Data.questSupport and ns.Data.questSupport.quests[q.id]
        local seen={}
        for _,id in ipairs(support and support.rewards or {}) do
            if type(id)=="number" and id>0 and not seen[id] then
                seen[id]=true
                rewards[#rewards+1]={id=id,quest=q.id,dungeon=d.slug,source="Quest reward reference · "..q.title,referenceOnly=true}
            end
        end
        if #rewards>0 then
            section((listedFallback or q.rewardLayoutUnknown) and "Listed rewards" or "Choose one reward")
            local inspectSource
            if not listedFallback and not q.rewardLayoutUnknown and state<4 then
                inspectSource=function(item) M.OpenGearCandidate(nil,item.id,item) end
            end
            C.ItemTiles(rewards,function(item) ns.ItemCompare.Show(item) end,inspectSource,states[q.id]~=6)
        end
    end,d.slug..":quest:"..tostring(V.quest))
    local actions={}
    if q then
        if states[q.id]~=6 and ns.Journey.OnQuest(q.id) then
            actions[#actions+1]={label="Open quest log",run=function() ns.QuestWorkspace.Details(q) end}
            local watched=ns.Safe(ns.API.Call("C_QuestLog","GetQuestWatchType",q.id))~=nil
            actions[#actions+1]={label=watched and "Untrack quest" or "Track quest",run=function()
                if watched then ns.QuestWorkspace.Untrack(q)
                elseif C_QuestLog and C_QuestLog.AddQuestWatch then
                    ns.char.manuallyUntracked=ns.char.manuallyUntracked or {};ns.char.manuallyUntracked[q.id]=nil;C_QuestLog.AddQuestWatch(q.id)
                end
                ns.Emit("STATE_CHANGED")
            end}
        end
        if states[q.id]~=5 and states[q.id]~=6 and not ns.Journey.Speedrunning() then
            local included=ns.DungeonJourney.Included(d.slug,q.id)
            actions[#actions+1]={label=included and "Leave out of Journey" or "Include in Journey",run=function()
                ns.DungeonJourney.Toggle(d.slug,q.id);ns.Journey.Advance();M.Render()
            end}
        end
    end
    footer(right,actions)
end
local function bossView(d,left,right)
    local rows={}
    for index,boss in ipairs(d.encounters or {}) do rows[#rows+1]={value=index,label=boss.name,section=boss.wing~=d.name and boss.wing or nil,icon="Interface\\TargetingFrame\\UI-TargetingFrame-Skull"} end
    if not (d.encounters or {})[V.boss or 1] then V.boss=1 end
    V.boss=V.boss or 1
    U.Label(left,"Bosses  |  "..#rows,12,-12,left:GetWidth()-40,"GameFontNormal")
    C.JournalList(left,rows,V.boss,function(index) V.boss=index;V.item=nil;M.Render() end,V.reveal)
    V.reveal=nil
    local boss=d.encounters[V.boss];local selected
    C.Read(right,function()
        if not boss then M.Line("No sourced encounters for this dungeon.");return end
        M.Line(boss.name,"GameFontNormalLarge")
        if boss.wing and boss.wing~=d.name then M.Line(boss.wing,"GameFontHighlightSmall") end
        section("Loot")
        local drops=D.Drops(d,"",boss)
        for _,item in ipairs(drops) do
            if V.requestedItem==item.id or V.item and V.item.id==item.id then selected=item end
        end
        if selected then V.item=selected end
        V.requestedItem=nil
        C.ItemTiles(drops,function(item) V.item=item;M.Render() end,function(item) ns.ItemCompare.Show(item) end,true)
        if #drops==0 then M.Line("No source-listed drops.") end
    end,d.slug..":boss:"..V.boss)
    local actions,summary={}
    if selected then
        local item=selected;local target=ns.char.farming[item.id]
        local status=not item.referenceOnly and ns.ItemComparison.ItemDecision(item.id,item.link,item.info)
        summary=(item.link or item.name)..(status and " · "..status or "")
        if item.reason and not item.actionable then summary=summary.."\n"..item.reason end
        actions[#actions+1]={label="Compare",run=function() ns.ItemCompare.Show(item) end}
        local equipment=item.info and ns.Data.equipSlots[item.info.equip]
        if equipment then actions[#actions+1]={label="Equipment",run=function() M.OpenGearCandidate(nil,item.id,item) end} end
        if equipment or target then
            actions[#actions+1]={label=target and "Remove target" or "Track item",enabled=target~=nil or item.actionable==true,run=function()
                if target then ns.Gear.UntrackHunt(item.id) elseif not ns.Gear.PlanReference(item) then ns.Message("Current usable item data is required to track this item.") end
            end}
        end
    end
    if boss then actions[#actions+1]={label="Dungeon map",run=function()
        local target
        for _,page in ipairs(V.MapPages(d)) do
            for _,pin in ipairs(bossMapPins(d,page)) do
                if pin.index==V.boss then target=page.id;break end
            end
            if target then break end
        end
        M.OpenPage("Dungeons",function()
            V.mapID=target or D.UIMapForInstance(boss.instanceID or d.instanceID)
            V.mapChosen=target~=nil;V.artChecked=false;V.tab="map";V.zoom=1;V.panX=0;V.panY=0
        end)
    end} end
    footer(right,actions,summary)
end
local function openDungeon(slug,tab,prepare)
    return M.OpenPage("Dungeons",function()
        V.dungeon=slug;V.quest=nil;V.boss=nil;V.item=nil;V.requestedItem=nil;V.mapID=nil
        V.tab=tab or "quests"
        V.reveal=prepare~=nil
        if prepare then prepare() end
    end)
end
function M.OpenDungeonSource(dungeon,item)
    return openDungeon(dungeon.slug,item.quest and "quests" or "loot",function()
        if item.quest then V.quest=item.quest;return end
        local bossKey=item.bossKey or item.encounter and item.encounter.id
        for i,boss in ipairs(dungeon.encounters or {}) do
            if bossKey and boss.id==bossKey or not bossKey and boss.name==item.boss then
                V.boss=i;V.requestedItem=item.id;break
            end
        end
    end)
end
local function detail(d,entries,position)
    if V.context~=d.slug then
        V.context=d.slug;V.mapChosen=false;V.artChecked=false;V.zoom=1;V.panX=0;V.panY=0;V.item=nil;V.maps[d.slug]=nil
    end
    local heading=M.y
    local tab=V.tab or "quests"
    local choices={}
    for _,entry in ipairs(entries) do choices[#choices+1]={value=entry.slug,label=entry.name} end
    local back=U.Button(M.body,V.query and V.query~="" and "Search results" or "All dungeons",116,function()
        M.OpenPage("Dungeons",function() V.dungeon=nil end)
    end)
    back:SetPoint("TOPLEFT",8,heading)
    local previous=U.Button(M.body,"<",32,function() openDungeon(entries[position-1].slug,tab) end)
    previous:SetPoint("LEFT",back,"RIGHT",8,0);previous:SetEnabled(position>1)
    U.Tooltip(previous,"Previous dungeon")
    local choose=U.Cycle(M.body,choices,d.slug,math.min(370,M.width-230),function(slug) openDungeon(slug,tab) end)
    choose.choiceTitle="Choose a dungeon";choose:SetPoint("LEFT",previous,"RIGHT",4,0)
    local following=U.Button(M.body,">",32,function() openDungeon(entries[position+1].slug,tab) end)
    following:SetPoint("LEFT",choose,"RIGHT",4,0);following:SetEnabled(position<#entries)
    U.Tooltip(following,"Next dungeon")
    local tabs=U.Options(M.body,{{value="quests",label="Quests"},{value="loot",label="Bosses & Loot"},{value="map",label="Map"}},tab,360,function(value)
        if value~=V.tab then M.OpenPage("Dungeons",function() V.tab=value end) end
    end,3)
    local tabsTop=heading-math.max(back:GetHeight(),choose:GetHeight())-8
    tabs:SetPoint("TOPLEFT",8,tabsTop)
    local level=U.Label(M.body,D.LevelText(d),382,tabsTop-7,M.width-396,"GameFontHighlightSmall")
    local top=tabsTop-math.max(tabs:GetHeight(),level:GetStringHeight()+8)-8
    local height=math.max(200,M.scroll:GetHeight()+top-32)
    if tab=="map" then
        mapView(d,top,height);return
    end
    local leftWidth=math.max(270,math.min(330,math.floor(M.width*.27)))
    local left=C.Pane(M.body,leftWidth,height,8,top,"dungeonSelection")
    local right=C.Pane(M.body,M.width-leftWidth-24,height,leftWidth+16,top,"dungeonDetails",true)
    left.scroll:ClearAllPoints();left.scroll:SetPoint("TOPLEFT",12,-42);left.scroll:SetPoint("BOTTOMRIGHT",-30,12)
    local key=d.slug..":"..tab
    if left.context~=key then left.scroll:SetVerticalScroll(0);left.context=key end
    if tab=="quests" then questView(d,left,right) else bossView(d,left,right) end
    M.y=top-height-8
end
local function dungeonSearch()
    local top=M.y
    local search=U.Edit(M.body,math.min(400,M.width-140),V.query or "",function(query)
        V.query=query:match("^%s*(.-)%s*$");V.searchResult=nil;V.resultQuery=nil;M.Render()
    end)
    search:SetMaxLetters(120);search:SetPoint("TOPLEFT",8,top)
    U.Placeholder(search,"Dungeon, quest, boss, loot or ID · Enter")
    local library=U.Button(M.body,"Library books",130,function() M.OpenPage("Books") end)
    library:SetPoint("TOPRIGHT",M.body,"TOPRIGHT",-8,top)
    if V.query and V.query~="" then
        local clear=U.Button(M.body,"Clear search",110,function() V.query=nil;V.searchResult=nil;M.Render() end)
        clear:SetPoint("LEFT",search,"RIGHT",8,0)
    end
    M.y=top-search:GetHeight()-10
    if not V.query or V.query=="" then return false end
    if V.resultQuery~=V.query then
        V.resultQuery=V.query;V.results,V.resultCount=D.Search(V.query,100)
    end
    if V.resultCount==0 then M.Line("No matches. Try a shorter name or an exact item or quest ID.");return true end
    if V.resultCount>#V.results then M.Line("Showing "..#V.results.." of "..V.resultCount.." matches. Refine the search to narrow results.","GameFontHighlightSmall") end
    local pane=C.Pane(M.body,M.width-16,math.max(220,M.scroll:GetHeight()+M.y-28),8,M.y,"dungeonSearch")
    if pane.context~=V.query then pane.context=V.query;pane.scroll:SetVerticalScroll(0) end
    local rows,lookup={},{}
    for i,match in ipairs(V.results) do
        local badges,restriction
        if match.record then badges,restriction=questBadges(match.record) end
        rows[#rows+1]={value=i,label=match.name,badges=badges,section=match.dungeon.name,
            subtitle=restriction and restriction~="" and ("Quest · "..restriction)
                or match.kind=="quest" and "Quest" or match.bossName or match.kind=="boss" and "Boss" or D.LevelText(match.dungeon)}
        lookup[i]=match
    end
    C.JournalList(pane,rows,V.searchResult,function(index)
        local match=lookup[index]
        openDungeon(match.dungeon.slug,match.boss and "loot" or "quests",function()
            V.searchResult=index;V.boss=match.boss;V.quest=match.quest;V.requestedItem=match.item
        end)
    end)
    M.y=M.y-pane:GetHeight()-8
    return true
end
function M.Dungeons()
    if ns.db.settings.modules.dungeons==false then
        M.Line("Dungeon Journal is off.")
        M.Action("Enable Dungeon Journal",function()
            ns.db.settings.modules.dungeons=true;ns.Emit("SETTINGS_CHANGED");M.Render()
        end,220)
        return
    end
    local entries=D.Entries()
    for index,d in ipairs(entries) do if d.slug==V.dungeon then detail(d,entries,index);return end end
    V.dungeon=nil
    if dungeonSearch() then return end
    local top=M.y;local columns=4;local gap=8;local count=#entries;local rows=math.max(1,math.ceil(count/columns))
    local available=math.max(1,M.scroll:GetHeight()+top-24)
    local cardHeight=math.max(67*(ns.db.settings.textScale or 1),(available-(rows-1)*gap)/rows)
    local width=(M.width-16-(columns-1)*gap)/columns
    for i,d in ipairs(entries) do local record=d
        local b=U.New("Button",M.body,"BackdropTemplate","dungeonCard");b:SetSize(width,cardHeight);b:SetPoint("TOPLEFT",8+((i-1)%columns)*(width+gap),top-math.floor((i-1)/columns)*(cardHeight+gap))
        b:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
        b.art=b.art or b:CreateTexture(nil,"BACKGROUND");b.art:ClearAllPoints();b.art:SetPoint("TOPLEFT",4,-4);b.art:SetPoint("BOTTOMRIGHT",-4,4)
        b.art:SetTexture(record.background or "Interface\\QuestFrame\\QuestBG");b.art:SetAlpha(.95)
        local crop=record.backgroundCoords
        b.art:SetTexCoord(crop and crop[1] or 0,crop and crop[2] or 1,crop and crop[3] or .15,crop and crop[4] or .85)
        b.shade=b.shade or b:CreateTexture(nil,"BORDER");b.shade:ClearAllPoints();b.shade:SetPoint("TOPLEFT",4,-4);b.shade:SetPoint("TOPRIGHT",-4,-4);b.shade:SetHeight(math.min(48,math.max(20,cardHeight-26)));b.shade:SetColorTexture(.035,.025,.012,.55)
        b.footer=b.footer or b:CreateTexture(nil,"BORDER");b.footer:ClearAllPoints();b.footer:SetPoint("BOTTOMLEFT",4,4);b.footer:SetPoint("BOTTOMRIGHT",-4,4);b.footer:SetHeight(22);b.footer:SetColorTexture(.035,.025,.012,.6)
        b:SetBackdropBorderColor(.57,.41,.19,1)
        local name=U.Label(b,record.name,10,-8,width-20,"GameFontNormal");name:SetTextColor(1,.82,.3);name:SetShadowColor(0,0,0,1);name:SetShadowOffset(1,-1)
        local questCount=0
        for _,q in ipairs(record.questSource or {}) do if not q.classic then questCount=questCount+1 end end
        local count=U.Label(b,questCount.." quests",width-82,-cardHeight+22,72,"GameFontHighlightSmall");count:SetTextColor(1,.86,.42);count:SetJustifyH("RIGHT")
        U.Label(b,D.LevelText(record),10,-cardHeight+22,width-100,"GameFontHighlightSmall")
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
        b:SetScript("OnClick",function() openDungeon(record.slug) end)
    end
    M.y=top-rows*cardHeight-(rows-1)*gap
end
