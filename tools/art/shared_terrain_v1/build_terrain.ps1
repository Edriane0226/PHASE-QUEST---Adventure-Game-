param([switch]$SampleOnly)
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$taskDestination = Join-Path $taskRoot 'assets/world/shared_terrain/v1'
$taskSvgDirectory = Join-Path $taskDestination 'svg'
[IO.Directory]::CreateDirectory($taskSvgDirectory) | Out-Null
$taskContract = Get-Content -Raw -LiteralPath (Join-Path $taskRoot 'docs/art/r3-prompt002/production-contract.json') | ConvertFrom-Json
$taskEntries = [Collections.Generic.List[object]]::new()
$taskCulture = [Globalization.CultureInfo]::InvariantCulture
function Num([double]$Value) { $Value.ToString('0.###',$taskCulture) }
function Mix([string]$Value,[string]$Other,[double]$Amount) {
    $taskA=[Drawing.ColorTranslator]::FromHtml($Value); $taskB=[Drawing.ColorTranslator]::FromHtml($Other)
    '#{0:X2}{1:X2}{2:X2}' -f [int]($taskA.R*(1-$Amount)+$taskB.R*$Amount),[int]($taskA.G*(1-$Amount)+$taskB.G*$Amount),[int]($taskA.B*(1-$Amount)+$taskB.B*$Amount)
}
Add-Type -AssemblyName System.Drawing
function Points($Values) { (@($Values | ForEach-Object {(Num $_[0])+','+(Num $_[1])}) -join ' ') }
function Polygon($Values,[string]$Fill,[string]$Extra='') { $taskBleed=if($Fill -match '^#[0-9A-Fa-f]{6}$' -and -not $Extra){'stroke="'+$Fill+'" stroke-width="1" stroke-linejoin="round"'}else{''}; '<polygon points="'+(Points $Values)+'" fill="'+$Fill+'" '+$taskBleed+' '+$Extra+'/>' }
function Stroke($Values,[string]$Color,[double]$Width=2,[string]$Extra='') { '<polyline points="'+(Points $Values)+'" fill="none" stroke="'+$Color+'" stroke-width="'+(Num $Width)+'" stroke-linecap="round" stroke-linejoin="round" '+$Extra+'/>' }
function Definitions($Roles) {
    $taskLight=Mix $Roles.top '#FFFFFF' .28; $taskRim=Mix $Roles.top '#E8F2BB' .30
    $taskOutline=Mix $Roles.top '#263D31' .56
    $taskSideDark=Mix $Roles.earth_side_dark '#26343A' .21
    @"
<defs>
 <linearGradient id="sideL" x1="0" y1="0" x2="0.4" y2="1"><stop stop-color="$(Mix $Roles.earth_side_light '#4A453E' .12)"/><stop offset="1" stop-color="$($Roles.earth_side_light)"/></linearGradient>
 <linearGradient id="sideR" x1="0" y1="0" x2="0.75" y2="1"><stop stop-color="$taskSideDark"/><stop offset="1" stop-color="$($Roles.earth_side_dark)"/></linearGradient>
 <linearGradient id="stone" x1="0" y1="0" x2="1" y2="1"><stop stop-color="$(Mix $Roles.stone '#FFFFFF' .17)"/><stop offset="1" stop-color="$(Mix $Roles.stone '#26343A' .17)"/></linearGradient>
 <linearGradient id="water" x1="0" y1="0" x2="0" y2="1"><stop stop-color="$($Roles.water)"/><stop offset="1" stop-color="$($Roles.water)"/></linearGradient>
 <radialGradient id="wash"><stop stop-color="$taskLight" stop-opacity=".20"/><stop offset=".75" stop-color="$taskLight" stop-opacity=".05"/><stop offset="1" stop-color="$taskLight" stop-opacity="0"/></radialGradient>
 <linearGradient id="wood" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#C29A6B"/><stop offset=".42" stop-color="#AD7D50"/><stop offset="1" stop-color="#91603E"/></linearGradient>
 <linearGradient id="fogNE" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#819B9B" stop-opacity=".65"/><stop offset=".58" stop-color="#A0B5AE" stop-opacity=".25"/><stop offset="1" stop-color="#B5C4BA" stop-opacity="0"/></linearGradient>
</defs>
"@
}
function Write-Asset([string]$Id,[string]$Biome,[string]$Kind,[string]$Body,$Size,$Pivot,[string]$Profile,[int]$Mask=0,[string]$Direction='',[int]$Depth=0,$Extra=@{}) {
    $taskFile = $Id+'.svg'
    $taskPath = Join-Path $taskSvgDirectory $taskFile
    $taskDocument='<svg xmlns="http://www.w3.org/2000/svg" width="'+$Size[0]+'" height="'+$Size[1]+'" viewBox="0 0 '+$Size[0]+' '+$Size[1]+'">'+$Body+'</svg>'
    [IO.File]::WriteAllText($taskPath,$taskDocument,[Text.UTF8Encoding]::new($false))
    $taskRow=[ordered]@{id=$Id;biome=$Biome;kind=$Kind;path='res://assets/world/shared_terrain/v1/svg/'+$taskFile;source_size=@($Size);pivot_px=@($Pivot);top_anchor_px=@($Pivot);bottom_anchor_px=@($Pivot[0],($Pivot[1]+$Depth*2));world_size=@(($Size[0]*.5),($Size[1]*.5));world_scale=.5;ground_origin=@(0,0);edge_mask=$Mask;direction=if($Direction){$Direction}else{$null};elevation=$Depth;side_depth_world_units=$Depth;top_plane_height_world_units=0;profile_id=$Profile;sorting='logical ground/top anchor; visual elevation applied independently';alpha='transparent RGBA vector; no opaque canvas/matte';treatments=@('material-colored thin contours on exposed edges','rim highlight plus dark contact seam','restrained original gradients/material cues','no internal tile-outline grid');placement='Position top_anchor at selected support plane; side depth is visual extent and never grants elevation/support';sha256=(Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash}
    foreach($taskKey in $Extra.Keys){$taskRow[$taskKey]=$Extra[$taskKey]}
    $taskEntries.Add($taskRow)
}
$taskTop=@(@(88,48),@(168,88),@(88,128),@(8,88))
function Terrain-Body($Roles,[int]$Mask,[int]$Depth,[bool]$Top=$true) {
    $taskBody=Definitions $Roles
    $taskDy=$Depth*2
    $taskDark=Mix $Roles.top '#263D31' .58
    $taskRim=Mix $Roles.top '#F0F6CA' .43
    if($Mask -band 4 -and $Depth -gt 0){
        $taskFace=@(@(8,88),@(88,128),@(88,(128+$taskDy)),@(8,(88+$taskDy)))
        $taskBody+=Polygon $taskFace 'url(#sideL)'
        $taskBody+=Stroke @(@(8,(88+$taskDy)),@(88,(128+$taskDy))) (Mix $Roles.earth_side_light '#2D3431' .48) 1.5
        $taskBody+=Polygon @(@(8,88),@(88,128),@(88,134),@(8,94)) (Mix $Roles.top '#394939' .23)
        $taskBody+=Stroke @(@(8,94),@(88,134)) '#3B3A30' 1.2 'opacity=".43"'
        if($Depth -ge 40){$taskBody+=Stroke @(@(19,108),@(40,119),@(42,128)) '#433F38' 1 'opacity=".17"'}
    }
    if($Mask -band 2 -and $Depth -gt 0){
        $taskFace=@(@(168,88),@(88,128),@(88,(128+$taskDy)),@(168,(88+$taskDy)))
        $taskBody+=Polygon $taskFace 'url(#sideR)'
        $taskBody+=Stroke @(@(88,(128+$taskDy)),@(168,(88+$taskDy))) (Mix $Roles.earth_side_dark '#24343A' .36) 1.5
        $taskBody+=Polygon @(@(168,88),@(88,128),@(88,134),@(168,94)) (Mix $Roles.top '#263E31' .32)
        $taskBody+=Stroke @(@(168,94),@(88,134)) '#333A30' 1.2 'opacity=".48"'
        if($Depth -ge 40){$taskBody+=Stroke @(@(151,112),@(132,122),@(129,135)) '#2B3538' 1 'opacity=".15"'}
    }
    if($Top){
        $taskBody+=Polygon $taskTop $Roles.top
        # Interior-only wash: shared top vertices and edge colors remain exact.
        $taskBody+='<ellipse cx="84" cy="85" rx="55" ry="21" fill="url(#wash)"/>'
        foreach($taskBit in @(1,2,4,8)){
            if(-not($Mask -band $taskBit)){continue}
            $taskIndex=@{1=0;2=1;4=2;8=3}[$taskBit]
            $taskA=$taskTop[$taskIndex]; $taskB=$taskTop[($taskIndex+1)%4]
            $taskBody+=Stroke @($taskA,$taskB) $taskDark 2.0
            $taskInset=@(@((88+($taskA[0]-88)*.972),(88+($taskA[1]-88)*.972)),@((88+($taskB[0]-88)*.972),(88+($taskB[1]-88)*.972)))
            $taskBody+=Stroke $taskInset $taskRim 2.15 'opacity=".94"'
        }
    }
    $taskBody
}
function Ramp-Body($Roles,[string]$Direction,[bool]$Stairs) {
    $taskBody=Definitions $Roles
    $taskHigh=@{NE=@(0,1);SE=@(1,2);SW=@(2,3);NW=@(3,0)}[$Direction]
    $taskRaised=@(for($taskI=0;$taskI -lt 4;$taskI++){,@($taskTop[$taskI][0],($taskTop[$taskI][1]-(40*[int]($taskI -in $taskHigh))))})
    foreach($taskEdge in @(@(1,2),@(2,3))){
        $taskA=$taskEdge[0];$taskB=$taskEdge[1]
        if(($taskA -in $taskHigh)-or($taskB -in $taskHigh)){
            $taskBody+=Polygon @($taskRaised[$taskA],$taskRaised[$taskB],$taskTop[$taskB],$taskTop[$taskA]) $(if($taskA -eq 1){'url(#sideR)'}else{'url(#sideL)'})
            $taskBody+=Stroke @($taskRaised[$taskA],$taskRaised[$taskB]) (Mix $Roles.top '#263D31' .5) 2
        }
    }
    if(-not $Stairs){$taskBody+=Polygon $taskRaised $Roles.top;$taskBody+=Polygon $taskRaised 'url(#wash)'}
    if($Stairs){
        # Four actual horizontal treads5/10/15/20wu, matching ceil(t*4)*5 profile.
        $taskH0=$taskTop[$taskHigh[0]];$taskH1=$taskTop[$taskHigh[1]]
        # Preserve quadrilateral topology; Euclidean nearest projected endpoints are wrong.
        $taskL0=$taskTop[($taskHigh[0]+3)%4];$taskL1=$taskTop[($taskHigh[1]+1)%4]
        $taskVisibleRisers=($taskL0[1]+$taskL1[1]) -gt ($taskH0[1]+$taskH1[1])
        $taskOrder=if($taskVisibleRisers){@(3,2,1,0)}else{@(0,1,2,3)}
        foreach($taskStep in $taskOrder){
            $taskT0=$taskStep/4.0;$taskT1=($taskStep+1)/4.0;$taskHeight=($taskStep+1)*10
            $taskA0=@(($taskL0[0]+($taskH0[0]-$taskL0[0])*$taskT0),($taskL0[1]+($taskH0[1]-$taskL0[1])*$taskT0-$taskHeight))
            $taskB0=@(($taskL1[0]+($taskH1[0]-$taskL1[0])*$taskT0),($taskL1[1]+($taskH1[1]-$taskL1[1])*$taskT0-$taskHeight))
            $taskA1=@(($taskL0[0]+($taskH0[0]-$taskL0[0])*$taskT1),($taskL0[1]+($taskH0[1]-$taskL0[1])*$taskT1-$taskHeight))
            $taskB1=@(($taskL1[0]+($taskH1[0]-$taskL1[0])*$taskT1),($taskL1[1]+($taskH1[1]-$taskL1[1])*$taskT1-$taskHeight))
            $taskBody+=Polygon @($taskA0,$taskA1,@($taskA1[0],($taskA1[1]+$taskHeight)),@($taskA0[0],($taskA0[1]+$taskHeight))) 'url(#sideL)'
            $taskBody+=Polygon @($taskB0,$taskB1,@($taskB1[0],($taskB1[1]+$taskHeight)),@($taskB0[0],($taskB0[1]+$taskHeight))) 'url(#sideR)'
            if($taskVisibleRisers){$taskBody+=Polygon @($taskA0,$taskB0,@($taskB0[0],($taskB0[1]+10)),@($taskA0[0],($taskA0[1]+10))) (Mix $Roles.top '#3B483E' .34)}
            $taskBody+=Polygon @($taskA0,$taskB0,$taskB1,$taskA1) $Roles.top
            $taskBody+=Stroke @($taskA0,$taskB0) (Mix $Roles.top '#FFFFFF' .4) 2.0
            $taskBody+=Stroke @($taskA0,$taskA1) (Mix $Roles.top '#263D31' .43) 1.5
            $taskBody+=Stroke @($taskB0,$taskB1) (Mix $Roles.top '#263D31' .47) 1.5
        }
    }
    if(-not $Stairs){$taskBody+=Stroke @($taskRaised[0],$taskRaised[1],$taskRaised[2],$taskRaised[3],$taskRaised[0]) (Mix $Roles.top '#263D31' .5) 1.7}
    $taskBody+=Stroke @($taskRaised[$taskHigh[0]],$taskRaised[$taskHigh[1]]) (Mix $Roles.top '#FFFFFF' .42) 2.2
    $taskBody
}
function Bridge-Body($Roles,[string]$Direction,[bool]$Rails,[string]$Layer='all') {
    $taskBody=Definitions $Roles
    $taskSign=if($Direction -eq 'NE'){-1}else{1}
    # Source center[300,180], half-length(200,+/-100), cross-half(80,-/+40).
    $taskL=@(200,(100*$taskSign));$taskW=@(80,(-40*$taskSign));$taskCenter=@(300,180)
    $taskCorners=@(@((300-$taskL[0]-$taskW[0]),(180-$taskL[1]-$taskW[1])),@((300-$taskL[0]+$taskW[0]),(180-$taskL[1]+$taskW[1])),@((300+$taskL[0]+$taskW[0]),(180+$taskL[1]+$taskW[1])),@((300+$taskL[0]-$taskW[0]),(180+$taskL[1]-$taskW[1])))
    # Modest cast shadow geometry is separate texture alpha, never support.
    $taskShadow=@($taskCorners | ForEach-Object {,@(($_[0]+13),($_[1]+24))})
    $taskBody+=Polygon $taskShadow '#243D39' 'opacity=".13"'
    foreach($taskEdge in @(@(0,1),@(1,2),@(2,3))){$taskA=$taskCorners[$taskEdge[0]];$taskB=$taskCorners[$taskEdge[1]];$taskBody+=Polygon @($taskA,$taskB,@($taskB[0],($taskB[1]+12)),@($taskA[0],($taskA[1]+12))) '#71513B'}
    $taskBody+=Polygon $taskCorners 'url(#wood)' 'stroke="#614936" stroke-width="2.2" stroke-linejoin="round"'
    for($taskN=1;$taskN -lt 14;$taskN++){
        $taskT=-1+$taskN/7.0
        $taskBase=@((300+$taskL[0]*$taskT),(180+$taskL[1]*$taskT))
        $taskA=@(($taskBase[0]-$taskW[0]),($taskBase[1]-$taskW[1]));$taskB=@(($taskBase[0]+$taskW[0]),($taskBase[1]+$taskW[1]))
        $taskBody+=Stroke @(@(($taskA[0]+1),($taskA[1]+2)),@(($taskB[0]+1),($taskB[1]+2))) '#644936' 2 'opacity=".72"'
        $taskBody+=Stroke @(@(($taskA[0]+1),($taskA[1]-1)),@(($taskB[0]+1),($taskB[1]-1))) '#D5AF7B' 1.6 'opacity=".75"'
        if(($taskN%3)-eq 0){$taskBody+=Stroke @(@(($taskBase[0]-16),($taskBase[1]-4)),@(($taskBase[0]+10),($taskBase[1]+8))) '#77543B' 1 'opacity=".24"'}
    }
    $taskDeckBody=$taskBody
    $taskBackRail='';$taskFrontRail=''
    if($Rails){
        foreach($taskSide in @(-1,1)){
            $taskRailBody=''
            $taskEnds=@()
            foreach($taskT in @(-.9,-.3,.3,.9)){
                $taskX=300+$taskL[0]*$taskT+$taskW[0]*$taskSide;$taskY=180+$taskL[1]*$taskT+$taskW[1]*$taskSide
                $taskRailBody+=Polygon @(@(($taskX-4),$taskY),@(($taskX+3),($taskY+3)),@(($taskX+3),($taskY-30)),@(($taskX-4),($taskY-33))) '#815E41' 'stroke="#614936" stroke-width="1.2"'
                $taskRailBody+=Stroke @(@(($taskX-3),($taskY-31)),@(($taskX+2),($taskY-29))) '#C8A476' 1.4
            }
            $taskA=@((300-$taskL[0]*.96+$taskW[0]*$taskSide),(180-$taskL[1]*.96+$taskW[1]*$taskSide-28))
            $taskB=@((300+$taskL[0]*.96+$taskW[0]*$taskSide),(180+$taskL[1]*.96+$taskW[1]*$taskSide-28))
            $taskRailBody+=Stroke @($taskA,$taskB) '#654B35' 5
            $taskRailBody+=Stroke @(@($taskA[0],($taskA[1]-1)),@($taskB[0],($taskB[1]-1))) '#C9A675' 2
            if($taskW[1]*$taskSide -gt 0){$taskFrontRail=$taskRailBody}else{$taskBackRail=$taskRailBody}
        }
    }
    if($Layer -eq 'back_rail'){return ((Definitions $Roles)+$taskBackRail)}
    if($Layer -eq 'front_rail'){return ((Definitions $Roles)+$taskFrontRail)}
    if($Layer -eq 'supports'){
        $taskSupportBody=Definitions $Roles
        foreach($taskT in @(-.72,.72)){
            foreach($taskSide in @(-1,1)){
                $taskX=300+$taskL[0]*$taskT+$taskW[0]*$taskSide*.75;$taskY=180+$taskL[1]*$taskT+$taskW[1]*$taskSide*.75
                $taskSupportBody+=Polygon @(@(($taskX-5),($taskY+9)),@(($taskX+4),($taskY+12)),@(($taskX+4),($taskY+41)),@(($taskX-5),($taskY+38))) '#77533B' 'stroke="#574232" stroke-width="1.3"'
                $taskSupportBody+=Stroke @(@(($taskX-3),($taskY+12)),@(($taskX-3),($taskY+35))) '#B18B5E' 1.4
            }
        }
        return $taskSupportBody
    }
    $taskDeckBody+$taskBackRail+$taskFrontRail
}
$taskBiomes=@{1='snow';2='grass';3='lab'}
foreach($taskBiome in $taskContract.biome_palettes){
    $taskName=$taskBiomes[[int]$taskBiome.zone]; $taskRoles=$taskBiome.roles
    $taskMasks=if($SampleOnly){@(15)}else{@(0..15)}
    $taskDepths=if($SampleOnly){@(20)}else{@(20,40,60)}
    foreach($taskDepth in $taskDepths){
        foreach($taskMask in $taskMasks){
            $taskProfile=if($taskDepth -gt 20){'cliff80x40'}elseif($taskMask -eq 0){'flat80x40'}else{'edge80x40'}
            Write-Asset ($taskName+'_tile_e'+$taskMask+'_h'+$taskDepth) $taskName $(if($taskDepth -gt 20){'cliff'}else{'terrain_tile'}) (Terrain-Body $taskRoles $taskMask $taskDepth) @(176,[Math]::Max(176,136+$taskDepth*2)) @(88,88) $taskProfile $taskMask '' $taskDepth
        }
    }
    foreach($taskDirection in @('NE','SE','SW','NW')){
        Write-Asset ($taskName+'_ramp_'+$taskDirection) $taskName 'ramp' (Ramp-Body $taskRoles $taskDirection $false) @(176,176) @(88,88) ('ramp_'+$taskDirection+'20') 15 $taskDirection 20 @{high_edge=$taskDirection;high_height_world_units=20;ramp_height_rule='See matching profile: high edge+20, low edge0; art/supported height interpolation separate'}
        Write-Asset ($taskName+'_stairs_'+$taskDirection) $taskName 'stairs' (Ramp-Body $taskRoles $taskDirection $true) @(176,176) @(88,88) ('stairs_'+$taskDirection+'20') 15 $taskDirection 20 @{high_edge=$taskDirection;high_height_world_units=20;treads=4;tread_rise_world_units=5}
    }
    if(-not $SampleOnly){
        foreach($taskDepth in @(20,40,60)){
            foreach($taskPair in @(@('SE',2),@('SW',4))){Write-Asset ($taskName+'_side_'+$taskPair[0]+'_h'+$taskDepth) $taskName 'side_only' (Terrain-Body $taskRoles $taskPair[1] $taskDepth $false) @(176,[Math]::Max(176,136+$taskDepth*2)) @(88,88) 'side_only' $taskPair[1] $taskPair[0] $taskDepth}
        }
        foreach($taskDirection in @('NE','SE','SW','NW')){
            $taskIndex=@{NE=0;SE=1;SW=2;NW=3}[$taskDirection]
            $taskMask=(1 -shl $taskIndex) -bor (1 -shl (($taskIndex+1)%4))
            foreach($taskKind in @('outer','inner')){
                $taskCornerBody=Definitions $taskRoles
                if($taskKind -eq 'outer'){$taskCornerBody=Terrain-Body $taskRoles $taskMask 20}
                else{
                    $taskCorner=$taskTop[($taskIndex+1)%4]
                    $taskA=@((88+($taskTop[$taskIndex][0]-88)*.43),(88+($taskTop[$taskIndex][1]-88)*.43))
                    $taskB=@((88+($taskTop[($taskIndex+2)%4][0]-88)*.43),(88+($taskTop[($taskIndex+2)%4][1]-88)*.43))
                    $taskCornerBody+=Stroke @($taskA,$taskCorner,$taskB) (Mix $taskRoles.top '#243D32' .58) 3.3 'opacity=".7"'
                    $taskCornerBody+=Stroke @(@($taskA[0],($taskA[1]-2)) ,@($taskCorner[0],($taskCorner[1]-2)),@($taskB[0],($taskB[1]-2))) (Mix $taskRoles.top '#F0F6CA' .43) 1.8
                }
                Write-Asset ($taskName+'_corner_'+$taskKind+'_'+$taskDirection) $taskName 'corner_overlay' $taskCornerBody @(176,176) @(88,88) 'corner_overlay' $taskMask $taskDirection $(if($taskKind -eq 'outer'){20}else{0}) @{composition=if($taskKind -eq 'inner'){'Concave boundary contact overlay; place only at compatible 3-tile union boundary, never as standalone ground'}else{'Convex two-edge cap visual; matching underlying support must be separately instanced'}}
            }
        }
    }
    foreach($taskMask in $taskMasks){
        $taskWaterBody=(Definitions $taskRoles)+(Polygon $taskTop $taskRoles.water)
        # No border/glint in shared base: edges match exactly across every joined water cell.
        if($taskMask -gt 0){
            foreach($taskBit in @(1,2,4,8)){
                if(-not($taskMask -band $taskBit)){continue}
                $taskIndex=@{1=0;2=1;4=2;8=3}[$taskBit];$taskA=$taskTop[$taskIndex];$taskB=$taskTop[($taskIndex+1)%4]
                $taskWaterBody+=Stroke @($taskA,$taskB) (Mix $taskRoles.water '#1B3D4A' .5) 6
                $taskWaterBody+=Stroke @(@((88+($taskA[0]-88)*.94),(88+($taskA[1]-88)*.94)),@((88+($taskB[0]-88)*.94),(88+($taskB[1]-88)*.94))) (Mix $taskRoles.water '#C6DFD9' .36) 2.2
            }
        }
        Write-Asset ($taskName+'_water_e'+$taskMask) $taskName $(if($taskMask){'shore_water'}else{'water'}) $taskWaterBody @(176,176) @(88,88) $(if($taskMask){'shore_water'}else{'water80x40'}) $taskMask '' 0 @{phase='liquid; no implicit floor support';shore_rule='Masked edge is visual water-depth/shoreline band; neighboring land owns support'}
    }
}
if(-not $SampleOnly){
    $taskRoles=$taskContract.biome_palettes[1].roles
    foreach($taskDirection in @('NE','SE')){
        foreach($taskRails in @($false,$true)){Write-Asset ('bridge_'+$taskDirection+'_'+$(if($taskRails){'rails'}else{'open'})) 'shared' $(if($taskRails){'bridge_preview'}else{'bridge'}) (Bridge-Body $taskRoles $taskDirection $taskRails) @(600,360) @(300,180) ('bridge_'+$taskDirection) 0 $taskDirection 0 @{support_width_world_units=71.554175;span_world_units=223.606798;rail_visual_only=$taskRails;bridge_top_anchor_px=@(300,180);visual_origin='top center; supports/side shadow do not extend floor coverage';layer_usage=if($taskRails){'Preview/contact sheet only. Production actors require open floor + back/front rail layers.'}else{'Production deck. Add back rail behind actor and front rail in front; support remains separate.'}}}
        foreach($taskLayer in @('back_rail','front_rail','supports')){Write-Asset ('bridge_'+$taskDirection+'_'+$taskLayer) 'shared' 'bridge_overlay' (Bridge-Body $taskRoles $taskDirection $true $taskLayer) @(600,360) @(300,180) 'side_only' 0 $taskDirection 0 @{rail_visual_only=$true;layer_usage=if($taskLayer -eq 'front_rail'){'Foreground rail only; render in front of actor on supported deck'}elseif($taskLayer -eq 'back_rail'){'Background rail only; render behind actor on supported deck'}else{'Supports only; render beneath deck, no added floor'}}}
    }
    foreach($taskDirection in @('NE','SE','SW','NW')){
        $taskAngle=@{NE=0;SE=90;SW=180;NW=270}[$taskDirection]
        $taskBody='<defs><linearGradient id="mist" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#799398" stop-opacity=".68"/><stop offset=".42" stop-color="#99ADAB" stop-opacity=".36"/><stop offset="1" stop-color="#C5D1C8" stop-opacity="0"/></linearGradient></defs><g transform="rotate('+$taskAngle+' 88 88)"><path d="M8 48 Q28 42 48 49 T88 48 T128 49 T168 48 L168 128 L8 128 Z" fill="url(#mist)"/></g>'
        Write-Asset ('fog_edge_'+$taskDirection) 'shared' 'fog_edge' $taskBody @(176,176) @(88,88) 'fog_edge' 0 $taskDirection 0 @{permission='visual-only; invisible access barrier profile is independent';composition='Soft-alpha edge layer over actual terrain; no matte or support/collision'}
    }
}
$taskCatalog=[ordered]@{schema_version=1;kit_id='phase-quest-shared-terrain-v1';prompt='R3 003';date='2026-11-15';source='tools/art/shared_terrain_v1/build_terrain.ps1';provenance='Original deterministic editable SVG authored for this project. No copied reference pixels, third-party raster assets or generated character substitutions.';standard_id=$taskContract.standard_id;status='Production resources generated; root isolated import/render/physics/visual review remains separate';sample_only=[bool]$SampleOnly;coordinate_contract=[ordered]@{tile_world_units=@(80,40);source_pixels_per_world_unit=2;world_scale=.5;tile_source_vertices=@($taskTop);tile_top_anchor_px=@(88,88);edge_bits=[ordered]@{NE=1;SE=2;SW=4;NW=8};edge_sequence=@('north->east','east->south','south->west','west->north');surface_elevation='Placement supplied separately; .elevation is visible side depth only, not a progression or support claim';ground_sorting='Store logical ground origin, support plane and visual elevation separately';seam_contract='All base top vertices exact; internal edges unoutlined; land base edge color exact per biome; water unmasked base flat exact matching color';top_support='Separate reusable support profile; no collision encoded in SVG or inferred from alpha'};entry_count=$taskEntries.Count;entries=@($taskEntries)}
$taskCatalog | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath (Join-Path $taskDestination 'terrain_catalog.json') -Encoding utf8
Write-Output ('TERRAIN SVG BUILD: '+$taskEntries.Count+' assets; sample_only='+[bool]$SampleOnly)
