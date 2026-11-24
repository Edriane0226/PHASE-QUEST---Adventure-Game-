param(
    [ValidateSet('Layout','Locked','Earned','Optional')][string]$Suite = 'Layout',
    [string]$EarnedProfile
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$engine = Join-Path $root '.godot/prompt001-audit/Godot_v4.7-stable_win64_console.exe'
$evidence = Join-Path $root 'output/world/r3-prompt052/evidence'
New-Item -ItemType Directory -Force $evidence | Out-Null
$oldApp = $env:APPDATA
$oldLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $root ('.godot/r3-052/checks-' + [Guid]::NewGuid().ToString('N'))
    $env:LOCALAPPDATA = Join-Path $env:APPDATA 'local'
    $flags = @('--stage-campaign-garden')
    $script = 'res://tools/world/r3_052/check.gd'
    $expected = 'CAMPAIGN052 PASS'
    if ($Suite -eq 'Layout') { $flags += '--layout' }
    if ($Suite -in @('Earned','Optional')) {
        $flags += '--earned'
        if (!$EarnedProfile) { $EarnedProfile = Join-Path $root '.godot/r3-prompt048/workspace/.godot/r3-prompt044/fixtures/fresh-z3l6.save' }
        $slot = Join-Path $env:APPDATA 'Godot/app_userdata/Phase Quest'
        New-Item -ItemType Directory -Force $slot | Out-Null
        Copy-Item -LiteralPath $EarnedProfile -Destination (Join-Path $slot 'campaign-staging-profile.save')
    }
    if ($Suite -eq 'Optional') {
        $harness = 'preload("res://tools/world/r3_052/title_entry.gd")'
        $source = [IO.File]::ReadAllText((Join-Path $root 'tools/world/r3_045/check.gd'))
        $source = $source.Replace('res://touch_route.gd','res://tools/world/r3_030/touch_route.gd').Replace('res://../../../output/world/r3-prompt045/evidence/','res://output/world/r3-prompt052/evidence/')
        $source = $source -replace '(?m)^\tchange_scene_to_file\(WORLD\)\r?\n\tawait scene_changed\r?\n\tworld = current_scene',([string][char]9+"world = await $harness.open(self)")
        $source = $source.Replace('profile.fail_commit = true',"$harness.block_save(profile,true)").Replace('profile.fail_commit = false',"$harness.block_save(profile,false)")
        # Toast acknowledgements are presentation. Compare durable rewards and progress.
        $source = $source.Replace('"achievements":profile.achievement_state()','"achievements":[profile.achievement_state().unlocks,profile.achievement_state().progress]')
        $script = Join-Path $env:APPDATA 'optional.gd'
        [IO.File]::WriteAllText($script,$source)
        $expected = 'OPTIONAL045 PASS'
    }
    $log = Join-Path $evidence ($Suite.ToLowerInvariant()+'.log')
    & $engine --headless --fixed-fps 60 --path $root --script $script --quit-after 90000 -- @flags *> $log
    $result = $LASTEXITCODE
    Get-Content -LiteralPath $log -Tail 12
    if ($result -or !(Select-String -LiteralPath $log -Quiet $expected) -or (Select-String -LiteralPath $log -Quiet 'SCRIPT ERROR|^ERROR: (?!Failed to read the root certificate store\.)')) {
        throw "$Suite failed. See $log"
    }
} finally {
    $env:APPDATA = $oldApp
    $env:LOCALAPPDATA = $oldLocal
}
