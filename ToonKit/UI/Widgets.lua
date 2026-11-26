local addonName, ns = ...
local U={labels={},themes={forever={.105,.085,.06,.88,.80,.66},bronze={.16,.12,.075,.88,.84,.72},slate={.10,.13,.18,.65,.73,.85},umber={.18,.095,.05,.80,.63,.48}},accents={gold={1,.82,.42},copper={1,.66,.39},ivory={.94,.90,.76}}}; ns.UI=U
function U.StyleLabel(label)
    local settings=ns.db and ns.db.settings;if not settings then return end
    label:SetFontObject(label.baseFont or "GameFontNormal")
    local path,size,flags=label:GetFont()
    if path and size then label:SetFont(path,math.max(size,(label.baseFont or ""):find("Small") and 11 or 13)*(settings.textScale or 1),flags) end
    label:SetTextColor(.90,.87,.79,1)
    local accent=U.accents[settings.accent] or U.accents.gold
    if (label.baseFont or ""):find("Large") then label:SetTextColor(accent[1],accent[2],accent[3],1) end
end
function U.Restyle()
    for _,label in ipairs(U.labels) do U.StyleLabel(label) end
    for _,frame in ipairs(U.windows or {}) do U.Skin(frame) end
end
-- Render pools keep event-driven redraws from allocating permanent WoW frames.
function U.New(kind,parent,template,role)
    if not parent._managed then return CreateFrame(kind,nil,parent,template) end
    parent._frames=parent._frames or {}; parent._indices=parent._indices or {}
    local key=kind..":"..(template or "")..":"..(role or ""); local i=(parent._indices[key] or 0)+1; parent._indices[key]=i
    parent._frames[key]=parent._frames[key] or {}; local f=parent._frames[key][i]
    if not f then f=CreateFrame(kind,nil,parent,template); f._managed=true; parent._frames[key][i]=f end
    f:ClearAllPoints(); f:SetAlpha(1);if f.UnlockHighlight then f:UnlockHighlight() end;if f.Enable then f:Enable() end; f:SetScript("OnEnter",nil); f:SetScript("OnLeave",nil); f:Show(); return f
end
function U.Release(parent)
    if U.choiceOwner==parent and U.choiceWindow then U.choiceWindow:Hide();U.choiceOwner=nil end
    parent._indices={}; parent._fontIndices={}
    for _,pool in pairs(parent._frames or {}) do for _,f in ipairs(pool) do U.Release(f); f:Hide() end end
    for _,pool in pairs(parent._fonts or {}) do for _,f in ipairs(pool) do f:Hide() end end
