local addonName, ns = ...
local S={bankOpen=false,guildOpen=false};ns.Storage=S
local function read(name,...)
    if type(_G[name])~="function" then return end
    local ok,a,b,c,d,e,f=pcall(_G[name],...)
    if ok then return ns.Safe(a),ns.Safe(b),ns.Safe(c),ns.Safe(d),ns.Safe(e),ns.Safe(f) end
end
local function number(value) value=ns.Safe(value);return type(value)=="number" and value>=0 and value==math.floor(value) and value or nil end
local function stamp() return number(read("GetServerTime")) or 0 end
local function new(label) return {label=label,items={},counts={},recorded=stamp()} end
local function add(snapshot,id,link,count,place,name)
    id,count=number(id),number(count);link=ns.Safe(link)
    if not id or id<1 or not count or count<1 then return false end
    local key=id..":"..place
    snapshot.items[key]={id=id,link=type(link)=="string" and link or "item:"..id,count=count,place=place,name=type(ns.Safe(name))=="string" and ns.Safe(name) or type(link)=="string" and link:match("%[([^%]]+)%]")}
    snapshot.counts[id]=(snapshot.counts[id] or 0)+count;return true
end
local function save(key,snapshot)
    ns.char.storage=ns.char.storage or {};ns.char.storage[key]=snapshot
    ns.Emit("STORAGE_CHANGED")
end
function S.CaptureBanks()
    if not ns.char or not S.bankOpen then return end
    local types=ns.API.Call("C_Bank","FetchViewableBankTypes")
    if type(types)~="table" then return end
    for _,kind in ipairs(types) do
        kind=number(kind)
        if kind and ns.Safe(ns.API.Call("C_Bank","CanViewBank",kind))==true then
            local tabs=ns.API.Call("C_Bank","FetchPurchasedBankTabIDs",kind)
            if type(tabs)=="table" then
                local snapshot=new("Character bank");local valid=#tabs>0 or ns.Safe(ns.API.Call("C_Bank","FetchNumPurchasedBankTabs",kind))==0
                local labels={}
                local tabData=ns.API.Call("C_Bank","FetchPurchasedBankTabData",kind)
                for _,data in ipairs(type(tabData)=="table" and tabData or {}) do
                    local id,name=number(data.ID),ns.Safe(data.name)
                    if id and type(name)=="string" then labels[id]=name end
                end
                for _,bag in ipairs(tabs) do
                    bag=number(bag)
                    local slots=bag and number(ns.API.Call("C_Container","GetContainerNumSlots",bag))
                    if not slots or slots==0 or slots>200 then valid=false;break end
                    for slot=1,slots do
                        local info=ns.API.Call("C_Container","GetContainerItemInfo",bag,slot)
                        if type(info)=="table" then
                            if not add(snapshot,info.itemID,info.hyperlink,info.stackCount,(labels[bag] or "Bank tab")..", slot "..slot) then valid=false end
                        elseif ns.Safe(ns.API.Call("C_Container","GetContainerItemID",bag,slot)) then valid=false end
                    end
                end
                if valid then
                    local account=Enum and Enum.BankType and Enum.BankType.Account
                    if account~=nil and kind==account then
                        snapshot.label="Account bank";ns.db.accountStorage=snapshot;ns.Emit("STORAGE_CHANGED")
                    else save("bank:"..kind,snapshot) end
                end
            end
        end
    end
