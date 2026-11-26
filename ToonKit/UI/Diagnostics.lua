local addonName, ns = ...
local U=ns.UI
local function count(tableValue) local n=0;for _ in pairs(tableValue or {}) do n=n+1 end;return n end
function ns.DiagnosticText()
    local version,build,_,interface=GetBuildInfo()
    local lines={ns.Brand.displayName.." "..ns.Brand.version,"Client: "..tostring(ns.Safe(version)).." / "..tostring(ns.Safe(build)).." / interface "..tostring(ns.Safe(interface)),
        "Class / level: "..tostring(ns.State.class).." / "..tostring(ns.State.level),"Rules: "..ns.db.settings.mode.."; cap "..ns.Rules.Cap(),
        "Talents: matched="..count(ns.Talents.nodes)..", unmatched="..#(ns.Talents.unmatched or {})..", mismatches="..tostring(ns.Talents.mismatches or 0),
        "Native spec: "..tostring(ns.State.spec).."; allocation="..table.concat(ns.Talents.totals or {0,0,0},"/").."; read="..tostring(ns.Talents.readReason or "ready"),
        "Bags: capacity="..tostring(ns.State.capacity)..", free="..tostring(ns.State.free)..", cells="..#ns.State.bags,
        "Bag draw: cells="..tostring(ns.Inventory.drawn or 0).."; failures="..tostring(ns.Inventory.cellErrors or 0).."; bag filter="..tostring(ns.Inventory.bagFilter),
        "Native bag template: "..tostring(ns.Inventory.supported==true).."; replacement enabled="..tostring(ns.Inventory.Enabled()==true),
        "Optional inventory providers: Masque="..tostring(ns.BagIntegrations.masque~=nil).."; Pawn API="..tostring(type(PawnShouldItemLinkHaveUpgradeArrow)=="function").."; appearance API="..tostring(type(CanIMogIt)=="table" and type(CanIMogIt.GetTooltipText)=="function"),
        "Item action: "..tostring(ns.InventoryActions.review and ns.InventoryActions.review.action).." / "..tostring(ns.InventoryActions.review and ns.InventoryActions.review.status).."; confirmed stacks="..tostring(ns.InventoryActions.review and ns.InventoryActions.review.completed or 0),
        "Quests: "..#ns.State.quests.."; refresh revision="..tostring(ns.State.revision),
        "Quest tracker enabled: "..tostring(ns.db.settings.questTrackerEnabled),
        "UI revision: "..tostring(U.revision).."; native tracker frames="..count(ns.QuestWorkspace.nativeTrackers).."; parked="..count(ns.QuestWorkspace.nativeParents),
        "Seamless map: API="..tostring(ns.MapWorkspace.Provider() and ns.MapWorkspace.Provider().version).."; seamless="..tostring(ns.MapWorkspace.Stitched()).."; ToonKit layers="..tostring(ns.db.settings.openMapIntegration).."; reload pending="..tostring(ns.MapWorkspace.reloadPending==true),
        "Saved quest snapshot: "..tostring(ns.char.questSnapshot and ns.char.questSnapshot.recorded).."; native progress always takes precedence",
        "Wetlands phase: "..tostring(ns.char.wetlandsProgress and ns.char.wetlandsProgress.phase).."; character refreshes="..tostring(ns.State.refreshCount or 0),
        "Item requests in flight: "..tostring(ns.API.loading or 0),
        "Route: "..tostring(ns.char.route).."; mode="..tostring(ns.char.routeMode),
        "Zone visit: "..tostring(ns.char.zoneVisit and ns.char.zoneVisit.map).."; source route="..tostring(ns.char.zoneVisit and ns.char.zoneVisit.route),
        "Trip commitment: "..tostring(ns.char.itinerary and ns.char.itinerary.family).."; destination map="..tostring(ns.char.itinerary and ns.char.itinerary.map),
        "Navigation ticker: "..tostring(ns.Navigation.ticker~=nil).."; minimap book pins="..#ns.DiscoveryPins.points,
        "Dungeon catalog: "..#ns.Journal.Entries().."; native scan ready="..tostring(ns.Journal.catalogReady==true).."; browser matches="..tostring(ns.Main.catalogMatches or "not opened"),
        "Journal selection: "..tostring(ns.Main.dungeon).."; boss="..tostring(ns.Main.encounterSelection).."; all-boss loot="..tostring(ns.Main.allBossLoot==true),
        "Bag assignment mode: "..tostring(ns.Inventory.assignMode==true).."; native destination API="..tostring(C_Container and type(C_Container.SetBagSlotFlag)=="function" or false),
        "Encounter history: "..count(ns.char.encounters).."; custom bag groups="..#ns.db.settings.bagGroups.."; rules="..#ns.db.settings.bagRules,
        "Recorded diagnostics follow; no client validation is implied."}
    local function errors(title,records)
        lines[#lines+1]=title..": "..count(records)
        local keys={};for key in pairs(records) do keys[#keys+1]=key end;table.sort(keys)
        for index=1,math.min(40,#keys) do local key=keys[index];lines[#lines+1]=key..": "..tostring(records[key]):sub(1,240) end
    end
    errors("Module errors",ns.errors);errors("API errors",ns.API.errors)
    return table.concat(lines,"\n"):sub(1,24000)
end
function ns.ShowDiagnostics()
    local f=U.diagnostics
    if not f then
        f=U.Window(760,540,ns.Brand.shortName.." - Diagnostics","diagnostics");U.diagnostics=f
        U.Label(f,"Click the text, press Ctrl+A then Ctrl+C to copy. No report is sent automatically.",24,-48,705,"GameFontHighlightSmall")
        f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");f.scroll:SetPoint("TOPLEFT",24,-80);f.scroll:SetSize(695,390)
        f.edit=U.Edit(f.scroll,665,"");U.Multiline(f.edit,f.scroll,390);f.edit:SetMaxLetters(24000);f.edit:SetHeight(390);f.scroll:SetScrollChild(f.edit)
        local refresh=U.Button(f,"Refresh report",180,function() f.edit:SetText(ns.DiagnosticText());f.scroll:SetVerticalScroll(0) end);refresh:SetPoint("BOTTOMLEFT",24,24)
    end
    f.edit:SetText(ns.DiagnosticText());f.scroll:SetVerticalScroll(0);f:Show()
end
