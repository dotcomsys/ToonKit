local addonName, ns = ...
local E={entries={}};ns.ExperienceDisplay=E
local ids={"xp","rate","eta","rested","quests","mobs","session","money","goldrate","goldsession","goldlife","goldtotal","bags","durability","location","performance","clock"}
local names={xp="XP to level",rate="XP/hour",eta="Level in",rested="Rested XP",quests="Quests left",mobs="Mobs left",session="Session XP",money="Money",bags="Free bag slots",durability="Durability",location="Location",performance="FPS / latency",clock="Clock"}
local icons={xp="INV_Misc_Book_09",rate="INV_Misc_Book_09",eta="INV_Misc_PocketWatch_01",money="INV_Misc_Coin_01",bags="INV_Misc_Bag_08",durability="INV_Chest_Plate16",location="INV_Misc_Map_01",clock="INV_Misc_PocketWatch_01",performance="INV_Misc_Gear_01"}
E.ids=ids;E.names=names
names.goldrate="Loot and quest gold/hour";names.goldsession="Session wallet change";names.goldlife="Recorded wallet inflows";names.goldtotal="Recorded character gold"
for _,id in ipairs({"goldrate","goldsession","goldlife","goldtotal"}) do icons[id]=icons.money;ns.Defaults["bar_"..id]=id=="goldrate" end
local function read(name,...)
    local f=_G[name];if type(f)~="function" then return end
    local ok,a,b,c,d=pcall(f,...);if ok then return ns.Safe(a),ns.Safe(b),ns.Safe(c),ns.Safe(d) end
end
function E.Settings()
    ns.Main.OpenSettings("Status bar")
end
function E.Center()
    ns.db.settings.positions.statusBar={point="CENTER",relative="CENTER",x=0,y=0}
    ns.SetSetting("barPosition","floating")
    E.Update()
