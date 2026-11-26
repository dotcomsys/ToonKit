local addonName, ns = ...
local U,M,P=ns.UI,ns.Main,ns.Preferences
local about=M.About
local function control(label,description,build)
    local row=U.New("Frame",M.body);row:SetPoint("TOPLEFT",8,M.y);row:SetSize(M.width-16,38)
    row.fill=row.fill or row:CreateTexture(nil,"BACKGROUND");row.fill:SetAllPoints();row.fill:SetColorTexture(.075,.065,.045,1)
    local title=U.Label(row,label,12,-9,math.floor(M.width*.34)-24,"GameFontNormal");title:SetWordWrap(true)
    local widget=build(row);widget:SetPoint("TOPRIGHT",-12,-6)
    row:EnableMouse(true);U.Tooltip(row,label,{description,"Changes apply immediately; number fields apply with Enter."});U.Tooltip(widget,label,{description})
    local height=math.max(38,title:GetStringHeight()+17,widget:GetHeight()+12);row:SetHeight(height);M.y=M.y-height-3
end
local function check(key,label,description)
    control(label,description,function(row) return U.Check(row,"",ns.db.settings[key],function(v) P.Set(key,v) end) end)
end
local function number(key,label,description)
    control(label,description,function(row) local edit=U.Edit(row,110,tostring(ns.db.settings[key]),function(v) P.Set(key,v) end);edit:SetMaxLetters(8);return edit end)
end
local function choice(key,label,description,values)
    control(label,description,function(row) return U.Options(row,values,ns.db.settings[key],math.floor(M.width*.62),function(v) P.Set(key,v) end) end)
end
local function subtabs(section,names)
    M.settingsSections=M.settingsSections or {};local selected=M.settingsSections[section] or names[1]
    for i,name in ipairs(names) do local choice=name
        local b=U.Button(M.body,(selected==name and "|cffffd16a" or "")..name,155,function() M.settingsSections[section]=choice;M.lastPageKey=nil;M.Render() end)
        b:SetPoint("TOPLEFT",8+(i-1)*165,M.y)
    end
    M.y=M.y-34;return selected
