local addonName, ns = ...
local U=ns.UI
local M={width=1180,tab="Journey",sub="Talents",query="",slot=16,tree=1}; ns.Main=M
local journalPages={Journey={"Journey"},Talents={"Character","Talents"},Equipment={"Character","Equipment"},
    Farming={"Character","Farming"},Dungeons={"Adventure","Dungeons"},Books={"Books"},Settings={"Settings"}}
local function at(widget,x,y) widget:SetPoint("TOPLEFT",x,y); return widget end
function M.Choose(rows,key,caption,name)
    if #rows==0 then M[key]=nil;M[key.."Identity"]=nil;return nil end
    local choices,identities={},{};local selected
    for i,row in ipairs(rows) do
        local text=name(row,i)
        local identity=tostring(row.id or row.spellID or row.name or text)..":"..tostring(row.source or "")..":"..tostring(row.kind or "")..":"..tostring(row.time or "")
        identities[i]=identity;choices[#choices+1]={value=i,label=text}
        if M[key.."Identity"]==identity then selected=i end
    end
    selected=selected or math.max(1,math.min(M[key] or 1,#rows));M[key]=selected;M[key.."Identity"]=identities[selected]
    local callback=function(value) M[key]=value;M[key.."Identity"]=identities[value];M.Render() end
    local pick
    if #choices<=6 then pick=U.Options(M.body,choices,selected,M.width-24,callback)
    else pick=U.Roster(M.body,choices,selected,M.width-24,180,callback,key) end
    pick:SetPoint("TOPLEFT",10,M.y);M.y=M.y-pick:GetHeight()-12
    return selected
end

function M.Clear()
    if not M.body then M.body=CreateFrame("Frame",nil,M.scroll); M.body._managed=true; M.body:SetSize(M.width,1400); M.scroll:SetScrollChild(M.body) end
    U.Release(M.body);M.body:SetWidth(M.width);M.y=-8;M.visiblePanes={}
end
function M.Line(text,font)
    local t=U.Label(M.body,text,8,M.y,M.width-16,font or "GameFontHighlight")
    t:SetWordWrap(true); local h=math.max(18,t:GetStringHeight()+(ns.db.settings.rowDensity=="compact" and 3 or 7)); M.y=M.y-h; return t
end
function M.Heading(text)
    M.y=M.y-10
    local title=M.Line(text,"GameFontNormalLarge")
    local bar=U.New("Frame",M.body);bar:SetPoint("TOPLEFT",8,M.y);bar:SetSize(M.width-16,1)
    bar.fill=bar.fill or bar:CreateTexture(nil,"BACKGROUND");bar.fill:SetAllPoints();bar.fill:SetColorTexture(.39,.29,.14,1)
    M.y=M.y-12;return title
end
function M.Summary(values)
    local width=math.floor((M.width-16)/#values);local cards={};local height=53
    for i,value in ipairs(values) do
        local card=U.New("Frame",M.body);card:SetPoint("TOPLEFT",8+(i-1)*width,M.y);card:SetSize(width-8,53)
        card.fill=card.fill or card:CreateTexture(nil,"BACKGROUND");card.fill:SetAllPoints();card.fill:SetColorTexture(.13,.10,.06,1)
        U.Label(card,value[1],12,-8,width-32,"GameFontHighlightSmall")
        local text=U.Label(card,tostring(value[2] or ""),12,-25,width-32,"GameFontNormal");text:SetWordWrap(true)
        height=math.max(height,text:GetStringHeight()+33);cards[#cards+1]=card
    end
    for _,card in ipairs(cards) do card:SetHeight(height) end
    M.y=M.y-height-8
end
function M.Action(text,callback,width)
    local b=at(U.Button(M.body,text,width or 150,callback),10,M.y); M.y=M.y-29; return b
end
function M.Row(text,action,callback,tooltip)
    local row=U.New("Frame",M.body); row:SetPoint("TOPLEFT",8,M.y); row:SetSize(M.width-16,40)
    row.fill=row.fill or row:CreateTexture(nil,"BACKGROUND");row.fill:SetAllPoints();row.fill:SetColorTexture(.055,.052,.045,1)
    local label=U.Label(row,text,10,-9,M.width-(action and 205 or 36),"GameFontHighlight")
    row.label=label
    local button
    if action then button=at(U.Button(row,action,155,callback),M.width-184,-8); if tooltip then U.Tooltip(button,action,tooltip) end end
    local height=math.max(ns.db.settings.rowDensity=="compact" and 34 or 46,label:GetStringHeight()+20,button and button:GetHeight()+16 or 0)
    row:SetHeight(height); M.y=M.y-height-4; return row
end
function M.ItemCard(record,subtitle,action,callback,slot)
    local row=U.New("Frame",M.body);row:SetPoint("TOPLEFT",8,M.y);row:SetSize(M.width-16,86)
    row.fill=row.fill or row:CreateTexture(nil,"BACKGROUND");row.fill:SetAllPoints();row.fill:SetColorTexture(.055,.052,.045,1)
    U.Item(row,record.id,10,-12,38,record.link)
    local title=(record.link or record.name or record.info and record.info.name or "Item #"..record.id)
    if record.comparison then title=title..string.format("  |  %+.1f stat estimate",record.comparison.delta) end
    local heading=U.Label(row,title,60,-12,M.width-265,"GameFontNormal");heading:SetWordWrap(true)
    local detailTop=18+heading:GetStringHeight()
    local detail=U.Label(row,subtitle,60,-detailTop,M.width-265,"GameFontHighlightSmall");detail:SetWordWrap(true)
    local button=at(U.Button(row,action,160,callback),M.width-188,-10);button:SetEnabled(record.actionable~=false)
    if slot then at(U.Button(row,"Compare details",160,function() ns.ItemCompare.Show(record,slot) end),M.width-188,-43) end
    row:SetHeight(math.max(86,detail:GetStringHeight()+detailTop+13));M.y=M.y-row:GetHeight()-8;return row
end
function M.Subtabs(values)
    local x=8
    for _,name in ipairs(values) do local choice=name
        at(U.Button(M.body,(M.sub==name and "|cffffd16a" or "")..name,135,function() if choice=="Equipment" then M.OpenQuickGear();return end;M.sub=choice;M.scroll:SetVerticalScroll(0);M.Render() end),x,M.y); x=x+140
    end
    M.y=M.y-36
end
function M.JourneyReview()
    local J=ns.Journey
    if not ns.db.settings.modules.journey then M.Line("Journey is disabled in Settings."); return end
    local route=J.Selected(); local steps=J.Steps(); local step,current=J.Current()
    M.Heading(route.name)
    at(U.Button(M.body,"Change route",135,function() M.routePicker=not M.routePicker; M.scroll:SetVerticalScroll(0); M.Render() end),10,M.y)
    at(U.Button(M.body,"Find my route",145,function() M.routePicker=false;M.journeyPage="Now"; M.routeStep=nil; J.Automatic() end),155,M.y)
    at(U.Button(M.body,"Show guide",120,function() ns.SetSetting("guide",true) end),310,M.y)
    M.y=M.y-34
    M.Line((ns.char.routeMode=="auto" and "Automatic route" or "Manual route").."   |   Level "..ns.State.level.." "..ns.State.race.." "..ns.State.className.."   |   "..ns.State.faction,"GameFontNormalSmall")
    if M.browsingRoute~=route.id then M.routeStep=nil; M.goalPage=nil; M.browsingRoute=route.id end
    local index=M.routeStep or current
    if index then index=math.max(1,math.min(#steps,index)); step=steps[index] end
    if not step then
        M.Heading(#steps==0 and "Ready to begin" or "Route complete")
        M.Line(#steps==0 and "Choose Find my route for a leveling guide, or accept quests to use your quest log." or "You have reached the end of this route segment.")
        if J.NextID(route) then M.Action("Continue to next zone",function() M.routeStep=nil; J.NextRoute() end,220) end
        return
    end
    local completed,skipped=0,0
    for i in ipairs(steps) do
        local status=not route.live and J.Status(route,i) or route.live and ns.char.liveHidden and ns.char.liveHidden[steps[i].quest]
        if status=="skipped" then skipped=skipped+1 elseif status then completed=completed+1 end
    end
    M.Line("Step "..index.." of "..#steps.."   |   "..completed.." complete"..(skipped>0 and "  |  "..skipped.." skipped" or "")..(index~=current and "   |   Reviewing another step" or ""),"GameFontNormal")
    at(U.Button(M.body,"< Back",100,function() M.routeStep=math.max(1,index-1); M.goalPage=1; M.Render() end),10,M.y)
    at(U.Button(M.body,"Current step",130,function() M.routeStep=nil; M.goalPage=1; M.Render() end),120,M.y)
    at(U.Button(M.body,"Ahead >",100,function() M.routeStep=math.min(#steps,index+1); M.goalPage=1; M.Render() end),260,M.y); M.y=M.y-34
    local entry=(ns.char.routeEntries or {})[route.id]
    if entry then M.Line(entry.reason.." (step "..entry.index..").","GameFontNormalSmall") end
    M.Heading(step.text)
    if step.detail then M.Line(step.detail) end
    local activeGoal=J.Action();local prerequisite,_,pickup=J.Prerequisite(activeGoal)
    if prerequisite then M.Row("Prerequisite pickup: "..J.GoalText(pickup),"Show pickup",function()
        if not J.GoalWaypoint(pickup) then
            if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(pickup.quest) end
            ns.Message(J.GoalText(pickup)..". "..prerequisite.name)
        end
    end) end
    local goals={}
    for _,g in ipairs(step.goals or {}) do if J.Applies(g.only) then goals[#goals+1]=g end end
    local first=M.Choose(goals,"reviewAction","Choose a step action",function(g) return J.GoalText(g) end)
    for i=first or 1,first or 0 do
        local g=goals[i]; local done=J.GoalDone(g); local manual=g.id and ns.char.goalProgress and ns.char.goalProgress[g.id]
        M.Row((manual=="skipped" and "|cffaaaaaa[Skipped]|r " or done and "|cff88dd88["..(manual or "Confirmed").."]|r " or J.OptionalDeferred(g) and "[Optional] " or "|cffffd16a"..i..".|r ")..J.GoalText(g),manual and "Undo my mark" or (not done and not J.AutomaticGoal(g) and "I did this" or nil),function() if manual then J.MarkGoal(g,nil) else J.MarkGoal(g,"manual") end end)
        if g.note then M.Line(g.note,"GameFontHighlightSmall") end
        if g.pre then
            local missing={}; for _,q in pairs(g.pre) do if not J.QuestDone(q) then missing[#missing+1]="#"..q end end
            if #missing>0 then M.Line("Requires: "..table.concat(missing,", "),"GameFontNormalSmall") end
        end
    end
    for _,o in ipairs(step.objectives or {}) do M.Line((ns.Safe(o.finished,false) and "|cff88dd88[Done]|r " or "")..ns.Safe(o.text,"Objective data unavailable")) end
    at(U.Button(M.body,"Show destination",155,function() J.Waypoint(step) end),10,M.y)
    local canConfirm=true
    for _,g in ipairs(goals) do if J.AutomaticGoal(g) and not J.GoalDone(g) and not J.OptionalDeferred(g) then canConfirm=false;break end end
    at(U.Button(M.body,"I finished this step",165,function() M.routeStep=nil; M.goalPage=nil; J.Mark(index,"manual") end),175,M.y):SetEnabled(canConfirm)
    at(U.Button(M.body,"Skip step",110,function() M.routeStep=nil; M.goalPage=nil; J.Mark(index,"skipped") end),350,M.y)
    if not route.live and J.Status(route,index) then
        at(U.Button(M.body,"Undo step",110,function() ns.char.routes[route.id][index]=nil; ns.Emit("STATE_CHANGED") end),470,M.y)
    end
    M.y=M.y-34
    M.Line("Quest actions update automatically. Use 'I did this' for travel, training or other actions you completed yourself.","GameFontHighlightSmall")
    local classRoute=J.ClassRoute()
    if classRoute and route.category=="Leveling" then M.Row("Class quest guide: "..classRoute.name,"Follow detour",function() J.Select(classRoute.id) end) end
    if ns.db.settings.nearby then
        local map,x,y=ns.API.Position()
        if map and x and y then
            local shown=false
            for _,r in ipairs(ns.World.Records()) do if not shown and not ns.World.Status(r) then
                for _,p in ipairs(ns.World.Locations(r)) do if p.map==map and (p.x-x)^2+(p.y-y)^2<.0004 then
                    local record,point=r,p; M.Row("Nearby discovery: "..r.name,"Show location",function() ns.World.Waypoint(record,point) end); shown=true; break
                end end
            end end
        end
    end
end
function M.TalentCode()
    local T=ns.Talents
    if not M.codeFrame then
        local f=U.Window(520,245,"Share a talent plan","buildCode");M.codeFrame=f
        U.Label(f,"Copy this code, or paste a code and choose Preview. Import never spends points.",20,-47,475,"GameFontHighlightSmall")
        local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",24,-82);scroll:SetPoint("BOTTOMRIGHT",-45,68)
        f.edit=U.Edit(scroll,445,"",nil);U.Multiline(f.edit,scroll,80);f.edit:SetMaxLetters(4096);f.edit:SetHeight(110);scroll:SetScrollChild(f.edit)
        f.message=U.Label(f,"Ctrl+C copies selected text. Ctrl+V pastes a build code.",20,-180,475,"GameFontNormalSmall")
        at(U.Button(f,"Preview code",155,function()
            local ok,reason=T.Import(f.edit:GetText())
            if ok then M.tab="Character";M.sub="Talents";M.talentPage="Plan";U.main:Show();f:Hide();M.Render()
            else f.message:SetText(reason) end
        end),20,-205)
        at(U.Button(f,"Use current plan",180,function() f.edit:SetText(T.Export(ns.char.draft or {},ns.char.draftOrder or {},ns.char.previewLevel));f.edit:HighlightText();f.edit:SetFocus() end),190,-205)
    end
    M.codeFrame.edit:SetText(T.Export(ns.char.draft or {},ns.char.draftOrder or {},ns.char.previewLevel));M.codeFrame:Show();M.codeFrame.edit:HighlightText();M.codeFrame.edit:SetFocus()
end
function M.TalentMatches()
    local T=ns.Talents
    M.Heading("Match live talents")
    M.Line("Spell identities and native names match automatically. For an unmatched localized talent, select the source definition and the live node you recognize. Manual matches are pinned to this client build.")
    local sources={};for ti,tree in ipairs(T.Definitions()) do for i,d in ipairs(tree.talents) do sources[#sources+1]={value=T.Key(ti,i),label=tree.name..": "..d.name} end end
    M.bindingKey=M.bindingKey or (sources[1] and sources[1].value)
    at(U.Cycle(M.body,sources,M.bindingKey,M.width-36,function(v) M.bindingKey=v;M.Render() end),10,M.y);M.y=M.y-34
    local nodes={};for _,node in ipairs(T.live or {}) do nodes[#nodes+1]={value=node.id,label=node.name.." ("..node.rank.."/"..node.max..") #"..node.id} end
    M.bindingNode=M.bindingNode or (nodes[1] and nodes[1].value)
    if #nodes==0 then M.Line("The client has not supplied a live talent tree.");return end
    at(U.Cycle(M.body,nodes,M.bindingNode,M.width-36,function(v) M.bindingNode=v;M.Render() end),10,M.y);M.y=M.y-34
    M.Line("Source: "..((T.Definition(M.bindingKey) or {}).name or ""))
    local live;for _,node in ipairs(T.live) do if node.id==M.bindingNode then live=node;break end end
    if live then
        M.Line("Live: "..live.name.."   |   "..live.rank.."/"..live.max.."   |   Spell #"..tostring(live.spell))
        local description=live.spell and ns.Safe(ns.API.Call("C_Spell","GetSpellDescription",live.spell));if description then M.Line(description) end
    end
    M.Action("Match these talents",function() local ok,reason=T.Bind(M.bindingKey,M.bindingNode);M.bindingMessage=ok and "Match saved for this client build." or reason;M.Render() end,240)
    M.Action("Remove selected manual match",function()
        local bindings=(ns.char.talentBindings or {})[ns.State.class];if bindings then bindings[M.bindingKey]=nil end
        T.Read();M.bindingMessage="Manual match removed.";ns.Emit("STATE_CHANGED")
    end,260)
    if M.bindingMessage then M.Line(M.bindingMessage,"GameFontNormalSmall") end
    M.Line(#(T.unmatched or {}).." unmatched live nodes; "..T.mismatches.." allocation or rank-cap mismatches.","GameFontHighlightSmall")
end
function M.TalentCompare()
    local T=ns.Talents;local values={{value="@actual",label="Learned talents"},{value="@draft",label="Current plan"}}
    for name in pairs(ns.char.builds) do values[#values+1]={value="saved:"..name,label=name} end
    M.compareLeft=M.compareLeft or "@actual";M.compareRight=M.compareRight or "@draft"
    local function ranks(key) return key=="@actual" and T.actual or key=="@draft" and (ns.char.draft or {}) or (ns.char.builds[key:sub(7)] or {}).ranks or {} end
    M.Heading("Compare allocations")
    at(U.Cycle(M.body,values,M.compareLeft,math.floor((M.width-40)/2),function(v) M.compareLeft=v;M.comparePage=1;M.Render() end),10,M.y)
    at(U.Cycle(M.body,values,M.compareRight,math.floor((M.width-40)/2),function(v) M.compareRight=v;M.comparePage=1;M.Render() end),math.floor(M.width/2)+8,M.y);M.y=M.y-34
    local differences=T.Differences(ranks(M.compareLeft),ranks(M.compareRight))
    M.Line(#differences.." differing talents   |   "..T.Total(ranks(M.compareLeft)).." vs "..T.Total(ranks(M.compareRight)).." points")
    local selected=M.Choose(differences,"compareTalent","Choose a differing talent",function(d) return d.name.."  "..d.left.." / "..d.right end)
    U.Label(M.body,"Talent",18,M.y,700,"GameFontNormal")
    U.Label(M.body,"Left allocation",M.width-290,M.y,130,"GameFontNormalSmall");U.Label(M.body,"Right allocation",M.width-150,M.y,130,"GameFontNormalSmall");M.y=M.y-27
    for i=selected or 1,selected or 0 do local d=differences[i]
        local row=M.Row(d.name);row.label:SetWidth(M.width-360)
        U.Label(row,tostring(d.left),M.width-298,-9,130,"GameFontHighlight");U.Label(row,tostring(d.right),M.width-158,-9,130,"GameFontHighlight")
    end
    if #differences==0 then M.Line("The allocations match.") end
    M.Action("Back to builds",function() M.talentPage="Builds";M.Render() end,170)
end
function M.TalentOrder()
    local T=ns.Talents;local order=ns.char.draftOrder or {}
    M.Heading("Planned point order")
    M.Line(ns.char.draftOrderOrigin or "This is a plan for spending points, not a record of past purchases.","GameFontNormalSmall")
    local choices={}
    local ranks={};for i,key in ipairs(order) do ranks[key]=(ranks[key] or 0)+1;choices[#choices+1]={value=i,label="Level "..(i+9)..": "..T.Display(key).name.." rank "..ranks[key]} end
    M.orderIndex=math.max(1,math.min(M.orderIndex or 1,#order))
    if #order>0 then
        at(U.Cycle(M.body,choices,M.orderIndex,M.width-36,function(v) M.orderIndex=v;M.Render() end),10,M.y);M.y=M.y-34
        at(U.Button(M.body,"Earlier",140,function() local ok,reason=T.MovePoint(M.orderIndex,-1);if ok then M.orderIndex=M.orderIndex-1 end;M.orderMessage=reason;M.Render() end),10,M.y)
        at(U.Button(M.body,"Later",140,function() local ok,reason=T.MovePoint(M.orderIndex,1);if ok then M.orderIndex=M.orderIndex+1 end;M.orderMessage=reason;M.Render() end),160,M.y);M.y=M.y-34
        local first=math.max(1,M.orderIndex-1)
        for i=first,math.min(#choices,M.orderIndex+1) do M.Row((i==M.orderIndex and "|cffffd16a> " or "")..choices[i].label) end
    else M.Line("This allocation has no recorded order. Create a legal suggested order below.") end
    if M.orderMessage then M.Line(M.orderMessage,"GameFontNormalSmall") end
    M.Action("Create suggested order",function()
        local generated,reason=T.GenerateOrder(ns.char.draft or {})
        if generated then ns.char.draftOrder=generated;ns.char.draftOrderOrigin="Generated legal plan order; not purchase history";M.orderMessage="Suggested order created. Save & follow in Plan to use it."
        else M.orderMessage=reason end;M.Render()
    end,230)
    M.Action("Back to plan",function() M.talentPage="Plan";M.Render() end,160)
end
function M.Talents()
    local T=ns.Talents
    if not ns.db.settings.modules.talents then M.Line("Talent planner is disabled in Settings."); return end
    local page=M.talentPage or "Guide"
    for i,name in ipairs({"Guide","Plan","Builds","Match"}) do local choice=name
        at(U.Button(M.body,(page==name and "|cffffd16a" or "")..(name=="Guide" and "Home" or name),145,function() M.talentPage=choice; M.scroll:SetVerticalScroll(0); M.Render() end),10+(i-1)*155,M.y)
    end
    M.y=M.y-34
    local draft=ns.char.draft or {}
    if page=="Match" then M.TalentMatches();return end
    if page=="Compare" then M.TalentCompare();return end
    if page=="Order" then M.TalentOrder();return end
    if page=="Builds" then
        M.Heading("Choose a build")
        at(U.Button(M.body,"Compare plans",170,function() M.talentPage="Compare";M.Render() end),10,M.y)
        at(U.Button(M.body,"Share / import",170,M.TalentCode),190,M.y);M.y=M.y-34
        if ns.char.activeBuild then M.Action("Stop following this plan",T.StopFollowing,240) end
        local entries={}
        for name,build in pairs(ns.char.builds) do entries[#entries+1]={name=name,build=build,saved=true} end
        table.sort(entries,function(a,b) return a.name<b.name end)
        for _,g in ipairs(T.Recommendations()) do entries[#entries+1]={name=g.title,guide=g} end
        local selected=M.Choose(entries,"buildSelection","Choose a plan or source reference",function(e) return (e.saved and "Saved: " or "Reference: ")..e.name end)
        M.Line("Saved plans and source build references. Preview a reference, then save it to follow its point order.")
        for i=selected or 1,selected or 0 do local e=entries[i]
            local row=M.Row((e.saved and "[Saved] " or "")..e.name,e.saved and "Follow plan" or "Preview",function()
                if e.saved then
                    local ok,reason=T.FollowBuild(e.name);if not ok then ns.Message(reason);return end;M.talentPage="Guide"
                else T.LoadRecommendation(e.guide); M.talentPage="Plan" end
                M.Render()
            end)
            if e.saved then row.label:SetWidth(M.width-345);at(U.Button(row,"Delete",100,function() U.Confirm("Delete saved plan?","Delete "..e.name.."? Learned talents are unchanged.",function() ns.char.builds[e.name]=nil;if ns.char.activeBuild==e.name then ns.char.activeBuild=nil end;M.Render() end) end),M.width-300,-8) end
        end
        return
    end
    M.Line("Choose Home or Plan to view your talent trees.")
end
function M.GearWeights()
    M.Action("Back",function()
        if #M.history>0 then M.GoBack() else M.showWeights=false;M.Render() end
    end,115)
    local profile=ns.ItemComparison.Profile()
    if not profile.valid then
        M.Line("The client needs to report a primary talent tree before you can edit its weights.")
        return
    end
    M.Heading("Stat priorities · "..profile.name)
    M.Line("Personal weights change the advisory stat estimate for this spec.","GameFontHighlightSmall")
    local weights=ns.Gear.Weights(profile);local keys={};for key in pairs(weights) do keys[#keys+1]=key end;table.sort(keys)
    local top=M.y;local columnWidth=math.floor((M.width-24)/2)
    for index,stat in ipairs(keys) do local key=stat
        local x=12+((index-1)%2)*columnWidth;local y=top-math.floor((index-1)/2)*40
        U.Label(M.body,_G[stat] or stat,x,y-4,columnWidth-160,"GameFontHighlight")
        at(U.Edit(M.body,140,tostring(weights[stat]),function(value)
            local n=tonumber(value);if not n or n<0 or n>100 then ns.Message("Use a weight from 0 to 100.");return end
            local keyProfile=ns.Gear.ProfileKey(profile);ns.db.settings.weights[keyProfile]=ns.db.settings.weights[keyProfile] or {};ns.db.settings.weights[keyProfile][key]=n
            ns.Emit("EQUIPMENT_WEIGHTS_CHANGED");ns.Emit("SETTINGS_CHANGED");ns.Emit("STATE_CHANGED")
        end),x+columnWidth-152,y)
    end
    M.y=top-math.ceil(#keys/2)*40-8
    M.Action("Reset weights for this spec",function()
        ns.db.settings.weights[ns.Gear.ProfileKey(profile)]=nil
        ns.Emit("EQUIPMENT_WEIGHTS_CHANGED");ns.Emit("SETTINGS_CHANGED");ns.Emit("STATE_CHANGED")
    end,260)
end
function M.EquipmentContent()
    if not ns.db.settings.modules.gear then M.Line("Gear advice is disabled in Settings."); return end
    if M.showWeights then M.GearWeights();return end
    local equipped=ns.State.equipment[M.slot];local slotName="Slot "..M.slot
    for _,slot in ipairs(ns.Data.slots) do if slot[1]==M.slot then slotName=slot[2] end end
    M.Line(slotName,"GameFontNormalLarge")
    if equipped and equipped.id then
        U.Item(M.body,equipped.id,10,M.y,36,equipped.link)
        U.Label(M.body,equipped.link or equipped.info and equipped.info.name or "Loading equipped item",56,M.y-4,M.width-70,"GameFontNormal");M.y=M.y-45
    else M.Line("This slot is empty.") end
    at(U.Check(M.body,"Include reference sources",M.unverified,function(v) M.unverified=v;M.gearPage=1;M.Render() end),8,M.y)
    at(U.Button(M.body,"Stat priorities",130,function() M.showWeights=true;M.Render() end),M.width-145,M.y);M.y=M.y-35
    local candidates=ns.Gear.ForSlot(M.slot,M.unverified)
    local allCount=#candidates
    local query=at(U.Edit(M.body,M.width-28,M.gearQuery or "",function(value) M.gearQuery=value:lower();M.gearCandidate=nil;M.Render() end),12,M.y)
    U.Placeholder(query,"Find an item or source");M.y=M.y-34
    local visible={}
    for _,r in ipairs(candidates) do if ((r.name or r.info.name).." "..(r.source or "")):lower():find(M.gearQuery or "",1,true) then visible[#visible+1]=r end end
    candidates=visible
    M.Line(#candidates.." of "..allCount.." candidates | Stat estimates, not measured DPS.","GameFontHighlightSmall")
    local selected
    for index,r in ipairs(candidates) do if M.gearCandidateKey==tostring(r.link or r.id)..":"..(r.source or "") then selected=index;break end end
    selected=selected or math.max(1,math.min(M.gearCandidate or 1,#candidates));M.gearCandidate=selected
    local chosen=candidates[selected];M.gearCandidateKey=chosen and (tostring(chosen.link or chosen.id)..":"..(chosen.source or "")) or nil
    local top=M.y;local listWidth=math.floor(M.width*.48);local detailWidth=M.width-listWidth-24
    local height=math.max(240,(M.scroll:GetHeight()+top-42))
    local list=U.Panel(M.body,listWidth,height,8,top,"equipmentCandidates")
    local choices={};for i,record in ipairs(candidates) do
        local delta=record.comparison and record.comparison.delta
        choices[#choices+1]={value=i,label=(record.name or record.info.name)..(delta and string.format("  %+.1f",delta) or "")}
    end
    local roster=U.Roster(list,choices,selected,listWidth-20,height-24,function(index)
        local record=candidates[index];M.gearCandidate=index;M.gearCandidateKey=tostring(record.link or record.id)..":"..(record.source or "");M.Render()
    end,"gearCandidates:"..tostring(M.slot),true)
    roster:SetPoint("TOPLEFT",10,-12)
    local detail=U.Panel(M.body,detailWidth,height,listWidth+20,top,"equipmentComparison")
    local r=candidates[selected];local y=-14
    local function line(text,font)
        if not text or text=="" then return end
        local label=U.Label(detail,text,12,y,detailWidth-24,font or "GameFontHighlightSmall");y=y-label:GetStringHeight()-10
    end
    if r then
        U.Item(detail,r.id,12,y,32,r.link)
        local title=U.Label(detail,r.name or r.info.name,52,y,detailWidth-64,"GameFontNormal")
        y=y-math.max(38,title:GetStringHeight()+12)
        line(r.source);line(r.reason)
        local track=U.Button(detail,ns.char.farming[r.id] and "Tracked" or "Track",math.floor((detailWidth-30)/2),function() ns.Gear.Track(r) end)
        track:SetPoint("TOPLEFT",12,y);track:SetEnabled(r.actionable==true and not ns.char.farming[r.id])
        local effects=U.Button(detail,"Effects & details",math.floor((detailWidth-30)/2),function() ns.ItemCompare.Show(r,M.slot) end)
        effects:SetPoint("TOPLEFT",18+math.floor((detailWidth-30)/2),y)
        y=y-math.max(track:GetHeight(),effects:GetHeight())-16
        line("Equipped / Candidate / Change","GameFontNormal")
        local stats=ns.Gear.StatDeltas(r,M.slot)
        for _,stat in ipairs(stats) do
            line(stat.name..":  "..tostring(stat.before).." / "..tostring(stat.after)..string.format(" / %+.1f",stat.delta))
        end
        if #stats==0 then line("No readable stat differences. Hover the item for its native tooltip.") end
        line("Stat estimates are not measured DPS. Effects and sets require separate judgment.")
    else line(allCount==0 and "No cached candidates meet the current rules." or "No matching items. Clear the filter.") end
    local measured=math.max(height,-y+12);detail:SetHeight(measured);list:SetHeight(measured)
    M.y=top-measured-12
end

function M.EncounterNotes(d,e)
    if not M.noteWindow then
        local f=U.Window(690,360,"Personal encounter notes","encounterNotes");M.noteWindow=f
        f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");f.scroll:SetPoint("TOPLEFT",24,-75);f.scroll:SetSize(625,200)
        f.edit=U.Edit(f.scroll,595,"");U.Multiline(f.edit,f.scroll,200);f.edit:SetMaxLetters(1500);f.edit:SetHeight(200);f.scroll:SetScrollChild(f.edit)
        f.save=U.Button(f,"Save notes",160);f.save:SetPoint("BOTTOMLEFT",24,25)
        U.Label(f,"Personal notes are separate from sourced encounter information.",24,-48,630,"GameFontHighlightSmall")
    end
    local f=M.noteWindow;f.title:SetText(e.name.." - Personal notes");f.edit:SetText(ns.Journal.Note(d,e) or "");f.scroll:SetVerticalScroll(0)
    f.save:SetScript("OnClick",function() ns.Journal.Note(d,e,f.edit:GetText());f:Hide();M.Render() end);f:Show()
end
function M.EncounterAbilities(d,selectedBoss)
    local choices={};for i,e in ipairs(d.encounters) do choices[#choices+1]={value=i,label=e.name} end
    if #choices==0 then M.Line("No sourced encounter identities are available for this instance.");return end
    local selected=math.min(M.encounterSelection or 1,#choices);local e=d.encounters[selected]
    if not selectedBoss then at(U.Cycle(M.body,choices,selected,490,function(v) M.SelectBoss(v) end,"Encounter: "),10,M.y);M.y=M.y-34 end
    if M.NativeEncounter and M.NativeEncounter(d,e) then return end
    local recorded=ns.Journal.Mechanics(d,e)
    if recorded then
        local history=(ns.char.encounters or {})[recorded.encounterID]
        if recorded.encounterID then M.Line("Your recorded kills: "..(history and history.kills or 0).."   |   Native encounter #"..recorded.encounterID,"GameFontNormal") end
        M.Line("Aegis source-listed spells and role alerts. Native spell text comes from your client. Recorded measurements, when present, are observations rather than fixed values or predictions.","GameFontHighlightSmall")
        local rows=recorded.abilities;local selected=M.Choose(rows,"abilitySelection","Choose an ability",function(r) return r.name end)
        for n=selected or 1,selected or 0 do local r=rows[n]
            local spell=ns.API.Call("C_Spell","GetSpellInfo",r.spellID);local name=spell and ns.Safe(spell.name) or r.name
            local icon=spell and ns.Safe(spell.iconID)
            M.Heading((icon and "|T"..icon..":22:22|t " or "")..name.."  #"..r.spellID)
            if r.flags and #r.flags>0 then M.Line("Source role alerts: "..table.concat(r.flags,", "),"GameFontNormalSmall") end
            local description=ns.Safe(ns.API.Call("C_Spell","GetSpellDescription",r.spellID))
            if description then M.Line("Native spell text: "..description) else ns.API.Call("C_Spell","RequestLoadSpellData",r.spellID);M.Line("Native spell text is unavailable.","GameFontHighlightSmall") end
            if r.hit then M.Line("Recorded hit range: "..r.hit[1].."-"..r.hit[2]..". Actual damage varies.","GameFontHighlightSmall") end
            if r.every then M.Line("Recorded gaps between casts: "..r.every[1].."-"..r.every[2].." seconds.","GameFontHighlightSmall") end
            if r.firstCast then M.Line("First recorded cast: "..r.firstCast.." seconds after engagement.","GameFontHighlightSmall") end
        end
    else M.Line("No recorded spell data for this encounter in the licensed snapshot. Your personal notes can be saved below.") end
    local note=ns.Journal.Note(d,e)
    if note then M.Heading("Your notes");M.Line(note) end
    M.Action("Edit personal notes",function() M.EncounterNotes(d,e) end,200)
end
function M.EncounterHistory()
    M.Heading("Your encounter history")
    M.Line("Recorded native encounter results and reported loot. Group loot reports do not prove personal ownership.","GameFontHighlightSmall")
    local rows=ns.Journal.History();local selected=M.Choose(rows,"historySelection","Choose an encounter",function(e) return e.record.name end)
    for n=selected or 1,selected or 0 do local entry=rows[n];local r=entry.record
        M.Heading(r.name.."   |   "..r.kills.." kills, "..r.wipes.." failed attempts")
        local when=r.updated>0 and type(date)=="function" and date("%Y-%m-%d %H:%M",r.updated) or "Time unavailable"
        M.Line(when.."   |   Encounter #"..entry.id,"GameFontHighlightSmall")
        local items={};for _,item in pairs(r.loot) do items[#items+1]=item end;table.sort(items,function(a,b) return a.id<b.id end)
        if #items>0 then
            local choices={};for index,item in ipairs(items) do local info=ns.API.Item(item.link);choices[#choices+1]={value=index,label=(info and info.name or "Item #"..item.id).." x"..item.count} end
            M.historyItem=M.historyItem or {};local selected=math.min(M.historyItem[entry.id] or 1,#items)
            at(U.Cycle(M.body,choices,selected,520,function(v) M.historyItem[entry.id]=v;M.Render() end,"Reported loot: "),10,M.y);M.y=M.y-32
            local item=items[selected];local row=M.Row(item.link);row:EnableMouse(true);U.Tooltip(row,"Reported encounter loot",{"Native event report, separate from the global loot catalog."},item.link)
        end
    end
    if #rows==0 then M.Line("Encounter history fills when the client reports readable encounter-end or encounter-loot events.") end

end
function M.DungeonContent()
    if not ns.db.settings.modules.dungeons then M.Line("Dungeon browser is disabled in Settings."); return end
    local d=ns.Journal.Get(M.dungeon) or ns.Journal.Suggested() or ns.Journal.Entries()[1]
    if not d then M.Line("No dungeon entries are available.");return end
    M.dungeon=d.slug
    local available,reason=ns.Journal.SourceAllowed(d)
    local section=M.dungeonPage or "Overview"
    local selectedBoss=d.encounters and d.encounters[M.encounterSelection or 1]
    if section=="Abilities" then M.BossIdentity(d,selectedBoss) end
    if section=="Abilities" then M.EncounterAbilities(d,selectedBoss) end
    if section=="History" then M.EncounterHistory() end
    if section=="Loot" or section=="Overview" then
    local search=at(U.Edit(M.body,math.min(340,M.width-225),M.lootQuery or "",function(v) M.lootQuery=v:lower();M.Render() end),15,M.y)
    U.Placeholder(search,"Search dungeon loot")
    at(U.Button(M.body,M.relevantLoot and "Class usable only" or "All source loot",180,function() M.relevantLoot=not M.relevantLoot;M.Render() end),M.width-195,M.y)
    M.y=M.y-34
    local filters={{value="all",label="All slots"}}
    for _,slot in ipairs(ns.Data.slots) do filters[#filters+1]={value=tostring(slot[1]),label=slot[2]} end
    local slotFilter=U.Cycle(M.body,filters,M.lootSlot or "all",math.max(140,math.floor((M.width-38)/2)),function(v) M.lootSlot=v;M.lootSelection=nil;M.Render() end)
    slotFilter:SetPoint("TOPLEFT",15,M.y)
    local ownedFilter=U.Cycle(M.body,{{value="all",label="All ownership"},{value="missing",label="Missing items"},{value="owned",label="Owned items"},{value="tracked",label="Tracked targets"}},M.lootOwnership or "all",math.max(140,math.floor((M.width-38)/2)),function(v) M.lootOwnership=v;M.lootSelection=nil;M.Render() end)
    ownedFilter:SetPoint("TOPLEFT",23+math.floor((M.width-38)/2),M.y)
    M.y=M.y-math.max(slotFilter:GetHeight(),ownedFilter:GetHeight())-8
    local drops={}
    for _,r in ipairs(ns.Journal.Drops(d,M.lootQuery,not M.allBossLoot and selectedBoss or nil)) do
        if ns.Journal.MatchesLoot(r,{usable=M.relevantLoot,slot=tonumber(M.lootSlot),ownership=M.lootOwnership}) then drops[#drops+1]=r end
    end
    table.sort(drops,function(a,b) if a.boss~=b.boss then return a.boss<b.boss end;if a.name~=b.name then return a.name<b.name end;return a.id<b.id end)
    local chosen
    for _,r in ipairs(drops) do if M.lootSelection==(r.dungeon or "")..":"..(r.boss or "")..":"..r.id then chosen=r;break end end
    if #drops>8 then
        local choices={}
        for _,record in ipairs(drops) do choices[#choices+1]={value=(record.dungeon or "")..":"..(record.boss or "")..":"..record.id,label=record.name.." - "..record.boss} end
        chosen=chosen or drops[1]
        local key=(chosen.dungeon or "")..":"..(chosen.boss or "")..":"..chosen.id
        M.lootSelection=key
        local roster=U.Roster(M.body,choices,key,M.width-16,190,function(v) M.lootSelection=v;M.Render() end,"dungeonLoot",true)
        roster:SetPoint("TOPLEFT",8,M.y);M.y=M.y-198
        M.Line(#drops.." matching drops. Select an item above; refine the search to find more.","GameFontHighlightSmall")
        drops={chosen}
    end
    if M.dungeonEmbedded then M.y=M.y-30 end
    local actionY=M.dungeonEmbedded and M.y+30 or M.y+34
    local track=at(U.Button(M.body,chosen and ns.char.farming[chosen.id] and "Tracked" or "Track selected",140,function() if chosen then ns.Gear.Track(chosen) end end),M.dungeonEmbedded and 15 or M.width-345,actionY)
    track:SetEnabled(chosen and chosen.actionable==true and not ns.char.farming[chosen.id])
    local slots=chosen and chosen.info and ns.Data.equipSlots[chosen.info.equip]
    local compare=at(U.Button(M.body,M.lootFacts and "Hide stats" or "Compare",110,function() M.lootFacts=not M.lootFacts;M.Render() end),M.dungeonEmbedded and 165 or M.width-465,actionY);compare:SetEnabled(slots~=nil)
    if not M.dungeonEmbedded then M.Line(#drops.." source-listed drops | "..ns.State.className.." | Role: "..(ns.State.role or "unknown"),"GameFontHighlightSmall") end
    if M.lootFacts and chosen and slots then
        M.Line(chosen.name or chosen.info.name,"GameFontNormal")
        local facts=ns.Gear.StatDeltas(chosen,slots[1]);local start=M.y;local rowHeight=0
        for i,stat in ipairs(facts) do
            local column=(i-1)%2
            if column==0 and i>1 then start=start-rowHeight-8;rowHeight=0 end
            local label=U.Label(M.body,stat.name..": "..stat.before.." / "..stat.after..string.format(" (%+.1f)",stat.delta),12+column*math.floor(M.width/2),start,math.floor(M.width/2)-24,"GameFontHighlightSmall")
            rowHeight=math.max(rowHeight,label:GetStringHeight())
        end
        M.y=start-rowHeight-12
    end
    local columns={52,math.floor(M.width*.64),math.floor(M.width*.90)}
    U.Label(M.body,"Item",columns[1],M.y,M.width*.44,"GameFontNormal")
    if not M.dungeonEmbedded or #drops<=8 then U.Label(M.body,"Slot / type",columns[2],M.y,M.width*.25,"GameFontNormal") end
    if not M.dungeonEmbedded or #drops<=8 then U.Label(M.body,"Level",columns[3],M.y,M.width*.09,"GameFontNormal") end;M.y=M.y-25
    -- The complete dungeon view retains clear boss boundaries.
    for _,encounter in ipairs(d.encounters or {}) do
        local rows={};for _,r in ipairs(drops) do if r.encounter==encounter then rows[#rows+1]=r end end
        if #rows>0 then
            if not M.dungeonEmbedded or M.allBossLoot then
            M.y=M.y-8
            local heading=U.New("Button",M.body,"BackdropTemplate","lootBossHeading");heading:SetPoint("TOPLEFT",8,M.y);heading:SetSize(M.width-16,30)
            heading:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"});heading:SetBackdropColor(.22,.15,.065,1)
            heading.icon=heading.icon or heading:CreateTexture(nil,"ARTWORK");heading.icon:SetSize(24,24);heading.icon:SetPoint("TOPLEFT",6,-3);M.BossPortrait(heading.icon,encounter)
            U.Label(heading,encounter.name.."  |  "..#rows.." drops",40,-7,M.width-180,"GameFontNormal")
            U.Tooltip(heading,encounter.name,{"Click to collapse or expand this boss's loot."})
            local key=d.slug..":"..(encounter.id or encounter.name)
            M.collapsedLootBosses=M.collapsedLootBosses or {}
            U.Label(heading,M.collapsedLootBosses[key] and "+" or "-",M.width-45,-7,25,"GameFontNormal")
            heading:SetScript("OnClick",function() M.collapsedLootBosses[key]=not M.collapsedLootBosses[key];M.Render() end)
            M.y=M.y-34
            end
            local key=d.slug..":"..(encounter.id or encounter.name)
            if M.dungeonEmbedded and not M.allBossLoot or not (M.collapsedLootBosses or {})[key] then
                local fullWidth=M.width;local columns=#rows>8 and 2 or 1;local width=math.floor((fullWidth-12)/columns);local gridY=M.y
                for first=1,#rows,columns do
                    local height=0
                    for column=1,columns do local r=rows[first+column-1];if r then
                        M.width=width;M.y=gridY;local row=M.LootRow(r);row:ClearAllPoints();row:SetPoint("TOPLEFT",8+(column-1)*(width+6),gridY)
                        height=math.max(height,gridY-M.y)
                    end end
                    gridY=gridY-height
                end
                M.width=fullWidth;M.y=gridY
            end
        end
    end
    if #drops==0 then M.Line(d.hasLoot and "No matching loot. Clear the search or choose All source loot." or "No licensed loot table has been published for this instance.") end
    end
    local quests=d.questSource
    if section=="Quests" and not quests then M.Line("No licensed quest list is available for this instance.") end
    if section=="Quests" and quests then M.DungeonQuestWorkspace(d,quests);return end
    if section~="Overview" or M.dungeonEmbedded then return end
    M.Heading("Tracked targets here")
    for id,target in pairs(ns.char.farming) do
        local entry=target.dungeon and ns.Journal.Get(target.dungeon)
        if entry and entry.slug==d.slug then M.Line("Item #"..id..": "..(target.obtained and "Obtained" or "Still seeking").." | "..(target.boss or target.source or "")) end
    end
end
function M.Books()
    if not ns.db.settings.modules.world then M.Line("World collections are disabled in Settings."); return end
    M.Heading("Library books & discoveries")
    local search=at(U.Edit(M.body,270,M.bookQuery or "",function(v) M.bookQuery=v:match("^%s*(.-)%s*$"):lower(); M.bookSelection=nil;M.bookZone=nil;M.Render() end),8,M.y);U.Placeholder(search,"Search books or zones")
    at(U.Button(M.body,M.zoneOnly and "Current zone" or "All zones",130,function() M.zoneOnly=not M.zoneOnly; M.bookZone=nil;M.bookSelection=nil;M.Render() end),288,M.y)
    at(U.Button(M.body,M.hideDone and "Missing only" or "All progress",130,function() M.hideDone=not M.hideDone; M.Render() end),428,M.y)
    at(U.Button(M.body,M.bookRewards and "Show collection" or "Milestone rewards",165,function() M.bookRewards=not M.bookRewards;M.Render() end),568,M.y)
    at(U.Button(M.body,"Browse on map",140,M.OpenBookMap),743,M.y)
    M.y=M.y-38
    local map=ns.API.Call("C_Map","GetBestMapForUnit","player"); local total,done,donated=0,0,0; local choices,records={},{}
    for _,r in ipairs(ns.World.Records()) do
        local status=ns.World.Status(r)
        if r.item and r.id:match("^library:") then
            total=total+1;if status=="donated" or status=="collected" then done=done+1 end
            if status=="donated" then donated=donated+1 end
        end
        local onMap=r.map==map; for _,point in ipairs(ns.World.Locations(r)) do if point.map==map then onMap=true end end
        local text=(r.name.." "..(r.zone or "").." "..tostring(r.item or "")):lower()
        if (not M.zoneOnly or map and onMap) and (not M.hideDone or not status) and text:find(M.bookQuery or "",1,true) then
            choices[#choices+1]={value=r.id,label=r.name.." - "..(r.zone or "Discovery")}; records[r.id]=r
        end
    end
    M.Line(done.." / "..total.." library books collected or donated  ·  "..donated.." donated","GameFontHighlightSmall")
    if M.bookRewards then M.LibraryMilestones(donated);return end
    M.Line(#choices.." matching books and discoveries","GameFontHighlightSmall")
    if M.zoneOnly and not map then M.Line("The current map is unavailable. Choose All zones to browse the full collection.") end
    M.Action(M.recordDiscovery and "Cancel new discovery" or "Record a discovery here",function()
        M.recordDiscovery=not M.recordDiscovery;M.Render()
    end,220)
    if M.recordDiscovery then
        M.Line("Enter a title to save your current position as a player note.")
        local title=at(U.Edit(M.body,430,"",function(v)
            if ns.World.Register(v) then M.recordDiscovery=false;M.Render() end
        end),8,M.y)
        title:SetMaxLetters(140);M.y=M.y-32
    end
    if not records[M.bookSelection] then M.bookSelection=choices[1] and choices[1].value end
    local function details()
        local r=records[M.bookSelection]
        if not r then M.Line("No matching discoveries. Clear the search or choose All zones.");return end
        local status=ns.World.Status(r); M.Heading(r.name)
        M.Line("Status: "..ns.World.StatusLabel(r).."   |   "..(r.zone or "Player discovery"))
        if r.detail then M.Line(r.detail) end
        if r.caution then M.Line(r.caution,"GameFontNormalSmall") end
        local locations=ns.World.Locations(r)
        for _,point in ipairs(locations) do
            local location=point; local info=ns.API.Call("C_Map","GetMapInfo",point.map)
            M.Row((point.label and point.label..": " or "")..(info and info.name or point.zone or r.zone or "Map #"..point.map)..string.format(" (%.1f, %.1f)",point.x*100,point.y*100),"Show location",function() ns.Connected.Map(location) end)
        end
        if #locations==0 then M.Line("No supported pickup waypoint is available.") end
        for _,point in ipairs(r.accessPoints or {}) do local reference=point
            M.Row(point.label,"Show reference",function() ns.API.MapPoint(reference.map,reference.x,reference.y) end)
        end
        if status=="manual" or not status then M.Action(status=="manual" and "Undo my mark" or "Mark found",function() ns.World.Mark(r) end,190) end
        if r.item and r.id:match("^library:") then M.Action("Donation location",function() ns.BooksUI.ShowDonation(r) end,165) end
        if r.donationFaction then M.Line("Donation: "..r.donationFaction) end
        if r.item then M.Line("Item #"..r.item.."   |   "..(r.quest and "Donation quest #"..r.quest or "Forever donation unconfirmed"),"GameFontHighlightSmall") end
        local source=M.Action(M.bookEvidence and "Hide source details" or "Source details",function() M.bookEvidence=not M.bookEvidence; M.Render() end,160)
        U.Tooltip(source,"Source",{r.source or "Player observation",r.evidence or ""})
        if M.bookEvidence then M.Line(r.source or "Player observation"); if r.evidence then M.Line(r.evidence) end end
    end
    if #choices==0 then details() else M.BookWorkspace(choices,records,details) end
end

function M.About()
M.Heading(ns.Brand.displayName.." "..ns.Brand.version)
M.Action("Copy diagnostics",ns.ShowDiagnostics,180)
local version,build,_,interface=GetBuildInfo(); M.Line("Client "..tostring(version).." build "..tostring(build).."   |   Interface "..tostring(interface))
for key,value in pairs(ns.API.Capabilities()) do M.Line(key..": "..(value and "API present" or "API unavailable")) end
local count=0; for key,error in pairs(ns.errors) do
    if count<3 then M.Line(key..": "..error,"GameFontNormalSmall"); count=count+1 end
end
for key,error in pairs(ns.API.errors) do
    if count<3 then M.Line(key..": "..error,"GameFontNormalSmall"); count=count+1 end
end
M.Line("Routes: ToonKit. Quest facts: EverythingQuests and AllTheThings (MIT). Loot: Spyglass / AllTheThings (MIT). Books: Sixty Forever (CC BY 4.0), Library Guide / Librarian (MIT). Talents: Talents Forever (CC BY 4.0). Abilities: Aegis (MIT). Build references: WoW Forever Builds (MIT).")
M.Line("See SOURCES.md and Licenses for attribution. Source checks do not establish client behavior.","GameFontHighlightSmall")
end
function M.Render()
    if not U.main or not ns.char then return end
    if not U.main:IsShown() then return end
    local scale=U.PreferredScale(U.main)
    local width=math.floor(math.max(1040,math.min(1240,(UIParent:GetWidth()-24)/scale)))
    local height=math.floor(math.max(610,math.min(800,(UIParent:GetHeight()-24)/scale)))
    if U.main:GetWidth()~=width or U.main:GetHeight()~=height then U.main:SetSize(width,height) end
    M.width=width-60
    local navHeight=math.max(U.main.help:GetHeight(),U.main.bags:GetHeight())
    for _,button in ipairs(U.main.nav) do navHeight=math.max(navHeight,button:GetHeight()) end
    M.scroll:SetPoint("TOPLEFT",18,-math.max(94,60+navHeight))
    U.Fit(U.main)
    U.main.title:SetText(ns.Brand.displayName.."  ·  "..ns.State.name.."  ·  Level "..ns.State.level.." "..ns.State.className)
    if not U.main:IsShown() then return end
    if U.subpage and U.subpage:IsShown() then
        if U.subpage.pageTab==M.tab and U.subpage.pageSub==M.sub then return end
        U.CloseSubpage()
    end
    local context
    if M.tab=="Character" and M.sub=="Equipment" then
        local equipment=ns.EquipmentView
        context=table.concat({equipment.slot or 16,equipment.scope or "available",M.gearRequirementRecord and M.gearRequirementRecord.id or "",tostring(M.showWeights)},":")
    elseif M.tab=="Character" then
        context=M.sub=="Talents" and (M.talentPage or "Guide") or tostring(M.farmingPage)
    elseif M.tab=="Adventure" and M.sub=="Dungeons" then
        local dungeon=ns.DungeonView
        context=table.concat({dungeon.dungeon or "overview",dungeon.tab or "",dungeon.boss or "",dungeon.quest or "",dungeon.query or ""},":")
    elseif M.tab=="Books" then
        context=table.concat({M.bookQuery or "",M.bookZone or "",tostring(M.bookRewards)},":")
    elseif M.tab=="Settings" then
        local section=M.settingsPage or "Appearance"
        context=table.concat({tostring(M.helpOpen),tostring(M.advancedSettings),section,
            (M.settingsSections or {})[section] or "",M.bagSettingsPage or ""},":")
    else
        context=table.concat({M.journeyPage or "Now",tostring(M.routePicker),M.routeStep or ""},":")
    end
    local pageKey=M.tab..":"..(M.sub or "")..":"..tostring(context)
    local scroll=M.lastPageKey==pageKey and M.scroll:GetVerticalScroll() or 0;M.lastPageKey=pageKey
    for _,b in ipairs(U.main.nav or {}) do
        local active=b.page[2]==M.tab and (not b.page[3] or b.page[3]==M.sub)
        if b.group then active=b.page[2]==M.tab end
        b:SetSelected(active)
    end
    ns.char.lastPage=M.tab=="Character" and M.sub or M.tab=="Adventure" and "Dungeons" or M.tab
    M.Clear()
    if M.tab=="Character" and M.sub~="Equipment" then
        M.Subtabs({"Talents","Equipment","Farming"})
    end
    if M.tab=="Journey" then M.Journey()
    elseif M.tab=="Character" then
        if M.sub~="Talents" and M.sub~="Equipment" and M.sub~="Farming" then M.sub="Talents" end
        M[M.sub]()
    elseif M.tab=="Adventure" then M.Dungeons()
    elseif M.tab=="Books" then M.Books()
    else M.Settings() end
    local viewport=math.max(1,M.scroll:GetHeight()); local height=math.max(viewport,-M.y+20)
    M.body:SetHeight(height);M.scroll:UpdateScrollChildRect(); M.scroll:SetVerticalScroll(math.min(scroll,math.max(0,height-viewport)))
    M.scroll:EnableMouseWheel(true)
    local bar=M.scroll.ScrollBar or M.scroll.scrollBar
    if bar then bar:SetShown(height>viewport+1) end
end
function M.Create()
    M.StartPage();U.main=U.Window(1240,800,ns.Brand.displayName,"main")
    local brand=U.main:CreateTexture(nil,"ARTWORK");brand:SetTexture(ns.Brand.icon);brand:SetSize(28,28);brand:SetPoint("TOPLEFT",16,-12)
    U.main.title:ClearAllPoints();U.main.title:SetPoint("TOPLEFT",U.main,"TOPLEFT",52,-18)
    local navIcons={Journey="INV_Misc_Map_01",Talents="Ability_Marksmanship",Equipment="INV_Chest_Plate16",Farming="INV_Misc_Coin_01",Dungeons="INV_Misc_Key_14",Books="INV_Misc_Book_09",Settings="Trade_Engineering"}
    local pages={{"Journey","Journey"},{"Dungeons","Adventure","Dungeons"},{"Books","Books"},{"Equipment","Character","Equipment"},{"Settings","Settings"}}
    U.main.nav={}
    for i,page in ipairs(pages) do local choice=page
        local b=U.NavigationButton(U.main,page[1],function()
            U.CloseSubpage()
            M.OpenPage(choice[3] or choice[2])
        end,"Interface\\Icons\\"..(navIcons[page[1]] or (page[1]=="Play" and navIcons.Journey or page[1]=="Character" and navIcons.Equipment or navIcons.Dungeons)));b:SetSize(150,32);b.text:SetWidth(110);b:SetPoint("TOPLEFT",14+(i-1)*160,-48);b.page=page;b.group=false;U.main.nav[#U.main.nav+1]=b
    end
    local bags=U.NavigationButton(U.main,"Open bags",function() ns.Inventory.Toggle() end,"Interface\\Icons\\INV_Misc_Bag_08");bags:SetSize(132,30);bags.text:SetWidth(90);bags:SetPoint("TOPRIGHT",-14,-48)
    local help=U.Button(U.main,"Help",65,function() M.OpenPage("Settings",function() M.helpOpen=true end) end);help:SetPoint("TOPLEFT",814,-49)
    U.main.help=help;U.main.bags=bags
    local version=U.Label(U.main,ns.Brand.version,0,0,130,"GameFontHighlightSmall")
    version:ClearAllPoints();version:SetPoint("TOPRIGHT",-60,-20);version:SetJustifyH("RIGHT")
    M.scroll=CreateFrame("ScrollFrame",nil,U.main,"UIPanelScrollFrameTemplate");M.scroll:EnableMouseWheel(true);M.scroll:SetPoint("TOPLEFT",18,-94);M.scroll:SetPoint("BOTTOMRIGHT",-43,24)
    U.main:SetScript("OnShow",function() M.Render();if M.UpdateGuide then M.UpdateGuide() end end)
    U.main:HookScript("OnHide",function() if M.UpdateGuide then M.UpdateGuide() end end)
    U.main:EnableKeyboard(true);U.main:SetPropagateKeyboardInput(true)
    U.main:SetScript("OnKeyDown",function(self,key) if key=="ESCAPE" then self:Hide();self:SetPropagateKeyboardInput(false) else self:SetPropagateKeyboardInput(true) end end)
end
function M.StartPage()
    local name=ns.db.settings.rememberPage and ns.char.lastPage or ns.db.settings.startPage
    local page=journalPages[name or "Journey"] or journalPages.Journey;M.tab=page[1];M.sub=page[2] or M.sub
end
for _,event in ipairs({"UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"}) do
    ns.On(event,function()
        if U.main and U.main:IsShown() then ns.After("journalViewport",function() M.Render() end) end
    end)
end
function M.Toggle() if U.main:IsShown() then U.main:Hide() else if not ns.db.settings.rememberPage then M.StartPage() end;U.main:Show() end end
function M.OpenPage(page)
    local selected=journalPages[page];if not selected or not U.main then return false end
    U.CloseSubpage();M.tab=selected[1];M.sub=selected[2] or M.sub
    M.lastPageKey=nil
    if U.main:IsShown() then M.Render() else U.main:Show() end
    return true
end
function M.OpenHunt(id)
    if not ns.char.farming[id] then return false end
    return M.OpenPage("Farming",function()
        M.farmingSelection=id;M.farmingFilter="all";M.farmingDungeon=nil;M.farmingQuery=""
    end)
end
function M.OpenGearCandidate(slot,id)
    M.quickGear=false;M.gearWorkspace="cap";M.showWeights=false;M.gearRequirementRecord=nil
    ns.char.gearTree="auto";ns.char.gearRole="auto"
    M.slot=slot or M.slot or 16;M.huntItem=id;M.huntAcquisition=nil;M.huntSource="all";M.huntLevel="current"
    return M.OpenPage("Equipment")
end
function M.OpenQuickGear(slot)
    M.quickGear=true;M.quickGearSlot=slot or M.quickGearSlot or 16;M.showWeights=false;M.gearRequirementRecord=nil
    return M.OpenPage("Equipment")
end
function M.Editing()
    local focus=type(GetCurrentKeyBoardFocus)=="function" and GetCurrentKeyBoardFocus()
    for _=1,20 do
        if not focus then return false end
        if focus==U.main then return true end
        focus=focus.GetParent and focus:GetParent()
    end
    return false
end
ns.Listen("STATE_CHANGED",function(kind)
    local visible=U.main and U.main:IsShown()
    local relevant=true
    if M.tab=="Character" and M.sub=="Talents" then relevant=ns.Changed(kind,"talents","identity")
    elseif M.tab=="Journey" then relevant=ns.Changed(kind,"inventory","quests","identity","talents","journey")
    elseif M.tab=="Character" then relevant=ns.Changed(kind,"inventory","quests","identity","talents","storage")
    elseif M.tab=="Adventure" and M.sub=="Dungeons" then
        local tab=ns.DungeonView and ns.DungeonView.tab or "map"
        if tab=="map" then relevant=ns.Changed(kind)
        elseif tab=="quests" then relevant=ns.Changed(kind,"quests","identity","watch")
        else relevant=ns.Changed(kind,"inventory","quests","identity","talents") end
        if M.dungeonPage=="History" then relevant=relevant or ns.Changed(kind,"encounters") end
    elseif M.tab=="Books" then relevant=ns.Changed(kind,"inventory","quests","identity","books") end
    if visible and relevant then ns.After("journalStateRefresh",function()
        if not U.main or not U.main:IsShown() then return end
        if M.Editing() then M.pendingRefresh=true else M.Render() end
    end,0.25) end
    if M.UpdateGuide and ns.Changed(kind,"inventory","quests","identity","talents","journey") then ns.After("guideStateRefresh",M.UpdateGuide,0.25) end
end)

local function refreshLoadedItems()
    if not U.main or not U.main:IsShown() then return end
    if M.Editing() then M.pendingRefresh=true else M.Render() end
end
-- Native item loads repaint only a visible surface that actually uses that ID.
ns.Listen("ITEM_DATA_READY",function(ids)
    if type(ids)~="table" then return end
    if U.main and U.main:IsShown() and M.tab=="Books" and M.bookRewards then
        for _,milestone in ipairs(ns.Data.libraryGoals or {}) do
            for _,reward in ipairs(milestone.rewards or {}) do
                if ids[reward.item] then ns.After("journalItemRefresh",refreshLoadedItems,.25);return end
            end
        end
    end
    local goal=ns.Navigation and ns.Navigation.goal
    if goal and goal.item and ids[goal.item] then
        if ns.Guide and ns.Guide:IsShown() then ns.After("guideItemRefresh",M.UpdateGuide,0.25) end
        if U.main and U.main:IsShown() and M.tab=="Journey" then ns.After("journalItemRefresh",refreshLoadedItems,0.25) end
    end
    if not U.main or not U.main:IsShown() or M.tab~="Adventure" or M.sub~="Dungeons" or not ns.DungeonView then return end
    local v=ns.DungeonView;if v.tab~="loot" and v.tab~="quests" then return end
    local d=ns.Journal.Get(v.dungeon);if not d then return end
    local items={}
    if v.tab=="loot" then local boss=d.encounters[v.boss or 1];items=boss and boss.loot or {}
    else for _,quest in ipairs(d.questSource or {}) do if quest.id==v.quest then items=quest.choice or {};break end end end
    for _,item in ipairs(items) do if ids[item.id] then ns.After("journalItemRefresh",refreshLoadedItems,0.25);break end end
end)
