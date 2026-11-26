param(
    [Parameter(Mandatory)][string]$PackageDirectory,
    [Parameter(Mandatory)][ValidatePattern('^[0-9A-Za-z.-]+$')][string]$Version,
    [ValidateSet('alpha','beta','release')][string]$ReleaseType = 'alpha',
    [ValidatePattern('^[1-9][0-9]*$')][string]$ParentFileID,
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
    $response = Invoke-WebRequest -Uri "$api/projects/$project/upload-file" -Headers $headers -Method Post -TimeoutSec 180 -SkipHttpErrorCheck -Form @{
        metadata = ConvertTo-Json -InputObject $metadata -Compress
        file = $file
    }
    if ($response.StatusCode -ge 300) {
        $detail = (($response.Content -replace '\s+', ' ').Trim() -replace [regex]::Escape($env:CURSEFORGE_API_TOKEN), '[redacted]')
        if ($detail.Length -gt 600) { $detail = $detail.Substring(0, 600) }
        throw "CurseForge rejected $($file.Name) (HTTP $($response.StatusCode)). $detail"
    }
    $result = $response.Content | ConvertFrom-Json
    if ($result.id -notmatch '^[1-9][0-9]*$') { throw "CurseForge returned no file ID for $($file.Name)." }
    return $result.id
}

$parent = $ParentFileID
if ($parent) {
    Write-Host "Source-only retry for existing CurseForge file $parent."
} else {
    $parent = Send-Archive $files[0] @{
        displayName = "ToonKit $Version"
        releaseType = $ReleaseType
        gameVersions = @([int]$forever[0].id)
        changelog = "ToonKit $Version for WoW Forever."
    }
    Write-Host "CurseForge accepted the installable ZIP as file $parent."
}
"CurseForge installable file ID: $parent" >> $env:GITHUB_STEP_SUMMARY
try {
    $source = Send-Archive $files[1] @{
        displayName = "ToonKit $Version Source"
        releaseType = $ReleaseType
        parentFileID = [int]$parent
        changelog = "Corresponding source for ToonKit $Version."
    }
} catch {
    "Source upload failed. Check the attachments on file $parent before running a source-only retry." >> $env:GITHUB_STEP_SUMMARY
    throw
}
Write-Host "CurseForge accepted source file $source under parent $parent."
"Matching source file ID: $source" >> $env:GITHUB_STEP_SUMMARY
