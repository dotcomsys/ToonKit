param([string]$Version, [string]$Destination)
$ErrorActionPreference = 'Stop'
$reviewRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$toc = Get-Content -LiteralPath (Join-Path $reviewRoot 'ToonKit/ToonKit.toc')
if (-not $Version) {
    $declaredVersion = @($toc | Select-String '^## Version: ([0-9A-Za-z.-]+)$')
    if ($declaredVersion.Count -ne 1) { throw 'Expected one version in ToonKit.toc' }
    $Version = $declaredVersion[0].Matches[0].Groups[1].Value
}
if ($Version -notmatch '^[0-9A-Za-z.-]+$') { throw 'Invalid review version' }
$shareRoot = if ($Destination) { [IO.Path]::GetFullPath($Destination) } else { Join-Path $reviewRoot "Share-$Version" }
$contentRoot = Join-Path $reviewRoot '.sources/content'
$recoveryRoot = Join-Path $reviewRoot ".sources/recovered-$Version"
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (-not ($toc -contains "## Version: $Version")) { throw 'Review version does not match TOC' }
foreach ($line in $toc) {
    if ($line.Trim() -and -not $line.StartsWith('#') -and -not (Test-Path -LiteralPath (Join-Path $reviewRoot "ToonKit/$($line.Trim())") -PathType Leaf)) { throw "Missing load file: $line" }
}
$addonFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
Get-ChildItem -LiteralPath (Join-Path $reviewRoot 'ToonKit') -File -Recurse | ForEach-Object { [void]$addonFiles.Add($_.FullName) }
$sourceFiles = [Collections.Generic.HashSet[string]]::new($addonFiles,[StringComparer]::OrdinalIgnoreCase)
foreach ($name in @('AGENTS.md','CONTENT-COVERAGE.md','QUALITY.md','VERIFICATION.md','SOURCE-MANIFEST.json')) {
    [void]$addonFiles.Remove((Join-Path $reviewRoot "ToonKit/$name"))
}
[void]$sourceFiles.Add((Join-Path $reviewRoot 'tools/Import-ReagentUses.ps1'))
[void]$sourceFiles.Add((Join-Path $reviewRoot 'tools/Import-DungeonMinimaps.ps1'))
[void]$sourceFiles.Add((Join-Path $reviewRoot 'tools/Import-SoloRoutes.py'))
Get-ChildItem -LiteralPath (Join-Path $reviewRoot 'Branding') -File -Recurse | ForEach-Object { [void]$sourceFiles.Add($_.FullName) }
foreach ($scriptName in @('Import-LiveForever.py','Import-ForeverAdvice.py','Import-JournalCoverage.py','Import-Content.py','Import-QuestSupport.py','Import-GearSources.py','Import-DungeonPreparation.py','Import-EffectCoverage.py','Inspect-Delivery.py','Package.ps1','Sync-Brand.ps1','Package-Review.ps1','Recover-SourceInputs.cjs')) {
    [void]$sourceFiles.Add((Join-Path $reviewRoot "tools/$scriptName"))
}
$manifest = Get-Content -LiteralPath (Join-Path $reviewRoot 'ToonKit/SOURCE-MANIFEST.json') -Raw | ConvertFrom-Json
$recoveredEntries = @{}
$blocked = [Collections.Generic.List[string]]::new()
foreach ($record in $manifest.sources) {
    if (($record | ConvertTo-Json -Compress) -match 'PolestarGearProgression|route-refresh-baseline|ForeverDungeonRoutes/maps/') {
        throw 'The release manifest refers to retired data or excluded map artwork.'
    }
    $relative = if ($record.localFile) { $record.localFile }
        elseif ($record.repository) { ([string]$record.repository).Split('/')[-1] + '/' + $record.file }
        else { 'sixty-books.json' }
    if ([IO.Path]::IsPathRooted($relative) -or ($relative -split '[/\\]') -contains '..') { throw "Invalid source path: $relative" }
    $canonical = Join-Path $contentRoot $relative
    $recovered = Join-Path $recoveryRoot $relative
    $revisionRelative = '.by-sha256/' + $record.sha256 + '/' + $relative.Replace('\','/')
    $revisionPath = Join-Path $contentRoot $revisionRelative
    $matched = $false
    foreach ($path in @($canonical,$revisionPath,$recovered)) {
        try { $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash } catch { continue }
        if ($hash -ne $record.sha256) { continue }
        [void]$sourceFiles.Add($path)
        if ($path -eq $recovered) {
            # Preserve a recovered revision separately when the canonical path already holds another file.
            $archiveRelative = if ([IO.File]::Exists($canonical)) { $revisionRelative } else { $relative.Replace('\','/') }
            $recoveredEntries[$path] = '.sources/content/' + $archiveRelative
        }
        $matched = $true
        break
    }
    if (-not $matched) { $blocked.Add("Pinned input: $relative") }
}
foreach ($relative in @('.sources/AllTheThings-tree.json','.sources/content/Spyglass-tree.json')) { [void]$sourceFiles.Add((Join-Path $reviewRoot $relative)) }
foreach ($file in $sourceFiles) {
    try { $stream=[IO.File]::OpenRead($file);$stream.Dispose() }
    catch { $blocked.Add("Unreadable source file: " + [IO.Path]::GetRelativePath($reviewRoot,$file)) }
}
if ($blocked.Count) { throw ("Corresponding source is incomplete:`n" + ($blocked -join "`n")) }
[void](New-Item -ItemType Directory -Path $shareRoot -Force)
function Write-ReviewArchive($files, $name) {
    $output = Join-Path $shareRoot $name
    $temporary = $output + '.tmp'
    $verifiedPaths = @{}
    $stream = [IO.File]::Open($temporary,[IO.FileMode]::Create,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try {
        $zip = [IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
        try {
            foreach ($file in $files) {
                $relative = [IO.Path]::GetRelativePath($reviewRoot,$file).Replace('\','/')
                if ($relative.StartsWith('../') -or [IO.Path]::IsPathRooted($relative)) { throw "File outside workspace: $file" }
                if ($recoveredEntries.ContainsKey($file)) { $relative=$recoveredEntries[$file] }
                if ($verifiedPaths.ContainsKey($relative)) { throw "Duplicate archive path: $relative" }
                $verifiedPaths[$relative]=$file
            }
            foreach ($relative in ($verifiedPaths.Keys | Sort-Object -CaseSensitive)) {
                [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$verifiedPaths[$relative],$relative,[IO.Compression.CompressionLevel]::Optimal)
            }
        } finally { $zip.Dispose() }
    } finally { $stream.Dispose() }
    $read = [IO.Compression.ZipFile]::OpenRead($temporary)
    try {
        if ($read.Entries.Count -ne $files.Count) { throw 'Archive file count differs' }
        foreach ($entry in $read.Entries) {
            $entryStream = $entry.Open()
            try { $actual = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($entryStream)) }
            finally { $entryStream.Dispose() }
            $expected = (Get-FileHash -LiteralPath $verifiedPaths[$entry.FullName] -Algorithm SHA256).Hash
            if ($actual -ne $expected) { throw "Archive byte mismatch: $($entry.FullName)" }
        }
    } finally { $read.Dispose() }
    Move-Item -LiteralPath $temporary -Destination $output -Force
    $digest = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText("$output.sha256","$digest  $name`n",[Text.UTF8Encoding]::new($false))
    Write-Output "$name : $($files.Count) files; exact byte verification passed; SHA256 $digest"
}
Write-ReviewArchive $sourceFiles "ToonKit-$Version-Source.zip"
Write-ReviewArchive $addonFiles "ToonKit-$Version.zip"
