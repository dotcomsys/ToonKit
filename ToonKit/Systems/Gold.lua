local addonName, ns = ...
local G={};ns.Gold=G
ns.Defaults.goldRealmOnly=true
ns.Defaults.goldFactionOnly=false
local function read(name)
    local method=_G[name];if type(method)~="function" then return end
    local ok,value=pcall(method);if ok then return ns.Safe(value) end
end
local function money()
    local value=read("GetMoney")
    if type(value)=="number" and value>=0 and value<math.huge and value==math.floor(value) then return value end
end
local function now() local value=read("GetTime");return type(value)=="number" and value end
function G.Checkpoint()
    if not G.session or not ns.char then return end
    local time=now();local elapsed=time and G.lastTime and math.max(0,time-G.lastTime) or 0
    if G.active then G.session.seconds=G.session.seconds+elapsed;ns.char.goldLedger.seconds=ns.char.goldLedger.seconds+elapsed end
    G.lastTime=time
end
function G.Start()
    if not ns.char or G.session then return end
    local value=money();if not value then return end
    local ledger=ns.char.goldLedger
    if type(ledger)~="table" then ledger={earned=0,spent=0,seconds=0,since=read("GetServerTime") or 0,initial=value};ns.char.goldLedger=ledger end
    for _,key in ipairs({"earned","spent","seconds"}) do if type(ledger[key])~="number" or ledger[key]<0 or ledger[key]~=ledger[key] then ledger[key]=0 end end
    if ledger.observationScope~=1 then
        ledger.legacyRecorded={earned=ledger.earned,spent=ledger.spent,since=ledger.since}
        ledger.observationScope=1
    end
    ledger.balance=value;ledger.realm=ns.Safe(type(GetRealmName)=="function" and GetRealmName());ledger.faction=ns.State.faction
    ledger.name=ns.Safe(type(UnitName)=="function" and UnitName("player"));ledger.recorded=read("GetServerTime") or 0
    G.session={earned=0,spent=0,seconds=0,initial=value};G.balance=value;G.lastTime=now();G.active=true
    ns.Emit("GOLD_CHANGED")
end
function G.Sample()
    if not G.session then G.Start();return end
    if not G.active then return end
    G.Checkpoint();local value=money()
    if not value then G.balance=nil;G.gap=true;return end
    local ledger=ns.char.goldLedger
    if G.balance then
        local delta=value-G.balance
        if delta>0 then G.session.earned=G.session.earned+delta;ledger.earned=ledger.earned+delta
        elseif delta<0 then G.session.spent=G.session.spent-delta;ledger.spent=ledger.spent-delta end
    end
    G.balance=value;ledger.balance=value;ledger.recorded=read("GetServerTime") or 0
end
function G.ResetSession()
    G.Sample();if not G.session then return end
    G.session={earned=0,spent=0,seconds=0,initial=G.balance};G.gap=nil;G.lastTime=now();ns.Emit("GOLD_CHANGED")
end
function G.Format(value)
    if type(value)~="number" then return "Unavailable" end
    local negative=value<0;value=math.floor(math.abs(value)+.5)
    local text=ns.Safe(ns.API.Call("C_CurrencyInfo","GetCoinTextureString",value))
    return (negative and "-" or "")..(text or string.format("%dg %ds %dc",math.floor(value/10000),math.floor(value/100)%100,value%100))
end
local function sessionSeconds()
    local time=G.active and now()
    return G.session.seconds+(time and G.lastTime and math.max(0,time-G.lastTime) or 0)
end
local function unexplainedChange()
    local session=G.session
    if not session or not G.balance or not session.initial then return end
    return G.balance-session.initial-(session.earned-session.spent)
end
function G.Holdings()
    return G.Format(G.balance)
end
function G.Rate()
    if not G.session then return "Unavailable" end
    if G.gap or unexplainedChange()~=0 then return "Incomplete session" end
    local seconds=sessionSeconds()
    return seconds>=60 and G.Format((G.session.earned-G.session.spent)*3600/seconds) or "Measuring (60s)"
