local addonName, ns = ...
ns.events, ns.signals, ns.pending = {}, {}, {}
ns.errors={}
ns.frame = CreateFrame("Frame")
function ns.Safe(value, fallback)
    if type(issecretvalue) == "function" and issecretvalue(value) then return fallback end
    if value == nil then return fallback end
    return value
end
function ns.Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for k, v in pairs(value) do out[k] = ns.Copy(v) end; return out
end
function ns.On(event, callback)
    if not ns.events[event] then
        ns.events[event] = {}
        local ok = pcall(ns.frame.RegisterEvent, ns.frame, event)
        if not ok then ns.events[event] = nil; return false end
    end
    table.insert(ns.events[event], callback); return true
end
function ns.Listen(signal, callback)
    ns.signals[signal] = ns.signals[signal] or {}; table.insert(ns.signals[signal], callback)
end
function ns.Emit(signal, ...)
    if signal=="STATE_CHANGED" then ns.stateEpoch=(ns.stateEpoch or 0)+1 end
    for index,callback in ipairs(ns.signals[signal] or {}) do ns.Invoke(signal..":"..index,callback,...) end
end
function ns.Invoke(key,callback,...)
    -- Fault isolation only; protected actions still obey their normal restrictions.
    local ok,error=pcall(callback,...)
    if not ok then
        local first=not ns.errors[key]; ns.errors[key]=tostring(error)
        if first then
            ns.Message("A module error was recorded ("..key.."). See Settings > About.")
            if geterrorhandler then geterrorhandler()(error) end
        end
    end
    return ok
end
-- Unscoped/manual changes retain full invalidation for existing controls.
function ns.Changed(kind,...)
    if kind==nil or kind=="all" or type(kind)=="table" and kind.all then return true end
    for index=1,select("#",...) do
        local key=select(index,...)
        if kind==key or type(kind)=="table" and kind[key] then return true end
    end
    return false
end
function ns.After(key, callback, delay)
    if ns.pending[key] then return end
    ns.pending[key] = true
    C_Timer.After(delay or 0.15, function() ns.pending[key] = nil; if ns.db then ns.Invoke("timer:"..key,callback) end end)
end
function ns.Message(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffd4af66" .. ns.Brand.shortName .. "|r: " .. tostring(text)) end
end
ns.deferred = {}
function ns.OutOfCombat(key, callback)
    if InCombatLockdown() then ns.deferred[key] = callback else callback() end
end
ns.On("PLAYER_REGEN_ENABLED", function()
    local queue = ns.deferred; ns.deferred = {}; for key,callback in pairs(queue) do ns.Invoke("combat:"..key,callback) end
end)
ns.frame:SetScript("OnEvent", function(_, event, ...)
    for index,callback in ipairs(ns.events[event] or {}) do ns.Invoke(event..":"..index,callback,...) end
end)
