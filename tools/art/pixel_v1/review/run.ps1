# Opens the PX-03 review scene with a disposable profile, so the real save is never read or written.
# -Mobile uses the Compatibility renderer. -Capture <folder> writes the captures and closes.
param([switch]$Mobile, [string]$Capture, [string]$Godot = 'C:\Users\Nitro\Desktop\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe')
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$profileDir = Join-Path ([IO.Path]::GetTempPath()) ('px03-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $profileDir | Out-Null
$oldApp = $env:APPDATA; $oldLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = $profileDir; $env:LOCALAPPDATA = $profileDir
    $list = @('--path', $root)
    if ($Mobile) { $list += @('--rendering-method', 'gl_compatibility') }
    $list += 'res://tools/art/pixel_v1/review/px03_slice.tscn'
    if ($Capture) { $env:SHOT_DIR = $Capture.Replace('\', '/'); $list += @('--', '--capture'); if ($Mobile) { $list += '--mobile' } }
    & $Godot @list
} finally { $env:APPDATA = $oldApp; $env:LOCALAPPDATA = $oldLocal }
