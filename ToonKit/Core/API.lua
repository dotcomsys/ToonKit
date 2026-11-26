local addonName, ns = ...
local A = {}; ns.API = A
A.requested,A.queued,A.failed,A.itemQueue,A.loading={},{},{},{},0
A.catalogQueue={};A.itemHead=1;A.catalogHead=1;A.itemCache={};A.itemVersions={}
A.errors={}
function A.Client()
    local version,build,_,interface=GetBuildInfo()
    return {version=ns.Safe(version),build=ns.Safe(build),interface=ns.Safe(interface),supported=ns.Safe(interface)==16001}
end
function A.CatalogVisible()
    local ui,m=ns.UI,ns.Main
    if not (ui and ui.main and ui.main:IsShown() and m) then return false end
    local dungeon=ns.DungeonView
    if m.tab=="Adventure" and m.sub=="Dungeons" then
        return dungeon and dungeon.dungeon and (dungeon.tab=="loot" or dungeon.tab=="quests")
    end
    if m.tab=="Character" and m.sub=="Equipment" then
        local equipment=ns.EquipmentView
        local job=equipment and equipment.job
        return m.gearRequirementRecord~=nil or equipment and equipment.scope and equipment.scope~="available"
            or job and (job.running or next(job.pending)~=nil)
    end
    return false
end
local function pop(catalog)
    local queue=catalog and A.catalogQueue or A.itemQueue
    local field=catalog and "catalogHead" or "itemHead";local expected=catalog and "catalog" or "urgent"
    while A[field]<=#queue do
        local id=queue[A[field]];A[field]=A[field]+1
        if A.queued[id]==expected then A.queued[id]=nil;return id end
    end
    if catalog then A.catalogQueue={} else A.itemQueue={} end;A[field]=1
end
function A.PumpItems()
    local request=C_Item and C_Item.RequestLoadItemDataByID
    if type(request)~="function" then return end
    local combat=type(InCombatLockdown)=="function" and InCombatLockdown()
    local limit=combat and 2 or 8
    while A.loading<limit do
        local id=pop(false)
        if not id and not combat and A.CatalogVisible() then id=pop(true) end
        if not id then break end
        local pending={};A.requested[id]=pending;A.loading=A.loading+1
        local ok=pcall(request,id)
        if not ok then A.ItemLoaded(id,false)
        elseif A.requested[id]==pending then
            local function timeout()
                if A.requested[id]==pending then A.ItemLoaded(id,false) end
            end
            if C_Timer.NewTimer then pending.timer=C_Timer.NewTimer(10,timeout)
            else C_Timer.After(10,timeout) end
        end
    end
end
function A.ItemLoaded(id,success)
    id=ns.Safe(id);if type(id)~="number" then return end
    local pending=A.requested[id]
    if pending then
        A.requested[id]=nil;A.loading=math.max(0,A.loading-1)
        if pending.timer then pending.timer:Cancel() end
    end
    A.itemVersions[id]=(A.itemVersions[id] or 0)+1
    if ns.Safe(success,false) then A.failed[id]=nil
    else A.failed[id]=true;ns.Emit("ITEM_DATA_UNAVAILABLE",id) end
    ns.After("requestItems",A.PumpItems)
end
-- Capability guards handle API drift. pcall is not a workaround for protected actions.
local questReads={IsOnQuest=true,GetQuestObjectives=true,IsQuestFlaggedCompleted=true,IsComplete=true,IsEliteQuest=true,GetSuggestedGroupSize=true}
function A.Call(namespace, method, ...)
    local memo,key
    if namespace=="C_QuestLog" and questReads[method] then
        local id=ns.Safe(select(1,...))
        if type(id)=="number" then
            local revision=ns.State and ns.State.questRevision or 0
            if A.questMemoRevision~=revision then A.questMemo={};A.questMemoRevision=revision end
            memo=A.questMemo;key=method..":"..id
            if memo[key] then return memo[key].value end
        end
    end
    local object = _G[namespace]
    if type(object) ~= "table" or type(object[method]) ~= "function" then return nil end
    local ok, a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q = pcall(object[method], ...)
    if ok then A.errors[namespace.."."..method]=nil;if memo then memo[key]={value=a} end;return a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q end
    A.errors[namespace.."."..method]=tostring(a)
