local addonName, ns = ...
local M,U,S,G=ns.Main,ns.UI,ns.Simulation,ns.Gear
local function at(widget,x,y) widget:SetPoint("TOPLEFT",x,y);return widget end
local function control(label,value,x,y,width,fields,key)
    U.Label(M.body,label,x,y,width,"GameFontNormal")
    local entry=at(U.Edit(M.body,width,tostring(value or ""),nil),x,y-25);fields[key]=entry;return entry
end
local function statChoices()
    local seen,rows={},{}
    for _,weights in pairs(ns.Data.priorities) do for stat in pairs(weights) do if not seen[stat] then seen[stat]=true;rows[#rows+1]={value=stat,label=_G[stat] or stat} end end end
    table.sort(rows,function(a,b) return a.label<b.label end);return rows
end
function M.EffectContext()
    M.Heading("Effect calculations and source coverage")
    M.Line("Enter power excluding the flat stats on modeled gear, plus landed event rates. Native flat gear power and active flat set bonuses are added per loadout. Supported on-use power buffs follow the shared activation timeline. Class attribute conversions and rotations are not inferred. Multipliers cover your target and modifiers; 1 means raw output.","GameFontHighlightSmall")
    local config=ns.Copy(ns.db.settings.simulationCombat);local fields={}
    local settings={{"spellPower","Spell power excluding modeled gear"},{"healingPower","Healing power excluding modeled gear"},{"attackPower","Attack power excluding modeled gear"},{"damageMultiplier","Damage multiplier after target mitigation"},{"healingMultiplier","Healing multiplier"},{"overhealing","Overhealing fraction (0 to 1)"},{"manaWeight","Scenario points per mana/sec"},{"melee","Eligible landed melee events/sec"},{"ranged","Eligible landed ranged events/sec"},{"spell","Eligible spell events/sec"},{"struck","Eligible incoming hits/sec"}}
    local top=M.y;local width=math.floor((M.width-40)/3)
    for index,row in ipairs(settings) do local column=(index-1)%3;local line=math.floor((index-1)/3)
        control(row[2],config[row[1]],8+column*(width+12),top-line*75,width,fields,row[1])
    end
    M.y=top-math.ceil(#settings/3)*75
    local cadence=at(U.Check(M.body,"Evenly spaced events for chance procs (off: Poisson arrival model)",config.fixedEvents==true,function(value) config.fixedEvents=value end),8,M.y)
    M.y=M.y-38
    M.Action("Save effect inputs",function()
        for key,field in pairs(fields) do config[key]=tonumber(field:GetText()) end
        local ok,why=ns.EffectMath.ValidCombat(config);if not ok then return ns.Message(why) end
        ns.db.settings.simulationCombat=config
        ns.db.settings.simulation.combat=ns.Copy(config)
        M.simResult=nil;ns.Emit("SETTINGS_CHANGED");M.Render()
    end,230)
    local snapshot=ns.EffectMath.Snapshot()
    if not snapshot then M.Line("No numeric effect snapshot matches this client build. Native tooltip parsing and sourced personal models remain available; another build's numbers are never silently applied.","GameFontNormal");return end
    local classes={};for token in pairs(ns.Data.referenceTalents) do classes[#classes+1]=token end;table.sort(classes)
    local ids={WARRIOR=1,PALADIN=2,HUNTER=3,ROGUE=4,PRIEST=5,SHAMAN=7,MAGE=8,WARLOCK=9,DRUID=11}
    local rows={}
    for _,token in ipairs(classes) do for index,tree in ipairs(ns.Data.referenceTalents[token]) do rows[#rows+1]={class=token,tree=index,label=token.." / "..tree.name} end end
    local index=M.Choose(rows,"effectCoverageSpec","Class/spec coverage",function(row) return row.label end)
    if index then
        local row=rows[index];local count,modeled,complete=0,0,0;local bit=2^(ids[row.class]-1)
        for _,entry in pairs(snapshot.items) do if entry.classMask<=0 or math.floor(entry.classMask/bit)%2==1 then
            count=count+1;if #entry.models>0 then modeled=modeled+1 end
            if #entry.unknown==0 then complete=complete+1 end
        end end
        M.Line(string.format("Build %s: %d compatible item-effect records, %d with calculated components, %d with no unresolved table effects.",snapshot.build,count,modeled,complete),"GameFontNormal")
        M.Line("Class compatibility is not obtainability or verified BiS. The same numeric effect engine serves every listed spec, including healing/tank roles; scripted, pet, form and ability interactions still require specific sourced models.","GameFontHighlightSmall")
    end
end
function M.EffectModels()
    local width=M.width;local column=math.floor((width-32)/2);local fields={};local draft=M.effectDraft or {kind="stat",trigger="use",stat="ITEM_MOD_STRENGTH_SHORT",amount=0,duration=0,cooldown=0,ppm=0,chance=0,icd=0,group="",sharedCooldown=0,source=""};M.effectDraft=draft
    M.effectItem=M.effectItem or M.huntItem or (G.PersonalTarget(M.slot or 15,ns.Rules.Cap(),G.HuntProfile()) or {}).id
    local top=M.y
    local id=control("Item ID",M.effectItem,8,top,150,fields,"item")
    at(U.Button(M.body,"Load item models",190,function() M.effectItem=tonumber(id:GetText());M.effectModelIndex=nil;M.effectDraft=nil;M.effectCoverage=nil;M.Render() end),170,top-25)
    local record=M.effectItem and ns.API.Item(M.effectItem,true)
    if not record then M.y=top-75;M.Line("Enter a real item ID and load its native item data before editing effects.");return end
    U.Label(M.body,record.link or record.name,380,top-30,width-400,"GameFontNormal")
    local saved=ns.db.settings.simEffects[M.effectItem];local models=saved and saved.models or {};local rows={{value=0,label="Add another effect"}}
    for index,model in ipairs(models) do rows[#rows+1]={value=index,label=(model.kind or "Effect").." / "..(model.trigger or "").." / "..tostring(model.amount or "")} end
    local pick=U.Cycle(M.body,rows,M.effectModelIndex or 0,width-16,function(v) M.effectModelIndex=v;M.effectDraft=v>0 and ns.Copy(models[v]) or nil;M.Render() end)
    pick:SetPoint("TOPLEFT",8,top-75)
    local y=top-120
    local function keepDraft()
        for _,key in ipairs({"amount","duration","cooldown","chance","ppm","icd","sharedCooldown","spellCoefficient","apCoefficient","period"}) do if fields[key] then draft[key]=tonumber(fields[key]:GetText());if key=="chance" and draft[key] then draft[key]=draft[key]/100 end end end
        for _,key in ipairs({"group","source"}) do if fields[key] then draft[key]=fields[key]:GetText() end end
    end
    at(U.Cycle(M.body,{{value="stat",label="Stat buff"},{value="damage",label="Damage"},{value="healing",label="Healing"},{value="mana",label="Mana restored"}},draft.kind,column,function(v) keepDraft();draft.kind=v;M.Render() end),8,y)
    at(U.Cycle(M.body,{{value="use",label="On use"},{value="proc",label="Proc"},{value="passive",label="Passive"}},draft.trigger,column,function(v) keepDraft();draft.trigger=v;M.Render() end),24+column,y)
    at(U.Cycle(M.body,statChoices(),draft.stat,column,function(v) keepDraft();draft.stat=v;M.Render() end),8,y-40)
    control("Amount per trigger (passive: per second)",draft.amount,24+column,y-40,column,fields,"amount")
    control("Buff duration (seconds)",draft.duration,8,y-100,column,fields,"duration")
    control("Use cooldown (seconds)",draft.cooldown,24+column,y-100,column,fields,"cooldown")
    control("Proc chance per event (%) - choose chance or PPM",(draft.chance or 0)*100,8,y-160,column,fields,"chance")
    control("Procs per minute (PPM)",draft.ppm,24+column,y-160,column,fields,"ppm")
    control("Internal cooldown (seconds)",draft.icd,8,y-220,column,fields,"icd")
    control("Shared cooldown lockout (seconds)",draft.sharedCooldown,24+column,y-220,column,fields,"sharedCooldown")
    control("Spell power coefficient (0 if none)",draft.spellCoefficient or 0,8,y-280,column,fields,"spellCoefficient")
    control("Attack power coefficient (0 if none)",draft.apCoefficient or 0,24+column,y-280,column,fields,"apCoefficient")
    control("Periodic tick interval (0 = direct)",draft.period or 0,8,y-340,column,fields,"period")
    at(U.Cycle(M.body,{{value="any",label="Generic event rate"},{value="melee",label="Landed melee events"},{value="ranged",label="Landed ranged events"},{value="spell",label="Eligible spell events"},{value="struck",label="Eligible incoming hits"}},draft.event or "any",column,function(v) keepDraft();draft.event=v~="any" and v or nil;M.Render() end),24+column,y-365)
    y=y-120
    control("Shared cooldown group (same name on linked effects)",draft.group,8,y-280,column,fields,"group")
    control("Source / measured assumptions",draft.source,24+column,y-280,column,fields,"source")
    local complete=saved and saved.complete==true
    if M.effectCoverage~=nil then complete=M.effectCoverage end
    local covered=at(U.Check(M.body,"I have modeled all otherwise unscored effects on this item",complete,function(v) M.effectCoverage=v end),8,y-340)
    local function capture()
        local model=ns.Copy(draft)
        for _,key in ipairs({"amount","duration","cooldown","chance","ppm","icd","sharedCooldown","spellCoefficient","apCoefficient","period"}) do model[key]=tonumber(fields[key]:GetText()) end
        if model.period==0 then model.period=nil end
        if model.chance then model.chance=model.chance/100 end
        model.group=fields.group:GetText():match("^%s*(.-)%s*$");model.source=fields.source:GetText():match("^%s*(.-)%s*$")
        return model
    end
    at(U.Button(M.body,"Save effect model",190,function()
        local model=capture();local ok,why=S.ValidateModel(model);if not ok then return ns.Message(why) end
        local entry=ns.db.settings.simEffects[M.effectItem] or {models={}}
        local index=(M.effectModelIndex or 0)>0 and M.effectModelIndex or #entry.models+1
        local facts=G.Facts(record.link)
        entry.nativeSignature=table.concat(facts.effects or {},"\n").."\n"..(facts.useDescription or "")
        if type(GetBuildInfo)=="function" then local _,build=GetBuildInfo();entry.build=tostring(ns.Safe(build,"unknown")) end
        entry.models[index]=model;entry.complete=M.effectCoverage==nil and complete or M.effectCoverage==true
        ns.db.settings.simEffects[M.effectItem]=entry;M.effectDraft=ns.Copy(model);M.effectModelIndex=index;M.effectCoverage=nil;S.Cancel();M.simResult=nil;ns.Emit("SETTINGS_CHANGED");M.Render()
    end),8,y-378)
    at(U.Button(M.body,"Remove selected model",210,function()
        local entry=ns.db.settings.simEffects[M.effectItem]
        if entry and M.effectModelIndex and M.effectModelIndex>0 then table.remove(entry.models,M.effectModelIndex);if #entry.models==0 then ns.db.settings.simEffects[M.effectItem]=nil end end
        M.effectModelIndex=nil;M.effectDraft=nil;M.effectCoverage=nil;S.Cancel();M.simResult=nil;ns.Emit("SETTINGS_CHANGED");M.Render()
    end),210,y-378)
    at(U.Button(M.body,"Read native use effect",210,function()
        local facts=G.Facts(record.link);local models=S.Models({id=M.effectItem,info=record,link=record.link},facts,true)
        if models[1] then M.effectDraft=ns.Copy(models[1]);M.effectModelIndex=0;M.Render() else ns.Message("The client did not supply a simple use effect with a readable cooldown. Enter sourced parameters explicitly.") end
    end),430,y-378)
    M.y=y-425
    M.Line("Personal models use your supplied values and source notes. Chance procs use the selected fixed-event or Poisson model; sourced PPM uses renewal timing. These are expected outputs under the entered assumptions, not observed combat results. Native item stats remain the base score.","GameFontHighlightSmall")
end
function M.Simulation()
    local pages=at(U.Options(M.body,{{value="loadout",label="Scenario"},{value="results",label="Results"},{value="effects",label="Effect models"},{value="context",label="Effect inputs / coverage"}},M.simPage or "loadout",M.width-16,function(v) M.simPage=v;M.Render() end,4),8,M.y)
    M.y=M.y-pages:GetHeight()-12
    if M.simPage=="context" then return M.EffectContext() end
    if M.simPage=="effects" then return M.EffectModels() end
    if M.simPage=="results" then return M.SimulationResults() end
    M.Heading("BiS targets and effect simulation")
    M.Line("Compare modeled loadouts using native item stats, legal saved talents, source-backed effects and your selected targets. Effect outputs use numeric amounts and scaling; the combined gear score still includes advisory stat weights.","GameFontHighlightSmall")
    local choices={{value="auto",label="Live build"}}
    for index,tree in ipairs(ns.Talents.Definitions()) do choices[#choices+1]={value=tostring(index),label=tree.name} end
    local names={};for name,plan in pairs(ns.char.builds or {}) do if plan.class==ns.State.class then names[#names+1]=name end end;table.sort(names)
    for _,name in ipairs(names) do choices[#choices+1]={value="plan:"..name,label="Plan: "..name} end
    local top=M.y;local column=math.floor((M.width-40)/3)
    at(U.Cycle(M.body,choices,M.simBuild or "auto",column,function(v) M.simBuild=v;M.simResult=nil;M.Render() end),8,top)
    local level=at(U.Edit(M.body,column,tostring(M.simLevel or ns.State.level),nil),20+column,top);U.Tooltip(level,"Planning level",{"Current level through the active cap. Future-level results are plans, not equip-now advice."})
    local roles={{value="auto",label="Build role"},{value="melee",label="Melee"},{value="ranged",label="Ranged"},{value="caster",label="Caster"},{value="healer",label="Healer"},{value="tank",label="Tank"}}
    at(U.Cycle(M.body,roles,M.simRole or "auto",column,function(v) M.simRole=v;M.simResult=nil;M.Render() end),32+column*2,top)
    local config=ns.Copy(ns.db.settings.simulation);local fields={};local settings={{"duration","Fight duration (seconds)"},{"attacks","Eligible proc events per second"},{"useDelay","First use delay (seconds)"},{"weaponWeight","Weapon priority multiplier (legacy: points per DPS)"},{"damageWeight","Points per effect damage/second"},{"healingWeight","Points per effect healing/second"},{"perSlot","Candidates per slot (plus equipped and pinned)"},{"maxNodes","Search-node budget"}}
    local y=top-45;local rowHeight=75
    for index,setting in ipairs(settings) do local col=(index-1)%3;local row=math.floor((index-1)/3)
        control(setting[2],config[setting[1]],8+col*(column+12),y-row*rowHeight,column,fields,setting[1])
    end
    M.y=y-math.ceil(#settings/3)*rowHeight-6
    at(U.Button(M.body,S.job and "Restart search" or "Find best modeled set",240,function()
        if InCombatLockdown() then return ns.Message("Run the comparison after combat.") end
        for key,field in pairs(fields) do config[key]=tonumber(field:GetText()) end
        config.combat=ns.Copy(ns.db.settings.simulationCombat)
        local ok,why=S.ValidateScenario(config);if not ok then return ns.Message(why) end
        local n=tonumber(level:GetText());if not n or n~=math.floor(n) or n<1 or n>ns.Rules.Cap() then return ns.Message("Enter a planning level within the active cap.") end
        M.simLevel=n;ns.db.settings.simulation=ns.Copy(config);S.settingsRevision=S.settingsRevision+1;S.modelRevision=S.modelRevision+1;G.capKey=nil;G.rankInput=nil
        local profile=G.HuntProfile(M.simBuild or "auto",M.simRole or "auto",n)
        local data=G.CapTargets(n,profile);M.simResult=nil;M.simError=nil
        local started,reason=S.Optimize(data,profile,config,function(job,error)
            M.simResult=job;M.simError=error;if job then M.simPage="results" end
            if U.main and U.main:IsShown() then M.Render() end
        end)
        if not started then M.simError=reason end
        M.Render()
    end),8,M.y)
    at(U.Button(M.body,"Stop search",140,function() S.Cancel();M.Render() end),260,M.y)
    M.y=M.y-44
    if S.job then M.simProgress=M.Line("Searching in short batches: "..S.job.nodes.." nodes visited. Search stops if item or character data changes.","GameFontNormal") end
    if M.simError then M.Line(M.simError,"GameFontNormal") end
    if M.simResult then M.Action("Open result",function() M.simPage="results";M.Render() end,200) end
    M.Line("Selected eligible slot targets stay pinned. Unique-equipped limits, distinct rings/trinkets and weapon/off-hand conflicts constrain the search. Shared uses compete chronologically, with slot order breaking simultaneous ties; proc models use the entered event rate or sourced PPM. Candidate limits and search budgets are explicit.","GameFontHighlightSmall")
end

function M.SimulationResults()
    M.Heading("Advisory modeled loadout result")
    if M.simError then M.Line(M.simError) end
    local job=M.simResult
    if job and job.best then
        M.Line(string.format("Best modeled score: %.2f | %d nodes | %s",job.best.score,job.nodes,job.limited and "Budget reached; search incomplete" or "Search complete within this candidate pool"),"GameFontNormal")
        if job.baseline then M.Line(string.format("Versus equipped: %+.2f scenario points%s",job.best.score-job.baseline.score,(job.baselineMissing or 0)>0 and " (baseline item data incomplete)" or ""),"GameFontNormal") end
        if (job.uncertain or 0)>0 then M.Line(job.uncertain.." candidate entries have incomplete effect coverage; this search compares their modeled components.","GameFontHighlightSmall") end
        M.Line(string.format("Effect outputs: %.2f damage/sec, %.2f effective healing/sec, %.2f mana/sec under the saved effect inputs.",job.best.damage,job.best.healing,job.best.mana or 0),"GameFontHighlightSmall")
        M.Line("This result combines advisory stat weights with modeled item effects. It is not a class rotation simulation or verified BiS; pet, form and scripted class mechanics are incomplete.","GameFontNormal")
        M.Action("Save this modeled farming set",function()
            local ok,why=S.Apply(job);if not ok then ns.Message(why) end
            M.Render()
        end,330)
        local rows={};for _,slot in ipairs(ns.Data.slots) do local item=job.loadout[slot[1]];if item then rows[#rows+1]={value=slot[1],label=slot[2]..": "..item.record.info.name} end end
        local selected=M.simSlot or rows[1] and rows[1].value
        local roster=at(U.Cycle(M.body,rows,selected,M.width-16,function(v) M.simSlot=v;M.Render() end),8,M.y);M.y=M.y-roster:GetHeight()-10
        local item=selected and job.loadout[selected]
        if item then
            M.Line(item.record.link or item.record.info.name)
            M.Line(item.record.source or "Recorded source")
            M.Action("Compare selected item",function() local copy=ns.Copy(item.record);copy.previewProfile=job.profile;ns.ItemCompare.Show(copy,selected) end,230)
            M.Action("Edit this item's effects",function() M.effectItem=item.record.id;M.effectDraft=nil;M.effectModelIndex=nil;M.simPage="effects";M.Render() end,230)
            local details={};for _,entry in ipairs(job.best.effects) do if entry.item==item.record.info.name then details[#details+1]=entry end end
            if #details>0 then
                local index=M.Choose(details,"simEffectDetail","Calculated effects",function(entry) return entry.model.kind.." / "..entry.model.trigger..(entry.model.spell and " / spell #"..entry.model.spell or "") end)
                if index then local entry=details[index];local value=entry.result
                    M.Line(entry.model.source or "Personal source")
                    M.Line(value.unknown or string.format("Expected activations: %.3f | Average %s: %.3f%s",value.events or 0,entry.model.kind,value.value or 0,value.ticks and (" | Ticks: "..string.format("%.0f",value.ticks)) or ""))
                end
            end
        end
        if #job.best.unknown>0 then
            M.Line(#job.best.unknown.." unmodeled or uncertain effect entries remain in this set.","GameFontNormal")
            local index=M.Choose(job.best.unknown,"simUnknown","Review effect coverage",function(text) return text end)
            if index then M.Line(job.best.unknown[index]) end
        else M.Line("No unmodeled entries were detected in the available tooltip data or selected personal models.","GameFontHighlightSmall") end
    end
    if not M.simResult then M.Line("Run a scenario first.") end
    M.Line("The best result is scoped to this candidate pool and these modeled inputs. Review unmodeled effects before treating a result as BiS.","GameFontHighlightSmall")
end
ns.Listen("SIMULATION_PROGRESS",function(job)
    if M.tab=="Character" and M.sub=="Equipment" and M.gearWorkspace=="simulation" and M.simProgress and M.simProgress:IsShown() then
        M.simProgress:SetText("Searching in short batches: "..job.nodes.." nodes visited.")
    end
end)
