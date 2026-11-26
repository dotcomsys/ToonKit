local addonName, ns = ...
local M,U=ns.Main,ns.UI
U.revision="forever-upgrade-filter-and-raid-audit-20261123"
local openPage=M.OpenPage
M.history={}
local journalFields={"tab","sub","journeyPage","routePicker","routeQuery","routePreview","routeStep","campaignBand",
    "campaignSelection","campaignSelectionIdentity","journeyNotes","journeyGoalKey","preparationOpen",
    "tripPlanningSection","tripPriorityDungeon","tripPrepSelection","tripPrepSelectionIdentity",
    "helpOpen","advancedSettings","settingsPage","scaleWindow","bagSettingsPage","talentPage","farmingSelection",
    "farmingQuery","farmingFilter","farmingDungeon","timingSelection","timingAction","timingActionIdentity",
    "questHistorySelection","questHistorySelectionIdentity","wetlandsReviewChoice","wetlandsReviewChoiceIdentity",
    "bookQuery","zoneOnly","hideDone","bookZone","bookSelection","bookRewards","bookEvidence","recordDiscovery",
    "showWeights","gearRequirementRecord","requirementQuest","requirementQuestIdentity","requirementRecipe","requirementRecipeIdentity",
    "requirementGuideQuest","requirementGuideQuestIdentity","requirementMaterial","requirementMaterialIdentity"}
local dungeonFields={"dungeon","boss","quest","tab","mapID","mapChosen","artChecked","zoom","panX","panY","item","requestedItem","query","searchResult","reveal"}
local equipmentFields={"slot","selected","wanted","scope","query","sourceChoice","sourceFocus","waitingSlot","inspection","browse"}
local organizerFields={"page","index","character","query","group","ruleGroup","preview","previewGroup","previewPage"}
local function fields(object,keys)
    local result={}
    for _,key in ipairs(keys) do result[key]=object[key] end
    return result
end
local function restore(object,keys,values)
    for _,key in ipairs(keys) do object[key]=values[key] end
end
local function pushHistory()
    if not U.main or not U.main:IsShown() then return false end
    local scrolls={}
    for role,pane in pairs(M.visiblePanes or {}) do scrolls[role]=pane.scroll:GetVerticalScroll() end
    M.history[#M.history+1]={journal=fields(M,journalFields),dungeon=fields(ns.DungeonView,dungeonFields),
        equipment=fields(ns.EquipmentView,equipmentFields),organizer=fields(ns.InventoryOrganizer,organizerFields),
        sections=ns.Copy(M.settingsSections),scroll=M.scroll:GetVerticalScroll(),panes=scrolls}
    if #M.history>20 then table.remove(M.history,1) end
    return true
end
function M.OpenPage(page,prepare)
    if not U.main then return false end
    local current=M.tab=="Character" and M.sub or M.tab=="Adventure" and "Dungeons" or M.tab
    if page~=current or prepare or page=="Settings" and (M.helpOpen or M.bagSettingsPage)
        or page=="Equipment" and (M.gearRequirementRecord or M.showWeights) then pushHistory() end
    if page=="Settings" then M.bagSettingsPage=nil;M.helpOpen=false end
    if page=="Equipment" then M.gearRequirementRecord=nil;M.showWeights=false end
    if prepare then prepare() end
    return openPage(page)
end
function M.OpenBookMap()
    local fromJournal=U.main and U.main:IsShown()
    if not ns.World.OpenBooks(fromJournal) then return false end
    if fromJournal then pushHistory();U.main:Hide() end
    return true
end
function M.OpenSettings(section,subsection)
    return M.OpenPage("Settings",function()
        M.advancedSettings=true;M.settingsPage=section
        if subsection then
            M.settingsSections=M.settingsSections or {};M.settingsSections[section]=subsection
        end
    end)
