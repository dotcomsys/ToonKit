local addonName, ns = ...
local U,M=ns.UI,ns.Main
local equipment,settings,review=M.EquipmentContent,M.SettingsContent,M.JourneyReview
local function at(widget,x,y) widget:SetPoint("TOPLEFT",x,y);return widget end
function U.ScrollPane(parent,width,height,x,y,role)
    local pane=U.Panel(parent,width,height,x,y,role)
    if not pane.scroll then
        pane.scroll=CreateFrame("Frame",nil,pane);pane.scroll:SetPoint("TOPLEFT",10,-12);pane.scroll:SetPoint("BOTTOMRIGHT",-16,12)
        pane.scroll.SetVerticalScroll=function() end;pane.scroll.GetVerticalScroll=function() return 0 end
        pane.content=CreateFrame("Frame",nil,pane.scroll);pane.content._managed=true;pane.content:SetPoint("TOPLEFT",0,0)
    end
    U.Release(pane.content);pane.content:SetWidth(width-42);return pane
end

function M.InPane(pane,width,key,render)
    local parent,oldWidth,y=M.body,M.width,M.y
    M.body=pane.content;M.width=width-42;M.y=-4
    local ok,err=pcall(render);local height=math.max(100,-M.y+12)
    M.body=parent;M.width=oldWidth;M.y=y;pane.content:SetHeight(height)
    pane:SetHeight(math.max(pane:GetHeight(),height+24))
    if pane.key~=key then pane.scroll:SetVerticalScroll(0);pane.key=key end
    if not ok then error(err) end
