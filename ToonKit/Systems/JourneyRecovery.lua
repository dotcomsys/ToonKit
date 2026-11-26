local addonName, ns = ...
local J=ns.Journey
local action=J.Action
-- Recover only the current unfinished quest. This does not advance a cursor,
-- resurrect an explicit skip, or reorder unrelated route stops.
function J.RecoverTurnIn(goal,step,index)
    if not goal or goal.t~="turnin" or not goal.quest or not J.OnQuest(goal.quest)
        or J.QuestDone(goal.quest) or J.ReadyToTurnIn(goal.quest) then return end
    local native=ns.API.Call("C_QuestLog","GetQuestObjectives",goal.quest)
    if type(native)~="table" then return end
    local route=J.Selected();local found,seen={},{};local authored=false
    for _,sourceStep in ipairs(route.steps or {}) do
        if J.Applies(sourceStep.only) then for _,source in ipairs(sourceStep.goals or {}) do
            if source.quest==goal.quest and J.Applies(source.only) and not J.OptionalDeferred(source)
                and (source.t=="kill" or source.t=="collect" or source.t=="complete" or source.t=="interact") then
                authored=true
                if not J.GoalDone(source) and not J.Blocked(source) then
                local key=source.oi or source.item or source.id
                if key and not seen[key] then seen[key]=true;found[#found+1]=source end
                end
            end
        end end
    end
    if #found==0 and not authored then
        for oi,objective in ipairs(native) do if ns.Safe(objective.finished)==false then
            local nativeGoal={id="recovery:"..goal.quest..":"..oi,t="complete",quest=goal.quest,oi=oi,nativeText=true,title=ns.Safe(objective.text,"Finish this quest objective")}
            if not J.GoalDone(nativeGoal) then found[#found+1]=nativeGoal end
        end end
    end
    if #found==0 then return end
    local recovery=ns.Copy(step or {});recovery.text="Finish "..(goal.title or "the quest").." before returning";recovery.goals={}
    for _,source in ipairs(found) do
        local copy=ns.Copy(source);copy.note=(copy.note and copy.note.."\n" or "").."Unfinished quest: complete this before the turn-in."
        recovery.goals[#recovery.goals+1]=copy
    end
    local current=recovery.goals[1];local focus=J.focusGoal
    if focus and focus.route==ns.char.route and focus.index==index then
        for _,candidate in ipairs(recovery.goals) do if candidate.id and candidate.id==focus.id then current=candidate end end
    end
    return current,recovery,index
end
function J.Action()
    local focus=J.focusGoal
    local goal,step,index=action()
    local retained=J.focusGoal
    if focus and focus.route==ns.char.route and focus.index==index then J.focusGoal=focus end
    local recovered,recovery,position=J.RecoverTurnIn(goal,step,index)
    if recovered then return recovered,recovery,position end
    J.focusGoal=retained
    return goal,step,index
end
