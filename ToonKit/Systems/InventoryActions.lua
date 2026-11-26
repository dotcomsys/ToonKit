local addonName, ns = ...
local A={serial=0,session=0,merchantOpen=false};ns.InventoryActions=A
local function integer(value) return type(value)=="number" and value==value and value>=0 and value<math.huge and value==math.floor(value) end
local function hidden(value) return type(issecretvalue)=="function" and issecretvalue(value) end
local function read(name,...)
    local f=_G[name];if type(f)~="function" then return end
    return ns.Safe(f(...))
end
local function normal(bag) for _,id in ipairs(ns.API.Bags()) do if id==bag then return true end end;return false end
function A.Context(plan)
    if not ns.char or not ns.db then return false,"Character data is not ready." end
    if type(InCombatLockdown)~="function" or InCombatLockdown() then return false,"Finish combat first." end
    if not C_Container or type(C_Container.UseContainerItem)~="function" then return false,"Native item transfers are unavailable." end
    if type(GetCursorInfo)~="function" then return false,"Cursor state is unavailable." end
    local cursor=GetCursorInfo();if hidden(cursor) or cursor~=nil then return false,"Clear the item or spell from your cursor first." end
    if plan.session~=A.session then return false,"The interaction changed. Review the items again." end
    if plan.action=="sell" then
        if not A.merchantOpen or not MerchantFrame or not MerchantFrame:IsShown() or ns.Storage.bankOpen then return false,"Visit a merchant and review these items there." end
        local guid=read("UnitGUID","npc")
        if plan.merchant and guid~=plan.merchant then return false,"The merchant changed. Review again." end
    elseif plan.action=="deposit" or plan.action=="withdraw" then
        if A.merchantOpen then return false,"Close the merchant before moving bank items." end
        local ok,reason=ns.StorageActions.BankContext(plan.bankType);if not ok then return false,reason end
        if not BankFrame or type(BankFrame.GetActiveBankType)~="function" or ns.Safe(BankFrame:GetActiveBankType())~=plan.bankType then return false,"The selected bank type changed. Review again." end
    else return false,"Unsupported item action." end
    return true
