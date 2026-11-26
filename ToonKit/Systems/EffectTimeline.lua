local addonName, ns = ...
local T={};ns.EffectTimeline=T
local keys={ITEM_MOD_SPELL_POWER_SHORT={"spellPower","healingPower"},ITEM_MOD_SPELL_HEALING_DONE_SHORT={"healingPower"},ITEM_MOD_ATTACK_POWER_SHORT={"attackPower"}}
local Timeline={};Timeline.__index=Timeline
-- All users of a shared lockout compete in chronological order. Reserving
-- every future use of the first trinket would incorrectly starve the second.
function T.Schedule(entries,scenario)
    local actors,byID,uses,unknown={}, {}, {}, {}
    for index,entry in ipairs(entries) do local model=entry.model
        local valid,why=ns.Simulation.ValidateModel(model)
        if not valid then unknown[#unknown+1]=entry.item..": "..why
        elseif model.trigger=="use" then
            uses[index]={}
            local id=model.activation and entry.owner..":"..model.activation or tostring(index)
            local actor=byID[id]
            if not actor then
                actor={indices={},ready=scenario.useDelay,cooldown=model.cooldown,group=model.group,lock=model.sharedCooldown,order=index}
                byID[id]=actor;actors[#actors+1]=actor
            elseif actor.cooldown~=model.cooldown or actor.group~=model.group or actor.lock~=model.sharedCooldown then
                unknown[#unknown+1]="Compound activation has conflicting cooldown components: "..entry.item
            end
            actor.indices[#actor.indices+1]=index
        end
    end
    local groups={};local count=0
    while true do
        local nextActor,nextTime
        for _,actor in ipairs(actors) do
            local time=math.max(actor.ready,actor.group and actor.group~="" and (groups[actor.group] or 0) or 0)
            if time<scenario.duration and (not nextTime or time<nextTime or time==nextTime and actor.order<nextActor.order) then nextActor=actor;nextTime=time end
        end
        if not nextActor then break end
        count=count+1
        if count>4096 then unknown[#unknown+1]="Shared-use timeline exceeds 4096 activations; shorten the scenario.";break end
        for _,index in ipairs(nextActor.indices) do uses[index][#uses[index]+1]=nextTime end
        if type(nextActor.cooldown)~="number" or nextActor.cooldown<=0 then unknown[#unknown+1]="Invalid activation cooldown.";break end
        nextActor.ready=nextTime+nextActor.cooldown
        if nextActor.group and nextActor.group~="" then
            if type(nextActor.lock)~="number" or nextActor.lock<=0 then unknown[#unknown+1]="Missing shared activation lockout.";break end
            groups[nextActor.group]=nextTime+nextActor.lock
        end
    end
    return uses,unknown
end
function T.New(duration)
    return setmetatable({duration=duration,buffs={},unknown={},uncertain={}},Timeline)
end
function Timeline:Add(model,result,profile,order)
    local values={[model.stat]=model.amount}
    if ns.Gear.TalentAdjustments and (not profile or profile.live or profile.ranks and profile.valid) then values=ns.Gear.TalentAdjustments(values,profile) end
    for stat,amount in pairs(values) do
        if not keys[stat] and amount~=0 then self.unknown[#self.unknown+1]="Timed "..stat.." requires class attribute/combat-table modeling before its output interaction is complete." end
        for _,key in ipairs(keys[stat] or {}) do
        if model.trigger~="use" then
            self.uncertain[key]=true
            self.unknown[#self.unknown+1]="Proc stat buff #"..tostring(model.spell or model.stat).." needs a correlated activation timeline for scaling output."
        else
            local windows={}
            for _,time in ipairs(result.uses or {}) do
                local ending=math.min(self.duration,time+model.duration)
                local previous=windows[#windows]
                if previous and time<=previous[2] then previous[2]=math.max(previous[2],ending)
                else windows[#windows+1]={time,ending} end
            end
            self.buffs[#self.buffs+1]={key=key,amount=amount,windows=windows,order=order or 0}
        end
    end end
end
function Timeline:Relevant(model)
    local power=model.kind=="healing" and "healingPower" or "spellPower"
    local relevant={}
    if (model.spellCoefficient or 0)~=0 then relevant[power]=model.spellCoefficient end
    if (model.apCoefficient or 0)~=0 then relevant.attackPower=model.apCoefficient end
    return relevant
end
function Timeline:Extra(model,uses,order)
    local relevant=self:Relevant(model);local found=false
    for key in pairs(relevant) do if self.uncertain[key] then return nil,"Scaling output depends on an unresolved proc stat-buff timeline." end end
    for _,buff in ipairs(self.buffs) do if relevant[buff.key] then found=true;break end end
    if not found then return 0 end
    if model.trigger=="proc" then return nil,"Scaling procs during timed buffs need a correlated event timeline." end
    if model.period then return nil,"Periodic scaling during timed buffs needs sourced snapshot/refresh behavior." end
    local total=0
    for _,buff in ipairs(self.buffs) do local coefficient=relevant[buff.key]
        if coefficient then
            local active=0
            if model.trigger=="passive" then
                for _,window in ipairs(buff.windows) do active=active+window[2]-window[1] end
            else
                for _,time in ipairs(uses or {}) do for _,window in ipairs(buff.windows) do
                    if (time>window[1] or time==window[1] and buff.order<(order or math.huge)) and time<window[2] then active=active+1;break end
                end end
            end
            total=total+buff.amount*coefficient*active/self.duration
        end
    end
    return total
end
