param (
    [string[]] $Case = @(
        'garden-carried', 'garden-r2', 'garden-receipt', 'garden-complete', 'path',
        'mill-held', 'mill-installed', 'mill-complete', 'rollback', 'backup',
        'corrupt', 'future', 'future-world', 'future-attempt', 'foreign-path',
        'zone1', 'zone2', 'zone3'
    ),
    [string] $RunRoot = '',
    [switch] $Standard
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$engine = Join-Path $project '.godot/prompt001-audit/Godot_v4.7-stable_win64_console.exe'
if (!$RunRoot) {
    $RunRoot = Join-Path $project ('.godot/r3-053/' + [guid]::NewGuid())
}
$fixtureFiles = @{
    zone1 = '.godot/r3-052/zone1-route/attempts/after-l1.save'
    zone2 = '.godot/r3-prompt048/workspace/.godot/r3-prompt037/fixtures/fresh-z2l3.save'
    zone3 = '.godot/r3-prompt048/workspace/.godot/r3-prompt044/fixtures/fresh-z3l6.save'
}
$rejected = @('corrupt', 'future', 'future-world', 'future-attempt', 'foreign-path')
$profileFilename = if ($Standard) {'phasequest_profile.save'} else {'campaign-staging-profile.save'}
$originalAppData = $env:APPDATA
$originalLocalAppData = $env:LOCALAPPDATA
$originalGodotData = $env:GODOT_USERDATA_OVERRIDE

function Invoke-Check([string] $Pass, [string] $Flag = '') {
    $log = Join-Path $caseRoot ($Pass + '.log')
    $gameFlags = @(('--case=' + $name))
    if (!$Standard) { $gameFlags += '--stage-campaign-garden' }
    if ($Flag) { $gameFlags += $Flag }
    & $engine --headless --path $project --fixed-fps 60 --quit-after 6000 --script res://tools/world/r3_053/check.gd -- @gameFlags *> $log
    $result = $LASTEXITCODE
    $summary = Select-String -LiteralPath $log -SimpleMatch 'CAMPAIGN053 PASS'
    $errors = Select-String -LiteralPath $log -Pattern '^(SCRIPT ERROR|ERROR: (?!Failed to read the root certificate store\.|.* still in use at exit))'
    if ($result -ne 0 -or $errors -or ($Pass -ne 'seed' -and !$summary)) {
        Get-Content -LiteralPath $log -Tail 55
        throw "$name $Pass failed (exit $result), see $log"
    }
    if ($summary) { Write-Output "$Pass $($summary.Line)" }
}

try {
    Remove-Item Env:GODOT_USERDATA_OVERRIDE -ErrorAction SilentlyContinue
    foreach ($name in $Case) {
        $caseRoot = Join-Path $RunRoot $name
        $env:APPDATA = Join-Path $caseRoot 'roaming'
        $env:LOCALAPPDATA = Join-Path $caseRoot 'local'
        $profile = Join-Path $env:APPDATA 'Godot/app_userdata/Phase Quest'
        if (Test-Path -LiteralPath $caseRoot) { throw "Use a fresh run folder. Existing case $caseRoot" }
        New-Item -ItemType Directory -Path $profile, $env:LOCALAPPDATA -Force | Out-Null
        if ($fixtureFiles.ContainsKey($name)) {
            Copy-Item -LiteralPath (Join-Path $project $fixtureFiles[$name]) -Destination (Join-Path $profile $profileFilename)
        } else {
            Invoke-Check 'seed' '--seed'
        }
        Invoke-Check 'cold'
        if ($name -eq 'rollback') { Invoke-Check 'retry' '--retry' }
        if ($name -notin $rejected) { Invoke-Check 'second' '--second' }
    }
} finally {
    $env:APPDATA = $originalAppData
    $env:LOCALAPPDATA = $originalLocalAppData
    $env:GODOT_USERDATA_OVERRIDE = $originalGodotData
}