end
function S.CaptureGuild()
    if not ns.char or not S.guildOpen then return end
    local tab=number(read("GetCurrentGuildBankTab"));if not tab or tab<1 or tab>20 then return end
    local label,_,canView=read("GetGuildBankTabInfo",tab)
    local guild=read("GetGuildInfo","player");local realm=read("GetRealmName")
    if type(guild)~="string" or type(realm)~="string" or canView~=true then return end
    if type(GetGuildBankItemInfo)~="function" or type(GetGuildBankItemLink)~="function" then return end
    local key=realm..":"..guild;ns.db.guildStorage=ns.db.guildStorage or {}
    local snapshot=new(guild..": "..(type(label)=="string" and label or "Tab "..tab))
    for slot=1,98 do
        local texture,count=read("GetGuildBankItemInfo",tab,slot)
        if texture then
            local link=read("GetGuildBankItemLink",tab,slot)
            if type(link)~="string" or not add(snapshot,tonumber(link:match("item:(%d+)")),link,count,"Tab "..tab..", slot "..slot) then return end
        end
    end
    ns.db.guildStorage[key]=ns.db.guildStorage[key] or {};ns.db.guildStorage[key][tab]=snapshot
    ns.char.guildStorageKey=key;ns.Emit("STORAGE_CHANGED")
end
function S.Records()
    local rows={}
    for key,character in pairs(ns.db.characters or {}) do
        local identity=character.identity or {};local owner=(identity.name or "Character").." - "..(identity.realm or "Realm")
        for location,snapshot in pairs(character.storage or {}) do if type(location)=="string" and location:match("^bank:") then rows[#rows+1]={key=key..":"..location,owner=owner,snapshot=snapshot} end end
    end
    if ns.db.accountStorage then rows[#rows+1]={key="account",owner="Account",snapshot=ns.db.accountStorage} end
    local guild=read("GetGuildInfo","player");local realm=read("GetRealmName")
    local key=type(guild)=="string" and type(realm)=="string" and realm..":"..guild
    for tab,snapshot in pairs(key and ns.db.guildStorage and ns.db.guildStorage[key] or {}) do rows[#rows+1]={key="guild:"..key..":"..tab,owner="Guild (shared)",snapshot=snapshot,shared=true} end
    table.sort(rows,function(a,b) if a.owner~=b.owner then return a.owner<b.owner end;return a.key<b.key end)
    return rows
end
function S.Locations(id)
    local rows={}
    for _,record in ipairs(S.Records()) do
        local count=(record.snapshot.counts or {})[id]
        if count and count>0 then rows[#rows+1]={owner=record.owner,label=record.snapshot.label,count=count,recorded=record.snapshot.recorded,partial=record.snapshot.partial,shared=record.shared} end
    end
    return rows
end
function S.PersonalLocation(id)
    local matches={}
    for key,snapshot in pairs(ns.char and ns.char.storage or {}) do
        if type(key)=="string" and key:match("^bank:") and (snapshot.counts[id] or 0)>0 then matches[#matches+1]={key=key,label=snapshot.label,count=snapshot.counts[id],recorded=snapshot.recorded} end
    end
    local account=ns.db and ns.db.accountStorage
    if account and (account.counts[id] or 0)>0 then matches[#matches+1]={key="account",label=account.label,count=account.counts[id],recorded=account.recorded} end
    table.sort(matches,function(a,b) if a.recorded~=b.recorded then return a.recorded>b.recorded end;return a.key<b.key end)
    return matches[1]
end
local function queue(key,callback) ns.After("storage:"..key,callback) end
ns.On("BANKFRAME_OPENED",function() S.bankOpen=true;queue("bank",S.CaptureBanks) end)
ns.On("BANKFRAME_CLOSED",function() S.bankOpen=false end)
for _,event in ipairs({"PLAYERBANKSLOTS_CHANGED","PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED","BANK_TAB_SETTINGS_UPDATED"}) do ns.On(event,function() if S.bankOpen then queue("bank",S.CaptureBanks) end end) end
ns.On("GUILDBANKFRAME_OPENED",function() S.guildOpen=true end)
ns.On("GUILDBANKFRAME_CLOSED",function() S.guildOpen=false end)
ns.On("GUILDBANKBAGSLOTS_CHANGED",function() if S.guildOpen then queue("guild",S.CaptureGuild) end end)

ns.Listen("STORAGE_CHANGED",function() ns.After("storageState",function() ns.Emit("STATE_CHANGED","storage") end) end)
