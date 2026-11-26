local addonName, ns = ...
local S={};ns.Services=S
local function read(name,...)
    local f=_G[name];if type(f)~="function" then return end
    local ok,a,b=pcall(f,...);if ok then return ns.Safe(a),ns.Safe(b) end
end
local function numeric(v) return type(v)=="number" and v==v and v>=0 and v<math.huge end
function S.Refresh()
    local lowest,total,current=nil,0,0
    for _,slot in ipairs(ns.Data.slots) do
        local value,maximum=read("GetInventoryItemDurability",slot[1])
        if numeric(value) and numeric(maximum) and maximum>0 then
            lowest=math.min(lowest or 1,value/maximum);total=total+maximum;current=current+value
        end
    end
    S.lowest=lowest;S.durability=total>0 and current/total or nil
    local stacks=0
    for _,item in ipairs(ns.State.bags or {}) do
        local quality=item.quality or item.info and item.info.quality
        local quest=type(item.quest)=="table" and (ns.Safe(item.quest.isQuestItem,false) or ns.Safe(item.quest.questID))
        local candidate=item.id and quality==0 and not item.locked and not quest
            and item.info and item.info.classID~=12 and (item.info.sellPrice or 0)>0
        local needed=candidate and ns.QuestSupplies and #ns.QuestSupplies.ForItem(item.id)>0
        if candidate and not needed then stacks=stacks+1 end
    end
    S.junkStacks=stacks
end
function S.Reminder()
    local parts={}
    if type(ns.State.free)=="number" and (ns.State.capacity or 0)>0 and ns.State.free<=4 then
        parts[#parts+1]=ns.State.free==0 and "Bags full: sell unneeded items at a merchant." or ns.State.free.." bag slots free: clear space at your next vendor stop."
    end
    if S.lowest and S.lowest<=.25 then parts[#parts+1]="Equipment needs repair: lowest item "..math.floor(S.lowest*100).."%. Visit a merchant who offers repairs." end
    return #parts>0 and table.concat(parts,"\n") or nil
end
function S.HearthHint(goal)
    local lines={}
    local bind=read("GetBindLocation")
    if goal.t=="sethome" then
        lines[#lines+1]="Speak to the innkeeper and choose Make this inn your home. A matching native bind is detected; use Done if it cannot be matched."
    else
        lines[#lines+1]="Use your Hearthstone to return to "..(goal.location or "the route's stated destination")..". A successful cast and matching arrival are detected; use Done if destination data is unavailable."
    end
    if type(bind)=="string" and bind~="" then lines[#lines+1]="Current hearth bind: "..bind.."." end
    if goal.t=="hearth" then
        local stone
        for _,item in ipairs(ns.State.bags or {}) do if item.id==6948 then stone=item;break end end
        if not stone then lines[#lines+1]="No Hearthstone found in carried bags. Follow the route's alternate directions, if provided."
        else
            local start,duration,enabled=ns.API.Call("C_Container","GetContainerItemCooldown",stone.bag,stone.slot)
            start,duration,enabled=ns.Safe(start),ns.Safe(duration),ns.Safe(enabled)
            local time=read("GetTime")
            if numeric(start) and numeric(duration) and numeric(time) then
                local remaining=math.max(0,start+duration-time)
                if enabled==0 or enabled==false then lines[#lines+1]="Hearthstone cooldown is not currently enabled."
                elseif enabled==1 or enabled==true then lines[#lines+1]=remaining>0 and ("Hearthstone cooldown: "..math.ceil(remaining/60).." min remaining.") or "Hearthstone is ready." end
            end
        end
        lines[#lines+1]="Check your bind against the route destination before using it."
    end
    return table.concat(lines,"\n")
end
function S.Hint(goal)
    if not goal then return end
    if goal.t=="sethome" or goal.t=="hearth" then return S.HearthHint(goal) end
    if goal.t=="vendor" then
        local lines={"Sell items you no longer need. Keep quest supplies and items you intend to use."}
        if S.junkStacks and S.junkStacks>0 then lines[#lines+1]=S.junkStacks.." gray sellable stacks currently have no known quest-supply requirement." end
        if S.durability then lines[#lines+1]="Equipment durability: "..math.floor(S.durability*100).."% overall; lowest item "..math.floor(S.lowest*100).."%." end
        local repair=read("CanMerchantRepair")
        lines[#lines+1]=repair==true and "This merchant offers repairs. Repair damaged equipment before continuing." or "Repair damaged equipment here if this merchant offers repairs."
        lines[#lines+1]="Confirm when finished. Nothing is sold or repaired automatically."
        return table.concat(lines,"\n")
    end
end
ns.Listen("STATE_CHANGED",function(kind) if ns.Changed(kind,"inventory","quests","identity") then ns.After("journeyServices",S.Refresh) end end)
for _,event in ipairs({"UPDATE_INVENTORY_DURABILITY","HEARTHSTONE_BOUND","MERCHANT_SHOW","MERCHANT_CLOSED"}) do
    ns.On(event,function() ns.After("journeyServices",function() if ns.char then S.Refresh();ns.Emit("SERVICES_CHANGED") end end) end)
end

-- Only the visible hearth task needs its cooldown wording refreshed. Ordinary
-- item/GCD cooldowns do not rescan durability, bags or quest supplies.
ns.On("BAG_UPDATE_COOLDOWN",function()
    local f=ns.Guide;local goal=f and f.goal
    if f and f:IsShown() and goal and goal.t=="hearth" then
        ns.After("hearthHint",function() ns.Emit("SERVICES_CHANGED") end,1)
    end
end)
