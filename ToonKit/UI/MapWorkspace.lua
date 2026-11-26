local addonName, ns = ...
local A={worldPoints={}};ns.MapWorkspace=A
local layers={
    {"mapPins","Show ToonKit map layers"},
    {"mapGuidePins","Current guide destination"},
    {"questMapPins","Quests in my log"},
    {"questPickupPins","Eligible quest pickups"},
    {"flightMapPins","Flight masters"},
    {"mapTransportPins","Transport boarding points"},
    {"mapDungeonPins","Dungeon entrances"},
    {"mapBookPins","Books and discoveries"},
    {"gearHuntPins","Tracked gear hunts"},
    {"journeyMinimap","Objective / flight minimap pins"},
}
function A.Provider()
    local api=OpenMapAPI
    return type(api)=="table" and api.major==1 and api or nil
end
function A.Stitched()
    local api=A.Provider()
    if not api or type(api.IsStitched)~="function" then return false end
    local ok,value=pcall(api.IsStitched);return ok and ns.Safe(value)==true
end
function A.Supported()
    local api=A.Provider()
    return api and type(api.version)=="number" and api.version>=2 and type(api.CanvasFromWorldPos)=="function"
        and type(api.ArtTopLevel)=="function"
end
function A.Project(point,map)
    if A.Stitched() then return point end
    return ns.Travel.Project(point,map)
end
function A.CanvasPoint(point,map)
    if not A.Stitched() then
        local p=ns.Travel.Project(point,map);return p and p.x,p and p.y
    end
    if not ns.db.settings.openMapIntegration or not A.Supported() or not CreateVector2D then return end
    local key=table.concat({point.map,point.x,point.y},":")
    local world=A.worldPoints[key]
    if not world then
        local continent,pos=ns.API.Call("C_Map","GetWorldPosFromMapPos",point.map,CreateVector2D(point.x,point.y))
        continent=ns.Safe(continent)
        if type(continent)~="number" or not pos or type(pos.GetXY)~="function" then return end
        local ok,x,y=pcall(pos.GetXY,pos);x,y=ns.Safe(x),ns.Safe(y)
        if not ok or type(x)~="number" or type(y)~="number" then return end
        world={continent=continent,x=x,y=y};A.worldPoints[key]=world
    end
    local good,mx,my=pcall(A.Provider().CanvasFromWorldPos,world.continent,world.x,world.y)
    mx,my=ns.Safe(mx),ns.Safe(my)
    -- Coordinates outside 0..1 are intentional: OpenMap shows neighbouring maps.
    if good and type(mx)=="number" and type(my)=="number" then return mx,my end
end
-- Use OpenMap's registered AceConfig option, exactly as its own settings UI does.
-- Never write OpenMapDB, patch its methods, or replace the M binding.
function A.EnabledOption()
    if not LibStub then return end
    local registry=LibStub("AceConfigRegistry-3.0",true)
    if not registry or type(registry.GetOptionsTable)~="function" then return end
    local ok,options=pcall(registry.GetOptionsTable,registry,"OpenMap","dialog","ToonKit")
    local option=ok and type(options)=="table" and options.args and options.args.enabled
    if type(option)=="table" and type(option.get)=="function" and type(option.set)=="function" then return option end
end
function A.OpenMapEnabled()
    local option=A.EnabledOption();if not option then return end
    local ok,value=pcall(option.get,{"enabled"})
    if ok and type(value)=="boolean" then return value end
end
function A.SetOpenMap(value)
    if InCombatLockdown() then ns.Message("Change seamless map mode after combat.");return end
    local option=A.EnabledOption();if not option then ns.Message("The seamless map control is unavailable.");return end
    local ok,err=pcall(option.set,{"enabled"},value==true)
    if not ok then ns.errors.openMapToggle=tostring(err);ns.Message("The seamless map mode could not be changed. See /tk diagnostics.");return end
    A.reloadPending=true;A.Refresh()
end
function A.Refresh()
    if not A.panel or not A.panel:IsShown() then return end
    for _,check in ipairs(A.checks) do check:SetChecked(ns.db.settings[check.key]~=false) end
    A.compat:SetChecked(ns.db.settings.openMapIntegration~=false)
    local enabled=A.OpenMapEnabled()
    A.enable:SetChecked(enabled==true);A.enable:SetEnabled(enabled~=nil and not InCombatLockdown())
    local text=A.reloadPending and "Map mode saved. Type /reload to apply."
        or enabled==nil and "No compatible seamless map is loaded."
        or A.Stitched() and "Seamless view is active." or "Seamless map mode applies after /reload."
    if not A.reloadPending then
        if (A.Provider() or enabled~=nil) and not A.Supported() then text="The installed map provider lacks seamless pin support."
        elseif A.Stitched() and ns.db.settings.openMapIntegration==false then text="Seamless view is active. ToonKit pins are turned off for this provider."
        elseif A.Stitched() and ns.db.settings.mapPins==false then text="Seamless view is active. ToonKit map layers are turned off." end
    end
    A.status:SetText(text)
