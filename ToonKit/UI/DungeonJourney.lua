local addonName, ns = ...
local U,M,P=ns.UI,ns.Main,ns.DungeonJourney
function P.Prompt()
    if ns.Journey.Speedrunning() then return end
    if not ns.char or (ns.char.dungeonJourney or {}).asked then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if not P.prompt then
        local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate");P.prompt=f
        f:SetWidth(540);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:EnableMouse(true);f:SetClampedToScreen(true);U.Skin(f)
        local title=U.Label(f,"Your leveling Journey",24,-24,492,"GameFontNormalLarge")
        local y=-34-title:GetStringHeight()
        local body=U.Label(f,"Include dungeon quests while leveling?\n\nJourney can prepare eligible quests, guide their objectives and returns, then resume your leveling route. Hall of Thanes is planned at 15; Deadmines at 20; SFK at 23; BFD at 25. Quest prerequisites and your actual class still apply. You can change this choice or add individual quests in dungeon details.",24,y,492,"GameFontHighlight")
        y=y-body:GetStringHeight()-22
        local yes=U.Button(f,"Include dungeon quests",238,function() f:Hide();P.Configure(true) end);yes:SetPoint("TOPLEFT",24,y)
        local no=U.Button(f,"Level without dungeon quests",238,function() f:Hide();P.Configure(false) end);no:SetPoint("TOPLEFT",278,y)
        f:SetHeight(-y+math.max(yes:GetHeight(),no:GetHeight())+24)
    end
    P.prompt:Show()
end
ns.On("PLAYER_REGEN_ENABLED",P.Prompt)
local planning=M.RoutePlanning
function M.RoutePlanning()
    local enabled=(ns.char.dungeonJourney or {}).enabled==true
    M.Heading("Dungeon quests in your Journey")
    local choices=U.Options(M.body,{{value=true,label="Include eligible dungeon quests"},{value=false,label="Only individually added quests"}},enabled,M.width-16,function(v) P.Configure(v) end,2)
    choices:SetPoint("TOPLEFT",8,M.y);M.y=M.y-choices:GetHeight()-8
    planning()
end
