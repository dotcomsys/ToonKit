local addonName, ns = ...
local P={};ns.Preferences=P
local extra={simpleUI=true,theme="forever",accent="gold",textScale=1,rowDensity="comfortable",windowScales={},
    bagWidth=460,bagHeight=360,bagIconSize=32,bagAutoHeight=false,bagPacked=true,bagCategoryColumns=2,guideWidth=320,guideObjectives=1,bagQuality=true,bagNewMarkers=false,bagGearTooltip=true,
    guideNotes=true,guideNext=true,guideProgress=true,guideArrow=true,guideNoteHeight=60,guideMaxHeight=420,
    startPage="Journey",rememberPage=true,xpDisplay=true,gearItemAdvice=true,
    bagItemLevel=true,bagBindingLabels=true,talentPointReminder=true,gearHuntPins=true,characterUpgradeButton=true}
extra.questMapPins=true;extra.flightMapPins=true;extra.journeyMinimap=true
extra.bagStableLayout=true
extra.questPickupPins=true;extra.mapDungeonPins=true;extra.mapBookPins=true;extra.openMapIntegration=true
extra.mapGuidePins=true;extra.mapTransportPins=true
extra.questTrackerEnabled=true;extra.questTrackerCollapsed=false;extra.questTrackerZone=false;extra.trackerTransparent=true
extra.barPosition="top";extra.barScale=1;extra.barWidth=1100;extra.barFontSize=13;extra.barOpacity=.9
extra.barAlignment="split"
extra.barIcons=true;extra.barHideCombat=false;extra.barHideAtCap=false;extra.barCoordinates=true;extra.barServerClock=false;extra.barClock24=true
extra.xpRateWindow="900";extra.barOrder="xp,rate,eta,rested,quests,mobs,session,money,bags,durability,location,|,performance,clock"
for _,id in ipairs({"xp","rate","eta","rested","quests","mobs","session","money","bags","durability","location","performance","clock"}) do extra["bar_"..id]=id~="quests" and id~="mobs" and id~="session" end
for k,v in pairs(extra) do ns.Defaults[k]=v end
P.integers={guideMaxHeight=true,guideWidth=true,guideObjectives=true,bagCategoryColumns=true,bagIconSize=true,bagColumns=true,bagSpacing=true,guideNoteHeight=true}
P.bounds={guideMaxHeight={220,640},bagWidth={320,1000},bagHeight={180,900},guideWidth={280,440},guideObjectives={1,5},bagCategoryColumns={1,4},scale={.65,1.5},textScale={.85,1.3},bagIconSize={28,56},bagColumns={4,20},bagSpacing={0,12},guideNoteHeight={40,160}}
P.choices={theme={forever=true,bronze=true,slate=true,umber=true},accent={gold=true,copper=true,ivory=true},rowDensity={compact=true,comfortable=true},bagSearchMode={filter=true,dim=true},startPage={Journey=true,Talents=true,Equipment=true,Farming=true,Dungeons=true,Books=true,Settings=true}}
P.bounds.barScale={.65,1.5};P.bounds.barWidth={400,2200};P.bounds.barFontSize={12,20};P.bounds.barOpacity={0,1}
P.integers.barFontSize=true;P.integers.barWidth=true
P.choices.barPosition={top=true,bottom=true,floating=true};P.choices.xpRateWindow={["0"]=true,["300"]=true,["900"]=true}
P.choices.barAlignment={split=true,center=true}
function P.Set(key,value)
    if P.bounds[key] then
        value=tonumber(value);local b=P.bounds[key]
        if not value or value~=value or value<b[1] or value>b[2] then ns.Message("Enter a value from "..b[1].." to "..b[2]..".");return false end
    elseif P.choices[key] and not P.choices[key][value] then return false end
    if P.integers[key] then value=math.floor(value) end
    ns.SetSetting(key,value);return true