end
function A.Connect()
    local api=A.Provider();if not api or A.connected==api then return end
    if type(api.RegisterCallback)=="function" then
        local function changed() ns.After("openMapView",function() ns.World.RefreshPins();A.Refresh() end) end
        api.RegisterCallback(A,"OpenMap_ViewChanged",changed)
        api.RegisterCallback(A,"OpenMap_StitchedChanged",changed)
    end
    if type(api.RegisterMenuToggle)=="function" then
        for _,definition in ipairs(layers) do local key,label=definition[1],definition[2]
            api.RegisterMenuToggle("ToonKit",{id=key,label=label,section="ToonKit",tab="show",
                get=function() return ns.db and ns.db.settings[key]~=false end,
                set=function(on) ns.SetSetting(key,on==true) end})
        end
    end
    A.connected=api
end
function A.Create()
    A.Connect()
    if A.button or not WorldMapFrame then return end
    local map=WorldMapFrame
    local button=CreateFrame("Button",nil,map,"UIPanelButtonTemplate");A.button=button
    button:SetSize(132,24);button:SetText("ToonKit layers");button:SetPoint("BOTTOMLEFT",map,"BOTTOMLEFT",16,8)
    button:SetFrameLevel(map:GetFrameLevel()+40)
    local panel=CreateFrame("Frame",nil,map,"BackdropTemplate");A.panel=panel
    panel:SetSize(308,508);panel:SetPoint("BOTTOMLEFT",button,"TOPLEFT",0,5);panel:SetClampedToScreen(true)
    panel:SetFrameLevel(button:GetFrameLevel()+10);panel:EnableMouse(true)
    panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
    panel:SetBackdropColor(.045,.038,.027,.98);panel:SetBackdropBorderColor(.55,.43,.24,1)
    ns.UI.Label(panel,"Map layers",14,-14,240,"GameFontNormalLarge")
    local close=CreateFrame("Button",nil,panel,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-2,-2)
    close:SetScript("OnClick",function() panel:Hide() end)
    A.checks={};local y=42
    for _,definition in ipairs(layers) do local key,label=definition[1],definition[2]
        local check=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate");check:SetSize(24,24);check:SetPoint("TOPLEFT",12,-y)
        ns.UI.Label(check,label,28,-4,246,"GameFontHighlight");check.key=key
        check:SetScript("OnClick",function(self) ns.SetSetting(key,self:GetChecked()==true) end)
        A.checks[#A.checks+1]=check;y=y+27
    end
    A.compat=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate");A.compat:SetSize(24,24);A.compat:SetPoint("TOPLEFT",12,-y)
    ns.UI.Label(A.compat,"ToonKit layers on seamless maps",28,-4,246,"GameFontHighlight")
    A.compat:SetScript("OnClick",function(self) ns.SetSetting("openMapIntegration",self:GetChecked()==true) end);y=y+32
    A.enable=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate");A.enable:SetSize(24,24);A.enable:SetPoint("TOPLEFT",12,-y)
    ns.UI.Label(A.enable,"Enable seamless map (requires reload)",28,-4,246,"GameFontHighlight")
    A.enable:SetScript("OnClick",function(self) A.SetOpenMap(self:GetChecked()==true) end);y=y+32
    A.status=ns.UI.Label(panel,"",16,-y,276,"GameFontHighlightSmall");A.status:SetWordWrap(true)
    local options=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate");options:SetSize(160,25);options:SetPoint("BOTTOMLEFT",14,14);options:SetText("Seamless map settings")
    options:SetScript("OnClick",function()
        if SlashCmdList and type(SlashCmdList.OPENMAP)=="function" then SlashCmdList.OPENMAP("") else ns.Message("No compatible seamless map is loaded.") end
    end)
    panel:Hide();panel:SetScript("OnShow",A.Refresh)
    button:SetScript("OnClick",function() panel:SetShown(not panel:IsShown()) end)
    map:HookScript("OnHide",function() panel:Hide() end)
end
ns.On("PLAYER_LOGIN",function() ns.After("mapWorkspace",A.Create) end)
ns.On("PLAYER_ENTERING_WORLD",function() A.worldPoints={} end)
ns.On("ADDON_LOADED",function(name) if name=="OpenMap" or name=="Blizzard_WorldMap" then ns.After("mapWorkspace",A.Create) end end)
ns.Listen("SETTINGS_CHANGED",A.Refresh)
