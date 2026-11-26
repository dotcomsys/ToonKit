local addonName, ns = ...
local V={};ns.QuestWorkspace=V
local U=ns.UI
local function combat() return type(InCombatLockdown)=="function" and InCombatLockdown() end
local function native(name,...) return ns.API.Call("C_QuestLog",name,...) end
local function difficulty(q)
    local value=ns.Safe(ns.API.Call("C_PlayerInfo","GetContentDifficultyQuestForPlayer",q.id))
    if value~=nil and type(GetDifficultyColor)=="function" then
        local color=GetDifficultyColor(value)
        if type(color)=="table" then return ns.Safe(color.r,.9),ns.Safe(color.g,.87),ns.Safe(color.b,.79) end
    end
    return .9,.87,.79
end
local function records()
    local count=ns.Safe(native("GetNumQuestWatches"))
    if type(count)~="number" then return {},false end
    local byID={};for _,q in ipairs(ns.State.quests or {}) do byID[q.id]=q end
    local rows={}
    local current=ns.db.settings.questTrackerZone and ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"))
    local function zone(map)
        for _=1,5 do
            if type(map)~="number" or map<=0 then return end
            local info=ns.API.Call("C_Map","GetMapInfo",map)
            if type(info)~="table" or not Enum or not Enum.UIMapType then return map end
            local mapType=ns.Safe(info.mapType)
            if mapType==Enum.UIMapType.Zone or mapType==Enum.UIMapType.Dungeon then return map end
            local parent=ns.Safe(info.parentMapID)
            if type(parent)~="number" or parent<=0 or parent==map then return map end
            map=parent
        end
        return map
    end
    current=zone(current)
    for index=1,count do
        local id=ns.Safe(native("GetQuestIDForQuestWatchIndex",index))
        if type(id)=="number" then
            local q=byID[id] or {id=id,title=ns.Safe(native("GetTitleForQuestID",id),"Quest details loading"),objectives={}}
            if not current or zone(ns.Safe(native("GetMapForQuestPOIs",id)) or q.map)==current then rows[#rows+1]={
                quest=q,
                objectives=ns.Safe(native("GetQuestObjectives",id),q.objectives),
                complete=ns.Journey.ReadyToTurnIn(id),
                level=ns.Safe(native("GetQuestDifficultyLevel",id),q.level or 0),
                zone=q.header or "Other quests",
            } end
        end
    end
    table.sort(rows,function(a,b)
        if a.zone~=b.zone then return a.zone<b.zone end
        if a.level~=b.level then return a.level<b.level end
        return (a.quest.title or "")<(b.quest.title or "")
    end)
    return rows,true
end
function V.ClearFocus(id)
    if not id or ns.char.questFocus~=id then return false end
    if ns.char.customWaypoint and ns.char.customWaypoint.owner=="quest:"..id then ns.char.customWaypoint=nil end
    ns.char.questFocus=nil;ns.Navigation.Refresh();ns.Emit("STATE_CHANGED","journey")
    return true
end
function V.Untrack(q)
    if not C_QuestLog or type(C_QuestLog.RemoveQuestWatch)~="function" then return end
    ns.char.manuallyUntracked=ns.char.manuallyUntracked or {};ns.char.manuallyUntracked[q.id]=true
    C_QuestLog.RemoveQuestWatch(q.id);V.ClearFocus(q.id);V.UpdateTracker()
end
function V.Focus(q)
    if V.ClearFocus(q.id) then return end
    local point=ns.Navigation.QuestLocation(q.id)
    if not point then ns.Message("No native objective destination is available.");return end
    point.owner="quest:"..q.id;ns.char.customWaypoint=point;ns.char.questFocus=q.id
    ns.Navigation.Refresh();ns.Emit("STATE_CHANGED")
end
function V.Details(q)
    if type(QuestMapFrame_OpenToQuestDetails)=="function" then QuestMapFrame_OpenToQuestDetails(q.id)
    elseif type(OpenQuestLog)=="function" then OpenQuestLog() end
