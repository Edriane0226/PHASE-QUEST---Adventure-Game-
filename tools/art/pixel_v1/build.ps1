# Runs the Lua builders. Sources edited by hand are never replaced.
param(
    [ValidateSet('palette', 'template', 'tiles', 'example', 'slice', 'terrain', 'review', 'all')][string[]]$What = @('all'),
    [string]$Aseprite = 'C:\aseprite\build\bin\aseprite.exe',
    [string]$Review
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path.Replace('\', '/')
if (!$Review) { $Review = "$root/docs/plans/pixel-art/px-01" }
$Review = $Review.Replace('\', '/')
New-Item -ItemType Directory -Force "$root/art_src/pixel_v1", $Review | Out-Null
if (!(Test-Path "$root/art_src/.gdignore")) { New-Item -ItemType File "$root/art_src/.gdignore" | Out-Null }
function Invoke-Lua([string]$Script, [string[]]$Params = @()) {
    $list = @('--batch', '--script-param', "root=$root", '--script-param', "review=$Review")
    foreach ($p in $Params) { $list += @('--script-param', $p) }
    $list += @('--script', "$root/tools/art/pixel_v1/$Script")
    $out = & $Aseprite @list 2>&1 | Out-String
    $out.Trim()
    if ($out -notmatch '(?m)^(WROTE|SKIP|PALETTE)' -or $out -match '(?i)error|attempt to|assertion') { throw "$Script failed" }
}
$all = $What -contains 'all'
if ($all -or $What -contains 'palette') { Invoke-Lua 'build_palette.lua' }
if ($all -or $What -contains 'template') { Invoke-Lua 'build_template.lua' }
if ($all -or $What -contains 'tiles') { foreach ($b in 'snow', 'grass', 'lab') { Invoke-Lua 'build_tiles.lua' @("biome=$b") } }
if ($all -or $What -contains 'example') { Invoke-Lua 'build_example.lua' }
if ($all -or $What -contains 'slice') { foreach ($s in 'tiles', 'props', 'explorer') { Invoke-Lua "build_slice_$s.lua" } }
if ($all -or $What -contains 'terrain') { Invoke-Lua 'build_terrain.lua' }
# Reads exported sheets, so run export.ps1 first.
if ($What -contains 'review') { Invoke-Lua 'build_review.lua' }
