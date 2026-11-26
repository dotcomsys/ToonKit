local addonName, ns = ...
-- Session estimates use observed values only. No combat-log access or fixed XP tables.
local X={gained=0,questTotal=0,questCount=0,mobTotal=0,mobCount=0};ns.Experience=X
local function number(value)
    value=ns.Safe(value)
    if type(value)=="number" and value==value and value>=0 and value<math.huge then return value end
end
local function read(name,...)
    local f=_G[name];if type(f)~="function" then return end
    local ok,v=pcall(f,...);if ok then return number(v) end
end
local function now() return read("GetTime") or 0 end
local function gain(delta)
    if not delta or delta<=0 then return end
    X.gained=X.gained+delta;X.samples=X.samples or {};local time=now()
    local last=X.samples[#X.samples]
    if last and math.floor(last.time)==math.floor(time) then last.gain=last.gain+delta else X.samples[#X.samples+1]={time=time,gain=delta} end
    while X.samples[1] and time-X.samples[1].time>900 do table.remove(X.samples,1) end
end
function X.Sample()
    local xp,max,level=read("UnitXP","player"),read("UnitXPMax","player"),read("UnitLevel","player")
    if not xp or not max or not level or level<1 or xp>max then return end
    if max==0 then
        if level>=ns.Rules.Cap() then
            if X.lastLevel and level==X.lastLevel+1 then gain(X.lastMax-X.lastXP) elseif X.lastLevel and level~=X.lastLevel then X.incomplete=true end
            X.level=level;X.xp=xp;X.maximum=max;X.lastLevel=level;X.lastXP=xp;X.lastMax=max
        else X.level=level;X.xp=nil;X.maximum=nil end
        X.rested=read("GetXPExhaustion");return
    end
    -- PLAYER_LEVEL_UP can precede the native XP/level updates. Preserve the
    -- old level's maximum and counter until the rollover has settled.
    if X.pendingLevel and level<X.pendingLevel then return end
    if X.lastXP and X.lastLevel and level==X.lastLevel and xp<X.lastXP then return end
    X.started=X.started or now();local delta
    if X.lastXP and X.lastLevel then
        if level==X.lastLevel then delta=xp-X.lastXP
        elseif level==X.lastLevel+1 then delta=(X.lastMax-X.lastXP)+xp
        else X.incomplete=true end
    end
    gain(delta)
    X.lastXP,X.lastMax,X.lastLevel=xp,max,level
    X.xp,X.maximum,X.level=xp,max,level;X.pendingLevel=nil
    X.rested=read("GetXPExhaustion")
    if type(GetXPExhaustion)=="function" then
        local ok,raw=pcall(GetXPExhaustion)
        if ok and not (type(issecretvalue)=="function" and issecretvalue(raw)) and raw==nil then X.rested=0 end
    end
end
function X.Reset()
    X.gained=0;X.questTotal=0;X.questCount=0;X.mobTotal=0;X.mobCount=0
    X.started=nil;X.lastXP=nil;X.lastLevel=nil;X.lastMax=nil;X.pendingLevel=nil;X.incomplete=nil;X.samples={}
    X.Sample();ns.Emit("EXPERIENCE_CHANGED")
end
-- Match the client's localized kill-XP formats, never guess from arbitrary digits.
function X.MatchGain(message,format)
    if type(message)~="string" or type(format)~="string" then return end
    local pattern,captures,xpCapture="^",0,nil;local i=1
    while i<=#format do
        local c=format:sub(i,i)
        if c=="%" then
            local tail=format:sub(i);local token=tail:match("^%%[sd]") or tail:match("^%%%d+%$[sd]")
            if token then
                captures=captures+1;local kind=token:sub(-1)
                pattern=pattern..(kind=="d" and "(%d[%d%.,]*)" or "(.-)")
                if kind=="d" and not xpCapture then xpCapture=captures end
                i=i+#token
            elseif tail:sub(1,2)=="%%" then pattern=pattern.."%%";i=i+2
            else return end
        else
            pattern=pattern..c:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1");i=i+1
        end
    end
    if not xpCapture then return end
    local values={message:match(pattern.."$")};local value=values[xpCapture];return type(value)=="string" and number(tonumber((value:gsub("[^%d]","")))) or nil
end
function X.MobGain(message)
    message=ns.Safe(message);if type(message)~="string" then return end
    if not X.killFormats then
        X.killFormats={}
        for key,format in pairs(_G) do
            if type(key)=="string" and key:match("^COMBATLOG_XPGAIN_FIRSTPERSON") and type(ns.Safe(format))=="string" then X.killFormats[#X.killFormats+1]=ns.Safe(format) end
        end
    end
    for _,format in ipairs(X.killFormats) do
        local gain=X.MatchGain(message,format)
        if gain and gain>0 then X.mobTotal=X.mobTotal+gain;X.mobCount=X.mobCount+1;return end
    end
end
local function rounded(n) return n and tostring(math.floor(n+.5)) or "Unavailable" end
function X.View(compact)
    local remaining=X.xp and X.maximum and math.max(0,X.maximum-X.xp)
    local current=now();local elapsed=X.started and math.max(0,current-X.started) or 0
    local span=tonumber(ns.db.settings.xpRateWindow) or 0;local gained=X.gained
    if span>0 then
        span=math.min(span,elapsed);gained=0
        for _,sample in ipairs(X.samples or {}) do if current-sample.time<=span then gained=gained+sample.gain end end
    else span=elapsed end
    local rate=not X.incomplete and elapsed>=60 and span>0 and gained*3600/span or nil
    local capped=X.level and X.level>=ns.Rules.Cap()
    local function estimate(total,count)
        if capped then return "At cap" end
        return remaining and count>0 and total>0 and ("~"..math.ceil(remaining/(total/count))) or "Collecting data"
    end
    local eta=rate and rate>0 and remaining and math.ceil(remaining/rate*60)
    local v={remaining=capped and "At cap" or rounded(remaining),rate=rate and rounded(rate) or "Collecting data",
        eta=capped and "At cap" or eta and (eta.." min") or rate==0 and "No recent XP" or "Collecting data",quests=estimate(X.questTotal,X.questCount),mobs=estimate(X.mobTotal,X.mobCount),
        rested=rounded(X.rested),fraction=not capped and X.maximum and X.maximum>0 and X.xp and math.min(1,X.xp/X.maximum) or nil}
    v.compact=capped and "At active level cap" or (v.remaining.." XP to level  |  "..v.rate.." XP/h")
    if not compact then v.lines={"XP to level: "..v.remaining,"Session XP: "..rounded(X.gained),"XP/hour: "..v.rate.." ("..(tonumber(ns.db.settings.xpRateWindow)==0 and "session" or (ns.db.settings.xpRateWindow/60).." min window")..")","Time to level: "..v.eta,
        "Quests remaining: "..v.quests.." ("..X.questCount.." rewards sampled)","Mobs remaining: "..v.mobs.." ("..X.mobCount.." localized XP messages sampled)",
        "Rested XP pool: "..v.rested,"Estimates use this session's averages; future rewards and rested bonuses can differ."} end
    v.session=rounded(X.gained);v.elapsed=math.floor(elapsed/60).." min";v.rawRate=rate;v.rawRemaining=remaining
    if X.incomplete then
        v.rate="Unavailable";v.eta="Unavailable";v.compact=v.remaining.." XP to level | XP rate unavailable"
        if v.lines then v.lines[#v.lines+1]="A multi-level transition was missed. Reset the XP session to restore rate estimates." end
    end
    return v
end
local function refresh()
    ns.After("experience",function() X.Sample();ns.Emit("EXPERIENCE_CHANGED") end)
end
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_XP_UPDATE","UPDATE_EXHAUSTION"}) do
    local observedEvent=event
    ns.On(event,function(unit) unit=ns.Safe(unit);if unit==nil or unit=="player" or observedEvent~="PLAYER_XP_UPDATE" then refresh() end end)
end
ns.On("PLAYER_LEVEL_UP",function(level) X.pendingLevel=number(level);refresh() end)
ns.On("QUEST_TURNED_IN",function(_,reward)
    reward=number(reward);if reward and reward>0 then X.questTotal=X.questTotal+reward;X.questCount=X.questCount+1 end
    refresh()
end)
ns.On("CHAT_MSG_COMBAT_XP_GAIN",function(message) X.MobGain(message);refresh() end)