end
-- Match the client’s self-loot messages and coin formats. Wallet changes
-- are never used to classify earnings.
local function literal(text)
    return (text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1"))
end
local function pattern(format,token,capture)
    if type(format)~="string" then return end
    local first,last=format:find("%" .. token,1,true)
    if not first then first,last=format:find("%1$" .. token,1,true) end
    if not first or format:sub(last+1):find("%",1,true) then return end
    return literal(format:sub(1,first-1))..capture..literal(format:sub(last+1))
end
local lootFormats,coinFormats={},{}
for _,key in ipairs({"YOU_LOOT_MONEY","LOOT_MONEY_SPLIT"}) do
    local value=pattern(ns.Safe(_G[key]),"s","(.+)")
    if value then lootFormats[#lootFormats+1]="^"..value.."$" end
end
local guildFormat=ns.Safe(_G.LOOT_MONEY_SPLIT_GUILD)
local guildPrefix=type(guildFormat)=="string" and guildFormat:match("^(.-)%%")
for _,coin in ipairs({{"GOLD_AMOUNT",10000},{"SILVER_AMOUNT",100},{"COPPER_AMOUNT",1}}) do
    local value=pattern(ns.Safe(_G[coin[1]]),"d","(%d+)")
    if value then coinFormats[#coinFormats+1]={pattern="^"..value.."()",factor=coin[2]} end
end
local function lootValue(text)
    local total,seen=0,{}
    while text~="" do
        local cursor
        for _,coin in ipairs(coinFormats) do
            local amount,finish=text:match(coin.pattern)
            if amount then
                if seen[coin.factor] then return end
                seen[coin.factor]=true;total=total+tonumber(amount)*coin.factor
                cursor=finish
                break
            end
        end
        if not cursor then return end
        text=text:sub(cursor):gsub("^[%s,]+",""):gsub("^、",""):gsub("^，",""):gsub("^%s+","")
    end
    if total>0 and total<math.huge then return total end
end
local earningsEvents
function G.EarningsRate()
    if not G.session or not earningsEvents then return "Unavailable" end
    if G.session.earningsIncomplete then return "Incomplete session" end
    local seconds=sessionSeconds()
    return seconds>=60 and G.Format(((G.session.loot or 0)+(G.session.quest or 0))*3600/seconds) or "Measuring (60s)"
end
local function recordEarnings(source,amount)
    if not G.session then G.Start() end
    if not G.session or not G.active then return end
    if type(amount)~="number" or amount<0 or amount>=math.huge or amount~=math.floor(amount) then
        G.session.earningsIncomplete=true
    else
        G.session[source]=(G.session[source] or 0)+amount
    end
    ns.Emit("GOLD_CHANGED")
end
local questEvents=ns.On("QUEST_TURNED_IN",function(_,_,copper) recordEarnings("quest",ns.Safe(copper)) end)
local lootEvents=ns.On("CHAT_MSG_MONEY",function(message)
    message=ns.Safe(message)
    if type(message)~="string" then recordEarnings("loot");return end
    for _,format in ipairs(lootFormats) do
        local coins=message:match(format)
        if coins then recordEarnings("loot",lootValue(coins));return end
    end
    if guildPrefix and guildPrefix~="" and message:sub(1,#guildPrefix)==guildPrefix then
        recordEarnings("loot")
    end
end)
earningsEvents=questEvents and lootEvents and #lootFormats==2 and #coinFormats==3
function G.View(compact)
    if not G.session then return {rate="Unavailable",session="Unavailable",lifetime="Unavailable",total="Unavailable",lines={"Money is not readable yet."}} end
    local session,ledger=G.session,ns.char.goldLedger
    local net=session.earned-session.spent;local total,characters=0,0;local wallets={}
    local function accountKey(value,fallback)
        if type(value.realm)=="string" and type(value.name)=="string" then return (value.realm..":"..value.name):lower() end
        return fallback
    end
    local currentKey=accountKey(ledger,ns.char)
    wallets[currentKey]=ledger
    for key,character in pairs(ns.db.characters or {}) do local other=character.goldLedger
        if character~=ns.char and type(other)=="table" and type(other.balance)=="number" and other.balance>=0 and other.balance<math.huge and (not ns.db.settings.goldRealmOnly or other.realm==ledger.realm) and (not ns.db.settings.goldFactionOnly or other.faction==ledger.faction) then
            local identity=accountKey(other,key);local previous=wallets[identity]
            if identity~=currentKey and (not previous or (tonumber(other.recorded) or 0)>(tonumber(previous.recorded) or 0)) then
                wallets[identity]=other
            end
        end
    end
    for _,wallet in pairs(wallets) do total=total+wallet.balance;characters=characters+1 end
    local rate=G.Rate()
    local lines
    if not compact then lines={"Starting wallet: "..G.Format(session.initial),"Current wallet: "..G.Holdings(),"Session received: "..G.Format(session.earned),"Session paid: "..G.Format(session.spent),"Observed session net: "..G.Format(net),"Net wallet/hour: "..rate,
        "Session online time: "..string.format("%.1f min",sessionSeconds()/60),"Observed wallet inflows (includes transfers): "..G.Format(ledger.earned),"Recorded wallet outflows: "..G.Format(ledger.spent),"Recorded wallet net: "..G.Format(ledger.earned-ledger.spent),
        "Tracked online time: "..string.format("%.1f hours",ledger.seconds/3600),"Recorded character gold: "..G.Format(total).." ("..characters.." characters)",
        "Lifetime earnings are unknown. Recorded inflows include transfers and repeat circulation of the same gold.","Rates use online time and wallet changes, including trades and transfers. They are not loot-only profit. Alt balances are last recorded; account-bank gold is excluded."}
    if G.gap then lines[#lines+1]="Money was unreadable during this session. Changes across that gap were not counted." end
    local difference=unexplainedChange()
    if difference and difference~=0 then lines[#lines+1]="Wallet change outside recorded events: "..G.Format(difference) end
    end
    return {rate=rate,session=G.Format(net),holdings=G.Holdings(),received=G.Format(ledger.earned),lifetime=G.Format(ledger.earned),total=G.Format(total),characters=characters,lines=lines}
end
function G.Tooltip(metric)
    if not G.session then return {"Waiting for readable wallet data."} end
    local session=G.session
    if metric=="goldrate" then
        if not earningsEvents then return {"This client’s loot or quest reward messages are unavailable."} end
        return {"Looted coin: "..G.Format(session.loot or 0).." · Quest coin: "..G.Format(session.quest or 0),
            string.format("Online time: %.1f min",sessionSeconds()/60),
            "Counts direct coin from loot and quest rewards. Purchases, sales, trades and transfers stay out.",
            session.earningsIncomplete and "A reward amount was unreadable. Reset the gold session for a fresh rate." or nil}
    end
    if metric=="goldlife" then return {"Total recorded wallet deposits: "..G.Format(ns.char.goldLedger.earned),"Includes transfers and repeat circulation of the same gold."} end
    if metric=="goldtotal" then
        local view=G.View(true)
        return {view.total.." across "..view.characters.." recorded characters.","Alt balances are last recorded. Account-bank gold is excluded."}
    end
    local lines={"Started with: "..G.Format(session.initial),"Current wallet: "..G.Holdings(),
        "Received: "..G.Format(session.earned).." · Paid: "..G.Format(session.spent),
        "Observed wallet change: "..G.Format(session.earned-session.spent)}
    local difference=unexplainedChange()
    if difference and difference~=0 then lines[#lines+1]="Untracked wallet change: "..G.Format(difference) end
    if G.Rate()=="Incomplete session" then lines[#lines+1]="Wallet tracking was interrupted. Reset the gold session in Status bar settings for a fresh rate." end
    lines[#lines+1]="Wallet changes include purchases, trades and transfers."
    return lines
end
ns.On("PLAYER_LOGIN",function() ns.After("goldStart",G.Start) end)
ns.On("PLAYER_MONEY",function() G.Sample();ns.Emit("GOLD_CHANGED") end)
ns.On("PLAYER_LEAVING_WORLD",function() G.Checkpoint();G.active=false;G.balance=nil end)
ns.On("PLAYER_ENTERING_WORLD",function()
    if not G.session then ns.After("goldStart",G.Start);return end
    G.lastTime=now();G.active=true;G.balance=nil
    ns.After("goldWorldEntry",function()
        if G.active then G.Sample();ns.Emit("GOLD_CHANGED") end
    end)
end)
ns.On("PLAYER_LOGOUT",G.Sample)
