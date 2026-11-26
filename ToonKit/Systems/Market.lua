local addonName, ns = ...
local M={};ns.Market=M
function M.Scope()
    return ns.Safe(GetRealmName(),"unknown")..":"..(ns.State.faction or "unknown")
end
function M.Key(key)
    if type(key)~="table" then return end
    local parts={}
    for _,field in ipairs({"itemID","itemLevel","itemSuffix","battlePetSpeciesID"}) do
        local value=ns.Safe(key[field],0);if type(value)~="number" then return end
        parts[#parts+1]=tostring(value)
    end
    return table.concat(parts,":")
end
function M.Record(key,rows,complete)
    local identity=M.Key(key);if not identity or not ns.db then return end
    ns.db.market=ns.db.market or {};local scope=M.Scope();ns.db.market[scope]=ns.db.market[scope] or {}
    local entries=ns.db.market[scope];local sample={time=ns.Safe(GetServerTime(),0),complete=complete==true,offers=#rows,key=ns.Copy(key)}
    for _,r in ipairs(rows) do if r.unitPrice and (not sample.lowest or r.unitPrice<sample.lowest) then sample.lowest=r.unitPrice end end
    local history=entries[identity] or {};entries[identity]=history;history[#history+1]=sample
    while #history>20 do table.remove(history,1) end
    local keys={};for k,v in pairs(entries) do keys[#keys+1]={key=k,time=v[#v] and v[#v].time or 0} end
    if #keys>500 then table.sort(keys,function(a,b) return a.time<b.time end);for i=1,#keys-500 do entries[keys[i].key]=nil end end
end
function M.Latest(key)
    local identity=M.Key(key);local history=identity and ns.db and ns.db.market and ns.db.market[M.Scope()] and ns.db.market[M.Scope()][identity]
    return history and history[#history]
end
