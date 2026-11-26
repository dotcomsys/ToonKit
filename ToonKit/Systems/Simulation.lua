local addonName, ns = ...
local S={};ns.Simulation=S
ns.Defaults.simulation={duration=120,attacks=0,damageWeight=1,healingWeight=1,weaponWeight=1,useDelay=0,perSlot=6,maxNodes=100000}
ns.Defaults.simEffects={}
ns.Defaults.gearUseModels=false
S.nativeModels={};S.modelRevision=0;S.settingsRevision=0
local stats={strength="ITEM_MOD_STRENGTH_SHORT",agility="ITEM_MOD_AGILITY_SHORT",stamina="ITEM_MOD_STAMINA_SHORT",intellect="ITEM_MOD_INTELLECT_SHORT",spirit="ITEM_MOD_SPIRIT_SHORT",["attack power"]="ITEM_MOD_ATTACK_POWER_SHORT",["spell power"]="ITEM_MOD_SPELL_POWER_SHORT"}
local function number(value,min,max)
    return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge and value>=min and value<=max
end
function S.ValidateScenario(input)
    if type(input)~="table" then return false,"Missing scenario." end
    local bounds={duration={1,1800},attacks={0,30},damageWeight={0,1000},healingWeight={0,1000},weaponWeight={0,1000},useDelay={0,1800},perSlot={1,30},maxNodes={100,1000000}}
    for key,range in pairs(bounds) do if not number(input[key],range[1],range[2]) then return false,"Invalid scenario value: "..key end end
    if input.perSlot~=math.floor(input.perSlot) or input.maxNodes~=math.floor(input.maxNodes) then return false,"Candidate and node budgets must be whole numbers." end
    if input.combat then return ns.EffectMath.ValidCombat(input.combat) end
    return true
end
function S.ValidateModel(model)
    if type(model)~="table" or type(model.source)~="string" or model.source:match("^%s*$") then return false,"Every effect needs a source or observation note." end
    if model.kind~="stat" and model.kind~="damage" and model.kind~="healing" and model.kind~="mana" then return false,"Choose an effect type." end
    if model.trigger~="use" and model.trigger~="proc" and model.trigger~="passive" then return false,"Choose a trigger." end
    if not number(model.amount,model.kind=="stat" and -1000000 or 0,1000000) then return false,"Enter a valid amount." end
    if model.kind=="stat" then
        local known=false;for _,weights in pairs(ns.Data.priorities) do if weights[model.stat]~=nil then known=true end end
        if not known then return false,"Choose a supported weighted stat." end
    end
    if model.trigger=="use" and not number(model.cooldown,0.01,86400) then return false,"An on-use effect needs its sourced cooldown." end
    if model.kind=="stat" and model.trigger~="passive" and not number(model.duration,0.01,3600) then return false,"A stat buff needs its sourced duration." end
    for key,maximum in pairs({duration=3600,cooldown=86400,chance=1,ppm=1000,icd=86400,sharedCooldown=86400}) do
        if model[key]~=nil and not number(model[key],0,maximum) then return false,"Invalid effect value: "..key end
    end
    if model.trigger=="proc" then
        if (model.ppm or 0)>0 and (model.chance or 0)>0 then return false,"Choose per-event chance or PPM, not both." end
        if not (number(model.ppm or 0,0.0001,1000) or number(model.chance or 0,0.000001,1)) then return false,"Supply a sourced PPM or per-event proc chance." end
        if not number(model.icd or 0,0,86400) then return false,"Invalid internal cooldown." end
    end
    if model.group~=nil and type(model.group)~="string" then return false,"Invalid shared cooldown group." end
    if model.group and model.group~="" and not number(model.sharedCooldown,0.01,86400) then return false,"A shared cooldown group needs its sourced lockout." end
    for _,key in ipairs({"spellCoefficient","apCoefficient"}) do if model[key]~=nil and not number(model[key],0,1000) then return false,"Invalid scaling coefficient." end end
    if model.period~=nil and (not number(model.period,0.01,3600) or not number(model.duration,model.period,3600)) then return false,"Periodic effects need a sourced period and duration." end
    if model.event~=nil and model.event~="melee" and model.event~="ranged" and model.event~="spell" and model.event~="struck" then return false,"Unsupported proc event." end
    return true
end
local function cooldown(lines)
    for _,line in ipairs(lines or {}) do
        local text=line:lower()
        local minutes,seconds=text:match("(%d+)%s*min%s+(%d+)%s*sec%s+cooldown")
        if minutes then return tonumber(minutes)*60+tonumber(seconds) end
        local value=text:match("(%d+%.?%d*)%s*min%s+cooldown") or text:match("cooldown:%s*(%d+%.?%d*)%s*min")
        if value then return tonumber(value)*60 end
        value=text:match("(%d+%.?%d*)%s*sec%s+cooldown") or text:match("cooldown:%s*(%d+%.?%d*)%s*sec")
        if value then return tonumber(value) end
    end
