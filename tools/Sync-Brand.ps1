param([string]$AddonPath = (Join-Path $PSScriptRoot '..\ToonKit'))
$ErrorActionPreference = 'Stop'
$brandText = Get-Content -Raw -LiteralPath (Join-Path $AddonPath 'Brand.lua')
$tocPath = Join-Path $AddonPath ((Split-Path (Resolve-Path -LiteralPath $AddonPath) -Leaf) + '.toc')
$tocText = Get-Content -Raw -LiteralPath $tocPath
$fieldMap = @{ displayName = 'Title'; description = 'Notes'; version = 'Version'; author = 'Author'; icon = 'IconTexture' }
foreach ($field in $fieldMap.Keys) {
    $match = [regex]::Match($brandText, ('\b' + $field + '\s*=\s*"([^"\r\n]*)"'))
    if (-not $match.Success) { throw "Brand field not found: $field" }
    $metadata = $fieldMap[$field]
    $value = $match.Groups[1].Value.Replace('\\','\')
    $tocText = [regex]::Replace($tocText, "(?m)^## ${metadata}:[^\r\n]*", [System.Text.RegularExpressions.MatchEvaluator]{ param($m) "## ${metadata}: $value" })
}
[IO.File]::WriteAllText($tocPath, $tocText, [Text.UTF8Encoding]::new($false))
Write-Output "Synchronized brand metadata: $tocPath"
