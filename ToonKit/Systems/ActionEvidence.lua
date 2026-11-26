local addonName, ns = ...
-- Observe native actions for the currently armed instruction only. Never perform
-- training, item use, binding or taxi selection on the player's behalf.
local A={};ns.ActionEvidence=A
local function read(name,...)
    local f=_G[name];if type(f)~="function" then return end
    local ok,value=pcall(f,...);if ok then return ns.Safe(value) end
end
local function same(a,b)
    return type(a)=="string" and type(b)=="string" and a~="" and a:lower()==b:lower()
end
local function npcID()
    local guid=read("UnitGUID","npc")
    return type(guid)=="string" and tonumber(guid:match("^[^-]+%-[^-]+%-[^-]+%-[^-]+%-[^-]+%-(%d+)%-")) or nil
end
local function matchesNPC(goal,id)
    if not id then return false end
    if goal.npc==id then return true end
    for _,p in ipairs(goal.locations or {}) do if p.npc==id and ns.Journey.Applies(p.only) then return true end end
    return false
end
local function spellbook()
    local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if bank==nil then return end
    local count=ns.Safe(ns.API.Call("C_SpellBook","GetNumSpellBookSkillLines"))
    if type(count)~="number" or count<1 or count>64 then return end
    local found={}
    for line=1,count do
        local info=ns.Safe(ns.API.Call("C_SpellBook","GetSpellBookSkillLineInfo",line))
        local offset=info and ns.Safe(info.itemIndexOffset);local size=info and ns.Safe(info.numSpellBookItems)
        local guild=info and ns.Safe(info.isGuild)
        if type(offset)~="number" or type(size)~="number" or size>2048 then return end
        if type(guild)~="boolean" then return end
        if not guild then for slot=offset+1,offset+size do
            local item=ns.Safe(ns.API.Call("C_SpellBook","GetSpellBookItemInfo",slot,bank))
            if type(item)~="table" then return end
            local id=item and ns.Safe(item.spellID)
            if type(id)=="number" then
                local known=ns.Safe(ns.API.Call("C_SpellBook","IsSpellKnown",id,bank))
                local action=ns.Safe(item.actionID)
                if type(known)~="boolean" or type(action)~="number" then return end
                if known then found[id..":"..action]=true end
            end
        end end
    end
    return found
end
local function atPoint(point,radius)
    if not point then return false end
    local map,x,y=ns.API.Position()
    if map~=point.map then
        local projected=ns.Safe(ns.API.Call("C_Map","GetPlayerMapPosition",point.map,"player"))
        if not projected or type(projected.GetXY)~="function" then return false end
        local ok,px,py=pcall(projected.GetXY,projected);px,py=ns.Safe(px),ns.Safe(py)
        if not ok or type(px)~="number" or type(py)~="number" then return false end
        map,x,y=point.map,px,py
    end
    if type(x)~="number" or type(y)~="number" then return false end
    local width,height=ns.API.Call("C_Map","GetMapWorldSize",map);width,height=ns.Safe(width),ns.Safe(height)
    if type(width)~="number" or type(height)~="number" or width<=0 or height<=0 then return false end
    return ((x-point.x)*width)^2+((y-point.y)*height)^2<=radius^2
end
local function atNamedDestination(goal)
    local map=ns.API.Position();local info=map and ns.API.Call("C_Map","GetMapInfo",map)
    return same(read("GetSubZoneText"),goal.location) or same(read("GetZoneText"),goal.location) or same(info and ns.Safe(info.name),goal.location)
end
function A.Done(goal)
    if goal.t=="sethome" and same(read("GetBindLocation"),goal.location) then return true,"native-current-bind" end
    return false
end
function A.Watch(goal)
    if A.goal and goal and A.goal.id==goal.id then return end
    A.goal=goal;A.seenTaxi=nil;A.hearthCast=nil
    if not goal then return end
    if goal.t=="fly" then A.seenTaxi=read("UnitOnTaxi","player")==true end
    if goal.t=="train" and A.trainer and A.trainer.open and matchesNPC(goal,A.trainer.npc) then A.trainer.goal=goal.id end
end
function A.Commit(goal,reason)
    if not ns.char or not goal or not goal.id or not A.goal or A.goal.id~=goal.id then return false end
    ns.char.goalProgress=ns.char.goalProgress or {}
    if ns.char.goalProgress[goal.id] then return false end
    ns.char.goalProgress[goal.id]=reason
    ns.char.actionEvidence=ns.char.actionEvidence or {}
    ns.char.actionEvidence[goal.id]={kind=goal.t,reason=reason,time=read("GetServerTime")}
    A.goal=nil;A.hearthCast=nil;A.seenTaxi=nil
    ns.Journey.Advance();ns.Emit("STATE_CHANGED");return true
