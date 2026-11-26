local addonName, ns = ...
local J=ns.Journey
local S={};ns.SoloRoutes=S
function S.Routes()
    local faction,race=ns.State.faction,ns.State.raceToken or ns.State.race
    local key=tostring(faction)..":"..tostring(race)
    if S.routeKey==key then return S.routes end
    local rows={}
    local function token(v) return tostring(v or ""):lower():gsub("[^%w]","") end
    for _,factory in ipairs(ns.Data.soloRouteFactories or {}) do
        local matches=not factory.races
        for _,allowed in ipairs(factory.races or {}) do if token(allowed)==token(race) then matches=true;break end end
        if (not factory.faction or factory.faction==faction) and matches then rows[#rows+1]=factory.build() end
    end
    S.routeKey,S.routes=key,rows
    return rows
end
local function read(name,...)
    local fn=_G[name]
    if type(fn)=="function" then return ns.Safe(fn(...)) end
end
local function number(value)
    value=ns.Safe(value)
    if type(value)=="number" and value==value and value>=0 and value<math.huge then return value end
end
function S.Level()
    local level=number(ns.State.level);if not level then return end
    local xp=ns.Experience
    if xp and xp.level==level and number(xp.xp) and number(xp.maximum) and xp.maximum>0 then return level+xp.xp/xp.maximum,true end
    local current,maximum=number(read("UnitXP","player")),number(read("UnitXPMax","player"))
    if current and maximum and maximum>0 and current<=maximum then return level+current/maximum,true end
    -- A whole level proves whole-level gates, but cannot prove a fractional one.
    return level,false
end
local function compare(a,op,b)
    if a==nil or b==nil then return end
    if op=="<" then return a<b elseif op==">=" then return a>=b elseif op=="<=" then return a<=b elseif op==">" then return a>b end
end
function S.Condition(c)
    local result
    if c.k=="onquest" then
        result=false
        for _,id in ipairs(c.q or {}) do if J.OnQuest(id) then result=true;break end end
    elseif c.k=="turnedin" then result=J.QuestDone(c.q)
    elseif c.k=="complete" then result=J.ReadyToTurnIn(c.q)
    elseif c.k=="has" then result=(ns.State.owned[c.item] or 0)>=(c.n or 1)
    elseif c.k=="money" then result=compare(number(read("GetMoney")),c.op,c.n)
    elseif c.k=="level" then
        local level,reliable=S.Level();local target=c.n+(c.frac or 0)
        -- Native XP unavailable at this level: leave the gate unresolved.
        if level==c.n and (c.frac or 0)>0 and not reliable then return nil end
        result=compare(level,c.op,target)
    elseif c.k=="zone" or c.k=="bound" then
        local expected=ns.Safe(ns.API.Call("C_Map","GetAreaInfo",c.area))
        local actual=read(c.k=="bound" and "GetBindLocation" or "GetRealZoneText")
        if type(expected)=="string" and type(actual)=="string" then result=expected==actual end
    elseif c.k=="group" or c.k=="dungeon" then
        local key=c.k..":"..tostring(c.q or c.map)
        if c.k=="dungeon" and J.Speedrunning() then result=false
        else result=(ns.char.sourceRouteChoices or {})[key] end
    elseif c.k=="knows" then
        local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        if bank then result=ns.Safe(ns.API.Call("C_SpellBook","IsSpellKnown",c.spell,bank)) end
        local player=read("IsPlayerSpell",c.spell)
        if player==true then result=true end
        if type(result)~="boolean" then result=nil end
    elseif c.k=="skill" then
        local info=c.skillLine and ns.Safe(ns.API.Call("C_SkillInfo","GetSkillLineInfoByID",c.skillLine))
        local rank=type(info)=="table" and ns.Safe(info.rank)
        if type(rank)=="number" and rank>=0 then result=rank>=c.n end
    elseif c.k=="taxi" then
        result=ns.Travel and ns.Travel.Known(c.node)
    elseif c.k=="done" then
        if c.sourceRoute and c.sourceStep then
            local status=(ns.char.routes[c.sourceRoute] or {})[c.sourceStep]
            result=status==true or status=="confirmed" or status=="manual"
        end
    elseif c.k=="available" then
        if J.OnQuest(c.q) or J.QuestDone(c.q) then result=false
        elseif (c.minLevel or 1)>ns.State.level then result=false
        else
            result=true
            for _,id in ipairs(c.closedBy or {}) do if J.OnQuest(id) or J.QuestDone(id) then result=false;break end end
            for _,id in ipairs(c.pre or {}) do if not J.QuestDone(id) then result=false;break end end
            if result and ns.QuestSupplies then result=ns.QuestSupplies.Eligible(c.q,ns.State.level) end
        end
    end
    if result~=nil and c.neg then result=not result end
    return result
end
function S.Conditions(conditions)
    local unknown=false
    for _,c in ipairs(conditions or {}) do
        local result=S.Condition(c)
        if result==false then return false end
        if result==nil then unknown=true end
    end
    if unknown then return nil end
    return true
end
function S.ResetChoices()
    ns.char.sourceRouteChoiceArchives=ns.char.sourceRouteChoiceArchives or {}
    local archive={choices=ns.Copy(ns.char.sourceRouteChoices),steps={}}
    for _,route in ipairs(J.Routes()) do
        local saved=ns.char.routes[route.id]
        for index,status in pairs(saved or {}) do if status=="source condition absent" then
            archive.steps[route.id]=archive.steps[route.id] or {};archive.steps[route.id][index]=status;saved[index]=nil
            local entry=(ns.char.routeEntries or {})[route.id]
            if entry then entry.index=math.min(entry.index,index) end
        end end
    end
    local history=ns.char.sourceRouteChoiceArchives;history[#history+1]=archive
    if #history>5 then table.remove(history,1) end
    ns.char.sourceRouteChoices={};ns.Emit("STATE_CHANGED")
end
local optional=J.OptionalDeferred
function J.OptionalDeferred(g)
    if (g.soloSpeedrun or g.sourceRouteConditions) and S.Conditions(g.soloWhen)==false then return true end
    return optional(g)
end
local stepDone=J.StepDone
function J.StepDone(step)
    if (step.soloSpeedrun or step.sourceRouteConditions) and not step.superseded then
        local applies=S.Conditions(step.soloWhen)
        if applies==false then return true,"source condition absent" end
        if applies==nil then return false end
    end
    return stepDone(step)
end
local blocked=J.Blocked
function J.Blocked(g)
    if (g.soloSpeedrun or g.sourceRouteConditions) then
        if S.Conditions(g.soloWhen)==nil then
            for _,condition in ipairs(g.soloWhen or {}) do
                if condition.k=="group" or condition.k=="dungeon" then
                    local key=condition.k..":"..tostring(condition.q or condition.map)
                    if (ns.char.sourceRouteChoices or {})[key]==nil then return "Open Play to choose whether to include this optional branch." end
                end
            end
            return "Waiting for native route-condition data. Check the written instructions before continuing."
        end
        if g.t=="level" and g.level==ns.Rules.Cap() and (g.frac or 0)>0 then return "This XP checkpoint is beyond the active level cap. Change the content range in Advanced settings to continue on a launch realm." end
        if g.t=="accept" then
            local m=ns.Data.questSupport.meta[g.quest]
            if m then
                if m.parent and not J.OnQuest(m.parent) then return "The parent quest must still be in your quest log." end
                for _,id in ipairs(m.excl or {}) do if J.OnQuest(id) or J.QuestDone(id) then return "An alternative quest branch is already selected. Leave this pickup for later." end end
            end
        end
    end
    return blocked(g)
end
-- Prefer the newer route's explicit all-prerequisites; its any-list stays any.
local prerequisites=J.MissingPrerequisites
function J.MissingPrerequisites(g)
    if not (g.soloSpeedrun or g.sourceRouteConditions) then return prerequisites(g) end
    local missing={}
    for _,id in ipairs(g.preAll or {}) do if not J.QuestDone(id) then missing[#missing+1]=id end end
    if #(g.pre or {})>0 then
        local any=false
        for _,id in ipairs(g.pre) do if J.QuestDone(id) then any=true;break end end
        if not any then for _,id in ipairs(g.pre) do missing[#missing+1]=id end end
    end
    return missing
end
local done=J.GoalDone
function J.GoalDone(g)
    if (g.soloSpeedrun or g.sourceRouteConditions) and g.t=="level" and (g.frac or 0)>0 then
        if not J.Applies(g.only) then return true,"not applicable" end
        if (ns.char.goalProgress or {})[g.id]=="skipped" then return true,"skipped" end
        if ns.State.level>g.level then return true,"native-xp" end
        if ns.State.level<g.level then return false end
        local xp,maximum=number(read("UnitXP","player")),number(read("UnitXPMax","player"))
        return xp~=nil and maximum~=nil and maximum>0 and xp/maximum>=g.frac or false,"native-xp"
    end
    return done(g)
end
local goalText=J.GoalText
function J.GoalText(g)
    if (g.soloSpeedrun or g.sourceRouteConditions) and g.t=="level" and (g.frac or 0)>0 then
        return "Reach level "..g.level.." + "..math.floor(g.frac*100+.5).."% XP"
    end
    return goalText(g)
end