end
function M.GoBack()
    local context=table.remove(M.history);if not context then return end
    U.CloseSubpage()
    local books=ns.BooksUI
    if books and books.returnToJournal then
        books.returnToJournal=nil;books.openedMap=nil
        if books.frame then books.frame:Hide() end
    end
    restore(M,journalFields,context.journal)
    restore(ns.DungeonView,dungeonFields,context.dungeon)
    ns.DungeonView.context=context.dungeon.dungeon
    restore(ns.EquipmentView,equipmentFields,context.equipment)
    restore(ns.InventoryOrganizer,organizerFields,context.organizer)
    M.settingsSections=context.sections;M.lastPageKey=nil
    if U.main:IsShown() then M.Render() else U.main:Show() end
    local range=math.max(0,M.body:GetHeight()-M.scroll:GetHeight())
    M.scroll:SetVerticalScroll(math.min(context.scroll,range))
    for role,scroll in pairs(context.panes) do
        local pane=(M.visiblePanes or {})[role]
        if pane then pane.scroll:SetVerticalScroll(math.min(scroll,math.max(0,pane.content:GetHeight()-pane.scroll:GetHeight()))) end
    end
end
local render=M.Render
function M.Render()
    render()
    if M.backButton then M.backButton:SetEnabled(#M.history>0) end
end
local create=M.Create
function M.Create()
    create()
    M.backButton=U.Button(U.main,"Back",80,M.GoBack);M.backButton:SetPoint("TOPRIGHT",-200,-12);M.backButton:SetEnabled(false)
    U.main:HookScript("OnHide",function() if ns.QuestWorkspace.menu then ns.QuestWorkspace.menu:Hide() end end)
end
local settings=M.Settings
function M.Settings()
    if M.bagSettingsPage then
        M.Action("Settings",function() M.OpenPage("Settings") end,180)
        local pane=ns.Connected.Pane(M.body,M.width-16,math.max(400,M.scroll:GetHeight()+M.y-20),8,M.y,"bagSettings")
        local O=ns.InventoryOrganizer;O.frame=U.main;O.body=pane.content;O.page=M.bagSettingsPage
        O.Refresh();pane.content:SetHeight(520);M.y=M.y-pane:GetHeight()-8;return
    end
    settings()
    if M.helpOpen or M.advancedSettings then return end
    M.Heading("Character and bag tools")
    M.Action("Talent plans",function() M.OpenPage("Talents") end,240)
    M.Action("Gear hunts",function() M.OpenPage("Farming") end,240)
    M.Action("Bag categories and search",function() ns.InventoryOrganizer.Show("Groups") end,240)
end
function ns.InventoryOrganizer.Show(page)
    if page=="Storage" or page=="History" then ns.Inventory.Toggle();ns.Message("Recorded ownership is available in your bags and item tooltips.");return end
    M.OpenPage("Settings",function() M.bagSettingsPage=page or "Groups" end)
end
local talents=M.Talents
function M.Talents()
    M.Line("Native Forever talents. Saved plans are previews; the native talent window is authoritative for purchase requirements.","GameFontHighlightSmall")
    if not ns.Talents.nativeDefinitions then M.Line("Waiting for the current native talent tree. Historical tree snapshots are not used.");return end
    talents()
end
local simulation=M.Simulation
function M.Simulation()
    local coverage=ns.Data.effectCoverage
    if not coverage or tostring(coverage.build)~=tostring(ns.Safe(select(2,GetBuildInfo()))) then
        M.Line("No effect model snapshot is approved for this Forever build. Use native equipped comparison; historical simulation inputs remain preserved in source.");return
    end
    simulation()
end
ns.Listen("SETTINGS_CHANGED",function() ns.ItemComparison.cache=nil end)

local organizerRefresh=ns.InventoryOrganizer.Refresh
function ns.InventoryOrganizer.Refresh()
    if M.tab=="Settings" and M.bagSettingsPage and U.main and U.main:IsShown() then return organizerRefresh() end
end
