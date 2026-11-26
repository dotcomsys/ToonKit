local addonName, ns = ...
local V={};ns.AuctionUI=V
function V.Refresh()
    if not ns.db or not ns.Auction.open then return end
    local parent=AuctionHouseFrame
    if not parent or not parent:IsShown() then return end
    if not V.frame then
        local f=CreateFrame("Frame",nil,parent,"BackdropTemplate");V.frame=f;f:SetSize(330,265);f:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-12,-60)
        f:SetFrameLevel(parent:GetFrameLevel()+20);f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=32,edgeSize=12,insets={left=4,right=4,top=4,bottom=4}})
        ns.UI.Label(f,"ToonKit • observed prices",12,-12,280,"GameFontNormal")
        f.close=ns.UI.Button(f,"Close",60,function() f:Hide();ns.Auction.Cancel() end);f.close:SetPoint("TOPRIGHT",-8,-6)
        ns.UI.Label(f,"Drag an item here or paste its link",12,-43,300,"GameFontHighlightSmall")
        f.item=ns.UI.Edit(f,110,"");f.item:SetPoint("TOPLEFT",14,-62)
        f.item:SetScript("OnReceiveDrag",function(self)
            local kind,id,link=GetCursorInfo();kind,id,link=ns.Safe(kind),ns.Safe(id),ns.Safe(link)
            if kind=="item" and type(id)=="number" then self:SetText(type(link)=="string" and link or tostring(id));ClearCursor() end
        end)
        f.search=ns.UI.Button(f,"Search",85,function() ns.Auction.Search(f.item:GetText());V.Refresh() end);f.search:SetPoint("TOPLEFT",135,-60)
        f.cancel=ns.UI.Button(f,"Cancel",85,function() ns.Auction.Cancel();V.Refresh() end);f.cancel:SetPoint("TOPLEFT",232,-60)
        f.status=ns.UI.Label(f,"",12,-98,300,"GameFontHighlightSmall")
        f.results=ns.UI.Label(f,"",12,-142,300,"GameFontHighlightSmall")
    end
    local f=V.frame;f.status:SetText(ns.Auction.status or "No market observations.")
    f.search:SetEnabled(not ns.Auction.running);f.cancel:SetEnabled(ns.Auction.running==true)
    local lines={};for i,row in ipairs(ns.Auction.rows) do
        if i>4 then break end
        lines[#lines+1]=ns.Gold.Format(row.unitPrice).." / item × "..row.quantity
    end
    f.results:SetText(#lines>0 and table.concat(lines,"\n").."\nAsking prices, not completed sales." or "No observed buyout offers.\nNative posting and purchases remain unchanged.")
    f:Show()
end
local function install()
    if not AuctionHouseFrame or V.button then return end
    V.button=ns.UI.Button(AuctionHouseFrame,"ToonKit prices",130,function()
        if V.frame and V.frame:IsShown() then V.frame:Hide();ns.Auction.Cancel() else V.Refresh() end
    end)
    V.button:SetPoint("TOPRIGHT",AuctionHouseFrame,"TOPRIGHT",-45,-28)
end
ns.On("AUCTION_HOUSE_SHOW",function() ns.After("auctionEntry",install) end)
ns.On("ADDON_LOADED",function() if ns.db then install() end end)
ns.Listen("MARKET_CHANGED",function() if V.frame and V.frame:IsShown() then V.Refresh() end end)