end
function A.CheckTrainer(session)
    local goal=A.goal
    if not session or not session.closed or not goal or goal.t~="train" or not goal.class or session.goal~=goal.id or not matchesNPC(goal,session.npc) then return end
    local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if bank~=nil then for id in pairs(session.learned or {}) do
        if ns.Safe(ns.API.Call("C_SpellBook","IsSpellKnown",id,bank))==true then A.Commit(goal,"native-class-training-session");return end
    end end
    if not session.before then return end
    local after=spellbook();if not after then return end
    for key in pairs(after) do if not session.before[key] then A.Commit(goal,"native-class-training-session");return end end
end
function A.Arrival()
    local goal=A.goal;if not goal then return end
    if goal.t=="fly" then
        local taxi=read("UnitOnTaxi","player")
        if taxi==true then A.seenTaxi=true
        elseif taxi==false and A.seenTaxi then
            local point=ns.Travel.Point(goal)
            if point and point.native and atPoint(point,100) then A.Commit(goal,"native-taxi-arrival") end
        end
    elseif goal.t=="hearth" and A.hearthCast==goal.id then
        local bind=read("GetBindLocation");local observed=ns.char.homeBindObservation
        local atBind=observed and same(observed.name,bind) and atPoint(observed,100)
        if same(bind,goal.location) and (atNamedDestination(goal) or atBind) then A.Commit(goal,"native-hearth-cast-and-arrival") end
    end
end
function A.QueueArrival()
    A.Arrival()
    local id=A.goal and A.goal.id
    if not id or not C_Timer or not C_Timer.After then return end
    -- Map positions and taxi state can settle after the world/control event.
    -- Bounded retries, scoped to this action; no permanent movement poll.
    for _,delay in ipairs({.5,1.5}) do C_Timer.After(delay,function() if A.goal and A.goal.id==id then A.Arrival() end end) end
end
function A.Hint(goal)
    if goal.t=="train" then return "Learning a spell or rank at the source-listed class trainer is detected when you close training. If nothing remains to learn, choose Done to confirm your visit." end
    if goal.t=="sethome" then return "Your native hearth bind is checked. A matching bind or observed binding at this inn advances the instruction. Choose Done if the destination cannot be matched." end
    if goal.t=="hearth" then return "A successful Hearthstone cast and matching arrival advance this instruction. A canceled cast does not. Choose Done if the destination cannot be matched." end
    if goal.t=="fly" then return "A taxi journey followed by landing at the native destination point advances this instruction. Knowing a flight path alone is not arrival. Choose Done if destination data is unavailable." end
    if goal.t=="getfp" then return "The native flight map is checked for this character's learned path. Choose Done only if the client cannot report it." end
end
ns.On("TRAINER_SHOW",function()
    local goal=A.goal
    A.trainer={open=true,npc=npcID(),before=spellbook(),goal=goal and goal.t=="train" and goal.id or nil}
end)
ns.On("TRAINER_CLOSED",function()
    local session=A.trainer;if not session then return end
    session.open=false;session.closed=true
    ns.After("trainingEvidence",function() A.CheckTrainer(session) end)
end)
ns.On("SPELLS_CHANGED",function()
    local session=A.trainer
    if session and session.closed then ns.After("trainingEvidence",function() A.CheckTrainer(session) end) end
end)
ns.On("LEARNED_SPELL_IN_SKILL_LINE",function(spell,_,guild)
    spell,guild=ns.Safe(spell),ns.Safe(guild)
    local session=A.trainer
    if session and session.open and type(spell)=="number" and guild==false then
        session.learned=session.learned or {};session.learned[spell]=true
    end
end)
ns.On("HEARTHSTONE_BOUND",function()
    if not ns.char then return end
    local bind=read("GetBindLocation");local map,x,y=ns.API.Position()
    if type(bind)=="string" and type(map)=="number" and type(x)=="number" and type(y)=="number" then ns.char.homeBindObservation={name=bind,map=map,x=x,y=y} end
    local goal=A.goal
    if goal and goal.t=="sethome" and (same(bind,goal.location) or matchesNPC(goal,npcID())) then A.Commit(goal,"native-hearth-binding") end
end)
ns.On("UNIT_SPELLCAST_SUCCEEDED",function(unit,_,spell)
    unit,spell=ns.Safe(unit),ns.Safe(spell)
    local goal=A.goal
    if unit~="player" or not goal or goal.t~="hearth" or type(spell)~="number" then return end
    local _,stoneSpell=ns.API.Call("C_Item","GetItemSpell",6948);stoneSpell=ns.Safe(stoneSpell)
    if spell==stoneSpell then A.hearthCast=goal.id;ns.After("arrivalEvidence",A.QueueArrival) end
end)
for _,event in ipairs({"PLAYER_CONTROL_LOST","PLAYER_CONTROL_GAINED","PLAYER_ENTERING_WORLD","ZONE_CHANGED","ZONE_CHANGED_NEW_AREA","PLAYER_STOPPED_MOVING"}) do
    ns.On(event,function() if ns.char then ns.After("arrivalEvidence",A.QueueArrival) end end)
end
