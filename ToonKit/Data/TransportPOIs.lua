local addonName, ns = ...

-- Boarding locations reported for Forever. Coordinates identify map pins only.
-- https://www.wowhead.com/forever/guide/flight-points-zeppelins-and-ships
local markers = {}
local function add(map, x, y, origin, destination, kind, faction)
    markers[#markers+1] = {map=map,x=x/100,y=y/100,faction=faction,
        name=origin.." · "..kind.." to "..destination,
        description="WoW Forever boarding point"}
end

add(1437, 4.7, 63.8, "Menethil Harbor", "Theramore", "Boat", "Alliance")
add(1445, 71.7, 56.7, "Theramore", "Menethil Harbor", "Boat", "Alliance")
add(1437, 4.5, 56.7, "Menethil Harbor", "Southshore", "Boat", "Alliance")
add(1424, 50.7, 70.4, "Southshore", "Auberdine", "Boat", "Alliance")
add(1439, 32.3, 44.1, "Auberdine", "Menethil Harbor", "Boat", "Alliance")
add(1439, 30.5, 40.9, "Auberdine", "Stormwind", "Boat", "Alliance")
add(1453, 21.8, 56.9, "Stormwind Harbor", "Auberdine", "Boat", "Alliance")
add(1439, 33.3, 39.8, "Auberdine", "Rut'theran Village", "Boat", "Alliance")
add(1438, 54.8, 97.2, "Rut'theran Village", "Auberdine", "Boat", "Alliance")
add(1413, 63.8, 38.8, "Ratchet", "Booty Bay", "Boat")
add(1434, 25.7, 73.1, "Booty Bay", "Ratchet", "Boat")
add(1444, 43.5, 42.6, "Forgotten Coast", "Feathermoon Isle", "Ferry", "Alliance")
add(1444, 31.0, 39.5, "Feathermoon Isle", "Forgotten Coast", "Ferry", "Alliance")
add(1446, 68.6, 23.0, "Steamwheedle Port", "Powderfuse Port", "Boat")
add(2521, 65.8, 83.8, "Valanaar Skydocks", "Dalaran", "Airship", "Alliance")
add(1416, 12.8, 51.2, "Dalaran", "Valanaar Skydocks", "Airship", "Alliance")
add(1411, 50.5, 12.7, "Orgrimmar", "Grom'gol", "Zeppelin", "Horde")
add(1434, 31.2, 30.4, "Grom'gol", "Orgrimmar", "Zeppelin", "Horde")
add(1411, 51.0, 13.9, "Orgrimmar", "Undercity", "Zeppelin", "Horde")
add(1420, 60.6, 58.9, "Undercity", "Orgrimmar", "Zeppelin", "Horde")
add(1420, 61.9, 58.9, "Undercity", "Grom'gol", "Zeppelin", "Horde")
add(1434, 31.5, 29.1, "Grom'gol", "Undercity", "Zeppelin", "Horde")
add(2521, 57.7, 81.0, "Valanaar", "Thunder Bluff", "Airship", "Horde")
add(1412, 34.3, 26.1, "Thunder Bluff", "Valanaar", "Airship", "Horde")

ns.Data.transportPOIs = markers
