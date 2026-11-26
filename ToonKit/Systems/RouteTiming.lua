local addonName, ns = ...
local R={};ns.RouteTiming=R
ns.Defaults.routeTiming=true
local function time()
    local value=type(GetTime)=="function" and ns.Safe(GetTime())
    return type(value)=="number" and value or nil
end
function R.Finish(reason)
    local active=R.active;R.active=nil
    if not active or not ns.char then return end
    local clock=time();if not clock or clock<active.started then return end
    active.seconds=math.floor(clock-active.started);active.started=nil;active.reason=reason
    if active.seconds<1 then return end
    active.goal=nil
    ns.char.routeTimings=ns.char.routeTimings or {};local rows=ns.char.routeTimings
    rows[#rows+1]=active
    while #rows>400 do table.remove(rows,1) end
end
function R.Observe()
    if not ns.char or not ns.db then return end
    if R.suspended or not ns.db.settings.routeTiming or not ns.db.settings.guide or ns.char.journeyPaused or not ns.db.settings.modules.journey then R.Finish("paused");return end
    local goal,step,index=ns.Journey.Action();local route=ns.Journey.Selected()
    if not goal or not route or not index then R.Finish("route changed");return end
    local spec=ns.Talents.specKey or "unresolved"
    local key=table.concat({route.id,index,goal.id or goal.t,ns.State.level or 1,spec,ns.State.role or "unknown",ns.char.journeyGoal or "casual"},":")
    if R.active and R.active.key==key then return end
    if R.active then
        local done,evidence=ns.Journey.GoalDone(R.active.goal)
        R.Finish(done and (evidence=="skipped" and "skipped" or "completed") or "action changed")
    end
    local clock=time();if not clock then return end
    local stamp=type(GetServerTime)=="function" and ns.Safe(GetServerTime())
    R.active={key=key,route=route.id,name=route.name,index=index,title=ns.Journey.GoalText(goal),
        class=ns.State.class,role=ns.State.role,spec=spec,level=ns.State.level,journeyGoal=ns.char.journeyGoal or "casual",started=clock,recorded=type(stamp)=="number" and stamp or 0,
        goal=ns.Copy(goal),deaths=0}
end
function R.Summary()
    local summaries={}
    for _,row in ipairs(ns.char.routeTimings or {}) do
        local key=table.concat({row.route,row.class or "unknown",row.spec or "unresolved",row.role or "unknown",row.level,row.journeyGoal or "casual"},":")
        local record=summaries[key]
        if not record then record={key=key,name=row.name,class=row.class,spec=row.spec,role=row.role,level=row.level,journeyGoal=row.journeyGoal or "casual",seconds=0,actions=0,completed=0,skipped=0,deaths=0};summaries[key]=record end
        record.seconds=record.seconds+row.seconds;record.actions=record.actions+1;record.deaths=record.deaths+(row.deaths or 0)
        if row.reason=="completed" then record.completed=record.completed+1 elseif row.reason=="skipped" then record.skipped=record.skipped+1 end
    end
    local rows={};for _,row in pairs(summaries) do rows[#rows+1]=row end
    table.sort(rows,function(a,b) if a.level~=b.level then return a.level<b.level end;return a.key<b.key end)
    return rows
end
ns.Listen("STATE_CHANGED",function(kind) if ns.Changed(kind,"inventory","quests","identity","talents","journey") then ns.After("routeTiming",R.Observe) end end)
ns.Listen("SETTINGS_CHANGED",function() ns.After("routeTiming",R.Observe) end)
ns.On("PLAYER_LOGIN",function() R.active=nil;R.suspended=false;ns.After("routeTiming",R.Observe) end)
ns.On("PLAYER_LOGOUT",function() R.Finish("logout") end)
ns.On("PLAYER_LEAVING_WORLD",function() R.suspended=true;R.Finish("loading") end)
ns.On("PLAYER_ENTERING_WORLD",function() R.suspended=false;ns.After("routeTiming",R.Observe) end)
ns.On("PLAYER_DEAD",function() if R.active then R.active.deaths=R.active.deaths+1 end end)