end
function S.ParseUse(text,cd)
    if type(text)~="string" or not cd then return end
    local lower=text:lower():gsub("^use:%s*","")
    for name,stat in pairs(stats) do
        local amount,duration,tail=lower:match("^increases your "..name.." by (%d+) for (%d+%.?%d*) sec%.?(.*)$")
        if not amount then amount,duration,tail=lower:match("^increases "..name.." by (%d+) for (%d+%.?%d*) sec%.?(.*)$") end
        if amount then
            tail=tail:gsub("[%s%(%)%.|]","")
            if tail=="" or tail:match("^%d+mincooldown$") or tail:match("^%d+seccooldown$") or tail:match("^%d+min%d+seccooldown$") then
                return {kind="stat",trigger="use",stat=stat,amount=tonumber(amount),duration=tonumber(duration),cooldown=cd,source="Native item/spell tooltip: "..text}
            end
        end
    end
end
local function represented(text,record)
    local values=ns.API.Call("C_Item","GetItemStats",record.link or record.info.link)
    for name,stat in pairs(stats) do
        local amount=text:match("^equip: increases your "..name.." by (%d+)%.*$") or text:match("^equip: increases "..name.." by (%d+)%.*$")
        local value=values and ns.Safe(values[stat])
        if amount and type(value)=="number" and value>=tonumber(amount) then return true end
    end
    return false
