local addonName, ns = ...
local function commands(message)
    local cmd,arg=(message or ""):match("^(%S*)%s*(.-)%s*$"); cmd=cmd:lower()
    if cmd=="bags" then ns.Inventory.Toggle()
    elseif cmd=="talents" or cmd=="builds" then ns.Main.OpenPage("Talents",function() ns.Main.talentPage=cmd=="builds" and "Builds" or "Guide" end)
    elseif cmd=="gear" or cmd=="equipment" then ns.Main.OpenGearCandidate()
    elseif cmd=="upgrades" then
        local slot=tonumber(arg)
        for _,record in ipairs(ns.Data.slots) do if record[2]:lower()==arg:lower() then slot=record[1];break end end
        if arg~="" and not slot then ns.Message("Choose a slot name or number, such as /tk upgrades head or /tk upgrades 16.");return end
        if slot then local found=false;for _,record in ipairs(ns.Data.slots) do if slot==record[1] then found=true end end;if not found then ns.Message("Choose a normal equipment slot, such as head or 16.");return end end
        ns.Main.OpenQuickGear(slot)
    elseif cmd=="farming" or cmd=="hunts" then ns.Main.OpenPage("Farming",function() ns.Main.farmingDungeon=nil;ns.Main.farmingQuery="" end)
    elseif cmd=="bank" then ns.Bank.Show()
    elseif cmd=="bar" then ns.SetSetting("xpDisplay",not ns.db.settings.xpDisplay)
    elseif cmd=="xp" then if arg:lower()=="reset" then ns.Experience.Reset() else ns.ExperienceDisplay.Settings() end
    elseif cmd=="guide" then ns.SetSetting("guide",not ns.db.settings.guide)
    elseif cmd=="auto" then ns.Journey.Automatic(); ns.SetSetting("guide",true)
    elseif cmd=="settings" then ns.Main.OpenPage("Settings")
    elseif cmd=="route" then ns.Main.OpenJourneyPage("Routes",arg:lower())
    elseif cmd=="retrack" then ns.Journey.Retrack()
    elseif cmd=="tracker" then ns.QuestWorkspace.ShowTracker(arg=="reset")
    elseif cmd=="next" then ns.Main.routeStep=nil; ns.Journey.NextRoute()
    elseif cmd=="minimap" then ns.SetSetting("minimap",true); ns.db.settings.minimapAngle=225; ns.MinimapButton.Create(); ns.MinimapButton.Position()
    elseif cmd=="world" then if arg:lower()=="map" then ns.Main.OpenBookMap() else ns.Main.OpenPage("Books") end
    elseif cmd=="dungeons" then ns.Main.OpenPage("Dungeons")
    elseif cmd=="record" then ns.World.Register(arg)
    elseif cmd=="refresh" then ns.errors={}; ns.API.errors={}; ns.API.failed={}; ns.State.Refresh("all")
    elseif cmd=="diagnostics" then ns.ShowDiagnostics()
    elseif cmd=="help" then ns.Message("Commands: auto, bags, bank, bar, xp reset, guide, talents, builds, gear, upgrades <slot>, hunts, minimap, route <search>, retrack, next, settings, world, dungeons, record <title>, refresh, diagnostics.")
    else ns.Main.Toggle() end
end
ns.On("ADDON_LOADED",function(loaded)
    if loaded~=addonName then return end
    ns.LoadStore()
    for i,alias in ipairs(ns.Brand.aliases) do _G["SLASH_ADVENTURECOMPANION"..i]=alias end
    SlashCmdList.ADVENTURECOMPANION=commands
end)
ns.On("PLAYER_LOGIN",function()
    if not ns.db then return end
    if not ns.API.Client().supported then ns.Message("This ToonKit build supports WoW Forever only (Interface 16001).");return end
    ns.LoadCharacterStore()
    ns.Invoke("initialCharacterRefresh",ns.State.Refresh,"all")
    ns.Invoke("initialQuestTracker",ns.QuestWorkspace.UpdateTracker)
    ns.Main.Create(); ns.Main.CreateGuide(); ns.MinimapButton.Create(); ns.Inventory.Create(); ns.DiscoveryPins.Create();ns.Main.UpdateGuide()
    ns.DungeonJourney.Prompt()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local panel=CreateFrame("Frame")
        ns.UI.Label(panel,ns.Brand.displayName,16,-18,600,"GameFontNormalLarge")
        ns.UI.Label(panel,ns.Brand.description,16,-50,600,"GameFontHighlight")
        local button=ns.UI.Button(panel,"Open configuration",200,function() ns.Main.OpenPage("Settings") end)
        button:SetPoint("TOPLEFT",16,-90)
        ns.settingsCategory=Settings.RegisterCanvasLayoutCategory(panel,ns.Brand.displayName)
        Settings.RegisterAddOnCategory(ns.settingsCategory)
    end
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow",ns.World.RefreshPins)
        if WorldMapFrame.SetMapID then hooksecurefunc(WorldMapFrame,"SetMapID",ns.World.RefreshPins) end
        WorldMapFrame:HookScript("OnSizeChanged",ns.World.RefreshPins)
    end
    ns.Message(ns.Brand.version.." ready. "..ns.Brand.aliases[1].." opens your journal; "..(ns.Brand.aliases[2] or ns.Brand.aliases[1]).." bags opens inventory. ".."Forever live content.")
end)
ns.Listen("SETTINGS_CHANGED",function() ns.Talents.Detect(); ns.Main.UpdateGuide() end)
