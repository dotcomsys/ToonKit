local addonName, ns = ...
local R={};ns.GearRequirements=R
local learnedRecipes,personalUses={},{}
local function isLearned(spell)
    if learnedRecipes[spell]~=nil then return learnedRecipes[spell] end
    local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local known=bank and ns.Safe(ns.API.Call("C_SpellBook","IsSpellKnown",spell,bank))
    learnedRecipes[spell]=known==true
    return learnedRecipes[spell]
end
local function professionSkill(id)
    local info=ns.API.Call("C_TradeSkillUI","GetProfessionInfoBySkillLineID",id)
    local source=ns.Data.reagentRecipeIndex and ns.Data.reagentRecipeIndex.skills[id]
    local name=type(info)=="table" and (ns.Safe(info.professionName) or ns.Safe(info.name))
    local current=type(info)=="table" and ns.Safe(info.skillLevel)
    return name or source and source.name or "Skill #"..id,
        type(current)=="number" and current>0 and current<math.huge and current or nil
end
function R.Skill(packed)
    if type(packed)~="number" then return "Profession requirement unavailable" end
    local id,rank=math.floor(packed/10000),packed%10000
    local name,current=professionSkill(id)
    return name.." "..rank.." (current "..(current or "unknown")..")"
end
function R.Reputation(packed,minimum)
    if type(packed)~="number" then return "Reputation requirement unavailable" end
    local id,required=math.floor(packed/1000000),packed%1000000
    local info=ns.API.Call("C_Reputation","GetFactionDataByID",id)
    local name=type(info)=="table" and ns.Safe(info.name)
    local current=type(info)=="table" and ns.Safe(info.currentStanding)
    return (name or "Faction #"..id)..(minimum and " at least " or " at most ")..required..(type(current)=="number" and " (current "..current..")" or " (current standing unreadable)")
end
local function title(id)
    local meta=ns.Data.questSupport and ns.Data.questSupport.meta[id]
    return meta and meta.name or ns.Safe(ns.API.Call("C_QuestLog","GetTitleForQuestID",id)) or "Quest #"..id
