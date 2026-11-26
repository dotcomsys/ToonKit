param(
    [Parameter(Mandatory)][string]$PackageDirectory,
    [Parameter(Mandatory)][ValidatePattern('^[0-9A-Za-z.-]+$')][string]$Version,
    [ValidateSet('alpha','beta','release')][string]$ReleaseType = 'alpha',
    [switch]$VerifyOnly
)
$ErrorActionPreference = 'Stop'

$files = foreach ($suffix in @('', '-Source')) {
    $name = "ToonKit-$Version$suffix.zip"
    $file = Get-Item -LiteralPath (Join-Path $PackageDirectory $name)
    $checksum = (Get-Content -LiteralPath "$($file.FullName).sha256" -Raw).Trim()
    if ($checksum -notmatch '^([0-9a-fA-F]{64})\s+(.+)$' -or $Matches[2] -cne $name -or
        (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne $Matches[1]) {
        throw "Checksum verification failed for $name."
    }
    $archive = [IO.Compression.ZipFile]::OpenRead($file.FullName)
    try {
        $toc = $archive.GetEntry('ToonKit/ToonKit.toc')
        if (-not $toc) { throw "Missing ToonKit.toc in $name." }
        $reader = [IO.StreamReader]::new($toc.Open())
        try { $metadata = $reader.ReadToEnd() -split '\r?\n' } finally { $reader.Dispose() }
        if ($metadata -cnotcontains '## Interface: 16001' -or $metadata -cnotcontains "## Version: $Version") {
            throw "The WoW Forever interface or ToonKit version does not match in $name."
        }
        $hasSource = $null -ne $archive.GetEntry('tools/Package-Review.ps1')
        if ($hasSource -ne ($suffix -eq '-Source')) { throw "Archive contents do not match $name." }
    } finally {
        $archive.Dispose()
    }
    Write-Host "Verified $name"
    $file
}
if ($VerifyOnly) { return }

$project = $env:CURSEFORGE_PROJECT_ID
if ($project -notmatch '^[1-9][0-9]*$' -or -not $env:CURSEFORGE_API_TOKEN) {
    throw 'Set the CURSEFORGE_PROJECT_ID repository variable and CURSEFORGE_API_TOKEN repository secret.'
}
$api = 'https://wow.curseforge.com/api'
$headers = @{ 'X-Api-Token' = $env:CURSEFORGE_API_TOKEN }
$versions = Invoke-RestMethod -Uri "$api/game/versions" -Headers $headers -TimeoutSec 60
$forever = @($versions | Where-Object { $_.gameVersionTypeID -eq 88568 -and $_.name -eq '1.60.1' })
if ($forever.Count -ne 1 -or $forever[0].id -notmatch '^[1-9][0-9]*$') {
    throw 'Could not identify exactly one CurseForge game version for WoW Forever 1.60.1.'
}

function Send-Archive($file, $metadata) {
    $response = Invoke-RestMethod -Uri "$api/projects/$project/upload-file" -Headers $headers -Method Post -TimeoutSec 180 -Form @{
        metadata = ConvertTo-Json -InputObject $metadata -Compress
        file = $file
    }
    if ($response.id -notmatch '^[1-9][0-9]*$') { throw "CurseForge returned no file ID for $($file.Name)." }
    return $response.id
}

$parent = Send-Archive $files[0] @{
    displayName = "ToonKit $Version"
    releaseType = $ReleaseType
    gameVersions = @([int]$forever[0].id)
    changelog = "ToonKit $Version for WoW Forever. The matching source is attached as an additional file."
}
Write-Host "CurseForge accepted the installable ZIP as file $parent."
try {
    $source = Send-Archive $files[1] @{
        displayName = "ToonKit $Version Source"
        releaseType = $ReleaseType
        parentFileID = [int]$parent
        changelog = "Corresponding source for ToonKit $Version."
    }
} catch {
    throw "The installable ZIP was accepted as CurseForge file $parent. Check that file’s attachments before retrying. If the source is missing, attach $($files[1].Name) from the selected build manually. $($_.Exception.Message)"
}
"Submitted ToonKit $Version to CurseForge as file $parent with matching source file $source." >> $env:GITHUB_STEP_SUMMARY
