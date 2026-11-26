local addonName, ns = ...

local U,M,T=ns.UI,ns.Main,ns.Talents

local talentPages=M.Talents

local dungeonDetails=M.DungeonContent

local function at(frame,x,y) frame:SetPoint("TOPLEFT",x,y);return frame end

function U.Panel(parent,width,height,x,y,role)

    local panel=U.New("Frame",parent,"BackdropTemplate",role);panel:SetSize(width,height);panel:SetPoint("TOPLEFT",x,y)

    panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10,insets={left=2,right=2,top=2,bottom=2}})

    local theme=U.themes[ns.db.settings.theme] or U.themes.bronze

    panel:SetBackdropColor(theme[1]*.75,theme[2]*.75,theme[3]*.75,1);panel:SetBackdropBorderColor(.55,.43,.20,1)

    panel.paper=panel.paper or panel:CreateTexture(nil,"BACKGROUND",nil,1);panel.paper:SetAllPoints()

    if not U.ClientTexture(panel.paper,"Interface\\FrameGeneral\\UI-Background-Marble") then panel.paper:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background") end

    panel.paper:SetHorizTile(true);panel.paper:SetVertTile(true);panel.paper:SetTexCoord(0,width/256,0,height/256);panel.paper:SetVertexColor(theme[4],theme[5],theme[6],.16)

    return panel

end

