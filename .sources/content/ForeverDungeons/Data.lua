-- Data.lua -- the instance catalogue.

local ADDON, ns = ...

ns.CATEGORY = {
	DUNGEON = 2,
	RAID = 114,
}

ns.CATEGORY_LABEL = {
	[2] = "Dungeons",
	[114] = "Raids",
}

-- Difficulty IDs that are not Forever content.
--
-- /dungeons dupes made this separable. Every Forever dungeon is difficulty 1,
-- and its raids are 9 (40-player), 148 (20-player) or 185. Four entries sit
-- outside that, and they are exactly the ones that duplicated an existing
-- instance at a raid size:
--
--   197  Blackfathom Deeps 10, Gnomeregan 10
--   215  Sunken Temple 20, Scarlet Enclave 40
--
--     1  dungeons, all 32 of them
--     9  40-player raids   (Molten Core, BWL, Naxxramas, Onyxia, AQ40, ...)
--   148  20-player raids   (Zul'Gurub, Ahn'Qiraj Ruins)
--   185  Forever raids     (The Crystal Vale)
--   197  SoD, excluded      215  SoD, excluded
ns.EXCLUDED_DIFFICULTIES = {
	[197] = "Season of Discovery, 10-player",
	[215] = "Season of Discovery, 20/40-player",
}

-- Its ref is below the table rather than above it because ns.REFS is defined
-- further down this file -- the one place in the addon where that ordering is
-- forced, since Data.lua is where the vocabulary itself lives.

-- A catalogue key contains a pipe, and WoW eats pipe sequences in chat and in
-- font strings: "2|Wailing Caverns" printed as "2ailing Caverns", because |W
-- opens a text-wrapping escape. Doubling the pipe is how you say you meant one.
function ns.SafeKey(key)
	return (tostring(key):gsub("|", "||"))
end

function ns.IsExcluded(entry)
	return ns.EXCLUDED_DIFFICULTIES[entry.difficultyID or -1]
end

----------------------------------------------------------------------
-- where a row came from
----------------------------------------------------------------------

-- Every data table here is a claim about a game nobody here wrote, and the
-- claims come from places of very different worth. Recorded in prose for a
-- year, the prose drifted: of 137 sections, 96 named no source at all, 12
-- carried a date and 5 a URL. PROSE DRIFTS BECAUSE NOTHING FAILS WHEN IT IS
-- MISSING.
ns.SITES = {
	-- published pages, in descending order of how often they answer
	wowhead        = "https://www.wowhead.com/%s",
	icyveins       = "https://www.icy-veins.com/%s",
	warcrafttavern = "https://www.warcrafttavern.com/%s",
	warcraftwiki   = "https://warcraft.wiki.gg/wiki/%s",
	-- Forever's own site. Added for the Dalaran map, whose boss positions
	-- no other consulted source publishes -- Icy Veins' Dalaran guide still
	-- reads "coming soon". A real publisher with a real page, which is the
	-- bar here: the thing this list must never grow is a site invented to
	-- hold a claim that has no page behind it, which is how reasoning gets
	-- dressed up as an address.
	wowf           = "https://wowf.io/%s",

	-- first-party, and worth more than any citation: a source describes where
	-- a door is, a capture is where the door WAS. The same distinction
	-- Locations.lua has always drawn in words.
	measured = false,  -- stood there and recorded it, on this client
	client   = false,  -- read from the running client's own tables

	-- neither published nor measured, and saying so is the point
	pack      = false, -- arrived inside an art drop, no page behind it
	estimated = false, -- no source consulted publishes it; a hint, not a fact
}

-- A `page` is everything after the domain, SECTION INCLUDED --
-- "forever/guide/..." and not "guide/...". Forever keeps its own content in
-- /forever/ and Classic's in /classic/, the same id means different things in
-- each, and a reference that drops the section is a reference to whichever
-- one you happened to be looking at. tools/crawl-abilities.py already refuses
-- to mix two sections in one run for this reason.
function ns.RefURL(one)
	local pattern = one and one.site and ns.SITES[one.site]
	if not (pattern and one.page) then
		return nil
	end
	return pattern:format(one.page)
end

-- A ref is a LIST, never a single entry, because corroboration is the whole
-- argument in half these files -- "the portrait pack agrees name for name,
-- which is two sources rather than one". One entry means one source, and the
-- tooltip at UI.lua already has words for that.
ns.REFS = {}

