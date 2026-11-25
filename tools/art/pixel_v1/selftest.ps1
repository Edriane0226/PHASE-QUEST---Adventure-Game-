# Proves that the validator catches each kind of fault, and that hand-edited sources survive a rebuild.
# Works on copies in a temporary folder. Project files are only read.
param([string]$Aseprite = 'C:\aseprite\build\bin\aseprite.exe')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path.Replace('\', '/')
$work = (Join-Path ([IO.Path]::GetTempPath()) ('pixel-selftest-' + [Guid]::NewGuid().ToString('N'))).Replace('\', '/')
$results = @()

function New-Copy {
    if (Test-Path $work) { Remove-Item -Recurse -Force $work }
    New-Item -ItemType Directory -Force $work | Out-Null
    Copy-Item -Recurse "$root/assets/pixel_v1" "$work/assets"
    Copy-Item -Recurse "$root/art_src/pixel_v1" "$work/source"
    Get-ChildItem "$work/assets" -Recurse -Filter *.import | Remove-Item -Force
}
function Set-Pixel([string]$Rel, [int]$X, [int]$Y, [Drawing.Color]$Colour) {
    $path = "$work/assets/$Rel.png"
    $stream = [IO.MemoryStream]::new([IO.File]::ReadAllBytes($path))
    $from = [Drawing.Bitmap]::new($stream)
    $copy = [Drawing.Bitmap]::new($from.Width, $from.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    for ($yy = 0; $yy -lt $from.Height; $yy++) { for ($xx = 0; $xx -lt $from.Width; $xx++) { $copy.SetPixel($xx, $yy, $from.GetPixel($xx, $yy)) } }
    $copy.SetPixel($X, $Y, $Colour)
    $copy.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    $from.Dispose(); $copy.Dispose(); $stream.Dispose()
}
function Edit-Text([string]$Path, [string]$From, [string]$To) {
    $text = [IO.File]::ReadAllText($Path)
    if (!$text.Contains($From)) { throw "Self-test cannot find '$From' in $Path" }
    [IO.File]::WriteAllText($Path, $text.Replace($From, $To))
}
function Test-Fault([string]$Name, [string]$Expect, [scriptblock]$Break) {
    New-Copy
    & $Break
    $out = pwsh -NoProfile -File "$root/tools/art/pixel_v1/validate.ps1" -Assets "$work/assets" -Source "$work/source" | Out-String
    $ok = $out -match [regex]::Escape($Expect) -and $out -match 'VALIDATE FAIL'
    $script:results += [pscustomobject]@{ Name = $Name; Ok = $ok }
    Write-Output ("{0} {1}" -f ($(if ($ok) { 'PASS' } else { 'FAIL' })), $Name)
    if (!$ok) { Write-Output $out }
}
$ex = 'example/ice_barrier_example'
try {
    Test-Fault 'off-palette pixel' 'off palette' { Set-Pixel $ex 64 90 ([Drawing.Color]::FromArgb(255, 1, 200, 3)) }
    Test-Fault 'partial alpha' 'partial alpha' { Set-Pixel $ex 64 90 ([Drawing.Color]::FromArgb(128, 108, 198, 207)) }
    Test-Fault 'colour limit' 'colour limit' { Set-Pixel $ex 64 90 ([Drawing.Color]::FromArgb(255, 20, 20, 31)) }
    Test-Fault 'cell size' 'cell size' { Edit-Text "$work/assets/$ex.meta.json" '[128, 128]' '[96, 128]' }
    Test-Fault 'tile cell size' 'tile_cap cells are' { Edit-Text "$work/assets/tiles/snow_cap.meta.json" '[40, 20]' '[20, 20]' }
    Test-Fault 'frame too fast' 'frame time' { Edit-Text "$work/assets/$ex.json" '"duration": 120' '"duration": 30' }
    Test-Fault 'pivot outside cell' 'pivot' { Edit-Text "$work/assets/$ex.meta.json" '[64, 104]' '[64, 140]' }
    Test-Fault 'pivot far from base' 'px from the base' { Edit-Text "$work/assets/$ex.meta.json" '[64, 104]' '[64, 50]' }
    Test-Fault 'cap gap' 'a gap' { Set-Pixel 'tiles/snow_cap' 20 0 ([Drawing.Color]::Transparent) }
    Test-Fault 'cap overlap' 'an overlap' { Set-Pixel 'tiles/snow_cap' 0 0 ([Drawing.Color]::FromArgb(255, 200, 220, 234)) }
    Test-Fault 'cap border seam' 'of its border' {
        for ($x = 1; $x -le 38; $x++) { for ($y = 19; $y -ge 0; $y--) {
            $half = if ($y -lt 10) { 2 * $y + 1 } else { 2 * (19 - $y) + 1 }
            if ($x -ge 20 - $half -and $x -le 19 + $half) { if ($x % 2) { Set-Pixel 'tiles/snow_cap' $x $y ([Drawing.Color]::FromArgb(255, 152, 185, 215)) }; break }
        } }
    }
    Test-Fault 'side gap' '3x3 seam: side' { Set-Pixel 'tiles/snow_side' 10 25 ([Drawing.Color]::Transparent) }
    Test-Fault 'clip missing from meta' 'is not in the meta file' { Edit-Text "$work/assets/$ex.json" '"idle_liquid"' '"idle_vapor"' }
    Test-Fault 'bad clip name' 'is not in the standard' { Edit-Text "$work/assets/$ex.json" '"idle_liquid"' '"Liquid Idle"' }
    Test-Fault 'orphan data file' 'orphan file' { Copy-Item "$work/assets/$ex.json" "$work/assets/example/lost.json" }
    Test-Fault 'orphan other file' 'orphan file' { [IO.File]::WriteAllText("$work/assets/example/notes.txt", 'x') }
    Test-Fault 'sheet older than source' 'older than its source' { Add-Content "$work/source/$ex.aseprite" 'x' }
    Test-Fault 'sheet without source' 'no source' { Remove-Item "$work/source/$ex.aseprite" }
    Test-Fault 'source without sheet' 'source without sheet' { Copy-Item "$work/source/$ex.aseprite" "$work/source/example/new_thing.aseprite" }
    Test-Fault 'export edited by hand' 'changed after export' { Set-Pixel $ex 64 90 ([Drawing.Color]::FromArgb(255, 108, 198, 207)) }
    Test-Fault 'source audit failed' 'source audit' { Edit-Text "$work/assets/manifest.json" '"audit": "ok"' '"audit": "palette entry 4 changed"' }

    # A source changed by a person must survive a rebuild. A generated one must be rebuilt.
    New-Copy
    $mini = "$work/mini"
    New-Item -ItemType Directory -Force "$mini/tools/art" | Out-Null
    Copy-Item -Recurse "$root/tools/art/pixel_v1" "$mini/tools/art/pixel_v1"
    New-Item -ItemType Directory -Force "$mini/art_src" | Out-Null
    Copy-Item -Recurse "$root/art_src/pixel_v1" "$mini/art_src/pixel_v1"
    $target = "$mini/art_src/pixel_v1/tiles/snow_cap.aseprite"
    Add-Content $target 'hand edit'
    $before = (Get-FileHash $target).Hash
    $out = & $Aseprite --batch --script-param "root=$mini" --script-param 'biome=snow' --script "$mini/tools/art/pixel_v1/build_tiles.lua" 2>&1 | Out-String
    $ok = $out -match 'SKIP hand-edited or unknown: tiles/snow_cap.aseprite' -and $out -match 'WROTE tiles/snow_edge.aseprite' -and (Get-FileHash $target).Hash -eq $before
    $results += [pscustomobject]@{ Name = 'hand-edited source is kept'; Ok = $ok }
    Write-Output ("{0} hand-edited source is kept" -f ($(if ($ok) { 'PASS' } else { "FAIL`n$out" })))

    # The same scripts must give the same files.
    Copy-Item "$root/art_src/pixel_v1/tiles/snow_cap.aseprite" $target -Force
    $null = & $Aseprite --batch --script-param "root=$mini" --script-param 'biome=snow' --script "$mini/tools/art/pixel_v1/build_tiles.lua" 2>&1 | Out-String
    $ok = (Get-FileHash $target).Hash -eq (Get-FileHash "$root/art_src/pixel_v1/tiles/snow_cap.aseprite").Hash
    $results += [pscustomobject]@{ Name = 'rebuild is repeatable'; Ok = $ok }
    Write-Output ("{0} rebuild is repeatable" -f ($(if ($ok) { 'PASS' } else { 'FAIL' })))
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
$bad = @($results | Where-Object { !$_.Ok }).Count
Write-Output ("SELFTEST {0} checks={1} failures={2}" -f ($(if ($bad) { 'FAIL' } else { 'PASS' })), $results.Count, $bad)
exit ($(if ($bad) { 1 } else { 0 }))
