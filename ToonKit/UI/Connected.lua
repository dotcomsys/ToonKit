local addonName, ns = ...
local C={};ns.Connected=C
local U,M=ns.UI,ns.Main
function C.UpdateScroll(pane)
    pane.scroll:UpdateScrollChildRect()
    local range=math.max(0,pane.content:GetHeight()-pane.scroll:GetHeight())
    pane.scroll:SetVerticalScroll(math.min(pane.scroll:GetVerticalScroll(),range))
    pane.scroll:EnableMouseWheel(range>1)
    local bar=pane.scroll.ScrollBar or pane.scroll.scrollBar
    if bar then bar:SetShown(range>1) end
end
function C.Footer(pane,actions,summary)
    local offset=16
    if #actions>0 then
        local width=(pane:GetWidth()-28-(#actions-1)*6)/#actions
        for index,action in ipairs(actions) do
            local button=U.Button(pane,action.label,width,action.run)
            button:SetPoint("BOTTOMLEFT",14+(index-1)*(width+6),12)
            button:SetEnabled(action.enabled~=false)
            offset=math.max(offset,button:GetHeight()+22)
        end
    end
    if summary then
        local label=U.Label(pane,summary,0,0,pane:GetWidth()-40,"GameFontHighlightSmall")
        label:ClearAllPoints();label:SetPoint("BOTTOMLEFT",20,offset-6)
        offset=offset+label:GetStringHeight()+4
    end
    pane.scroll:ClearAllPoints()
    pane.scroll:SetPoint("TOPLEFT",16,-16);pane.scroll:SetPoint("BOTTOMRIGHT",-32,offset)
    C.UpdateScroll(pane)
end
function C.Pane(parent,width,height,x,y,role,parchment)
    local f=U.New("Frame",parent,"BackdropTemplate",role)
    f:SetPoint("TOPLEFT",x,y);f:SetSize(width,height)
    f.parchment=parchment==true
    f:SetBackdrop({bgFile=parchment and "Interface\\Buttons\\WHITE8X8" or "Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=not parchment,tileSize=32,edgeSize=12,insets={left=5,right=5,top=5,bottom=5}})
    f:SetBackdropColor(parchment and .87 or 1,parchment and .76 or 1,parchment and .54 or 1,1)
    if parchment then
        -- Use a separately anchored texture: this client does not stretch the
        -- QuestBG backdrop to the full pane, leaving text over dark space.
        f.paper=f.paper or f:CreateTexture(nil,"BACKGROUND",nil,1)
        f.paper:ClearAllPoints();f.paper:SetPoint("TOPLEFT",5,-5);f.paper:SetPoint("BOTTOMRIGHT",-5,5)
        local atlas=QuestTextContrast and type(QuestTextContrast.GetDefaultBackgroundAtlas)=="function" and QuestTextContrast.GetDefaultBackgroundAtlas()
        local nativeAtlas=atlas and ns.API.Call("C_Texture","GetAtlasInfo",atlas)
        if nativeAtlas then f.paper:SetAtlas(atlas,false)
        else f.paper:SetTexture("Interface\\QuestFrame\\QuestBG");f.paper:SetTexCoord(0,1,0,1) end
        f.paper:SetVertexColor(1,1,1,1);f.paper:Show()
        f.lightText=nativeAtlas and QuestTextContrast and type(QuestTextContrast.UseLightText)=="function" and QuestTextContrast.UseLightText() or false
    elseif f.paper then f.paper:Hide();f.lightText=false end
    if not f.scroll then
        f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");f.scroll:SetPoint("TOPLEFT",12,-12);f.scroll:SetPoint("BOTTOMRIGHT",-30,12)
        f.content=CreateFrame("Frame",nil,f.scroll);f.content._managed=true;f.scroll:SetScrollChild(f.content)
    end
    if role and M.visiblePanes and parent==M.body then M.visiblePanes[role]=f end
    f.drawVisibleRows=nil
    U.Release(f.content);f.content:SetWidth(width-48);return f
end
function C.Read(pane,render,key)
    local body,width,y=M.body,M.width,M.y
    M.body=pane.content;M.width=pane.content:GetWidth();M.y=0
    local ok,err=pcall(render);local height=math.max(1,-M.y+8)
    M.body=body;M.width=width;M.y=y;pane.content:SetHeight(height)
    if pane.parchment then
        for font,pool in pairs(pane.content._fonts or {}) do
            for _,label in ipairs(pool) do
                if label:IsShown() then
                    if pane.lightText then label:SetTextColor(.94,.88,.73)
                    elseif font:find("Large") then label:SetTextColor(.27,.13,.035) else label:SetTextColor(.15,.10,.055) end
                    label:SetShadowColor(0,0,0,0)
                end
            end
        end
    end
    C.UpdateScroll(pane)
    if pane.context~=key then pane.scroll:SetVerticalScroll(0);pane.context=key end
    if not ok then error(err) end
end
function C.Badges(parent,badges,x,y,width)
    if (not badges or #badges==0) and not parent.journalBadges then return 0 end
    local columns=math.max(1,math.floor(width/21))
    parent.journalBadges=parent.journalBadges or {}
    for i,badge in ipairs(badges or {}) do
        local icon=parent.journalBadges[i] or parent:CreateTexture(nil,"ARTWORK")
        parent.journalBadges[i]=icon
        icon:ClearAllPoints();icon:SetSize(17,17)
        icon:SetPoint("TOPLEFT",x+(i-1)%columns*21,y-math.floor((i-1)/columns)*21)
        if badge.atlas then icon:SetAtlas(badge.atlas,false)
        else icon:SetTexture(badge.texture);icon:SetTexCoord(unpack(badge.coords or {0,1,0,1})) end
        icon:Show()
    end
    for i=(badges and #badges or 0)+1,#parent.journalBadges do parent.journalBadges[i]:Hide() end
    return badges and math.ceil(#badges/columns)*21 or 0
end
local function journalRow(pane,row,selected,callback,y,width,fixedHeight)
        local b=U.New("Button",pane.content,"BackdropTemplate","journalSelection")
        b:SetPoint("TOPLEFT",0,-y);b:SetWidth(width)
        b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        b:SetBackdropColor(row.value==selected and .29 or .16,.105,.035,1)
        b:SetBackdropBorderColor(row.value==selected and .9 or .42,row.value==selected and .69 or .30,.13,1)
        b.symbol=b.symbol or b:CreateTexture(nil,"ARTWORK");b.symbol:SetSize(row.iconSize or 19,row.iconSize or 19);b.symbol:SetPoint("TOPLEFT",8,-10)
        b.symbol:SetTexture(row.icon or "Interface\\GossipFrame\\AvailableQuestIcon")
        local inset=(row.iconSize or 19)+15
        local title=U.Label(b,row.label,inset,-9,width-inset-10,"GameFontNormal");title:SetTextColor(1,.82,.33)
        if title.SetMaxLines then title:SetMaxLines(fixedHeight and 2 or 0) end
        local h=title:GetStringHeight()+18
        h=h+C.Badges(b,row.badges,inset,-h+3,width-inset-10)
        if row.subtitle then
            local note=U.Label(b,row.subtitle,inset,-h+3,width-inset-10,"GameFontHighlightSmall");note:SetTextColor(.83,.75,.57)
            if note.SetMaxLines then note:SetMaxLines(fixedHeight and 1 or 0) end
            if fixedHeight then note:SetHeight(math.max(1,fixedHeight-h)) end
            h=h+note:GetStringHeight()+7
        end
        b:SetHeight(fixedHeight or math.max(45,h));b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
        b:RegisterForClicks("LeftButtonUp","RightButtonUp")
        b:SetScript("OnClick",function(_,mouse)
            if row.link and mouse=="RightButton" then ns.ItemCompare.Show(row.link);return end
            if row.link and HandleModifiedItemClick and HandleModifiedItemClick(row.link) then return end
            callback(row.value)
        end)
        if row.link then
            b:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(row.link);GameTooltip:Show() end)
            b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        end
        return b:GetHeight()
end
local function sectionLabel(pane,section,y,width)
    local label=U.Label(pane.content,section,4,-y,width-8,"GameFontNormal")
    label:SetTextColor(1,.82,.33)
    return label:GetStringHeight()
end
local function revealRow(pane,top,height)
    if not top then return end
    local scroll=pane.scroll:GetVerticalScroll();local viewport=pane.scroll:GetHeight()
    if top<scroll then pane.scroll:SetVerticalScroll(top)
    elseif top+height>scroll+viewport then pane.scroll:SetVerticalScroll(math.max(top+height-viewport,0)) end
end
function C.JournalList(pane,rows,selected,callback,reveal)
    local y=0;local width=pane.content:GetWidth();local section
    local selectedTop,selectedHeight
    for _,row in ipairs(rows) do
        if row.section and row.section~=section then
            section=row.section;y=y+sectionLabel(pane,section,y,width)+12
        end
        local height=journalRow(pane,row,selected,callback,y,width)
        if row.value==selected then selectedTop=y;selectedHeight=height end
        y=y+height+6
    end
    if #rows==0 then U.Label(pane.content,"No entries available.",0,0,width,"GameFontHighlightSmall");y=30 end
    pane.content:SetHeight(math.max(1,y));C.UpdateScroll(pane)
    if reveal then revealRow(pane,selectedTop,selectedHeight) end
end
function C.ScrollJournalList(pane,rows,selected,callback,reveal)
    if #rows==0 then return C.JournalList(pane,rows,selected,callback) end
    local width=pane.content:GetWidth()
    local scale=ns.db.settings.textScale or 1
    local rowHeight=math.ceil(64*scale)
    local entries={};local section;local y,selectedTop=0,nil
    for _,row in ipairs(rows) do
        if row.section and row.section~=section then
            section=row.section
            local height=math.ceil(27*scale)
            entries[#entries+1]={section=section,y=y,height=height}
            y=y+height
        end
        entries[#entries+1]={row=row,y=y,height=rowHeight+6}
        if row.value==selected then selectedTop=y end
        y=y+rowHeight+6
    end
    local previousFirst,previousLast
    pane.drawVisibleRows=function()
        local top=pane.scroll:GetVerticalScroll()
        local bottom=top+pane.scroll:GetHeight()+rowHeight
        local first,last=1,#entries
        while first<last do
            local middle=math.floor((first+last)/2)
            local entry=entries[middle]
            if entry.y+entry.height<top-rowHeight then first=middle+1 else last=middle end
        end
        last=first
        while entries[last+1] and entries[last+1].y<=bottom do last=last+1 end
        if previousFirst==first and previousLast==last then return end
        previousFirst,previousLast=first,last
        U.Release(pane.content)
        for i=first,last do
            local entry=entries[i]
            if entry.section then sectionLabel(pane,entry.section,entry.y,width)
            else journalRow(pane,entry.row,selected,callback,entry.y,width,rowHeight) end
        end
    end
    if not pane.scrollObserved then
        pane.scrollObserved=true
        pane.scroll:HookScript("OnVerticalScroll",function()
            if pane.drawVisibleRows and pane:IsVisible() then pane.drawVisibleRows() end
        end)
    end
    pane.content:SetHeight(math.max(1,y));C.UpdateScroll(pane)
    if reveal then revealRow(pane,selectedTop,rowHeight) end
    pane.drawVisibleRows()
end
function C.ItemTiles(items,callback,secondary,showDecision)
    local top=M.y;local columns=M.width>=400 and 2 or 1;local gap=8
    local width=(M.width-16-(columns-1)*gap)/columns;local y=0;local lineHeight=0;local line={}
    for index,entry in ipairs(items) do local item=entry
        if (index-1)%columns==0 and index>1 then
            for _,tile in ipairs(line) do tile:SetHeight(lineHeight) end
            y=y+lineHeight+gap;line={};lineHeight=0
        end
        local info=ns.API.Item(item.link or item.id)
        local b=U.New("Button",M.body,"BackdropTemplate","journalItem")
        b:SetPoint("TOPLEFT",8+((index-1)%columns)*(width+gap),top-y);b:SetWidth(width)
        b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        b:SetBackdropColor(.13,.085,.035,.96);b:SetBackdropBorderColor(.47,.34,.16,1)
        b.icon=b.icon or b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(36,36);b.icon:SetPoint("TOPLEFT",8,-8)
        b.icon:SetTexture(info and info.icon or item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local text=U.Label(b,info and info.link or item.name or ("Item "..item.id),52,-12,width-62,"GameFontNormal")
        text:SetTextColor(.94,.87,.66)
        local height=text:GetStringHeight()+24
        if showDecision then
            local status,advice=ns.ItemComparison.ItemDecision(item.id,item.link,info)
            local price=ns.ItemComparison.VendorValue(info,1)
            if item.referenceOnly then status="Source reference"
            elseif item.actionable==false and item.reason then status=item.reason;advice=nil end
            if status or price~=nil then
                local detail=status or ""
                if price~=nil then detail=detail..(status and " · " or "").."Vendor each "..ns.Gold.Format(price) end
                local label=U.Label(b,detail,52,-height+7,width-62,"GameFontHighlightSmall")
                if advice and advice.kind=="upgrade" and not item.referenceOnly then label:SetTextColor(.4,.95,.45) end
                height=height+label:GetStringHeight()+4
            end
        end
        lineHeight=math.max(lineHeight,52,height);line[#line+1]=b
        b:RegisterForClicks("LeftButtonUp","RightButtonUp");b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
        b:SetScript("OnClick",function(_,mouse)
            if mouse=="LeftButton" and info and info.link and HandleModifiedItemClick and HandleModifiedItemClick(info.link) then return end
            if mouse=="RightButton" and secondary then secondary(item) elseif callback then callback(item) end
        end)
        b:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(info and info.link or "item:"..item.id);GameTooltip:Show() end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    for _,tile in ipairs(line) do tile:SetHeight(lineHeight) end
    M.y=top-y-lineHeight-10
end
function C.List(pane,rows,selected,callback)
    local y=0
    for _,record in ipairs(rows) do
        local row=record
        local b=U.Button(pane.content,row.label,pane.content:GetWidth(),function() callback(row.value) end)
        b:SetPoint("TOPLEFT",0,-y)
        if row.value==selected then b:LockHighlight() end
        y=y+b:GetHeight()+4
    end
    if #rows==0 then U.Label(pane.content,"No source records available.",0,0,pane.content:GetWidth(),"GameFontHighlightSmall");y=28 end
    pane.content:SetHeight(math.max(1,y));C.UpdateScroll(pane)
end
function C.Map(point)
    if not point or not point.map or not point.x or not point.y then ns.Message("No precise sourced destination available.");return end
    local x,y=point.x,point.y;if x>1 or y>1 then x=x/100;y=y/100 end
    return ns.API.MapPoint(point.map,x,y,true)
end
function C.Item(record)
    local info=record.info or ns.API.Item(record.link or record.id,true)
    record.info=info
    M.Line(info and info.link or record.name or ("Item "..record.id),"GameFontNormal")
    M.Line(record.source or "Current Forever authored source","GameFontHighlightSmall")
    if record.referenceOnly or not ns.Gear.SourceConditions(record) then
        M.Line("Source reference")
    elseif record.actionable==false then
        M.Line(record.reason or "Acquisition unavailable")
    else
        local advice=ns.ItemComparison.Compare(record.id,record.link or info and info.link)
        if advice then M.Line(advice.text);if advice.reason then M.Line(advice.reason,"GameFontHighlightSmall") end end
    end
    M.Action("Compare",function() ns.ItemCompare.Show(record) end,180)
    local target=ns.char.farming[record.id]
    if target then
        M.Action("Remove target",function() ns.Gear.UntrackHunt(record.id) end,180)
        if ns.char.activeHunt==record.id then M.Action("Return to route",ns.Gear.StopFollowing,180)
        elseif not target.obtained then M.Action("Start hunt",function() if not ns.Gear.FollowHunt(record.id) then ns.Message("This hunt cannot start yet.") end end,180) end
    else
        local b=M.Action("Track target",function()
            local ok=ns.Gear.PlanReference(record);if not ok then ns.Message("Load item data and confirm current eligibility before tracking.") end
        end,180)
        b:SetEnabled(info~=nil and record.referenceOnly~=true)
    end
    if record.map and record.x and record.y then
        M.Action("Map",function() C.Map(record) end,180)
        M.Action("Set destination",function()
            local x,y=record.x,record.y;if x>1 or y>1 then x=x/100;y=y/100 end
            ns.char.questFocus=nil;ns.char.customWaypoint={map=record.map,x=x,y=y};ns.Navigation.Refresh();ns.Emit("STATE_CHANGED")
        end,180)
    end
end