end
function V.OpenLog() if type(OpenQuestLog)=="function" then OpenQuestLog() end end
function V.Menu(anchor,items,width)
    width=width or 235
    if not V.menu then
        V.menu=CreateFrame("Frame",nil,UIParent,"BackdropTemplate");V.menu._managed=true;V.menu:SetFrameStrata("DIALOG")
        V.menu:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
    end
    local f=V.menu;U.Release(f);f.owner=anchor
    if not anchor.tkMenuHide then
        anchor.tkMenuHide=true;anchor:HookScript("OnHide",function(self) if V.menu and V.menu.owner==self then V.menu:Hide() end end)
    end
    f:ClearAllPoints();f:SetPoint("TOPRIGHT",anchor,"BOTTOMRIGHT");f:SetSize(width,#items*23+14)
    local y=7
    for i,entry in ipairs(items) do local action=entry
        local button=U.New("Button",f,nil,"questMenuEntry");button:SetWidth(width-16);button:SetPoint("TOPLEFT",8,-y)
        local label=U.Label(button,action[1],7,-4,width-30,"GameFontHighlightSmall")
        button:SetHeight(math.max(23,label:GetStringHeight()+8));y=y+button:GetHeight()
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
        button:SetScript("OnClick",function() f:Hide();action[2]() end)
    end
    f:SetHeight(y+7);f:SetClampedToScreen(true);f:Show()
end
local function collapse(onlyObjectives)
    ns.char.questTrackerCollapsed=ns.char.questTrackerCollapsed or {};ns.char.questTrackerZones=ns.char.questTrackerZones or {}
    for _,entry in ipairs(records()) do
        if onlyObjectives then ns.char.questTrackerCollapsed[entry.quest.id]=true else ns.char.questTrackerZones[entry.zone]=true end
    end
    V.UpdateTracker()
end
function V.AnchorTracker(f)
    local left,top=f:GetLeft(),f:GetTop();if not left or not top then return end
    f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top)
end
function V.CreateTracker()
    if V.tracker then return end
    local f=CreateFrame("Frame",nil,UIParent);V.tracker=f;f:SetSize(320,480);f:SetMovable(true);f:SetResizable(true);f:SetClampedToScreen(true)
    f.background=f:CreateTexture(nil,"BACKGROUND");f.background:SetAllPoints();f.background:SetColorTexture(.04,.031,.02,.90)
    f:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-180,-250)
    local pos=ns.db.settings.positions.questTracker
    if pos then f:ClearAllPoints();f:SetPoint(pos.point,UIParent,pos.relative,pos.x,pos.y) end
    local header=CreateFrame("Button",nil,f);header:SetPoint("TOPLEFT");header:SetPoint("TOPRIGHT");header:SetHeight(24);header:RegisterForClicks("LeftButtonUp","RightButtonUp");header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function() if not combat() and (not ns.db.settings.locked or IsControlKeyDown()) then f:StartMoving() end end)
    header:SetScript("OnDragStop",function() f:StopMovingOrSizing();V.AnchorTracker(f);local a,_,b,x,y=f:GetPoint();ns.db.settings.positions.questTracker={point=a,relative=b,x=x,y=y} end)
    header:SetScript("OnClick",function(self,button)
        if button=="LeftButton" then ns.SetSetting("questTrackerCollapsed",not ns.db.settings.questTrackerCollapsed);return end
        V.Menu(self,{{"Collapse objectives",function() collapse(true) end},{"Collapse zones",function() collapse(false) end},{"Expand all",function() ns.char.questTrackerCollapsed={};ns.char.questTrackerZones={};V.UpdateTracker() end},{"Overflow scrolling: "..(ns.db.settings.questTrackerScroll and "on" or "off"),function() ns.SetSetting("questTrackerScroll",not ns.db.settings.questTrackerScroll) end},{"Close menu",function() end}})
    end)
    f.title=U.Label(header,"Quests",0,-3,300,"GameFontNormal")
    f.viewport=CreateFrame("ScrollFrame",nil,f);f.viewport:SetPoint("TOPLEFT",0,-27);f.viewport:SetPoint("BOTTOMRIGHT",0,28)
    f.body=CreateFrame("Frame",nil,f.viewport);f.body._managed=true;f.viewport:SetScrollChild(f.body)
    f.viewport:SetScript("OnMouseWheel",function(self,delta)
        if ns.db.settings.questTrackerScroll then self:SetVerticalScroll(math.max(0,math.min(math.max(0,f.body:GetHeight()-self:GetHeight()),self:GetVerticalScroll()-delta*28))) end
    end)
    f.notice=CreateFrame("Button",nil,f);f.notice:SetPoint("BOTTOMLEFT");f.notice:SetPoint("BOTTOMRIGHT");f.notice:SetHeight(24)
    f.notice.text=U.Label(f.notice,"",0,-2,300,"GameFontHighlightSmall")
    f.notice:SetScript("OnClick",function() V.Menu(f.notice,{{"Collapse objectives",function() collapse(true) end},{"Collapse zones",function() collapse(false) end},{"Enable overflow scrolling",function() ns.SetSetting("questTrackerScroll",true) end}}) end)
    local size=CreateFrame("Button",nil,f);size:SetPoint("BOTTOMRIGHT");size:SetSize(20,20);size:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    size:SetScript("OnMouseDown",function() if not combat() and IsControlKeyDown() then f:StartSizing("BOTTOMRIGHT") end end)
    size:SetScript("OnMouseUp",function() f:StopMovingOrSizing();ns.db.settings.questTrackerWidth=math.max(240,f:GetWidth());ns.db.settings.questTrackerHeight=math.max(140,f:GetHeight());V.UpdateTracker() end)
    U.Tooltip(size,"Resize tracker",{"Ctrl-drag. Header right-click: collapse and layout options."});V.AnchorTracker(f)
