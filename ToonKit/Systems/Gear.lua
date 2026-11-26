local addonName, ns = ...
local G={}; ns.Gear=G
local armorSlots={INVTYPE_HEAD=true,INVTYPE_SHOULDER=true,INVTYPE_CHEST=true,INVTYPE_ROBE=true,INVTYPE_WRIST=true,INVTYPE_HAND=true,INVTYPE_WAIST=true,INVTYPE_LEGS=true,INVTYPE_FEET=true}
local armorBaseline={WARRIOR=3,PALADIN=3,HUNTER=2,SHAMAN=2,ROGUE=2,DRUID=2,MAGE=1,PRIEST=1,WARLOCK=1}
-- Personal targets are scoped to this character, build and planning range.
-- A selection is an acquisition preference, never fabricated item statistics.
function G.TargetScope(profile)
    local key=table.concat({ns.State.class or "UNKNOWN",profile and profile.role or ns.State.role or "unknown",profile and profile.tree or ns.Talents and ns.Talents.specKey or "unresolved"},":")
    return profile and profile.plan and (key..":plan:"..profile.plan) or key
end
function G.SelectedTargets(level,profile)
    local selected={}
    local role=profile and profile.role or ns.State.role
    local tree=profile and profile.tree or ns.Talents and ns.Talents.specKey
    if ns.State.class=="PALADIN" and ns.State.faction=="Alliance" and role=="melee" and tonumber(tree)==3 and level<=30 then
        for _,fact in ipairs(ns.Data.personalGearTargets or {}) do if fact.required<=level then selected[fact.slot]=fact end end
    end
    local saved=ns.char and ns.char.gearTargets and ns.char.gearTargets[G.TargetScope(profile)]
    for slot,fact in pairs(saved or {}) do
        if fact.required<=level and level<=fact.through then selected[tonumber(slot)]=fact end
    end
    local rows={};for _,fact in pairs(selected) do rows[#rows+1]=fact end
    table.sort(rows,function(a,b) return a.slot<b.slot end);return rows
end
function G.PersonalTarget(slot,level,profile)
    for _,fact in ipairs(G.SelectedTargets(level,profile)) do if fact.slot==slot then return fact end end
end
function G.SetPersonalTarget(slot,record,level,profile,quiet)
    if not record or not record.info or not ns.Data.equipSlots[record.info.equip] then return false end
    local fits=false;for _,value in ipairs(ns.Data.equipSlots[record.info.equip]) do if value==slot then fits=true end end
    if not fits or not record.capSourceKnown or record.capPending then return false end
    local required=math.max(record.required or 1,record.info.required or 1)
    level=math.floor(tonumber(level) or ns.State.level)
    if required>level or level>ns.Rules.Cap() then return false end
    local partner=({[11]=12,[12]=11,[13]=14,[14]=13})[slot]
    local other=partner and G.PersonalTarget(partner,level,profile)
    if other and other.id==record.id then return false,"Choose a different item for the paired slot." end
    if other then
        local category,maximum=ns.API.Call("C_Item","GetItemUniqueness",record.link or record.id)
        local otherCategory=ns.Safe(ns.API.Call("C_Item","GetItemUniqueness",other.id))
        category,maximum=ns.Safe(category),ns.Safe(maximum)
        if type(category)=="number" and category~=0 and category==otherCategory and (type(maximum)~="number" or maximum<2) then return false,"These paired targets share a unique-equipped restriction." end
    end
    ns.char.gearTargets=ns.char.gearTargets or {};local scope=G.TargetScope(profile)
    ns.char.gearTargets[scope]=ns.char.gearTargets[scope] or {}
    local fact={id=record.id,slot=slot,name=record.info.name,required=required,through=level,equip=record.info.equip,armor=record.info.subID}
    for _,key in ipairs({"source","sourceKind","quest","dungeon","boss","map","x","y","locations","requirements","provenance","class","faction","recipe","recipeSpell"}) do fact[key]=ns.Copy(record[key]) end
    ns.char.gearTargets[scope][slot]=fact;G.capKey=nil;G.cacheKey=nil;if not quiet then ns.Emit("STATE_CHANGED") end;return true
end
function G.ClearPersonalTarget(slot,profile)
    local saved=ns.char.gearTargets and ns.char.gearTargets[G.TargetScope(profile)]
    if saved then saved[slot]=nil end
    G.capKey=nil;G.cacheKey=nil;ns.Emit("STATE_CHANGED")
end
function G.RoleKnown(profile) if profile and profile.valid==false then return false end;return ns.Data.treeRoles[ns.State.class]~=nil and ns.Data.priorities[profile and profile.role or ns.State.role]~=nil end
function G.PreferredArmor()
    local preferred=armorBaseline[ns.State.class]
    if not preferred then return nil end
    -- Use observed, natively equipped proficiency upgrades, not a guessed
    -- level threshold for this Forever client.
    for _,r in pairs(ns.State.equipment or {}) do local e=r.info
        if e and e.classID==4 and armorSlots[e.equip] and type(e.subID)=="number" and e.subID<=4 then
            preferred=math.max(preferred,e.subID)
        end
    end
    return preferred
end
function G.ArmorAppropriate(info,profile)
    if not info or info.classID~=4 or not armorSlots[info.equip] then return true end
    local preferred=G.PreferredArmor()
    if not preferred then return false end
    -- Physical farming defaults to class armor. Lower armor comparisons are
    -- explicit; spell roles retain their own wearable stat comparisons.
    local role=profile and profile.role or ns.State.role or "unknown"
    if role=="healer" or role=="caster" or ns.char and ns.char.gearArmor=="any" then return true end
    return type(info.subID)=="number" and info.subID>=preferred
end
function G.ProfileKey(profile)
    local key=table.concat({ns.State.class or "UNKNOWN",profile and profile.role or ns.State.role or "unknown",profile and profile.tree or ns.Talents and ns.Talents.specKey or "unresolved",ns.State.raceToken or "Unknown",ns.char and ns.char.gearArmor or "class"},":")
    return profile and profile.plan and (key..":plan:"..profile.plan..":"..(profile.rankSignature or "")) or key
end
function G.WeaponTalentNotes()
    local out={};local T=ns.Talents
    if not T or not T.available or T.mismatches>0 then return out end
    for ti,tree in ipairs(T.Definitions()) do for i,d in ipairs(tree.talents) do
        local rank=T.actual[T.Key(ti,i)] or 0
        local text=d.desc and d.desc[rank]
        if rank>0 and type(text)=="string" then
            local lower=text:lower()
            if lower:find("weapon",1,true) or lower:find("off-hand",1,true) or lower:find("ranged damage",1,true) then
                out[#out+1]=d.name..": "..text
            end
        end
    end end
    return out
end
function G.Weights(profile)
    local role=profile and profile.role or ns.State.role or "unknown"
    local weights=ns.Copy(ns.Data.priorities[role] or {})
    -- Rogues and cat druids value agility more than strength. These remain advisory weights.
    if role=="melee" and (ns.State.class=="ROGUE" or ns.State.class=="DRUID") then weights.ITEM_MOD_AGILITY_SHORT=2.4; weights.ITEM_MOD_STRENGTH_SHORT=1 end
    for stat,w in pairs(ns.db.settings.weights[ns.State.class..":"..role] or {}) do weights[stat]=w end
    for stat,w in pairs(ns.db.settings.weights[G.ProfileKey(profile)] or {}) do weights[stat]=w end
    return weights
end
function G.Evaluate(link,profile,slot)
    if not link then return {score=0,stats={},notes={"Empty slot"}} end
    if type(link)=="number" then link="item:"..link end
    if type(link)~="string" then return nil end
    local stats=ns.API.Call("C_Item","GetItemStats",link)
    if type(stats)~="table" then return nil end
    local adjusted,talentNotes=stats,{}
    if not (profile and profile.nativeOnly) and G.TalentAdjustments and (not profile or profile.live or profile.ranks and profile.valid) then adjusted,talentNotes=G.TalentAdjustments(stats,profile) end
    local score,parts=0,{}
    for stat,weight in pairs(G.Weights(profile)) do
        local value=ns.Safe(adjusted[stat])
        if value==nil and stat=="ITEM_MOD_SPELL_POWER_SHORT" and profile and profile.role=="caster" then
            value=ns.Safe(adjusted.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT)
        end
        value=value or 0
        if value~=0 then score=score+value*weight; parts[#parts+1]=( _G[stat] or stat ).." "..value end
    end
    local role=profile and profile.role or ns.State.role or "unknown"
    local effect=ns.Data.effects[tonumber(link:match("item:(%d+)"))]
    if not (profile and profile.nativeOnly) and effect and effect[role] then score=score+effect[role].value end
    for _,note in ipairs(talentNotes) do parts[#parts+1]=note end
    local effectProfile=ns.State.class..":"..role
    local personal=((ns.db.settings.effectOverrides or {})[effectProfile] or {})[tonumber(link:match("item:(%d+)"))]
    if personal and not (profile and profile.nativeOnly) then score=score+personal.value;parts[#parts+1]="Personal effect preference: "..string.format("%+.1f",personal.value).." ("..personal.note..")" end
    local modeled,incomplete
    if ns.Simulation and ns.db.settings.gearUseModels and not (profile and profile.withoutModels) then
        modeled,incomplete=ns.Simulation.EvaluationExtra(link,profile)
        if modeled then score=score+modeled;parts[#parts+1]=string.format("Modeled effect contribution: %+.2f scenario points (standalone; use loadout simulation for shared cooldowns).",modeled) end
        if incomplete and incomplete>0 then parts[#parts+1]="Some effect models lack usable scenario inputs. Review effect coverage in loadout simulation." end
    end
    return {score=score,stats=stats,adjusted=adjusted,notes=parts,effect=effect,personal=personal,simulationEffects=modeled,simulationIncomplete=incomplete or 0}

end
function G.Candidates()
    local cacheKey=table.concat({ns.State.inventoryRevision or 0,ns.State.questRevision or 0,ns.State.itemRevision or 0,ns.Rules.Cap(),ns.State.class,ns.State.level,ns.State.role or "unknown",ns.char and ns.char.gearArmor or "class"},":")
    if G.cacheKey==cacheKey then return G.candidates end
    local out,seen={},{}
    local function add(id,source,available,quest,dungeon,infoLink,conditions)
        if not id then return end
        local key=tostring(infoLink or id)..":"..source; if seen[key] then return end; seen[key]=true
        local info=ns.API.Item(infoLink or id,true)
        if not info or not ns.Data.equipSlots[info.equip] then return end
        local record={id=id,info=info,link=infoLink or info.link,source=source,quest=quest,dungeon=dungeon,required=info.required,
            live=available,availability=available and "confirmed" or nil}
        if conditions then
            record.classic=conditions.classic;record.verifiedBuild=conditions.verifiedBuild
            record.class=conditions.class; record.faction=conditions.faction or conditions.side
            record.classes=conditions.classes;record.races=conditions.races;record.sourceKind=conditions.sourceKind
            record.map=conditions.map;record.x=conditions.x;record.y=conditions.y;record.locations=conditions.locations;record.sourceNPC=conditions.sourceNPC
            record.requirements=conditions.requirements;record.provenance=conditions.provenance;record.sourceKnown=conditions.sourceKnown;record.recipe=conditions.recipe;record.recipeSpell=conditions.recipeSpell
            record.required=math.max(record.required,conditions.required or conditions.min or 1)
        end
        local allowed,reason=ns.Rules.Available(record,true); record.actionable=allowed; record.reason=reason
        local usable,eligibility=ns.API.ItemEligibility(id,info)
        if usable~=true then record.actionable=false; record.reason=eligibility end
        if not G.ArmorAppropriate(info) then record.actionable=false;record.reason="Below class/role armor preference; compare manually" end
        out[#out+1]=record
    end
    for _,item in ipairs(ns.State.bags) do if item.id then add(item.id,"In your bags",true,nil,nil,item.link) end end
    local live={}; for _,q in ipairs(ns.State.quests) do live[q.id]=true end
    for _,d in ipairs(ns.Data.dungeons or {}) do
        if ns.Rules.Available({min=d.min,classic=d.classic},false) then
            for _,q in ipairs(d) do
                local copy=ns.Copy(q)
                if ns.Rules.Available(copy,false) and not ns.API.QuestDone(q.id) then
                    for _,reward in ipairs(q.rewards or {}) do
                        add(reward.id,d.name..": "..q.title,live[q.id],q.id,d.slug)
                    end
                    for _,reward in ipairs(q.choice or {}) do
                        -- Quest acceptance proves the quest exists here, not eligibility for every choice.
                        add(reward.id,d.name..": "..q.title,live[q.id],q.id,d.slug)
                    end
                end
            end
        end
    end
    if ns.Journey then for _,route in ipairs(ns.Journey.Routes()) do if route.category=="Class" then
        for _,reward in ipairs(route.rewards or {}) do
            add(reward.item,route.name..": source-listed class quest reward",ns.Journey.OnQuest(reward.quest),reward.quest,nil,nil,{class=ns.State.class,faction=route.faction,required=route.min})
        end
    end end end
    local support=ns.Data.questSupport or {quests={},meta={}}
    local function maskAllows(mask,id) return not mask or mask==0 or type(id)=="number" and math.floor(mask/2^(id-1))%2==1 end
    for quest,rewards in pairs(support.quests) do
        local meta=support.meta[quest]
        if meta and (meta.min or 1)<=ns.Rules.Cap() and maskAllows(meta.classes,ns.State.classID) and ns.Rules.QuestRaceAllowed(meta.races)
            and not ns.API.QuestDone(quest) then
            for _,id in ipairs(rewards.rewards or {}) do
                add(id,"Quest reward: "..(meta.name or "Quest #"..quest),live[quest]==true,quest,nil,nil,{required=meta.min,sourceKnown=true,sourceKind="quest",provenance="EverythingQuests Forever MIT quest rewards"})
            end
        end
    end
    for _,r in ipairs(ns.Data.gear) do
        local facts=r
        if r.sourceKind=="quest" and r.sourceKnown then
            facts=ns.Copy(r);facts.sourceKnown=false
            local quest=(ns.Data.questSupport.quests or {})[r.quest]
            for _,reward in ipairs(quest and quest.rewards or {}) do if reward==r.id then facts.sourceKnown=true;break end end
        end
        add(r.id,r.source,r.availability=="confirmed",r.quest,r.dungeon,nil,facts)
    end
    for _,r in ipairs(ns.Data.gearSources or {}) do
        if ns.Rules.Available(r,false) then add(r.id,r.source,false,nil,nil,nil,r) end
    end
    if ns.Journal then
        for _,r in ipairs(ns.Journal.GearCandidates()) do
            local key=r.id..":"..r.source
            if not seen[key] then seen[key]=true; out[#out+1]=r end
        end
    end
    G.cacheKey,G.candidates=cacheKey,out
    return out
end
function G.Compare(candidate,slot,profile)
    local info=candidate.info
    if not info then return nil end
    local equipped=ns.State.equipment[slot]
    local current=equipped and (equipped.link or equipped.info and equipped.info.link)
    if equipped and equipped.id and not current then return nil end
    local link=candidate.link or info.link;if not link then return nil end
    local proposed=G.Evaluate(link,profile,slot); local baseline=G.Evaluate(current,profile,slot)
    if not proposed or not baseline then return nil end
    local delta=proposed.score-baseline.score; local notes={}
    for _,p in ipairs(proposed.notes) do notes[#notes+1]=p end
    if info.classID==2 then
        local dps=ns.Safe(proposed.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT)
        local currentDPS=ns.Safe(baseline.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT)
        if dps and currentDPS then notes[#notes+1]=string.format("Weapon DPS: %.1f vs %.1f equipped (%+.1f). Separate from the stat estimate.",dps,currentDPS,dps-currentDPS) end
        notes[#notes+1]="Compare weapon damage, speed, skill and talent interactions in the item tooltip."
    end
    if info.equip=="INVTYPE_2HWEAPON" and ns.State.equipment[17] and ns.State.equipment[17].link then
        local off=G.Evaluate(ns.State.equipment[17].link,profile,17)
        if off then delta=delta-off.score end
        notes[#notes+1]="Two-handed comparison includes the off-hand stat loss."
    end
    if info.equip=="INVTYPE_2HWEAPON" and ns.State.equipment[17] and ns.State.equipment[17].id and not ns.State.equipment[17].link then return nil end
    local limit,max=ns.API.Call("C_Item","GetItemUniqueness",candidate.id)
    if limit and limit~=0 then notes[#notes+1]="Unique category limit: "..(max or 1).."; verify equipped combinations." end
    notes[#notes+1]="Procs, sets, sockets and weapon handling can outweigh this stat estimate."
    if ns.Talents.uncertain then notes[#notes+1]="Build inference is uncertain; select a playstyle." end
    local loadout=not (profile and profile.withoutModels) and ns.Simulation and ns.db.settings.gearUseModels and ns.Simulation.CompareLoadout(candidate,slot,profile)
    if loadout then
        delta=loadout.delta
        table.insert(notes,1,loadout.partial and "Loadout comparison includes modeled sets/effects but has unresolved data; this is not verified BiS." or "Loadout comparison includes modeled set thresholds, shared cooldowns and effect scaling; base attributes still use advisory weights.")
        return {delta=delta,notes=notes,score=baseline.score+delta,baseline=baseline.score,conditional=true,loadout=loadout}
    end
    return {delta=delta,notes=notes,score=proposed.score,baseline=proposed.score-delta,conditional=info.classID==2 or not proposed.effect}
end
function G.ForSlot(slot,includeUnverified)
    local out={}
    for _,r in ipairs(G.Candidates()) do
        if not G.RoleKnown() then r.actionable=false;r.reason="Class or role unresolved; compare manually" end
        if not G.ArmorAppropriate(r.info) then r.actionable=false;r.reason="Below class/role armor preference; compare manually" end
        for _,s in ipairs(ns.Data.equipSlots[r.info.equip] or {}) do if s==slot and (r.actionable and G.ArmorAppropriate(r.info) or includeUnverified) then
            local same=ns.State.equipment[slot] and ns.State.equipment[slot].link==r.link
            if not same then r.comparison=G.Compare(r,slot);r.equipAllowed,r.equipReason=G.EquipCheck(r,slot);out[#out+1]=r end
            break
        end end
    end
    local preferred=G.PersonalTarget(slot,ns.State.level)
    table.sort(out,function(a,b)
        if a.actionable~=b.actionable then return a.actionable end
        if preferred and (a.id==preferred.id)~=(b.id==preferred.id) then return a.id==preferred.id end
        local ad,bd=a.comparison and a.comparison.delta or -math.huge,b.comparison and b.comparison.delta or -math.huge
        if ad~=bd then return ad>bd end
        local an,bn=a.info.name or "",b.info.name or ""
        if an~=bn then return an<bn end
        if a.id~=b.id then return a.id<b.id end
        return (a.source or "")<(b.source or "")
    end)
    return out
end
function G.Track(r)
    if not r.actionable then ns.Message(r.reason or "Availability unverified"); return end
    if r.info and ns.Data.equipSlots[r.info.equip] then
        local usable,reason=ns.API.ItemEligibility(r.id,r.info)
        if usable~=true then ns.Message(reason); return end
    end
    ns.char.farming[r.id]={id=r.id,source=r.source,quest=r.quest,dungeon=r.dungeon,boss=r.boss,bossKey=r.encounter and r.encounter.id,catalog=r.catalog,obtained=(ns.State.owned[r.id] or 0)>0}
    ns.Emit("STATE_CHANGED")
end
function G.UpdateFarming()
    if not ns.char then return end
    for id,target in pairs(ns.char.farming) do
        local owned=(ns.State.owned[id] or 0)>0
        if owned and not target.obtained then
            target.obtained=true
            ns.Emit("GEAR_HUNT_OBTAINED",id)
            if ns.db.settings.notifications then local info=ns.API.Item(id); ns.Message("Farming target obtained: "..(info and info.name or id)) end
        end
        target.ownedNow=owned
    end
end

ns.Listen("SETTINGS_CHANGED",function() G.cacheKey=nil;G.capKey=nil;G.rankInput=nil end)