end
function U.Label(parent,text,x,y,width,font)
    local label; font=font or "GameFontNormal"
    if parent._managed then
        parent._fonts=parent._fonts or {}; parent._fontIndices=parent._fontIndices or {}
        local i=(parent._fontIndices[font] or 0)+1; parent._fontIndices[font]=i; parent._fonts[font]=parent._fonts[font] or {}
        label=parent._fonts[font][i]
        if not label then label=parent:CreateFontString(nil,"OVERLAY",font); parent._fonts[font][i]=label end
        label:ClearAllPoints(); label:SetHeight(0); label:Show()
    else label=parent:CreateFontString(nil,"OVERLAY",font) end
    if not label.baseFont then U.labels[#U.labels+1]=label end;label.baseFont=font;label:SetAlpha(1);U.StyleLabel(label)
    if label.SetMaxLines then label:SetMaxLines(0) end
    label:SetPoint("TOPLEFT",x,y); label:SetWidth(width or 700); label:SetWordWrap(true);if label.SetNonSpaceWrap then label:SetNonSpaceWrap(true) end;label:SetJustifyH("LEFT"); label:SetText(text)
    return label
end
-- Fit captions against the actual native font, including later menu caption changes.
function U.FitCaption(button)
    if button.captionFitting or not button.GetFontString then return end
    local text=button:GetFontString();if not text then return end
    button.captionFitting=true
    local path,size,flags=text:GetFont()
    if path and size then
        text:SetFont(path,12*(ns.db and ns.db.settings.textScale or 1),flags)
        text:SetWidth(math.max(20,button:GetWidth()-16));text:SetWordWrap(true);if text.SetNonSpaceWrap then text:SetNonSpaceWrap(true) end
        local height=math.max(28,text:GetStringHeight()+10)
        if button:GetHeight()~=height then button:SetHeight(height) end
    end
    button.captionFitting=nil
end

function U.Button(parent,text,width,callback)
    local b=U.New("Button",parent,"UIPanelButtonTemplate"); b:SetSize(width or 110,26); b:SetText(text)
    if not b.captionHooks then
        b.captionHooks=true;b:HookScript("OnSizeChanged",U.FitCaption);b:HookScript("OnShow",U.FitCaption)
        if hooksecurefunc then hooksecurefunc(b,"SetText",U.FitCaption) end
    end
    b:Enable();b:UnlockHighlight();b:SetAlpha(1)
    U.FitCaption(b);b:SetScript("OnClick",callback); return b
end
function U.IconButton(parent,icon,title,callback,size)
    local b=U.New("Button",parent,"UIPanelButtonTemplate","iconAction");b:SetSize(size or 24,size or 24);b:SetText("");b:SetScript("OnClick",callback)
    b.icon=b.icon or b:CreateTexture(nil,"ARTWORK");b.icon:SetSize((size or 24)-6,(size or 24)-6);b.icon:SetPoint("CENTER")
    if not U.ClientTexture(b.icon,icon) then b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
    U.Tooltip(b,title);return b
end
function U.Multiline(edit,scroll,minimum)
    if edit.scrollSizing then return end;edit.scrollSizing=true
    edit:SetMultiLine(true)
    edit:HookScript("OnTextChanged",function(self)
        local lines=self.GetNumLines and self:GetNumLines() or 1
        local _,size=self:GetFont();size=size or 12
        self:SetHeight(math.max(minimum or 80,lines*(size+2)+20))
    end)
    edit:HookScript("OnCursorChanged",function(_,_,y,_,height)
        if type(y)~="number" then return end
        local offset=math.max(0,-y);local top=scroll:GetVerticalScroll();local viewport=scroll:GetHeight()
        if offset<top then scroll:SetVerticalScroll(offset) elseif offset+(height or 16)>top+viewport then scroll:SetVerticalScroll(math.max(0,offset+(height or 16)-viewport)) end
    end)
end
function U.Edit(parent,width,text,callback)
    local e=U.New("EditBox",parent,"InputBoxTemplate"); e:SetSize(width or 180,24); e:SetAutoFocus(false);e:SetMaxLetters(0)
    if e.placeholder then e.placeholder:SetText("");e.placeholder:Hide() end
    e:SetText(text or "")
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusLost",function()
        if ns.Main and ns.Main.pendingRefresh then ns.Main.pendingRefresh=nil;ns.After("journalAfterEdit",ns.Main.Render) end
    end)
    e:SetScript("OnEnterPressed",callback and function(self) local value=self:GetText();self:ClearFocus();callback(value) end or nil)
    return e
end
function U.ResizeSkin(frame)
    if not frame.solid then return end
    -- Anchor both corners explicitly. Only the edge uses BackdropTemplate; its
    -- generated background must never cover or constrain this full-size surface.
    frame.solid:ClearAllPoints();frame.solid:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);frame.solid:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    frame.paper:ClearAllPoints();frame.paper:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);frame.paper:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    local width,height=math.max(1,frame:GetWidth()),math.max(1,frame:GetHeight())
    if frame.preferenceKey=="bags" then
        -- Crop the square background proportionally; never repeat marble
        -- veins or use tiled UVs on this independently sized bag surface.
        local x,y=math.min(1,width/height),math.min(1,height/width)
        frame.paper:SetTexCoord((1-x)/2,(1+x)/2,(1-y)/2,(1+y)/2)
    else frame.paper:SetTexCoord(0,width/256,0,height/256) end