end
function P.Normalize()
    if (ns.db.statusBarRevision or 0)<2 then ns.db.settings.xpDisplay=true;ns.db.statusBarRevision=2 end
    if not ns.db.compactFieldGuide then
        if ns.db.settings.guideObjectives==3 then ns.db.settings.guideObjectives=1 end
        ns.db.compactFieldGuide=true
    end
    if not ns.db.foreverPresentation then
        if ns.db.settings.theme=="bronze" then ns.db.settings.theme="forever" end
        ns.db.foreverPresentation=true
    end
    if not ns.db.quietBags then ns.db.settings.bagNewMarkers=false;ns.db.quietBags=true end
    if not ns.db.fixedBagLayout then ns.db.settings.showEmpty=false;ns.db.settings.bagColumns=12;ns.db.settings.bagPacked=true;ns.db.fixedBagLayout=true end
    if not ns.db.compactLayout then
        local s=ns.db.settings
        if s.bagWidth==565 and s.bagHeight==570 then s.bagWidth=390;s.bagHeight=340 end
        if s.bagIconSize==40 then s.bagIconSize=32 end
        if s.bagSpacing==4 then s.bagSpacing=2 end
        if s.guideNoteHeight==100 then s.guideNoteHeight=60 end
        s.bagGrouped=true;ns.db.compactLayout=true
    end
    for key,b in pairs(P.bounds) do local v=ns.db.settings[key]
        if type(v)~="number" or v~=v or v<b[1] or v>b[2] then ns.db.settings[key]=ns.Defaults[key] end
    end
    for key in pairs(P.integers) do ns.db.settings[key]=math.floor(ns.db.settings[key]) end
    for key,choices in pairs(P.choices) do if not choices[ns.db.settings[key]] then ns.db.settings[key]=ns.Defaults[key] end end
    for key,v in pairs(ns.db.settings.windowScales) do if type(v)~="number" or v~=v or v<.65 or v>1.5 then ns.db.settings.windowScales[key]=nil end end
end
function P.Save(name)
    name=tostring(name or ""):match("^%s*(.-)%s*$")
    if #name<1 or #name>32 then ns.Message("Use a profile name from 1 to 32 characters.");return end
    ns.db.profiles=ns.db.profiles or {}
    local count=0;for _ in pairs(ns.db.profiles) do count=count+1 end
    if count>=20 and not ns.db.profiles[name] then ns.Message("You can save up to 20 profiles.");return end
    for _,frame in ipairs(ns.UI and ns.UI.windows or {}) do
        local point,_,relative,x,y=frame:GetPoint()
        if frame.preferenceKey and point and not frame.embedded then ns.db.settings.positions[frame.preferenceKey]={point=point,relative=relative or point,x=x or 0,y=y or 0} end
    end
    ns.db.profiles[name]=ns.Copy(ns.db.settings);ns.db.profileName=name;ns.Message("Saved preferences: "..name)
end
function P.Load(name)
    local profile=ns.db.profiles and ns.db.profiles[name];if type(profile)~="table" then return end
    local merged=ns.Copy(ns.Defaults)
    for key in pairs(ns.Defaults) do if type(profile[key])==type(ns.Defaults[key]) then merged[key]=ns.Copy(profile[key]) end end
    ns.db.settings=merged;ns.db.profileName=name;P.Normalize();P.ApplyPositions()
    ns.Emit("SETTINGS_CHANGED");ns.Emit("STATE_CHANGED")
end
function P.ApplyPositions()
    for _,frame in ipairs(ns.UI and ns.UI.windows or {}) do
        if not frame.embedded then
        local pos=ns.db.settings.positions[frame.preferenceKey]
        frame:ClearAllPoints()
        if pos then frame:SetPoint(pos.point,UIParent,pos.relative,pos.x,pos.y) else frame:SetPoint("CENTER") end
        end
    end
end
ns.On("PLAYER_LOGIN",P.Normalize)
