local addonName, ns = ...
local T=ns.Travel
local function same(a,b) return type(a)=="string" and type(b)=="string" and a:lower()==b:lower() end
function T.Project(point,map)
    if point.map==map then return point end
    if not CreateVector2D then return end
    local continent,world=ns.API.Call("C_Map","GetWorldPosFromMapPos",point.map,CreateVector2D(point.x,point.y))
    if not world or type(ns.Safe(continent))~="number" then return end
    local target,pos=ns.API.Call("C_Map","GetMapPosFromWorldPos",continent,world,map)
    if ns.Safe(target)~=map or not pos or not pos.GetXY then return end
    local ok,x,y=pcall(pos.GetXY,pos);x,y=ns.Safe(x),ns.Safe(y)
    if ok and type(x)=="number" and type(y)=="number" and x>=0 and x<=1 and y>=0 and y<=1 then return {map=map,x=x,y=y,native=true} end
end
function T.NodePoint(record,map)
    if record.points and record.points[map] then return record.points[map] end
    for _,p in pairs(record.points or {}) do local projected=T.Project(p,map);if projected then return projected end end
end
function T.CaptureFlights()
    if not ns.char then return end
    local map,x,y=ns.API.Position();local seen={};local states=Enum and Enum.FlightPathState
    if not states then return end
    for depth=1,8 do
        if not map or seen[map] then break end;seen[map]=true
        local rows=ns.API.Call("C_TaxiMap","GetAllTaxiNodes",map)
        local origin,reachable
        if type(rows)=="table" then
            reachable={}
            for _,raw in ipairs(rows) do
                local id,state=ns.Safe(raw.nodeID),ns.Safe(raw.state)
                if type(id)=="number" then
                    if state==states.Current or state==states.Reachable then
                        local name=ns.Safe(raw.name)
                        if type(name)=="string" then
                            ns.char.travelNodes=ns.char.travelNodes or {}
                            local record=ns.char.travelNodes[id] or {points={}}
                            record.name=name;record.known=true;record.points=record.points or {}
                            local position=ns.Safe(raw.position)
                            if position and position.GetXY then
                                local ok,px,py=pcall(position.GetXY,position);px,py=ns.Safe(px),ns.Safe(py)
                                if ok and type(px)=="number" and type(py)=="number" and px>=0 and px<=1 and py>=0 and py<=1 then record.points[map]={map=map,x=px,y=py,native=true} end
                            end
                            ns.char.travelNodes[id]=record
                        end
                    end
                    if state==states.Current then origin=id end
                    if state==states.Reachable then reachable[id]=true end
                end
            end
            if origin then
                ns.char.travelFlights=ns.char.travelFlights or {};ns.char.travelFlights[origin]=reachable
                local current=ns.API.Position();local record=(ns.char.travelNodes or {})[origin]
                if record and type(x)=="number" and type(y)=="number" then record.points=record.points or {};record.points[current]={map=current,x=x,y=y,native=true} end
            end
        end
        local info=ns.API.Call("C_Map","GetMapInfo",map);map=type(info)=="table" and ns.Safe(info.parentMapID) or nil
    end
    T.nodeRevision=(T.nodeRevision or 0)+1;T.optionCache=nil;ns.Emit("STATE_CHANGED")
end
ns.On("TAXIMAP_OPENED",function() ns.After("transportChoices",T.CaptureFlights) end)
function T.HomePoint(bind)
    if type(bind)~="string" or bind=="" then return end
    local home=ns.char.homeBindObservation
    if home and same(home.name,bind) and type(home.map)=="number" and type(home.x)=="number" and type(home.y)=="number" then return home end
    if not T.homePoints then
        T.homePoints={}
        for _,r in ipairs(ns.Data.routes) do for _,s in ipairs(r.steps or {}) do for _,g in ipairs(s.goals or {}) do
            if g.t=="sethome" and type(g.location)=="string" and g.map and g.x and g.y then
                local key=g.location:lower();local old=T.homePoints[key]
                if not old then T.homePoints[key]={name=g.location,map=g.map,x=g.x,y=g.y}
                elseif old.map~=g.map then old.ambiguous=true end
            end
        end end end
    end
    local point=type(bind)=="string" and T.homePoints[bind:lower()]
    if point and not point.ambiguous then return point end
end
function T.Transport(destination,current)
    if not ns.char or not destination or not current then return end
    local bind=type(GetBindLocation)=="function" and ns.Safe(GetBindLocation())
    local home=T.HomePoint(bind)
    local hearthUseful=current~=destination.map
    if not hearthUseful and home and destination.x and destination.y then
        local _,x,y=ns.API.Position()
        if type(x)=="number" and type(y)=="number" then
            hearthUseful=(x-destination.x)^2+(y-destination.y)^2>.16^2
                and (home.x-destination.x)^2+(home.y-destination.y)^2<.06^2
        end
    end
    if hearthUseful and home and home.map==destination.map and same(home.name,bind) then
        for _,item in ipairs(ns.State.bags or {}) do if item.id==6948 then
            local start,duration,enabled=ns.API.Call("C_Container","GetContainerItemCooldown",item.bag,item.slot)
            start,duration,enabled=ns.Safe(start),ns.Safe(duration),ns.Safe(enabled)
            local now=type(GetTime)=="function" and ns.Safe(GetTime())
            if type(start)=="number" and type(duration)=="number" and type(now)=="number" and (enabled==1 or enabled==true) and start+duration<=now then
                return {kind="hearth",title="Hearthstone to "..bind,text="Use your Hearthstone to return to "..bind..". Then continue to the quest destination.",nextMap=home.map,point=home}
            end
        end end
    end
    if current==destination.map then return end
    local key=current..":"..destination.map..":"..tostring(T.nodeRevision or 0)
    if not T.optionCache or T.optionCache.key~=key then
        local origins,targets={},{}
        for id,record in pairs(ns.char.travelNodes or {}) do if record.known then
            local p=T.NodePoint(record,current);if p then origins[#origins+1]={id=id,record=record,point=p} end
            p=T.NodePoint(record,destination.map);if p then targets[#targets+1]={id=id,record=record,point=p} end
        end end
        T.optionCache={key=key,origins=origins,targets=targets}
    end
    local _,x,y=ns.API.Position();local best,score
    for _,a in ipairs(T.optionCache.origins) do for _,b in ipairs(T.optionCache.targets) do if a.id~=b.id then
        local cost=(type(x)=="number" and (a.point.x-x)^2+(a.point.y-y)^2 or 0)
            +(destination.x and (b.point.x-destination.x)^2+(b.point.y-destination.y)^2 or 0)
        local verified=(ns.char.travelFlights or {})[a.id] and ns.char.travelFlights[a.id][b.id]
        local choice={kind="fly",title="Fly to "..b.record.name,nextMap=destination.map,point=a.point,
            text="Go to the flight master at "..a.record.name.." and fly to "..b.record.name..". Then continue to the quest destination."}
        if verified and (not score or cost<score) then best,score=choice,cost end
    end end end
    return best
end
function T.Directions(destination,current)
    local option=T.Transport(destination,current)
    if option then option.itinerary=option.text;return option end
end
local connection=T.Connection
function T.Connection(destination,goal)
    local current=ns.API.Position();local kind=goal and goal.t
    if kind~="fly" and kind~="hearth" and kind~="boat" and kind~="zeppelin" and kind~="portal" then
        local option=T.Transport(destination,current)
        if option then return option.point,option.text end
    end
    return connection(destination,goal)
end
function T.Markers()
    return ns.Data.transportPOIs
end
