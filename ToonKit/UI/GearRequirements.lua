local addonName, ns = ...
local M,R=ns.Main,ns.GearRequirements
function M.OpenGearRequirements(record)
    return M.OpenPage("Equipment",function()
        M.gearRequirementRecord=record
        for _,key in ipairs({"requirementQuest","requirementGuideQuest","requirementRecipe","requirementMaterial"}) do
            M[key]=nil;M[key.."Identity"]=nil
        end
    end)
end
function M.GearRequirementsView()
    local record=M.gearRequirementRecord
    M.Action("Back to equipment",function()
        if #M.history>0 then M.GoBack() else M.gearRequirementRecord=nil;M.Render() end
    end,220)
    M.Heading("Acquisition prerequisites and materials")
    M.Line(record.info and (record.info.link or record.info.name) or "Item #"..record.id,"GameFontNormal")
    M.Line(record.source or "Recorded source","GameFontHighlightSmall")
    if record.requirements then M.Line(record.requirements) end
    local quests=R.Quests(record)
    if #quests>0 then
        local index=M.Choose(quests,"requirementQuest","Quest chain",function(row) return row.name.." - "..row.status.." ("..row.relation..")" end)
        if index then local row=quests[index]
            M.Line(row.name.." | "..row.status,"GameFontNormal")
            local function names(ids) local out={};for _,id in ipairs(ids or {}) do local meta=ns.Data.questSupport.meta[id];out[#out+1]=(meta and meta.name or "Quest #"..id)..(ns.Journey.QuestDone(id) and " [complete]" or ns.Journey.OnQuest(id) and " [in log]" or " [unfinished]") end;return table.concat(out,"; ") end
            if row.meta then
                M.Line("Minimum level: "..tostring(row.meta.min or "not supplied"))
                if #row.all>0 then M.Line("Complete all: "..names(row.all)) end
                if #row.any>0 then M.Line("Complete any one: "..names(row.any)) end
                if #row.all==0 and #row.any==0 then M.Line("No prerequisite quests are listed in the available source. This does not prove the absence of additional server requirements.","GameFontHighlightSmall") end
                if row.meta.parent then local id=row.meta.parent;local meta=ns.Data.questSupport.meta[id]
                    M.Line("Must be in your quest log: "..(meta and meta.name or "Quest #"..id)..(ns.Journey.OnQuest(id) and " [in log]" or " [not confirmed in log]"))
                end
                if #(row.meta.excl or {})>0 then M.Line("Exclusive quest choices: "..names(row.meta.excl)) end
                if row.meta.skill then M.Line("Profession required: "..R.Skill(row.meta.skill)) end
                if row.meta.minRep then M.Line("Reputation: "..R.Reputation(row.meta.minRep,true)) end
                if row.meta.maxRep then M.Line("Reputation: "..R.Reputation(row.meta.maxRep,false)) end
            else M.Line("Prerequisite metadata is unavailable for this quest.") end
            if ns.Journey.OnQuest(row.id) and type(QuestMapFrame_OpenToQuestDetails)=="function" then M.Action("Open this quest",function() QuestMapFrame_OpenToQuestDetails(row.id) end,220) end
        end
        if quests.limited then M.Line("Chain traversal reached its safety limit; remaining links are not assumed complete.") end
    end
    local preparation=R.Guide(record)
    if #preparation>0 then
        local index=M.Choose(preparation,"requirementGuideQuest","Source guide preparation (ordered)",function(row,i) return i..". "..(row.goal.title or "Quest #"..row.goal.quest).." - "..row.status end)
        if index then local row=preparation[index];local goal=row.goal
            M.Line(row.route,"GameFontNormal");M.Line((goal.title or "Quest #"..goal.quest).." | "..row.status)
            if goal.npcName or goal.objName then M.Line("Pickup: "..(goal.npcName or goal.objName)) end
            if goal.note then M.Line(goal.note) end
            if goal.minLevel then M.Line("Source minimum level: "..goal.minLevel) end
            if goal.map and goal.x and goal.y then M.Action("Show this pickup location",function() ns.Journey.GoalWaypoint(goal) end,260) end
            M.Line("This is the authored guide order, separate from verified prerequisite links. Reading it does not complete or skip quests.","GameFontHighlightSmall")
        end
    end
    local recipes=R.Recipes(record)
    if #recipes>0 then
        local index=M.Choose(recipes,"requirementRecipe","Crafting recipes",function(row) return (row.profession or "Profession")..": "..row.name.." (#"..row.spell..")" end)
        if index then local recipe=recipes[index]
            M.Line(recipe.name.." - "..(recipe.profession or "Native recipe"),"GameFontNormal")
            M.Line(recipe.native and "Materials from the matching native schematic" or "A matching native schematic is unavailable.","GameFontHighlightSmall")
            M.Line(recipe.learned and "Recipe known by this character" or "Learning status unknown")
            M.Line("Materials per craft"..(recipe.output and recipe.output>0 and " | Base output: "..recipe.output or ""),"GameFontNormal")
            if recipe.materialIncomplete then M.Line("Some native reagent slots are unreadable. This material list is incomplete; refresh after the profession data loads.","GameFontNormal") end
            if #recipe.materialGroups==0 then M.Line("Materials are not readable. Open this profession and refresh; no zero-material cost is assumed.")
            elseif #recipe.materialGroups<=8 then for _,row in ipairs(recipe.materialGroups) do M.Line(R.Material(row)) end
            else local selected=M.Choose(recipe.materialGroups,"requirementMaterial","Material groups",R.Material);if selected then M.Line(R.Material(recipe.materialGroups[selected])) end end
            M.Line("Alternate reagents are choices, not a requirement to buy every option. Carried counts exclude recorded storage snapshots. Recipe discovery does not prove vendor stock or profession eligibility.","GameFontHighlightSmall")
        end
    elseif record.sourceKind=="crafted" or record.recipe then M.Line("No matching recipe/material data is available for this client build. The plan-item ID is not treated as a recipe spell.","GameFontNormal") end
    if #quests==0 and #recipes==0 then M.Line("No quest or crafting relationship is listed for this acquisition source.") end
    M.Action("Refresh prerequisite/material data",function() M.Render() end,320)
end
