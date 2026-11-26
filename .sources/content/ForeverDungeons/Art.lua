-- Art.lua -- block texture resolution and framing.

local ADDON, ns = ...

-- Ordered widest-art-first. Each entry carries the aspect (width/height) its
-- family is authored at, used to compute the crop.
local PATTERNS = {
	{ path = "Interface\\LFGFRAME\\UI-LFG-BACKGROUND-%s", aspect = 2.0 },
	{ path = "Interface\\EncounterJournal\\UI-EJ-DUNGEONBUTTON-%s", aspect = 2.0 },
	{ path = "Interface\\LFGFRAME\\LFGIcon-%s", aspect = 1.0 },
}

-- Texture names that do not match the activity name. Each entry is a list of
-- extra candidates tried before the derived name.
local ALIASES = {
	["Onyxia's Lair"] = { "Onyxia", "OnyxiasLair" },
	["Lower Blackrock Spire"] = { "BlackrockSpire", "LowerBlackrockSpire", "LBRS" },
	["Ahn'Qiraj Ruins"] = { "AhnQiraj", "RuinsofAhnQiraj", "AhnQirajRuins" },
	["Ahn'Qiraj Temple"] = { "AhnQirajTemple", "TempleofAhnQiraj", "AhnQiraj" },
	["Stormwind Stockades"] = { "TheStockade", "Stockades", "StormwindStockades" },
}

-- Used when an instance has no art of its own -- most of the new Forever
-- instances do not yet.
local FALLBACK_ATLAS = {
	[2] = "groupfinder-background-dungeons",
	[114] = "groupfinder-background-raids-midnight",
}

-- Asset probing lives here, in the layer that owns asset resolution, and is
-- published on ns so UI.lua uses the same answers. Both were previously
-- duplicated there, and FileExists had already diverged: UI's copy handled
-- numeric fileIDs but had lost the GetFileIDFromPath fallback, so the icon
-- picker screened its candidates with a weaker probe than the tile art used.
-- This is the union of the two.
function ns.FileExists(path)
	-- a numeric fileID is already resolved; IsKnownFile only takes paths
	if type(path) == "number" then
		return path > 0
	end
	-- Files this addon ships are not "known" to either API: both answer for the
	-- game's own assets, so an addon texture reads as missing and every caller
	-- falls back past it silently. A path under Interface\AddOns is taken on
	-- trust -- if it is not there the texture draws blank, which is visible and
	-- fixable, unlike a fallback nobody asked for.
	if type(path) == "string" and path:lower():find("interface\\addons\\", 1, true) then
		return true
	end
	if C_UIFileAsset and C_UIFileAsset.IsKnownFile then
		local ok, known = pcall(C_UIFileAsset.IsKnownFile, path)
		if ok and known == true then
			return true
		end
	end
	if GetFileIDFromPath then
		local ok, id = pcall(GetFileIDFromPath, path)
		if ok and tonumber(id) and tonumber(id) > 0 then
			return true
		end
	end
	return false
end

function ns.AtlasExists(name)
	if not name or not C_Texture or not C_Texture.GetAtlasExists then
		return false
	end
	local ok, exists = pcall(C_Texture.GetAtlasExists, name)
	return ok and exists == true
end

local FileExists, AtlasExists = ns.FileExists, ns.AtlasExists

local function Squash(s)
	return (s:gsub("[%s%p]", ""))
end

-- Several of these textures are artwork sitting in a larger, padded file --
-- the classic power-of-two layout, where a 165px image lives in a 256px file
-- and the remainder is blank. Sampling the whole file then shows that blank
-- area, which is why Ahn'Qiraj filled its block vertically but stopped short
-- across. Blizzard does the same thing itself: the selector glow reads
-- 0.002..0.639 horizontally, not 0..1.
ns.REFS["contentRects"] = {
	{ site = "measured", note = "tuned live against the art with the crop tuner, then baked back; the tuner is gone and the numbers are what it was for" },
}
ns.REFS["contentRects|2|Stormwind Stockades"] = {
	{ site = "estimated", note = "seeded from 165x110 of artwork in a 256x128 file, the convention the measured ones point at" },
}
ns.REFS["contentRects|2|Zul'Farrak"] = ns.REFS["contentRects|2|Stormwind Stockades"]
ns.REFS["contentRects|114|Onyxia's Lair"] = ns.REFS["contentRects|2|Stormwind Stockades"]

ns.contentRects = {
	["114|Ahn'Qiraj Temple"] = { 0, 0.66, 0, 1 },
	["114|Ahn'Qiraj Ruins"] = { 0, 0.66, 0, 1 },
	["2|Stormwind Stockades"] = { 0, 0.645, 0, 0.859 },
	["2|Zul'Farrak"] = { 0, 0.645, 0, 0.859 },
	["114|Onyxia's Lair"] = { 0, 0.645, 0, 0.859 },
}

local FULL_RECT = { 0, 1, 0, 1 }