end
function U.MapArtwork(mapID)
    local layers=ns.API.Call("C_Map","GetMapArtLayers",mapID)
    if type(layers)~="table" then return end
    for index,layer in ipairs(layers) do
        if index>8 then break end
        local w,h,tw,th=ns.Safe(layer.layerWidth),ns.Safe(layer.layerHeight),ns.Safe(layer.tileWidth),ns.Safe(layer.tileHeight)
        if type(w)=="number" and type(h)=="number" and type(tw)=="number" and type(th)=="number" and w==w and h==h and tw==tw and th==th and w>0 and h>0 and tw>0 and th>0 and w<=100000 and h<=100000 and tw<=100000 and th<=100000 and math.ceil(w/tw)*math.ceil(h/th)<=256 then
            local textures=ns.API.Call("C_Map","GetMapArtLayerTextures",mapID,index)
            if type(textures)=="table" then
                for n=1,math.min(#textures,256) do
                    local id=ns.Safe(textures[n])
                    if type(id)=="number" and id>0 then return {width=w,height=h,tileWidth=tw,tileHeight=th,textures=textures} end
                end
            end
        end
    end
end
function U.LocationMap(parent,mapID,width,height,point)
    local panel=U.Panel(parent,width,height,0,0,"nativeLocationMap")
    panel.mapArea=nil;panel.mapAvailable=false
    local art=U.MapArtwork(mapID)
    if not art then
        U.Label(panel,"The client has no readable map artwork for this location.",16,-20,width-32,"GameFontHighlight");return panel
    end
    local w,h,tw,th,textures=art.width,art.height,art.tileWidth,art.tileHeight,art.textures
    local scale=math.min((width-12)/w,(height-12)/h);local ox=(width-w*scale)/2;local oy=(height-h*scale)/2
    panel.mapArea={x=ox,y=oy,width=w*scale,height=h*scale}
    panel.mapAvailable=true
    local columns,rows=math.ceil(w/tw),math.ceil(h/th)
    for row=1,rows do for column=1,columns do
        local id=ns.Safe(textures[(row-1)*columns+column])
        if type(id)=="number" and id>0 then
            local pw,ph=math.min(tw,w-(column-1)*tw),math.min(th,h-(row-1)*th)
            local tile=U.New("Frame",panel,nil,"mapTile");tile:SetSize(pw*scale,ph*scale);tile:SetPoint("TOPLEFT",ox+(column-1)*tw*scale,-oy-(row-1)*th*scale)
            tile.art=tile.art or tile:CreateTexture(nil,"ARTWORK");tile.art:SetAllPoints();tile.art:SetTexture(id,nil,nil,"TRILINEAR");tile.art:SetTexCoord(0,pw/tw,0,ph/th)
        end
    end end
    if point and point.map==mapID and type(point.x)=="number" and type(point.y)=="number" and point.x>=0 and point.x<=1 and point.y>=0 and point.y<=1 then
        local pin=U.IconButton(panel,"Interface\\Minimap\\Tracking\\Door","Sourced entrance - show waypoint",function() ns.API.MapPoint(mapID,point.x,point.y) end,24)
        pin:SetPoint("CENTER",panel,"TOPLEFT",ox+point.x*w*scale,-oy-point.y*h*scale)
    end
    return panel
end
function M.DungeonMap(d,height)
    local mapID=d.entrance and d.entrance.map or d.zoneMap
    if not mapID then M.Line("No sourced map is available for this entry.");return end
    local info=ns.API.Call("C_Map","GetMapInfo",mapID)
    M.Line((info and ns.Safe(info.name) or "Source map #"..mapID)..(d.entrance and " - Entrance area" or " - Source map"),"GameFontNormal")
    local map=U.LocationMap(M.body,mapID,M.width-16,math.max(200,height-65),d.entrance)
    map:ClearAllPoints();map:SetPoint("TOPLEFT",8,M.y);M.y=M.y-map:GetHeight()-8
    M.Line("Native client map. Only the sourced entrance is marked; no interior rooms or boss positions are inferred.","GameFontHighlightSmall")
end
local function panels(role,leftWidth)
    local top=M.y;local height=math.max(300,M.scroll:GetHeight()+top-20)
    local left=U.ScrollPane(M.body,leftWidth,height,8,top,role.."List")
    local rightWidth=M.width-leftWidth-34
    local right=U.ScrollPane(M.body,rightWidth,height,leftWidth+20,top,role.."Detail")
    return left,right,rightWidth,top-height-8
end
local function selection(parent,text,detail,index,width,selected,callback,icon)
    if index==1 then parent.selectionHeight=0 end
    local b=U.New("Button",parent,"BackdropTemplate","selectionRow");b:SetSize(width,49);b:SetPoint("TOPLEFT",0,-(parent.selectionHeight or 0))
    b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8})
    b:SetBackdropColor(selected and .23 or .07,selected and .15 or .055,.035,1);b:SetBackdropBorderColor(selected and .8 or .36,.29,.12,1)
    b.icon=b.icon or b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(30,30);b.icon:SetPoint("LEFT",7,0);b.icon:SetTexture(icon);b.icon:SetShown(icon~=nil)
    local x=icon and 46 or 10
    local label=U.Label(b,text,x,-7,width-x-8,"GameFontNormal");label:SetWordWrap(true)
    local detailY=label:GetStringHeight()+11
    local description=U.Label(b,detail or "",x,-detailY,width-x-8,"GameFontHighlightSmall");description:SetWordWrap(true)
    local height=math.max(icon and 42 or 34,detailY+(detail~="" and description:GetStringHeight()+6 or 0))
    b:SetHeight(height);parent.selectionHeight=(parent.selectionHeight or 0)+height+4
    b:SetScript("OnClick",callback);U.Tooltip(b,text,{detail or ""});return b
