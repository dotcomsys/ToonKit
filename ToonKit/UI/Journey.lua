local addonName, ns = ...

local U,M,J=ns.UI,ns.Main,ns.Journey

local actionIcons

local function at(widget,x,y) widget:SetPoint("TOPLEFT",x,y);return widget end

function M.OpenJourneyPage(page,query,section)
    return M.OpenPage("Journey",function()
        M.journeyPage=page=="Routes" and "Now" or page or "Now"
        M.routePicker=page=="Routes";M.routeStep=nil;M.preparationOpen=false
        if page=="Routes" then M.routeQuery=query or "";M.routePreview=ns.char.route end
        if page=="Campaign" then M.campaignBand=nil end
        if page=="Planning" and section then M.tripPlanningSection=section end
    end)
end

local function openJourney() M.OpenJourneyPage("Now") end

function M.JourneyOptions(command)

    if command=="routes" or command=="dungeons" then return M.OpenJourneyPage("Routes",command=="dungeons" and "dungeon" or "") end
    if command=="review" then return M.OpenJourneyPage("Review") end
    if command=="timing" then return M.OpenJourneyPage("Timing") end
    if command=="history" then return M.OpenJourneyPage("History") end
    if command=="planning" then return M.OpenJourneyPage("Planning") end
    local view=J.View()

    if view.paused and (command=="skip" or command=="confirm") then ns.Message("Resume Journey before changing the current action.");return end

    if command=="automatic" then M.routePicker=false;M.journeyPage="Now";J.Automatic()

    elseif command=="skip" then if view.goal then J.Skip(view) elseif view.index then J.Mark(view.index,"skipped") end

    elseif command=="retrack" then J.Retrack()

    elseif command=="undo" then J.Undo()

    elseif command=="confirm" then J.Confirm(view)

    elseif command=="refresh" then ns.State.Refresh("all") end

    if command=="guide" then ns.SetSetting("guide",true) end

    M.Render()

end

local commands={{value="timing",label="My route timings"},{value="planning",label="Plan class quests and dungeon trips"},{value="guide",label="Show floating guide"},{value="review",label="Review route steps"},{value="history",label="My recorded quest history"},{value="routes",label="Choose a different route"},{value="dungeons",label="Dungeon quest routes"},{value="automatic",label="Choose automatically for my character"},{value="skip",label="Skip this action"},{value="undo",label="Undo my last action"},{value="retrack",label="Retrack skipped actions in this guide"},{value="confirm",label="Confirm current action manually"},{value="refresh",label="Refresh game data"}}

