local addonName, ns = ...
local J=ns.Journey
-- A committed automatic trip temporarily uses manual mode. An explicit guide
-- selection clears the commitment, so it must never be mistaken for this case.
function J.AutomaticContext()
    if not ns.char then return false end
    if ns.char.routeMode=="auto" then return true end
    local trip,back=ns.char.itinerary,ns.char.routeReturn
    return ns.char.routeMode=="manual" and trip and trip.route==ns.char.route and back and back.mode=="auto" or false
end
function J.NormalizeReturns()
    if not ns.char then return end
    local original=ns.char.routeReturn
    if J.returnChecked==original then return end
    local seen,nodes,visited={},{},{};local node=original;local changed=false
    while type(node)=="table" and not visited[node] do
        visited[node]=true
        local key=tostring(node.id)..":"..tostring(node.mode)
        if node.id and not seen[key] then
            seen[key]=true;nodes[#nodes+1]={id=node.id,mode=node.mode}
        else changed=true end
        node=node.parent
    end
    if node then changed=true end
    if changed then
        -- Preserve the original sequence as plain records, including repeated
        -- contexts. Do not recursively copy a possibly cyclic legacy stack.
        if not ns.char.returnStackArchive then
            local archive={};node=original;visited={}
            while type(node)=="table" and not visited[node] do
                visited[node]=true;archive[#archive+1]={id=node.id,mode=node.mode};node=node.parent
            end
            ns.char.returnStackArchive=archive
        end
        local head
        for i=#nodes,1,-1 do nodes[i].parent=head;head=nodes[i] end
        ns.char.routeReturn=head
    end
    J.returnChecked=ns.char.routeReturn
end
function J.PushReturn(id,mode)
    if not id then return end
    local back=ns.char.routeReturn
    if not back or back.id~=id or back.mode~=mode then ns.char.routeReturn={id=id,mode=mode,parent=back} end
    J.NormalizeReturns()
end
local load=ns.LoadCharacterStore
function ns.LoadCharacterStore(...) load(...);J.returnChecked=nil;J.NormalizeReturns() end

ns.Listen("EXPERIENCE_CHANGED",function()
    if not ns.char or ns.char.journeyPaused then return end
    local goal=ns.Navigation and ns.Navigation.goal
    if goal and goal.t~="level" then return end
    ns.After("journeyXPProgress",function()
        if not goal or J.GoalDone(goal) then J.Advance() end
        ns.Emit("STATE_CHANGED","journey")
    end)
end)
