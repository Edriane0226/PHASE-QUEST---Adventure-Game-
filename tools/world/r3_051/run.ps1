param(
    [ValidateSet('Play','Check')][string]$Mode = 'Play',
    [string]$Godot
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
if (!$Godot) {
    $bundled = Join-Path $root '.godot/prompt001-audit/Godot_v4.7-stable_win64_console.exe'
    $Godot = if (Test-Path -LiteralPath $bundled) { $bundled } else { (Get-Command godot -ErrorAction Stop).Source }
}
$Godot = (Resolve-Path -LiteralPath $Godot).Path
$work = Join-Path $root '.godot/r3-051'
$oldApp = $env:APPDATA
$oldLocal = $env:LOCALAPPDATA
try {
    if ($Mode -eq 'Play') {
        $env:APPDATA = Join-Path $work 'manual-user'
        $env:LOCALAPPDATA = Join-Path $env:APPDATA 'local'
        & $Godot --path $root --rendering-method gl_compatibility -- --stage-campaign-garden
        if ($LASTEXITCODE) { throw "Staged campaign exited with code $LASTEXITCODE" }
        return
    }
    $evidence = Join-Path $root 'output/world/r3-prompt051/evidence'
    New-Item -ItemType Directory -Force -Path $evidence | Out-Null
    $run = Join-Path $work ('checks-' + [Guid]::NewGuid().ToString('N'))
    $suites = @(
        @{Name='layout'; Profile='layout'; Flags=@('--editor-layout')},
        @{Name='direct'; Profile='stage'; Flags=@('--stage-campaign-garden','--direct')},
        @{Name='fresh'; Profile='stage'; Flags=@('--stage-campaign-garden')},
        @{Name='cold'; Profile='stage'; Flags=@('--stage-campaign-garden','--cold')},
        @{Name='legacy'; Profile='legacy'; Flags=@('--legacy')},
        @{Name='legacy-cold'; Profile='legacy'; Flags=@('--legacy','--cold')}
    )
    foreach ($suite in $suites) {
        $env:APPDATA = Join-Path $run $suite.Profile
        $env:LOCALAPPDATA = Join-Path $env:APPDATA 'local'
        $log = Join-Path $evidence ($suite.Name + '.log')
        & $Godot --headless --path $root --script res://tools/world/r3_051/check.gd --quit-after 12000 -- @($suite.Flags) *> $log
        $result = $LASTEXITCODE
        Get-Content -LiteralPath $log | Select-String 'CAMPAIGN_051'
        if ($result -or !(Select-String -LiteralPath $log -Quiet 'CAMPAIGN_051 PASS') -or (Select-String -LiteralPath $log -Quiet 'SCRIPT ERROR|^ERROR: (?!Failed to read the root certificate store.)')) {
            throw "Campaign suite $($suite.Name) failed. See $log"
        }
    }
} finally {
    $env:APPDATA = $oldApp
    $env:LOCALAPPDATA = $oldLocal
}
