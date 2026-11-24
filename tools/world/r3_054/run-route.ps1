param (
    [Parameter(Mandatory)][string] $RunRoot,
    [ValidateRange(1,3)][int] $Zone = 1,
    [ValidateRange(1,6)][int] $From = 1,
    [ValidateRange(1,6)][int] $To = 6,
    [switch] $CheckOnly,
    [string] $Package
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$engine = Join-Path $root '.godot/prompt001-audit/Godot_v4.7-stable_win64_console.exe'
$target = [IO.Path]::GetFullPath((Join-Path $root $RunRoot))
$relative = [IO.Path]::GetRelativePath($root,$target).Replace([char]92,[char]47)
if (!$relative.StartsWith('.godot/r3-054/')) { throw 'Use a disposable run directory under .godot/r3-054.' }
$before = Join-Path $root '.godot/r3-prompt048/workspace/.godot'
$oldAppData = $env:APPDATA
$oldLocalData = $env:LOCALAPPDATA
$oldOverride = $env:GODOT_USERDATA_OVERRIDE
$tab = [string][char]9
$touch = 'res://tools/world/r3_030/touch_route.gd'
$walk = 'preload("res://tools/world/r3_054/walking.gd")'
$title = 'preload("res://tools/world/r3_052/title_entry.gd")'
$save = Join-Path $target 'user/Godot/app_userdata/Phase Quest/phasequest_profile.save'
$contentPath = "res://$relative"
$engineProject = @('--path',$root)
if ($Package) {
    $packPath = (Resolve-Path -LiteralPath $Package).Path
    $empty = Join-Path $target 'empty'
    New-Item -ItemType Directory -Force $target,$empty | Out-Null
    $engineProject = @('--main-pack',$packPath,'--path',$empty)
    $contentPath = $target.Replace([char]92,[char]47)
    $sourcePath = $root.Replace([char]92,[char]47)
    $touch = "$sourcePath/tools/world/r3_030/touch_route.gd"
    $title = 'preload("' + $sourcePath + '/tools/world/r3_052/title_entry.gd")'
    $walk = 'preload("' + $contentPath + '/walking.gd")'
    $helper = [IO.File]::ReadAllText((Join-Path $root 'tools/world/r3_054/walking.gd'))
    [IO.File]::WriteAllText((Join-Path $target 'walking.gd'),$helper.Replace('res://tools/world/r3_030/touch_route.gd',$touch))
}

function Convert-Walking([string] $Script,[string] $Tree) {
    $Script = $Script.Replace('world.activate("Z3L3",profile.WORLD_SAVE.anchor("Z3L3","C0")) and profile.enter_world_subregion(world,"Z3L3")', "await $walk.cross($Tree,world,`"Z3L3`")")
    $Script = $Script.Replace('world.activate(CIRCUIT.REGION,room.points.C0) and profile.enter_world_subregion(world,CIRCUIT.REGION)',"await $walk.cross($Tree,world,CIRCUIT.REGION)")
    return $Script.Replace('world.activate(', "await $walk.reach($Tree,world,")
}

function Invoke-Route([string] $Script,[string] $Log,[string] $Expected,[string[]]$Flags=@()) {
    if ($CheckOnly) {
        & $engine --headless @engineProject --script $Script --check-only
        if ($LASTEXITCODE -ne 0) { throw "Could not compile $Script" }
        return
    }
    if (Test-Path -LiteralPath $Log) { throw "Evidence exists. Pick a new run or keep the prior log: $Log" }
    & $engine --headless --fixed-fps 60 @engineProject --script $Script --quit-after 200000 -- @Flags *> $Log
    $code = $LASTEXITCODE
    Get-Content -LiteralPath $Log -Tail 20
    if ($code -or !(Select-String -LiteralPath $Log -Quiet $Expected) -or (Select-String -LiteralPath $Log -Quiet '^(SCRIPT ERROR|FAIL|ERROR: (?!Failed to read the root certificate store\.|.* still in use at exit))')) {
        throw "Route failed. See $Log"
    }
}

try {
    $env:APPDATA = Join-Path $target 'user'
    $env:LOCALAPPDATA = Join-Path $target 'local'
    $env:GODOT_USERDATA_OVERRIDE = $null
    New-Item -ItemType Directory -Force $target,$env:APPDATA,$env:LOCALAPPDATA | Out-Null
    if ($Zone -eq 1) {
        if (Test-Path -LiteralPath $save) { throw 'Zone 1 must begin with a fresh profile.' }
        New-Item -ItemType Directory -Force (Join-Path $target 'attempts') | Out-Null
        $script = [IO.File]::ReadAllText((Join-Path $root 'tools/world/r3_030/check.gd'))
        $script = $script.Replace('res://touch_route.gd',$touch).Replace('res://../../../output/world/r3-prompt030/evidence/',"$contentPath/").Replace('res://../fixtures/',"$contentPath/attempts/")
        $script = $script -replace '(?m)^\tchange_scene_to_file\(CONNECTED\)\r?\n\tawait scene_changed\r?\n\tworld=current_scene', ($tab+"world=await $title.open(self,true)")
        $script = $script.Replace('t=DRIVER.new(self,world)','t=DRIVER.new(self,world)'+[Environment]::NewLine+$tab+'t.check(profile.save_path=="user://phasequest_profile.save","ordinary save path")')
        [IO.File]::WriteAllText((Join-Path $target 'zone1.gd'),$script)
        Invoke-Route "$contentPath/zone1.gd" (Join-Path $target 'zone1.log') '^ZONE030 PASS'
        return
    }
    if (!$CheckOnly -and !(Test-Path -LiteralPath $save)) { throw 'Continue the standard profile earned by the preceding route.' }
    $prompt = if ($Zone -eq 2) {'037'} else {'044'}
    foreach ($number in $From..$To) {
        $id = "z${Zone}l$number"
        $levelDir = Join-Path $target $id
        $res = "$contentPath/$id"
        $suite = Join-Path $before "r3-prompt$prompt/review"
        New-Item -ItemType Directory -Force $levelDir | Out-Null
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $suite "Checks/$number") -Filter '*.gd') {
            $script = [IO.File]::ReadAllText($file.FullName)
            $script = $script -replace 'res://Checks/\d+/',"$res/" -replace 'res://\.\./\.\./\.\./docs/world/r3-prompt\d+/evidence/',"$res/"
            $script = $script.Replace('res://touch_route.gd',$touch)
            foreach ($helper in 'handoff','route_support','service_route') { $script = $script.Replace("res://$helper.gd","$res/$helper.gd") }
            if ($file.Name -eq 'check.gd') {
                $boot = '(?m)^\tchange_scene_to_file\("res://World/Navigation/ConnectedWorld.tscn"\)\r?\n\tawait scene_changed\r?\n\tawait frames\(\)\r?\n\tworld = current_scene'
                if ($script -notmatch $boot) { throw "Unexpected title code in $id." }
                $script = $script -replace $boot, ($tab+"world = await $title.open(self)")
                $script = $script.Replace('profile.fail_commit = true',"$walk.block_save(profile,true)").Replace('profile.fail_commit = false',"$walk.block_save(profile,false)")
                $script = $script -replace '\bdriver\.pose\(', 'await driver.pose('
                if ($id -eq 'z2l1') {
                    # Approach from the west. The support tray blocks the straight approach from the north.
                    $script = $script.Replace('world.activate("Z2L1", span + Vector2(-87,0))',"(await $walk.reach(self,world,`"Z2L1`",span+Vector2(-150,-65)) and await $walk.reach(self,world,`"Z2L1`",span+Vector2(-150,0)) and await $walk.reach(self,world,`"Z2L1`",span+Vector2(-87,0)))")
                }
                if ($id -eq 'z2l2') {
                    # A raised step needs a jump in both directions.
                    $curb = 'await jump_to("OrchardCurb",orchard.points.curb+Vector2(-105,0),Vector2.RIGHT)'
                    $script = $script.Replace($curb, $curb+[Environment]::NewLine+$tab+"check(await $walk.leave_platform(self,world,Vector2.LEFT),`"jump down from curb`")")
                    $clothDone = 'await shot("cloth-dry")'
                    $script = $script.Replace($clothDone, $clothDone+[Environment]::NewLine+$tab+"check(await $walk.leave_platform(self,world,Vector2.DOWN),`"jump down from service plinth`")")
                    $oldBorder = '(?m)^\t# Adjacent points on the baked Sunlit--Orchard walking route\.\r?\n(?:\t[^\r\n]*\r?\n){5}'
                    $replacement = @(
                        ($tab+"check(await $walk.cross(self,world,`"Z2L1`"),`"walk back into Sunlit Landing`")"),
                        ($tab+"check(await $walk.cross(self,world,`"Z2L2`") and orchard.active() and checkpoint()==`"C1`",`"return to retained Orchard attempt`")")
                    ) -join [Environment]::NewLine
                    $script = $script -replace $oldBorder, ($replacement+[Environment]::NewLine)
                }
                if ($id -eq 'z2l5') {
                    $script = $script -replace '(?m)^(\tif not await preload\("[^"]+/handoff\.gd"\)\.prepare\()',($tab+"if not check(await $walk.leave_stream_deck(self,world),`"jump back across the Returning Stream gap`"): report();return"+[Environment]::NewLine+'$1')
                }
                $script = Convert-Walking $script 'self'
                $script = $script -replace '\t\tcheck\(await [^\r\n]+cross\(self,world,"Z3L3"\),\r?\n\t\t\t"archive[^\r\n]+\r?\n\t\tif not await remount\(\): return\r?\n', ($tab+$tab+'check(await cross(true),"walk to archive the in-flight charge")'+[Environment]::NewLine)
                $script = $script.Replace("await $walk.cross(self,world,CIRCUIT.REGION)","await cross()")
                if ($id -eq 'z3l4') {
                    # The attempt is already archived once the player has crossed the border.
                    $script = $script -replace '(?m)^(\t\t\tif not await walker\.go\(points\.back\(\)\):)$',($tab*3+'if world.active_subregion_id == to:break'+[Environment]::NewLine+'$1')
                }
                $script = [regex]::Replace($script,'(?<!not )world\.start_transit\(([^\r\n]+?)\)',{
                    param($matched)
                    "await $walk.board(self,world,$($matched.Groups[1].Value))"
                })
            } else {
                $script = $script -replace '(?sm)^func _input\(.*?(?=^func |\z)',''
                $script = Convert-Walking $script 'get_tree()'
            }
            [IO.File]::WriteAllText((Join-Path $levelDir $file.Name),$script)
        }
        $handoff = [IO.File]::ReadAllText((Join-Path $root 'tools/world/r3_037/handoff.gd')).Replace('res://touch_route.gd',$touch)
        $handoff = $handoff.Replace('world.activate(from,Vector2(anchor[0],anchor[1]))',"await $walk.reach(touch.tree,world,from,Vector2(anchor[0],anchor[1]))")
        $handoff = $handoff.Replace('world.activate(from,start)',"await $walk.reach(touch.tree,world,from,start)").Replace('and not world.activate(id,at)','')
        [IO.File]::WriteAllText((Join-Path $levelDir 'handoff.gd'),$handoff)
        $support = [IO.File]::ReadAllText((Join-Path $root 'tools/world/r3_044/route_support.gd')).Replace('res://touch_route.gd',$touch).Replace('res://handoff.gd',"$res/handoff.gd")
        [IO.File]::WriteAllText((Join-Path $levelDir 'route_support.gd'),(Convert-Walking $support 'tree'))
        $service = Join-Path $suite 'service_route.gd'
        if (Test-Path -LiteralPath $service) {
            $script = [IO.File]::ReadAllText($service).Replace('res://touch_route.gd',$touch).Replace('res://route_support.gd',"$res/route_support.gd").Replace('res://handoff.gd',"$res/handoff.gd")
            [IO.File]::WriteAllText((Join-Path $levelDir 'service_route.gd'),$script)
        }
        $flags = if ($Zone -eq 3 -and $number -eq 6) {@('--walk')} else {@()}
        if (!$CheckOnly) {
            $hash = (Get-FileHash -LiteralPath $save).Hash
            Add-Content -LiteralPath (Join-Path $target 'lineage.txt') "$id input $hash"
        }
        Invoke-Route "$res/check.gd" (Join-Path $target "$id.log") '^[A-Z]+\d+ PASS' $flags
        if (!$CheckOnly) { Add-Content -LiteralPath (Join-Path $target 'lineage.txt') "$id output $((Get-FileHash -LiteralPath $save).Hash)" }
    }
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalData
    $env:GODOT_USERDATA_OVERRIDE = $oldOverride
}