end
function M.Equipment()
    if ns.db.settings.modules.gear and M.quickGear and M.QuickGear and not M.showWeights and not M.gearRequirementRecord then return M.QuickGear() end
    if not ns.db.settings.modules.gear or M.showWeights then equipment();return end
    local top=M.y
    M.Line("Equipment","GameFontNormalLarge")
    local role=U.Options(M.body,{{value="auto",label="Detect from talents"},{value="tank",label="Tank"},{value="healer",label="Healer"},{value="melee",label="Melee damage"},{value="ranged",label="Ranged damage"},{value="caster",label="Spell damage"}},ns.char.playstyle,M.width-16,function(v) ns.char.playstyle=v;ns.Talents.Detect();ns.Emit("STATE_CHANGED") end)
    role:SetPoint("TOPLEFT",8,M.y);M.y=M.y-role:GetHeight()-10
    U.Tooltip(role,"Gear estimate role",{"Auto uses readable talent evidence. An unknown role is not assigned another class's priorities. Manual choices are saved for this character."})
    M.Line(ns.State.className.." | Role: "..(ns.State.role or "unknown").." | Select a slot to compare its candidates.","GameFontHighlightSmall")
    local left,right,width,bottom=panels("equipment",360)
    U.Label(left.content,ns.State.name,54,-5,230,"GameFontNormalLarge")
    U.Label(left.content,"Level "..ns.State.level.." "..ns.State.className,54,-29,230,"GameFontHighlightSmall")
    if not left.model and not left.modelUnsupported then
        local ok,model=pcall(CreateFrame,"PlayerModel",nil,left.content)
        if ok and model and type(model.SetUnit)=="function" then left.model=model;model:SetPoint("TOPLEFT",52,-65);model:SetSize(210,380);model:EnableMouse(false) else left.modelUnsupported=true end
    end
    if left.model and not InCombatLockdown() then
        local stamp=ns.State.class
        for _,slot in ipairs(ns.Data.slots) do stamp=stamp..":"..tostring(ns.State.equipment[slot[1]] and ns.State.equipment[slot[1]].id) end
        if left.modelStamp~=stamp then
            local ok=pcall(function() left.model:SetUnit("player");if left.model.SetPortraitZoom then left.model:SetPortraitZoom(0) end;if left.model.RefreshCamera then left.model:RefreshCamera() end end)
            left.model:SetShown(ok);left.modelStamp=ok and stamp or nil
        end
    end
    left.portrait=left.portrait or left.content:CreateTexture(nil,"ARTWORK");left.portrait:SetSize(150,150);left.portrait:SetPoint("TOPLEFT",82,-145)
    local preview=left.model and left.model:IsShown()
    left.portrait:SetShown(not preview)
    if not preview then
        if type(SetPortraitTexture)=="function" then SetPortraitTexture(left.portrait,"player") else left.portrait:SetTexture(ns.Brand.icon) end
    end
    for i,slot in ipairs(ns.Data.slots) do local id=slot[1];local current=ns.State.equipment[id]
        local _,empty=ns.API.Call("C_PaperDollInfo","GetInventorySlotInfoForInvSlot",id)
        local side=i<=8 and 0 or 1;local index=side==0 and i-1 or i-9
        local button=U.New("Button",left.content,"BackdropTemplate","equipmentSlot");button:SetSize(42,42);button:SetPoint("TOPLEFT",side==0 and 1 or 273,-60-index*47)
        button:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8});button:SetBackdropColor(.055,.045,.03,1);button:SetBackdropBorderColor(M.slot==id and 1 or .4,M.slot==id and .8 or .3,.15,1)
        button.icon=button.icon or button:CreateTexture(nil,"ARTWORK");button.icon:SetPoint("TOPLEFT",5,-5);button.icon:SetPoint("BOTTOMRIGHT",-5,5);button.icon:SetTexture(current and (current.icon or current.info and current.info.icon) or ns.Safe(empty) or 134400)
        U.Tooltip(button,slot[2],{current and current.info and current.info.name or "Empty or loading slot","Select to compare items for this slot."},current and current.link)
        button:RegisterForClicks("LeftButtonUp","RightButtonUp")
        button:SetScript("OnClick",function(_,mouse)
            if mouse=="RightButton" then M.slot=id;M.gearWorkspace="cap";M.huntItem=nil;M.huntAcquisition=nil;M.Render();return end
            M.slotContexts=M.slotContexts or {};M.slotContexts[M.slot]={query=M.gearQuery,candidate=M.gearCandidateKey}
            local previous=M.slotContexts[id] or {};M.slot=id;M.gearQuery=previous.query or "";M.gearCandidateKey=previous.candidate;M.gearCandidate=nil;M.Render()
        end)
    end
    left.content:SetHeight(500)
    M.equipmentEmbedded=true
    local ok,err=pcall(M.InPane,right,width,tostring(M.slot)..":"..tostring(M.gearPage),equipment)
    M.equipmentEmbedded=nil;M.y=bottom;if not ok then error(err) end
end
function M.Settings()
    local pages={"Appearance","Status bar","Journey","Inventory","Character","Maps","Profiles","About"}
    local aliases={General="Appearance",Bags="Inventory",Modules="Character"}
    M.settingsPage=aliases[M.settingsPage] or M.settingsPage or "Appearance"
    M.Line("Settings","GameFontNormalLarge")
    local left,right,width,bottom=panels("settings",205)
    for i,name in ipairs(pages) do local page=name
        selection(left.content,page,"",i,163,M.settingsPage==page,function() M.settingsPage=page;M.Render() end)
    end
    left.content:SetHeight(left.content.selectionHeight or 100)
    M.settingsEmbedded=true
    local key=M.settingsPage..":"..tostring((M.settingsSections or {})[M.settingsPage])
    local ok,err=pcall(M.InPane,right,width,key,settings)
    left:SetHeight(math.max(left:GetHeight(),right:GetHeight()));M.settingsEmbedded=nil;M.y=math.min(bottom,M.y-right:GetHeight()-8);if not ok then error(err) end
