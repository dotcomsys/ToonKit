local addonName, ns = ...

-- Original ToonKit itinerary. Quest IDs, eligibility and the 1690 -> 1691
-- prerequisite are recorded in QuestSupport's Forever metadata.
local route = {
    id = "toonkit:forever:tanaris:wastewander",
    category = "Leveling",
    name = "Tanaris: Gadgetzan bounties",
    source = "Original ToonKit route",
    original = true,
    min = 40, max = 49, zone = 1446,
}

local engineer = {name = "Chief Engineer Bilgewhizzle", x = .525, y = .285}
local operator = {name = "Spigot Operator Luglunket", x = .525, y = .284}
local poster = {name = "Wanted Poster", x = .518, y = .270}

local function goal(quest, phase, contact, note)
    local meta = ns.Data.questSupport.meta[quest]
    return {
        id = route.id .. ":" .. quest .. ":" .. phase,
        t = phase, quest = quest, title = meta.name, qlvl = meta.level,
        minLevel = meta.min, pre = phase == "accept" and meta.pre or nil,
        map = route.zone, x = contact and contact.x, y = contact and contact.y,
        npcName = contact and contact.name, note = note,
    }
end

route.steps = {
    {
        id = route.id .. ":first-pass",
        text = "Pick up the Gadgetzan bounties and clear the eastern camps",
        goals = {
            goal(1690, "accept", engineer, "Pick up the town bounties before leaving Gadgetzan."),
            goal(1707, "accept", operator, "Take the pouch bounty while you are at the engineering camp."),
            goal(2781, "accept", poster, "Read the Wanted Poster in Gadgetzan before heading east."),
            goal(1690, "complete", nil, "Fight Bandits and Thieves in the Wastewander camps east of Gadgetzan. Loot the kills for the pouch bounty."),
            goal(1707, "complete", nil, "Collect five Wastewander Water Pouches while working on the eastern bounties."),
            goal(2781, "complete", nil, "Look for Caliph Scorpidsting while working through the Wastewander camps."),
            goal(1690, "turnin", engineer, "Hand in the first Wastewander hunt to unlock the follow-up."),
            goal(2781, "turnin", engineer, "Turn in Caliph's bounty here if complete."),
            goal(1707, "turnin", operator, "Hand the pouches to Luglunket at the same camp."),
        },
    },
    {
        id = route.id .. ":follow-up",
        text = "Finish the Wastewander follow-up east of Gadgetzan",
        goals = {
            goal(1691, "accept", engineer, "Pick up the follow-up after turning in Wastewander Justice."),
            goal(1691, "complete", nil, "Work the eastern and southeastern camps for Rogues, Assassins, and Shadow Mages. Use the live counters to see which enemies you still need."),
            goal(1691, "turnin", engineer, "Return to Bilgewhizzle in Gadgetzan."),
        },
    },
}

ns.Data.originalRoutes = {route}
