local addonName, ns = ...

local meta = ns.Data.questSupport.meta
local locations = ns.Data.dungeonPreparation
local circuits = ns.Data.originalRoutes
local contacts = {
    [197] = "Marshal McBride", [240] = "Marshal Dughan", [253] = "William Pestle",
    [658] = "Sten Stoutarm", [714] = "Talin Keeneye", [786] = "Grelin Whitebeard", [823] = "Deputy Willem",
    [1568] = "Undertaker Mordo", [1569] = "Shadow Priest Sarvis", [1661] = "Novice Elreth", [1740] = "Deathguard Saltain",
    [2079] = "Conservator Ilthalaine", [2082] = "Gilshalan Windwalker",
    [2215] = "High Executor Darthalia", [2216] = "Apothecary Lydon",
    [2980] = "Grull Hawkwind", [2981] = "Chief Hawkwind", [2991] = "Greatmother Hawkwind",
    [3143] = "Gornek", [3287] = "Hana'zua", [3338] = "Sergra Darkthorn", [3464] = "Gazrog",
    [4452] = "Kravel Koalbeard", [4453] = "Wizzle Brassbolts", [4454] = "Fizzle Brassbolts",
    [235] = "Salma Saldean", [264] = "Commander Althea Ebonlocke",
    [715] = "Hemet Nesingwary", [716] = "Barnil Stonepot", [717] = "Ajeck Rouack", [718] = "Sir S. J. Erlgadin",
    [1855] = "Tirion Fordring", [9270] = "Williden Marshal", [9997] = "Spraggle Frock", [11758] = "Andi Lynn",
    [251361] = "Rorian the Dayseeker", [251362] = "Ailee Farheart", [253395] = "Ozwin Ironsprocket",
}

