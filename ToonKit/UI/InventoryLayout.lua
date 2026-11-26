local addonName, ns = ...
local L={};ns.InventoryLayout=L
-- Complete category columns. The least occupied column receives the next group,
-- so small groups pack vertically instead of leaving shelf-sized empty blocks.
-- Every source slot has exactly one entry and item cells retain natural size.
function L.Single(groups,categories,o)
    local best
    local visible=0;for _,category in ipairs(categories) do if #(groups[category.id] or {})>0 and o.visible(category.id) then visible=visible+1 end end
    local maxLanes=o.grouped and math.max(1,math.min(6,visible)) or 1
    if o.grouped and not o.packed then maxLanes=math.max(1,math.min(visible,o.lanes or 2)) end
    local minLanes=o.grouped and not o.packed and maxLanes or 1
    if o.stable then
        maxLanes=o.grouped and math.max(1,math.min(4,o.lanes or 2)) or 1
        minLanes=maxLanes
    end
    local minCells,maxCells=3,24
    if o.stable then minCells=math.max(3,math.ceil((o.preferredColumns or 12)/maxLanes));maxCells=minCells end
    for lanes=minLanes,maxLanes do for cells=minCells,maxCells do
        local gutter=12;local width=lanes*cells*o.step+(lanes-1)*gutter
        local bottoms={};for lane=1,lanes do bottoms[lane]=0 end
        local entries={};local height=1
        for categoryIndex,category in ipairs(categories) do
            local items=groups[category.id] or {}
            if #items>0 and o.visible(category.id) then
                local lane=1
                if o.stable and o.assignments and type(o.assignments[category.id])=="number" and o.assignments[category.id]>=1 and o.assignments[category.id]<=lanes then lane=o.assignments[category.id]
                else
                    for n=2,lanes do if bottoms[n]<bottoms[lane] then lane=n end end
                    if o.stable and o.assignments then o.assignments[category.id]=lane end
                end
                local collapsed=o.collapsed(category.id)
                local title=o.title(category.id,#items,false,collapsed)
                local heading=o.measure(title,cells*o.step-8)
                local rows=collapsed and 0 or math.ceil(#items/cells)
                local h=heading+2+rows*o.step+3
                entries[#entries+1]={category=category.id,items=items,first=1,last=#items,cells=cells,
                    x=(lane-1)*(cells*o.step+gutter),y=bottoms[lane],width=cells*o.step-4,
                    heading=heading,height=h,title=title,collapsed=collapsed}
                bottoms[lane]=bottoms[lane]+h+6;height=math.max(height,bottoms[lane]-6)
            end
        end
        local fit=math.min(1,o.width/math.max(1,width),o.height/math.max(1,height))
        local penalty=math.abs(lanes-(o.lanes or 2))*20+math.abs(lanes*cells-(o.preferredColumns or 12))*2
        local waste=width*height
        local preference=penalty+waste/100000
        if not best or fit>best.scale+.000001 or math.abs(fit-best.scale)<.000001 and preference<best.preference then
            best={entries=entries,width=width+6,height=height,scale=fit,columns=lanes*cells,lanes=lanes,preference=preference}
        end
    end end
    return best
end