end
function U.Skin(frame)
    if not frame.solid then
        frame.solid=frame:CreateTexture(nil,"BACKGROUND",nil,-8)
        frame.solid:SetColorTexture(.09,.065,.04,1)
        frame.paper=frame:CreateTexture(nil,"BACKGROUND",nil,-7)
        frame.paper:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
        frame.paper:SetHorizTile(true);frame.paper:SetVertTile(true);frame.paper:SetVertexColor(.85,.77,.62,1)
        frame:HookScript("OnSizeChanged",U.ResizeSkin)
    end
    local theme=U.themes[ns.db.settings.theme] or U.themes.bronze
    local accent=U.accents[ns.db.settings.accent] or U.accents.gold
    frame.solid:SetColorTexture(theme[1],theme[2],theme[3],1)
    local art=ns.db.settings.theme=="forever" and "Interface\\FrameGeneral\\UI-Background-Marble" or "Interface\\DialogFrame\\UI-DialogBox-Background"
    if frame.preferenceKey=="bags" then art="Interface\\DialogFrame\\UI-DialogBox-Background" end
    frame.paper:SetHorizTile(frame.preferenceKey~="bags");frame.paper:SetVertTile(frame.preferenceKey~="bags")
    if not U.ClientTexture(frame.paper,art) then frame.paper:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background") end
    frame.paper:SetVertexColor(theme[4],theme[5],theme[6],1)
    frame.paper:SetAlpha(frame.preferenceKey=="bags" and .18 or .35)
    frame:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Gold-Border",edgeSize=20,insets={left=0,right=0,top=0,bottom=0}})
    frame:SetBackdropBorderColor(accent[1]*.72,accent[2]*.72,accent[3]*.72,1);frame:SetAlpha(1)
    U.ResizeSkin(frame)
end
function U.NavigationButton(parent,text,callback,icon)
    local b=U.New("Button",parent);b:SetSize(150,34)
    b.fill=b.fill or b:CreateTexture(nil,"BACKGROUND");b.fill:SetAllPoints()
    b.text=U.Label(b,text,12,-9,132,"GameFontNormal")
    if icon then
        b.icon=b.icon or b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(20,20);b.icon:SetPoint("LEFT",7,0);b.icon:SetTexture(icon)
        b.text:ClearAllPoints();b.text:SetPoint("LEFT",33,0)
    end
    local function fitNavigation(self)
        local inset=self.icon and 39 or 18
        self.text:SetWidth(math.max(20,self:GetWidth()-inset));self.text:SetWordWrap(true)
        local height=math.max(34,self.text:GetStringHeight()+12)
        if self:GetHeight()~=height then self:SetHeight(height) end
    end
    if not b.navigationFit then b.navigationFit=true;b:HookScript("OnSizeChanged",fitNavigation) end;fitNavigation(b)
    b.line=b.line or b:CreateTexture(nil,"ARTWORK");b.line:SetColorTexture(.32,.25,.13,1);b.line:SetHeight(1);b.line:SetPoint("BOTTOMLEFT",6,0);b.line:SetPoint("BOTTOMRIGHT",-6,0)
    b:SetScript("OnClick",callback)
    b.SetSelected=function(self,selected)
        self.fill:SetColorTexture(selected and .25 or .10,selected and .17 or .075,selected and .07 or .045,1)
        local accent=U.accents[ns.db.settings.accent] or U.accents.gold
        self.text:SetTextColor(selected and accent[1] or .78,selected and accent[2] or .72,selected and accent[3] or .57,1)
    end
    b:SetSelected(false);return b
end
function U.Dependency(parent,x1,y1,x2,y2,met)
    local middle=(y1+y2)/2
    local function segment(ax,ay,bx,by)
        local f=U.New("Frame",parent);f:EnableMouse(false);f:SetFrameLevel(parent:GetFrameLevel()+1)
        f:SetPoint("TOPLEFT",math.min(ax,bx),math.max(ay,by));f:SetSize(math.max(2,math.abs(bx-ax)),math.max(2,math.abs(by-ay)))
        f.color=f.color or f:CreateTexture(nil,"ARTWORK");f.color:SetAllPoints();f.color:SetColorTexture(met and .35 or .6,met and .75 or .5,.18,1)
    end
    segment(x1,y1,x1,middle);segment(x1,middle,x2,middle);segment(x2,middle,x2,y2)