end
function E.Order(text)
    local left,right,seen={},{},{};local side=left
    for token in tostring(text):gmatch("[^,%s]+") do
        if token=="|" then side=right elseif names[token] and not seen[token] then side[#side+1]=token;seen[token]=true end
    end
    for _,id in ipairs(ids) do if not seen[id] then left[#left+1]=id end end
    return left,right
end
function E.Create()
    if E.frame then return end
    local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate");E.frame=f
    f:SetFrameStrata("LOW");f:SetMovable(true);f:SetClampedToScreen(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    local function startDrag()
        if ns.db.settings.barPosition=="floating" and not ns.db.settings.locked then f:StartMoving();E.dragging=true end
    end
    local function stopDrag()
        if not E.dragging then return end
        E.dragging=nil;f:StopMovingOrSizing()
        local p,_,r,x,y=f:GetPoint()
        ns.db.settings.positions.statusBar={point=p,relative=r,x=x,y=y}
    end
    f:SetScript("OnDragStart",startDrag)
    f:SetScript("OnDragStop",stopDrag)
    f:SetScript("OnMouseUp",function(_,button) if button=="RightButton" then E.Settings() end end)
    for _,id in ipairs(ids) do
        local button=CreateFrame("Button",nil,f);button:RegisterForClicks("LeftButtonUp","RightButtonUp")
        button:RegisterForDrag("LeftButton");button:SetScript("OnDragStart",startDrag);button:SetScript("OnDragStop",stopDrag)
        button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetSize(15,15);button.icon:SetPoint("LEFT",0,0)
        button.text=ns.UI.Label(button,"",0,0,1,"GameFontHighlight");button.text:ClearAllPoints();button.text:SetPoint("LEFT",0,0)
        button.text:SetWordWrap(false)
        if button.text.SetNonSpaceWrap then button.text:SetNonSpaceWrap(false) end
        if button.text.SetMaxLines then button.text:SetMaxLines(1) end
        button:SetScript("OnClick",function(_,key)
            if key=="LeftButton" and id=="bags" then ns.Inventory.Toggle() else E.Settings() end
        end)
        button:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_BOTTOMRIGHT");GameTooltip:SetText(names[id])
            if id=="xp" or id=="rate" or id=="eta" or id=="session" or id=="mobs" or id=="quests" or id=="rested" then
                for _,line in ipairs(ns.Experience.View().lines) do GameTooltip:AddLine(line,1,.85,.5,true) end
            elseif id=="money" or id:match("^gold") then for _,line in ipairs(ns.Gold.Tooltip(id)) do GameTooltip:AddLine(line,1,.85,.5,true) end
            else GameTooltip:AddLine(self.value or self.text:GetText(),1,.85,.5,true) end
            GameTooltip:AddLine(id=="bags" and "Left click: inventory. Right click: status bar settings." or "Click: status bar settings.",.7,.7,.7,true);GameTooltip:Show()
        end)
        button:SetScript("OnLeave",function() GameTooltip:Hide() end);E.entries[id]=button
    end
end
local xpMetrics={"xp","rate","eta","rested","quests","mobs","session"}
local goldMetrics={"goldsession","goldlife","goldtotal"}
local function enabled(s,id) return s["bar_"..id]~=false end
local function anyEnabled(s,metrics)
    for _,id in ipairs(metrics) do if enabled(s,id) then return true end end
end
local function values(s,reason)
    E.values=E.values or {}
    local v=E.values;local all=reason=="all";local tick=reason=="tick"
    if (all or reason=="xp" or tick and (enabled(s,"rate") or enabled(s,"eta") or enabled(s,"session"))) and anyEnabled(s,xpMetrics) then
        local xp=ns.Experience.View(true)
        v.xp="XP to level: "..xp.remaining;v.rate="XP/h: "..xp.rate;v.eta="Level in: "..xp.eta
        v.rested="Rested: "..xp.rested;v.quests="Quests left: "..xp.quests;v.mobs="Mobs left: "..xp.mobs
        v.session="Session XP: "..xp.session.." / "..xp.elapsed
    end
    if all or reason=="gold" then
        if anyEnabled(s,goldMetrics) then
            local gold=ns.Gold.View(true)
            v.goldsession="Wallet change: "..gold.session
            v.goldlife="Wallet inflows: "..gold.lifetime;v.goldtotal="Character gold: "..gold.total
        end
        if enabled(s,"money") then v.money=ns.Gold.Holdings() end
    end
    if (all or reason=="gold" or tick) and enabled(s,"goldrate") then v.goldrate="Loot + quest/h: "..ns.Gold.EarningsRate() end
    if (all or reason=="inventory") and enabled(s,"bags") then v.bags="Bags: "..(ns.State.free or 0).." / "..(ns.State.capacity or 0).." free" end
    if (all or reason=="services") and enabled(s,"durability") then
        local durability=ns.Services.durability
        v.durability="Durability: "..(type(durability)=="number" and math.floor(durability*100).."%" or "Unknown")
    end
    if (all or reason=="zone" or tick and s.barCoordinates) and enabled(s,"location") then
        v.location=read("GetRealZoneText") or read("GetZoneText") or "Unknown zone"
        if s.barCoordinates then
            local _,x,y=ns.API.Position()
            if type(x)=="number" and type(y)=="number" then v.location=string.format("%s %.1f, %.1f",v.location,x*100,y*100) end
        end
    end
    if all or tick then
        if enabled(s,"performance") then
            local fps=read("GetFramerate");local _,_,_,latency=read("GetNetStats")
            v.performance=(type(fps)=="number" and math.floor(fps).." FPS" or "FPS unknown")
                .." / "..(type(latency)=="number" and latency.." ms" or "latency unknown")
        end
        if enabled(s,"clock") then
            local clock
            if s.barServerClock then
                local h,m=read("GetGameTime")
                if type(h)=="number" and type(m)=="number" then clock=string.format("%02d:%02d",h,m) end
            else clock=read("date",s.barClock24 and "%H:%M" or "%I:%M %p") end
            v.clock=clock or "Clock unavailable"
        end
    end
    return v
end
local function anchor(frame,s,width,scale,saved)
    frame:SetScale(scale);frame:SetWidth(width);frame:ClearAllPoints()
    if s.barPosition=="bottom" then frame:SetPoint("BOTTOM",UIParent,"BOTTOM",0,0)
    elseif s.barPosition=="floating" and saved then frame:SetPoint(saved.point,UIParent,saved.relative,saved.x,saved.y)
    elseif s.barPosition=="floating" then frame:SetPoint("TOP",UIParent,"TOP",0,-40)
    else frame:SetPoint("TOP",UIParent,"TOP",0,0) end
    frame:SetBackdropColor(.035,.045,.06,s.barOpacity or .9)
    frame:SetBackdropBorderColor(.28,.32,.38,s.barOpacity or .9)
end
local function layout(width,height,alignment)
    if alignment=="center" then
        local rows={{width=0}}
        for _,group in ipairs({E.left,E.right}) do
            for _,id in ipairs(group) do
                local button=E.entries[id]
                if button:IsShown() then
                    local row=rows[#rows]
                    if row.width+button.metricWidth>width-24 then row={width=0};rows[#rows+1]=row end
                    row[#row+1]=button;row.width=row.width+button.metricWidth
                end
            end
        end
        for index,row in ipairs(rows) do
            local x=(width-row.width)/2
            for _,button in ipairs(row) do
                button:ClearAllPoints();button:SetPoint("TOPLEFT",x,-(index-1)*height);button:SetHeight(height)
                x=x+button.metricWidth
            end
        end
        E.frame:SetHeight(#rows*height)
        return
    end
    local rightEdge=width-12;local row=0;local limits={}
    local x=rightEdge
    for index=#E.right,1,-1 do
        local b=E.entries[E.right[index]]
        if b:IsShown() then
            if x-b.metricWidth<12 then row=row+1;x=rightEdge end
            x=x-b.metricWidth;limits[row]=x
            b:ClearAllPoints();b:SetPoint("TOPLEFT",x,-row*height);b:SetHeight(height)
        end
    end
    local lastRight=row
    row=0;x=12
    for _,id in ipairs(E.left) do
        local b=E.entries[id]
        if b:IsShown() then
            while x+b.metricWidth>(limits[row] or rightEdge)+.001 do row=row+1;x=12 end
            b:ClearAllPoints();b:SetPoint("TOPLEFT",x,-row*height);b:SetHeight(height)
            x=x+b.metricWidth
        end
    end
    E.frame:SetHeight((math.max(lastRight,row)+1)*height)
end
function E.Update(reason)
    if not ns.char or not ns.Experience then return end
    E.Create();local s=ns.db.settings;local f=E.frame
    local visible=s.xpDisplay and not (s.barHideCombat and InCombatLockdown()) and not (s.barHideAtCap and (ns.State.level or 0)>=ns.Rules.Cap())
    if visible and not f:IsShown() then reason="all" end
    f:SetShown(visible)
    if not visible then if E.ticker then E.ticker:Cancel();E.ticker=nil end;return end
    local animated=anyEnabled(s,{"rate","eta","session","goldrate","performance","clock"}) or s.barCoordinates and enabled(s,"location")
    if animated and not E.ticker and C_Timer.NewTicker then E.ticker=C_Timer.NewTicker(1,function() E.Update("tick") end)
    elseif not animated and E.ticker then E.ticker:Cancel();E.ticker=nil end
    local scale=s.barScale or 1
    local width=math.max(48,s.barPosition=="floating" and math.min(s.barWidth or 1100,UIParent:GetWidth()/scale-24) or UIParent:GetWidth()/scale)
    local saved=s.positions.statusBar
    local geometry=table.concat({width,scale,s.barPosition or "",s.barOpacity or .9,
        saved and saved.point or "",saved and saved.relative or "",saved and saved.x or 0,saved and saved.y or 0},":")
    if E.geometry~=geometry then E.geometry=geometry;anchor(f,s,width,scale,saved) end
    local fontSize=s.barFontSize or 13
    local style=table.concat({width,fontSize,tostring(s.barIcons),tostring(s.barOrder),s.barAlignment or "split"},":")
    local restyle=E.style~=style or not E.left
    if restyle then
        E.style=style;E.left,E.right=E.Order(s.barOrder)
    end
    local current=values(s,reason or "all")
    local relayout=restyle
    local height=fontSize+10
    for _,id in ipairs(ids) do
        local b=E.entries[id];local show=enabled(s,id)
        if b:IsShown()~=show then b:SetShown(show);relayout=true end
        if show then
            local text=current[id] or "Unavailable"
            if restyle or b.value~=text or not b.metricWidth then
                local font,_,flags=GameFontHighlight:GetFont()
                local icon=s.barIcons and icons[id]
                local inset=icon and 19 or 0
                b.icon:SetShown(icon and true or false)
                if icon then b.icon:SetTexture("Interface\\Icons\\"..icon) end
                b.text:ClearAllPoints();b.text:SetPoint("LEFT",inset,0)
                b.text:SetFont(font,fontSize,flags);b.text:SetWidth(0);b.text:SetHeight(0);b.text:SetText(text)
                local natural=b.text:GetStringWidth()
                if b.text.GetUnboundedStringWidth then natural=math.max(natural,b.text:GetUnboundedStringWidth()) end
                local metricWidth=math.min(width-24,math.ceil(natural)+inset+16)
                b:SetWidth(metricWidth);b.text:SetWidth(math.max(1,metricWidth-inset-8))
                if metricWidth~=b.metricWidth then relayout=true end
                b.value=text;b.metricWidth=metricWidth;b.metricHeight=math.ceil(b.text:GetStringHeight())+8
            end
            height=math.max(height,b.metricHeight)
        end
    end
    if relayout or E.height~=height then E.height=height;layout(width,height,s.barAlignment) end
end
ns.Listen("EXPERIENCE_CHANGED",function() E.Update("xp") end)
ns.Listen("GOLD_CHANGED",function() if E.frame and E.frame:IsShown() then ns.After("statusGold",function() E.Update("gold") end) end end)
ns.Listen("SERVICES_CHANGED",function() if E.frame and E.frame:IsShown() then E.Update("services") end end)
ns.Listen("SETTINGS_CHANGED",function() E.Update() end)
ns.Listen("STATE_CHANGED",function(kind)
    if ns.Changed(kind,"identity","inventory") then ns.After("statusInventory",function() E.Update("inventory") end) end
end)
for _,event in ipairs({"ZONE_CHANGED","ZONE_CHANGED_NEW_AREA","ZONE_CHANGED_INDOORS"}) do
    ns.On(event,function() if E.frame and E.frame:IsShown() then ns.After("statusZone",function() E.Update("zone") end) end end)
end
for _,event in ipairs({"PLAYER_LOGIN","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"}) do ns.On(event,function() ns.After("statusBar",E.Update) end) end
