param([string]$InputPath)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$build = '1.60.1.70959'
$source = if ($InputPath) { $InputPath } else { Join-Path $root ".sources/content/reagent-uses/$build" }

function LuaString([string]$value) {
    '"' + $value.Replace('\','\\').Replace('"','\"').Replace("`r",'\r').Replace("`n",'\n').Replace("`t",'\t') + '"'
}

$skillLines = @(Import-Csv (Join-Path $source 'SkillLine.csv'))
$baseSkills = @(129,164,165,171,182,185,186,197,202,333,356,393)
$professions = @{}
$skillNames = @{}
$classLines = [Collections.Generic.HashSet[string]]::new()
$classMasks = [ordered]@{"1"="WARRIOR";"2"="PALADIN";"4"="HUNTER";"8"="ROGUE";"16"="PRIEST";"64"="SHAMAN";"128"="MAGE";"256"="WARLOCK";"1024"="DRUID"}
foreach ($skill in $skillLines) {
    $skillNames[$skill.ID] = $skill.DisplayName_lang
    if ($skill.CategoryID -eq '7') { [void]$classLines.Add($skill.ID) }
    if ([int]$skill.ID -in $baseSkills) { $professions[$skill.ID] = $skill.DisplayName_lang }
}
foreach ($skill in $skillLines) {
    if ($professions.ContainsKey($skill.ParentSkillLineID)) {
        $professions[$skill.ID] = $professions[$skill.ParentSkillLineID]
    }
}
$skillsBySpell = @{}
$classesBySpell = @{}
foreach ($ability in (Import-Csv (Join-Path $source 'SkillLineAbility.csv'))) {
    if ($classLines.Contains($ability.SkillLine) -and $classMasks.Contains($ability.ClassMask)) {
        if (-not $classesBySpell.ContainsKey($ability.Spell)) {
            $classesBySpell[$ability.Spell] = [Collections.Generic.HashSet[string]]::new()
        }
        [void]$classesBySpell[$ability.Spell].Add($classMasks[$ability.ClassMask])
    }
    if (-not $professions.ContainsKey($ability.SkillLine)) { continue }
    if (-not $skillsBySpell.ContainsKey($ability.Spell)) {
        $skillsBySpell[$ability.Spell] = @{}
    }
    $skills = $skillsBySpell[$ability.Spell]
    $line = [int]$ability.SkillLine
    if (-not $skills.ContainsKey($line)) { $skills[$line] = [Collections.Generic.HashSet[int]]::new() }
    if ($ability.MinSkillLineRank -match '^\d+$') {
        [void]$skills[$line].Add([int]$ability.MinSkillLineRank)
    }
}
$namedSpells = [Collections.Generic.HashSet[string]]::new()
foreach ($spell in (Import-Csv (Join-Path $source 'SpellName.csv'))) {
    if (($skillsBySpell.ContainsKey($spell.ID) -or $classesBySpell.ContainsKey($spell.ID)) -and $spell.Name_lang) {
        [void]$namedSpells.Add($spell.ID)
    }
}
$uses = @{}
$classUses = @{}
$recipes = [Collections.Generic.HashSet[int]]::new()
foreach ($row in (Import-Csv (Join-Path $source 'SpellReagents.csv'))) {
    $spell = $row.SpellID
    if (-not $namedSpells.Contains($spell)) { continue }
    for ($slot = 0; $slot -lt 8; $slot++) {
        $item = [int]$row.("Reagent_$slot")
        if ($item -le 0 -or [int]$row.("ReagentCount_$slot") -le 0) { continue }
        foreach ($class in $classesBySpell[$spell]) {
            if (-not $classUses.ContainsKey($item)) { $classUses[$item] = @{} }
            if (-not $classUses[$item].ContainsKey($class)) { $classUses[$item][$class] = @{} }
            $count = [int]$row.("ReagentCount_$slot")
            $previous = $classUses[$item][$class][$spell]
            if ($null -ne $previous -and $previous -ne $count) { $count = 0 }
            $classUses[$item][$class][$spell] = $count
        }
        if (-not $skillsBySpell.ContainsKey($spell)) { continue }
        if (-not $uses.ContainsKey($item)) { $uses[$item] = @{} }
        foreach ($profession in ($skillsBySpell[$spell].Keys | ForEach-Object { $professions[[string]$_] } | Sort-Object -Unique)) {
            if (-not $uses[$item].ContainsKey($profession)) {
                $uses[$item][$profession] = [Collections.Generic.HashSet[int]]::new()
            }
            [void]$uses[$item][$profession].Add([int]$spell)
        }
        [void]$recipes.Add([int]$spell)
    }
}
$lines = [Collections.Generic.List[string]]::new()
$lines.Add('local addonName, ns = ...')
$lines.Add("-- Forever $build reagent relationships. Recipe names are resolved by the client.")
$lines.Add('ns.Data.reagentRecipeIndex = {build="70959", skills={')
foreach ($line in ($professions.Keys | Sort-Object { [int]$_ })) {
    $label = if ($skillNames[$line]) { $skillNames[$line] } else { $professions[$line] }
    $lines.Add("    [$line]={name=" + (LuaString $label) + ',profession=' + (LuaString $professions[$line]) + '},')
}
$lines.Add('}, ranks={')
foreach ($spell in ($recipes | Sort-Object)) {
    $requirements = foreach ($line in ($skillsBySpell[[string]$spell].Keys | Sort-Object)) {
        "[$line]={" + (($skillsBySpell[[string]$spell][$line] | Sort-Object) -join ',') + '}'
    }
    $lines.Add("    [$spell]={" + ($requirements -join ',') + '},')
}
$lines.Add('}, items={')
foreach ($item in ($uses.Keys | Sort-Object)) {
    $groups = foreach ($profession in ($uses[$item].Keys | Sort-Object)) {
        $spells = $uses[$item][$profession] | Sort-Object
        '[' + (LuaString $profession) + ']={' + ($spells -join ',') + '}'
    }
    $lines.Add("    [$item]={" + ($groups -join ',') + '},')
}
$lines.Add('}, classItems={')
foreach ($item in ($classUses.Keys | Sort-Object)) {
    $groups = foreach ($class in ($classUses[$item].Keys | Sort-Object)) {
        $spells = foreach ($spell in ($classUses[$item][$class].Keys | Sort-Object { [int]$_ })) {
            "{$spell,$($classUses[$item][$class][$spell])}"
        }
        $class + '={' + ($spells -join ',') + '}'
    }
    $lines.Add("    [$item]={" + ($groups -join ',') + '},')
}
$lines.Add('}}')
[IO.File]::WriteAllText((Join-Path $root 'ToonKit/Data/ReagentUses.lua'), ($lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
"$($uses.Count) crafting reagents, $($recipes.Count) crafting spells, $($classUses.Count) class-spell reagents"