end
function U.PreferredScale(frame)
    local scale=(ns.db.settings.windowScales or {})[frame.preferenceKey] or ns.db.settings.scale
    if type(scale)~="number" or scale~=scale or scale<=0 or scale==math.huge then scale=1 end
    return scale
end
function U.Fit(frame)
    if frame.embedded then frame:SetScale(1);return end
    local scale=U.PreferredScale(frame)
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    if width>24 and height>24 and frame:GetWidth()>0 and frame:GetHeight()>0 then
        scale=math.min(scale,(width-24)/frame:GetWidth(),(height-24)/frame:GetHeight())
    end
    frame:SetScale(math.max(.1,scale))
end
-- Window positions belong to the player. Keep this compatibility entry point
-- side-effect free; opening bags must not move or hide the journal.
function U.ArrangePlayWindows() end
function U.FitWindows()
    for _,frame in ipairs(U.windows or {}) do U.Fit(frame) end
    if U.openMenu then U.Fit(U.openMenu) end
    U.ArrangePlayWindows(U.main)
end
function U.Window(width,height,title,key)
    local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate"); f:SetSize(width,height); f:SetPoint("CENTER"); f:SetFrameStrata(key=="bags" and "HIGH" or "MEDIUM");f:SetFrameLevel(key=="bags" and 50 or 10)
    f.preferenceKey=key;U.Skin(f); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetClampedToScreen(true)
    f.header=f:CreateTexture(nil,"ARTWORK");f.header:SetColorTexture(.18,.115,.055,1)
    f.header:SetPoint("TOPLEFT",12,-10);f.header:SetPoint("TOPRIGHT",-12,-10);f.header:SetHeight(32)
    f.divider=f:CreateTexture(nil,"ARTWORK");f.divider:SetColorTexture(.45,.34,.16,1)
    f.divider:SetPoint("TOPLEFT",15,-42);f.divider:SetPoint("TOPRIGHT",-15,-42);f.divider:SetHeight(1)
    f:SetScript("OnDragStart",function(self) if not ns.db.settings.locked then self:StartMoving() end end)
    f:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing(); local point,_,relative,x,y=self:GetPoint()
        ns.db.settings.positions[key]={point=point,relative=relative,x=x,y=y}
    end)
    local p=ns.db.settings.positions[key]
    if p then f:ClearAllPoints(); f:SetPoint(p.point,UIParent,p.relative,p.x,p.y) end
    U.Fit(f)
    U.windows=U.windows or {};U.windows[#U.windows+1]=f
    f.title=U.Label(f,title,22,-18,width-65,"GameFontNormalLarge")
    f:HookScript("OnSizeChanged",function(self) if self.title then self.title:SetWidth(math.max(1,self:GetWidth()-(self.titleRightInset or 65))) end end)
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-5,-5)
    f.close=close
    local embeddedKeys={inventoryActions=true,makeRoom=true,choiceWorkspace=true,organizer=true,bagDestinations=true,assignGroup=true,itemCompare=true,diagnostics=true,confirmation=true,buildCode=true,encounterNotes=true}
    if U.main and embeddedKeys[key] then
        f.embedded=true;f:SetParent(U.main);f:SetFrameStrata("MEDIUM");f:SetFrameLevel(U.main:GetFrameLevel()+30)
        f:SetMovable(false);f:SetScript("OnDragStart",nil);f:SetScript("OnDragStop",nil)
        f:ClearAllPoints();f:SetPoint("TOPLEFT",U.main,"TOPLEFT",24,-88);f:SetScale(1)
        local show=f.Show
        f.Show=function(self)
            if U.subpage~=self then
                local previous=U.subpage;local cursor=previous;local found=false;local depth=0
                while cursor and depth<8 do
                    if cursor==self then found=true;break end
                    cursor=cursor.previousPage;depth=depth+1
                end
                if found then
                    U.subpage=self
                    while previous and previous~=self do local nextPage=previous.previousPage;previous.previousPage=nil;previous:Hide();previous=nextPage end
                else
                    if depth>=8 then U.CloseSubpage();previous=nil end
                    self.previousPage=previous;U.subpage=self
                    if previous then previous:Hide() end
                end
            end
            self.pageTab=ns.Main.tab;self.pageSub=ns.Main.sub
            U.main:Show();if ns.Main.scroll then ns.Main.scroll:Hide() end
            if ns.Main.pageTitle then ns.Main.pageTitle:Hide() end
            show(self)
        end
        f:HookScript("OnHide",function(self)
            if U.subpage~=self then return end
            if not U.main:IsShown() then return end
            U.subpage=nil
            local previous=self.previousPage;self.previousPage=nil
            if previous then previous:Show() elseif ns.Main.scroll then ns.Main.scroll:Show();if ns.Main.pageTitle then ns.Main.pageTitle:Show() end;ns.Main.Render() end
        end)
        close:SetScript("OnClick",function() f:Hide() end)
        local back=U.Button(f,"Back",75,function() f:Hide() end);back:SetPoint("TOPRIGHT",-37,-14)
        f.titleRightInset=130;f.title:SetWidth(width-150)
    end
    f:Hide(); return f
