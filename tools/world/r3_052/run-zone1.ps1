param([ValidateRange(0,5)][int]$ResumeAfter=0)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$relative='.godot/r3-052/zone1-route'
$work=Join-Path $root $relative
$engine=Join-Path $root '.godot/prompt001-audit/Godot_v4.7-stable_win64_console.exe'
$evidence=Join-Path $root 'output/world/r3-prompt052/evidence'
New-Item -ItemType Directory -Force -Path $work,(Join-Path $work 'attempts'),$evidence | Out-Null
$driver=[IO.File]::ReadAllText((Join-Path $root 'tools/world/r3_030/check.gd'))
$driver=$driver.Replace('res://touch_route.gd','res://tools/world/r3_030/touch_route.gd').Replace('res://../../../output/world/r3-prompt030/evidence/','res://output/world/r3-prompt052/evidence/').Replace('res://../fixtures/',"res://$relative/attempts/")
$boot=[string][char]9+'world=await preload("res://tools/world/r3_052/title_entry.gd").open(self,resume_after==0)'
$driver=$driver -replace '(?m)^\tchange_scene_to_file\(CONNECTED\)\r?\n\tawait scene_changed\r?\n\tworld=current_scene',$boot
[IO.File]::WriteAllText((Join-Path $work 'check.gd'),$driver)
$oldApp=$env:APPDATA
$oldLocal=$env:LOCALAPPDATA
try {
    $env:APPDATA=Join-Path $work ([Guid]::NewGuid().ToString('N'))
    $env:LOCALAPPDATA=Join-Path $env:APPDATA 'local'
    $flags=@('--stage-campaign-garden')
    $label='zone1'
    if($ResumeAfter) {
        $destination=Join-Path $env:APPDATA 'Godot/app_userdata/Phase Quest'
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
        Copy-Item -LiteralPath (Join-Path $work "attempts/after-l$ResumeAfter.save") -Destination (Join-Path $destination 'campaign-staging-profile.save')
        $flags+="--resume-after=$ResumeAfter"
        $label+="-from-l$ResumeAfter"
    }
    $log=Join-Path $evidence "$label.log"
    & $engine --headless --fixed-fps 60 --path $root --script "res://$relative/check.gd" --quit-after 120000 -- @flags *> $log
    $result=$LASTEXITCODE
    Get-Content -LiteralPath $log -Tail 24
    if($result -or !(Select-String -LiteralPath $log -Quiet 'ZONE030 PASS')) {throw "Campaign Zone 1 route requires review. See $log"}
} finally {
    $env:APPDATA=$oldApp
    $env:LOCALAPPDATA=$oldLocal
}