end
function V.SyncNativeTracker()
    if not ns.db or combat() then return end
    local manager=ObjectiveTrackerManager;local module=QuestObjectiveTracker
    if type(manager)~="table" or not module or type(manager.GetContainerForModule)~="function"
        or type(manager.SetModuleContainer)~="function" or type(manager.AddContainer)~="function" then return end
    -- Restore containers owned by the preceding broad parent-hiding implementation.
    for frame,saved in pairs(V.nativeParents or {}) do if saved.parent and frame.SetParent then frame:SetParent(saved.parent) end end
    V.nativeParents={}
    local replace=ns.db.settings.questTrackerEnabled~=false
    local current=manager:GetContainerForModule(module)
    if replace and current then
        if not V.parking then
            V.parkingRoot=CreateFrame("Frame",nil,UIParent);V.parkingRoot:Hide()
            V.parking=CreateFrame("Frame",nil,V.parkingRoot,"ObjectiveTrackerContainerTemplate")
            V.parking.modules={};V.parking.init=false;V.parking.needsSorting=false
            V.parking:SetScript("OnShow",nil);V.parking:SetScript("OnSizeChanged",nil)
            V.parking:OnLoad();V.parking:SetSize(320,480);V.parking:SetPoint("TOPLEFT");V.parking:Hide()
            manager:AddContainer(V.parking)
        end
        if current~=V.parking then V.originalContainer=current;manager:SetModuleContainer(module,V.parking) end
        V.parking:Hide()
    elseif not replace and V.originalContainer and current==V.parking then manager:SetModuleContainer(module,V.originalContainer) end
    if not V.managerHooked and type(hooksecurefunc)=="function" then
        V.managerHooked=true
        hooksecurefunc(manager,"SetModuleContainer",function(_,moved) if moved==module then ns.After("questModuleOwnership",V.SyncNativeTracker) end end)
    end
end
function V.ShowTracker(resetPosition)
    ns.db.settings.questTrackerEnabled=true
    ns.db.settings.questTrackerCollapsed=false
    if resetPosition then
        ns.db.settings.positions.questTracker=nil
        if V.tracker then
            V.tracker:ClearAllPoints()
            V.tracker:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-180,-250)
            V.AnchorTracker(V.tracker)
        end
    end
    V.UpdateTracker()