end
function R.Quests(record)
    local result,seen={},{}
    local function visit(id,depth,relation)
        if depth>16 or #result>=100 then result.limited=true;return end
        if seen[id] then return end;seen[id]=true
        local meta=ns.Data.questSupport and ns.Data.questSupport.meta[id]
        local row={id=id,name=title(id),depth=depth,relation=relation,meta=meta,
            status=ns.Journey.QuestDone(id) and "Complete" or ns.Journey.OnQuest(id) and "In quest log" or "Not confirmed complete"}
        result[#result+1]=row
        if not meta then row.unknown=true;return end
        row.all=ns.Copy(meta.preAll or {});row.any=ns.Copy(meta.pre or {})
        for _,prior in ipairs(row.all) do visit(prior,depth+1,"All required") end
        for _,prior in ipairs(row.any) do visit(prior,depth+1,"Alternative prerequisite (any one)") end
    end
    if record.quest then visit(record.quest,0,"Reward quest") end
    return result
end
function R.Guide(record)
    if not record.quest then return {} end
    local result={}
    for _,route in ipairs(ns.Journey.RouteSource()) do if route.category=="Class" and ns.Journey.Applies({classes=route.classes,factions=route.faction and {route.faction}}) then
        local rows,seen={},{}
        for _,step in ipairs(route.steps or {}) do if ns.Journey.Applies(step.only) then for _,goal in ipairs(step.goals or {}) do
            if goal.t=="accept" and goal.quest and ns.Journey.Applies(goal.only) and not seen[goal.quest] then
                seen[goal.quest]=true;rows[#rows+1]={goal=goal,route=route.name,status=ns.Journey.QuestDone(goal.quest) and "Complete" or ns.Journey.OnQuest(goal.quest) and "In quest log" or "Not confirmed complete"}
                if goal.quest==record.quest then return rows end
            end
        end end end
    end end
    return result
end
local function native(recipe,id)
    local schema=ns.API.Call("C_TradeSkillUI","GetRecipeSchematic",recipe.spell,false)
    if type(schema)~="table" or ns.Safe(schema.outputItemID)~=id then return end
    local rows=ns.Safe(schema.reagentSlotSchematics)
    if type(rows)~="table" then return end
    local materials={};local incomplete=false
    for _,slot in ipairs(rows) do
        local count=ns.Safe(slot.quantityRequired);local options=ns.Safe(slot.reagents)
        if type(count)=="number" and count>0 and count<math.huge and count==math.floor(count) and type(options)=="table" then
            local choices={}
            for _,option in ipairs(options) do
                local iid,currency=ns.Safe(option.itemID),ns.Safe(option.currencyID)
                if type(iid)=="number" and iid>0 then choices[#choices+1]={id=iid}
                elseif type(currency)=="number" and currency>0 then choices[#choices+1]={currency=currency}
                else incomplete=true end
            end
            if #choices>0 then materials[#materials+1]={count=count,choices=choices,optional=ns.Safe(slot.required)==false} end
            if #choices==0 then incomplete=true end
        elseif count~=0 or ns.Safe(slot.required)==true then incomplete=true
        end
    end
    recipe.materialGroups=materials;recipe.materialIncomplete=incomplete;recipe.native=true;recipe.output=ns.Safe(schema.quantityMin)
end
function R.Recipes(record)
    if type(record.recipeSpell)~="number" then return {} end
    local recipe={spell=record.recipeSpell,materialGroups={}}
    native(recipe,record.id)
    local info=ns.API.Call("C_TradeSkillUI","GetRecipeInfo",recipe.spell)
    recipe.name=type(info)=="table" and ns.Safe(info.name) or ns.Safe(ns.API.Call("C_Spell","GetSpellName",recipe.spell)) or "Recipe #"..recipe.spell
    recipe.learned=isLearned(recipe.spell) or nil
    return {recipe}
end
function R.Material(row)
    local parts={}
    for _,choice in ipairs(row.choices) do
        if choice.id then
            local info=ns.API.Item(choice.id,true);local owned=ns.Safe(ns.API.Call("C_Item","GetItemCount",choice.id,false,false,false,false))
            local counts=type(owned)=="number" and owned>=0 and owned<math.huge and owned==math.floor(owned) and ("carried "..owned..", missing "..math.max(0,row.count-owned)) or "carried count unreadable"
            parts[#parts+1]=(info and info.link or "Item #"..choice.id).." ("..counts..")"
        else
            local info=ns.API.Call("C_CurrencyInfo","GetCurrencyInfo",choice.currency)
            parts[#parts+1]=(type(info)=="table" and ns.Safe(info.name) or "Currency #"..choice.currency)
        end
    end
    return (row.optional and "Optional: " or "")..row.count.." x "..table.concat(parts," OR ")
end

local function recipeName(spell)
    local name=ns.Safe(ns.API.Call("C_Spell","GetSpellName",spell))
    return type(name)=="string" and name~="" and name or "Recipe #"..spell
end
local function recipeLine(index,spell,profession,currentRanks)
    local lines={}
    for id in pairs(index.ranks[spell] or {}) do
        local skill=index.skills[id]
        if skill and skill.profession==profession then lines[#lines+1]=id end
    end
    table.sort(lines)
    local requirements={}
    for _,id in ipairs(lines) do
        if currentRanks[id]==nil then local _,current=professionSkill(id);currentRanks[id]=current or false end
        local ranks=index.ranks[spell][id]
        local minimum=#ranks==0 and "unknown" or table.concat(ranks," / ")
        requirements[#requirements+1]=index.skills[id].name.." source minimum "..minimum..", current "..(currentRanks[id] or "unknown")
    end
    local requirement=#requirements>0 and table.concat(requirements," / ") or (profession.." source minimum unknown, current unknown")
    return recipeName(spell).." · "..requirement.." · "..(isLearned(spell) and "Known" or "Learning status unknown")
end
local function hasMaterial(spell,itemID)
    local schema=ns.API.Call("C_TradeSkillUI","GetRecipeSchematic",spell,false)
    local slots=type(schema)=="table" and ns.Safe(schema.reagentSlotSchematics)
    if type(slots)~="table" then return false end
    for _,slot in ipairs(slots) do
        local reagents=ns.Safe(slot.reagents)
        if type(reagents)=="table" then
            for _,reagent in ipairs(reagents) do if ns.Safe(reagent.itemID)==itemID then return true end end
        end
    end
    return false
end
for _,event in ipairs({"SPELLS_CHANGED","SKILL_LINES_CHANGED","TRADE_SKILL_SHOW","TRADE_SKILL_CLOSE","TRADE_SKILL_LIST_UPDATE","NEW_RECIPE_LEARNED"}) do
    ns.On(event,function() learnedRecipes={};personalUses={} end)
end
function R.AppendReagentUses(tooltip,item)
    if tooltip.tkReagentUses==item.id then return end
    local index=ns.Data.reagentRecipeIndex
    local uses=index and index.items[item.id]
    local character=ns.State.name or "the active character"
    local unknown="No learned recipe confirmed for "..character
    if not uses then
        local info=item.info or ns.API.Item(item.link or item.id)
        if info and (info.reagent or info.classID==7) then
            tooltip.tkReagentUses=item.id
            tooltip:AddLine((info.reagent and "Crafting reagent" or "Trade goods").." · recipe uses unknown",.62,.86,1,true)
            tooltip:AddLine(unknown,.72,.77,.83,true)
        end
        return
    end

    tooltip.tkReagentUses=item.id
    local build=type(GetBuildInfo)=="function" and ns.Safe(select(2,GetBuildInfo()))
    local exact=tostring(build)==index.build
    local professions={}
    for name in pairs(uses) do professions[#professions+1]=name end
    table.sort(professions)
    local personal=personalUses[item.id];local currentRanks={}
    if personal==nil then
        for _,name in ipairs(professions) do
            for _,spell in ipairs(uses[name]) do
                if isLearned(spell) and (exact or hasMaterial(spell,item.id)) then personal={spell=spell,profession=name};break end
            end
            if personal then break end
        end
        personalUses[item.id]=personal or false
    end
    if personal then tooltip:AddLine("Known by "..character.." · "..recipeLine(index,personal.spell,personal.profession,currentRanks),.43,1,.55,true)
    else tooltip:AddLine(unknown,.72,.77,.83,true) end
    local expanded=type(IsShiftKeyDown)=="function" and IsShiftKeyDown()
    local source=exact and "Crafting uses" or ("Forever recipe reference · Build "..index.build)
    if not expanded then
        tooltip:AddLine(source.." · "..table.concat(professions,", "),.62,.86,1,true)
        local first=professions[1]
        if first and not personal and uses[first][1] then tooltip:AddLine(recipeLine(index,uses[first][1],first,currentRanks),.82,.9,.95,true) end
        tooltip:AddLine("Shift-hover for more recipes.",.68,.76,.82,true)
        return
    end
    tooltip:AddLine(source,.62,.86,1,true)
    local remaining=24
    local perProfession=10
    for _,name in ipairs(professions) do
        local spells=uses[name]
        local count=math.min(#spells,perProfession,remaining)
        tooltip:AddLine(name.." ("..#spells..")",.62,.86,1,true)
        for i=1,count do
            tooltip:AddLine(recipeLine(index,spells[i],name,currentRanks),.82,.9,.95,true)
        end
        remaining=remaining-count
        if #spells>count then tooltip:AddLine((#spells-count).." more recipes",.68,.76,.82,true) end
    end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(tooltip,data)
        if tooltip~=GameTooltip or not ns.char then return end
        local id=ns.Safe(data and data.id)
        if type(id)=="number" and id>0 then R.AppendReagentUses(tooltip,{id=id}) end
    end)
end
if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipCleared",function(self) self.tkReagentUses=nil end)
end