end
function M.Farming()
    M.Line("Tracked acquisitions","GameFontNormalLarge")
    local filters=at(U.Options(M.body,{{value="seeking",label="Still seeking"},{value="obtained",label="Previously obtained"},{value="all",label="All tracked items"}},M.farmingFilter or "seeking",M.width-20,function(v) M.farmingFilter=v;M.Render() end),10,M.y);M.y=M.y-filters:GetHeight()-12
    local search=at(U.Edit(M.body,math.max(240,M.width-250),M.farmingQuery or "",function(value) M.farmingQuery=value:lower();M.Render() end),10,M.y)
    U.Placeholder(search,"Search hunts, sources, bosses or item IDs")
    at(U.Button(M.body,"Clear hunt filters",200,function() M.farmingQuery="";M.farmingDungeon=nil;M.farmingFilter="all";M.Render() end),M.width-220,M.y);M.y=M.y-36
    if M.farmingDungeon then local dungeon=ns.Journal.Get(M.farmingDungeon);M.Line("Hunts in "..(dungeon and dungeon.name or M.farmingDungeon),"GameFontNormal") end
    local rows={};local filter=M.farmingFilter or "seeking"
    for id,r in pairs(ns.char.farming) do if filter=="all" or filter=="seeking" and not r.obtained or filter=="obtained" and r.obtained then
        local info=ns.API.Item(id);local name=info and info.name or "Item #"..id
        local dungeon=r.dungeon and ns.Journal.Get(r.dungeon)
        if (not M.farmingDungeon or dungeon and dungeon.slug==M.farmingDungeon) and
            (name.." "..id.." "..(r.source or "").." "..(r.boss or "")):lower():find(M.farmingQuery or "",1,true) then
            rows[#rows+1]={id=id,info=info,target=r,name=name}
        end
    end end
    table.sort(rows,function(a,b) return a.name<b.name end)
    local found=false;for _,r in ipairs(rows) do if r.id==M.farmingSelection then found=true end end
    if not found then M.farmingSelection=rows[1] and rows[1].id end
    if #rows==0 then
        local card=U.Panel(M.body,M.width-16,196,8,M.y,"acquisitionWelcome")
        U.Label(card,next(ns.char.farming) and "No hunts match these filters" or "Build your acquisition list",24,-22,700,"GameFontNormalLarge")
        U.Label(card,"Choose equipment worth working toward. Track a sourced item from your equipment comparison or a boss loot table, then return here to follow its source and ownership.",24,-58,850,"GameFontHighlight")
        at(U.Button(card,"Compare equipment",220,function() M.tab="Character";M.sub="Equipment";M.Render() end),24,-138)
        at(U.Button(card,"Browse dungeon loot",220,function() M.tab="Adventure";M.sub="Dungeons";M.dungeonBrowse=true;M.Render() end),260,-138)
        M.y=M.y-208;return
    end
    local left,right,width,bottom=panels("farming",335)
    local selected
    local choices={};for _,r in ipairs(rows) do choices[#choices+1]={value=r.id,label=r.name} end
    local pick=U.Roster(left.content,choices,M.farmingSelection,293,left:GetHeight()-28,function(id) M.farmingSelection=id;M.Render() end,"farming")
    pick:SetPoint("TOPLEFT",0,0)
    for _,r in ipairs(rows) do if r.id==M.farmingSelection then selected=r;break end end
    left.content:SetHeight(pick:GetHeight())
    M.InPane(right,width,tostring(M.farmingSelection),function()
        if not selected then M.Line("Track an item from Equipment or Dungeons to follow its source here.");return end
        local r=selected;local target=r.target
        if not target.obtained then
            M.Action(ns.char.route=="gear-hunt:"..r.id and "Return to previous guide" or "Follow selected hunt in guide",function()
                if ns.char.route=="gear-hunt:"..r.id then ns.Gear.StopFollowing() else ns.Gear.FollowHunt(r.id) end
            end,260)
        end
        M.Heading(r.name);if r.info then U.Item(M.body,r.id,10,M.y,44,r.info.link);M.y=M.y-54 end
        M.Line(target.obtained and "Previously obtained" or "Still seeking","GameFontNormal")
        M.Line((ns.State.owned[r.id] or 0).." currently carried or equipped","GameFontHighlightSmall")
        M.Heading("Source");M.Line(target.source or "Recorded source")
        if target.dungeon then M.Action("Open boss and loot",function()
            M.tab="Adventure";M.sub="Dungeons";M.dungeon=target.dungeon;M.dungeonBrowse=false;M.dungeonPage="Loot";M.lootPage=1;M.lootQuery="";M.allBossLoot=false;M.encounterSelection=1
            local d=ns.Journal.Get(target.dungeon);local matched=false
            for i,e in ipairs(d and d.encounters or {}) do for _,item in ipairs(e.loot) do if item.id==r.id and (target.bossKey and target.bossKey==e.id or not target.bossKey and (not target.boss or target.boss==e.name)) then M.encounterSelection=i;matched=true;break end end;if matched then break end end
            M.bossFilter=M.encounterSelection;M.Render()
        end,220)
        elseif target.quest then M.Action("Inspect quest",function() if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(target.quest) end end,220) end
        local slots=r.info and ns.Data.equipSlots[r.info.equip]
        if slots then
            M.Action(M.farmingCompare and "Hide equipment comparison" or "Compare with equipment",function() M.farmingCompare=not M.farmingCompare;M.Render() end,240)
            if M.farmingCompare then
                for _,stat in ipairs(ns.Gear.StatDeltas({id=r.id,info=r.info,link=r.info.link,source=target.source},slots[1])) do
                    M.Line(stat.name..": "..stat.before.." / "..stat.after..string.format(" (%+.1f)",stat.delta),"GameFontHighlightSmall")
                end
            end
        end
        M.Action("Stop tracking this item",function() ns.Gear.UntrackHunt(r.id);M.Render() end,220)
    end)
    M.y=bottom
end
function M.JourneyReview()
    if not M.routePicker then
        review();return
    end
    M.Line("Journey campaign: 1-60","GameFontNormalLarge")
    M.Line("Active progression cap: "..ns.Rules.Cap()..". Later leveling segments remain available for planning.","GameFontHighlightSmall")
    local query=at(U.Edit(M.body,450,M.routeQuery or "",function(v) M.routeQuery=v:lower();M.Render() end),12,M.y);U.Placeholder(query,"Search zone, class or level");M.y=M.y-34
    local left,right,width,bottom=panels("routePicker",430)
    local rows={};for _,r in ipairs(ns.Journey.Routes()) do if not r.planSlug and (r.name.." "..(r.category or "")):lower():find(M.routeQuery or "",1,true) then rows[#rows+1]=r end end
    local found=false;for _,r in ipairs(rows) do if r.id==M.routePreview then found=true end end;if not found then M.routePreview=rows[1] and rows[1].id end
    local selected
    local choices={};for _,r in ipairs(rows) do choices[#choices+1]={value=r.id,label=r.name} end
    local pick=U.Roster(left.content,choices,M.routePreview,388,left:GetHeight()-28,function(id) M.routePreview=id;M.Render() end,"routes",true)
    pick:SetPoint("TOPLEFT",0,0)
    for _,r in ipairs(rows) do if r.id==M.routePreview then selected=r;break end end
    left.content:SetHeight(pick:GetHeight())
    M.InPane(right,width,tostring(M.routePreview),function()
        if not selected then M.Line("No guides match this search.");return end
        local r=selected;M.Heading(r.name)
        if r.min then M.Line("Levels "..r.min.."-"..(r.max or r.min)) end
        M.Line(r.source or "Your live quest log","GameFontHighlightSmall")
        if r.steps then M.Line(#r.steps.." source steps","GameFontNormal") end
        local nextID=ns.Journey.NextID(r)
        local nextRoute=nextID and ns.Journey.Get(nextID)
        if nextRoute then M.Line("Next: "..nextRoute.name) end
        if (r.min or 1)<=ns.Rules.Cap() then
            M.Action("Follow this guide",function() if ns.Journey.Select(r.id) then M.routePicker=false;M.journeyPage="Now";M.routeStep=nil end end,240)
        else
            M.Line("Future campaign segment. Retained for levels 31-60; following it is disabled above the active cap.","GameFontNormal")
        end
        M.Action("Choose automatically for me",function() M.routePicker=false;M.journeyPage="Now";ns.Journey.Automatic() end,240)
    end)
    M.y=bottom
end
