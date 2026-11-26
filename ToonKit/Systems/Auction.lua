local addonName, ns = ...
local A={open=false,rows={},unsettled={},conflicted={}};ns.Auction=A
local function number(v) v=ns.Safe(v);return type(v)=="number" and v==v and v>=0 and v<math.huge and v or nil end
local function settle(search,complete,status)
    if A.search~=search then return end
    A.search=nil;A.running=false;A.status=status
    if search.observed then ns.Market.Record(search.key,A.rows,complete) end
    ns.Emit("MARKET_CHANGED")
end
local function observeNativeSearch()
    if A.observing or type(hooksecurefunc)~="function" or not C_AuctionHouse
        or type(C_AuctionHouse.SendSearchQuery)~="function" then return end
    A.observing=pcall(hooksecurefunc,C_AuctionHouse,"SendSearchQuery",function(key)
        local search=A.search
        key=ns.Safe(key)
        if not search or A.submitting==search or type(key)~="table" or ns.Safe(key.itemID)~=search.id then return end
        A.conflicted[search.id]=true
        A.search=nil;A.running=false;A.rows={}
        A.status="Another auction search used this item. Reopen the auction house before observing it again."
        ns.Emit("MARKET_CHANGED")
    end)
end
function A.Search(query)
    if not A.open then A.status="Visit an auctioneer to search.";return end
    if A.search then return end
    local id=tonumber(query) or type(query)=="string" and tonumber(query:match("item:(%d+)"))
    if not id then local info=ns.API.Item(query);id=info and info.link and tonumber(info.link:match("item:(%d+)")) end
    if not id or id<1 or id~=math.floor(id) then A.status="Drag a bag item here or paste its item link.";return end
    if not C_AuctionHouse or not C_AuctionHouse.SendSearchQuery or not C_AuctionHouse.MakeItemKey then A.status="Forever auction search unavailable.";return end
    if ns.Safe(ns.API.Call("C_AuctionHouse","IsThrottledMessageSystemReady"))~=true then A.status="Auction search is throttled. Try again shortly.";return end
    local sort=Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price
    if not sort then A.status="Native auction sort context unavailable.";return end
    local key
    if ItemLocation and ItemLocation.CreateFromBagAndSlot then
        for _,item in ipairs(ns.State.bags or {}) do
            if item.id==id and (type(query)~="string" or not query:find("item:",1,true) or item.link==query) then
                key=ns.Safe(ns.API.Call("C_AuctionHouse","GetItemKeyFromItem",ItemLocation:CreateFromBagAndSlot(item.bag,item.slot)))
                if key then break end
            end
        end
    end
    local variantKnown=key~=nil
    key=ns.Safe(key or ns.API.Call("C_AuctionHouse","MakeItemKey",id,0,0,0))
    local identity=ns.Market.Key(key)
    if not identity or ns.Safe(key.itemID)~=id then A.status="Native item key unavailable.";return end
    if A.conflicted[id] then A.status="Reopen the auction house before observing this item again.";return end
    if A.unsettled[id] then
        A.status="The previous search for this item is still outstanding. Wait for its response or reopen the auction house.";return
    end
    local search={key=key,id=id,identity=identity,variantKnown=variantKnown}
    A.search=search;A.rows={};A.running=true;A.status=variantKnown and "Searching this bag item's variant…" or "Searching base item variant…"
    observeNativeSearch()
    A.submitting=search
    local ok,err=pcall(C_AuctionHouse.SendSearchQuery,key,{{sortOrder=sort,reverseSort=false}},false)
    A.submitting=nil
    if not ok then
        ns.errors.auctionSearch=tostring(err)
        settle(search,false,"The client could not submit the search. Try again.")
        return
    end
    ns.errors.auctionSearch=nil
    C_Timer.After(12,function()
        if A.search~=search then return end
        A.unsettled[id]=search.identity
        settle(search,false,search.observed and "Timed out · partial observation" or "No response from the auction house.")
    end)
    if A.search==search then ns.Emit("MARKET_CHANGED") end
end
function A.Cancel()
    local search=A.search
    if not search then return end
    A.unsettled[search.id]=search.identity
    A.search=nil;A.running=false;A.rows={};A.status="Observation cancelled.";ns.Emit("MARKET_CHANGED")
end
function A.Results(kind,id)
    if not A.open then return end
    local commodity=kind=="commodity"
    id=ns.Safe(id)
    local itemID=commodity and id or type(id)=="table" and ns.Safe(id.itemID)
    if type(itemID)~="number" then return end
    local identity=not commodity and ns.Market.Key(id)
    local unsettled=A.unsettled[itemID]
    if unsettled and (commodity or identity==unsettled) then
        local full=ns.Safe(ns.API.Call("C_AuctionHouse",commodity and "HasFullCommoditySearchResults" or "HasFullItemSearchResults",id))
        if full==true then A.unsettled[itemID]=nil end
        return
    end
    local search=A.search
    if not search or itemID~=search.id or not commodity and identity~=search.identity then return end
    local query=commodity and itemID or search.key
    local rows={}
    local count=number(ns.API.Call("C_AuctionHouse",commodity and "GetNumCommoditySearchResults" or "GetNumItemSearchResults",query))
    if not count then return end
    for index=1,math.min(count,500) do
        local row=ns.Safe(ns.API.Call("C_AuctionHouse",commodity and "GetCommoditySearchResultInfo" or "GetItemSearchResultInfo",query,index))
        if type(row)=="table" then
            local quantity=number(row.quantity)
            local total=number(row.buyoutAmount);local unit=commodity and number(row.unitPrice) or quantity and quantity>0 and total and total/quantity
            if quantity and quantity>0 and unit and unit>0 then rows[#rows+1]={quantity=quantity,unitPrice=unit,total=commodity and unit*quantity or total} end
        end
    end
    local full=ns.Safe(ns.API.Call("C_AuctionHouse",commodity and "HasFullCommoditySearchResults" or "HasFullItemSearchResults",query))==true
    table.sort(rows,function(a,b) return a.unitPrice<b.unitPrice end)
    A.rows=rows;search.observed=true
    local variant=search.variantKnown and " · bag item variant" or " · base variant"
    if full or count>=500 then
        local complete=full and count<=500
        if not full then A.unsettled[itemID]=search.identity end
        settle(search,complete,(complete and "Observed asking prices" or "Partial observation · 500-listing limit")..variant)
    else
        A.status="Waiting for more listings · partial results"..variant
        ns.Emit("MARKET_CHANGED")
    end
end
ns.On("AUCTION_HOUSE_SHOW",function()
    A.open=true;A.unsettled={};A.conflicted={};A.rows={};A.status="Search for current asking prices.";ns.Emit("MARKET_CHANGED")
end)
ns.On("AUCTION_HOUSE_CLOSED",function()
    A.open=false;A.Cancel();if ns.AuctionUI and ns.AuctionUI.frame then ns.AuctionUI.frame:Hide() end
end)
ns.On("COMMODITY_SEARCH_RESULTS_UPDATED",function(id) A.Results("commodity",id) end)
ns.On("COMMODITY_SEARCH_RESULTS_ADDED",function(id) A.Results("commodity",id) end)
ns.On("ITEM_SEARCH_RESULTS_UPDATED",function(key,newAuctionID)
    if ns.Safe(newAuctionID)==nil then A.Results("item",key) end
end)
ns.On("ITEM_SEARCH_RESULTS_ADDED",function(key) A.Results("item",key) end)