function M.JourneyTools(parent,width,floating)
    return U.Button(parent,"Guide tools",width,function(button)
        local choices={}
        local function add(label,command)
            choices[#choices+1]={label,function() M.JourneyOptions(command) end}
        end
        if floating then
            add("Undo last manual action","undo")
            add("Review route","review")
            add("Choose a guide","routes")
        end
        add("Quest priorities and raid preparation","planning")
        add("Quest history","history")
        add("Route timings","timing")
        add("Retrack skipped actions","retrack")
        choices[#choices+1]={"Guide settings",function() M.OpenSettings("Journey","Guide") end}
        ns.QuestWorkspace.Menu(button,choices,250)
    end)
end

-- Share the same quest-state markers in the journal and floating guide.

function M.JourneyIcon(goal,done,evidence)

    if evidence=="skipped" then return "Interface\\Buttons\\UI-GroupLoot-Pass-Up" end

    local kind=goal and goal.t

    if kind=="accept" then return evidence=="native-accepted" and "Interface\\GossipFrame\\IncompleteQuestIcon" or "Interface\\GossipFrame\\AvailableQuestIcon" end

    if kind=="turnin" then

        local ready=done or goal.quest and ns.Safe(ns.API.Call("C_QuestLog","IsComplete",goal.quest),false)

        return ready and "Interface\\GossipFrame\\ActiveQuestIcon" or "Interface\\GossipFrame\\IncompleteQuestIcon"

    end

    if done then return "Interface\\RaidFrame\\ReadyCheck-Ready" end

    if (kind=="kill" or kind=="collect" or kind=="interact") and actionIcons and actionIcons[kind] then return actionIcons[kind] end
    if goal and goal.quest then return "Interface\\GossipFrame\\IncompleteQuestIcon" end

    return actionIcons and actionIcons[kind] or "Interface\\Icons\\INV_Misc_Map_01"

end

function M.JourneyRowDetail(row,goal,done,evidence,width,iconX,iconY)

    local detail=J.ObjectiveDetail(goal)

    row.icon:SetTexture(M.JourneyIcon(goal,done,evidence))

    if not row.itemButton then

        row.itemButton=CreateFrame("Button",nil,row);row.itemButton:SetSize(22,22)

        row.itemButton.art=row.itemButton:CreateTexture(nil,"ARTWORK");row.itemButton.art:SetAllPoints()

    end

    row.itemButton:ClearAllPoints();row.itemButton:SetPoint("TOPLEFT",iconX+21,iconY)

    row.itemButton:SetShown(detail.item~=nil)

    if detail.item then

        row.itemButton.art:SetTexture(detail.icon or "Interface\\Icons\\INV_Misc_Bag_08")

        U.Tooltip(row.itemButton,detail.name,{detail.source or "Required by this route action."},detail.link)

    end

    local inset=iconX+(detail.item and 50 or 24)

    row.source=row.source or U.Label(row,"",inset,0,width-inset,"GameFontHighlightSmall")

    row.source:SetWidth(math.max(40,width-inset));row.source:SetText(detail.source or "");row.source:SetShown(detail.source~=nil)

    return inset,detail.source and row.source:GetStringHeight()+5 or 0

end

function M.JourneyBranchChoices(view)
    local conditions=view.goal and view.goal.soloWhen or view.step and view.step.soloWhen or {}
    for _,condition in ipairs(conditions) do
        if condition.k=="group" or condition.k=="dungeon" and not J.Speedrunning() then
            local key=condition.k..":"..tostring(condition.q or condition.map)
            if (ns.char.sourceRouteChoices or {})[key]==nil then
                M.Line(condition.k=="group" and "This guide has an optional group quest (#"..condition.q..")." or "This guide offers an optional dungeon branch: "..(condition.name or "Dungeon #"..condition.map),"GameFontNormal")
                M.Line("Choose whether to include it. Your choice does not complete any quests.","GameFontHighlightSmall")
                local controls=U.Options(M.body,{{value=true,label="Include this branch"},{value=false,label="Leave it out"}},nil,M.width-16,function(value)
                    ns.char.sourceRouteChoices=ns.char.sourceRouteChoices or {};ns.char.sourceRouteChoices[key]=value;ns.Emit("STATE_CHANGED")
                end)
                controls:SetPoint("TOPLEFT",8,M.y);M.y=M.y-controls:GetHeight()-12
                return true
            end
        end
    end
    return false
end

function M.Journey()

    if not ns.db.settings.modules.journey then M.Line("Journey is turned off.");M.Action("Enable Journey",function() ns.db.settings.modules.journey=true;ns.Emit("SETTINGS_CHANGED");ns.Emit("STATE_CHANGED") end,190);return end

    if M.journeyPage=="Planning" then

        M.Action("Back to my current action",function() M.journeyPage="Now";M.Render() end,240)

        M.RoutePlanning();return

    end

    if M.journeyPage=="History" then

        M.Action("Back to my current action",function() M.journeyPage="Now";M.Render() end,240)

        M.Line("My recorded quest history","GameFontNormalLarge")

        M.Line("Recorded locally from acceptance and turn-in events while ToonKit is running. Locations are your position at the event.","GameFontHighlightSmall")

        local history=ns.char.questHistory or {}

        local selected=M.Choose(history,"questHistorySelection","Choose a quest event",function(r) return (r.kind=="turnedIn" and "Turned in: " or "Accepted: ")..ns.QuestSupplies.Name(r.id) end)

        if not selected then M.Line("No events recorded yet. Older completion flags do not contain dates or order.") else

            local r=history[selected];M.Heading(ns.QuestSupplies.Name(r.id))

            M.Line((r.time and type(date)=="function" and date("%Y-%m-%d %H:%M",r.time) or "Time unavailable").." | Level "..(r.level or "?").." | Quest #"..r.id)

        end

        return

    end

    if M.routePicker or M.journeyPage=="Review" then

        M.Action("Back to my current action",function() M.routePicker=false;M.journeyPage="Now";M.scroll:SetVerticalScroll(0);M.Render() end,240)

        M.JourneyReview();return

    end

    local view=J.View()

    M.Line(view.route.name,"GameFontNormalLarge")

    M.Line(ns.State.className.."  |  "..view.progress.."  |  "..view.status,"GameFontHighlightSmall")


    if M.journeyDetails then
    M.Line(view.route.live and "Live quest log" or "Source guide: "..(view.route.source or "Unrecorded source"),"GameFontHighlightSmall")
    if view.classRoute then local detour=view.classRoute

        M.Row(view.classReminder,"Follow class quest",function() J.Select(detour.id) end)

    end

    local gaps=not J.Speedrunning() and ns.TripPlanning.ZoneGaps(view.route) or {}

    local preparationShown=M.preparationOpen==true or (not ns.db.settings.simpleUI and M.preparationOpen~=false)
    if not J.Speedrunning() and (not ns.db.settings.simpleUI or #gaps>0) then
        M.Row("Optional preparation: "..#gaps.." quest(s) to review.",preparationShown and "Hide preparation" or "Show preparation",function() M.preparationOpen=not preparationShown;M.Render() end)
    end

    local outside=J.QuestsOutsideRoute(view.route)

    if #outside>0 then

        M.Row(#outside.." quest(s) in your log are not covered by the remaining route. First: "..outside[1].title,"Follow quest log",function() J.Select("live") end)

    end

    M.y=M.y-12

    if view.route.category~="Dungeon" then

        local dungeon,count=J.DungeonSuggestion()

        if dungeon then M.Row(dungeon.name.." | "..count.." in your quest log","Follow quests",function() J.Select(dungeon.id) end) end

    end

    end -- Optional route suggestions
    if view.step and view.step.text and view.step.text~=view.title then M.Line(view.step.text,"GameFontNormalLarge") end

    local objectives={};for i,objective in ipairs(view.objectives or {}) do if i<=3 then objectives[#objectives+1]=objective end end

    if #objectives==0 then M.Heading(view.title) end

    for i,objective in ipairs(objectives) do

        local row=U.New("Button",M.body,"BackdropTemplate","journeyObjective");row:SetPoint("TOPLEFT",8,M.y);row:SetSize(M.width-16,38)

        row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8});row:SetBackdropColor(objective.current and .16 or .055,objective.current and .12 or .05,.035,1);row:SetBackdropBorderColor(.35,.27,.12,1)

        row.icon=row.icon or row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(16,16);row.icon:SetPoint("TOPLEFT",10,-12);row.icon:SetTexture(M.JourneyIcon(objective.goal,objective.done,objective.evidence))

        local inset,sourceHeight=M.JourneyRowDetail(row,objective.goal,objective.done,objective.evidence,M.width-32,10,-10)

        local label=U.Label(row,(objective.evidence=="skipped" and "Skipped: " or "")..(objective.taskTitle or objective.text)..(objective.amount and "  "..objective.amount or ""),inset,-10,M.width-inset-(objective.bundled and 122 or 108),objective.current and "GameFontNormalLarge" or "GameFontHighlight");label:SetWordWrap(true)

        local members=M.RenderTaskMembers(row,objective.bundled and objective or nil,M.width-40,label:GetStringHeight()+18)

        row.source:ClearAllPoints();row.source:SetPoint("TOPLEFT",inset,-14-label:GetStringHeight()-members)

        local height=math.max(40,label:GetStringHeight()+20+sourceHeight+members);row:SetHeight(height);M.y=M.y-height-3

        row:SetScript("OnClick",function() if objective.current then J.Destination() else J.GoalWaypoint(objective.goal) end end)

        local skip=U.Button(row,objective.bundled and "Skip task" or "Skip",objective.bundled and 100 or 58,function() local current=J.View();if current.goal and current.goal.id==objective.goal.id then J.Skip(current) end end)

        skip:SetPoint("TOPRIGHT",-8,-8);skip:SetShown(objective.current and not objective.done);skip:SetEnabled(not view.paused)

        if objective.bundled then U.Tooltip(skip,"Skip task",{"Skip the unfinished objectives in this task. Quests stay in your quest log. Undo restores the task."})

        else U.Tooltip(skip,"Skip, not complete",{"Move on without marking this quest completed. Unaccepted dependent quests in this route are skipped too. Undo restores this action."}) end

        U.Tooltip(row,objective.text,{objective.done and (objective.evidence=="skipped" and "Skipped manually; this is not a completed objective." or objective.evidence=="manual" and "Marked manually." or objective.evidence=="native-accepted" and "Quest accepted; its objectives and turn-in are separate route actions." or "Completion recorded by the existing quest/route evidence.") or objective.current and view.hint or "Upcoming objective. Click to show its destination."})

    end

    M.y=M.y-10

    if view.contact then M.Line(view.contact) end

    if view.quest then M.Line(view.quest,"GameFontHighlightSmall") end

    if view.amount then M.Line("Progress: "..view.amount,"GameFontNormal") end

    if view.travelInstructions and view.travelInstructions~=view.title then M.Line(view.travelInstructions) elseif view.note then M.Line(view.note) end

    if view.travelItinerary then M.Line("Travel itinerary","GameFontNormal");M.Line(view.travelItinerary) end

    M.Line(view.hint,"GameFontHighlightSmall")

    if M.journeyDetails and #(view.scheduledLater or {})>0 then

        M.Line("Accepted quests scheduled for later","GameFontNormal")

        for i=1,math.min(2,#view.scheduledLater) do M.Line(view.scheduledLater[i].text,"GameFontHighlightSmall") end

    end

    if M.journeyDetails and view.tripReminder then M.Line(view.tripReminder,"GameFontNormal") end

    if M.journeyDetails and view.serviceReminder and not view.service then M.Line(view.serviceReminder,"GameFontNormal") end
    if view.goal and view.goal.t=="vendor" and ns.InventoryActions.merchantOpen then
        M.Action("Review gray-item sales",function() ns.InventoryActionView.Show("sell",{query="junk"}) end,240)
        M.Action("Open bags to choose items",function() ns.Inventory.Show() end,240)
    end

    if view.prerequisite then M.Line("Pickup: "..J.GoalText(view.pickup),"GameFontNormal") end

    M.y=M.y-10

    local point=view.point

    if point then

        local info=ns.API.Call("C_Map","GetMapInfo",point.map)

        M.Line((point.handoff and "Travel handoff: " or point.native and "Quest area: " or "Destination: ")..(info and ns.Safe(info.name) or "Map #"..point.map)..string.format("  %.1f, %.1f",point.x*100,point.y*100),"GameFontNormalSmall")

    end

    local map=at(U.Button(M.body,view.pickup and "Show prerequisite" or point and "Show destination" or view.goal and view.goal.quest and "Open quest" or "Written directions",180,function() J.Destination() end),10,M.y)

    map:SetEnabled(not view.paused and (point~=nil or view.pickup~=nil or view.goal and view.goal.quest~=nil))

    local confirm=at(U.Button(M.body,view.paused and "Resume Journey" or J.SkipControl(view) and J.SkipLabel(view) or view.manual and ((view.goal or view.confirmStep) and "Done, next" or "Next step") or view.atCap and "At level cap" or not view.step and "Find my next route" or "Tracking automatically",205,function() J.Act(view) end),205,M.y)

    confirm:SetEnabled(view.paused or not view.atCap and not view.blocked and (view.manual or not view.step))

    M.y=M.y-42

    if #objectives<2 and view.nextTitle~="" then M.Line("Then: "..view.nextTitle,"GameFontHighlightSmall") end

    M.y=M.y-12

    local actions=U.Options(M.body,{{value="pause",label=view.paused and "Resume" or "Pause"},{value="undo",label="Undo"},{value="review",label="Review"},{value="routes",label="Guides"},{value="history",label="History"}},nil,M.width-20,function(v)

        if v=="pause" then J.Pause() else M.JourneyOptions(v) end

    end,5);actions:SetPoint("TOPLEFT",10,M.y);M.y=M.y-actions:GetHeight()-12

    if ns.char.routeMode=="manual" and not view.route.planSlug then M.Line("You chose this route. Automatic leveling resumes only when you select it.","GameFontHighlightSmall") end

    M.Action(M.journeyDetails and "Hide route suggestions" or "Route suggestions and preparation",function() M.journeyDetails=not M.journeyDetails;M.Render() end,300)
    if not M.journeyDetails then return end
    if not view.route.live then M.Action("Follow quests in my log",function() J.Select("live") end,240) end

    if ns.char.routeReturn then M.Action("Return to leveling route",J.Return,240)

    elseif view.route.category=="Leveling" then

        local choices={};for _,r in ipairs(J.ClassRoutes()) do choices[#choices+1]={value=r.id,label=r.name} end

        if #choices>0 then

            M.Line("Class quests available for your level","GameFontNormal")

            local detours=U.Options(M.body,choices,nil,M.width-20,function(id) J.Select(id) end)

            detours:SetPoint("TOPLEFT",10,M.y);M.y=M.y-detours:GetHeight()-10

        end

    end

end

function M.CreateGuide()

    local f=U.Window(ns.db.settings.guideWidth,210,"Journey","guide");ns.Guide=f;U.CompactChrome(f);f:SetFrameStrata("MEDIUM")

    f.close:SetScript("OnClick",function() ns.SetSetting("guide",false) end)

    if not ns.db.settings.positions.guide then f:ClearAllPoints();f:SetPoint("RIGHT",UIParent,"RIGHT",-35,20) end

    f.titleRightInset=70;f.title:SetWidth(f:GetWidth()-70);f.title:SetText("Journey");f.title:SetWordWrap(false)

    f.scroll=CreateFrame("ScrollFrame",nil,f)

    if f.scroll.EnableMouseWheel then f.scroll:EnableMouseWheel(false) end

    f.scroll:SetPoint("TOPLEFT",12,-35);f.scroll:SetSize(ns.db.settings.guideWidth-42,120)

    f.content=CreateFrame("Frame",nil,f.scroll);f.scroll:SetScrollChild(f.content)
    f.scroll:SetScript("OnMouseWheel",function(self,delta)
        local limit=math.max(0,f.content:GetHeight()-self:GetHeight())
        self:SetVerticalScroll(math.max(0,math.min(limit,self:GetVerticalScroll()-delta*24)))
    end)

    f.route=U.Label(f.content,"",0,-8,280,"GameFontNormal")

    f.progress=U.Label(f.content,"",0,-30,280,"GameFontHighlightSmall")

    f.unrouted=U.Label(f.content,"",0,0,280,"GameFontNormalSmall")

    f.scheduled=U.Label(f.content,"",0,0,280,"GameFontHighlightSmall")

    f.scheduledHit=CreateFrame("Frame",nil,f.content);f.scheduledHit:EnableMouse(true);f.scheduledHit:SetAllPoints(f.scheduled)



    f.stepHeading=U.Label(f.content,"",0,-50,280,"GameFontNormal")

    f.status=U.Label(f.content,"",0,-70,280,"GameFontNormalSmall")

    f.rows={}

    for i=1,5 do

        local row=CreateFrame("Button",nil,f.content);row:SetSize(280,28)

        row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(16,16);row.icon:SetPoint("TOPLEFT",0,-3)

        row.text=U.Label(row,"",24,-2,250,"GameFontHighlight");row.text:SetWordWrap(true);row.text:SetJustifyV("TOP")

        row:SetScript("OnClick",function(self) local view=J.View();if self.goal then J.GoalWaypoint(self.goal) else J.Destination(view) end end)

        row.skip=CreateFrame("Button",nil,row);row.skip:SetSize(24,24);row.skip:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")

        row.skip:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")

        row.skip.mark=row.skip:CreateTexture(nil,"OVERLAY");row.skip.mark:SetAllPoints()

        row.skip:SetScript("OnClick",function() local view=J.View();if row.current and not view.paused then J.Skip(view) end end)

        row.skip:SetPoint("TOPRIGHT",0,0)

        U.Tooltip(row.skip,"Skip, not complete",{"Move on now. Unaccepted dependent route actions are dismissed too. Use Undo to restore them."})

        f.rows[i]=row

    end

    f.text=f.rows[1].text

    f.note=U.Label(f.content,"",0,-95,280,"GameFontHighlightSmall")

    f.noteHit=CreateFrame("Frame",nil,f.content);f.noteHit:SetAllPoints(f.note);f.noteHit:EnableMouse(true)

    f.serviceReminder=U.Label(f.content,"",0,0,280,"GameFontNormalSmall")
    f.talent=U.Label(f.content,"",0,0,280,"GameFontNormalSmall")
    f.talentHit=CreateFrame("Button",nil,f.content);f.talentHit:SetAllPoints(f.talent)
    f.talentHit:SetScript("OnClick",function()
        local advice=ns.Talents.PointAdvice();M.talentPage=advice and advice.page or "Guide"
        M.OpenPage("Talents")
    end)

    f.navigation=U.Label(f.content,"",0,-130,250,"GameFontNormalSmall")

    f.arrow=f.content:CreateTexture(nil,"ARTWORK");f.arrow:SetSize(20,20);f.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")

    f.arrowCaption=U.Label(f.content,"",0,0,1,"GameFontHighlightSmall");f.arrowCaption:Hide()

    f.map=U.Button(f,"Map",90,function() J.Destination(J.View()) end)

    f.done=U.Button(f,"Next",100,function() local view=J.View();if view.paused then J.Pause() else J.Confirm(view) end end)

    f.more=U.Button(f,"Details",80,openJourney)
    f.skipTask=U.Button(f,"Skip task",90,function() local view=J.View();if view.goal and not view.paused then J.Skip(view) end end)

    f.next=U.Label(f.content,"",0,-155,280,"GameFontHighlightSmall")

    f.nextHit=CreateFrame("Frame",nil,f.content);f.nextHit:SetAllPoints(f.next);f.nextHit:EnableMouse(true)

    f.pause=CreateFrame("Button",nil,f);f.pause:SetSize(64,24)

    f.pause.caption=U.Label(f.pause,"Pause",0,-3,64,"GameFontHighlightSmall");f.pause.caption:SetJustifyH("CENTER")

    f.pause:SetScript("OnClick",J.Pause);U.Tooltip(f.pause,"Pause / resume Journey")

    f.progressTrack=f.content:CreateTexture(nil,"BACKGROUND");f.progressTrack:SetColorTexture(.34,.29,.20,.5)

    f.progressFill=f.content:CreateTexture(nil,"ARTWORK");f.progressFill:SetColorTexture(.88,.68,.29,1)

    for _,button in ipairs({f.map,f.done,f.more}) do

        for _,getter in ipairs({"GetNormalTexture","GetPushedTexture","GetDisabledTexture"}) do local texture=button[getter](button);if texture then texture:SetAlpha(0) end end

        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");button:GetHighlightTexture():SetAlpha(.2)

    end

    f.options=M.JourneyTools(f,120,true);f.options:SetPoint("BOTTOMLEFT",12,42)

    f.collapse=CreateFrame("Button",nil,f);f.collapse:SetSize(22,22);f.collapse:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-UP");f.collapse:SetPoint("TOPRIGHT",-32,-6)

    f.collapse:SetScript("OnClick",function() ns.SetSetting("guideCollapsed",not ns.db.settings.guideCollapsed) end);U.Tooltip(f.collapse,"Collapse / expand tracker")

    f:SetScript("OnHide",function() ns.Navigation.Stop();if ns.Navigation.frame then ns.Navigation.frame:Hide() end end)

end

actionIcons={accept="Interface\\GossipFrame\\AvailableQuestIcon",turnin="Interface\\GossipFrame\\ActiveQuestIcon",interact="Interface\\GossipFrame\\GossipGossipIcon",

    kill="Interface\\Icons\\Ability_DualWield",collect="Interface\\Icons\\INV_Misc_Bag_08",buy="Interface\\Icons\\INV_Misc_Coin_01",vendor="Interface\\Icons\\INV_Misc_Coin_01",

    goto="Interface\\Icons\\INV_Misc_Map_01",learn="Interface\\Icons\\INV_Misc_Book_09",note="Interface\\Icons\\INV_Misc_Book_09",fly="Interface\\Icons\\Ability_Mount_Wyvern_01",getfp="Interface\\Minimap\\Tracking\\FlightMaster",hearth="Interface\\Icons\\INV_Misc_Rune_01",sethome="Interface\\Icons\\INV_Misc_Rune_01",boat="Interface\\Icons\\INV_Misc_Map_01",zeppelin="Interface\\Icons\\INV_Misc_Map_01",portal="Interface\\Icons\\Spell_Arcane_PortalStormWind"}

local function layoutGuide()

    local f=ns.Guide;if not f then return end

    f:SetShown(ns.db.settings.guide and ns.db.settings.modules.journey and not M.GuideObstructed())

    if not f:IsShown() then ns.Navigation.Stop();return end
    local view=J.View();f.view=view;f.goal=view.goal

    local collapsed=ns.db.settings.guideCollapsed;local width=ns.db.settings.guideWidth;local cw=width-28
    local anchor=f:GetPoint()
    if anchor~="TOPLEFT" and not IsMouseButtonDown("LeftButton") then
        local left,top=f:GetLeft(),f:GetTop()
        if left and top then f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top) end
    end

    f:SetWidth(width);f.title:ClearAllPoints();f.title:SetPoint("TOPLEFT",14,-10);f.title:SetText(view.route.name or "Journey");f.title:SetWidth(math.max(80,cw-112))

    f.title:SetShown(not collapsed)
    if not f.routeHit then
        f.routeHit=CreateFrame("Button",nil,f);f.routeHit:RegisterForDrag("LeftButton")
        f.routeHit:SetScript("OnDragStart",function() local handler=f:GetScript("OnDragStart");if handler then handler(f) end end)
        f.routeHit:SetScript("OnDragStop",function() local handler=f:GetScript("OnDragStop");if handler then handler(f) end end)
        f.routeHit:SetScript("OnClick",function() M.OpenJourneyPage("Routes") end)
    end
    f.routeHit:ClearAllPoints();f.routeHit:SetPoint("TOPLEFT",14,-7);f.routeHit:SetSize(math.max(80,cw-112),22);f.routeHit:SetShown(not collapsed)
    U.Tooltip(f.routeHit,view.route.name or "Journey",{"Choose a guide",view.progress})

    f.header:ClearAllPoints();f.header:SetPoint("TOPLEFT",8,-3);f.header:SetPoint("TOPRIGHT",-8,-3);f.header:SetHeight(29)

    f.divider:ClearAllPoints();f.divider:SetPoint("TOPLEFT",9,-32);f.divider:SetPoint("TOPRIGHT",-9,-32)

    f:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})

    f:SetBackdropBorderColor(.43,.35,.22,.8)

    if f.solid then f.solid:SetColorTexture(.045,.038,.027,.90) end

    if f.paper then f.paper:SetAlpha(.06) end

    f.header:SetColorTexture(.16,.12,.065,.65);f.divider:SetColorTexture(.48,.37,.18,.6)

    f.pause:ClearAllPoints();f.pause:SetPoint("TOPRIGHT",-57,-6);f.pause:SetShown(not collapsed)

    f.pause.caption:SetText(view.paused and "Resume" or "Pause")

    f.collapse:SetNormalTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-UP" or "Interface\\Buttons\\UI-MinusButton-UP")

    f.scroll:ClearAllPoints();f.scroll:SetPoint("TOPLEFT",14,-39)

    local y=3

    local function measure(label,text,w)

        label:SetWidth(w);label:SetHeight(0);label:SetWordWrap(true)

        if label.SetNonSpaceWrap then label:SetNonSpaceWrap(true) end

        label:SetJustifyV("TOP");label:SetText(text or "")

        local h=math.max(16,math.ceil(label:GetStringHeight())+3);label:SetHeight(h);return h

    end

    local function place(label,text,font,availableWidth)

        if font then label.baseFont=font;U.StyleLabel(label) end

        label:ClearAllPoints();label:SetPoint("TOPLEFT",0,-y)

        y=y+measure(label,text,availableWidth or cw)+2;label:SetShown(not collapsed)

    end

    local zone=type(GetZoneText)=="function" and ns.Safe(GetZoneText()) or nil

    local heading=view.goal and view.goal.title or view.step and view.step.text or "Journey"


    f.route:Hide()

    if collapsed then f.title:ClearAllPoints();f.title:SetPoint("TOPLEFT",12,-10);f.title:SetWidth(width-75);f.title:SetText(heading);f.title:Show() end

    U.Tooltip(f.options,"Guide tools",{view.context,view.progress})

    if ns.db.settings.guideProgress then

        place(f.progress,view.paused and "Paused" or view.route.planSlug and "Preparation" or view.progress,"GameFontHighlightSmall")

        f.progressTrack:ClearAllPoints();f.progressTrack:SetPoint("TOPLEFT",0,-y);f.progressTrack:SetSize(cw,2)

        f.progressFill:ClearAllPoints();f.progressFill:SetPoint("TOPLEFT",0,-y)

        local total,index=view.displayTotal or view.total,view.displayIndex or view.index

        local fraction=total>0 and math.max(0,math.min(1,((index or total)-1)/total)) or 0

        f.progressFill:SetSize(math.max(1,cw*fraction),2)

        f.progressTrack:SetShown(not collapsed and not view.route.planSlug);f.progressFill:SetShown(not collapsed and not view.route.planSlug)

        if not view.route.planSlug then y=y+10 end

    else f.progress:Hide();f.progressTrack:Hide();f.progressFill:Hide() end

    f.stepHeading:Hide()

    if view.paused or view.blocked or not view.step then place(f.status,view.status,"GameFontNormal") else f.status:Hide() end

    local objectives=view.stepObjectives or view.objectives or {};local first=1

    for i,o in ipairs(objectives) do if o.current then first=math.max(1,i-1);break end end

    local limit=1

    if limit==1 then for i,o in ipairs(objectives) do if o.current then first=i;break end end end

    local count=math.min(math.max(0,#objectives-first+1),limit)

    for i,row in ipairs(f.rows) do

        local visible=i<=count or i==1 and count==0;row:SetShown(not collapsed and visible)

        if visible then

            local o=objectives[first+i-1];row.current=o and o.current or count==0;row.goal=o and o.goal or view.goal

            local detail=J.ObjectiveDetail(row.goal)

            local title=o and (o.taskTitle or o.text) or view.title

            local amount=o and o.amount or row.current and view.amount
            local text=(o and o.evidence=="skipped" and "Skipped: " or "")..title..(amount and "  "..amount or "")

            row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-y);row:SetWidth(cw)

            row.fill=row.fill or row:CreateTexture(nil,"BACKGROUND");row.fill:SetAllPoints();row.fill:SetColorTexture(.27,.21,.09,row.current and .23 or 0)

            row.stripe=row.stripe or row:CreateTexture(nil,"ARTWORK");row.stripe:ClearAllPoints();row.stripe:SetPoint("TOPLEFT",-6,0);row.stripe:SetPoint("BOTTOMLEFT",-6,0);row.stripe:SetWidth(2);row.stripe:SetColorTexture(.94,.72,.3,row.current and 1 or 0)

            row.icon:ClearAllPoints();row.icon:SetPoint("TOPLEFT",3,-4);row.icon:SetSize(18,18)

            M.JourneyRowDetail(row,row.goal,o and o.done,o and o.evidence,cw,3,-2)

            row.itemButton:ClearAllPoints();row.itemButton:SetPoint("TOPLEFT",25,-3);row.itemButton:SetSize(24,24)

            local inset=detail.item and 56 or 28

            if o and o.bundled then row.itemButton:Hide();inset=28 end

            row.text.baseFont="GameFontHighlight";U.StyleLabel(row.text)

            local font,size,flags=row.text:GetFont()

            if font then row.text:SetFont(font,math.max(size,13*(ns.db.settings.textScale or 1)),flags) end

            row.text:SetTextColor(o and o.done and .56 or row.current and 1 or .78,o and o.done and .58 or row.current and .91 or .78,o and o.done and .53 or row.current and .72 or .72,1)

            row.text:ClearAllPoints();row.text:SetPoint("TOPLEFT",inset,-3)

            local h=measure(row.text,text,cw-inset-29)

            row.source:Hide() -- Extended source text stays in the tooltip and journal.

            row.skip:ClearAllPoints();row.skip:SetPoint("TOPRIGHT",1,-1);row.skip:Hide()

            row.skip:SetEnabled(row.current and not view.paused and not (o and o.done))

            row.skip.mark:SetTexture(o and o.evidence=="skipped" and "Interface\\Buttons\\UI-GroupLoot-Pass-Up" or "Interface\\Buttons\\UI-CheckBox-Check")

            row.skip.mark:SetShown(o and o.done and true or false)

            local members=0

            row:SetHeight(math.max(28,h+5+members))

            local lines={detail.source or "",row.current and (view.travelInstructions or view.actionNote or view.hint) or "Another action in this route group.","Click to show the destination. Skip task leaves it unfinished."}

            if o and o.bundled then

                lines={"All objectives at this route stop are tracked together. Each keeps its own native completion evidence.",view.hint}

                for _,detail in ipairs(o.details or {}) do lines[#lines+1]=detail end

            end

            if o and o.done then lines={o.evidence=="skipped" and "Skipped manually, not completed." or o.evidence=="manual" and "Acknowledged manually." or "Recorded from existing quest evidence."} end

            U.Tooltip(row,title,lines)

            row.skip:Hide()
            y=y+row:GetHeight()+2

        end

    end

    local fullNote=view.paused and view.hint or view.blocked and view.hint or view.travel and view.travelInstructions or view.actionNote

    local showDirections=ns.db.settings.guideNotes~=false or view.blocked or view.route.live
    local note=not view.paused and (view.travelStop or view.approachCaption) or (showDirections and fullNote) or ""
    local notesEnabled=showDirections or view.approachCaption or view.contact

    -- Full directions remain available in the hover and journal.

    if not view.blocked and not view.paused then
        local first=note:match("^[^\n]+") or ""
        if #first>180 then
            local short=first:sub(1,180):match("^(.*)%s+%S*$")
            note=(short or "See full instructions").."..."
        else note=first~=view.title and first or "" end
    end

    if notesEnabled and view.contact and view.contact~="" and not note:find(view.contact,1,true) then
        note=view.contact..(note~="" and "\n"..note or "")
    end

    if notesEnabled and note~="" then

        place(f.note,note,"GameFontHighlightSmall")

        local stop=view.stopPreview and #view.stopPreview>0 and ("At this stop:\n"..table.concat(view.stopPreview,"\n"))
        f.noteHit:SetShown(not collapsed);U.Tooltip(f.noteHit,"Current instructions",{fullNote or view.hint,stop or view.tripChecklist or "Open Journey for the full current instructions."})

    else f.note:Hide();f.noteHit:Hide() end

    -- Planning summaries are useful in the journal, not permanent HUD rows.

    f.scheduled:Hide();f.scheduledHit:Hide();f.unrouted:Hide();f.serviceReminder:Hide()

    local focus=ns.char.questFocus
    if focus then
        f.focus=f.focus or U.Label(f.content,"",0,0,cw,"GameFontNormalSmall")
        local title=ns.Safe(ns.API.Call("C_QuestLog","GetTitleForQuestID",focus)) or ns.QuestSupplies.Name(focus)
        place(f.focus,"Focused quest · "..title,"GameFontNormalSmall")
    elseif f.focus then f.focus:Hide() end
    local upcoming=not view.paused and not view.blocked and not focus and view.nextTitle

    if ns.db.settings.guideNext and upcoming and upcoming~="" and count<2 then

        place(f.next,#upcoming<=100 and "Then: "..upcoming or "Next action: hover to preview","GameFontHighlightSmall")

        f.nextHit:SetShown(not collapsed);U.Tooltip(f.nextHit,"Next action",{upcoming})

    else f.next:Hide();f.nextHit:Hide() end

    local talent=false
    if talent then
        place(f.talent,talent.points..(talent.points==1 and " talent point: " or " talent points: ")..(talent.name or "review your build"),"GameFontNormalSmall")
        f.talentHit:SetShown(not collapsed);U.Tooltip(f.talentHit,"Talent guidance",{talent.text,"Click to open your talent build. Spend points yourself in the native talent window."})
    else f.talent:Hide();f.talentHit:Hide() end
    f.navigation:Hide();f.arrow:Hide();ns.Navigation.Pulse()

    local manual=not view.paused and not view.atCap and not view.waitingForLevel and (view.manual and not view.blocked or not view.step)

    local buttons={f.map,f.options};if view.goal and not view.paused then buttons[#buttons+1]=f.skipTask else f.skipTask:Hide() end
    if view.blocked or view.travel and not notesEnabled then buttons[#buttons+1]=f.more else f.more:Hide() end
    if manual then buttons[#buttons+1]=f.done end
    f.options:SetShown(not collapsed)

    f.map:SetText(focus and "Resume route" or view.pickup and "Prerequisite" or view.point and "Map" or "Quest")
    f.map:SetScript("OnClick",function()
        if ns.char.questFocus then ns.QuestWorkspace.ClearFocus(ns.char.questFocus) else J.Destination() end
    end)
    f.map:SetEnabled(focus~=nil or not view.paused and (view.point~=nil or view.pickup~=nil or view.goal and view.goal.quest~=nil))

    f.done:SetText(view.paused and "Resume" or view.manualNext and "Next guide" or not view.step and "Find route" or view.travel and "Arrived" or "Done")

    local columns=math.min(#buttons,math.max(1,math.floor((cw+6)/92)))
    local footerRows=math.ceil(#buttons/columns)
    local bw=(cw-(columns-1)*6)/columns
    local bh=24

    for _,b in ipairs(buttons) do
        b:SetWidth(bw);bh=math.max(bh,b:GetHeight())
    end
    for i,b in ipairs(buttons) do
        local column=(i-1)%columns
        local row=footerRows-1-math.floor((i-1)/columns)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT",14+column*(bw+6),9+row*(bh+4))
        b:SetShown(not collapsed)
    end

    f.done:SetShown(not collapsed and manual)

    f.done:SetEnabled(view.paused or not view.atCap and not view.blocked and (view.manual or not view.step))

    local footerHeight=footerRows*bh+(footerRows-1)*4
    local viewHeight=math.min(y,math.max(48,(ns.db.settings.guideMaxHeight or 420)-56-footerHeight))
    local taskKey=view.goal and view.goal.id or view.title
    local scroll=f.scrollKey==taskKey and f.scroll:GetVerticalScroll() or 0
    f.scrollKey=taskKey
    f.content:SetSize(cw,math.max(1,y));f.scroll:SetSize(cw,math.max(1,viewHeight))
    f.scroll:UpdateScrollChildRect()
    f.scroll:SetVerticalScroll(math.min(scroll,math.max(0,y-viewHeight)))
    f.scroll:EnableMouseWheel(not collapsed and y>viewHeight)
    f.scroll:SetShown(not collapsed)

    f:SetHeight(collapsed and 32 or viewHeight+56+footerHeight)

    -- Preserve readable configured scale. Do not shrink fonts to fit a tall note.

    f:SetScale((ns.db.settings.windowScales or {}).guide or ns.db.settings.scale or 1)

    ns.Navigation.UpdateTicker()

end



function M.UpdateGuide()
    if not ns.db or not ns.char then return end
    if not ns.Guide or M.guideLayingOut then return end

    M.guideLayingOut=true

    if ns.Guide.failure then ns.Guide.failure:Hide() end

    local ok,err=pcall(layoutGuide)

    M.guideLayingOut=false

    if ok then ns.errors.guide=nil;return end

    ns.errors.guide=tostring(err);ns.Navigation.Stop()

    if not ns.db.settings.guide or M.GuideObstructed() then ns.Guide:Hide();return end

    local f=ns.Guide
    f.view,f.goal=nil,nil
    f.scroll:Hide()
    f.map:Hide()
    f.done:Hide()
    f.skipTask:Hide()
    f:SetHeight(128)
    f.title:SetText("Journey")
    f.title:Show()

    if f.options then f.options:Hide() end;if f.settings then f.settings:Hide() end

    f.failure=f.failure or U.Label(f,"",12,-40,f:GetWidth()-30,"GameFontHighlightSmall")

    f.failure:SetWidth(f:GetWidth()-30);f.failure:SetText("Tracker layout unavailable. Open Journal or /tk diagnostics.");f.failure:Show()

    f.more:ClearAllPoints();f.more:SetPoint("BOTTOMRIGHT",-12,12);f.more:SetWidth(100);f.more:Show();U.Fit(f)

end

ns.On("UI_SCALE_CHANGED",M.UpdateGuide)

ns.On("DISPLAY_SIZE_CHANGED",M.UpdateGuide)



local guideInteractions={}

local guideCloseEvents={}

function M.GuideObstructed()

    if U.main and U.main:IsShown() then return true end

    if ns.db.settings.guideHideInteraction==false then return false end

    for _,active in pairs(guideInteractions) do if active then return true end end

    for _,frame in ipairs({QuestFrame or false,GossipFrame or false,MerchantFrame or false,ClassTrainerFrame or false,BankFrame or false,FlightMapFrame or false,TaxiFrame or false}) do

        if frame and frame.IsShown and frame:IsShown() then return true end

    end

    return false

end

for _,pair in ipairs({{"quest","QUEST_DETAIL","QUEST_FINISHED"},{"quest","QUEST_GREETING","QUEST_FINISHED"},{"quest","QUEST_PROGRESS","QUEST_FINISHED"},{"quest","QUEST_COMPLETE","QUEST_FINISHED"},{"gossip","GOSSIP_SHOW","GOSSIP_CLOSED"},{"merchant","MERCHANT_SHOW","MERCHANT_CLOSED"},{"trainer","TRAINER_SHOW","TRAINER_CLOSED"},{"bank","BANKFRAME_OPENED","BANKFRAME_CLOSED"},{"flight","TAXIMAP_OPENED","TAXIMAP_CLOSED"}}) do

    local key=pair[1]

    ns.On(pair[2],function() guideInteractions[key]=true;M.UpdateGuide() end)

    if not guideCloseEvents[pair[3]] then

        guideCloseEvents[pair[3]]=true

        ns.On(pair[3],function() guideInteractions[key]=nil;M.UpdateGuide();ns.After("guideInteraction",M.UpdateGuide) end)

    end

end

ns.On("PLAYER_ENTERING_WORLD",function() guideInteractions={};M.UpdateGuide() end)





ns.Listen("SERVICES_CHANGED",function() M.UpdateGuide();if U.main and U.main:IsShown() and M.tab=="Journey" then M.Render() end end)





function M.DungeonPreparation(d)

    M.Heading("Before you go: "..d.name)

    local rows=ns.TripPlanning.Dungeon(d.slug)


    for _,part in ipairs(ns.TripPlanning.CollectionGoals(d.slug)) do M.Line(part.text..". "..part.note,"GameFontNormal") end

    local selected=M.Choose(rows,"tripPrepSelection","Quest preparation",function(row) return row.text end)

    if not selected then M.Line("No unfinished eligible quests are listed in the bundled preparation data.");return end

    local row=rows[selected]

    M.Heading(row.name);M.Line(row.text);M.Line(row.note)

    if row.classic then M.Line("Classic reference; current Forever eligibility is not verified.","GameFontHighlightSmall") end

    if row.quest and not row.ready then

        local route=J.Prerequisite({t="complete",quest=row.quest})

        if route then M.Action("Follow the pickup route",function() J.Select(route.id);M.tab="Journey";M.journeyPage="Now" end,240)

        else M.Line("No pickup route is documented. Check the native quest giver before departure.") end

    end

    M.Line("This checklist does not confirm objectives or promise that a dungeon run is sufficient.","GameFontHighlightSmall")

end

local function questPriorities()
    local view=J.View()
    M.Heading("Do next")
    M.Line(view.title)
    if view.actionNote then M.Line(view.actionNote,"GameFontHighlightSmall") end
    if view.route.live then
        M.Action("Resume automatic leveling",function() J.Automatic();M.OpenJourneyPage("Now") end,235)
    elseif view.index then
        local seen,shown={},0
        if view.goal and view.goal.quest then seen[view.goal.quest]=true end
        for index=view.index,math.min(view.total,view.index+16) do
            local step=view.route.steps and view.route.steps[index]
            if step and J.Applies(step.only) then
                for _,goal in ipairs(step.goals or {}) do
                    local id=goal.quest
                    if id and shown<4 and not seen[id] and J.Applies(goal.only) and not J.GoalDone(goal) and not J.OptionalDeferred(goal) then
                        seen[id]=true;shown=shown+1
                        if shown==1 then M.Heading("Coming up on this route") end
                        M.Line(J.GoalText(goal)..(goal.optional and " · Optional" or "").." · "..(step.text or view.route.name))
                    end
                end
            end
            if shown>=4 then break end
        end
    end
    M.Heading("Before your next dungeon")
    if J.Speedrunning() then M.Line("Outdoor only mode is active. Switch to Questing + dungeons to plan a trip.","GameFontHighlightSmall") end
    local choices=ns.TripPlanning.RelevantDungeons()
    for i=1,math.min(4,#choices) do
        local entry=choices[i];local d=entry.dungeon;local pickup,active,locked=0,0,0
        for _,quest in ipairs(entry.quests) do
            if quest.ready then active=active+1
            elseif quest.blocked then locked=locked+1
            else pickup=pickup+1 end
        end
        M.Row(d.name.." · "..active.." in your log, "..pickup.." to pick up, "..locked.." to unlock","Prepare trip",function()
            M.tripPlanningSection="Dungeon trips";M.tripPriorityDungeon=d.slug;M.tripPrepSelection=nil;M.tripPrepSelectionIdentity=nil;M.Render()
        end)
    end
    if #choices==0 then M.Line("No unfinished dungeon preparation is documented near your level.") end
    M.Action("Onyxia attunement",function() M.OpenJourneyPage("Planning",nil,"Onyxia") end,200)
end
local function onyxiaPlanning()
    local rows,active,carried=ns.TripPlanning.Onyxia()
    M.Heading("Onyxia's Lair")
    M.Line("Level 60 raid. Carry the Drakefire Amulet in your inventory to enter.")
    if #rows==0 then M.Line("Your faction is unavailable.");return end
    if carried then M.Line("Drakefire Amulet found in your bags.","GameFontNormal")
    else M.Line("Drakefire Amulet hasn't been found in your bags.","GameFontHighlightSmall") end
    local nextStage=active
    if not nextStage then
        local latest=0
        for index,row in ipairs(rows) do if row.done then latest=index end end
        nextStage=rows[latest+1] and latest+1
    end
    if not carried and nextStage then
        local row=rows[nextStage]
        M.Heading((row.quest and "In your log · " or "Next checkpoint · ")..row.name);M.Line(row.note)
        if row.quest then M.Action("Open quest details",function() ns.QuestWorkspace.Details({id=row.quest}) end,200) end
    elseif not carried then
        M.Line("The last tracked quest is complete. Check where you stored the amulet before heading to the raid.")
    end
    M.Heading(ns.State.faction.." checkpoints")
    for _,row in ipairs(rows) do
        local status=row.done and "Complete" or row.quest and "In your log" or row.reference and "Reference" or "Pending"
        M.Line(row.name.." · "..status,"GameFontNormal");M.Line(row.note,"GameFontHighlightSmall")
    end
end
function M.RoutePlanning()

    local route=J.Selected();M.Heading("Route preparation")

    local sections={"Priorities","Class quests","Dungeon trips","Zone coverage","Onyxia"}

    local section=M.tripPlanningSection or "Priorities"

    local choices={};for _,name in ipairs(sections) do choices[#choices+1]={value=name,label=name} end

    local tabs=U.Options(M.body,choices,section,M.width-16,function(v) M.tripPlanningSection=v;M.tripPriorityDungeon=nil;M.Render() end,5)

    tabs:SetPoint("TOPLEFT",8,M.y);M.y=M.y-tabs:GetHeight()-12

    if section=="Priorities" then return questPriorities()
    elseif section=="Onyxia" then return onyxiaPlanning()
    elseif section=="Class quests" then

        local classes=J.ClassRoutes()

        local selected=M.Choose(classes,"tripClassSelection","Class quest routes",function(r) return r.name.." ("..r.min.."-"..r.max..")" end)

        if selected then

            local r=classes[selected];M.Line(r.name)

            for _,reward in ipairs(r.rewards or {}) do

                local info=ns.API.Item(reward.item)

                M.Line("Source-listed class reward: "..(info and info.link or "Item #"..reward.item),"GameFontNormal")

                local slots=info and ns.Data.equipSlots[info.equip]

                if slots and ns.State.role~="unknown" then

                    local comparison=ns.Gear.Compare({id=reward.item,info=info,link=info.link},slots[1])

                    if comparison then M.Line(string.format("Current %s stat estimate: %+.1f. Effects and weapon handling need separate judgment.",ns.State.role,comparison.delta),"GameFontHighlightSmall") end

                end

            end

            M.Line("Prepare its pickups before committing to dungeon trips. Progress uses your actual quest log and collected items.")

            M.Action("Follow this class route",function() J.Select(r.id);M.journeyPage="Now" end,240)

        else M.Line("No unfinished class route is available for your current character and level.") end

    elseif section=="Dungeon trips" then

        if M.tripPriorityDungeon then
            local dungeon=ns.Journal.Get(M.tripPriorityDungeon)
            if dungeon then
                M.Action("Choose another dungeon",function() M.tripPriorityDungeon=nil;M.Render() end,230)
                return M.DungeonPreparation(dungeon)
            end
        end

        local choices={}

        for _,d in ipairs(ns.Journal.Entries()) do if #ns.TripPlanning.Dungeon(d.slug)>0 then choices[#choices+1]=d end end

        local picked=M.Choose(choices,"tripDungeonSelection","Prepare a dungeon trip",function(d) return d.name end)

        if picked then M.DungeonPreparation(choices[picked]) else M.Line("No eligible dungeon preparation is documented for this character.") end

    else

        local gaps=ns.TripPlanning.ZoneGaps(route)

        M.Line(#gaps.." eligible, level-relevant quests missing from the selected route in this zone.")

        local gap=M.Choose(gaps,"zoneGapSelection","Eligible quests missing from this route",function(q) return q.name.." (level "..q.level..")" end)

        if gap then M.Line(gaps[gap].name.." | Quest #"..gaps[gap].id.." has source eligibility data but no action in the selected route. Pickup and travel order need verification.")

        else M.Line("No additional gaps found in this zone's bundled metadata. This is not proof of complete live quest coverage.") end

    end

end



ns.Listen("JOURNEY_LOCATION_CHANGED",M.UpdateGuide)

