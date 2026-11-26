$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$revision = '7d81bce917e79b32d6343d8a396b6b8c2756bcb9'
$source = Join-Path $root ".sources/content/forever-dungeon-routes/$revision"
$minimaps = Get-Content -LiteralPath (Join-Path $source 'ForeverDungeonRoutes/Data/Minimaps.lua') -Raw
$dungeons = Get-Content -LiteralPath (Join-Path $source 'ForeverDungeonRoutes/Data/Dungeons.lua') -Raw
$floors = Get-Content -LiteralPath (Join-Path $source 'ForeverDungeonRoutes/Data/Floors.lua') -Raw
$routes = Get-Content -LiteralPath (Join-Path $source 'ForeverDungeonRoutes/Data/DefaultRoutes.lua') -Raw
$floorIDs = [Collections.Generic.HashSet[int]]::new()
foreach ($match in [regex]::Matches($minimaps, '(?m)^\s*\[(\d+)\] = \{')) {
    [void]$floorIDs.Add([int]$match.Groups[1].Value)
}
$floorArt = foreach ($match in [regex]::Matches($floors, '(?m)^\s*\[(\d+)\] = \{ name = ("[^"]+")[^\r\n]*\r?\n\s*tiles = \{ ([\d, ]+) \}')) {
    $ids = $match.Groups[3].Value -split ',\s*'
    if ($ids.Count -ne 12) { continue }
    $floor = [int]$match.Groups[1].Value
    $name = $match.Groups[2].Value
    "    [$floor] = {name=$name, tiles={"
    for ($index = 0; $index -lt $ids.Count; $index++) {
        $x = ($index % 4) * 256
        $y = [Math]::Floor($index / 4) * 256
        $w = [Math]::Min(256, 1002 - $x)
        $h = [Math]::Min(256, 668 - $y)
        $right = ($w / 256).ToString([Globalization.CultureInfo]::InvariantCulture)
        $bottom = ($h / 256).ToString([Globalization.CultureInfo]::InvariantCulture)
        "        {$($ids[$index]),$x,$y,$w,$h,0,0,0,$bottom,$right,0,$right,$bottom,0},"
    }
    '    }},'
    [void]$floorIDs.Add($floor)
}
$instances = [ordered]@{}
foreach ($match in [regex]::Matches($dungeons, 'instanceID = (\d+), floors = \{ ([\d, ]*) \}')) {
    $instance = $match.Groups[1].Value
    if (-not $instances.Contains($instance)) { $instances[$instance] = [Collections.Generic.List[int]]::new() }
    foreach ($floor in ($match.Groups[2].Value -split ',\s*')) {
        if ($floor -and $floorIDs.Contains([int]$floor) -and -not $instances[$instance].Contains([int]$floor)) {
            $instances[$instance].Add([int]$floor)
        }
    }
}
if (-not $instances['3039'].Contains(1030391)) { throw 'Instance 3039 is missing from the pinned source.' }
$header = @"
local addonName, ns = ...
-- Client minimap tile identities, placements and UVs from Forever Dungeon Routes (MIT).
-- Checkov23, revision $revision. See Licenses/ForeverDungeonRoutes-MIT.txt.
-- Rebuild with tools/Import-DungeonMinimaps.ps1. This table contains no artwork.
"@
$mapping = foreach ($instance in $instances.Keys) {
    if ($instances[$instance].Count) { "    [$instance] = {" + ($instances[$instance] -join ', ') + "}," }
}
$bosses = [ordered]@{}
foreach ($match in [regex]::Matches($routes, '(?m)^\s*\{kind="(boss|optional|rare)", floor=(\d+), x=(0(?:\.\d+)?|1), y=(0(?:\.\d+)?|1), name=("[^"\r\n]+")')) {
    $floor = $match.Groups[2].Value
    if (-not $floorIDs.Contains([int]$floor)) { continue }
    if (-not $bosses.Contains($floor)) { $bosses[$floor] = [Collections.Generic.List[string]]::new() }
    $bosses[$floor].Add("{name=$($match.Groups[5].Value),x=$($match.Groups[3].Value),y=$($match.Groups[4].Value)}")
}
$pins = foreach ($floor in $bosses.Keys) { "    [$floor] = {" + ($bosses[$floor] -join ',') + "}," }
$tiles = $minimaps.Substring($minimaps.IndexOf('DR.MinimapArt = {')).Replace('DR.MinimapArt', 'ns.Data.dungeonMinimapTiles').TrimEnd()
$output = @($header,'ns.Data.dungeonMinimapFloors = {',($mapping -join "`n"),'}',
    'ns.Data.dungeonFloorArt = {',($floorArt -join "`n"),'}',
    'ns.Data.dungeonBossPins = {',($pins -join "`n"),'}',$tiles) -join "`n"
[IO.File]::WriteAllText((Join-Path $root 'ToonKit/Data/DungeonMinimaps.lua'), $output + "`n", [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $source 'LICENSE') -Destination (Join-Path $root 'ToonKit/Licenses/ForeverDungeonRoutes-MIT.txt')