end
function U.CloseSubpage()
    local f=U.subpage;U.subpage=nil
    while f do local previous=f.previousPage;f.previousPage=nil;f:Hide();f=previous end
    if ns.Main.scroll then ns.Main.scroll:Show() end
    if ns.Main.pageTitle then ns.Main.pageTitle:Show() end
end
ns.Listen("SETTINGS_CHANGED",function() U.Restyle();U.FitWindows() end)
ns.On("UI_SCALE_CHANGED",U.FitWindows)
ns.On("DISPLAY_SIZE_CHANGED",U.FitWindows)
function U.CompactChrome(frame)
    frame.header:ClearAllPoints();frame.header:SetPoint("TOPLEFT",8,-5);frame.header:SetPoint("TOPRIGHT",-8,-5);frame.header:SetHeight(23)
    frame.divider:ClearAllPoints();frame.divider:SetPoint("TOPLEFT",9,-30);frame.divider:SetPoint("TOPRIGHT",-9,-30)
    frame.title:ClearAllPoints();frame.title:SetPoint("TOPLEFT",12,-10);frame.title.baseFont="GameFontNormalSmall";U.StyleLabel(frame.title)
    frame.close:ClearAllPoints();frame.close:SetPoint("TOPRIGHT",-1,-1);frame.close:SetSize(26,26)
end
function U.Confirm(title,message,accept)
    if not U.confirmation then
        local f=U.Window(470,220,"Confirm","confirmation");U.confirmation=f
        f.message=U.Label(f,"",22,-57,425,"GameFontHighlight");f.message:SetWordWrap(true)
        local yes=U.Button(f,"Delete",150,function() local callback=f.accept;f:Hide();if callback then callback() end end);yes:SetPoint("BOTTOMLEFT",22,24)
        local no=U.Button(f,"Cancel",150,function() f:Hide() end);no:SetPoint("BOTTOMRIGHT",-22,24)
        f:SetScript("OnHide",function() f.accept=nil end)
    end
    local f=U.confirmation;f.title:SetText(title);f.message:SetText(message);f.accept=accept
    f:SetHeight(math.max(220,f.message:GetStringHeight()+125));f:Show();U.Fit(f)
end
function U.Tooltip(button,title,lines,link)
    button:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetText(title or "") end
        for _,line in ipairs(lines or {}) do GameTooltip:AddLine(line,1,.82,.5,true) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