-- Declared here because it describes a table defined above ns.REFS itself.
ns.REFS["EXCLUDED_DIFFICULTIES"] = {
	{ site = "client", note = "read out of this build's activity table; the two ids are the ones that duplicated an existing instance at a raid size" },
}

-- The section's own ref wins, then the table's. Returns nil rather than an
-- empty list when nothing is recorded: "unsourced" and "sourced to nothing"
-- are different answers and the checker reports them differently.
function ns.RefsFor(tableName, key, section)
	if type(section) == "table" and section.ref then
		return section.ref, "section"
	end
	local own = key and ns.REFS[tableName .. "|" .. key]
	if own then
		return own, "section"
	end
	local shared = ns.REFS[tableName]
	if shared then
		return shared, "table"
	end
	return nil
end

-- One line a person can read, for the tooltip and for /dungeons inspect.
-- Pessimistic on purpose, per CLAUDE.md: a diagnostic that can print a
-- confident nothing is worse than one that says it does not know.
function ns.RefLine(refs)
	if not (refs and refs[1]) then
		return "no source recorded"
	end
	local parts = {}
	for _, one in ipairs(refs) do
		local where = one.page or one.note or one.site
		parts[#parts + 1] = ("%s (%s%s)"):format(
			where, one.site, one.read and ", " .. one.read or "")
	end
	return table.concat(parts, " + ")
end

-- Activity IDs observed on build 69913 top out at 1997, and 2400 was chosen as
-- headroom over that. Not enough: another Forever map addon sweeps to 4000
-- and shows Ruins of Lordaeron at activity 3272 -- so content has
-- already landed above where this stopped looking, and the five dungeons
-- Forever's own guide lists but this catalogue does not show are the obvious
-- suspects. The sweep is pcall'd per id and prepared in batches after login.
local MAX_ACTIVITY_ID = 4000

-- "Scarlet Monastery - Graveyard" and "Dire Maul (East)" are wings of a single
-- instance and share one piece of tile art, so the art layer needs the parent
-- name while the label wants the full one.
local function SplitName(fullName)
	local parent = fullName:gsub("%s*%b()", "")
	parent = parent:gsub("%s*%-%s.*$", "")
	parent = parent:gsub("%s+$", "")
	local wing = fullName:match("%((.+)%)") or fullName:match("%-%s*(.+)$")
	return parent, wing
end