end
function S.Models(record,facts,nativeOnly)
    local custom=not nativeOnly and (ns.db.settings.simEffects or {})[record.id]
    if custom then
        local unknown=custom.complete==true and {} or {"Effect coverage not marked complete: "..record.info.name}
        local signature=table.concat(facts.effects or {},"\n").."\n"..(facts.useDescription or "")
        if facts.pending then unknown[#unknown+1]=record.info.name..": native tooltip data pending"
        elseif custom.nativeSignature and custom.nativeSignature~=signature then unknown[#unknown+1]=record.info.name..": native effect text changed since this personal model was saved" end
        if custom.build and type(GetBuildInfo)=="function" then local _,build=GetBuildInfo();if tostring(ns.Safe(build))~=custom.build then unknown[#unknown+1]=record.info.name..": personal model was saved on client build "..custom.build end end
        return ns.Copy(custom.models or {}),unknown
    end
    local models,unknown
    if not nativeOnly then models,unknown=ns.EffectMath.Models(record) end
    if models then
        if facts.pending then unknown[#unknown+1]=record.info.name..": native tooltip data pending" end
        local key=record.link or record.info.link or ("item:"..record.id)
        local version=(ns.API.itemVersions or {})[record.id] or 0
        local previous=S.nativeModels[key]
        if not previous or previous.version~=version then
            S.nativeModels[key]={models=ns.Copy(models),unknown=ns.Copy(unknown),version=version,id=record.id}
            S.modelRevision=S.modelRevision+1;ns.Gear.capKey=nil;ns.Gear.rankInput=nil
        end
        return models,unknown
    end
    models,unknown={},{}
    local locale=type(GetLocale)=="function" and GetLocale() or "enUS"
    local cd=cooldown(facts.lines);local parsed=false
    for _,text in ipairs(facts.effects or {}) do
        local lower=text:lower()
        if lower:find("^use:") and (locale=="enUS" or locale=="enGB") then
            local model=S.ParseUse(text,cd)
            -- Compound, conditional and proc descriptions need an explicit
            -- sourced model; a matching substring is not complete coverage.
            local compound=lower:find(" and ",1,true) or lower:find("chance",1,true) or lower:find(" if ",1,true) or lower:find("stack",1,true)
            if model and not compound and not parsed then models[#models+1]=model;parsed=true else unknown[#unknown+1]=record.info.name..": "..text end
        elseif lower:find("chance on hit",1,true) or lower:find("chance to",1,true) or lower:find("set:",1,true) then
            if not lower:find("set:",1,true) then unknown[#unknown+1]=record.info.name..": "..text end
        elseif not lower:find("set:",1,true) and not represented(lower,record) then unknown[#unknown+1]=record.info.name..": "..text end
    end
    if facts.useSpell and not parsed then unknown[#unknown+1]=record.info.name..": unmodeled use spell #"..facts.useSpell end
    if facts.pending then unknown[#unknown+1]=record.info.name..": native tooltip data pending" end
    local key=record.link or record.info.link or ("item:"..record.id)
    local version=(ns.API.itemVersions or {})[record.id] or 0
    local previous=S.nativeModels[key]
    if not facts.pending and (not previous or previous.version~=version) then
        S.nativeModels[key]={models=ns.Copy(models),unknown=ns.Copy(unknown),version=version,id=record.id}
        S.modelRevision=S.modelRevision+1;ns.Gear.capKey=nil;ns.Gear.rankInput=nil
        if ns.InventoryRules then ns.InventoryRules.facts={} end
    end
    return models,unknown
end
local function weighted(stat,amount,profile)
    local values={[stat]=amount}
    if ns.Gear.TalentAdjustments and (not profile or profile.live or profile.ranks and profile.valid) then values=ns.Gear.TalentAdjustments(values,profile) end
    local score=0;for key,value in pairs(values) do score=score+value*(ns.Gear.Weights(profile)[key] or 0) end;return score
end
function S.Effect(model,scenario,profile,nextGroup)
    local ok,why=S.ValidateModel(model);if not ok then return {score=0,unknown=why} end
    local duration=scenario.duration;local active,events=0,0;local uses={}
    if model.trigger=="passive" then active=duration;events=duration
    elseif model.trigger=="use" and scenario.scheduledUses then
        uses=scenario.scheduledUses[scenario.effectOrder] or {}
        local lastEnd=0
        for _,time in ipairs(uses) do
            events=events+1
            local ending=math.min(duration,time+(model.duration or 0))
            active=active+math.max(0,ending-math.max(time,lastEnd));lastEnd=math.max(lastEnd,ending)
        end
    elseif model.trigger=="use" then
        local start=scenario.useDelay;local lastEnd=0
        local group=model.group and model.group~="" and model.group
        local activation=group and model.activation and nextGroup._owner and (nextGroup._owner..":"..model.activation)
        nextGroup._casts=nextGroup._casts or {}
        local previous=activation and nextGroup._casts[activation]
        if previous then
            uses=previous
            for _,time in ipairs(uses) do
                events=events+1
                local ending=math.min(duration,time+(model.duration or 0))
                active=active+math.max(0,ending-math.max(time,lastEnd));lastEnd=math.max(lastEnd,ending)
            end
            start=duration
        elseif not group and not model.period and not scenario.timeline then
            if start<duration then
                events=math.floor((duration-start-0.00000001)/model.cooldown)+1
                if (model.duration or 0)>=model.cooldown then active=math.min(duration-start,(events-1)*model.cooldown+(model.duration or 0))
                else active=math.max(0,events-1)*(model.duration or 0)+math.min(model.duration or 0,duration-start-math.max(0,events-1)*model.cooldown) end
            end
            start=duration
        elseif math.ceil(duration/model.cooldown)>256 then return {score=0,unknown="Use schedule exceeds 256 activations; shorten the scenario."}
        elseif group then nextGroup[group]=nextGroup[group] or {} end
        while start<duration do
            if group then
                local changed=true
                while changed do
                    changed=false
                    for _,interval in ipairs(nextGroup[group]) do
                        if start<interval[2] and start+model.sharedCooldown>interval[1] then start=interval[2];changed=true end
                    end
                end
            end
            if start>=duration then break end
            events=events+1
            uses[#uses+1]=start
            local ending=math.min(duration,start+(model.duration or 0))
            active=active+math.max(0,ending-math.max(start,lastEnd));lastEnd=math.max(lastEnd,ending)
            if group then
                nextGroup[group][#nextGroup[group]+1]={start,start+model.sharedCooldown}
                table.sort(nextGroup[group],function(a,b) return a[1]<b[1] end)
            end
            start=start+model.cooldown
        end
        if activation and not previous then nextGroup._casts[activation]=uses end
    else
        local eligible=model.event and ns.EffectMath.Combat(scenario)[model.event] or scenario.attacks
        local rate=(model.ppm or 0)>0 and model.ppm/60 or eligible*(model.chance or 0)
        if rate<=0 then return {score=0,unknown="Per-event proc model needs a nonzero scenario attack/event rate."} end
        local why
        if (model.chance or 0)>0 and ns.EffectMath.Combat(scenario).fixedEvents then
            events,active,why=ns.EffectMath.FixedProc(model.chance,eligible,model.icd or 0,duration,model.kind=="stat" and model.duration or 0)
        else events,active,why=ns.EffectMath.Proc(rate,model.icd or 0,duration,model.kind=="stat" and model.duration or 0) end
        if why then return {score=0,unknown=why} end
    end
    active=math.min(duration,active)
    local value,why,raw,ticks
    if model.kind=="stat" then value=model.amount*active/duration
    else value,why,raw,ticks=ns.EffectMath.Output(model,scenario,events,uses);if why then return {score=0,unknown=why} end end
    local weight=model.kind=="damage" and scenario.damageWeight or model.kind=="mana" and ns.EffectMath.Combat(scenario).manaWeight or scenario.healingWeight
    local score=model.kind=="stat" and weighted(model.stat,value,profile) or value*weight
    return {score=score,uptime=active/duration,events=events,uses=uses,ticks=ticks,raw=raw,value=value,damage=model.kind=="damage" and value or 0,healing=model.kind=="healing" and value or 0,mana=model.kind=="mana" and value or 0}
end
function S.EvaluationExtra(link,profile)
    local id=type(link)=="string" and tonumber(link:match("item:(%d+)"))
    local custom=id and (ns.db.settings.simEffects or {})[id]
    local cached=S.nativeModels[link]
    if cached and cached.version~=((ns.API.itemVersions or {})[cached.id] or 0) then cached=nil end
    if not custom and not cached and id then
        local info=ns.API.Item(link)
        if info then S.Models({id=id,link=link,info=info},ns.Gear.Facts(link));cached=S.nativeModels[link] end
    end
    local models=custom and custom.models or cached and cached.models
    if not models then return end
    local score,unknown=0,custom and (custom.complete==true and 0 or 1) or cached and #(cached.unknown or {}) or 0
    if custom then
        local info=ns.API.Item(link)
        if info then local warnings;models,warnings=S.Models({id=id,link=link,info=info},ns.Gear.Facts(link));unknown=#warnings
        else unknown=unknown+1 end
    end
    local scenario=ns.Copy(ns.db.settings.simulation);scenario.combat=ns.Copy(ns.EffectMath.Combat(scenario))
    local values=ns.API.Call("C_Item","GetItemStats",link) or {}
    local spell=ns.Safe(values.ITEM_MOD_SPELL_POWER_SHORT,0)
    scenario.combat.spellPower=scenario.combat.spellPower+spell
    scenario.combat.healingPower=scenario.combat.healingPower+ns.Safe(values.ITEM_MOD_SPELL_HEALING_DONE_SHORT,spell)
    scenario.combat.attackPower=scenario.combat.attackPower+ns.Safe(values.ITEM_MOD_ATTACK_POWER_SHORT,0)
    for _,model in ipairs(models) do local result=S.Effect(model,scenario,profile,{})
        score=score+result.score;if result.unknown then unknown=unknown+1 end
    end
    return score,unknown
end
function S.Prepare(record,profile,scenario,slot)
    local rawProfile=ns.Copy(profile) or {live=true,role=ns.State.role};rawProfile.withoutModels=true
    local evaluation=ns.Gear.Evaluate(record.link or record.info.link,rawProfile);if not evaluation then return end
    local facts=ns.Gear.Facts(record.link or record.info.link)
    local models,unknown=S.Models(record,facts)
    local prepared={record=record,base=evaluation.score,nativeStats=ns.Copy(evaluation.adjusted or evaluation.stats),models=models,unknown=unknown,facts=facts,upper=evaluation.score}
    local physical=(profile and profile.role or ns.State.role)=="melee" or (profile and profile.role or ns.State.role)=="ranged"
    local weight=physical and 1 or 0
    prepared.weapon=record.info.classID==2 and facts.dps and facts.dps*scenario.weaponWeight*weight or 0
    if weight>0 and record.info.classID==2 and not facts.dps then unknown[#unknown+1]=record.info.name..": weapon DPS unavailable" end
    prepared.score=prepared.base+prepared.weapon;prepared.upper=prepared.base+math.max(0,prepared.weapon)
    for _,model in ipairs(models) do local effect=S.Effect(model,scenario,profile,{})
        prepared.score=prepared.score+effect.score;prepared.upper=prepared.upper+math.max(0,effect.score)
        if effect.unknown then unknown[#unknown+1]=record.info.name..": "..effect.unknown end
    end
    local category,maximum=ns.API.Call("C_Item","GetItemUniqueness",record.link or record.id)
    prepared.category,prepared.maximum=ns.Safe(category),ns.Safe(maximum,1)
    prepared.unique=ns.Safe(ns.API.Call("C_Item","GetItemUniquenessByID",record.id))==true
    return prepared
end
function S.SetBonuses(prepared)
    local bonuses={};local seen={}
    local snapshot=ns.EffectMath.Snapshot()
    for _,item in pairs(prepared) do
        local set=item.record.info.setID
        if set and snapshot and snapshot.sets[set] then
            for _,bonus in ipairs(snapshot.sets[set]) do
                local key=set..":"..bonus.threshold..":"..bonus.spell
                if not seen[key] then
                    seen[key]=true
                    bonuses[#bonuses+1]={set=set,threshold=bonus.threshold,models=ns.Copy(bonus.models),unknown=ns.Copy(bonus.unknown),text="Client set spell #"..bonus.spell}
                end
            end
        elseif set then for _,text in ipairs(item.facts.lines or {}) do
            local threshold,description=text:match("^%s*%((%d+)%)%s*[Ss]et:%s*(.+)")
            local key=set..":"..tostring(threshold)
            if threshold and not seen[key] then
                seen[key]=true;local stat,amount
                for name,token in pairs(stats) do
                    local value=description:lower():match("^%+(%d+) "..name.."%.*$") or description:lower():match("^increases your "..name.." by (%d+)%.*$") or description:lower():match("^increases "..name.." by (%d+)%.*$")
                    if value then stat=token;amount=tonumber(value);break end
                end
                bonuses[#bonuses+1]={set=set,threshold=tonumber(threshold),stat=stat,amount=amount,text=description}
            end
        end end
    end
    return bonuses
end
function S.Loadout(loadout,scenario,profile,bonuses)
    local result={score=0,stats=0,damage=0,healing=0,mana=0,unknown={},effects={}};local groups,sets={},{}
    local function addUnknown(text) result.unknown[#result.unknown+1]=text end
    scenario=ns.Copy(scenario);scenario.combat=ns.Copy(ns.EffectMath.Combat(scenario))
    bonuses=bonuses or S.SetBonuses(loadout)
    local scaling,buffs=false,false
    for _,item in pairs(loadout) do
        local set=item.record.info.setID;if set then sets[set]=(sets[set] or 0)+1 end
        local values=item.nativeStats or {}
        local spell=ns.Safe(values.ITEM_MOD_SPELL_POWER_SHORT,0)
        scenario.combat.spellPower=scenario.combat.spellPower+spell
        scenario.combat.healingPower=scenario.combat.healingPower+ns.Safe(values.ITEM_MOD_SPELL_HEALING_DONE_SHORT,spell)
        scenario.combat.attackPower=scenario.combat.attackPower+ns.Safe(values.ITEM_MOD_ATTACK_POWER_SHORT,0)
        for _,model in ipairs(item.models) do
            if (model.spellCoefficient or 0)~=0 or (model.apCoefficient or 0)~=0 then scaling=true end
            if model.kind=="stat" and model.trigger~="passive" then buffs=true end
        end
    end
    for _,bonus in ipairs(bonuses) do if (sets[bonus.set] or 0)>=bonus.threshold then
        local function add(stat,amount)
            if stat=="ITEM_MOD_SPELL_POWER_SHORT" then scenario.combat.spellPower=scenario.combat.spellPower+amount;scenario.combat.healingPower=scenario.combat.healingPower+amount
            elseif stat=="ITEM_MOD_ATTACK_POWER_SHORT" then scenario.combat.attackPower=scenario.combat.attackPower+amount
            elseif stat=="ITEM_MOD_SPELL_HEALING_DONE_SHORT" then scenario.combat.healingPower=scenario.combat.healingPower+amount end
        end
        if bonus.stat then add(bonus.stat,bonus.amount) end
        for _,model in ipairs(bonus.models or {}) do if model.kind=="stat" and model.trigger=="passive" then add(model.stat,model.amount) end end
    end end
    -- Resolve shared activations once, then evaluate output against the same
    -- deterministic buff schedule. Do not average a buff before sampling a cast.
    local scheduled={};local timeline=ns.EffectTimeline.New(scenario.duration)
    scenario.timeline=true
    local function schedule(owner,name,model)
        scheduled[#scheduled+1]={owner=owner,item=name,model=model}
    end
    for _,slot in ipairs(ns.Data.slots) do local item=loadout[slot[1]]
        if item then for _,model in ipairs(item.models) do schedule("item:"..item.record.id,item.record.info.name,model) end end
    end
    for _,bonus in ipairs(bonuses) do if (sets[bonus.set] or 0)>=bonus.threshold then
        for _,model in ipairs(bonus.models or {}) do schedule("set:"..bonus.set..":"..bonus.threshold,"Set #"..bonus.set.." ("..bonus.threshold..")",model) end
    end end
    local schedules,warnings=ns.EffectTimeline.Schedule(scheduled,scenario)
    scenario.scheduledUses=schedules
    for _,warning in ipairs(warnings) do addUnknown(warning) end
    for order,entry in ipairs(scheduled) do
        scenario.effectOrder=order
        local effect=S.Effect(entry.model,scenario,profile,{})
        entry.result=effect
        if entry.model.kind=="stat" and entry.model.trigger~="passive" and not effect.unknown then timeline:Add(entry.model,effect,profile,order) end
    end
    scenario.combat.timeline=timeline
    if scaling and buffs then for _,warning in ipairs(timeline.unknown) do addUnknown(warning) end end
    for _,slot in ipairs(ns.Data.slots) do local item=loadout[slot[1]]
        if item then
            groups._owner=item.record.id
            result.score=result.score+item.base+item.weapon;result.stats=result.stats+item.base
            for _,unknown in ipairs(item.unknown) do addUnknown(unknown) end

        end
    end
    local trinketUses={}
    for _,slot in ipairs({13,14}) do local item=loadout[slot]
        if item then for _,model in ipairs(item.models) do if model.trigger=="use" and (not model.group or model.group=="") then trinketUses[#trinketUses+1]=item.record.id;break end end end
    end
    if #trinketUses>1 then addUnknown("Multiple on-use trinkets have no sourced shared-cooldown group. Review their lockout before treating this score as complete.") end
    for _,bonus in ipairs(bonuses) do if (sets[bonus.set] or 0)>=bonus.threshold then
        if bonus.models then
            for _,text in ipairs(bonus.unknown or {}) do addUnknown("Set #"..bonus.set..": "..text) end
        elseif bonus.stat then result.score=result.score+weighted(bonus.stat,bonus.amount,profile)
        else addUnknown("Set #"..bonus.set.." ("..bonus.threshold.."): "..bonus.text) end
    end end
    for order,entry in ipairs(scheduled) do
        scenario.effectOrder=order
        local model,effect=entry.model,entry.result
        if model.kind~="stat" and not effect.unknown then
            local value,why,raw,ticks=ns.EffectMath.Output(model,scenario,effect.events,effect.uses)
            if why then effect={score=0,unknown=why}
            else
                local weight=model.kind=="damage" and scenario.damageWeight or model.kind=="mana" and scenario.combat.manaWeight or scenario.healingWeight
                effect.value=value;effect.raw=raw;effect.ticks=ticks;effect.score=value*weight
                effect.damage=model.kind=="damage" and value or 0;effect.healing=model.kind=="healing" and value or 0;effect.mana=model.kind=="mana" and value or 0
            end
        end
        entry.result=effect
        result.score=result.score+effect.score
        result.damage=result.damage+(effect.damage or 0);result.healing=result.healing+(effect.healing or 0);result.mana=result.mana+(effect.mana or 0)
        result.effects[#result.effects+1]=entry
        if effect.unknown then addUnknown(entry.item..": "..effect.unknown) end
    end

    return result
end
function S.Legal(loadout,slot,item)
    if not item then return true end
    local record=item.record
    if slot==17 then
        local main=loadout[16];if main and main.record.info.equip=="INVTYPE_2HWEAPON" then return false end
        if record.info.classID==2 and (type(CanDualWield)~="function" or ns.Safe(CanDualWield())~=true) then return false end
    end
    for otherSlot,other in pairs(loadout) do if otherSlot~=slot then
        if record.id==other.record.id and (item.unique or slot==11 and otherSlot==12 or slot==12 and otherSlot==11 or slot==13 and otherSlot==14 or slot==14 and otherSlot==13) then return false end
        if type(item.category)=="number" and item.category~=0 and item.category==other.category then
            local count=1;for key,entry in pairs(loadout) do if key~=slot and entry.category==item.category then count=count+1 end end
            if count>(type(item.maximum)=="number" and item.maximum or 1) then return false end
        end
    end end
    return true
end
function S.CompareLoadout(record,slot,profile)
    profile=profile or ns.Gear.HuntProfile()
    if not ns.Gear.RoleKnown(profile) then return end
    local fingerprint={}
    for _,entry in ipairs(ns.Data.slots) do local current=(ns.State.equipment or {})[entry[1]]
        if current and (current.id or current.link) then
            local id=current.id or type(current.link)=="string" and tonumber(current.link:match("item:(%d+)"))
            fingerprint[#fingerprint+1]=entry[1]..":"..tostring(current.link or current.id)..":"..tostring((ns.API.itemVersions or {})[id] or 0)
        end
    end
    local key=table.concat({table.concat(fingerprint,"|"),ns.State.level or 0,ns.Talents.revision or 0,S.settingsRevision,ns.Gear.ScoringKey(profile)},":")
    local cache=S.comparisonBaseline
    local time=type(GetTime)=="function" and ns.Safe(GetTime()) or 0
    if cache and cache.pending and type(time)=="number" and time-(cache.sampled or 0)>=.5 then cache=nil end
    if not cache or cache.key~=key then
        cache={key=key,loadout={},missing=0,results={},count=0,sampled=type(time)=="number" and time or 0}
        for currentSlot,current in pairs(ns.State.equipment or {}) do if current.id or current.link then
            local info=current.info or ns.API.Item(current.link or current.id)
            local id=current.id or type(current.link)=="string" and tonumber(current.link:match("item:(%d+)"))
            local prepared=info and id and S.Prepare({id=id,link=current.link or info.link,info=info,capEquipped=true},profile,ns.db.settings.simulation,currentSlot)
            if prepared then cache.loadout[currentSlot]=prepared else cache.missing=cache.missing+1 end
        end end
        S.comparisonBaseline=cache
    end
    local candidateKey=slot..":"..tostring(record.link or record.id)..":"..tostring((ns.API.itemVersions or {})[record.id] or 0)
    if cache.results[candidateKey] then return cache.results[candidateKey] end
    local proposed=S.Prepare(record,profile,ns.db.settings.simulation,slot);if not proposed then return end
    local after={};local prepared={proposed}
    for currentSlot,item in pairs(cache.loadout) do after[currentSlot]=item;prepared[#prepared+1]=item end
    after[slot]=proposed
    if slot==16 and record.info.equip=="INVTYPE_2HWEAPON" then after[17]=nil end
    if not S.Legal(after,slot,proposed) then return end
    local bonuses=S.SetBonuses(prepared)
    local before=S.Loadout(cache.loadout,ns.db.settings.simulation,profile,bonuses)
    local result=S.Loadout(after,ns.db.settings.simulation,profile,bonuses)
    local comparison={delta=result.score-before.score,before=before,after=result,partial=cache.missing>0 or #before.unknown>0 or #result.unknown>0}
    if not proposed.facts.pending and cache.missing==0 then
        local pending=false;for _,item in pairs(cache.loadout) do if item.facts.pending then pending=true;break end end
        if not pending then
            if cache.count>=2048 then cache.results={};cache.count=0 end
            cache.results[candidateKey]=comparison;cache.count=cache.count+1
        else cache.pending=true end
    end
    return comparison
end
function S.Cancel() S.job=nil end
function S.Optimize(data,profile,scenario,callback)
    if type(InCombatLockdown)=="function" and InCombatLockdown() then return false,"Run the comparison after combat." end
    profile=profile or ns.Gear.HuntProfile(nil,nil,ns.State.level)
    local valid,reason=S.ValidateScenario(scenario);if not valid then return false,reason end
    if not ns.Gear.RoleKnown(profile) then return false,"Choose a valid build and role before simulating." end
    S.Cancel();local job={nodes=0,best=nil,loadout=nil,prepared={},pools={},scenario=ns.Copy(scenario),profile=ns.Copy(profile),level=profile.level or ns.State.level,settingsRevision=S.settingsRevision,allPools={},uncertain=0,revision=ns.State.revision,itemRevision=ns.State.itemRevision}
    S.job=job
    local slots={16,17,11,12,13,14,1,2,3,5,6,7,8,9,10,15,18};local pins={}
    for _,slot in ipairs(slots) do
        local list=data[slot] or {ranked={},references={}};local pool,seen={},{};local requested
        for _,kind in ipairs({"ranked","references"}) do for _,record in ipairs(list[kind] or {}) do if record.capPreferred then requested=record end end end
        for _,kind in ipairs({"ranked","references"}) do for _,record in ipairs(list[kind] or {}) do
            if not seen[record.id] and record.capUsable and record.capSourceKnown and record.capArmorAllowed~=false then
                seen[record.id]=true
                local item=S.Prepare(record,profile,scenario,slot)
                if item then pool[#pool+1]=item;job.prepared[#job.prepared+1]=item;if #item.unknown>0 then job.uncertain=job.uncertain+1 end;if record.capPreferred then pins[slot]=item end end
            end
        end end
        if requested and not pins[slot] then S.job=nil;return false,"Selected target cannot be simulated yet: "..requested.info.name..". Load its native item data or use an eligible planning level." end
        table.sort(pool,function(a,b) if a.score~=b.score then return a.score>b.score end;return a.record.id<b.record.id end)
        local selected={};for index=1,math.min(math.floor(scenario.perSlot),#pool) do selected[#selected+1]=pool[index] end
        for _,item in ipairs(pool) do if item.record.capEquipped then local found=false;for _,entry in ipairs(selected) do if entry==item then found=true end end;if not found then selected[#selected+1]=item end end end
        if pins[slot] then selected={pins[slot]} end
        job.pools[slot]=selected;job.allPools[slot]=pool
    end
    if pins[16] and pins[16].record.info.equip=="INVTYPE_2HWEAPON" and pins[17] then S.job=nil;return false,"The selected two-handed target conflicts with the off-hand target." end
    local equipped={};job.baselineMissing=0
    for slot,current in pairs(ns.State.equipment or {}) do if current.id or current.link then
        local info=current.info or ns.API.Item(current.link or current.id)
        local id=current.id or type(current.link)=="string" and tonumber(current.link:match("item:(%d+)"))
        local item=info and id and S.Prepare({id=id,info=info,link=current.link or info.link,source="Currently equipped",capEquipped=true},profile,scenario,slot)
        if item then equipped[slot]=item;job.prepared[#job.prepared+1]=item else job.baselineMissing=job.baselineMissing+1 end
    end end
    local bonuses=S.SetBonuses(job.prepared);local setUpper=0;local scoredSets={}
    for _,item in ipairs(job.prepared) do for _,model in ipairs(item.models) do if (model.spellCoefficient or 0)~=0 or (model.apCoefficient or 0)~=0 then job.crossScaling=true end end end
    for _,bonus in ipairs(bonuses) do
        if bonus.stat or bonus.models and #bonus.models>0 then scoredSets[bonus.set]=true end
        for _,model in ipairs(bonus.models or {}) do if (model.spellCoefficient or 0)~=0 or (model.apCoefficient or 0)~=0 then job.crossScaling=true end end
    end
    for slot,pool in pairs(job.allPools) do if not pins[slot] then
        local seen={};for _,item in ipairs(job.pools[slot]) do seen[item.record.id]=true end
        for _,item in ipairs(pool) do if item.record.info.setID and scoredSets[item.record.info.setID] and not seen[item.record.id] then job.pools[slot][#job.pools[slot]+1]=item;seen[item.record.id]=true end end
    end end
    job.baseline=S.Loadout(equipped,scenario,profile,bonuses)
    for _,bonus in ipairs(bonuses) do if bonus.stat then setUpper=setUpper+math.max(0,weighted(bonus.stat,bonus.amount,profile)) end end
    for _,bonus in ipairs(bonuses) do for _,model in ipairs(bonus.models or {}) do setUpper=setUpper+math.max(0,S.Effect(model,scenario,profile,{}).score) end end
    local bounds={};bounds[#slots+1]=0
    for index=#slots,1,-1 do local maximum=0;for _,item in ipairs(job.pools[slots[index]]) do maximum=math.max(maximum,item.upper) end;bounds[index]=bounds[index+1]+maximum end
    local loadout={}
    local thread=coroutine.create(function()
        local function walk(index,upper)
            job.nodes=job.nodes+1
            local elapsed=type(debugprofilestop)=="function" and ns.Safe(debugprofilestop())
            if job.nodes%200==0 or type(elapsed)=="number" and job.deadline and elapsed>=job.deadline then coroutine.yield() end
            if job.nodes>scenario.maxNodes then job.limited=true;return end
            if not job.crossScaling and job.best and upper+bounds[index]+setUpper<job.best.score then return end
            if index>#slots then
                local result=S.Loadout(loadout,scenario,profile,bonuses)
                if not job.best or result.score>job.best.score then job.best=result;job.loadout={};for slot,item in pairs(loadout) do job.loadout[slot]=item end end
                return
            end
            local slot=slots[index];local main=loadout[16]
            if slot==17 and main and main.record.info.equip=="INVTYPE_2HWEAPON" then walk(index+1,upper);return end
            for _,item in ipairs(job.pools[slot]) do if not job.limited and S.Legal(loadout,slot,item) then
                loadout[slot]=item;walk(index+1,upper+item.upper);loadout[slot]=nil
            end end
            if not pins[slot] and not job.limited then walk(index+1,upper) end
        end
        walk(1,0)
    end)
    local function step()
        if S.job~=job then return end
        if InCombatLockdown() then S.job=nil;callback(nil,"Simulation stopped for combat.");return end
        if job.revision~=ns.State.revision or job.itemRevision~=ns.State.itemRevision then S.job=nil;callback(nil,"Item or character data changed. Run the comparison again.");return end
        local start=type(debugprofilestop)=="function" and ns.Safe(debugprofilestop());job.deadline=type(start)=="number" and start+4 or nil
        local ok,error=coroutine.resume(thread)
        if not ok then S.job=nil;callback(nil,tostring(error));return end
        if coroutine.status(thread)=="dead" then S.job=nil;if job.best then callback(job) else callback(nil,job.limited and "Search budget reached before a compatible set was found." or "No compatible set satisfies the selected targets.") end
        else ns.Emit("SIMULATION_PROGRESS",job);C_Timer.After(.01,step) end
    end
    C_Timer.After(0,step);return true
end

function S.Apply(job)
    if not job or not job.best or job.limited then return false,"Finish a complete search before applying its targets." end
    if #job.best.unknown>0 or (job.uncertain or 0)>0 or (job.baselineMissing or 0)>0 or job.baseline and #job.baseline.unknown>0 then return false,"Resolve unmodeled candidate effects and missing item data before applying this set as BiS targets. Individual personal targets remain available." end
    if job.revision~=ns.State.revision or job.itemRevision~=ns.State.itemRevision or job.settingsRevision~=S.settingsRevision then return false,"Character, item or model inputs changed. Run the search again before applying targets." end
    local old=ns.char.gearTargets;local scope=ns.Gear.TargetScope(job.profile)
    ns.char.gearTargets=ns.Copy(old or {});ns.char.gearTargets[scope]=ns.char.gearTargets[scope] or {}
    for slot in pairs(job.loadout) do ns.char.gearTargets[scope][slot]=nil end
    for slot,item in pairs(job.loadout) do
        local ok,why=ns.Gear.SetPersonalTarget(slot,item.record,job.level,job.profile,true)
        if not ok then ns.char.gearTargets=old;ns.Gear.capKey=nil;ns.Gear.cacheKey=nil;return false,why or "A target is no longer eligible; no targets were changed." end
    end
    ns.Emit("STATE_CHANGED");return true
end
ns.Listen("SETTINGS_CHANGED",function() S.settingsRevision=S.settingsRevision+1;S.modelRevision=S.modelRevision+1;S.Cancel() end)
