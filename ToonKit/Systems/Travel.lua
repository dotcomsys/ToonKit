local addonName, ns = ...
local T={};ns.Travel=T
-- Read native map nodes, scoped to this character. Never infer a flight connection.
function T.Scan()
    if not ns.char then return end
    ns.char.travelNodes=ns.char.travelNodes or {}
    local map=ns.Safe(ns.API.Call("C_Map","GetBestMapForUnit","player"));local visited={};local changed=false
    for depth=1,8 do
        if type(map)~="number" or map<=0 or visited[map] then break end;visited[map]=true
        local rows=ns.API.Call("C_TaxiMap","GetTaxiNodesForMap",map)
        if type(rows)=="table" then for _,raw in ipairs(rows) do
            local id,name,unknown,faction=ns.Safe(raw.nodeID),ns.Safe(raw.name),ns.Safe(raw.isUndiscovered),ns.Safe(raw.faction)
            local factions=Enum and Enum.FlightPathFaction
            local permitted=factions and (faction==factions.Neutral or ns.State.faction=="Alliance" and faction==factions.Alliance or ns.State.faction=="Horde" and faction==factions.Horde)
            if type(id)=="number" and type(name)=="string" and permitted and type(unknown)=="boolean" then
                local record=ns.char.travelNodes[id] or {points={}}
                if record.known~=not unknown or record.name~=name then changed=true end
                record.name=name;record.known=not unknown;record.points=record.points or {}
                local point=ns.Safe(raw.position)
                if point and point.GetXY then
                    local ok,x,y=pcall(point.GetXY,point);x,y=ns.Safe(x),ns.Safe(y)
                    if ok and type(x)=="number" and type(y)=="number" and x>=0 and x<=1 and y>=0 and y<=1 then
                        local previous=record.points[map];if not previous or previous.x~=x or previous.y~=y then changed=true end
                        record.points[map]={map=map,x=x,y=y,native=true}
                    end
                end
                ns.char.travelNodes[id]=record
            end
        end end
        local info=ns.API.Call("C_Map","GetMapInfo",map);map=type(info)=="table" and ns.Safe(info.parentMapID) or nil
    end
    if changed then T.nodeRevision=(T.nodeRevision or 0)+1;T.optionCache=nil;if ns.Journey then ns.Journey.Advance() end;ns.Emit("STATE_CHANGED") end
end
function T.Known(node)
    local record=ns.char and ns.char.travelNodes and ns.char.travelNodes[node]
    return record and record.known
