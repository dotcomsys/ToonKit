local addonName, ns = ...
local B={selections={}};ns.BooksUI=B
local function destination(record)
    if record and record.map and record.x and record.y then return {map=record.map,x=record.x,y=record.y} end
end
local function pickup()
    local r=B.selected;if not r then return end
    if r.reward then ns.ItemCompare.Show({id=r.item,name=r.name});return end
    if destination(r) then ns.Connected.Map(r) else ns.Message(r.detail or "Precise pickup location is unconfirmed.") end
end
function B.ShowDonation(r)
    if not r or r.reward then return end
    if r.donationFaction and r.donationFaction~=ns.State.faction then ns.Message("Donation eligibility has conflicting source evidence; check the native librarian.");return end
    local alliance=ns.State.faction=="Alliance"
    local map=ns.World.MapForZone(alliance and "Stormwind City" or "Undercity")
    if not map then ns.Message(r.lateHandIn and "Visit Jennea Cannon in Stormwind or Oran Snakewrithe in Undercity." or "Visit your capital's librarian.");return end
    local x,y
    if r.lateHandIn then x=alliance and .495 or .733;y=alliance and .858 or .324
    else x=alliance and .49 or .736;y=alliance and .864 or .33 end
    ns.Connected.Map({map=map,x=x,y=y})
end
local function close()
    local returnToJournal,openMap=B.returnToJournal,B.openedMap
    B.returnToJournal=nil;B.openedMap=nil
    B.frame:Hide()
    if returnToJournal then
        if openMap and WorldMapFrame:IsShown() and type(HideUIPanel)=="function" then HideUIPanel(WorldMapFrame) end
        ns.Main.GoBack()
    end
end
function B.Refresh()
    if not B.frame or not B.frame:IsShown() then return end
    local rows,lookup={},{};local found,donated,total=0,0,0
    local mode=B.rewards and "rewards" or "books"
    if B.rewards then
        for _,g in ipairs(ns.Data.libraryGoals or {}) do for _,r in ipairs(g.rewards or {}) do
            local info=ns.API.Item(r.item)
            local key="reward:"..g.books..":"..r.item
            lookup[key]={reward=true,item=r.item,name=info and info.name or r.name or ("Item #"..r.item),milestone=g.books}
            rows[#rows+1]={value=key,label=g.books.." donations · "..lookup[key].name}
        end end
        B.title:SetText("Library milestone rewards")
    else
        for _,r in ipairs(ns.World.Records()) do if r.item and type(r.id)=="string" and r.id:match("^library:") then
            local status=ns.World.Status(r);local confirmed=status=="donated" or status=="collected"
            total=total+1;if confirmed then found=found+1 end;if status=="donated" then donated=donated+1 end
            if not ns.db.settings.bookMissingOnly or not confirmed then
                lookup[r.id]=r
                rows[#rows+1]={value=r.id,label=r.name.." · "..(r.zone or "Unknown pickup")..(confirmed and " · "..status or "")}
            end
        end end
        B.title:SetText("Books: "..found.." / "..total.." source catalog")
    end
    B.filter:SetShown(not B.rewards)
    B.filter:SetText(ns.db.settings.bookMissingOnly and "Show all books" or "Show missing only")
    B.mode:SetText(B.rewards and "Show books" or "Milestone rewards")
    B.count:SetText(B.rewards and "Source-listed milestone rewards" or donated.." donated")
    B.selected=lookup[B.selections[mode]]
    ns.UI.Release(B.pane.content)
    ns.Connected.List(B.pane,rows,B.selections[mode],function(key) B.selections[mode]=key;B.Refresh() end)
    local selected=B.selected
    local detail=selected and selected.name or (B.rewards and "Select a reward." or "Select a book.")
    if selected and selected.milestone then detail=detail.." · "..selected.milestone.." donations"
    elseif selected then detail=detail.."\n"..(selected.zone or "Pickup area unavailable") end
    B.detail:SetText(detail)
    B.pickup:SetText(B.rewards and "Compare" or "Pickup map")
    B.pickup:SetEnabled(selected~=nil and (B.rewards or destination(selected)~=nil))
    B.turnin:SetEnabled(B.selected~=nil and not B.rewards)
    B.navigate:SetEnabled(B.selected~=nil and not B.rewards and destination(B.selected)~=nil)
end
function ns.World.OpenBooks(returnToJournal)
    if not ns.db.settings.modules.world then ns.Message("Books and discoveries are disabled in Settings.");return false end
    local openedMap=not WorldMapFrame or not WorldMapFrame:IsShown()
    if openedMap then
        if C_Map and type(C_Map.OpenWorldMap)=="function" then ns.API.Call("C_Map","OpenWorldMap")
        elseif type(OpenWorldMap)=="function" then OpenWorldMap() end
    end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then ns.Message("The native map is unavailable.");return false end
    B.returnToJournal=returnToJournal==true;B.openedMap=openedMap
    if not B.frame then
        local f=CreateFrame("Frame",nil,WorldMapFrame,"BackdropTemplate");B.frame=f;f:SetSize(350,520);f:SetPoint("TOPRIGHT",WorldMapFrame,"TOPRIGHT",-6,-40);f:SetFrameLevel(WorldMapFrame:GetFrameLevel()+15)
        f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=32,edgeSize=12,insets={left=4,right=4,top=4,bottom=4}})
        B.title=ns.UI.Label(f,"Books",12,-12,265,"GameFontNormal")
        local dismiss=ns.UI.Button(f,"×",30,close);dismiss:SetPoint("TOPRIGHT",-8,-8)
        B.filter=ns.UI.Button(f,"Show missing only",150,function() ns.SetSetting("bookMissingOnly",not ns.db.settings.bookMissingOnly);B.Refresh() end);B.filter:SetPoint("TOPLEFT",12,-40)
        B.back=ns.UI.Button(f,"Back to journal",155,close);B.back:SetPoint("TOPLEFT",180,-40)
        B.count=ns.UI.Label(f,"",12,-75,324,"GameFontHighlightSmall")
        B.pane=ns.Connected.Pane(f,330,278,10,-104,"bookList")
        B.detail=ns.UI.Label(f,"Select a book.",12,-390,320,"GameFontHighlightSmall")
        B.pickup=ns.UI.Button(f,"Pickup map",155,pickup);B.pickup:SetPoint("TOPLEFT",12,-438)
        B.turnin=ns.UI.Button(f,"Turn-in map",155,function() B.ShowDonation(B.selected) end);B.turnin:SetPoint("TOPLEFT",180,-438)
        B.navigate=ns.UI.Button(f,"Set destination",155,function()
            local point=destination(B.selected)
            if point then ns.char.questFocus=nil;ns.char.customWaypoint=point;ns.Navigation.Refresh();ns.Emit("STATE_CHANGED") end
        end);B.navigate:SetPoint("TOPLEFT",12,-478)
        B.mode=ns.UI.Button(f,"Milestone rewards",155,function()
            B.rewards=not B.rewards;B.pane.scroll:SetVerticalScroll(0);B.Refresh()
        end);B.mode:SetPoint("TOPLEFT",180,-478)
        WorldMapFrame:HookScript("OnHide",function() if f:IsShown() then close() end end)
    end
    B.back:SetShown(B.returnToJournal)
    B.frame:Show();B.Refresh();return true
end
ns.Listen("STATE_CHANGED",function() if B.frame and B.frame:IsShown() then ns.After("bookListRefresh",B.Refresh) end end)
ns.Listen("ITEM_DATA_READY",function() if B.frame and B.frame:IsShown() and B.rewards then ns.After("bookRewardItems",B.Refresh) end end)