local function rememberDraft()

    ns.char.draftUndo=ns.char.draftUndo or {};local history=ns.char.draftUndo

    history[#history+1]={ranks=ns.Copy(ns.char.draft or {}),order=ns.Copy(ns.char.draftOrder or {}),origin=ns.char.draftOrderOrigin}

    if #history>20 then table.remove(history,1) end

end

local function edit(key,delta)

    rememberDraft();local ok,why=T.Edit(key,delta)

    if not ok then table.remove(ns.char.draftUndo);M.talentMessage=why else M.talentMessage="Plan updated." end

    M.Render()

end

local function treeBackground(panel,tree)

    panel.treeArt=panel.treeArt or {}

    local class=ns.State.class:sub(1,1)..ns.State.class:sub(2):lower()

    local base="Interface\\TalentFrame\\"..class..tree.name:gsub("[^%w]","").."-"

    local width,height=panel:GetWidth()-6,panel:GetHeight()-50

    local left,top=width*256/300,height*256/331

    for i,piece in ipairs({{"TopLeft",0,0,left,top},{"TopRight",left,0,width-left,top},{"BottomLeft",0,top,left,height-top},{"BottomRight",left,top,width-left,height-top}}) do

        local art=panel.treeArt[i] or panel:CreateTexture(nil,"BACKGROUND",nil,1);panel.treeArt[i]=art

        art:ClearAllPoints();art:SetPoint("TOPLEFT",3+piece[2],-47-piece[3]);art:SetSize(piece[4],piece[5])

        art:SetShown(U.ClientTexture(art,base..piece[1]));art:SetVertexColor(.67,.62,.53,1)

    end

end



function M.Talents()

    local page=M.talentPage or "Guide"

    if page~="Guide" and page~="Plan" or not ns.db.settings.modules.talents then talentPages();return end

    local definitions=T.Definitions();if #definitions==0 then M.Line("No sourced talent trees for this class.");return end

    for i,name in ipairs({"Guide","Plan","Builds","Match"}) do local choice=name

        at(U.Button(M.body,(page==name and "|cffffd16a" or "")..(name=="Guide" and "Home" or name),148,function() M.talentPage=choice;M.Render() end),8+(i-1)*156,M.y)

    end

    local search=at(U.Edit(M.body,250,M.talentSearch or "",function(v) M.talentSearch=v:lower();M.Render() end),M.width-405,M.y);U.Placeholder(search,"Find a talent")

    local levels={};for level=10,ns.Rules.Cap() do levels[#levels+1]={value=level,label="Level "..level} end

    at(U.Cycle(M.body,levels,ns.char.previewLevel or ns.Rules.Cap(),120,function(v) ns.char.previewLevel=v;M.Render() end),M.width-135,M.y)

    M.y=M.y-34

    local plan=page=="Plan";local ranks=plan and (ns.char.draft or {}) or T.actual

    local nextKey,suggestion=T.Next()

    local top=M.y;local treeWidth=282;local treeHeight=450;local treeTotals={}

    for ti,tree in ipairs(definitions) do

        local panel=U.Panel(M.body,treeWidth,treeHeight,8+(ti-1)*288,top);treeBackground(panel,tree)

        local total=0;for i in ipairs(tree.talents) do total=total+(ranks[T.Key(ti,i)] or 0) end;treeTotals[ti]=total

        local icon=panel.treeIcon or panel:CreateTexture(nil,"ARTWORK");panel.treeIcon=icon;icon:SetTexture("Interface\\Icons\\"..tree.icon);icon:SetSize(25,25);icon:SetPoint("TOPLEFT",9,-10)

        U.Label(panel,tree.name,41,-9,220,"GameFontNormal");U.Label(panel,total.." points",41,-28,210,"GameFontHighlightSmall")

        for _,definition in ipairs(tree.talents) do if definition.req then for pi,parent in ipairs(tree.talents) do if parent.name==definition.req then

            U.Dependency(panel,42+(parent.col-1)*64,-90-(parent.row-1)*52,42+(definition.col-1)*64,-54-(definition.row-1)*52,(ranks[T.Key(ti,pi)] or 0)>=parent.max)

        end end end end

        for i,definition in ipairs(tree.talents) do

            local key=T.Key(ti,i);local display=T.Display(key);local actual=T.actual[key] or 0;local rank=ranks[key] or 0

            local button=U.New("Button",panel,"BackdropTemplate");button:SetSize(48,48);button:SetPoint("TOPLEFT",18+(definition.col-1)*64,-59-(definition.row-1)*52);button:SetFrameLevel(panel:GetFrameLevel()+2)

            button:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10})

            local prospective=ns.Copy(ranks);prospective[key]=rank+1;local legal=T.Valid(prospective,plan and (ns.char.previewLevel or ns.Rules.Cap()) or ns.State.level)

            button:SetBackdropBorderColor(key==nextKey and legal and .25 or rank>0 and 1 or .4,key==nextKey and legal and 1 or rank>0 and .79 or .4,rank>0 and .16 or .4,1)

            button.icon=button.icon or button:CreateTexture(nil,"ARTWORK");button.icon:SetPoint("TOPLEFT",3,-3);button.icon:SetPoint("BOTTOMRIGHT",-3,3);button.icon:SetTexture(display.icon)

            local matches=(M.talentSearch or "")=="" or display.name:lower():find(M.talentSearch,1,true)

            button:SetAlpha(matches and 1 or .25);button.icon:SetDesaturated(rank==0)

            button.badge=button.badge or button:CreateTexture(nil,"OVERLAY");button.badge:SetColorTexture(.025,.03,.03,.95);button.badge:SetPoint("BOTTOMLEFT",3,3);button.badge:SetPoint("BOTTOMRIGHT",-3,3);button.badge:SetHeight(14)

            local badge=U.Label(button,rank.."/"..definition.max,3,-31,42,"GameFontHighlightSmall");badge:SetJustifyH("CENTER")

            button:RegisterForClicks("LeftButtonUp","RightButtonUp")

            button:SetScript("OnClick",function(_,mouse) M.selectedTalent=key;if plan and not IsShiftKeyDown() then edit(key,mouse=="RightButton" and -1 or 1) else M.Render() end end)

            U.Tooltip(button,display.name,{"Learned "..actual.."/"..definition.max.." | Plan "..rank.."/"..definition.max,(definition.desc or {})[math.max(1,rank)] or "",plan and "Left: add. Right: remove. Shift: inspect." or "Click to inspect. Open Plan to edit."},T.nodes[key] and T.nodes[key].spell and "spell:"..T.nodes[key].spell)

        end

    end

    local side=U.Panel(M.body,300,treeHeight,872,top)

    U.Label(side,plan and "Your talent plan" or (T.detected or "Your talents"),12,-12,276,"GameFontNormalLarge")

    U.Label(side,(plan and "PLANNED  " or "LEARNED  ")..table.concat(treeTotals," / ").." points",12,-42,276,"GameFontHighlight")

    local selected=M.selectedTalent and T.Definition(M.selectedTalent)

    U.Label(side,selected and T.Display(M.selectedTalent).name or nextKey and "Next planned point" or "Make this build yours",12,-76,276,"GameFontNormal")

    local detail=selected and ((selected.desc or {})[math.min(selected.max,(ranks[M.selectedTalent] or 0)+1)] or T.Display(M.selectedTalent).description) or suggestion

    local text=U.Label(side,detail or "Your learned talents are shown on Home. Select any talent to inspect it. Create a plan from your character, or choose a sourced build to follow its recorded point order.",12,-105,276,"GameFontHighlightSmall");text:SetWordWrap(true)

    if text:GetStringHeight()>198 then

        text:SetText("Hover the selected talent for its complete description.")

    end

    U.Label(side,M.talentMessage or (plan and "Editing a plan never spends live points." or "Hover shows learned and planned ranks. Gold borders show allocated ranks."),12,-315,276,"GameFontHighlightSmall")

    at(U.Button(side,plan and "View character" or "Edit plan",272,function() M.talentPage=plan and "Guide" or "Plan";M.Render() end),14,-405)

    M.y=top-treeHeight-10

    local build=ns.char.builds[ns.char.activeBuild or ""];local order=plan and ns.char.draftOrder or build and build.order

    if order and #order>0 then

        local timeline=U.Panel(M.body,M.width-16,66,8,M.y,"talentTimeline")

        U.Label(timeline,"Planned point order  |  "..#order.." points  |  "..T.Total(T.actual).." learned",10,-5,M.width-40,"GameFontNormalSmall")

        local spacing=(M.width-58)/math.max(1,#order-1)

        for n,key in ipairs(order) do local definition=T.Definition(key);if definition then

            local x=12+(n-1)*spacing;local icon=U.New("Button",timeline,nil,"plannedPoint");icon:SetSize(18,18);icon:SetPoint("TOPLEFT",x,-26)

            icon.art=icon.art or icon:CreateTexture(nil,"ARTWORK");icon.art:SetAllPoints();icon.art:SetTexture(T.Display(key).icon)

            if n==1 or (n+9)%10==0 or n==#order then U.Label(timeline,tostring(n+9),x,-48,28,"GameFontHighlightSmall") end

            if n==T.Total(T.actual)+1 then

                icon.glow=icon.glow or icon:CreateTexture(nil,"OVERLAY");icon.glow:SetAllPoints();icon.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");icon.glow:SetBlendMode("ADD");icon.glow:SetVertexColor(1,.8,.15,1);icon.glow:Show()

            elseif icon.glow then icon.glow:Hide() end

            icon:SetScript("OnClick",function() M.selectedTalent=key;M.Render() end)

            U.Tooltip(icon,definition.name,{"Planned level "..(n+9),n==T.Total(T.actual)+1 and "Next point in the order" or "Future plan, not purchase history.","Click to inspect this talent."})

        end end

        M.y=M.y-68

    end

    if plan then

        local name=at(U.Edit(M.body,190,ns.char.activeBuild or "My leveling plan"),12,M.y)

        at(U.Button(M.body,"Save & follow",130,function() if T.Save(name:GetText()) then M.talentPage="Guide" end;M.Render() end),215,M.y)

        at(U.Button(M.body,"From character",140,function() rememberDraft();ns.char.draft=ns.Copy(T.actual);ns.char.draftOrder={};ns.char.draftOrderOrigin="Copied learned allocation; purchase history is unknown";M.Render() end),355,M.y)

        at(U.Button(M.body,"Undo",90,function() local old=table.remove(ns.char.draftUndo or {});if old then ns.char.draft=old.ranks;ns.char.draftOrder=old.order;ns.char.draftOrderOrigin=old.origin;M.Render() end end),505,M.y)

        at(U.Button(M.body,"Clear",90,function() rememberDraft();ns.char.draft={};ns.char.draftOrder={};ns.char.draftOrderOrigin="Personal planned purchase order";M.Render() end),605,M.y)

        at(U.Button(M.body,"Point order",120,function() M.talentPage="Order";M.Render() end),705,M.y)

    else

        at(U.Button(M.body,"Choose build",150,function() M.talentPage="Builds";M.Render() end),10,M.y)

        at(U.Button(M.body,"Share / import",150,M.TalentCode),175,M.y)

        U.Label(M.body,"Learned "..T.Total(T.actual).." | Current level "..ns.State.level.." | "..(ns.char.activeBuild or "No plan selected"),350,M.y-5,470,"GameFontHighlightSmall")

    end

    M.y=M.y-35
    if not plan and ns.char.activeBuild and ns.char.builds[ns.char.activeBuild] then
        M.Action("Compare gear with my current talents",function() M.OpenPage("Equipment") end,310)
    end

end

local dungeonArt={ ["ragefire-chasm"]="RagefireChasm",["the-deadmines"]="Deadmines",["wailing-caverns"]="WailingCaverns",["shadowfang-keep"]="ShadowfangKeep",["the-stockade"]="StormwindStockades",["blackfathom-deeps"]="BlackfathomDeeps",["gnomeregan"]="Gnomeregan",["razorfen-kraul"]="RazorfenKraul",["razorfen-downs"]="RazorfenDowns",["scarlet-monastery"]="ScarletMonastery",["uldaman"]="Uldaman",["zul-farrak"]="ZulFarrak",["maraudon"]="Maraudon",["blackrock-depths"]="BlackrockDepths",["scholomance"]="Scholomance",["stratholme"]="Stratholme",["dire-maul"]="DireMaul",["dire-maul-east"]="DireMaul",["dire-maul-west"]="DireMaul",["dire-maul-north"]="DireMaul",["scarlet-monastery-graveyard"]="ScarletMonastery",["scarlet-monastery-library"]="ScarletMonastery",["scarlet-monastery-armory"]="ScarletMonastery",["scarlet-monastery-cathedral"]="ScarletMonastery",["zulfarrak"]="ZulFarrak",["sunken-temple"]="SunkenTemple" }

function M.Dungeons()

    if not ns.db.settings.modules.dungeons then dungeonDetails();return end

    if M.dungeonBrowse==false or M.dungeon and M.dungeonPage and M.dungeonPage~="Browse" and not M.dungeonBrowse then

        M.Action("Browse dungeons",function() M.dungeonBrowse=true;M.Render() end,180)

        local selected=ns.Journal.Get(M.dungeon)

        if selected and (selected.announcement or selected.nativeOnly) then

            M.Heading(selected.name);M.Line(ns.Journal.LevelText(selected));M.Line(ns.Journal.CatalogStatus(selected))

            M.Line("This place is included in the catalog. Bosses, quests and loot are not documented in the bundled journal yet.")

            M.Line("Your existing journal and quest records remain available from Browse dungeons.","GameFontHighlightSmall")

            if selected.sharedJournal then M.Action("Open shared instance journal",function() M.dungeon=selected.sharedJournal;M.dungeonPage="Overview";M.Render() end,260) end

            M.Action("Source details",function() ns.Message(selected.source) end,180);return

        end

        if M.DungeonWorkspace then M.DungeonWorkspace(dungeonDetails) else dungeonDetails() end;return

    end

    M.Heading("Browse dungeons");M.Line("Select a dungeon to view bosses, loot and quests.","GameFontHighlightSmall")

    local search=at(U.Edit(M.body,450,M.dungeonSearch or "",function(v) M.dungeonSearch=v:lower();M.dungeonBrowsePage=1;M.Render() end),14,M.y);U.Placeholder(search,"Search dungeon, zone, boss, item name or ID")

    at(U.Button(M.body,"Show all",140,function() M.dungeonSearch="";M.dungeonScope="all";M.dungeonBrowsePage=1;M.Render() end),500,M.y)

    local scope=at(U.Options(M.body,{{value="all",label="All dungeons and raids"},{value="level",label="Around my level"},{value="hunts",label="My tracked hunts"}},M.dungeonScope or "all",260,function(v) M.dungeonScope=v;M.dungeonBrowsePage=1;M.Render() end),M.width-285,M.y);M.y=M.y-math.max(36,scope:GetHeight()+10)

    local entries,matches={},{}

    for _,d in ipairs(ns.Journal.Entries()) do

        local match=ns.Journal.SearchMatch(d,M.dungeonSearch)
        local scope=M.dungeonScope or "all"
        if match and (scope=="all" or scope=="hunts" and ns.Journal.HuntCount(d)>0 or scope=="level" and not d.levelsUnknown and d.min<=ns.State.level+5 and d.max>=ns.State.level-5) then entries[#entries+1]=d;matches[d.slug]=match end

    end

    M.catalogMatches=#entries;M.catalogTotal=#ns.Journal.Entries()

    M.Line(#entries.." matching entries | "..#ns.Journal.Entries().." in the catalog | Ordered by entry level"..(ns.Journal.catalogPreparing and " | Reading client entries..." or ""),"GameFontHighlightSmall")

    local top=M.y;local columns=(#entries>40 or (ns.db.settings.textScale or 1)>1.1) and 5 or 4;local gap=8;local cellWidth=math.floor((M.width-16-gap*(columns-1))/columns)

    local lineY=top;local lineHeight=0

    for index,d in ipairs(entries) do

        local column=(index-1)%columns

        if column==0 and index>1 then lineY=lineY-lineHeight-5;lineHeight=0 end

        local card=U.New("Button",M.body,"BackdropTemplate","dungeonCard");card:SetWidth(cellWidth)

        card:SetPoint("TOPLEFT",8+column*(cellWidth+gap),lineY)

        card:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8});card:SetBackdropColor(.09,.07,.045,1);card:SetBackdropBorderColor(.42,.32,.16,1)

        card.art=card.art or card:CreateTexture(nil,"ARTWORK");card.art:ClearAllPoints();card.art:SetPoint("TOPLEFT",6,-6);card.art:SetSize(22,22)

        local art=dungeonArt[d.slug] or d.name:gsub("^The ",""):gsub("[^%w]","")

        if not U.ClientTexture(card.art,"Interface\\LFGFRAME\\LFGIcon-"..art) then card.art:SetTexture("Interface\\Icons\\INV_Misc_Key_14") end

        card.art:Show()

        local name=U.Label(card,d.name,35,-8,cellWidth-94,"GameFontHighlight")

        local level=U.Label(card,d.levelsUnknown and "?" or tostring(d.min).."-"..tostring(d.max),cellWidth-56,-10,48,"GameFontHighlightSmall");level:SetJustifyH("RIGHT")

        local height=math.max(34,name:GetStringHeight()+16);card:SetHeight(height);lineHeight=math.max(lineHeight,height)

        card:SetScript("OnClick",function()
            M.dungeonContexts=M.dungeonContexts or {}
            local fields={"dungeonPage","bossFilter","encounterSelection","lootSelection","lootQuery","questSelection","lootFacts","relevantLoot"}
            if M.dungeon then local saved={};for _,key in ipairs(fields) do saved[key]=M[key] end;M.dungeonContexts[M.dungeon]=saved end
            local previous=M.dungeonContexts[d.slug] or {dungeonPage="Loot",bossFilter=1,encounterSelection=1,lootQuery=""}
            M.dungeon=d.slug;M.dungeonBrowse=false
            for _,key in ipairs(fields) do M[key]=previous[key] end
            local match=matches[d.slug]
            if match and match.boss then
                M.dungeonPage=match.kind=="boss" and "Abilities" or "Loot";M.bossFilter=match.boss;M.encounterSelection=match.boss
                M.lootQuery=match.item and tostring(match.item) or "";M.lootSlot="all";M.lootOwnership="all";M.relevantLoot=false
                M.lootSelection=match.item and (d.slug..":"..match.bossName..":"..match.item) or nil
            end
            M.allBossLoot=false;M.Render()
        end)

        U.Tooltip(card,d.name,{ns.Journal.LevelText(d),d.zone or ns.Journal.CatalogStatus(d),d.questSource and #d.questSource.." source-listed quests" or "Quest details unavailable", "Open bosses, loot and quests.",d.source or "Source-listed reference"})

    end

    M.y=#entries>0 and lineY-lineHeight-8 or top

    if #entries==0 then M.Line("No matching dungeons. Clear the search or choose All dungeons and raids.") end

end

