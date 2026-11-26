local addonName, ns = ...
local E={};ns.EffectMath=E
ns.Defaults.simulationCombat={spellPower=0,healingPower=0,attackPower=0,damageMultiplier=1,healingMultiplier=1,overhealing=0,manaWeight=0,melee=0,ranged=0,spell=0,struck=0,fixedEvents=true}
function E.Snapshot()
    local build=type(GetBuildInfo)=="function" and select(2,GetBuildInfo())
    build=ns.Safe(build)
    return build and (ns.Data.effectCoverage or {})[tostring(build)]
end
function E.Combat(scenario) return scenario.combat or ns.db.settings.simulationCombat or ns.Defaults.simulationCombat end
function E.ValidCombat(config)
    if type(config)~="table" then return false,"Missing effect context." end
    if config.fixedEvents~=nil and type(config.fixedEvents)~="boolean" then return false,"Choose a valid event cadence." end
    for key,maximum in pairs({spellPower=100000,healingPower=100000,attackPower=100000,damageMultiplier=100,healingMultiplier=100,overhealing=1,manaWeight=1000,melee=100,ranged=100,spell=100,struck=100}) do
        local value=config[key]
        if type(value)~="number" or value~=value or value<0 or value>maximum then return false,"Invalid effect context: "..key end
    end
    return true
end
-- Erlang arrival CDF: n exponential waits plus (n-1) internal cooldowns.
-- Used only for bounded sourced proc rates; no random rolls or combat reader.
local function cdf(n,x)
    if x<=0 then return 0 end
    if x>745 and n<256 then return 1 end
    local term=math.exp(-x);local sum=term
    for k=1,n-1 do term=term*x/k;sum=sum+term end
    return math.max(0,math.min(1,1-sum))
end
local function integral(n,time,rate)
    if time<=0 then return 0 end
    return math.max(0,time*cdf(n,time*rate)-n/rate*cdf(n+1,time*rate))
end
local function proc(rate,icd,duration,buff)
    if rate<=0 then return 0,0 end
    if icd==0 then
        local window=math.min(duration,buff or 0)
        local uptime=window-(1-math.exp(-rate*window))/rate+(duration-window)*(1-math.exp(-rate*window))
        return rate*duration,math.max(0,uptime)
    end
    local limit=math.ceil(duration/icd)
    if limit>255 then return nil,nil,"Proc arrival schedule exceeds 255 events; shorten the fight or use a longer sourced ICD." end
    local events,active=0,0
    for n=1,limit do
        local horizon=duration-(n-1)*icd
        if horizon<=0 then break end
        events=events+cdf(n,horizon*rate)
        if buff and buff>0 and buff<=icd then active=active+integral(n,horizon,rate)-integral(n,horizon-buff,rate) end
    end
    if buff and buff>icd then
        -- Overlapping renewal buffs require a stacking/refresh model.
        return events,nil,"Buff refresh with duration above ICD needs a sourced stacking/refresh model."
    end
    return events,math.min(duration,active)
end
E.procCache={};E.procCount=0
function E.Proc(rate,icd,duration,buff)
    local key=table.concat({rate,icd,duration,buff or 0},":")
    local cached=E.procCache[key]
    if cached then return cached[1],cached[2],cached[3] end
    local events,active,why=proc(rate,icd,duration,buff)
    if E.procCount>=256 then E.procCache={};E.procCount=0 end
    E.procCache[key]={events,active,why};E.procCount=E.procCount+1
    return events,active,why
end
local function fixed(chance,rate,icd,duration,buff)
    if rate<=0 then return 0,0 end
    local count=math.floor(duration*rate+.00000001)
    if count>60000 then return nil,nil,"Fixed-event schedule exceeds 60,000 events." end
    local steps=math.max(1,math.ceil(icd*rate-.00000001))
    if icd>0 and buff>steps/rate then return nil,nil,"Overlapping ICD buff refresh needs a specific timeline model." end
    local ready,events,active=1,0,0;local returns={}
    local whole=math.floor(buff*rate);local fraction=buff*rate-whole
    for index=1,count do
        ready=ready+(returns[index] or 0)
        local probability=math.max(0,math.min(1,ready))*chance
        events=events+probability;ready=ready-probability
        returns[index+steps]=(returns[index+steps] or 0)+probability
        local time=index/rate
        if icd==0 and buff>0 then
            local interval=math.min(1/rate,duration-time)
            local early=math.min(interval,fraction/rate)
            active=active+early*(1-(1-chance)^math.min(index,whole+1))+(interval-early)*(1-(1-chance)^math.min(index,whole))
        elseif buff>0 then active=active+probability*math.max(0,math.min(buff,duration-time)) end
    end
    return events,math.min(duration,active)
end
E.fixedCache={};E.fixedCount=0
function E.FixedProc(chance,rate,icd,duration,buff)
    local key=table.concat({chance,rate,icd,duration,buff or 0},":")
    local cached=E.fixedCache[key];if cached then return cached[1],cached[2],cached[3] end
    local events,active,why=fixed(chance,rate,icd,duration,buff or 0)
    if E.fixedCount>=256 then E.fixedCache={};E.fixedCount=0 end
    E.fixedCache[key]={events,active,why};E.fixedCount=E.fixedCount+1
    return events,active,why
end
function E.Output(model,scenario,events,uses)
    local config=E.Combat(scenario)
    local power=model.kind=="healing" and config.healingPower or config.spellPower
    local amount=model.amount+(model.spellCoefficient or 0)*power+(model.apCoefficient or 0)*config.attackPower
    local count=events
    if model.period then
        if model.trigger~="use" then return nil,"Periodic procs need an explicit refresh/stacking model." end
        count=0
        for _,time in ipairs(uses or {}) do
            count=count+math.max(0,math.floor((math.min(model.duration,scenario.duration-time)+.00000001)/model.period))
        end
        -- Repeated periodic uses may refresh rather than stack; do not assume.
        if model.duration>model.cooldown then return nil,"Periodic uses overlap; supply the actual stacking/refresh behavior." end
    end
    local raw=amount*count/scenario.duration
    if config.timeline then
        local extra,why=config.timeline:Extra(model,uses,scenario.effectOrder)
        if why then return nil,why end
        raw=raw+extra
    end
    local value=raw
    if model.kind=="damage" then value=value*config.damageMultiplier
    elseif model.kind=="healing" then value=value*config.healingMultiplier*(1-config.overhealing) end
    return value,nil,raw,count
end
function E.Models(record)
    local snapshot=E.Snapshot();local entry=snapshot and snapshot.items[record.id]
    if not entry then return end
    local models,unknown={},ns.Copy(entry.unknown)
    for _,model in ipairs(entry.models) do
        -- Passive attributes are normally included by GetItemStats. Score only
        -- native-reported omission; an unavailable read never means zero stats.
        if model.kind=="stat" and model.trigger=="passive" then
            local values=ns.API.Call("C_Item","GetItemStats",record.link or record.info.link)
            local value=type(values)=="table" and ns.Safe(values[model.stat])
            if type(value)~="number" or value<model.amount then unknown[#unknown+1]="Passive stat #"..model.spell.." is not corroborated by native item stats" end
        else models[#models+1]=ns.Copy(model) end
    end
    return models,unknown
end
