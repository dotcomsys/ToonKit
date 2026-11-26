local addonName, ns = ...
local D=ns.Journal
-- Native activity catalogue discovery informed by ForeverDungeons 0.11.0 (MIT).
-- Uses the running client's names/levels. This does not assert boss/loot evidence.
local function words(name)
    local parts={};for word in (name or ""):lower():gsub("^the ",""):gmatch("%w+") do parts[#parts+1]=word end
    table.sort(parts);return #parts>0 and table.concat(parts,"") or (name or "")
end
function D.LevelText(d)
    if d.levelsUnknown or not d.min or d.min==0 then return "Level range not supplied" end
    return "Level "..d.min.."-"..d.max
end
function D.CatalogStatus(d)
    if d.announcement then return "Announced | details not published here" end
    if d.nativeOnly then return "Listed by your client | journal details unavailable" end
    local allowed,reason=D.SourceAllowed(d)
    return allowed and "Within your current planning rules" or reason
end
local sourceEntries=D.Entries
function D.Entries()
    local entries=sourceEntries();local result={};local known={}
    for _,entry in ipairs(entries) do result[#result+1]=entry;known[entry.slug]=true end
    for _,entry in ipairs(D.extraCatalog or {}) do if not known[entry.slug] then result[#result+1]=entry;known[entry.slug]=true end end
    table.sort(result,function(a,b)
        local al=a.levelsUnknown and math.huge or a.min;local bl=b.levelsUnknown and math.huge or b.min
        if al~=bl then return al<bl end;return a.name<b.name
    end)
    return result
end
local accept={[1]=true,[9]=true,[148]=true,[185]=true}
local function consume(info,id)
    if type(info)~="table" then return end
    local category=ns.Safe(info.categoryID);local difficulty=ns.Safe(info.difficultyID)
    local name=ns.Safe(info.fullName)
    if (category~=2 and category~=114) or not accept[difficulty] or type(name)~="string" or name=="" then return end
    local key=words(name);local match
    for _,entry in ipairs(D.Entries()) do
        if words(entry.name)==key or entry.nativeNames and entry.nativeNames[key] then match=entry;break end
        if key=="hallofthanes" and entry.slug=="hall-of-thanes" or key=="stockadesstormwind" and entry.slug=="the-stockade" then match=entry;break end
    end
    if match then match.nativeActivity=id;return end
    local low,high=ns.Safe(info.minLevelSuggestion,0),ns.Safe(info.maxLevelSuggestion,0)
    if type(low)~="number" then low=0 end;if type(high)~="number" then high=0 end
    local entry={slug="native:"..category..":"..key,name=name,min=low,max=high,required=math.huge,levelsUnknown=low<=0 or high<=0,
        nativeOnly=true,nativeActivity=id,categoryID=category,encounters={},hasLoot=false,source="Your client's group-finder activity catalogue"}
    if name:lower():find("stratholme",1,true) and D.Get("stratholme") then entry.sharedJournal="stratholme" end
    D.extraCatalog[#D.extraCatalog+1]=entry
end
function D.PrepareCatalog()
    -- The live family catalog is explicit; do not scan arbitrary activity IDs at login.
    D.catalogReady=true
end