local function ContentRect(entry)
	return ns.contentRects[entry.key] or FULL_RECT
end

-- At a block art rect of 370x47 the target is 7.87:1, so a 2:1 source shows
-- only the middle 25% of its height and a 1:1 source 13%. WHICH band that is
-- matters more than the crop maths: these are landscapes, and the recognisable
-- feature is rarely dead centre.
--
-- 0 takes the band from the top of the content, 1 from the bottom, 0.5 is
-- centred -- which is what the crop did before this existed, and read as an
-- anonymous strip on a lot of instances. Lua cannot judge where the subject of
-- an image is, so this was aimed in game with /dungeons focus and 0.35 is what
-- looked right across the list: these are landscapes, and their subject sits
-- above the middle far more often than below it.
ns.ARTWORK_FOCUS = 0.35
ns.artFocus = {}

local function FocusY(entry)
	return ns.artFocus[entry.key] or ns.ARTWORK_FOCUS
end

local resolved = {}

-- Returns kind, value, sourceAspect where kind is "file", "atlas" or "none".
function ns.ResolveArt(entry)
	local cached = resolved[entry.key]
	if cached then
		return cached.kind, cached.value, cached.aspect
	end

	local candidates = {}
	local function add(name)
		if name and name ~= "" then
			candidates[#candidates + 1] = name
		end
	end

	for _, alias in ipairs(ALIASES[entry.name] or ALIASES[entry.parentName] or {}) do
		add(alias)
	end
	add(Squash(entry.parentName))
	add(Squash(entry.name))

	for _, name in ipairs(candidates) do
		for _, pattern in ipairs(PATTERNS) do
			local path = pattern.path:format(name)
			if FileExists(path) then
				resolved[entry.key] = { kind = "file", value = path, aspect = pattern.aspect }
				return "file", path, pattern.aspect
			end
		end
	end

	local atlas = FALLBACK_ATLAS[entry.categoryID]
	if AtlasExists(atlas) then
		resolved[entry.key] = { kind = "atlas", value = atlas }
		return "atlas", atlas
	end

	resolved[entry.key] = { kind = "none" }
	return "none"
end

-- Centred cover crop within the file's content rect: sample the largest region
-- matching the block's aspect so the image fills it without being squashed,
-- while never straying into the file's blank padding. `trim` shaves a little
-- off every edge, hiding the soft borders some of these textures carry.
local function CoverTexCoords(sourceAspect, targetAspect, trim, rect, focusY)
	trim = trim or 0
	rect = rect or FULL_RECT
	focusY = math.min(math.max(focusY or 0.5, 0), 1)

	local rectW = rect[2] - rect[1]
	local rectH = rect[4] - rect[3]
	if rectW <= 0 or rectH <= 0 then
		rectW, rectH = 1, 1
		rect = FULL_RECT
	end

	-- the aspect of the content, not of the whole file
	local contentAspect = sourceAspect and (sourceAspect * (rectW / rectH)) or nil

	-- work in content space first, 0..1 across the rect
	local left, right, top, bottom = 0, 1, 0, 1
	if contentAspect and targetAspect and contentAspect > 0 and targetAspect > 0 then
		if contentAspect > targetAspect then
			local fraction = targetAspect / contentAspect
			left = (1 - fraction) / 2
			right = 1 - left
		elseif contentAspect < targetAspect then
			-- the band is `fraction` of the content tall; focusY slides it, so
			-- 0.5 leaves it exactly where the centred crop used to put it
			local fraction = contentAspect / targetAspect
			top = (1 - fraction) * focusY
			bottom = top + fraction
		end
	end

	local insetX = (right - left) * trim
	local insetY = (bottom - top) * trim
	left, right = left + insetX, right - insetX
	top, bottom = top + insetY, bottom - insetY

	-- then map back into the file
	return rect[1] + left * rectW, rect[1] + right * rectW,
		rect[3] + top * rectH, rect[3] + bottom * rectH
end

-- Paint a texture for an entry, framed for a block of targetW x targetH.
-- Returns the kind used: "file", "atlas" or "none".
function ns.ApplyArt(texture, entry, targetW, targetH)
	local kind, value, sourceAspect = ns.ResolveArt(entry)

	if kind == "file" then
		texture:SetTexture(value)
		local targetAspect = (targetW and targetH and targetH > 0) and (targetW / targetH) or nil
		texture:SetTexCoord(CoverTexCoords(sourceAspect, targetAspect, 0.04,
			ContentRect(entry), FocusY(entry)))
		texture:SetVertexColor(1, 1, 1)
		return "file"
	elseif kind == "atlas" then
		-- atlases carry their own coords and must not be re-cropped
		texture:SetAtlas(value)
		texture:SetVertexColor(1, 1, 1)
		return "atlas"
	end

	texture:SetTexture(nil)
	texture:SetColorTexture(0.10, 0.12, 0.16, 1)
	return "none"
end