end
function V.UpdateTracker()
    if not ns.db or not ns.char then return end
    if not combat() then
        V.CreateTracker()
        ns.Invoke("questTrackerNativeSync",V.SyncNativeTracker)
    end
    local f=V.tracker
    if not f then return end
    f:SetShown(ns.db.settings.questTrackerEnabled~=false)
    if not f:IsShown() then return end
    f.background:SetShown(ns.db.settings.trackerTransparent==false)
    local width=math.max(240,ns.db.settings.questTrackerWidth or 320);local height=math.max(140,ns.db.settings.questTrackerHeight or 480)
    f:SetWidth(width);f:SetHeight(ns.db.settings.questTrackerCollapsed and 24 or height);f.title:SetWidth(width-20)
    f:SetScale((ns.db.settings.windowScales or {}).questTracker or ns.db.settings.scale or 1)
    local rows,known=records();f.title:SetText((ns.db.settings.questTrackerCollapsed and "+ " or "- ").."Quests ("..(known and #rows or "?")..")")
    f.viewport:SetShown(not ns.db.settings.questTrackerCollapsed);f.notice:Hide();if ns.db.settings.questTrackerCollapsed then return end
    U.Release(f.body);f.body:SetWidth(width)
    ns.char.questTrackerCollapsed=ns.char.questTrackerCollapsed or {};ns.char.questTrackerZones=ns.char.questTrackerZones or {}
    local zones,order={},{}
    for _,entry in ipairs(rows) do if not zones[entry.zone] then zones[entry.zone]={};order[#order+1]=entry.zone end;table.insert(zones[entry.zone],entry) end
    local y=0
    for _,zone in ipairs(order) do local name=zone
        local closed=ns.char.questTrackerZones[name]
        local z=U.New("Button",f.body,nil,"zone");z:SetPoint("TOPLEFT",0,-y);z:SetSize(width,24)
        z.symbol=z.symbol or z:CreateTexture(nil,"ARTWORK");z.symbol:SetSize(12,12);z.symbol:SetPoint("TOPLEFT",0,-2)
        z.symbol:SetTexture(closed and "Interface\\Buttons\\UI-PlusButton-UP" or "Interface\\Buttons\\UI-MinusButton-UP")
        local heading=U.Label(z,name.." ("..#zones[name]..")",17,0,width-20,"GameFontNormal");heading:SetTextColor(1,.82,.3);heading:SetShadowColor(0,0,0,1);heading:SetShadowOffset(1,-1)
        z:SetScript("OnClick",function() ns.char.questTrackerZones[name]=not ns.char.questTrackerZones[name];V.UpdateTracker() end);y=y+26
        if not closed then for _,entry in ipairs(zones[name]) do
            local q=entry.quest;local expanded=not ns.char.questTrackerCollapsed[q.id]
            local b=U.New("Button",f.body,nil,"quest");b:SetPoint("TOPLEFT",15,-y);b:SetWidth(width-15);b:RegisterForClicks("LeftButtonUp","RightButtonUp")
            local title=U.Label(b,"["..(entry.level>0 and entry.level or "?").."] "..q.title..(entry.complete and " (Complete)" or ""),32,0,width-62,"GameFontNormal")
            title:SetTextColor(difficulty(q));title:SetShadowColor(0,0,0,1);title:SetShadowOffset(1,-1)
            local h=title:GetStringHeight()+4
            local chevron=U.New("Button",b,nil,"collapse");chevron:SetPoint("TOPLEFT",0,-2);chevron:SetSize(12,12)
            chevron:SetNormalTexture(expanded and "Interface\\Buttons\\UI-MinusButton-UP" or "Interface\\Buttons\\UI-PlusButton-UP")
            local focus=U.New("Button",b,nil,"focusQuest");focus:SetPoint("TOPLEFT",14,-1);focus:SetSize(15,15)
            focus:SetNormalTexture("Interface\\Buttons\\UI-RadioButton")
            local focused=ns.char.questFocus==q.id
            focus:GetNormalTexture():SetTexCoord(focused and .5 or 0,focused and .75 or .25,0,1)
            focus:SetScript("OnClick",function() V.Focus(q) end)
            U.Tooltip(focus,focused and "Unfocus quest" or "Focus quest destination")
            chevron:SetScript("OnClick",function() ns.char.questTrackerCollapsed[q.id]=not ns.char.questTrackerCollapsed[q.id];V.UpdateTracker() end)
            if expanded then
                local lines={};for _,o in ipairs(entry.objectives or {}) do
                    lines[#lines+1]=(ns.Safe(o.finished)==true and "|cff80c080" or "|cffdeded0")..ns.Safe(o.text,"Objectives loading").."|r"
                end
                local t=U.Label(b,entry.complete and "Ready to turn in" or #lines>0 and table.concat(lines,"\n") or "Objectives loading",44,-h,width-74,"GameFontHighlightSmall");t:SetShadowColor(0,0,0,1);t:SetShadowOffset(1,-1);h=h+t:GetStringHeight()+3
            end
            b:SetHeight(h)
            b:SetScript("OnClick",function(self,button)
                if button=="RightButton" then V.Menu(self,{{"Show on map",function() V.Details(q) end},{ns.char.questFocus==q.id and "Unfocus quest" or "Focus quest destination",function() V.Focus(q) end},{"Untrack quest",function() V.Untrack(q) end},{expanded and "Collapse objectives" or "Expand objectives",function() ns.char.questTrackerCollapsed[q.id]=expanded;V.UpdateTracker() end}})
                elseif IsShiftKeyDown() then
                    local chat=type(ChatEdit_GetActiveWindow)=="function" and ChatEdit_GetActiveWindow()
                    local link=native("GetQuestLink",q.id)
                    if chat then
                        if not link and type(GetQuestLink)=="function" then link=ns.Safe(GetQuestLink(q.id)) end
                        if link then chat:Insert(link) else ns.Message("The native quest link is unavailable.") end
                    else V.Untrack(q) end
                else V.Details(q) end
            end)
            U.Tooltip(b,q.title,{"Click: native quest details. Right-click: options. Shift-click: Untrack / chat link."})
            y=y+h+5
        end end
    end
    if #rows==0 then
        local empty=ns.db.settings.questTrackerZone and "No watched quests mapped to this area." or "No watched quests."
        U.Label(f.body,known and empty or "Native watched quests are unavailable.",0,0,width,"GameFontHighlightSmall");y=24
    end
    f.body:SetHeight(math.max(1,y));f.viewport:EnableMouseWheel(ns.db.settings.questTrackerScroll==true)
    if not ns.db.settings.questTrackerScroll then f.viewport:SetVerticalScroll(0) end
    if y>f.viewport:GetHeight() then f.notice.text:SetWidth(width-24);f.notice.text:SetText(ns.db.settings.questTrackerScroll and "Mouse wheel: watched quests" or "Layout: collapse objectives / zones or resize");f.notice:Show() end
end
for _,event in ipairs({"PLAYER_REGEN_ENABLED","PLAYER_ENTERING_WORLD","QUEST_WATCH_LIST_CHANGED","ADDON_LOADED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"}) do ns.On(event,function() ns.After("questTrackerRefresh",V.UpdateTracker) end) end
local function refreshWatchedObjectives()
    if V.tracker and V.tracker:IsShown() then ns.After("questTrackerRefresh",V.UpdateTracker) end
end
ns.On("QUEST_WATCH_UPDATE",refreshWatchedObjectives)
ns.On("QUEST_LOG_UPDATE",refreshWatchedObjectives)
ns.On("ZONE_CHANGED_NEW_AREA",refreshWatchedObjectives)
ns.On("ZONE_CHANGED",refreshWatchedObjectives)
ns.On("QUEST_REMOVED",function(id) if ns.char then V.ClearFocus(ns.Safe(id)) end end)
ns.On("UNIT_QUEST_LOG_CHANGED",function(unit)
    if ns.Safe(unit)=="player" then refreshWatchedObjectives() end
end)
ns.Listen("SETTINGS_CHANGED",function() ns.After("questTrackerRefresh",V.UpdateTracker) end)
ns.Listen("STATE_CHANGED",function(kind) if ns.Changed(kind,"quests","identity","watch") then ns.After("questTrackerRefresh",V.UpdateTracker,0.25) end end)

ns.On("QUEST_ACCEPTED",function(first,second)
    if not ns.char or ns.db.settings.questTrackerAutoWatch==false then return end
    local id=ns.Safe(second) or ns.Safe(first)
    if type(id)=="number" and C_QuestLog and C_QuestLog.AddQuestWatch then
        ns.char.manuallyUntracked=ns.char.manuallyUntracked or {};ns.char.manuallyUntracked[id]=nil
        C_QuestLog.AddQuestWatch(id)
    end
end)

ns.On("QUEST_WATCH_LIST_CHANGED",function(id,added)
    if not ns.char then return end
    if ns.Safe(added)==false then V.ClearFocus(ns.Safe(id)) end
    ns.Emit("STATE_CHANGED","watch")
end)
