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

function Publish-Source($file) {
    if ($env:BUILD_SHA -notmatch '^[0-9a-f]{40}$') { throw 'Missing verified build commit.' }
    $github = "$env:GITHUB_API_URL/repos/$env:GITHUB_REPOSITORY"
    $githubHeaders = @{ Authorization = "Bearer $env:GH_TOKEN"; Accept = 'application/vnd.github+json' }
    $tag = "v$Version"
    $lookup = Invoke-WebRequest -Uri "$github/releases/tags/$tag" -Headers $githubHeaders -SkipHttpErrorCheck
    if ($lookup.StatusCode -eq 404) {
        $metadata = @{
            tag_name = $tag
            target_commitish = $env:BUILD_SHA
            name = "ToonKit $Version source"
            body = "Corresponding source for ToonKit $Version for WoW Forever."
            prerelease = $Version -match '-(alpha|beta)'
            make_latest = 'false'
        } | ConvertTo-Json -Compress
        $release = Invoke-RestMethod -Uri "$github/releases" -Headers $githubHeaders -ContentType 'application/json' -Method Post -Body $metadata
    } elseif ($lookup.StatusCode -eq 200) {
        $release = $lookup.Content | ConvertFrom-Json
    } else {
        throw "Could not look up the GitHub source release (HTTP $($lookup.StatusCode))."
    }
    $commit = Invoke-RestMethod -Uri "$github/commits/$tag" -Headers $githubHeaders
    if ($commit.sha -ne $env:BUILD_SHA) { throw "GitHub tag $tag points at a different build." }
    $asset = $release.assets | Where-Object name -CEQ $file.Name | Select-Object -First 1
    if (-not $asset) {
        $upload = ($release.upload_url -replace '\{.*$', '') + '?name=' + [uri]::EscapeDataString($file.Name)
        $asset = Invoke-RestMethod -Uri $upload -Headers $githubHeaders -ContentType 'application/zip' -Method Post -InFile $file.FullName -TimeoutSec 180
    }
    $digest = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    if ($asset.state -ne 'uploaded' -or $asset.digest -ne "sha256:$digest" -or -not $asset.browser_download_url) {
        throw 'The GitHub source release asset did not match the verified source ZIP.'
    }
    Write-Host "Verified public source asset $($asset.id)."
    return $asset.browser_download_url
}

$sourceUrl = Publish-Source $files[1]
$changelog = @"
ToonKit $Version for WoW Forever.

[Download the matching source ZIP]($sourceUrl)
"@
"Matching source ZIP: $sourceUrl" >> $env:GITHUB_STEP_SUMMARY
$parent = $ParentFileID
if ($parent) {
    $result = Invoke-RestMethod -Uri "$api/projects/$project/update-file" -Headers $headers -Method Post -TimeoutSec 60 -Form @{
        metadata = @{
            fileID = [int]$parent
            changelogType = 'markdown'
            changelog = $changelog
        } | ConvertTo-Json -Compress
    }
    if ($result.id -ne $parent) { throw 'CurseForge did not confirm the changelog update.' }
    Write-Host "CurseForge linked the verified source ZIP in the changelog for existing file $parent."
} else {
    $parent = Send-Archive $files[0] @{
        displayName = "ToonKit $Version"
        releaseType = $ReleaseType
        gameVersions = @([int]$forever[0].id)
        changelogType = 'markdown'
        changelog = $changelog
    }
    Write-Host "CurseForge accepted the installable ZIP as file $parent."
}
"CurseForge installable file ID: $parent" >> $env:GITHUB_STEP_SUMMARY
