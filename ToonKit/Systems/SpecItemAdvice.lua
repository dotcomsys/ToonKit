local addonName, ns = ...
local A={};ns.SpecItemAdvice=A
local schoolBits={2,4,8,16,32,64}
local schoolSpecs={WARLOCK={Affliction={32},Demonology={4,32},Destruction={4}},PRIEST={Shadow={32},Holy={2},Discipline={2}},DRUID={Balance={8,64}},SHAMAN={Elemental={4,8,16}}}
local function has(mask,bit) return type(mask)=="number" and math.floor(mask/bit)%2==1 end
local function clean(text) return type(text)=="string" and text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","") or "" end
local function profile()
    local T=ns.Talents;local top,total,second=1,0,0
    for index,value in ipairs(T.totals or {}) do total=total+value;if value>(T.totals[top] or 0) then top=index end end
    for index,value in ipairs(T.totals or {}) do if index~=top then second=math.max(second,value) end end
    local tree=T.Definitions()[top];local role=(ns.Data.treeRoles[ns.State.class] or {})[top]
    local valid=T.available and T.nativeDefinitions and T.mismatches==0 and total>0 and tree~=nil
    local schools={}
    local name=tree and tree.name
    for _,bit in ipairs(schoolBits) do
        local label=ns.Safe(ns.API.Call("C_Spell","GetSchoolString",bit))
        if type(label)=="string" and name and label:lower()==name:lower() then schools={bit};break end
    end
    if #schools==0 then schools=(schoolSpecs[ns.State.class] or {})[name or ""] or {} end
    local hybrid=total>0 and second>0 and (T.totals[top] or 0)==second
    -- A clear primary tree stays primary even with utility points elsewhere.
    -- Only equal leading allocations require multi-school/tied-role handling.
    if hybrid then
        local union={};for _,bit in ipairs(schools) do union[bit]=true end
        for index,value in ipairs(T.totals) do if value==T.totals[top] and value>0 then
            if (ns.Data.treeRoles[ns.State.class] or {})[index]~=role then valid=false end
            local other=T.Definitions()[index];local found=(schoolSpecs[ns.State.class] or {})[other and other.name or ""]
            if ns.State.class=="MAGE" and other then for _,bit in ipairs(schoolBits) do
                if ns.Safe(ns.API.Call("C_Spell","GetSchoolString",bit))==other.name then found={bit};break end
            end end
            for _,bit in ipairs(found or {}) do union[bit]=true end
        end end
        schools={};for _,bit in ipairs(schoolBits) do if union[bit] then schools[#schools+1]=bit end end
    end
    return {role=role,tree=tostring(top),name=hybrid and "Hybrid "..(name or "") or name,schools=schools,valid=valid,live=true,nativeOnly=true,withoutModels=true,level=ns.State.level}
end
function A.Profile()
    local key=table.concat({ns.Talents.revision or 0,ns.State.level or 0,ns.State.class or ""},":")
    if A.profileKey~=key then A.profileKey=key;A.profile=profile() end
    return A.profile
end
local function snapshot()
    local _,build=GetBuildInfo();return (ns.Data.foreverAdviceFacts or {})[tostring(ns.Safe(build))]
end
local function schoolLine(text)
    local lower=clean(text):lower()
    local names,amount=lower:match("^equip: increases damage done by ([%a ]+) spells and effects by up to (%d+)%.?$")
    if not names then amount,names=lower:match("^equip: %+(%d+) ([%a ]+) damage%.?$") end
    if not names then return end
    local mask=0
    for _,bit in ipairs(schoolBits) do
        local label=ns.Safe(ns.API.Call("C_Spell","GetSchoolString",bit))
        if type(label)=="string" and names:find(label:lower(),1,true) then mask=mask+bit end
    end
    if mask>0 then return mask,tonumber(amount) end
end
local function represented(text,stats)
    local map={strength="ITEM_MOD_STRENGTH_SHORT",agility="ITEM_MOD_AGILITY_SHORT",stamina="ITEM_MOD_STAMINA_SHORT",intellect="ITEM_MOD_INTELLECT_SHORT",spirit="ITEM_MOD_SPIRIT_SHORT",["attack power"]="ITEM_MOD_ATTACK_POWER_SHORT",["spell power"]="ITEM_MOD_SPELL_POWER_SHORT",["damage and healing done by magical spells and effects"]="ITEM_MOD_SPELL_POWER_SHORT"}
    local lower=clean(text):lower()
    local enchant=lower:match("^enchanted: (.+)$")
    if enchant then
        local known={strength="ITEM_MOD_STRENGTH_SHORT",agility="ITEM_MOD_AGILITY_SHORT",stamina="ITEM_MOD_STAMINA_SHORT",intellect="ITEM_MOD_INTELLECT_SHORT",spirit="ITEM_MOD_SPIRIT_SHORT",armor="RESISTANCE0_NAME"}
        local count=0;local remaining=enchant
        while remaining do
            local piece,tail=remaining:match("^(.-) and (.+)$")
            piece=piece or remaining;remaining=tail
            local name,amount=piece:match("^([%a ]+) %+(%d+)$")
            if not name then amount,name=piece:match("^%+(%d+) ([%a ]+)$") end
            local key=name and known[name];local native=key and ns.Safe(stats[key])
            if not key or type(native)~="number" or native<tonumber(amount) then return false end
            count=count+1
        end
        return count>0
    end
    local checks={
        {"^equip: improves your chance to get a critical strike with spells by (%d+%.?%d*)%%%.?$",{"ITEM_MOD_CRIT_SPELL_RATING_SHORT","ITEM_MOD_CRIT_RATING_SHORT"}},
        {"^equip: increases your chance to get a critical strike with spells by (%d+%.?%d*)%%%.?$",{"ITEM_MOD_CRIT_SPELL_RATING_SHORT","ITEM_MOD_CRIT_RATING_SHORT"}},
        {"^equip: improves your chance to get a critical strike by (%d+%.?%d*)%%%.?$",{"ITEM_MOD_CRIT_RATING_SHORT"}},
        {"^equip: improves your chance to hit with spells by (%d+%.?%d*)%%%.?$",{"ITEM_MOD_HIT_SPELL_RATING_SHORT","ITEM_MOD_HIT_RATING_SHORT"}},
        {"^equip: improves your chance to hit by (%d+%.?%d*)%%%.?$",{"ITEM_MOD_HIT_RATING_SHORT"}},
        {"^equip: restores (%d+) mana per 5 sec%.?$",{"ITEM_MOD_MANA_REGENERATION_SHORT"}},
        {"^equip: increases healing done by spells and effects by up to (%d+)%.?$",{"ITEM_MOD_SPELL_HEALING_DONE_SHORT"}},
    }
    for _,check in ipairs(checks) do
        local amount=lower:match(check[1])
        if amount then for _,key in ipairs(check[2]) do if ns.Safe(stats[key])==tonumber(amount) then return true end end end
    end
    for name,key in pairs(map) do
        local amount=lower:match("^equip: increases "..name.." by up to (%d+)%.?$") or lower:match("^equip: increases "..name.." by (%d+)%.?$") or lower:match("^equip: increases your "..name.." by (%d+)%.?$")
        local value=ns.Safe(stats[key])
        if value==nil and name=="damage and healing done by magical spells and effects" then
            value=ns.Safe(stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT)
        end
        if amount and type(value)=="number" and value>=tonumber(amount) then return true end
    end
    return false
end
local function native(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b,c=pcall(fn,...)
    if ok then return ns.Safe(a),ns.Safe(b),ns.Safe(c) end
end
local function buffUptime(rate,icd,duration)
    if not duration or duration<=0 then return 0 end
    if duration<=icd then return duration*rate/(1+rate*icd) end
    return (rate*icd+1-math.exp(-rate*(duration-icd)))/(1+rate*icd)
end
local function ownBuffPower(model,index,models,atTime,liveBuffs)
    local spell,attack=0,0
    for otherIndex,buff in ipairs(models or {}) do
        if buff.activation==model.activation and buff.trigger==model.trigger and (buff.kind=="stat" or buff.kind=="schoolDamage") and buff.trigger~="passive" then
            local active=0
            if atTime>0 then active=atTime<(buff.duration or 0) and 1 or 0
            elseif otherIndex<index then active=1
            elseif model.trigger=="proc" and (model.ppm or 0)>0 then active=1-math.exp(-(model.ppm/60)*math.max(0,(buff.duration or 0)-(model.icd or 0)))
            elseif model.trigger=="use" and (buff.duration or 0)>math.max(model.cooldown or math.huge,model.group and (model.sharedCooldown or 0) or 0) then active=1 end
            -- Native character power already includes any currently active copy.
            active=active-(liveBuffs and liveBuffs[buff.spell] and 1 or 0)
            if model.kind=="damage" and buff.kind=="schoolDamage" and has(buff.mask,model.school) or buff.stat=="ITEM_MOD_SPELL_POWER_SHORT" or model.kind=="healing" and buff.stat=="ITEM_MOD_SPELL_HEALING_DONE_SHORT" then spell=spell+buff.amount*active end
            if buff.stat=="ITEM_MOD_ATTACK_POWER_SHORT" then attack=attack+buff.amount*active end
            if (model.apCoefficient or 0)~=0 and (buff.stat=="ITEM_MOD_STRENGTH_SHORT" or buff.stat=="ITEM_MOD_AGILITY_SHORT") then
                liveBuffs=liveBuffs or {};liveBuffs.attackConversions=liveBuffs.attackConversions or {}
                local key=buff.stat..":"..buff.amount;local value=liveBuffs.attackConversions[key]
                if value==nil then value=native(GetAttackPowerForStat,buff.stat=="ITEM_MOD_STRENGTH_SHORT" and 1 or 2,buff.amount);liveBuffs.attackConversions[key]=type(value)=="number" and value or false end
                if type(value)~="number" then return nil,nil,"Native temporary attribute conversion is unreadable" end
                attack=attack+value*active
            end
        end
    end
    return spell,attack
end
local function output(model,events,index,models,liveBuffs)
    local amount=model.amount;local spRate,apRate=0,0
    local terms=model.period and type(model.period)=="number" and model.period>0 and math.floor((model.duration or 0)/model.period+.00000001) or 1
    if (terms+(model.period and 1 or 0))*(#(models or {}))^2>4096 then return nil,"Correlation exceeds the bounded item-advice budget" end
    if (model.projectileSpeed or 0)>0 and ((model.spellCoefficient or 0)~=0 or (model.apCoefficient or 0)~=0) then
        for _,buff in ipairs(models or {}) do if buff.activation==model.activation and buff.trigger==model.trigger and (buff.kind=="stat" or buff.kind=="schoolDamage") and buff.trigger~="passive" then
            return nil,"Projectile/buff correlation needs the impact timing"
        end end
    end
    local launch=model.launchDelay or 0
    local ticks=1;local spellBuff,attackBuff,buffError=ownBuffPower(model,index,models,launch,liveBuffs)
    if buffError then return nil,buffError end
    if model.period then
        if type(model.period)~="number" or model.period<=0 then return nil,"Periodic timing is invalid" end
        ticks=math.floor((model.duration or 0)/model.period+.00000001)
        if model.trigger=="proc" and (model.icd or 0)<(model.duration or 0) then
            if (model.icd or 0)>0 then return nil,"Periodic refresh needs a non-overlap model" end
            local rate=model.ppm and model.ppm/60
            if not rate then return nil,"Periodic refresh rate is unavailable" end
            if ticks>256 then return nil,"Periodic refresh exceeds the bounded advice budget" end
            ticks=0
            for i=1,math.floor((model.duration or 0)/model.period+.00000001) do ticks=ticks+math.exp(-rate*i*model.period) end
        end
    end
    if model.period and ticks>0 then
        if ticks>256 then return nil,"Periodic correlation exceeds the bounded advice budget" end
        local sumSpell,sumAttack,weight=0,0,0
        local rate=model.trigger=="proc" and (model.ppm or 0)/60 or 0
        for i=1,math.floor((model.duration or 0)/model.period+.00000001) do
            local at=i*model.period;local chance=model.trigger=="proc" and (model.icd or 0)==0 and math.exp(-rate*at) or 1
            local sp,ap,why=ownBuffPower(model,index,models,launch+at,liveBuffs)
            if why then return nil,why end
            sumSpell=sumSpell+sp*chance;sumAttack=sumAttack+ap*chance;weight=weight+chance
        end
        if weight>0 then spellBuff=sumSpell/weight;attackBuff=sumAttack/weight end
    end
    if (model.spellCoefficient or 0)~=0 then
        local power
        if model.kind=="healing" then power=native(GetSpellBonusHealing)
        else for index,bit in ipairs({1,2,4,8,16,32,64}) do if model.school==bit then power=native(GetSpellBonusDamage,index);break end end end
        if type(power)~="number" then return nil,"Native spell scaling is unreadable" end
        amount=amount+(power+spellBuff)*model.spellCoefficient;spRate=model.spellCoefficient*events*ticks
    end
    if (model.apCoefficient or 0)~=0 then
        local base,positive,negative=native(UnitAttackPower,"player")
        if type(base)~="number" or type(positive)~="number" or type(negative)~="number" then return nil,"Native attack-power scaling is unreadable" end
        amount=amount+(base+positive+negative+attackBuff)*model.apCoefficient;apRate=model.apCoefficient*events*ticks
    end
    return amount*events*ticks,nil,{kind=model.kind,school=model.school,spell=spRate,attack=apRate}
end
function A.SharedClear(group,slot,model,id,removeOffhand)
    if not slot or not C_Item or type(C_Item.GetItemSpell)~="function" then return false end
    local revision=tostring(ns.State.inventoryRevision or 0)..":"..tostring(ns.State.itemRevision or 0)
    if A.useRevision~=revision then A.useRevision=revision;A.useCache={} end
    local key=table.concat({slot,group,id or 0,tostring(removeOffhand==true)},":")
    if A.useCache[key]~=nil then return A.useCache[key] end
    local data=snapshot();local actors,seen={},{}
    local function add(owner,entry)
        if not entry or #(entry.unknown or {})>0 or #(entry.models or {})>64 then return false end
        for _,effect in ipairs(entry.models or {}) do if effect.trigger=="use" and effect.group==group then
            local scaling=(effect.spellCoefficient or 0)~=0 or (effect.apCoefficient or 0)~=0
            local actorKey=owner..":"..tostring(effect.activation or effect.spell)
            local cooldown=math.max(effect.cooldown or 0,effect.sharedCooldown or 0)
            local lock=effect.sharedCooldown
            if cooldown<=0 or type(lock)~="number" or lock<=0 then return false end
            local previous=seen[actorKey]
            if previous and (previous.cooldown~=cooldown or previous.lock~=lock) then return false end
            if not previous then
                local actor={cooldown=cooldown,lock=lock,scaling=scaling};seen[actorKey]=actor;actors[#actors+1]=actor
                if #actors>2 then return false end
            elseif scaling then previous.scaling=true end
        end end
        return true
    end
    if not add(slot,data and data.items[id]) then return false end
    for otherSlot,item in pairs(ns.State.equipment) do if otherSlot~=slot and not (removeOffhand and otherSlot==17) and item.id then
        local name,spell=ns.API.Call("C_Item","GetItemSpell",item.link or item.id)
        if type(issecretvalue)=="function" and (issecretvalue(name) or issecretvalue(spell)) then return false,true end
        name,spell=ns.Safe(name),ns.Safe(spell)
        if name and not spell or ns.API.errors["C_Item.GetItemSpell"] then return false,true end
        if spell and not add(otherSlot,data and data.items[item.id]) then return false end
    end end
    local feasible=#actors==1
    if #actors==2 then
        local first,second=actors[1],actors[2]
        if first.scaling or second.scaling then return false end
        local x,y=math.floor(first.cooldown*1000+.5),math.floor(second.cooldown*1000+.5)
        for i=1,32 do if y==0 then break end;x,y=y,x%y end
        -- Two periodic uses can be phased without reducing either frequency
        -- when their lock windows fit between the common activation lattice.
        feasible=y==0 and x>=math.ceil((first.lock+second.lock)*1000-.00001)
    end
    A.useCache[key]=feasible;return feasible
end
function A.Effects(id,link,profile,slot)
    local revision=table.concat({ns.State.inventoryRevision or 0,ns.State.itemRevision or 0,ns.Talents.revision or 0,profile.role or ""},":")
    if A.effectRevision~=revision then A.effectRevision=revision;A.effectCache={};A.effectCount=0 end
    local effectKey=link..":"..tostring(slot or "")
    local cached=A.effectCache[effectKey];if cached then return cached end
    local facts=ns.Gear.Facts(link);local values=ns.API.Call("C_Item","GetItemStats",link) or {}
    local result={schools={},stat=0,damage=0,healing=0,mana=0,unknown={},notes={},scaling={},pending=facts.pending}
    local weights=ns.Gear.Weights(profile);local data=snapshot();local entry=data and data.items[id]
    local itemInfo=ns.API.Item(link);local removeOffhand=slot==16 and itemInfo and itemInfo.equip=="INVTYPE_2HWEAPON"
    local nativeSchool=false;local other={}
    for _,text in ipairs(facts.effects or {}) do
        local mask,amount=schoolLine(text)
        if mask then
            nativeSchool=true
            for _,bit in ipairs(schoolBits) do if has(mask,bit) then result.schools[bit]=(result.schools[bit] or 0)+amount end end
        elseif not clean(text):lower():match("^%s*%(%d+%)%s*set:") and not clean(text):lower():match("^set:") and not represented(text,values) then other[#other+1]=text end
    end
    if facts.pending then result.unknown[#result.unknown+1]="Native effect details are loading" end
    -- Set membership and threshold changes are compared across equipped slots below.
    local models=entry and entry.models or {}
    if #models>64 then result.unknown[1]="Effect bundle exceeds the bounded advice budget";return result end
    if entry then
        for _,why in ipairs(entry.unknown or {}) do
            local spell=why:match("^Spell #(%d+) effect 6/aura %d+ needs a specific model$")
            local description=spell and ns.Safe(ns.API.Call("C_Spell","GetSpellDescription",tonumber(spell)))
            -- Numeric import omissions for ordinary passive stats are covered only
            -- by a full native description and matching native stat units.
            local covered=type(description)=="string" and represented("Equip: "..description,values)
            if not covered then result.unknown[#result.unknown+1]=why end
        end
    elseif #other>0 or facts.useSpell then
        result.unknown[#result.unknown+1]="No complete numeric effect model for this item on your Forever build"
    end
    local hasTemporaryStats,hasScaling=false,false
    for _,model in ipairs(models) do
        if (model.kind=="stat" or model.kind=="schoolDamage") and model.trigger~="passive" then hasTemporaryStats=true end
        if (model.spellCoefficient or 0)~=0 or (model.apCoefficient or 0)~=0 then hasScaling=true end
    end
    local liveBuffs={}
    if hasScaling then result.volatile=true end
    if hasTemporaryStats and hasScaling then
        result.volatile=true
        if not C_UnitAuras or type(C_UnitAuras.GetPlayerAuraBySpellID)~="function" then
            result.unknown[#result.unknown+1]="Native temporary-buff state is unavailable"
        else for _,buff in ipairs(models) do if (buff.kind=="stat" or buff.kind=="schoolDamage") and buff.trigger~="passive" and buff.spell and liveBuffs[buff.spell]==nil then
            local aura=ns.API.Call("C_UnitAuras","GetPlayerAuraBySpellID",buff.spell)
            if type(issecretvalue)=="function" and issecretvalue(aura) or ns.API.errors["C_UnitAuras.GetPlayerAuraBySpellID"] then
                result.unknown[#result.unknown+1]="Native temporary-buff state is unreadable";result.pending=true
            else liveBuffs[buff.spell]=aura~=nil end
        end end end
        for _,outputModel in ipairs(models) do if (outputModel.spellCoefficient or 0)~=0 or (outputModel.apCoefficient or 0)~=0 then
            for _,buff in ipairs(models) do if (buff.kind=="stat" or buff.kind=="schoolDamage") and buff.trigger~="passive" and buff.activation~=outputModel.activation then
                result.unknown[#result.unknown+1]="Cross-activation buff correlation is not specified";break
            end end
        end end
    end
    for modelIndex,model in ipairs(models) do
        local active,events=1,0;local covered=true
        if (model.kind=="stat" or model.kind=="schoolDamage") and model.trigger~="passive" and (model.duration or 0)<=0 then
            covered=false;result.unknown[#result.unknown+1]="Temporary stat duration is not specified"
        end
        if model.trigger=="use" then
            local clear,waiting=true,false
            if model.group then clear,waiting=A.SharedClear(model.group,slot,model,id,removeOffhand) end
            if waiting then result.pending=true end
            if model.cooldown and model.cooldown>0 and clear then
                local cooldown=math.max(model.cooldown,model.group and (model.sharedCooldown or 0) or 0)
                active=math.min(1,(model.duration or 0)/cooldown);events=1/cooldown
            else covered=false;result.unknown[#result.unknown+1]="Shared on-use cooldown needs a loadout schedule" end
        elseif model.trigger=="proc" then
            -- Never invent a swing/cast/hit rate from specialization alone.
            local rate=model.ppm and model.ppm/60
            local compatible=model.event=="melee" and (profile.role=="melee" or profile.role=="tank") or model.event=="ranged" and (profile.role=="ranged" or profile.role=="caster" and slot==18) or model.event=="spell" and (profile.role=="caster" or profile.role=="healer")
            if model.rateCondition then
                covered=false;result.unknown[#result.unknown+1]=model.rateCondition
            elseif model.rateExcludeFeral and ns.State.class=="DRUID" and (profile.role=="melee" or profile.role=="tank") then
                covered=false;result.unknown[#result.unknown+1]="The published weapon-rate measurement excludes feral forms"
            elseif rate and rate>0 and compatible then
                local icd=model.icd or 0;events=rate/(1+rate*icd)
                active=buffUptime(rate,icd,model.duration or 0)
            elseif model.event=="melee" and (profile.role=="caster" or profile.role=="healer") then
                covered=false;result.notes[#result.notes+1]="Melee-only proc excluded from the casting/healing comparison"
            else covered=false;result.unknown[#result.unknown+1]="Proc rate needs eligible events for this build; no hit/cast cadence is invented" end
        end
        if model.kind=="schoolDamage" then
            if model.trigger=="passive" then
                if not nativeSchool then covered=false;result.unknown[#result.unknown+1]="School damage is not corroborated by the native item tooltip" end
            elseif covered then
                for _,bit in ipairs(schoolBits) do if has(model.mask,bit) then result.schools[bit]=(result.schools[bit] or 0)+model.amount*active end end
            end
        elseif model.kind=="stat" then
            if model.trigger=="passive" then
                if type(ns.Safe(values[model.stat]))~="number" or ns.Safe(values[model.stat])<model.amount then
                    covered=false;result.unknown[#result.unknown+1]="Passive stat is not corroborated by native item stats"
                end
            elseif covered then result.stat=result.stat+model.amount*active*(weights[model.stat] or 0) end
        elseif covered then
            if model.kind=="damage" or model.kind=="healing" or model.kind=="mana" then
                local value,why,scaling=output(model,events,modelIndex,models,liveBuffs)
                if value then result[model.kind]=result[model.kind]+value;result.scaling[#result.scaling+1]=scaling
                else covered=false;result.unknown[#result.unknown+1]=why;if why:find("unreadable",1,true) then result.pending=true end end
            else covered=false;result.unknown[#result.unknown+1]="Unsupported effect model" end
        end
        if model.rateConfidence then result.rateConfidence=result.rateConfidence=="observed" and "observed" or model.rateConfidence end
        if covered and model.trigger~="passive" then result.notes[#result.notes+1]=string.format("Spell #%d: sourced %s, expected sustained contribution",model.spell or 0,model.trigger) end
    end
    if not result.pending and not result.volatile then
        if A.effectCount>=96 then A.effectCache={};A.effectCount=0 end
        A.effectCount=A.effectCount+1;A.effectCache[effectKey]=result
    end
    return result
end
function A.SetDelta(info,slot,profile,offhand)
    local current=ns.State.equipment[slot];local oldSet=current and current.info and current.info.setID or 0;local newSet=info.setID or 0
    local result={points=0,schools={},unknown={}}
    if current and current.id and not current.info then result.unknown[1]="Equipped set metadata is loading";return result end
    local offSet=offhand and offhand.info and offhand.info.setID or 0
    if offhand and offhand.id and not offhand.info then result.unknown[1]="Off-hand set metadata is loading";return result end
    if oldSet==newSet and offSet==0 then return result end
    local counts={};local complete=true
    for _,item in pairs(ns.State.equipment) do if item.id then
        if not item.info then complete=false else local set=item.info.setID;if set and set~=0 then counts[set]=(counts[set] or 0)+1 end end
    end end
    if not complete then result.unknown[1]="Equipped set membership is loading";return result end
    local data=snapshot();local weights=ns.Gear.Weights(profile);local seen={}
    for _,set in ipairs({oldSet,newSet,offSet}) do if set~=0 and not seen[set] then
        seen[set]=true;local before=counts[set] or 0;local after=before+(set==newSet and 1 or 0)-(set==oldSet and 1 or 0)-(set==offSet and 1 or 0)
        local bonuses=data and data.sets[set]
        if not bonuses then result.unknown[#result.unknown+1]="Set thresholds are unavailable for this Forever build"
        else for _,bonus in ipairs(bonuses) do
            local change=(after>=bonus.threshold and 1 or 0)-(before>=bonus.threshold and 1 or 0)
            if change~=0 then
                for _,why in ipairs(bonus.unknown or {}) do result.unknown[#result.unknown+1]=why end
                for _,model in ipairs(bonus.models or {}) do
                    if model.trigger=="passive" and model.kind=="stat" then result.points=result.points+change*model.amount*(weights[model.stat] or 0)
                    elseif model.trigger=="passive" and model.kind=="schoolDamage" then for _,bit in ipairs(schoolBits) do if has(model.mask,bit) then result.schools[bit]=(result.schools[bit] or 0)+change*model.amount end end
                    else result.unknown[#result.unknown+1]="Set effect needs its trigger model" end
                end
            end
        end end
    end end
    return result
end
function A.Compare(id,link,wantedSlot,profile)
    profile=profile or A.Profile()
    if not profile.valid or not ns.Gear.RoleKnown(profile) then return {kind="manual",text="Keep until your live talent allocation is readable",reason="ToonKit detects native Forever talents automatically; no Classic build fallback is used."} end
    local info=ns.API.Item(link or id);if not info then return {kind="pending",text="Loading item data"} end
    link=link or info.link
    if not link then return {kind="pending",text="Loading exact item variant"} end
    local removedOffhand=info.equip=="INVTYPE_2HWEAPON" and ns.State.equipment[17]
    if removedOffhand and removedOffhand.id and (not removedOffhand.link or not removedOffhand.info or type(ns.API.Call("C_Item","GetItemStats",removedOffhand.link))~="table") then return {kind="pending",text="Loading off-hand comparison data"} end
    local best
    for _,slot in ipairs(ns.Data.equipSlots[info.equip] or {}) do if not wantedSlot or wantedSlot==slot then
        local record={id=id,info=info,link=link}
        if ns.Gear.EquipCheck(record,slot)==true then
            local proposed=A.Effects(id,link,profile,slot)
            local current=ns.State.equipment[slot]
            local currentLink=current and (current.link or current.info and current.info.link)
            local base=ns.Gear.Compare(record,slot,profile)
            if base then
                local prior=current and current.id and currentLink and A.Effects(current.id,currentLink,profile,slot) or {schools={},stat=0,damage=0,healing=0,mana=0,unknown={},notes={},scaling={}}
                if removedOffhand and removedOffhand.id then
                    prior=ns.Copy(prior)
                    local lost=A.Effects(removedOffhand.id,removedOffhand.link,profile,17)
                    for _,key in ipairs({"stat","damage","healing","mana"}) do prior[key]=(prior[key] or 0)+(lost[key] or 0) end
                    for bit,value in pairs(lost.schools) do prior.schools[bit]=(prior.schools[bit] or 0)+value end
                    for _,why in ipairs(lost.unknown) do prior.unknown[#prior.unknown+1]="Off-hand: "..why end
                    prior.pending=prior.pending or lost.pending;prior.volatile=prior.volatile or lost.volatile
                    if lost.rateConfidence=="observed" then prior.rateConfidence="observed" end
                end
                local setChange=A.SetDelta(info,slot,profile,removedOffhand)
                local delta=base.delta+proposed.stat-prior.stat+setChange.points
                if profile.role=="healer" then
                    local new=ns.API.Call("C_Item","GetItemStats",link) or {};local old=currentLink and ns.API.Call("C_Item","GetItemStats",currentLink) or {}
                    if removedOffhand and removedOffhand.link then
                        old=ns.Copy(old or {});for key,value in pairs(ns.API.Call("C_Item","GetItemStats",removedOffhand.link) or {}) do
                            value=ns.Safe(value);if type(value)=="number" then old[key]=ns.Safe(old[key],0)+value end
                        end
                    end
                    local extra=math.max(0,ns.Safe(new.ITEM_MOD_SPELL_HEALING_DONE_SHORT,0)-ns.Safe(new.ITEM_MOD_SPELL_POWER_SHORT,0))-math.max(0,ns.Safe(old.ITEM_MOD_SPELL_HEALING_DONE_SHORT,0)-ns.Safe(old.ITEM_MOD_SPELL_POWER_SHORT,0))
                    delta=delta+extra*(ns.Gear.Weights(profile).ITEM_MOD_SPELL_POWER_SHORT or 0)
                end
                local low,high=delta,delta;local schoolNotes={}
                local schoolUnknown=false
                if profile.role=="caster" and #profile.schools>0 then
                    low,high=math.huge,-math.huge
                    for _,bit in ipairs(profile.schools) do
                        local change=(proposed.schools[bit] or 0)-(prior.schools[bit] or 0)+(setChange.schools[bit] or 0)
                        local value=delta+change*(ns.Gear.Weights(profile).ITEM_MOD_SPELL_POWER_SHORT or 0)
                        low=math.min(low,value);high=math.max(high,value)
                        schoolNotes[#schoolNotes+1]=string.format("%s damage %+.0f",ns.Safe(ns.API.Call("C_Spell","GetSchoolString",bit),"School "..bit),change)
                    end
                elseif next(proposed.schools) or next(prior.schools) or next(setChange.schools) then
                    schoolUnknown=profile.role=="caster"
                end
                local unknown=#proposed.unknown+#prior.unknown+#setChange.unknown+(schoolUnknown and 1 or 0)
                local replacedBuffActive=false
                if #(proposed.scaling or {})>0 then
                    local data=snapshot();local inspected={}
                    for _,old in ipairs({current or {},removedOffhand or {}}) do if old.id and old.id~=id then
                        local source=data and data.items[old.id]
                        for _,buff in ipairs(source and source.models or {}) do if buff.trigger~="passive" and (buff.kind=="stat" or buff.kind=="schoolDamage") and buff.spell and not inspected[buff.spell] then
                            inspected[buff.spell]=true
                            if not C_UnitAuras or type(C_UnitAuras.GetPlayerAuraBySpellID)~="function" then replacedBuffActive=true
                            else
                                local aura=ns.API.Call("C_UnitAuras","GetPlayerAuraBySpellID",buff.spell)
                                if type(issecretvalue)=="function" and issecretvalue(aura) or aura~=nil or ns.API.errors["C_UnitAuras.GetPlayerAuraBySpellID"] then replacedBuffActive=true end
                            end
                        end end
                    end end
                    if replacedBuffActive then unknown=unknown+1 end
                end
                local scaled={damage=0,healing=0,mana=0}
                local newStats=ns.API.Call("C_Item","GetItemStats",link) or {}
                local oldStats=currentLink and ns.API.Call("C_Item","GetItemStats",currentLink) or {}
                if removedOffhand and removedOffhand.link then
                    oldStats=ns.Copy(oldStats or {});for key,value in pairs(ns.API.Call("C_Item","GetItemStats",removedOffhand.link) or {}) do
                        value=ns.Safe(value);if type(value)=="number" then oldStats[key]=ns.Safe(oldStats[key],0)+value end
                    end
                end
                local spellDelta=ns.Safe(newStats.ITEM_MOD_SPELL_POWER_SHORT,0)-ns.Safe(oldStats.ITEM_MOD_SPELL_POWER_SHORT,0)
                local apDelta=ns.Safe(newStats.ITEM_MOD_ATTACK_POWER_SHORT,0)-ns.Safe(oldStats.ITEM_MOD_ATTACK_POWER_SHORT,0)
                for index,key in ipairs({"ITEM_MOD_STRENGTH_SHORT","ITEM_MOD_AGILITY_SHORT"}) do
                    local after=native(GetAttackPowerForStat,index,ns.Safe(newStats[key],0))
                    local before=native(GetAttackPowerForStat,index,ns.Safe(oldStats[key],0))
                    if type(after)=="number" and type(before)=="number" then apDelta=apDelta+after-before end
                end
                for _,term in ipairs(proposed.scaling or {}) do
                    local power=spellDelta+(proposed.schools[term.school] or 0)-(prior.schools[term.school] or 0)
                    if term.kind=="healing" then power=math.max(ns.Safe(newStats.ITEM_MOD_SPELL_HEALING_DONE_SHORT,0),ns.Safe(newStats.ITEM_MOD_SPELL_POWER_SHORT,0))-math.max(ns.Safe(oldStats.ITEM_MOD_SPELL_HEALING_DONE_SHORT,0),ns.Safe(oldStats.ITEM_MOD_SPELL_POWER_SHORT,0)) end
                    scaled[term.kind]=scaled[term.kind]+power*term.spell+apDelta*term.attack
                end
                local dps=profile.role~="healer" and proposed.damage-prior.damage+scaled.damage or 0
                local healing=profile.role=="healer" and proposed.healing-prior.healing+scaled.healing or 0
                local mana=(profile.role=="caster" or profile.role=="healer") and proposed.mana-prior.mana+scaled.mana or 0
                local positive=low>=0 and dps>=0 and healing>=0 and mana>=0 and (low>0 or dps>0 or healing>0 or mana>0)
                local negative=high<=0 and dps<=0 and healing<=0 and mana<=0
                local weaponUnknown=false;local weaponDelta=0
                if info.classID==2 and (profile.role=="melee" or profile.role=="ranged" or profile.role=="tank" or slot==18) then
                    local new=ns.Gear.Facts(link);local old=currentLink and ns.Gear.Facts(currentLink)
                    if not old then
                        if current and current.id then weaponUnknown=true
                        elseif type(new.dps)=="number" then weaponDelta=new.dps else weaponUnknown=true end
                    elseif current.info and info.subID==current.info.subID and type(new.dps)=="number" and type(old.dps)=="number" and new.speed==old.speed and type(new.speed)=="number" then weaponDelta=new.dps-old.dps
                    else weaponUnknown=true end
                end
                if weaponUnknown then unknown=unknown+1 end
                positive=positive and weaponDelta>=0 or low>=0 and dps>=0 and healing>=0 and mana>=0 and weaponDelta>0
                negative=negative and weaponDelta<=0
                local kind=unknown>0 and "compare" or positive and "upgrade" or negative and "noUpgrade" or "compare"
                local keep=ns.Gear.ItemAdvice(id,link)
                local protected=keep and keep.kind=="keep"
                local sell=kind=="noUpgrade" and not protected and info.sellPriceKnown and (info.sellPrice or 0)>0
                local text=kind=="upgrade" and "KEEP: upgrade for "..profile.name or kind=="noUpgrade" and (protected and keep.text or sell and "SELL CANDIDATE: keep your equipped item" or "KEEP EQUIPPED: no spec upgrade") or "KEEP FOR REVIEW: effect / stat tradeoff"
                local reason=string.format("Auto: %s (%s). %+.1f to %+.1f build-weighted points. %s",profile.name,profile.role,low,high,table.concat(schoolNotes,", "))
                if weaponDelta~=0 then reason=reason..string.format(" Weapon DPS %+.2f (same skill/speed).",weaponDelta) end
                if removedOffhand and removedOffhand.id then reason=reason.." Includes off-hand stat, effect and set loss." end
                if setChange.points~=0 then reason=reason..string.format(" Set threshold change: %+.1f points.",setChange.points) end
                if proposed.rateConfidence or prior.rateConfidence then reason=reason.." Proc PPM: post-launch Forever log evidence ("..((proposed.rateConfidence=="observed" or prior.rateConfidence=="observed") and "observed" or "measured")..")." end
                if proposed.stat~=prior.stat then reason=reason..string.format(" Expected proc/on-use stat contribution: %+.1f points.",proposed.stat-prior.stat) end
                if dps~=0 or healing~=0 or mana~=0 then reason=reason..string.format(" Expected sustained effects: %+.2f damage/s, %+.2f healing/s, %+.2f mana/s.",dps,healing,mana) end
                local warnings={};if replacedBuffActive then warnings[#warnings+1]="An active buff from the replaced item affects native power; compare again after it expires" end;for _,why in ipairs(setChange.unknown) do warnings[#warnings+1]=why end;if weaponUnknown then warnings[#warnings+1]="Weapon skill, speed and paired effects need a loadout comparison" end;if schoolUnknown then warnings[#warnings+1]="Relevant damage schools are not resolved for this build" end;for _,why in ipairs(proposed.unknown) do warnings[#warnings+1]=why end;for _,why in ipairs(prior.unknown) do warnings[#warnings+1]="Equipped: "..why end
                if unknown>0 then
                    local shown={};for i=1,math.min(3,#warnings) do shown[#shown+1]=warnings[i] end
                    reason=reason.." "..table.concat(shown,"; ")..(#warnings>3 and "; additional effect details unresolved" or "")
                end
                reason=reason.." School/stat points are advisory preferences; effect rates are sourced estimates, not measured DPS."
                local statPercent
                if kind=="upgrade" and not base.loadout and base.baseline>0 and base.delta>0 then
                    statPercent=100*base.delta/base.baseline
                end
                local result={kind=kind,text=text,reason=reason,retry=replacedBuffActive or proposed.pending or prior.pending or proposed.volatile or prior.volatile,delta=low,weaponDelta=weaponDelta,effectDamageDelta=dps,slot=slot,info=info,sellCandidate=sell,
                    statDelta=base.delta,effectsUnresolved=unknown>0,tradeoff=unknown==0 and kind=="compare",
                    specName=profile.name,statPercent=statPercent}
                if not best or kind=="upgrade" and best.kind~="upgrade" or kind==best.kind and low>best.delta then best=result end
            end
        end
    end end
    return best or {kind="manual",text="Keep until equipped data and slot restrictions are resolved"}
end

ns.Listen("SETTINGS_CHANGED",function() A.effectRevision=nil;A.profileKey=nil end)
