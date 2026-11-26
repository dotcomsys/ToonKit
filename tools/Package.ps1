param([string]$AddonPath = (Join-Path $PSScriptRoot '..\ToonKit'), [string]$Destination = (Join-Path $PSScriptRoot '..\Share\ToonKit.zip'))
$ErrorActionPreference = 'Stop'
$resolvedAddon = (Resolve-Path -LiteralPath $AddonPath).Path
$addonId = Split-Path $resolvedAddon -Leaf
$tocPath = Join-Path $resolvedAddon "$addonId.toc"
if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) { throw "Missing matching TOC: $tocPath" }
foreach ($entry in Get-Content -LiteralPath $tocPath) {
    if ($entry.Trim() -and -not $entry.StartsWith('#') -and -not (Test-Path -LiteralPath (Join-Path $resolvedAddon $entry.Trim()) -PathType Leaf)) {
        throw "Missing addon load file: $entry"
    }
}
[void](New-Item -ItemType Directory -Path (Split-Path ([IO.Path]::GetFullPath($Destination)) -Parent) -Force)
Compress-Archive -LiteralPath $resolvedAddon -DestinationPath $Destination -Force
$hash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLowerInvariant()
$hashPath = "$Destination.sha256"
[IO.File]::WriteAllText($hashPath, "$hash  $([IO.Path]::GetFileName($Destination))`n", [Text.UTF8Encoding]::new($false))
Write-Output "Package: $Destination"
Write-Output "SHA256: $hash"