function U.Item(parent,id,x,y,size,link)
    local b=U.New("Button",parent); b:SetSize(size or 30,size or 30); b:SetPoint("TOPLEFT",x,y)
    local info=ns.API.Item(link or id); b.icon=b.icon or b:CreateTexture(nil,"ARTWORK");local icon=b.icon;icon:ClearAllPoints(); icon:SetAllPoints(); icon:SetTexture(info and info.icon or 134400)
    U.Tooltip(b,info and info.name or tostring(id),nil,link or ("item:"..id))
    b:SetScript("OnClick",function() if HandleModifiedItemClick then HandleModifiedItemClick(link or ("item:"..id)) end end)
    return b
end
-- Named choices use the journal workspace, never a floating dropdown.
-- Inline choices reserve their measured height; no picker page for small sets.
function U.Options(parent,values,current,width,onChange,columns)
    local frame=U.New("Frame",parent,nil,"inlineOptions");frame:SetWidth(width)
    columns=columns or math.min(#values,math.max(1,math.floor(width/130)))
    columns=math.max(1,columns);local cw=math.floor((width-(columns-1)*6)/columns)
    local y,line=0,0
    for index,row in ipairs(values) do
        local col=(index-1)%columns
        if col==0 and index>1 then y=y+line+6;line=0 end
        local value=row.value
        local button=U.Button(frame,(value==current and "|cffffd16a" or "")..tostring(row.label),cw,function() onChange(value) end)
        button:SetPoint("TOPLEFT",col*(cw+6),-y)
        if row.tooltip then U.Tooltip(button,row.label,row.tooltip) end
        if value==current then button:LockHighlight() else button:UnlockHighlight() end
        line=math.max(line,button:GetHeight())
    end
    frame:SetHeight(math.max(26,y+line));return frame
end
-- A searchable roster stays beside its detail panel. Height is bounded, and
-- oversized catalogs ask for a narrower search rather than shrinking text.
function U.Roster(parent,values,current,width,height,onChange,key,externalSearch)
    local frame=U.New("Frame",parent,nil,"roster:"..(key or "choices"));frame:SetSize(width,height)
    frame.query=externalSearch and "" or frame.query or ""
    local function draw()
        U.Release(frame);local y=0;local filtered={}
        if not externalSearch and (#values>3 or frame.query~="") then
            local search=U.Edit(frame,width-8,frame.query,function(v) frame.query=v:lower();draw() end)
            search:SetPoint("TOPLEFT",4,0);U.Placeholder(search,"Find by name, then Enter");y=36
        end
        for _,row in ipairs(values) do if tostring(row.label):lower():find(frame.query,1,true) then filtered[#filtered+1]=row end end
        local capacity=0;local columns=math.min(3,math.max(1,math.floor(width/260)))
        local cw=math.floor(width/columns);local rowHeight=0;local exhausted=false
        for i,row in ipairs(filtered) do
            if exhausted then break end
            local col=(i-1)%columns
            if col==0 and i>1 then y=y+rowHeight+6;rowHeight=0 end
            local value=row.value
            local b=U.Button(frame,(value==current and "|cffffd16a" or "")..row.label,cw-8,function() onChange(value) end)
            local h=math.max(30,b:GetHeight());rowHeight=math.max(rowHeight,h)
            if exhausted or y+h>height-48 then b:Hide();exhausted=true else
                b:SetPoint("TOPLEFT",4+col*cw,-y);capacity=capacity+1
                if value==current then b:LockHighlight() else b:UnlockHighlight() end
            end
        end
        y=math.min(height-48,y+rowHeight+6)
        if capacity<#filtered then U.Label(frame,(#filtered-capacity)..(externalSearch and " more; refine search above." or " more; search by name."),4,-y,width-8,"GameFontHighlightSmall")
        elseif #filtered==0 then U.Label(frame,"No matching names.",4,-y,width-8,"GameFontHighlightSmall") end
    end
    draw();return frame
end
-- One pooled chooser for all named selections. Search stays outside the
-- result pool, so redraws do not steal keyboard focus or reset the cursor.
function U.FlatRoster(parent,values,current,width,height,onChange,key,context)
    local frame=U.New("Frame",parent,nil,"flatRoster:"..(key or "items"));frame:SetSize(width,height)
    if frame.context~=context then frame.query="";frame.context=context end
    frame.query=frame.query or ""
    if not frame.results then
        frame.results=CreateFrame("Frame",nil,frame);frame.results._managed=true
        frame.search=U.Edit(frame,width,"",nil)
        frame.search:SetPoint("TOPLEFT",4,0)
        U.Placeholder(frame.search,"Search names")
        frame.search:SetScript("OnTextChanged",function(self,userInput)
            if not userInput then return end
            frame.query=(self:GetText() or ""):lower();frame.serial=(frame.serial or 0)+1;local serial=frame.serial
            C_Timer.After(.12,function() if frame:IsShown() and frame.serial==serial and frame.draw then frame.draw() end end)
        end)
    end
    frame.search:SetWidth(width-8);frame.search:SetText(frame.query)
    frame.draw=function()
        U.Release(frame.results)
        local searching=#values>8 or frame.query~=""
        frame.search:SetShown(searching)
        local inset=searching and 34 or 0
        frame.results:ClearAllPoints();frame.results:SetPoint("TOPLEFT",0,-inset);frame.results:SetSize(width,math.max(1,height-inset))
        local matches={};for _,entry in ipairs(values) do if tostring(entry.label):lower():find(frame.query,1,true) then matches[#matches+1]=entry end end
        local columns=math.min(3,math.max(1,math.floor(width/260)));local cw=math.floor(width/columns)
        local y,line,shown=0,0,0
        for index,entry in ipairs(matches) do
            local col=(index-1)%columns
            if col==0 and index>1 then y=y+line+4;line=0 end
            local value=entry.value
            local button=U.New("Button",frame.results,nil,"listItem");button:SetWidth(cw-6)
            button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
            local title=U.Label(button,entry.label,6,-5,cw-18,"GameFontNormal")
            if value==current then title:SetTextColor(1,.82,.3) else title:SetTextColor(.86,.85,.8) end
            local h=math.max(28,title:GetStringHeight()+10)
            if y+h>height-inset-28 then button:Hide();break end
            button:SetHeight(h);button:SetPoint("TOPLEFT",col*cw,-y);button:SetScript("OnClick",function() onChange(value) end)
            U.Tooltip(button,entry.label)
            line=math.max(line,h);shown=shown+1
        end
        local hint=#matches==0 and "No matching names." or shown<#matches and (#matches-shown).." more; narrow the search." or ""
        U.Label(frame.results,hint,4,-math.min(height-inset-24,y+line+4),width-8,"GameFontHighlightSmall")
    end
    frame.draw();return frame
end
function U.Cycle(parent,values,current,width,onChange,label)
    local b=U.Button(parent,"",width)
    local function choices() return type(values)=="function" and values() or values end
    local function caption()
        for _,v in ipairs(choices()) do if v.value==current then return (label or "")..tostring(v.label) end end
        return label or "Choose"
    end
    b:SetText(caption())
    b:SetScript("OnClick",function()
        local rows=choices();if #rows==0 then return end
        if not U.choiceWindow then
            local page=U.Window(900,620,"Choose an option","choiceWorkspace");U.choiceWindow=page
            page.content=CreateFrame("Frame",nil,page);page.content._managed=true
            page.content:SetPoint("TOPLEFT",18,-90)
            page.search=U.Edit(page,850,"",nil);page.search:SetPoint("TOPLEFT",24,-48)
            U.Placeholder(page.search,"Search by name")
            page.search:SetScript("OnEscapePressed",function() page:Hide() end)
            page.search:SetScript("OnTextChanged",function(self,userInput)
                if not userInput then return end
                page.searchRevision=(page.searchRevision or 0)+1;local revision=page.searchRevision
                C_Timer.After(.12,function()
                    if page:IsShown() and page.searchRevision==revision and page.draw then page.draw() end
                end)
            end)
            page:HookScript("OnHide",function()
                page.search:ClearFocus();page.searchRevision=(page.searchRevision or 0)+1
                page.draw=nil;U.choiceOwner=nil
            end)
        end
        local page=U.choiceWindow;U.choiceOwner=b
        page.searchRevision=(page.searchRevision or 0)+1
        page.title:SetText(b.choiceTitle or label or caption());page.search:SetText("")
        page.draw=function()
            U.Release(page.content)
            local w=864;local height=490;local query=(page.search:GetText() or ""):lower()
            local filtered={};for _,row in ipairs(rows) do if tostring(row.label):lower():find(query,1,true) then filtered[#filtered+1]=row end end
            local columns=#filtered>8 and 3 or #filtered>4 and 2 or 1
            local cw=math.floor(w/columns);local y,line,shown=0,0,0
            for i,row in ipairs(filtered) do
                local col=(i-1)%columns
                if col==0 and i>1 then y=y+line+10;line=0 end
                local value=row.value
                local choice=U.Button(page.content,(value==current and "|cffffd16a" or "")..tostring(row.label),cw-12,function()
                    current=value;b:SetText(caption());page:Hide();onChange(value)
                end)
                local h=choice:GetHeight()
                if y+h>height-44 then choice:Hide();break end
                choice:SetPoint("TOPLEFT",col*cw,-y);line=math.max(line,h);shown=shown+1
                if value==current then choice:LockHighlight() end
            end
            local message=#filtered==0 and "No matching names." or shown<#filtered and (#filtered-shown).." more matches. Keep typing to narrow the list." or #filtered.." choices"
            U.Label(page.content,message,0,-math.min(height-26,y+line+12),w,"GameFontHighlightSmall")
            page.content:SetSize(w,height)
        end
        page:Show();page.draw();U.Fit(page)
        if #rows>6 then page.search:SetFocus() end
    end)
    return b
end
function U.CommandMenu(parent,values,width,caption,callback)
    local b
    b=U.Cycle(parent,values,nil,width,function(value) b:SetText(caption);callback(value) end,caption)
    b.choiceTitle=caption;b:SetText(caption);return b
end
function U.IconMenu(parent,values,icon,title,size,callback)
    local b
    b=U.Cycle(parent,values,nil,size,function(value) b:SetText("");callback(value) end,title)
    b.choiceTitle=title;b:SetText("");b:SetSize(size,size)
    b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(size-6,size-6);b.icon:SetPoint("CENTER");b.icon:SetTexture(icon)
    U.Tooltip(b,title);return b
end

function U.Check(parent,label,value,callback)
    local c=U.New("CheckButton",parent,"UICheckButtonTemplate"); c:SetSize(26,26)
    c.text=U.Label(c,label,30,-5,650); c:SetChecked(value)
    c:SetScript("OnClick",function(self) callback(self:GetChecked() and true or false) end); return c
end

function U.Placeholder(edit,text)
    if not edit.placeholder then
        edit.placeholder=edit:CreateFontString(nil,"OVERLAY","GameFontDisableSmall");edit.placeholder:SetPoint("LEFT",6,0);edit.placeholder:SetJustifyH("LEFT")
        edit:HookScript("OnTextChanged",function(self) self.placeholder:SetShown(self:GetText()=="") end)
        edit:HookScript("OnEditFocusGained",function(self) self.placeholder:Hide() end)
        edit:HookScript("OnEditFocusLost",function(self) self.placeholder:SetShown(self:GetText()=="") end)
        edit:HookScript("OnSizeChanged",function(self) self.placeholder:SetWidth(math.max(1,self:GetWidth()-12)) end)
    end
    edit.placeholder:SetWidth(math.max(1,edit:GetWidth()-12));edit.placeholder:SetText(text);edit.placeholder:SetShown(edit:GetText()=="")
end

function U.ClientTexture(texture,path)
    if type(path)=="string" and path:lower():find("interface\\addons\\",1,true)==1 then return texture:SetTexture(path)~=false end
    if type(GetFileIDFromPath)=="function" then
        local ok,id=pcall(GetFileIDFromPath,path);id=ok and ns.Safe(id)
        if type(id)~="number" or id<=0 then return false end
        texture:SetTexture(id);return true
    end
    return texture:SetTexture(path)~=false
end
