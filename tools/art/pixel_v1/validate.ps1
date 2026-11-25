# Checks every exported sheet. Runs Godot in an empty project with a disposable profile,
# so no game code, autoload or save is involved. Exit code 0 means every check passed.
param(
    [string[]]$Legacy,
    [string]$Assets,
    [string]$Source,
    [string]$Only,
    [string]$Report,
    [string]$Godot = 'C:\Users\Nitro\Desktop\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path.Replace('\', '/')
$work = Join-Path ([IO.Path]::GetTempPath()) ('pixel-validate-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$work/project", "$work/user", "$work/local" | Out-Null
[IO.File]::WriteAllText("$work/project/project.godot", "config_version=5`n")
$flags = @("--root=$root")
foreach ($item in $Legacy) { $flags += "--legacy=" + (Resolve-Path $item).Path.Replace('\', '/') }
if ($Assets) { $flags += "--assets=" + $Assets.Replace('\', '/') }
if ($Source) { $flags += "--source=" + $Source.Replace('\', '/') }
if ($Only) { $flags += "--only=$Only" }
if ($Report) { $flags += "--report=" + $Report.Replace('\', '/') }
$oldApp = $env:APPDATA
$oldLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = "$work/user"
    $env:LOCALAPPDATA = "$work/local"
    & $Godot --headless --path "$work/project" --script "$root/tools/art/pixel_v1/validate.gd" -- @flags 2>&1 | Where-Object { "$_" -notmatch '^Godot Engine|^\s*$' } | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
} finally {
    $env:APPDATA = $oldApp
    $env:LOCALAPPDATA = $oldLocal
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
exit $code