end
function M.SettingsContent()
    local section=M.settingsPage or "Appearance"
    if section=="General" then section="Appearance" elseif section=="Bags" then section="Inventory" elseif section=="Modules" then section="Character" end
    M.Line("Changes apply immediately. Number fields apply when you press Enter.","GameFontHighlightSmall")
    if section=="Appearance" then
        local preview=U.Panel(M.body,M.width-16,56,8,M.y,"appearancePreview")
        U.Label(preview,"Your field journal",12,-10,M.width-210,"GameFontNormalLarge")
        U.Label(preview,"Current theme, accent and text size",12,-32,M.width-210,"GameFontHighlightSmall")
        local sample=U.Button(preview,"Selected action",155,function() end);sample:SetPoint("TOPRIGHT",-12,-14)
        M.y=M.y-66

        choice("theme","Classic background","Opaque texture fills every window.",{{value="forever",label="Forever parchment"},{value="bronze",label="Bronze"},{value="slate",label="Slate"},{value="umber",label="Umber"}})
        choice("accent","Headings and borders","Choose your classic accent color.",{{value="gold",label="Antique gold"},{value="copper",label="Copper"},{value="ivory",label="Ivory"}})
        check("xpDisplay","Status bar","XP and utility metrics; customize them in Status bar settings. Enabled by default.")
        number("textScale","Text size","0.85 to 1.30. Body labels reflow to fit.")
        number("scale","Overall window scale","0.65 to 1.50, capped to fit your screen.")
        control("Window to adjust","Select a window, then edit its scale below.",function(row)
            return U.Options(row,{{value="main",label="Journal"},{value="guide",label="Guide"},{value="bags",label="Bags"}},M.scaleWindow or "main",math.floor(M.width*.62),function(v) M.scaleWindow=v;M.Render() end,3)
        end)
        control("Selected window scale","0.65 to 1.50.",function(row)
            local key=M.scaleWindow or "main"
            return U.Edit(row,110,tostring(ns.db.settings.windowScales[key] or ns.db.settings.scale),function(v)
                local n=tonumber(v);if n and n>=.65 and n<=1.5 then ns.db.settings.windowScales[key]=n;ns.Emit("SETTINGS_CHANGED");M.Render() else ns.Message("Use a scale from 0.65 to 1.50.") end
            end)
        end)
        choice("rowDensity","Information density","Adjust spacing in headings, rows and lists.",{{value="comfortable",label="Comfortable"},{value="compact",label="Compact"}})
        check("locked","Lock positions","Prevents window dragging and minimap button movement.")
        M.Action("Use overall scale for all windows",function() ns.db.settings.windowScales={};ns.Emit("SETTINGS_CHANGED");M.Render() end,290)
        M.Action("Center all windows",function() ns.db.settings.positions={};P.ApplyPositions();ns.db.settings.minimapAngle=225;ns.MinimapButton.Position() end,220)
    elseif section=="Status bar" then
        local page=subtabs(section,{"Layout","Metrics","Session","Gold"})
        check("xpDisplay","Show status bar","Use /tk bar to toggle the status bar.")
        if page=="Layout" then
            choice("barPosition","Dock position","Top, bottom, or a draggable floating strip.",{{value="top",label="Top"},{value="bottom",label="Bottom"},{value="floating",label="Floating"}})
            choice("barAlignment","Metric alignment","Center each row or keep separate left and right groups.",{{value="center",label="Centered"},{value="split",label="Left and right"}})
            M.Action("Center floating bar",function() ns.ExperienceDisplay.Center();M.Render() end,220)
            number("barScale","Bar scale","0.65 to 1.50; separate from other windows.")
            number("barFontSize","Text size","12 to 20 pixels; metrics wrap to additional rows when needed.")
            number("barOpacity","Background opacity","0 for transparent, 1 for opaque.")
            number("barWidth","Floating width","400 to 2200 pixels; limited to available screen width.")
            check("barIcons","Metric icons","Small native icons beside metric values.")
            check("barHideCombat","Hide during combat","Restore the bar after combat ends.")
            check("barHideAtCap","Hide at active cap","Hide the entire strip at the active content cap.")
        elseif page=="Metrics" then
            for _,id in ipairs(ns.ExperienceDisplay.ids) do check("bar_"..id,ns.ExperienceDisplay.names[id],"Show this metric on the status bar.") end
            control("Metric order","Comma-separated metric IDs. Use | between left and right sections. Missing IDs are appended; visibility is controlled above.",function(row)
                return U.Edit(row,math.floor(M.width*.6),ns.db.settings.barOrder,function(v) ns.SetSetting("barOrder",v) end)
            end)
            M.Line("IDs: xp, rate, eta, rested, quests, mobs, session, money, goldrate, goldsession, goldlife, goldtotal, bags, durability, location, performance, clock","GameFontHighlightSmall")
        elseif page=="Gold" then
            check("goldRealmOnly","This realm only","Limit recorded character gold to this realm.")
            check("goldFactionOnly","This faction only","Limit recorded character gold to this faction.")
            M.Action("Reset gold session",function() ns.Gold.ResetSession();M.Render() end,240)
            M.Line("Loot and quest gold/hour: "..ns.Gold.EarningsRate(),"GameFontNormal")
            for _,line in ipairs(ns.Gold.Tooltip("goldrate")) do M.Line(line,"GameFontHighlightSmall") end
            for _,line in ipairs(ns.Gold.View().lines) do M.Line(line,"GameFontHighlightSmall") end
        else
            choice("xpRateWindow","XP rate window","Session average includes all session time; rolling windows include recent idle time. Rates start after one minute.",{{value="0",label="Session"},{value="300",label="5 minutes"},{value="900",label="15 minutes"}})
            check("barCoordinates","Location coordinates","Add current native map coordinates to the location metric.")
            check("barServerClock","Server clock","Use the native server clock instead of your local clock.")
            check("barClock24","24-hour local clock","Off: use a 12-hour local clock with AM/PM.")
            M.Action("Reset XP session",ns.Experience.Reset,240)
            for _,line in ipairs(ns.Experience.View().lines) do M.Line(line,"GameFontHighlightSmall") end
        end
    elseif section=="Journey" then
        local page=subtabs(section,{"Tracker","Guide","Automation"})
        if page=="Tracker" then
            check("questTrackerEnabled","ToonKit quest tracker","Show watched quests by zone and level. Right-click a quest for tracking controls.")
            check("questTrackerZone","Current-zone quests only","Use the native quest map association. Unmapped quests appear when this filter is off.")
            check("trackerTransparent","Transparent quest tracker","Show quest text without an opaque window background.")
        elseif page=="Guide" then
            number("guideWidth","Guide width","Width of the floating current-action guide.")
            number("guideMaxHeight","Maximum guide height","Long directions scroll within the guide.")
            check("guide","Floating guide","Keep your current action visible while playing.")
            check("guideHideInteraction","Hide during conversations","Temporarily hide during quest, gossip, merchant and trainer dialogs; restore afterward.")
            check("guideNotes","Directions and notes","Show source directions; full text remains in the journal.")
            check("guideNext","Upcoming action","Show the next task when it is not already an objective row.")
            check("guideProgress","Route progress","Show the step and action counts.")
        else
            check("autoAdvance","Automatic advancement","Advance using actual quest and objective evidence.")
            check("guideArrow","Direction arrow","Straight-line direction to a known destination.")
        end
    elseif section=="Inventory" then
        local page=subtabs(section,{"Layout","Items","Categories","Storage"})
        if page=="Layout" then
            M.Line("Keep full-size items on one canvas. Stable columns keep categories in the same column as their contents change.","GameFontHighlightSmall")
            check("bagStableLayout","Stable category columns","Use your preferred columns and category order. Disable to choose an automatically packed layout.")
            number("bagCategoryColumns","Category columns","1 to 4 fixed category columns when stable layout is enabled.")
            number("bagWidth","Preferred bag width","320 to 1000 pixels. Bags adapt to the available screen space.")
            number("bagHeight","Preferred bag height","180 to 900 pixels. The window grows to fit every slot.")
            check("bagAutoHeight","Fit height to contents","Reduce empty window space while keeping every item at its configured size.")
            number("bagIconSize","Item cell size","28 to 56 pixels; default 32.")
            number("bagColumns","Preferred item columns","Preferred column count when several layouts fit. Inventory chooses the largest readable fit for all items on one canvas.")
            number("bagSpacing","Space between cells","0 to 12 pixels; default 2.")
        elseif page=="Items" then
            check("inventory","Replace player bags","Native mode remains active until ToonKit inventory is reopened.")
            check("bagEquipmentSets","Equipment-set categories","Use named native equipment sets as automatic categories.")
            check("bagCategoryCounts","Category counts","Show the item-slot count beside category names.")
            check("showEmpty","Expand free slots","Off: one native empty drop slot with a free-space count. On: show every free slot.")
            choice("bagSearchMode","Search results","Hide other items, or dim them in place.",{{value="filter",label="Matching items only"},{value="dim",label="Dim other items"}})
            check("bagQuality","Quality borders","Show native item quality coloring.")
            check("bagNewMarkers","New item label","Optional static New label. No glow or flashing on refresh.")
            check("bagItemLevel","Equipment item levels","Show item level in the lower-left corner of live and recorded equipment cells.")
            check("bagMasque","Masque skins","Use the installed Masque inventory skin when available.")
            check("bagPawn","Pawn upgrade markers","Read upgrade advice from an installed, initialized Pawn. This does not change ToonKit scoring.")
            check("bagAppearances","Appearance markers","Read known appearance icons from an installed Can I Mog It. Stack quantities keep priority.")
            check("bagBindingLabels","Unbound BoE labels","Show BoE only when the native binding state confirms an unbound bind-on-equip item. New labels take priority in that corner.")
            check("gearItemAdvice","Item upgrades and sell advice","Automatically detect live Forever talents for school-aware item and quest reward advice. Include sourced effects, protect keep items and mark unresolved effects for review.")
            check("questKeepAdvice","Quest supply advice","Show sourced active, guide, pinned and nearby-future quest needs on item tooltips.")
        elseif page=="Storage" then
            M.Line("Banking uses the Blizzard bank window and controls.","GameFontHighlightSmall")
            M.Action("Show Blizzard bank",function() ns.Bank.Show() end,240)
            M.Action("Browse recorded storage",function() ns.InventoryOrganizer.Show("Storage") end,240)
        else
            check("bagGrouped","Category sections","Separate your items into named, collapsible groups.")
            check("bagPacked","Pack category groups","Balance complete categories into columns and choose a footprint that fits all item cells.")
            number("bagCategoryColumns","Preferred category columns","1 to 4 category columns; packing can choose more when needed to keep items readable.")
            M.Action("Edit groups and ordered rules",function() ns.InventoryOrganizer.Show("Groups") end,260)
        end
        M.Action("Choose physical bag destinations",function() ns.InventoryOrganizer.BagPreferences(0) end,300)
        M.Action("Assign individual item categories",function() ns.Inventory.assignMode=true;ns.Inventory.Show() end,300)
        local open=U.Button(M.body,"Open ToonKit inventory",220,function() ns.SetSetting("inventory",true);ns.Inventory.Show() end);open:SetPoint("TOPLEFT",8,M.y)
        local native=U.Button(M.body,"Use Blizzard bags",220,ns.Inventory.OpenNative);native:SetPoint("TOPLEFT",240,M.y);M.y=M.y-33
    elseif section=="Character" then
        check("talentPointReminder","Talent point announcements","Announce an available planned point when it or the active build changes.")
        check("gearHuntPins","Tracked hunt map pins","Show each unfinished hunt's sourced current destination. Shift-click a pin to open that hunt.")
        control("Planning role","Used by older gear planning views. Current comparisons follow live talents.",function(row)
            return U.Options(row,{{value="auto",label="Detect from talents"},{value="tank",label="Tank"},{value="healer",label="Healer"},{value="melee",label="Melee damage"},{value="ranged",label="Ranged damage"},{value="caster",label="Spell damage"}},ns.char.playstyle,math.floor(M.width*.62),function(v) ns.char.playstyle=v;ns.Talents.Detect();ns.Emit("STATE_CHANGED") end)
        end)
        control("Stat priorities","Edit advisory stat weights for the detected spec.",function(row)
            return U.Button(row,"Edit stat weights",200,function()
                M.OpenPage("Equipment",function() M.showWeights=true end)
            end)
        end)
        for _,entry in ipairs({{"journey","Journey"},{"talents","Talents"},{"gear","Gear advice"},{"dungeons","Dungeon journal"},{"world","Books and discoveries"}}) do local key=entry[1]
            control(entry[2],"Enable this feature in ToonKit.",function(row) return U.Check(row,"",ns.db.settings.modules[key],function(v) ns.db.settings.modules[key]=v;ns.Emit("SETTINGS_CHANGED");ns.Emit("STATE_CHANGED") end) end)
        end
        check("rememberPage","Remember my page","Reopen the journal where you left it.")
        local starts={};for _,page in ipairs({"Journey","Talents","Equipment","Farming","Dungeons","Books","Settings"}) do starts[#starts+1]={value=page,label=page} end
        choice("startPage","Starting page","Used on login and when page memory is disabled.",starts)
    elseif section=="Maps" then
        check("minimap","Minimap button","Left-click: journal. Right-click: bags. Shift-click: guide.")
        check("mapPins","World map markers","Show sourced Journey and book destinations.")
        check("discoveryMinimap","Book pins on minimap","Only mapped points within your current minimap radius.")
        check("questMapPins","Quest destinations and pickups","Live quest destinations and licensed reference points; nearby-level source pickups are not confirmed availability.")
        check("questPickupPins","Eligible quest pickups","Show route pickups whose known level and quest requirements you meet.")
        check("openMapIntegration","ToonKit layers on seamless maps","Show ToonKit layers when a compatible seamless map is loaded.")
        check("flightMapPins","Flight master locations","Licensed route locations and native recorded nodes; no flight connections are inferred.")
        check("journeyMinimap","Quest objectives and flight pins on minimap","Show ToonKit objective and flight markers alongside Blizzard quest pickups and turn-ins.")
        check("collections","Record readable objects","Record collection evidence from supported events.")
        check("nearby","Nearby discovery notices","Notify about discoveries on your current map.")
        check("notifications","Acquisition notices","Show ToonKit acquisition messages.")
    elseif section=="Profiles" then
        M.Heading("Your preference profiles")
        M.Line("Save appearance, window layout, bag rules and gear weights together. Loading a profile keeps quests, talent plans, books and farming progress.")
        M.Line("Last saved or loaded: "..(ns.db.profileName or "Unsaved preferences"),"GameFontNormal")
        control("Save preferences","An existing name replaces that saved profile.",function(row) return U.Edit(row,280,"",function(v) P.Save(v);M.Render() end) end)
        local values={};for name in pairs(ns.db.profiles or {}) do values[#values+1]={value=name,label=name} end
        table.sort(values,function(a,b) return a.label<b.label end)
        if #values>0 then
            control("Load saved profile","Applies preferences immediately. Save your current choices first.",function(row) return U.Cycle(row,values,ns.db.profileName,280,function(v) ns.OutOfCombat("loadProfile",function() P.Load(v) end) end) end)
        else M.Line("No saved profiles yet. Type a name above and press Enter.") end
        M.Action("Save current as character name",function() P.Save(ns.State.name);M.Render() end,290)
    else
        M.settingsPage="About";about()
    end
end
