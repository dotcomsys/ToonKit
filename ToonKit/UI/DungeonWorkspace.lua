local addonName, ns = ...
local U,M,D=ns.UI,ns.Main,ns.Journal
local function at(frame,x,y) frame:SetPoint("TOPLEFT",x,y);return frame end
local function portrait(texture,e)
    local display=ns.Safe(e.displayID)
    if type(display)=="number" and display>0 and type(SetPortraitTextureFromCreatureDisplayID)=="function" then
        local ok=pcall(SetPortraitTextureFromCreatureDisplayID,texture,display);if ok then return true end
    end
    return type(e.portrait)=="string" and U.ClientTexture(texture,e.portrait)
end
function M.BossPortrait(texture,record)
    if not portrait(texture,record) then texture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull") end
end
function M.LootRow(record)
    local key=(record.dungeon or "")..":"..(record.boss or "")..":"..record.id
    local selected=M.lootSelection==key
    local size=ns.db.settings.rowDensity=="compact" and 30 or 38
    local row=U.New("Button",M.body,"BackdropTemplate","bossLootRow");row:SetSize(M.width-16,size);row:SetPoint("TOPLEFT",8,M.y)
    row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"});row:SetBackdropColor(selected and .24 or .12,selected and .17 or .095,.065,1)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
    row:SetScript("OnClick",function() M.lootSelection=not selected and key or nil;M.Render() end)
    local decision=record.referenceOnly and "Source reference" or record.actionable==false and record.reason
        or ns.ItemComparison.ItemDecision(record.id,record.link,record.info)
    local price=ns.ItemComparison.VendorValue(record.info,1)
    local notes={record.source or "",decision or "Source-listed drop"}
    if price~=nil then notes[#notes+1]="Vendor each "..ns.Gold.Format(price) end
    U.Tooltip(row,record.name,notes,record.link or "item:"..record.id)
    U.Item(row,record.id,4,-3,size-6,record.link)
    if M.dungeonEmbedded and M.width<460 then
        local title=U.Label(row,record.link or record.name,44,-5,M.width-66,"GameFontNormalSmall")
        row:SetHeight(math.max(size,title:GetStringHeight()+10))
        M.y=M.y-row:GetHeight()-3;return row
    end
    local title=U.Label(row,record.link or record.name,44,-5,math.floor(M.width*.64)-56,"GameFontNormalSmall");title:SetWordWrap(true)
    local info=record.info
    local kind=U.Label(row,info and (ns.Safe(_G[info.equip or ""]) or info.sub or info.class) or "Loading",math.floor(M.width*.64)-8,-5,math.floor(M.width*.26)-18,"GameFontHighlightSmall");kind:SetWordWrap(true)
    U.Label(row,info and tostring(info.required or "?") or "?",math.floor(M.width*.90)-8,-7,math.floor(M.width*.10)-18,"GameFontHighlightSmall")
    row:SetHeight(math.max(size,title:GetStringHeight()+10,kind:GetStringHeight()+10))
    M.y=M.y-row:GetHeight()-3;return row
end
function M.SelectBoss(index)
    M.bossFilter=index;M.encounterSelection=index;M.lootSelection=nil;M.lootPage=1;M.abilityPage=1;M.lootQuery="";M.allBossLoot=false;M.Render()
end
function M.BossIdentity(d,e)
    if not e then return end
    if M.dungeonEmbedded then
        local card=U.Panel(M.body,M.width-16,54,8,M.y,"bossIdentityCompact")
        card.icon=card.icon or card:CreateTexture(nil,"ARTWORK");card.icon:SetSize(38,38);card.icon:SetPoint("TOPLEFT",8,-8);M.BossPortrait(card.icon,e);card.icon:Show()
        U.Label(card,e.name,56,-8,M.width-80,"GameFontNormalLarge")
        U.Label(card,(e.level and "Level "..e.level.." | " or "")..#e.loot.." source-listed drops",56,-32,M.width-80,"GameFontHighlightSmall")
        M.y=M.y-62;return
    end
    local card=U.Panel(M.body,M.width-16,98,8,M.y,"bossIdentity")
    U.Label(card,e.name,112,-12,M.width-145,"GameFontNormalLarge")
    U.Label(card,(e.level and "Level "..e.level.."  |  " or "")..#e.loot.." source-listed drops"..(e.rare and "  |  Rare" or ""),112,-43,M.width-145,"GameFontHighlightSmall")
    U.Tooltip(card,e.name,{e.description or "Select an item below to compare or track it.",d.source or "Licensed catalog"});card:EnableMouse(true)
    local record=D.Mechanics(d,e);local npc=ns.Safe(e.npc or record and record.npc);local display=ns.Safe(e.displayID)
    if not card.model and not card.unsupported then
        local ok,model=pcall(CreateFrame,"PlayerModel",nil,card)
        if ok and model and type(model.SetCreature)=="function" then
            card.model=model;model:SetPoint("TOPLEFT",4,-4);model:SetSize(96,88);model:EnableMouse(false)
            model:SetScript("OnHide",function(self) if self.ClearModel then self:ClearModel() end end)
        else card.unsupported=true end
    end
    local available=false
    if card.model then
        local model=card.model;model:Hide()
        if model.ClearModel then model:ClearModel() end
        if type(display)=="number" and display>0 and type(model.SetDisplayInfo)=="function" or type(npc)=="number" and npc>0 then
            model:Show()
            available=pcall(function() if type(display)=="number" and display>0 and type(model.SetDisplayInfo)=="function" then model:SetDisplayInfo(display) else model:SetCreature(npc) end;if model.RefreshCamera then model:RefreshCamera() end;if model.SetFacing then model:SetFacing(.4) end end)
            if not available then model:Hide() end
        end
    end
    if not available then U.Label(card,"No native preview",6,-36,94,"GameFontHighlightSmall") end
    M.y=M.y-108
end
function M.DungeonWorkspace(renderContent)
    local d=D.Get(M.dungeon) or D.Suggested() or D.Entries()[1]
    if not d then M.Line("No dungeon entries are available.");return end
    M.dungeon=d.slug
    M.encounterSelection=math.max(1,math.min(M.encounterSelection or 1,math.max(1,#(d.encounters or {}))))
    local section=M.dungeonPage or "Loot";if section=="Overview" then section="Loot";M.dungeonPage=section end
    local header=U.Panel(M.body,M.width-16,64,8,M.y,"dungeonTitle")
    U.Label(header,d.name,14,-10,M.width-545,"GameFontNormalLarge")
    U.Label(header,D.LevelText(d)..(d.zone and "  |  "..d.zone or ""),14,-37,M.width-545,"GameFontHighlightSmall")
    local hunts=U.Button(header,"Hunts here ("..D.HuntCount(d)..")",180,function()
        M.farmingDungeon=d.slug;M.farmingFilter="seeking";M.farmingQuery="";M.OpenPage("Farming")
    end);hunts:SetPoint("TOPRIGHT",-14,-12);hunts:SetEnabled(D.HuntCount(d)>0)
    local entrance=U.Button(header,"Entrance waypoint",180,function() local p=d.entrance;if p then ns.API.MapPoint(p.map,p.x,p.y) end end)
    entrance:SetPoint("TOPRIGHT",-204,-12);entrance:SetEnabled(d.entrance~=nil)
    header:SetHeight(100)
    U.Tooltip(header,d.name,{d.source or "Licensed source catalog"});header:EnableMouse(true)
    local sections=U.Options(header,{{value="Map",label="Map"},{value="Loot",label="Boss loot"},{value="Quests",label="Quests"},{value="Preparation",label="Preparation"},{value="Abilities",label="Abilities"},{value="History",label="History"}},section,M.width-44,function(v) M.dungeonPage=v;M.Render() end,6)
    sections:SetPoint("TOPLEFT",14,-64);header:SetHeight(74+sections:GetHeight())
    M.y=M.y-header:GetHeight()-10
    if section=="Map" then M.DungeonMap(d,420);return end
    if section=="Preparation" then M.DungeonPreparation(d);return end
    if section=="Loot" or section=="Abilities" then
        local bosses=d.encounters or {}
        local selected=math.max(1,math.min(M.bossFilter or M.encounterSelection or 1,math.max(1,#bosses)))
        M.bossFilter=selected;M.encounterSelection=selected
        local top=M.y;local height=math.max(300,M.scroll:GetHeight()+top-16)
        local leftWidth=#bosses>20 and 540 or #bosses>10 and 400 or 290
        local roster=U.Panel(M.body,leftWidth,height,8,top,"dungeonBossRoster")
        U.Label(roster,"Bosses",12,-12,leftWidth-24,"GameFontNormalLarge")
        if section=="Loot" then
            local all=U.Button(roster,M.allBossLoot and "Showing all bosses" or "Show all dungeon loot",leftWidth-24,function() M.allBossLoot=not M.allBossLoot;M.lootSelection=nil;M.Render() end)
            all:SetPoint("TOPLEFT",12,-39)
        end
        local columns=#bosses>20 and 3 or #bosses>10 and 2 or 1;local width=math.floor((leftWidth-24)/columns);local y=section=="Loot" and -77 or -43;local rowHeight=0
        for index,e in ipairs(bosses) do
            local column=(index-1)%columns
            if column==0 and index>1 then y=y-rowHeight-5;rowHeight=0 end
            local row=U.New("Button",roster,"BackdropTemplate","dungeonBossChoice");row:SetWidth(width-5);row:SetPoint("TOPLEFT",12+column*width,y)
            row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8})
            row:SetBackdropColor(index==selected and .29 or .13,index==selected and .19 or .09,.055,1);row:SetBackdropBorderColor(.46,.34,.16,1)
            row.icon=row.icon or row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(30,30);row.icon:SetPoint("TOPLEFT",7,-7);M.BossPortrait(row.icon,e);row.icon:Show()
            local label=U.Label(row,e.name,44,-9,width-57,"GameFontNormal");local h=math.max(44,label:GetStringHeight()+18);row:SetHeight(h);rowHeight=math.max(rowHeight,h)
            row:SetScript("OnClick",function() M.SelectBoss(index) end)
            U.Tooltip(row,e.name,{e.level and "Level "..e.level or "Boss level not supplied",#e.loot.." source-listed drops"})
        end
        local rightWidth=M.width-leftWidth-28
        local detail=U.Panel(M.body,rightWidth,height,leftWidth+20,top,"dungeonBossDetails")
        if not detail.content then detail.content=CreateFrame("Frame",nil,detail);detail.content._managed=true;detail.content:SetPoint("TOPLEFT",10,-10) end
        U.Release(detail.content);detail.content:SetWidth(rightWidth-20)
        local parent,oldWidth,oldY=M.body,M.width,M.y
        M.body=detail.content;M.width=rightWidth-20;M.y=0;M.dungeonEmbedded=true
        local ok,err=pcall(function() if section=="Loot" and not M.allBossLoot then M.BossIdentity(d,bosses[selected]) end;renderContent() end)
        detail.content:SetHeight(math.max(1,-M.y));M.body=parent;M.width=oldWidth;M.y=top-height-8;M.dungeonEmbedded=nil
        if not ok then error(err) end
        return
    end
    renderContent()
end

function M.BookWorkspace(choices,records,renderDetails)
    local zones,order={},{}
    for _,choice in ipairs(choices) do
        local zone=records[choice.value].zone or "Player discoveries"
        if not zones[zone] then zones[zone]={};order[#order+1]=zone end
        zones[zone][#zones[zone]+1]=choice
    end
    table.sort(order)
    if M.bookZone and not zones[M.bookZone] then M.bookZone=nil end
    if not M.bookZone then
        M.Heading("Choose a zone")
        local columns=M.width>=740 and 3 or 2;local gap=6;local width=math.floor((M.width-16-(columns-1)*gap)/columns)
        local top=M.y;local y=0;local rowHeight=0
        for i,zone in ipairs(order) do
            local selectedZone=zone;local col=(i-1)%columns
            if col==0 and i>1 then y=y+rowHeight+gap;rowHeight=0 end
            local found=0;for _,choice in ipairs(zones[zone]) do if ns.World.Status(records[choice.value]) then found=found+1 end end
            local tile=U.Panel(M.body,width,50,8+col*(width+gap),top-y,"bookZoneGrid")
            tile.icon=tile.icon or tile:CreateTexture(nil,"ARTWORK");local icon=tile.icon;icon:SetSize(22,22);icon:SetPoint("TOPLEFT",9,-8);icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
            local title=U.Label(tile,zone.."  "..found.." / "..#zones[zone],40,-10,width-52,"GameFontNormal")
            local height=math.max(38,title:GetStringHeight()+18);tile:SetHeight(height);rowHeight=math.max(rowHeight,height)
            local hit=U.New("Button",tile,nil,"bookZoneHit");hit:SetAllPoints();hit:SetScript("OnClick",function()
                M.bookZone=selectedZone;M.bookZoneSelections=M.bookZoneSelections or {};M.bookSelection=M.bookZoneSelections[selectedZone];M.Render()
            end);U.Tooltip(hit,zone,{found.." of "..#zones[zone].." books found. Select to view this zone's books."})
        end
        M.y=top-y-rowHeight-12;return
    end
    M.Action("Zone list",function()
        M.bookZoneSelections=M.bookZoneSelections or {};M.bookZoneSelections[M.bookZone]=M.bookSelection;M.bookZone=nil;M.Render()
    end,130)
    M.Heading(M.bookZone)
    local visible=zones[M.bookZone] or {};local exists=false
    for _,choice in ipairs(visible) do if choice.value==M.bookSelection then exists=true end end
    if not exists then M.bookSelection=visible[1] and visible[1].value end
    local top=M.y;local left=math.floor(M.width*.44);local right=M.width-left-32
    local grid=U.Panel(M.body,left,280,8,top,"bookTileGrid")
    local dy=12
    for _,choice in ipairs(visible) do
        local id=choice.value;local book=records[id]
        local tile=U.New("Button",grid,"BackdropTemplate","bookTile");tile:SetPoint("TOPLEFT",10,-dy);tile:SetWidth(left-20)
        tile:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8})
        tile:SetBackdropColor(id==M.bookSelection and .24 or .07,.12,.04,1)
        tile.icon=tile.icon or tile:CreateTexture(nil,"ARTWORK");tile.icon:SetSize(30,30);tile.icon:SetPoint("TOPLEFT",9,-12);tile.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
        local title=U.Label(tile,book.name,48,-10,left-82,"GameFontNormal")
        local status=U.Label(tile,ns.World.StatusLabel(book),48,-16-title:GetStringHeight(),left-82,"GameFontHighlightSmall")
        local h=math.max(62,title:GetStringHeight()+status:GetStringHeight()+28);tile:SetHeight(h);dy=dy+h+8
        tile:SetScript("OnClick",function() M.bookSelection=id;M.Render() end)
    end
    local detail=U.Panel(M.body,right,280,left+20,top,"bookGridDetails")
    if not detail.content then detail.content=CreateFrame("Frame",nil,detail);detail.content._managed=true;detail.content:SetPoint("TOPLEFT",12,-12) end
    U.Release(detail.content);detail.content:SetWidth(right-24)
    local parent,width=M.body,M.width;M.body=detail.content;M.width=right-24;M.y=0
    local ok,err=pcall(renderDetails);local height=math.max(280,dy+8,-M.y+24)
    detail.content:SetHeight(height-24);grid:SetHeight(height);detail:SetHeight(height)
    M.body=parent;M.width=width;M.y=top-height-12;if not ok then error(err) end
end

function M.LibraryMilestones(donated)
    local width=math.floor((M.width-34)/3);local top=M.y;local cards={};local height=110
    for i,goal in ipairs(ns.Data.libraryGoals or {}) do
        local card=U.Panel(M.body,width,150,8+(i-1)*(width+9),top,"libraryMilestone")
        local complete=ns.API.QuestDone(goal.quest)
        U.Label(card,goal.books.." books  |  Level "..goal.level,12,-10,width-24,"GameFontNormal")
        local status=complete and "Reward quest completed" or goal.title.." · "..math.min(donated,goal.books).." / "..goal.books.." confirmed donations"
        local note=U.Label(card,status,12,-31,width-24,"GameFontHighlightSmall")
        local rewardY=math.max(51,39+note:GetStringHeight())
        for j,reward in ipairs(goal.rewards or {}) do
            local y=-rewardY;local info=ns.API.Item(reward.item)
            local icon=U.Item(card,reward.item,12,y,24,info and info.link)
            local classAllowed=not reward.classes
            for _,class in ipairs(reward.classes or {}) do if class==ns.State.class then classAllowed=true end end
            local text=info and info.link or reward.name
            local label=U.Label(card,text,44,y-2,width-54,"GameFontHighlightSmall");label:SetWordWrap(true)
            local advice=classAllowed and ns.ItemComparison.ItemDecision(reward.item,info and info.link,info) or nil
            if not classAllowed then advice="Other class" end
            local price=ns.ItemComparison.VendorValue(info,1)
            local summary=advice or ""
            if price~=nil then summary=summary..(advice and " · " or "").."Vendor each "..ns.Gold.Format(price) end
            local textHeight=label:GetStringHeight()
            if summary~="" then
                local decision=U.Label(card,summary,44,y-textHeight-4,width-54,"GameFontHighlightSmall")
                textHeight=textHeight+decision:GetStringHeight()+4
            end
            rewardY=rewardY+math.max(30,textHeight+8)
            U.Tooltip(icon,reward.name,{"Choose a reward from "..goal.title.." (quest #"..goal.quest..").",reward.level and "Source item level requirement: "..reward.level or "Source quest level requirement: "..goal.level,classAllowed and "Source class restriction permits your class; native usability is separate." or "Source reward is for other classes."},info and info.link or "item:"..reward.item)
            if not classAllowed then icon:SetAlpha(.45);label:SetAlpha(.45) else icon:SetAlpha(1);label:SetAlpha(1) end
        end
        height=math.max(height,rewardY+12);cards[#cards+1]=card
    end
    for _,card in ipairs(cards) do card:SetHeight(height) end
    M.y=top-height-8
end

-- Quest roster and parchment share one journal surface, with no selector popup.
function M.DungeonQuestWorkspace(d,source)
    local records={};local live={}
    for _,q in ipairs(ns.State.quests or {}) do live[q.id]=true end
    for _,q in ipairs(source) do if ns.Rules.Available(q,false) then records[#records+1]=q end end
    local selected
    for _,q in ipairs(records) do if q.id==M.questSelection then selected=q end end
    selected=selected or records[1];M.questSelection=selected and selected.id
    local top=M.y;local left=math.floor(M.width*.36);local right=M.width-left-36
    local roster=U.Panel(M.body,left,100,8,top,"dungeonQuestRoster")
    local parchment=U.Panel(M.body,right,100,left+20,top,"dungeonQuestParchment")
    parchment:SetBackdrop({bgFile="Interface\\QuestFrame\\QuestBG",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=4,right=4,top=4,bottom=4}})
    parchment:SetBackdropColor(.88,.80,.61,1)
    U.Label(roster,"Quests  |  "..#records,14,-14,left-28,"GameFontNormalLarge")
    local all=U.Button(roster,"Add all eligible quests to Journey",left-28,function() ns.DungeonJourney.IncludeDungeon(source) end)
    all:SetPoint("TOPLEFT",14,-44);all:SetEnabled(ns.Journey.Get("dungeon:"..source.slug)~=nil)
    local y=-52-all:GetHeight()
    for _,q in ipairs(records) do
        local quest=q;local done=ns.API.QuestDone(q.id);local active=live[q.id]
        local row=U.New("Button",roster,"BackdropTemplate","dungeonQuestChoice")
        row:SetWidth(left-24);row:SetPoint("TOPLEFT",12,y)
        row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8})
        row:SetBackdropColor(q.id==M.questSelection and .30 or .12,q.id==M.questSelection and .24 or .09,.05,1)
        row.icon=row.icon or row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(22,22);row.icon:SetPoint("TOPLEFT",8,-9)
        row.icon:SetTexture(done and "Interface\\GossipFrame\\ActiveQuestIcon" or active and "Interface\\GossipFrame\\ActiveQuestIcon" or "Interface\\GossipFrame\\AvailableQuestIcon");row.icon:Show()
        local title=U.Label(row,q.title,38,-9,left-76,"GameFontNormal")
        local sy=title:GetStringHeight()+15
        local status=U.Label(row,(done and "Completed" or active and "In quest log" or "Not accepted").."  |  Level "..tostring(q.req or "?"),38,-sy,left-76,"GameFontHighlightSmall")
        local h=sy+status:GetStringHeight()+12;row:SetHeight(h);y=y-h-6
        row:SetScript("OnClick",function() M.questSelection=quest.id;M.Render() end)
    end
    if not selected then U.Label(parchment,"No eligible quests in this source list.",20,-20,right-40,"GameFontNormal") end
    local dy=-20
    local function text(value,font,heading)
        if not value or value=="" then return end
        local label=U.Label(parchment,value,20,dy,right-40,font or "GameFontHighlight")
        label:SetTextColor(heading and .30 or .16,heading and .16 or .10,.035,1)
        dy=dy-label:GetStringHeight()-12
    end
    if selected then
        local q=selected
        text(q.title,"GameFontNormalLarge",true)
        text("Requires level "..tostring(q.req or "unknown").."  |  "..tostring(q.side or "Both factions"),"GameFontHighlightSmall")
        if source.classic then text("Classic reference: Forever eligibility and rewards remain unverified.","GameFontHighlightSmall") end
        text("Objectives","GameFontNormal",true);text(q.goal or "Objective text is not supplied by this source.")
        if q.needsId then text("Prerequisite","GameFontNormal",true);text((q.needs or "Quest").." (#"..q.needsId..")") end
        if q.startAt then
            local point=q.startAt;text("Starts at","GameFontNormal",true)
            text((point.place or point.zone or "Source location")..(point.x and point.y and string.format(" (%.1f, %.1f)",point.x,point.y) or ""))
        end
        if q.note then text("Notes","GameFontNormal",true);text(q.note) end
        local rewards=q.choice or q.rewards or {}
        if #rewards>0 then
            text(q.choice and "Choose one reward" or "Rewards","GameFontNormal",true)
            local cw=math.floor((right-48)/2);local rh=0
            for i,reward in ipairs(rewards) do
                local col=(i-1)%2;if col==0 and i>1 then dy=dy-rh-8;rh=0 end
                local card=U.Panel(parchment,cw,54,20+col*(cw+8),dy,"dungeonQuestReward")
                local info=ns.API.Item(reward.id);U.Item(card,reward.id,7,-8,32,info and info.link)
                local label=U.Label(card,info and info.link or reward.name or "Item #"..reward.id,46,-9,cw-58,"GameFontNormal")
                local h=math.max(54,label:GetStringHeight()+18);card:SetHeight(h);rh=math.max(rh,h)
            end
            dy=dy-rh-14
        end
        local included=ns.DungeonJourney.Included(source.slug,q.id)
        local add=U.Button(parchment,included and "Remove this quest from leveling Journey" or "Add this quest to leveling Journey",right-40,function()
            ns.DungeonJourney.Toggle(source.slug,q.id)
        end);add:SetPoint("TOPLEFT",20,dy);add:SetEnabled(ns.Journey.Get("dungeon:"..source.slug)~=nil);dy=dy-add:GetHeight()-8
        local follow=U.Button(parchment,"Prepare this dungeon in Journey",right-40,function()
            ns.Journey.PrepareDungeon(source.slug);ns.SetSetting("guide",true)
        end);follow:SetPoint("TOPLEFT",20,dy);follow:SetEnabled(ns.Journey.Get("dungeon:"..source.slug)~=nil);dy=dy-follow:GetHeight()-18
    end
    local height=math.max(320,-y+12,-dy+12)
    roster:SetHeight(height);parchment:SetHeight(height);M.y=top-height-12
end