end
function A.Item(id,catalog)
    if not id then return nil end
    local itemID=tonumber(id) or type(id)=="string" and tonumber(id:match("item:(%d+)"))
    local version=itemID and (A.itemVersions[itemID] or 0) or 0
    local cached=A.itemCache[id];if cached and cached.version==version then return cached.info end
    local name, link, quality, level, required, class, sub, stack, equip, icon, price, classID, subID, bind,expansion,setID,reagent = A.Call("C_Item", "GetItemInfo", id)
    name=ns.Safe(name)
    if not name then
        local key = tonumber(id) or (type(id) == "string" and tonumber(id:match("item:(%d+)")))
        if key and C_Item and type(C_Item.RequestLoadItemDataByID)=="function" and not A.failed[key] and not A.requested[key] then
            if not A.queued[key] or not catalog and A.queued[key]=="catalog" then
                A.queued[key]=catalog and "catalog" or "urgent"
                local queue=catalog and A.catalogQueue or A.itemQueue;queue[#queue+1]=key
            end
            if not catalog or A.CatalogVisible() then ns.After("requestItems",A.PumpItems) end
        end
        return nil
    end
    local info={ name=ns.Safe(name, "Item"), link=ns.Safe(link), quality=ns.Safe(quality), level=ns.Safe(level,0), required=ns.Safe(required,0),
        class=ns.Safe(class), sub=ns.Safe(sub), stack=ns.Safe(stack), equip=ns.Safe(equip), icon=ns.Safe(icon), classID=ns.Safe(classID), subID=ns.Safe(subID), bind=ns.Safe(bind),setID=ns.Safe(setID),reagent=ns.Safe(reagent,false),sellPrice=ns.Safe(price,0),sellPriceKnown=type(ns.Safe(price))=="number" }
    A.itemCache[id]={version=version,info=info};return info
end
function A.QuestDone(id) return ns.Safe(A.Call("C_QuestLog", "IsQuestFlaggedCompleted", id), false) end
-- The global OpenWorldMap helper can open the player's zone without selecting
-- its argument. Forever exposes the map-ID entry point on C_Map instead.
function A.OpenMap(map)
    map=ns.Safe(map)
    if type(map)~="number" or map<=0 then return false end
    if not A.Call("C_Map","GetMapInfo",map) then return false end
    if C_Map and type(C_Map.OpenWorldMap)=="function" then
        C_Map.OpenWorldMap(map)
    elseif type(OpenWorldMap)=="function" then
        if not WorldMapFrame or type(WorldMapFrame.SetMapID)~="function" then return false end
        OpenWorldMap()
    else return false end
    -- Select after opening too: showing the frame can initialize its zone map.
    if WorldMapFrame and type(WorldMapFrame.SetMapID)=="function" then WorldMapFrame:SetMapID(map) end
    return true
end
function A.MapPoint(map, x, y, openMap)
    if not map or not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return end
    if A.Call("C_Map","CanSetUserWaypointOnMap",map)==false then return end
    if UiMapPoint and C_Map and C_Map.SetUserWaypoint then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
        if openMap~=false then A.OpenMap(map) end
        return true
    end
end
function A.ItemEligibility(id,info)
    if not info then return nil,"Waiting for item data" end
    if info.required>math.min(ns.State.level,ns.Rules.Cap()) then return false,"Requires level "..info.required end
    local usable=ns.Safe(A.Call("C_PlayerInfo","CanUseItem",id))
    if usable==false then return false,"Your character cannot use this item" end
    return usable,usable==nil and "Client item eligibility is unavailable" or nil
end
function A.BagItemLevel(bag,slot,link,info,location)
    if not info or not ns.Data.equipSlots[info.equip] then return end
    if not location and ItemLocation and type(ItemLocation.CreateFromBagAndSlot)=="function" then
        location=ItemLocation:CreateFromBagAndSlot(bag,slot)
    end
    local level=location and ns.Safe(A.Call("C_Item","GetCurrentItemLevel",location))
    if type(level)=="number" and level>0 and level<math.huge then return level end
    level=type(link)=="string" and ns.Safe(A.Call("C_Item","GetDetailedItemLevelInfo",link))
    if type(level)=="number" and level>0 and level<math.huge then return level end
end
function A.Position()
    local map = A.Call("C_Map", "GetBestMapForUnit", "player")
    local pos = map and A.Call("C_Map", "GetPlayerMapPosition", map, "player")
    if pos then local x,y=pos:GetXY(); x,y=ns.Safe(x),ns.Safe(y); if x and y then return map,x,y end end
end
function A.Bags()
    local bags = {}; local max = NUM_BAG_SLOTS or 4
    for bag=0,max do bags[#bags+1]=bag end
    -- Reagent bag is included only if the client defines a player reagent bag index.
    local reagent = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if reagent and reagent > max then bags[#bags+1] = reagent end
    return bags
end
function A.Capabilities()
    return {
        talents = C_Traits and C_Traits.GetNodeInfo and C_ClassTalents and C_ClassTalents.GetActiveConfigID and true or false,
        equipment = ItemLocation and ItemLocation.CreateFromEquipmentSlot and C_Item and C_Item.GetItemID and true or false,
        money = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString and true or false,
        bags = C_Container and C_Container.GetContainerItemInfo and true or false,
        quests = C_QuestLog and C_QuestLog.GetInfo and true or false,
        map = C_Map and C_Map.SetUserWaypoint and true or false,
    }
end

function A.Equipped(slot)
    local location
    if ItemLocation and type(ItemLocation.CreateFromEquipmentSlot)=="function" then location=ItemLocation:CreateFromEquipmentSlot(slot) end
    if location and A.Call("C_Item","DoesItemExist",location)==true then
        return ns.Safe(A.Call("C_Item","GetItemID",location)),ns.Safe(A.Call("C_Item","GetItemLink",location)),ns.Safe(A.Call("C_Item","GetItemIcon",location))
    end
    -- Optional compatibility only. Missing legacy globals must never abort bags.
    local id=type(GetInventoryItemID)=="function" and ns.Safe(GetInventoryItemID("player",slot)) or nil
    local link=type(GetInventoryItemLink)=="function" and ns.Safe(GetInventoryItemLink("player",slot)) or nil
    return id,link
end
function A.Money()
    local copper=type(GetMoney)=="function" and ns.Safe(GetMoney(),0) or 0
    local text=ns.Safe(A.Call("C_CurrencyInfo","GetCoinTextureString",copper))
    if text then return text end
    if type(GetCoinTextureString)=="function" then return ns.Safe(GetCoinTextureString(copper),"") end
    return math.floor(copper/10000).."g "..math.floor(copper/100)%100 .."s "..copper%100 .."c"
end

-- Read the player's native Show on Backpack selections; do not alter them.
function A.BackpackCurrencies()
    local rows={}
    for index=1,3 do
        local raw=ns.Safe(A.Call("C_CurrencyInfo","GetBackpackCurrencyInfo",index))
        if type(raw)=="table" then
            local name,quantity,icon=ns.Safe(raw.name),ns.Safe(raw.quantity),ns.Safe(raw.iconFileID)
            if type(name)=="string" and type(quantity)=="number" then
                rows[#rows+1]={name=name,quantity=quantity,icon=type(icon)=="number" and icon or nil,id=ns.Safe(raw.currencyTypesID)}
            end
        end
    end
    return rows
end

ns.On("PLAYER_REGEN_ENABLED",function() ns.After("requestItems",A.PumpItems) end)