end
function T.Point(goal)
    local record=goal and goal.node and ns.char and ns.char.travelNodes and ns.char.travelNodes[goal.node]
    if not record then return end
    local current=ns.API.Position();if record.points[current] then return record.points[current] end
    local maps={};for map in pairs(record.points) do maps[#maps+1]=map end;table.sort(maps)
    return maps[1] and record.points[maps[1]] or nil
end
function T.KnownLocation(goal)
    if not goal or not goal.map or type(goal.location)~="string" then return false end
    local wanted=goal.location:lower()
    for _,record in pairs(ns.char.travelNodes or {}) do
        local name=type(record.name)=="string" and record.name:match("^([^,]+)")
        if record.known==true and name and name:lower()==wanted and record.points and record.points[goal.map] then return true end
    end
    return false
end
function T.Hint(goal)
    if not goal or not goal.node or (goal.t~="fly" and goal.t~="getfp") then return end
    local known=T.Known(goal.node)
    if known==true then return "This character has learned the destination flight path." end
    if known==false then return "The client reports this flight path as undiscovered. Follow the route's written instructions before attempting the flight." end
    return "Flight-path status is unknown. Speak to a flight master to refresh native flight information."
end
for _,event in ipairs({"PLAYER_ENTERING_WORLD","TAXIMAP_OPENED","TAXI_NODE_STATUS_CHANGED"}) do
    ns.On(event,function() ns.After("travelNodes",T.Scan) end)
end


-- Zone routing uses native map links and continuous, observed ground crossings.
-- No straight-line border intersections, invented roads or inferred taxi edges.
local function valid(p)
    return p and type(p.map)=="number" and type(p.x)=="number" and type(p.y)=="number"
        and p.x>=0 and p.x<=1 and p.y>=0 and p.y<=1
end
local zoneTypes={}
local function zone(map)
    if zoneTypes[map]~=nil then return zoneTypes[map] end
    local info=ns.API.Call("C_Map","GetMapInfo",map)
    local result=type(info)=="table" and ns.Safe(info.mapType)==3
    if type(info)=="table" then zoneTypes[map]=result end
    return result
end
local function mapName(map)
    local info=ns.API.Call("C_Map","GetMapInfo",map)
    return type(info)=="table" and ns.Safe(info.name) or "Map #"..tostring(map)
end
local function links(map)
    local result={}
    for _,raw in ipairs(ns.API.Call("C_Map","GetMapLinksForMap",map) or {}) do
        local target,position=ns.Safe(raw.linkedUiMapID),ns.Safe(raw.position)
        if type(target)=="number" and target~=map and position and position.GetXY then
            local ok,x,y=pcall(position.GetXY,position);x,y=ns.Safe(x),ns.Safe(y)
            local point={map=map,x=x,y=y,to=target,native=true,connection=true,label=ns.Safe(raw.name),provenance="Native map connection"}
            if ok and valid(point) then result[#result+1]=point end
        end
    end
    for _,point in ipairs(ns.char and ns.char.zoneCrossings and ns.char.zoneCrossings[map] or {}) do
        if valid(point) and type(point.to)=="number" then result[#result+1]=point end
    end
    table.sort(result,function(a,b) if a.to~=b.to then return a.to<b.to end;if a.x~=b.x then return a.x<b.x end;return a.y<b.y end)
    return result
end
function T.Connection(destination,goal)
    local current,x,y=ns.API.Position()
    if not destination or not current or current==destination.map then return destination end
    -- Preserve explicit boat/hearth/taxi instructions and native arrival evidence.
    local kind=goal and goal.t
    if kind=="fly" or kind=="hearth" or kind=="boat" or kind=="zeppelin" or kind=="portal" then return destination end
    local key=tostring(current)..":"..tostring(destination.map)..":"..tostring(T.connectionRevision or 0)
    local now=type(GetTime)=="function" and ns.Safe(GetTime()) or 0
    local cached=T.connectionCache
    if not cached or cached.key~=key or now-cached.time>30 then
        local queue,head,seen,found={{map=current}},1,{[current]=true},nil
        while head<=#queue and head<=64 do
            local node=queue[head];head=head+1
            local edges=links(node.map)
            if node.map==current and type(x)=="number" and type(y)=="number" then
                table.sort(edges,function(a,b) return (a.x-x)^2+(a.y-y)^2 < (b.x-x)^2+(b.y-y)^2 end)
            end
            for _,point in ipairs(edges) do
                local first=node.first or point
                if point.to==destination.map then found=first;break end
                if not seen[point.to] and #queue<64 then seen[point.to]=true;queue[#queue+1]={map=point.to,first=first} end
            end
            if found then break end
        end
        cached={key=key,time=now,point=found};T.connectionCache=cached
    end
    if not cached.point then
        return destination,"Travel to "..mapName(destination.map).." from "..mapName(current)..". No verified connection directions are available for this trip yet. The map pin marks the final objective."
    end
    local p=cached.point
    return p,"Travel via "..(p.label or mapName(p.to)).." toward "..mapName(destination.map)..". "..(p.provenance or "Observed ground crossing").."; the quest remains unfinished until its own objective is done."
end
function T.ObserveCrossing()
    if not ns.char then return end
    local map,x,y=ns.API.Position();local now=type(GetTime)=="function" and ns.Safe(GetTime())
    local ground=type(IsFlying)=="function" and ns.Safe(IsFlying())==false
        and type(UnitOnTaxi)=="function" and ns.Safe(UnitOnTaxi("player"))==false
        and type(IsInInstance)=="function" and ns.Safe(IsInInstance())==false
    local point={map=map,x=x,y=y,time=now}
    if not ground or not now or not valid(point) or not zone(map) then T.previousGround=nil;return end
    local old=T.previousGround;T.previousGround=point
    if not old or old.map==map or now-old.time>2 or now<old.time then return end
    -- Project the new position into the previous map to reject hearths, portals
    -- and distant jumps. A map change alone is never crossing evidence.
    local projected=ns.API.Call("C_Map","GetPlayerMapPosition",old.map,"player")
    if not projected or not projected.GetXY then return end
    local ok,px,py=pcall(projected.GetXY,projected);px,py=ns.Safe(px),ns.Safe(py)
    local w,h=ns.API.Call("C_Map","GetMapWorldSize",old.map);w,h=ns.Safe(w),ns.Safe(h)
    if not ok or type(px)~="number" or type(py)~="number" or type(w)~="number" or type(h)~="number" or w<=0 or h<=0 then return end
    if ((px-old.x)*w)^2+((py-old.y)*h)^2>80^2 then return end
    ns.char.zoneCrossings=ns.char.zoneCrossings or {}
    local function save(from,to)
        local rows=ns.char.zoneCrossings[from.map] or {};ns.char.zoneCrossings[from.map]=rows
        for _,p in ipairs(rows) do if p.to==to.map and math.abs(p.x-from.x)<.015 and math.abs(p.y-from.y)<.015 then return end end
        if #rows>=24 then return end
        rows[#rows+1]={map=from.map,x=from.x,y=from.y,to=to.map,connection=true,observed=true,provenance="Observed nearby ground crossing"}
    end
    save(old,point);save(point,old);T.connectionRevision=(T.connectionRevision or 0)+1;T.connectionCache=nil
end
for _,event in ipairs({"ZONE_CHANGED_NEW_AREA","ZONE_CHANGED","PLAYER_ENTERING_WORLD"}) do
    ns.On(event,function() T.connectionCache=nil;ns.After("zoneConnection",function() ns.Emit("STATE_CHANGED") end) end)
end
