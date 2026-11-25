# Rebuilds every sheet from its .aseprite source with the Aseprite command line.
# Output: assets/pixel_v1/<folder>/<group>.png, .json, .meta.json and assets/pixel_v1/manifest.json.
param([string]$Aseprite = 'C:\aseprite\build\bin\aseprite.exe')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path.Replace('\', '/')
$src = "$root/art_src/pixel_v1"
$dst = "$root/assets/pixel_v1"
New-Item -ItemType Directory -Force $dst | Out-Null
$version = (& $Aseprite --batch --version 2>&1 | Out-String).Trim()
$sheets = [ordered]@{}
$failed = 0
foreach ($file in (Get-ChildItem $src -Recurse -Filter *.aseprite | Sort-Object FullName)) {
    $rel = $file.FullName.Replace('\', '/').Substring($src.Length + 1) -replace '\.aseprite$', ''
    if ($rel -match '(^|/)_template/' -or $rel -match '^palette/') { continue }
    $meta = "$src/$rel.meta.json"
    if (!(Test-Path $meta)) { Write-Output "FAIL $rel has no meta file"; $failed++; continue }
    New-Item -ItemType Directory -Force (Split-Path "$dst/$rel") | Out-Null
    $audit = & $Aseprite --batch $file.FullName --script-param "root=$root" --script "$root/tools/art/pixel_v1/audit_source.lua" 2>&1 | Out-String
    $note = if ($audit -match 'AUDIT (.*)') { $Matches[1].Trim() } else { 'audit did not run' }
    # Piping makes PowerShell wait for the Aseprite window program to finish.
    & $Aseprite --batch $file.FullName --sheet "$dst/$rel.png" --data "$dst/$rel.json" --format json-array --sheet-type rows --sheet-columns 8 --list-tags 2>&1 | Out-String | Out-Null
    if (!(Test-Path "$dst/$rel.png") -or !(Test-Path "$dst/$rel.json")) { Write-Output "FAIL $rel was not exported"; $failed++; continue }
    # Aseprite writes absolute or local paths. Keep only the file name, so the file is the same on every PC.
    $data = [IO.File]::ReadAllText("$dst/$rel.json") -replace '("image"\s*:\s*")[^"]*/([^"/]+")', '$1$2' -replace '("image"\s*:\s*")[^"]*\\\\([^"\\]+")', '$1$2'
    [IO.File]::WriteAllText("$dst/$rel.json", $data.Replace("`r`n", "`n"))
    [IO.File]::WriteAllText("$dst/$rel.meta.json", [IO.File]::ReadAllText($meta).Replace("`r`n", "`n"))
    if ($note -ne 'ok') { $failed++ }
    $sheets[$rel] = [ordered]@{
        source = "art_src/pixel_v1/$rel.aseprite"
        source_sha256 = (Get-FileHash $file.FullName).Hash.ToLower()
        sheet_sha256 = (Get-FileHash "$dst/$rel.png").Hash.ToLower()
        audit = $note
    }
    Write-Output "EXPORT $rel audit: $note"
}
$manifest = [ordered]@{ version = 1; aseprite = $version; sheets = $sheets } | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText("$dst/manifest.json", $manifest.Replace("`r`n", "`n") + "`n")
Write-Output "EXPORTED $($sheets.Count) sheets, $failed problems"
if ($failed) { exit 1 }