end
function A.BankBags(kind)
    if ns.Safe(ns.API.Call("C_Bank","CanViewBank",kind))~=true then return nil,"Bank contents are not readable." end
    local tabs=ns.API.Call("C_Bank","FetchPurchasedBankTabIDs",kind)
    if type(tabs)~="table" then return nil,"Bank tabs are unavailable." end
    local result={}
    for _,raw in ipairs(tabs) do local tab=ns.Safe(raw);if not integer(tab) or normal(tab) then return nil,"Invalid native bank tab." end;result[#result+1]=tab end
    return result
end
function A.Row(bag,slot)
    local slots=ns.Safe(ns.API.Call("C_Container","GetContainerNumSlots",bag))
    if not integer(slots) or not integer(slot) or slot<1 or slot>slots then return nil,"Container is unavailable." end
    local raw=ns.Safe(ns.API.Call("C_Container","GetContainerItemInfo",bag,slot))
    if raw==nil then
        if not C_Container.GetContainerItemID then return nil,"Item state is unavailable." end
        local id=C_Container.GetContainerItemID(bag,slot)
        if hidden(id) or id~=nil then return nil,"Item information is not readable yet." end
        return {bag=bag,slot=slot,empty=true}
    end
    if type(raw)~="table" then return nil,"Item information is unavailable." end
    local id,count,link,locked=ns.Safe(raw.itemID),ns.Safe(raw.stackCount),ns.Safe(raw.hyperlink),ns.Safe(raw.isLocked)
    if not integer(id) or id<1 or not integer(count) or count<1 or type(link)~="string" or type(locked)~="boolean" then return nil,"Item identity, quantity or lock state is unknown." end
    local info=ns.API.Item(link);if not info then return nil,"Loading item data." end
    local quest=ns.Safe(ns.API.Call("C_Container","GetContainerItemQuestInfo",bag,slot))
    local row={bag=bag,slot=slot,id=id,count=count,link=link,locked=locked,info=info,quality=ns.Safe(raw.quality),quest=quest,
        bound=ns.Safe(raw.isBound),boundKnown=type(ns.Safe(raw.isBound))=="boolean"}
    if ItemLocation and type(ItemLocation.CreateFromBagAndSlot)=="function" then
        row.location=ItemLocation:CreateFromBagAndSlot(bag,slot)
        if C_Item and type(C_Item.GetItemGUID)=="function" then
            local guid=ns.Safe(C_Item.GetItemGUID(row.location));if type(guid)~="string" then return nil,"Item identity is still loading." end;row.guid=guid
        end
    end
    row.itemLevel=ns.API.BagItemLevel(bag,slot,link,info,row.location)
    return row
end
function A.KeepReason(row)
    local id=row.id;local quest=row.quest
    if type(quest)~="table" or ns.Safe(quest.isQuestItem)~=false or ns.Safe(quest.questID)~=nil then return "Quest-item status is unknown or protected." end
    if row.info.classID==12 then return "Quest item." end
    if (ns.char.itemGroups or {})[id] or (ns.char.questKeep or {})[id] then return "Manually kept or categorized." end
    if (ns.char.farming or {})[id] then return "Tracked acquisition." end
    if ns.InventoryRules.itemSets and ns.InventoryRules.itemSets[id] then return "Equipment set item." end
    for _,target in ipairs(ns.Gear.SelectedTargets(ns.Rules.Cap())) do if target.id==id then return "Selected equipment target." end end
    for _,equipped in pairs(ns.State.equipment or {}) do if equipped.id==id then return "An equipped item of this type is protected." end end
    if not ns.QuestSupplies then return "Quest-supply protection is unavailable." end
    if #ns.QuestSupplies.Lines(id)>0 then return "Known quest supply." end
end
function A.Allowed(plan,row)
    if row.empty then return false,"The slot is empty." end
    if row.locked then return false,"The item is locked." end
    if plan.action=="withdraw" then
        local tabs,reason=A.BankBags(plan.bankType);if not tabs then return false,reason end
        local found=false;for _,tab in ipairs(tabs) do if tab==row.bag then found=true end end
        if not found then return false,"This slot is outside the selected bank." end
    elseif not normal(row.bag) then return false,"This is not a normal player bag." end
    if plan.action=="sell" then
        local keep=A.KeepReason(row);if keep then return false,keep end
        local index=ns.Data.reagentRecipeIndex
        if row.info.reagent or row.info.classID==7 or index and index.items[row.id] then
            return false,"Crafting material; review and sell it individually if you choose."
        end
        if not row.location or ns.Safe(ns.API.Call("C_Item","CanBeRefunded",row.location))~=false then return false,"Refund status is unknown or protected; review this item natively." end
        if row.info.sellPriceKnown~=true or not integer(row.info.sellPrice) or row.info.sellPrice<=0 then return false,"No confirmed vendor value." end
        if ns.Data.equipSlots[row.info.equip] then return false,"Compare and sell equipment manually using the native merchant." end
        if row.info.quality~=0 then return false,"Future use is unconfirmed. Review this non-junk item individually at the merchant." end
    elseif plan.action=="deposit" then
        if not row.location then return false,"Native item location is unavailable." end
        if ns.Safe(ns.API.Call("C_Bank","IsItemAllowedInBankType",plan.bankType,row.location))~=true then return false,"This bank has not confirmed item eligibility." end
        local account=Enum and Enum.BankType and Enum.BankType.Account
        if account~=nil and plan.bankType==account and ns.Safe(ns.API.Call("C_Item","CanBeRefunded",row.location))~=false then return false,"Use the native account-bank control to review refund protection." end
    end
    return true
end
local function same(a,b)
    return a and b and not a.empty and not b.empty and a.bag==b.bag and a.slot==b.slot and a.id==b.id and a.link==b.link and a.count==b.count and (not a.guid or a.guid==b.guid)
end
function A.Total(id,bags)
    local total=0
    for _,bag in ipairs(bags) do
        local count=ns.Safe(ns.API.Call("C_Container","GetContainerNumSlots",bag))
        if not integer(count) or count>200 then return end
        for slot=1,count do
            local raw=ns.Safe(ns.API.Call("C_Container","GetContainerItemInfo",bag,slot))
            if raw~=nil then
                if type(raw)~="table" then return end
                local itemID,quantity=ns.Safe(raw.itemID),ns.Safe(raw.stackCount)
                if not integer(itemID) or not integer(quantity) then return end
                if itemID==id then total=total+quantity end
            elseif C_Container.GetContainerItemID then
                local itemID=C_Container.GetContainerItemID(bag,slot);if hidden(itemID) or itemID~=nil then return end
            else return end
        end
    end
    return total
end
function A.Preview(action,options)
    if A.running then return nil,"Finish or cancel the current item action first." end
    options=options or {};if options.recorded then return nil,"Recorded inventories cannot move or sell items." end
    local query=options.query or "";if type(query)~="string" or #query>512 then return nil,"Use a search of at most 512 characters." end
    ns.InventoryRules.Search({recorded=true},query,"");if ns.InventoryRules.searchError then return nil,ns.InventoryRules.searchError end
    local plan={action=action,bankType=options.bankType,session=A.session,merchant=action=="sell" and read("UnitGUID","npc") or nil,
        query=query,bag=options.bag,group=options.group,items={},skipped={},excluded={},total=0,units=0,status="review",completed=0}
    local ok,reason=A.Context(plan);if not ok then return nil,reason end
    local bags=ns.API.Bags()
    if action=="withdraw" then bags,reason=A.BankBags(plan.bankType);if not bags then return nil,reason end end
    for _,bag in ipairs(bags) do if not options.bag or options.bag==bag then
        local count=ns.Safe(ns.API.Call("C_Container","GetContainerNumSlots",bag))
        if not integer(count) or count>200 then return nil,"Container capacity is unreadable." end
        for slot=1,count do
            local row,why=A.Row(bag,slot)
            if row and not row.empty then
                local category=action=="withdraw" and "Bank" or ns.InventoryRules.Category(row)
                if (not options.group or options.group=="All" or options.group==category) and ns.InventoryRules.Search(row,query,category) then
                    local allowed,blocked=A.Allowed(plan,row)
                    if allowed then plan.items[#plan.items+1]=row;plan.total=plan.total+(row.info.sellPriceKnown and row.info.sellPrice or 0)*row.count;plan.units=plan.units+row.count
                    else plan.skipped[#plan.skipped+1]={id=row.id,name=row.info.name,reason=blocked} end
                end
            elseif not row then plan.skipped[#plan.skipped+1]={name="Bag "..bag..", slot "..slot,reason=why} end
        end
    end end
    A.serial=A.serial+1;plan.serial=A.serial;A.review=plan;return plan
end
function A.Cancel(reason)
    local plan=A.running or A.review
    if plan then plan.status=reason and "stopped" or "cancelled";plan.message=reason or "Cancelled." end
    A.running=nil;A.pending=nil;A.serial=A.serial+1;ns.Emit("INVENTORY_ACTION_CHANGED")
end
function A.CheckRow(plan,row)
    local current,reason=A.Row(row.bag,row.slot)
    if not same(current,row) then return false,reason or "A reviewed stack moved or changed. Review again." end
    local ok,why=A.Allowed(plan,current);if not ok then return false,why end
    if plan.action=="sell" and current.info.sellPrice~=row.info.sellPrice then return false,"Vendor value changed. Review again." end
    return true
end
function A.Dispatch()
    local plan=A.running;if not plan or A.pending then return end
    local ok,reason=A.Context(plan);if not ok then A.Cancel(reason);return end
    plan.index=plan.index or 1
    while plan.items[plan.index] and plan.excluded[plan.index] do plan.index=plan.index+1 end
    local row=plan.items[plan.index]
    if not row then plan.status="complete";plan.message="Finished the reviewed item action.";A.running=nil;ns.Emit("INVENTORY_ACTION_CHANGED");return end
    ok,reason=A.CheckRow(plan,row);if not ok then A.Cancel(reason);return end
    local destination
    if plan.action=="deposit" then destination,reason=A.BankBags(plan.bankType)
    elseif plan.action=="withdraw" then destination=ns.API.Bags() end
    local before=destination and A.Total(row.id,destination)
    if destination and before==nil then A.Cancel("Destination contents are unreadable. Review again.");return end
    local money=plan.action=="sell" and read("GetMoney") or nil
    if plan.action=="sell" and not integer(money) then A.Cancel("Wallet is unreadable. Review again.");return end
    A.pending={row=row,before=before,destination=destination,serial=plan.serial,money=money}
    plan.status="running";ns.Emit("INVENTORY_ACTION_CHANGED")
    C_Timer.After(6,function() if A.running==plan and A.pending and A.pending.row==row then A.Cancel("No complete item movement was confirmed. Check space and native messages, then review again.") end end)
    -- Native API dispatch only in a revalidated merchant or bank context.
    -- No native item scripts, secure snippets or protected spell actions are called.
    if plan.action=="deposit" then C_Container.UseContainerItem(row.bag,row.slot,nil,plan.bankType,false)
    else C_Container.UseContainerItem(row.bag,row.slot) end
end
function A.Start(plan)
    if plan~=A.review or plan.serial~=A.serial or plan.status~="review" or A.running then return false,"Review these items again." end
    local ok,reason=A.Context(plan);if not ok then return false,reason end
    local selected=0
    for index,row in ipairs(plan.items) do if not plan.excluded[index] then
        ok,reason=A.CheckRow(plan,row);if not ok then return false,reason end;selected=selected+1
    end end
    if selected==0 then return false,"No reviewed stacks are selected." end
    plan.selected=selected;A.running=plan;A.Dispatch();return true
end
function A.Observe()
    local plan,pending=A.running,A.pending;if not plan or not pending then return end
    local ok,reason=A.Context(plan);if not ok then A.Cancel(reason);return end
    local current=A.Row(pending.row.bag,pending.row.slot);if not current then return end
    if not current.empty and current.id==pending.row.id and current.count==pending.row.count then return end
    if not current.empty and current.id==pending.row.id then A.Cancel("The reviewed stack changed only partially. Review the remaining items again.");return end
    if pending.destination then
        local total=A.Total(pending.row.id,pending.destination)
        if total==nil or total<pending.before+pending.row.count then return end
    end
    if pending.money then
        local money=read("GetMoney")
        if not integer(money) or money<pending.money+pending.row.info.sellPrice*pending.row.count then return end
    end
    plan.completed=plan.completed+1;plan.index=plan.index+1;A.pending=nil
    ns.Emit("INVENTORY_ACTION_CHANGED");ns.After("inventoryActionNext",A.Dispatch)
end
for _,event in ipairs({"BAG_UPDATE_DELAYED","ITEM_LOCK_CHANGED","PLAYERBANKSLOTS_CHANGED","MERCHANT_UPDATE","PLAYER_MONEY"}) do ns.On(event,function() if A.running then ns.After("inventoryActionObserve",A.Observe) end end) end
ns.On("MERCHANT_SHOW",function() A.session=A.session+1;A.merchantOpen=true;if A.running then A.Cancel("The merchant interaction changed.") end end)
ns.On("MERCHANT_CLOSED",function() A.session=A.session+1;A.merchantOpen=false;if A.running then A.Cancel("Merchant closed.") end end)
for _,event in ipairs({"BANKFRAME_OPENED","BANKFRAME_CLOSED","PLAYER_REGEN_DISABLED","PLAYER_ENTERING_WORLD"}) do ns.On(event,function() A.session=A.session+1;if A.running then A.Cancel("The interaction changed or combat began.") end end) end