local function AddSize(entry, n)
	if not n or n <= 0 then
		return
	end
	for _, existing in ipairs(entry.sizes) do
		if existing == n then
			return
		end
	end
	entry.sizes[#entry.sizes + 1] = n
end

-- Blizzard ships the same instance under several activity IDs for different
-- raid sizes (Molten Core is both 839 and 1613; Ahn'Qiraj Temple is 843, 1614).
-- Collapse those into one tile and keep the sizes as a list.
local function ScanCatalogue(batched)
	local byKey, order = {}, {}

	if not C_LFGList or not C_LFGList.GetActivityInfoTable then
		return order
	end

	for id = 1, MAX_ACTIVITY_ID do
		local ok, info = pcall(C_LFGList.GetActivityInfoTable, id)
		if ok and type(info) == "table" and info.fullName and info.fullName ~= ""
			and (info.categoryID == ns.CATEGORY.DUNGEON or info.categoryID == ns.CATEGORY.RAID)
		then
			local key = info.categoryID .. "|" .. info.fullName
			local entry = byKey[key]

			if not entry then
				local parent, wing = SplitName(info.fullName)
				entry = {
					key = key,
					activityID = id,
					name = info.fullName,
					parentName = parent,
					wing = wing,
					categoryID = info.categoryID,
					mapID = info.mapID,
					difficultyID = info.difficultyID,
					-- Season of Discovery dungeons ship at difficulty 1 like
					-- any other, so difficulty alone cannot tell them apart.
					-- The activity group can.
					groupID = info.groupFinderActivityGroupID,
					minLevel = info.minLevelSuggestion or 0,
					maxLevel = info.maxLevelSuggestion or 0,
					sizes = {},
					activityIDs = {},
				}
				byKey[key] = entry
				order[#order + 1] = entry
			end

			entry.activityIDs[#entry.activityIDs + 1] = id
			AddSize(entry, info.maxNumPlayers)

			-- widen the band if a duplicate ID reports a different suggestion
			local lo = info.minLevelSuggestion or 0
			if lo > 0 then
				entry.minLevel = (entry.minLevel > 0) and math.min(entry.minLevel, lo) or lo
			end
			entry.maxLevel = math.max(entry.maxLevel, info.maxLevelSuggestion or 0)
		end
		if batched and id % 100 == 0 then
			coroutine.yield()
		end
	end

	for _, entry in ipairs(order) do
		table.sort(entry.sizes)
	end

	table.sort(order, function(a, b)
		if a.minLevel ~= b.minLevel then
			return a.minLevel < b.minLevel
		end
		return a.name < b.name
	end)

	-- The level band is fixed for the life of an entry, so build its label here
	-- rather than concatenating it per row on every refresh.
	for _, entry in ipairs(order) do
		entry.levelText = "Level " .. ns.FormatLevels(entry)
	end

	return order
end

local preparedCatalogue, catalogueWorker
local catalogueLoader = CreateFrame("Frame")

local function ResumeCatalogue()
	local ok, result = coroutine.resume(catalogueWorker)
	if not ok or coroutine.status(catalogueWorker) == "dead" then
		catalogueWorker = nil
		catalogueLoader:SetScript("OnUpdate", nil)
		if not ok then
			_G.error(result)
		end
		preparedCatalogue = result
	end
end

-- Keep a synchronous getter for discovery and map consumers that need the
-- complete list immediately; they finish the same scan, never a second one.
function ns.BuildCatalogue()
	if preparedCatalogue then
		return preparedCatalogue
	end
	if catalogueWorker then
		while catalogueWorker do
			ResumeCatalogue()
		end
		return preparedCatalogue
	end
	if not C_LFGList or not C_LFGList.GetActivityInfoTable then
		return {}
	end
	preparedCatalogue = ScanCatalogue(false)
	return preparedCatalogue
end

catalogueLoader:RegisterEvent("PLAYER_LOGIN")
catalogueLoader:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	self:SetScript("OnEvent", nil)
	if preparedCatalogue or not C_LFGList or not C_LFGList.GetActivityInfoTable then
		return
	end
	catalogueWorker = coroutine.create(function()
		return ScanCatalogue(true)
	end)
	self:SetScript("OnUpdate", ResumeCatalogue)
end)

-- Whether this addon has anything written up for a place yet.
function ns.UnderConstruction(entry)
	return not ns.BossesFor or ns.BossesFor(entry) == nil
end

function ns.FormatLevels(entry)
	if entry.minLevel <= 0 and entry.maxLevel <= 0 then
		return "?"
	end
	if entry.minLevel == entry.maxLevel then
		return tostring(entry.minLevel)
	end
	return entry.minLevel .. " - " .. entry.maxLevel
end

function ns.FormatSizes(entry)
	if #entry.sizes == 0 then
		return ""
	end
	return table.concat(entry.sizes, " / ") .. " player"
end

-- True when the player's level falls inside the suggested band. `level` is
-- optional: a caller filtering the whole catalogue should read UnitLevel once
-- and pass it in rather than have this ask per entry.
function ns.IsAtLevel(entry, level)
	level = level or UnitLevel("player") or 1
	if entry.minLevel <= 0 then
		return false
	end
	return level >= entry.minLevel and (entry.maxLevel <= 0 or level <= entry.maxLevel)
end

-- Is this value something an addon can actually look at?
ns.TAB_ICON = "Interface\\AddOns\\ForeverDungeons\\media\\tab-icon"

-- The map a found door wears. Ours too, at the same 128 square as
-- everything else here, so it neither softens nor needs a Blizzard file
-- that cannot be pushed past 64.
ns.FOUND_ICON = "Interface\\AddOns\\ForeverDungeons\\media\\found-icon"

function ns.Readable(value)
	local ok, text = pcall(tostring, value)
	if not ok then
		return nil, "refused"
	end
	if not pcall(string.lower, text) then
		return nil, "secret"
	end
	return text
end

-- Register an event and then ask whether it actually took.
ns.eventProbes = {}

function ns.TryRegister(frame, event)
	local ok = pcall(frame.RegisterEvent, frame, event)
	local verdict
	if not ok then
		verdict = "no such event on this client"
	elseif frame.IsEventRegistered then
		local asked, answer = pcall(frame.IsEventRegistered, frame, event)
		verdict = (asked and answer) and "registered"
			or "refused by this client"
	else
		-- No way to ask. Say so rather than claim the optimistic answer.
		verdict = "registered (unverified)"
	end
	ns.eventProbes[event] = verdict
	return verdict == "registered"
end
