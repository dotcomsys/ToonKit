local addonName, ns = ...
local M,U=ns.Main,ns.UI
U.revision="functional-ui-20261117"
local settings=M.Settings
local journey=M.Journey

local function campaign(J)
    M.Action("Current action",function() M.OpenJourneyPage("Now") end,200)
    local sources=U.Options(M.body,{
        {value="toonkit",label="ToonKit guides"},
        {value="polestar",label="Polestar guides"},
    },ns.char.journeyGuideSource or "toonkit",M.width-16,function(value)
        J.SetGuideSource(value);M.Render()
    end)
    sources:SetPoint("TOPLEFT",8,M.y);M.y=M.y-sources:GetHeight()-10
    local path=J.Campaign()
    if #path==0 then
        M.Line("No starting guide matches this character. You can still choose a zone guide.")
        M.Action("Choose a guide",function() M.OpenJourneyPage("Routes") end,200)
        return
    end
    local current=J.Selected()
    if current.category~="Leveling" then current=J.Recommended() end
    local band=M.campaignBand or math.max(1,math.min(6,math.floor((ns.State.level-1)/10)+1))
    local choices={}
    for i=1,6 do choices[i]={value=i,label=(i*10-9).."–"..(i*10)} end
    local tabs=U.Options(M.body,choices,band,M.width-16,function(value) M.campaignBand=value;M.Render() end)
    tabs:SetPoint("TOPLEFT",8,M.y);M.y=M.y-tabs:GetHeight()-12
    local rows={}
    for _,route in ipairs(path) do
        if route.min<=band*10 and route.max>=band*10-9 then rows[#rows+1]=route end
    end
    local selected=M.Choose(rows,"campaignSelection","Choose a leveling segment",function(route)
        return (route.id==current.id and "Current: " or "")..route.name
    end)
    local route=rows[selected or 0]
    if not route then M.Line("No linked segment covers this level range.");return end
    M.Heading(route.name)
    local following=J.CampaignNext(route)
    if following then M.Line("Next guide: "..following.name,"GameFontHighlightSmall") end
    if route.min>ns.State.level then
        M.Line("Available at level "..route.min..".","GameFontHighlightSmall")
    else
        M.Action(route.original and "Follow this route" or "Follow campaign from here",function()
            M.journeyPage="Now"
            if not J.Automatic(route.id) then M.journeyPage="Campaign" end
            M.Render()
        end,250)
    end
end

function M.Journey()
    local J=ns.Journey
    if ns.db.settings.modules.journey and (M.routePicker or not M.journeyPage or M.journeyPage=="Now" or M.journeyPage=="Campaign") then
        local withDungeons=(ns.char.dungeonJourney or {}).enabled==true
        local current=J.Speedrunning() and "speedrun" or withDungeons and "dungeons" or "questing"
        local mode=U.Options(M.body,{
            {value="questing",label="Questing",tooltip={"Follow the questing campaign. Individually included dungeon quests can still appear."}},
            {value="dungeons",label="Questing + dungeons",tooltip={"Keep your questing progress and include eligible dungeon quests by default."}},
            {value="speedrun",label="Outdoor only",tooltip={"Follow outdoor leveling without automatic dungeon detours."}},
        },current,M.width-16,function(value)
            if value=="speedrun" then
                J.SetGoal("speedrun")
            else
                ns.DungeonJourney.Configure(value=="dungeons",true)
                if J.Speedrunning() then J.SetGoal("casual") else J.Advance();ns.Emit("STATE_CHANGED") end
            end
            M.Render()
        end)
        mode:SetPoint("TOPLEFT",8,M.y);M.y=M.y-mode:GetHeight()-10
    end
    if M.journeyPage=="Campaign" and ns.db.settings.modules.journey then return campaign(J) end
    if M.routePicker or M.journeyPage and M.journeyPage~="Now" then
        return journey()
    end
    M.preparationOpen=false;M.journeyPage="Now"
    if not ns.db.settings.modules.journey then
        M.Line("Journey is off.");M.Action("Enable Journey",function() ns.db.settings.modules.journey=true;ns.Emit("STATE_CHANGED") end,200);return
    end
    local view=J.View();local C=ns.Connected
    if M.JourneyBranchChoices(view) then return end
    local goalKey=view.goal and view.goal.id or view.title
    if M.journeyGoalKey~=goalKey then M.journeyGoalKey=goalKey;M.journeyNotes=false end
    local top=M.y;local height=math.max(240,M.scroll:GetHeight()+top-32)
    local leftWidth=math.floor((M.width-24)*.55)
    local task=C.Pane(M.body,leftWidth,height,8,top,"journeyCurrent")
    local guide=C.Pane(M.body,M.width-leftWidth-24,height,leftWidth+16,top,"journeyGuide",true)
    C.Read(task,function()
        M.Line(view.route.name or "Journey","GameFontNormal")
        if view.step then M.Line(view.progress,"GameFontHighlightSmall") end
        M.y=M.y-14
        local row=U.New("Button",M.body,nil,"journeyCurrentAction");row:SetPoint("TOPLEFT",8,M.y);row:SetWidth(M.width-16)
        row.icon=row.icon or row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",0,-2);row.icon:SetSize(20,20)
        local detail=J.ObjectiveDetail(view.goal)
        M.JourneyRowDetail(row,view.goal,false,nil,M.width-16,0,-2);row.source:Hide()
        local inset=detail.item and 54 or 28
        local title=U.Label(row,view.title,inset,-2,M.width-inset-26,"GameFontNormalLarge")
        row:SetHeight(math.max(34,title:GetStringHeight()+10));M.y=M.y-row:GetHeight()-6
        row:SetScript("OnClick",function() J.Destination(J.View()) end)
        U.Tooltip(row,view.title,{view.actionNote or view.travelInstructions or view.hint})
        if view.amount then M.Line(view.amount,"GameFontNormal") end
        if view.quest then M.Line(view.quest,"GameFontHighlightSmall") end
        local point=view.pickup or view.point
        local mapInfo=point and point.map and ns.API.Call("C_Map","GetMapInfo",point.map)
        local destination=type(mapInfo)=="table" and ns.Safe(mapInfo.name)
        if view.travelStop then M.Line(view.travelStop,"GameFontNormal") end
        if view.approachCaption then M.Line(view.approachCaption,"GameFontHighlightSmall")
        elseif type(destination)=="string" and destination~="" then M.Line(destination,"GameFontHighlightSmall") end
        if view.pickup then M.Line("First: "..J.GoalText(view.pickup),"GameFontNormal")
        elseif view.contact then M.Line(view.contact,"GameFontNormal") end
        local note
        if view.blocked then note=view.hint
        elseif view.route.live or ns.db.settings.guideNotes~=false then
            note=view.approach and view.actionNote or (not view.approach and (view.travelInstructions or view.actionNote or view.hint))
        end
        if note and note~="" and note~=view.title and note~=view.contact then
            local brief=note:match("^[^\n]+") or note
            if #brief>180 then brief=(brief:sub(1,180):match("^(.*)%s+%S*$") or brief:sub(1,180)).."..." end
            M.Line(brief,"GameFontHighlightSmall")
        end
        if view.paused then M.Line("Paused","GameFontNormal") end
        if ns.char.customWaypoint then
            M.Action("Resume guide destination",function() ns.char.customWaypoint=nil;ns.char.questFocus=nil;ns.Navigation.Refresh();ns.Emit("STATE_CHANGED") end,230)
        end
    end,"task:"..tostring(goalKey))
    task.scroll:ClearAllPoints();task.scroll:SetPoint("TOPLEFT",14,-14);task.scroll:SetPoint("BOTTOMRIGHT",-32,87);C.UpdateScroll(task)
    local buttons={{label=view.pickup and "Prerequisite" or "Map",run=function() J.Destination(J.View()) end,enabled=view.point~=nil or view.pickup~=nil or view.goal and view.goal.quest~=nil},
        {label="Undo",run=J.Undo},{label=view.paused and "Resume" or "Pause",run=J.Pause},
        {label="Skip task",run=function() J.Skip(J.View()) end,enabled=view.goal~=nil and not view.paused}}
    local width=(task:GetWidth()-34)/4
    for index,action in ipairs(buttons) do
        local b=U.Button(task,action.label,width,action.run);b:SetPoint("BOTTOMLEFT",12+(index-1)*(width+3),46);b:SetEnabled(action.enabled~=false)
    end
    local play=U.Button(task,"Continue in guide",task:GetWidth()-24,function() ns.SetSetting("guide",true);U.main:Hide() end);play:SetPoint("BOTTOMLEFT",12,12)
    if view.manual and not view.paused and not view.blocked then
        local done=U.Button(task,view.travel and "Arrived" or "Done",130,function() J.Confirm(J.View()) end)
        done:SetPoint("TOPRIGHT",-14,-12)
        -- Keep manual acknowledgment separate from Skip; native quest actions
        -- never gain a synthetic Done control.
        task.scroll:SetPoint("TOPLEFT",14,-48);C.UpdateScroll(task)
    end
    C.Read(guide,function()
        if view.nextTitle and view.nextTitle~="" then
            M.Line("Up next","GameFontNormal")
            M.Line(view.nextTitle,"GameFontHighlight")
            M.y=M.y-12
        end
        if view.manualNext and not view.paused then M.Action("Continue to next guide",J.NextRoute,200) end
        if view.stopPreview and #view.stopPreview>0 then
            M.Line("At this stop","GameFontNormal")
            for _,text in ipairs(view.stopPreview) do M.Line(text,"GameFontHighlightSmall") end
        end
        local action=view.pickup or view.goal
        local destination=not view.paused and action and ns.Navigation.FinalLocation(action)
        if destination and view.approach and not view.blocked then
            local label=action.t=="accept" and "Show quest pickup" or action.t=="turnin" and "Show quest turn-in" or "Show final destination"
            M.Action(label,function() ns.Navigation.ShowDestination(destination) end,200)
        end
        if view.tripChecklist then M.Line(view.tripChecklist,"GameFontHighlightSmall") end
        if view.route.live then
            M.Line("Quest log mode follows accepted quests. Resume automatic leveling for a route with ordered pickups and travel.","GameFontHighlightSmall")
        end
        M.Action(view.route.live and "Resume automatic leveling" or "Find my next route",J.Automatic,230)
        M.Action("Quest priorities",function() M.OpenJourneyPage("Planning",nil,"Priorities") end,200)
        M.Action("Leveling campaign",function() M.OpenJourneyPage("Campaign") end,200)
        M.Action("Choose a guide",function() M.OpenJourneyPage("Routes") end,200)
        M.Action("Review route",function() M.OpenJourneyPage("Review") end,200)
        local tools=M.JourneyTools(M.body,200);tools:SetPoint("TOPLEFT",8,M.y);M.y=M.y-tools:GetHeight()-7
        M.y=M.y-10
        local instructions=view.travelInstructions or view.actionNote or view.hint
        if instructions and instructions~="" then
            M.Action(M.journeyNotes and "Hide instructions" or view.approach and "Travel directions" or "Full instructions",function() M.journeyNotes=not M.journeyNotes;M.Render() end,200)
        end
        if M.journeyNotes then
            M.y=M.y-8;M.Line(instructions or "")
            local detail=J.ObjectiveDetail(view.goal);if detail.source then M.Line(detail.source,"GameFontHighlightSmall") end
        end
    end,"guide:"..tostring(goalKey))
    M.y=top-height-8
end

local function toggle(key,label,detail)
    M.Row(label..(detail and "\n"..detail or ""),ns.db.settings[key] and "Turn off" or "Turn on",function()
        ns.SetSetting(key,not ns.db.settings[key])
    end,detail and {detail})
end

-- Keep everyday choices together. Detailed tools remain available on request.
function M.Settings()
    if M.helpOpen then
        M.Heading("Getting started")
        M.Line("Take one task at a time. You can always come back here using the Help button.")
        M.Row("What should I do next?\nOpen Journey to see your current task and directions.","Open Journey",function() M.OpenJourneyPage("Now") end)
        M.Row("Where are my quests?\nYour quest log shows the quests you have already accepted.","My quests",function() ns.QuestWorkspace.OpenLog() end)
        M.Row("Where are my items?\nOpen your bags to search for an item or see your free space.","Open bags",function() ns.Inventory.Toggle() end)
        M.Row("Is this equipment useful?\nPick a slot to find items, compare them and see their sources.","Find equipment",function() M.OpenQuickGear() end)
        M.Heading("A few useful things to know")
        M.Line("Quest progress updates as you play. For travel or other manual tasks, press Done only after you have finished. Skip leaves a task unfinished; Undo reverses your last supported guide change.")
        M.Line("Show destination marks a known location on your map. The arrow points toward it; follow the terrain and roads yourself.")
        M.Line("Press Escape to close the journal. To open it again, click the ToonKit minimap button or type /tk in chat.")
        M.Action("Back to settings",function() M.helpOpen=false;M.Render() end,230)
        return
    end
    local tabs=U.Options(M.body,{{value="everyday",label="Everyday settings"},{value="advanced",label="Advanced settings"}},M.advancedSettings and "advanced" or "everyday",M.width-16,function(value)
        M.advancedSettings=value=="advanced";M.Render()
    end)
    tabs:SetPoint("TOPLEFT",8,M.y);M.y=M.y-tabs:GetHeight()-12
    if M.advancedSettings then
        return settings()
    end
    M.Heading("Make yourself comfortable")
    M.Line("Choose what you want to see while playing. Your quests, routes and saved plans stay intact.")
    toggle("guide","Route guide","Show your current route action while playing.")
    toggle("questTrackerEnabled","Quest tracker","Show tracked quests by zone and difficulty.")
    toggle("xpDisplay","XP and status bar","Show the XP and utility bar.")
    toggle("inventory","ToonKit bags","Organize your carried items in one bag window.")
    toggle("mapPins","Guide and book map markers")
    toggle("questMapPins","Quest map markers")
    toggle("minimap","Minimap button")
    toggle("locked","Lock window positions")
    M.Heading("Reading size")
    local sizes=U.Options(M.body,{{value=1,label="Normal"},{value=1.15,label="Larger"},{value=1.3,label="Largest"}},ns.db.settings.textScale,M.width-16,function(value) ns.Preferences.Set("textScale",value) end)
    sizes:SetPoint("TOPLEFT",8,M.y);M.y=M.y-sizes:GetHeight()-12
    M.Heading("My role")
    M.Line("Used for gear advice. This does not change your talents.","GameFontHighlightSmall")
    local roles=U.Options(M.body,{{value="auto",label="Detect from talents"},{value="tank",label="Tank"},{value="healer",label="Healer"},{value="melee",label="Melee"},{value="ranged",label="Ranged"},{value="caster",label="Caster"}},ns.char.playstyle,M.width-16,function(value)
        ns.char.playstyle=value;ns.Talents.Detect();ns.Emit("STATE_CHANGED")
    end)
    roles:SetPoint("TOPLEFT",8,M.y);M.y=M.y-roles:GetHeight()-12
    M.Action("Center my windows",function()
        ns.db.settings.positions={};ns.Preferences.ApplyPositions()
    end,230)
    M.Heading("More options")
    M.Line("Appearance, bag categories, map layers and other detailed preferences are available when you need them.","GameFontHighlightSmall")
    M.Action("Open advanced settings",function() M.advancedSettings=true;M.Render() end,230)
    M.Action("Copy troubleshooting report",ns.ShowDiagnostics,250)
end