local function addRoute(key, name, map, min, max, identity, passes)
    local route = {
        id = "toonkit:forever:" .. key, name = name, zone = map,
        category = "Leveling", source = "Original ToonKit route", original = true,
        min = min, max = max, faction = identity and identity.faction,
        races = identity and identity.races, steps = {},
    }
    for _,pass in ipairs(passes) do
        local step = {id = route.id .. ":" .. pass.key, text = pass.title, goals = {}}
        for _,phase in ipairs({"accept", "complete", "turnin"}) do
            for _,quest in ipairs(pass.quests) do
                local id, note = quest[1], quest[2]
                local record = meta[id]
                if phase ~= "complete" or note then
                    local points = locations[id]
                    local candidates = points and (phase == "accept" and points.pickup or phase == "turnin" and points.turnin)
                    local point
                    for _,candidate in ipairs(candidates or {}) do
                        if candidate.map == map and (candidate.kind == 1 or candidate.kind == 2) then
                            point = candidate
                            break
                        end
                    end
                    local goal = {
                        id = route.id .. ":" .. id .. ":" .. phase,
                        t = phase, quest = id, title = record.name,
                        qlvl = record.level, minLevel = record.min,
                        map = map, x = point and point.x, y = point and point.y,
                        note = phase == "complete" and note or nil,
                    }
                    if phase == "accept" then
                        goal.pre = record.pre
                        goal.preAll = record.preAll
                    end
                    if point and point.kind == 1 then
                        goal.npc, goal.npcName = point.provider, contacts[point.provider]
                    elseif point and point.kind == 2 then
                        goal.fromKind, goal.fromId = "object", point.provider
                        goal.note = "Read the quest sign at the marked location."
                    end
                    step.goals[#step.goals + 1] = goal
                end
            end
        end
        route.steps[#route.steps + 1] = step
    end
    circuits[#circuits + 1] = route
end

addRoute("elwynn:northshire", "Elwynn: Northshire kobolds", 1429, 1, 6,
    {faction = "Alliance", races = {"Human"}}, {
    {key = "marshal", title = "Report to Marshal McBride", quests = {{783}}},
    {key = "camp", title = "Clear the kobold camp", quests = {{7, "Fight the kobold vermin in the camp north of the abbey."}}},
    {key = "ridge", title = "Work uphill toward Echo Ridge Mine", quests = {{15, "Fight kobold workers on the approach to Echo Ridge Mine."}}},
    {key = "mine", title = "Finish the Echo Ridge mine pass", quests = {{21, "Fight kobold laborers in the mine and return to the abbey."}}},
})

addRoute("elwynn:fargodeep", "Elwynn: Fargodeep mine circuit", 1429, 4, 11,
    {faction = "Alliance"}, {
    {key = "mine", title = "Pick up both Goldshire quests before Fargodeep", quests = {
        {60, "Loot kobolds for candles while scouting the mine."},
        {62, "Walk far enough into Fargodeep Mine to complete the scouting objective."},
    }},
})

addRoute("dun-morogh:coldridge", "Dun Morogh: Coldridge Valley", 1426, 1, 6,
    {faction = "Alliance", races = {"Dwarf", "Gnome"}}, {
    {key = "hunting", title = "Gather wolf meat and clear boars in Coldridge", quests = {
        {179, "Loot Coldridge wolves for the outfitter."},
        {183, "Fight Small Crag Boars in the valley while collecting the wolf meat."},
    }},
    {key = "trolls", title = "Clear the trolls near the cave", quests = {{182, "Fight the Frostmane trolls by their cave."}}},
})

addRoute("teldrassil:shadowglen", "Teldrassil: Shadowglen spiders", 1438, 3, 8,
    {faction = "Alliance", races = {"NightElf"}}, {
    {key = "venom", title = "Collect Webwood venom", quests = {{916, "Fight the Webwood spiders in Shadowglen and collect their venom."}}},
    {key = "egg", title = "Retrieve a Webwood egg", quests = {{917, "Return to the spider cave and look for the quest egg."}}},
})

addRoute("teldrassil:balance", "Teldrassil: The first Shadowglen hunts", 1438, 1, 4,
    {faction = "Alliance", races = {"NightElf"}}, {
    {key = "first-hunt", title = "Start the Shadowglen wildlife hunt", quests = {{456, "Hunt the first pair of wildlife types listed in the quest log."}}},
    {key = "follow-up", title = "Take the follow-up from Ilthalaine", quests = {{457, "Hunt the next pair of wildlife types and return to Ilthalaine."}}},
})

addRoute("zephras-isle:opening", "Zephras Isle: Skyborne opening", 2521, 1, 4,
    {races = {"Skyborne"}}, {
    {key = "introduction", title = "Meet Ailee and report to Rorian", quests = {{92460}}},
    {key = "balance", title = "Take Rorian's first assignment", quests = {{92461, "Look for Juvenile Vuldren and check the live objective before returning to Rorian."}}},
})

addRoute("durotar:valley-of-trials", "Durotar: Valley of Trials hunts", 1411, 1, 6,
    {faction = "Horde", races = {"Orc", "Troll"}}, {
    {key = "boars", title = "Start with the mottled boars", quests = {{788, "Fight Mottled Boars in the valley."}}},
    {key = "scorpids", title = "Take the scorpid and Sarkoth quests before moving out", quests = {
        {789, "Fight Scorpid Workers and loot their tails."},
        {790, "Look for Sarkoth in the Valley of Trials while working on the scorpid tails."},
    }},
    {key = "report", title = "Take the hunter's report back", quests = {{804}}},
})

addRoute("mulgore:red-cloud", "Mulgore: Red Cloud Mesa hunts", 1412, 1, 6,
    {faction = "Horde", races = {"Tauren"}}, {
    {key = "hunt", title = "Start the mesa hunt and pick up the water errand", quests = {
        {747, "Loot the plainstriders on the mesa for the first hunt."}, {752},
    }},
    {key = "second", title = "Collect the water and finish the second hunt", quests = {
        {753, "Collect the water from the nearby well."}, {750, "Hunt the mountain cougars on the mesa."},
    }},
    {key = "boars", title = "Clear the battleboars", quests = {{780, "Fight Battleboars on the mesa."}}},
})

addRoute("tirisfal:deathknell", "Tirisfal: Deathknell sweep", 1420, 1, 6,
    {faction = "Horde", races = {"Scourge", "Undead"}}, {
    {key = "wake", title = "Report out of the crypt", quests = {{363}}},
    {key = "outskirts", title = "Clear Deathknell's outskirts", quests = {
        {364, "Fight Mindless Zombies and Wretched Zombies around Deathknell."},
        {376, "Fight the local wolves and bats for their quest drops."},
    }},
    {key = "village", title = "Sweep the village for skeletons and supplies", quests = {
        {3901, "Fight Rattlecage Skeletons in Deathknell."},
        {3902, "Collect scavenging supplies as you clear the village."},
    }},
})

addRoute("westfall:farm-country", "Westfall: Farm country", 1436, 9, 18, {faction = "Alliance"}, {
    {key = "farms", title = "Collect both farm quests before the field pass", quests = {
        {22, "Loot goretusks for livers as you cross the fields."},
        {92909, "Work through the harvesters in the Westfall fields and check your live objective counters."},
    }},
})

addRoute("barrens:crossroads", "Barrens: Crossroads hunts", 1413, 10, 19, {faction = "Horde"}, {
    {key = "first-hunt", title = "Load up on Crossroads hunts", quests = {
        {844, "Loot the local plainstriders for beaks."}, {869, "Loot raptors for the stolen silver."},
    }},
    {key = "zhevra", title = "Finish the unlocked zhevra hunt", quests = {{845, "Hunt zhevras around the Crossroads for hooves."}}},
})

addRoute("duskwood:night-watch", "Duskwood: The Night Watch", 1431, 18, 30, {faction = "Alliance"}, {
    {key = "first-watch", title = "Take the first Night Watch patrol", quests = {{56, "Fight the skeletal enemies specified by the quest. Use the live counters to track the two types."}}},
    {key = "second-watch", title = "Return for the second Night Watch patrol", quests = {{57, "Work on the two ghoul objectives after accepting the follow-up."}}},
    {key = "third-watch", title = "Finish the last Night Watch patrol", quests = {{58, "Work through the skeletal objectives in the final patrol."}}},
})

addRoute("hillsbrad:tarren-mill", "Hillsbrad: Tarren Mill circuit", 1424, 21, 29, {faction = "Horde"}, {
    {key = "first-pass", title = "Pick up both elixirs and the first Hillsbrad assignment", quests = {
        {496, "Collect the bear tongues and spider ichor called for by the elixir."},
        {501, "Loot the mountain lions for blood while crossing the hills."},
        {527, "Clear the listed farm targets around Hillsbrad Fields."},
    }},
    {key = "follow-up", title = "Pick up the unlocked Hillsbrad follow-up", quests = {
        {528, "Clear the next set of targets listed by Darthalia."},
    }},
})

addRoute("thousand-needles:raceway", "Thousand Needles: Raceway supply run", 1441, 28, 36, nil, {
    {key = "flats", title = "Pick up all three raceway jobs before crossing the flats", quests = {
        {1104, "Loot the salt-flat scorpids for venom."},
        {1105, "Work on the turtle shells while crossing the same flats."},
        {1110, "Pick up rocket car parts as you move between the wildlife packs."},
    }},
})

addRoute("stranglethorn:expedition", "Stranglethorn: Expedition hunts", 1434, 28, 38, nil, {
    {key = "intro", title = "Introduce yourself at the expedition camp", quests = {{583}}},
    {key = "first-hunts", title = "Pick up three hunts before leaving the expedition", quests = {
        {185, "Look for the young tigers on the first hunt."},
        {190, "Pick off young panthers as you work around the expedition area."},
        {194, "Work the first raptor objective when you reach the raptor packs."},
    }},
    {key = "second-tiger", title = "Take the next tiger hunt on the return pass", quests = {{186, "Fight the tiger type listed by the new objective."}}},
})

addRoute("tanaris:dunemaul", "Tanaris: Dunemaul Compound", 1446, 44, 53, nil, {
    {key = "compound", title = "Clear the compound on one visit from Gadgetzan", quests = {
        {5863, "Work through the Dunemaul Brutes and Enforcers while looking for Gor'marok the Ravager."},
    }},
})

addRoute("ungoro:expedition", "Un'Goro: Expedition fieldwork", 1449, 49, 58, nil, {
    {key = "fieldwork", title = "Take both Un'Goro assignments before the field pass", quests = {
        {3881, "Recover expedition supplies during your circuit through the crater."},
        {4501, "Check the live counters for the two pterrordax targets as you travel."},
    }},
})

addRoute("eastern-plaguelands:tirion", "Eastern Plaguelands: Tirion's hunts", 1423, 52, 60, nil, {
    {key = "wildlife", title = "Take Tirion's three hunts before leaving the cottage", quests = {
        {5542, "Fight the plaguehound types listed in the quest log."},
        {5543, "Fight plaguebats while working around the other wildlife objectives."},
        {5544, "Loot carrion worms for meat during the same field pass."},
    }},
})

-- Catalog batches use Forever quest facts and bounded pickup groups. They
-- complement the authored field passes where objective positions are unknown.
local outdoors = {
    [1411]="Durotar", [1412]="Mulgore", [1413]="The Barrens", [1416]="Alterac Mountains",
    [1417]="Arathi Highlands", [1418]="Badlands", [1419]="Blasted Lands", [1420]="Tirisfal Glades",
    [1421]="Silverpine Forest", [1422]="Western Plaguelands", [1423]="Eastern Plaguelands",
    [1424]="Hillsbrad Foothills", [1425]="The Hinterlands", [1426]="Dun Morogh", [1427]="Searing Gorge",
    [1428]="Burning Steppes", [1429]="Elwynn Forest", [1431]="Duskwood", [1432]="Loch Modan",
    [1433]="Redridge Mountains", [1434]="Stranglethorn Vale", [1435]="Swamp of Sorrows", [1436]="Westfall",
    [1437]="Wetlands", [1438]="Teldrassil", [1439]="Darkshore", [1440]="Ashenvale", [1441]="Thousand Needles",
    [1442]="Stonetalon Mountains", [1443]="Desolace", [1444]="Feralas", [1445]="Dustwallow Marsh",
    [1446]="Tanaris", [1447]="Azshara", [1448]="Felwood", [1449]="Un'Goro Crater", [1450]="Moonglade",
    [1451]="Silithus", [1452]="Winterspring", [2521]="Zephras Isle",
}
local cities = {[1453]="Alliance",[1454]="Horde",[1455]="Alliance",[1456]="Horde",[1457]="Alliance",[1458]="Horde"}

function ns.Data.InstanceQuest(id)
    return (ns.Data.foreverQuestCategories[id] or 0)%2==1 or id==1654 or id==1806
end

local function sourcePoint(points, allowCity)
    for _,point in ipairs(points or {}) do
        if (outdoors[point.map] or allowCity and cities[point.map]==ns.State.faction)
            and (point.kind==1 or point.kind==2) then return point end
    end
end

local function catalogRoute(id, name, category, rows)
    local first = rows[1]
    local route = {id=id,name=name,zone=first.pickup.map,min=first.min,max=first.max,category=category,
        source="ToonKit route using Forever quest records",original=true,catalogBatch=true}
    local step = {id=id..":pass",text=name,goals={}}
    for _,phase in ipairs({"accept","complete","turnin"}) do
        for _,row in ipairs(rows) do
            local point = phase=="accept" and row.pickup or phase=="turnin" and row.turnin or nil
            local goal = {id=id..":"..row.id..":"..phase,t=phase,quest=row.id,title=row.meta.name,
                qlvl=row.meta.level,minLevel=row.meta.min,catalogQuest=true,pre=phase=="accept" and row.meta.pre or nil}
            if point then
                goal.map,goal.x,goal.y=point.map,point.x,point.y
                if point.kind==1 then
                    goal.npc,goal.npcName=point.provider,contacts[point.provider]
                else
                    goal.fromKind,goal.fromId="object",point.provider
                end
            else
                goal.note="Use the live quest objectives to locate the targets. This pass groups nearby quest contacts."
            end
            step.goals[#step.goals+1]=goal
        end
    end
    route.steps={step}
    return route
end

function ns.Data.BuildOriginalCatalog()
    local excluded, dungeonQuest, outdoorGroups, classRoutes = {}, {}, {}, {}
    for _,route in ipairs(circuits) do
        if ns.Rules.RouteAvailable(route) and ns.Journey.Applies({races=route.races}) then
            for _,step in ipairs(route.steps) do for _,goal in ipairs(step.goals) do excluded[goal.quest]=true end end
        end
    end
    for _,dungeon in ipairs(ns.Data.dungeons or {}) do
        for _,quest in ipairs(dungeon) do dungeonQuest[quest.id]=true end
    end
    for _,id in ipairs({92745,13}) do excluded[id]=true end -- Independently guided by Westfall fieldwork.
    for id,record in pairs(meta) do
        local classQuest = (record.classes or 0)>0
        local requirements = #(record.pre or {})+#(record.preAll or {})
        local details = ns.Data.questSupport.quests[id]
        local points = locations[id]
        local repeatable = math.floor((ns.Data.foreverQuestCategories[id] or 0)/2)%2==1
        local instance = ns.Data.InstanceQuest(id)
        if points and not excluded[id] and not repeatable and not dungeonQuest[id]
            and (not instance or classQuest) and not (details and (details.classic or details.repeatable))
            and not (record.skill or record.minRep or record.maxRep)
            and (classQuest or not record.parent and #(record.excl or {})==0)
            and ns.Rules.MaskAllows(record.classes,ns.State.classID) and ns.Rules.QuestRaceAllowed(record.races) then
            local pickup = sourcePoint(points.pickup,classQuest)
            local turnin = sourcePoint(points.turnin,classQuest)
            local min = math.max(record.min or 1,classQuest and 1 or (record.level or 1)-3,1)
            local max = math.min((record.level or min)+4,60)
            if pickup and turnin and min<=max and (pickup.map~=2521 or ns.Journey.Applies({races={"Skyborne"}})) then
                local row = {id=id,meta=record,pickup=pickup,turnin=turnin,min=min,max=max}
                if classQuest then
                    local route=catalogRoute("toonkit:forever:class:"..id,record.name,"Class",{row})
                    route.finalQuest=id
                    route.requiresDungeon=instance
                    classRoutes[#classRoutes+1]=route
                elseif pickup.map==turnin.map
                    and (pickup.x-turnin.x)^2+(pickup.y-turnin.y)^2<=.09^2 then
                    -- Exact minimums make every pickup in a batch eligible at entry.
                    local key = pickup.map..":"..min..":"..max..":"..math.floor(pickup.x*16)..":"..math.floor(pickup.y*16)
                    -- A gated follow-up must never hold up an independent pickup batch.
                    if requirements>0 then key=key..":followup:"..id end
                    outdoorGroups[key]=outdoorGroups[key] or {}
                    table.insert(outdoorGroups[key],row)
                end
            end
        end
    end
    local result=classRoutes
    for key,rows in pairs(outdoorGroups) do
        table.sort(rows,function(a,b) return a.id<b.id end)
        for start=1,#rows,4 do
            local batch={}
            for i=start,math.min(start+3,#rows) do batch[#batch+1]=rows[i] end
            local first=batch[1]
            local name=outdoors[first.pickup.map]..": "..first.meta.name
            if #batch>1 then name=name.." + "..(#batch-1).." nearby" end
            -- IDs describe the exact quest set so saved skips cannot move to different quests.
            local ids={}
            for _,row in ipairs(batch) do ids[#ids+1]=row.id end
            result[#result+1]=catalogRoute("toonkit:forever:outdoor:"..key..":"..table.concat(ids,"-"),name,"Leveling",batch)
        end
    end
    table.sort(result,function(a,b) if a.min~=b.min then return a.min<b.min end;return a.id<b.id end)
    return result
end
