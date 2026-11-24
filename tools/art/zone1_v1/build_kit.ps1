$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$taskOut=Join-Path $taskRoot 'assets/zones/zone_1/world_v1'
New-Item -ItemType Directory -Force (Join-Path $taskOut svg)|Out-Null
$taskRows=[Collections.Generic.List[object]]::new()
$taskDefs=@'
<defs>
<linearGradient id="snow" x2=".3" y2="1"><stop stop-color="#FCFEF5"/><stop offset="1" stop-color="#BDCED2"/></linearGradient>
<linearGradient id="pine" x2=".8" y2="1"><stop stop-color="#6E9781"/><stop offset="1" stop-color="#365B57"/></linearGradient>
<linearGradient id="wood" x2=".8" y2="1"><stop stop-color="#B98B63"/><stop offset="1" stop-color="#745347"/></linearGradient>
<linearGradient id="metal" x2=".85" y2="1"><stop stop-color="#D0E1DF"/><stop offset=".45" stop-color="#8AA1A8"/><stop offset="1" stop-color="#465D6A"/></linearGradient>
<linearGradient id="brass" x2=".7" y2="1"><stop stop-color="#F3D798"/><stop offset=".5" stop-color="#C99B56"/><stop offset="1" stop-color="#8C653D"/></linearGradient>
<linearGradient id="ice" x2=".7" y2="1"><stop stop-color="#EDFDFC" stop-opacity=".93"/><stop offset=".4" stop-color="#A4DEEB" stop-opacity=".88"/><stop offset="1" stop-color="#71A9C2" stop-opacity=".93"/></linearGradient>
<linearGradient id="water" x2=".4" y2="1"><stop stop-color="#81BDC6"/><stop offset="1" stop-color="#477D96"/></linearGradient>
<linearGradient id="warm" x2="0" y2="1"><stop stop-color="#FFF2B6"/><stop offset=".6" stop-color="#E6A34A"/><stop offset="1" stop-color="#AE613F"/></linearGradient>
</defs>
'@
function Path([string]$D,[string]$Fill,[string]$Extra=''){return '<path d="'+$D+'" fill="'+$Fill+'" '+$Extra+'/>'}
function Line([string]$D,[string]$Color='#F3E8CB',[double]$Width=2){return Path $D none ('stroke="'+$Color+'" stroke-width="'+$Width+'"')}
function Shadow([double]$Rx=60){return '<ellipse cx="139" cy="211" rx="'+$Rx+'" ry="14" fill="#294B51" opacity=".18" stroke="none"/>'}
function Mark([string]$State){
 switch($State){
  selected {return '<path d="M41 210l-10-8 10-8m174 0 10 8-10 8" fill="none" stroke="#E6A34A" stroke-width="4"/>'}
  wrong {return '<path d="M202 154l17 17m0-17-17 17" fill="none" stroke="#AD554B" stroke-width="5"/>'}
  solved {return '<path d="M199 166l8 8 18-22" fill="none" stroke="#386D62" stroke-width="5"/>'}
  default {return ''}
 }
}
function Asset([string]$Id,[string]$Family,[string]$Group,[string]$State,[string]$Body,[double[]]$Foot=@(-24,-12,48,24),[hashtable]$Extra=@{}){
 $taskW=256;$taskH=256;$taskPivot=@(128,208)
 if($Extra.ContainsKey('large') -and $Extra.large){$taskW=384;$taskH=320;$taskPivot=@(192,264);$Body='<g transform="translate(64 56)">'+$Body+'</g>'}
 $taskFile=Join-Path $taskOut ('svg/'+$Id+'.svg')
 $taskSvg='<svg xmlns="http://www.w3.org/2000/svg" width="'+$taskW+'" height="'+$taskH+'" viewBox="0 0 '+$taskW+' '+$taskH+'">'+$taskDefs+'<g stroke="#344A52" stroke-width="2" stroke-linejoin="round" stroke-linecap="round">'+$Body+'</g></svg>'
 [IO.File]::WriteAllText($taskFile,$taskSvg,[Text.UTF8Encoding]::new($false))
 $taskRow=[ordered]@{id=$Id;family=$Family;group=$Group;state=$State;path=('res://assets/zones/zone_1/world_v1/svg/'+$Id+'.svg');source_size=@($taskW,$taskH);pivot_px=$taskPivot;world_scale=.5;sorting='ground pivot, caller-owned elevation; no baked support permission';footprint_world=$Foot;collision_status='proposed placement envelope only; no active collision or gameplay';owner='R3 004';consumer='isolated review now; future R3 016 and R3 024-030/045 adapters';dependencies=@('R3 002 measured contract','R3 003 shared snow terrain');action='new';source_format='original editable native SVG';license='Original project-authored geometry; no third-party extraction';sha256=(Get-FileHash $taskFile -Algorithm SHA256).Hash}
 foreach($taskKey in $Extra.Keys){$taskRow[$taskKey]=$Extra[$taskKey]}
 $taskRows.Add($taskRow)
}
function Box([int]$X,[int]$Y,[int]$W,[int]$D,[int]$H,[string]$Top='url(#snow)',[string]$Left='#9CAFAF',[string]$Right='#728A90'){
 $a=$X-$W;$b=$X+$W;$c=$Y+$D;$z=$Y-$H;$q=$c-$H
 return (Path "M$a $z L$X $q L$X $c L$a $Y Z" $Left)+(Path "M$X $q L$b $z L$b $Y L$X $c Z" $Right)+(Path "M$X $($z-$D) L$b $z L$X $q L$a $z Z" $Top)+(Line "M$a $z L$X $($z-$D) L$b $z" '#F6FFF2' 1.8)
}
function Pool([int]$Radius=58){return (Path "M$(128-$Radius) 207q$Radius -24 $($Radius*2) 0q-18 23 -$Radius 13q-40 9 -$Radius -13z" 'url(#water)')+(Line 'M92 208l23-4m20 12 25-5' '#C5EBE9' 2)}
function Ice([int]$Stage=0,[int]$Width=100,[int]$Height=90){
 if($Stage -ge 3){return Pool ([int]($Width*.6))}
 $taskHalf=[int]($Width*.5);$taskDrop=[int]($Height*(1-($Stage*.26)));$taskL=128-$taskHalf;$taskR=128+$taskHalf;$taskTop=201-$taskDrop
 $taskB=if($Stage -gt 0){Pool ([int]($Width*.6))}else{Shadow ($Width*.55)}
 $taskB+=Path "M$taskL $taskTop L128 $($taskTop-15) L$taskR $taskTop L$taskR 195 L128 213 L$taskL 195Z" 'url(#ice)'
 $taskB+=Path "M$taskL $taskTop L128 $($taskTop+15) L$taskR $taskTop M128 $($taskTop+15)V213" none 'stroke="#78ABBD"'
 $taskB+=Line "M$($taskL+5) $($taskTop+3) L128 $($taskTop-10) L$($taskR-7) $($taskTop+2) M$($taskL+9) $($taskTop+20)v23" '#F4FFFD' 3
 if($Stage -gt 0){$taskB+=Line "M$taskL 204l-7 7M$($taskR+4) 204l6 6" '#C9EFF0' 2}
 return $taskB
}
function Tray([string]$State,[string]$Insert=''){
 $taskB=Shadow 63
 $taskB+=Box 128 204 65 25 13 'url(#metal)' '#6C8994' '#465F6F'
 $taskB+=Path 'M75 180l52-21 53 22-53 24z' '#304F5B'
 if($State -in @('liquid','freezing','solid','latched','melting','fitted')){$taskB+=Path 'M80 180l47-18 48 19-48 21z' 'url(#water)';$taskB+=Line 'M96 180l23-8m9 16 21-8' '#C9F0EA' 2}
 if($State -in @('freezing','solid','latched','fitted')){$taskB+=Path 'M80 180l47-18 48 19-48 21z' 'url(#ice)';$taskB+=Line 'M89 180l35-13m10 16 28-3' '#F9FFFC' 3;if($State -eq 'freezing'){$taskB+=Path 'M80 180l47 5 48-4-48 21z' 'url(#water)'}}
 if($State -eq 'melting'){$taskB+=Path 'M106 178l22-8 24 10-25 10z' 'url(#ice)'}
 if($State -eq 'latched'){$taskB+=Path 'M66 191l22 10v10l-22-9zm101 0 23-10v10l-23 10z' 'url(#brass)';$taskB+=Line 'M66 197l22 9m79-9 23-10' '#F8E4B8'}
 return $taskB+$Insert
}
function Part([string]$Name,[string]$Fill='url(#metal)'){
 switch($Name){
 gear {return '<g transform="translate(128 168)">'+(Path 'M-9-35H9l3 9 9 5 9-2 9 15-7 7v9l7 7-9 15-10-2-8 5-3 9H-9l-3-9-9-5-9 2-9-15 7-7v-9l-7-7 9-15 9 2 9-5z' $Fill)+'<circle r="20" fill="#415A64"/><circle r="9" fill="url(#brass)"/>'+(Line 'M-6-29H6m-32 11 4-6' '#EDF4E8' 2)+'</g>'}
 crank {return (Path 'M104 201q-20-3-18-19 1-14 19-17l9-46q1-9 11-10l49-1 5 15-43 9-10 48q-2 21-22 21z' $Fill)+'<ellipse cx="105" cy="181" rx="9" ry="10" fill="url(#brass)"/><path d="M129 106q-4 10 3 24l39-3q12-10 0-23z" fill="url(#wood)"/>'+(Line 'M100 172l13-6 10-47m14-9h28' '#E9E9CF' 2)}
 brake_shoe {return (Path 'M79 179q18-57 85-49l17 22-10 15-16-2q-35-3-44 28l-24 3z' $Fill)+(Path 'M85 174q22-45 73-37l9 13q-48-6-66 34z' 'url(#brass)')+'<circle cx="104" cy="158" r="3" fill="#6E5945"/><circle cx="140" cy="145" r="3" fill="#6E5945"/><ellipse cx="94" cy="187" rx="5" ry="3" fill="#334D58"/>'}
 }
}
function Plank([string]$Type='plank'){
 switch($Type){
 plank {return (Path 'M74 166l77-20 35 15-77 27z' 'url(#wood)')+(Path 'M74 166l35 22v11l-35-22zm35 22 77-27v11l-77 27z' '#80604C')+(Line 'M88 164l22 14 60-19m-57 18 28-8' '#DAB68A' 2)}
 rope {return '<g fill="none" stroke="#594C3F" stroke-width="10"><ellipse cx="128" cy="177" rx="40" ry="20"/><ellipse cx="128" cy="174" rx="28" ry="12"/></g><g fill="none" stroke="#D8C195" stroke-width="6"><ellipse cx="128" cy="175" rx="40" ry="20"/><ellipse cx="128" cy="172" rx="28" ry="12"/><path d="M162 183l18 13-9 8"/></g>'}
 sailcloth {return (Path 'M84 157l64-7 29 25-63 18z' '#F3E8CB')+(Path 'M84 157l30 24 63-6v15l-63 16-30-30z' '#C2B59A')+(Line 'M94 159l25 19 45-6m-43 9v20' '#FFFAE3')}
 rudder {return (Path 'M117 128l14-5 7 40 26 13-1 31-44-19z' 'url(#wood)')+(Line 'M124 135l7 35 24 13v18' '#DDBB8D')+(Path 'M117 148l17-4 2 9-17 4zm5 23 17-3 1 9-17 4z' 'url(#metal)')}
 }
}
# Original sparse snow dressing: stepped canopies, quiet surfaces, no tile clutter.
foreach($taskTree in @('young','pine','birch')){
 $taskB=Shadow 53
 $taskB+=Path 'M127 202l30-7 29 11 16 1 27 17-25 13-30-1-25-15z' '#294B51' 'opacity=".16" stroke="none"'
 $taskB+=Box 128 205 10 5 63 'url(#wood)' '#88654F' '#694D45'
 if($taskTree -eq 'birch'){$taskB+=Path 'M118 145l10 5v60l-10-5z' '#D8DDD0';$taskB+=Line 'M119 163l6 2m-6 15 6 2' '#58686A'}
 $taskB+=Box 109 149 34 17 39 'url(#pine)' '#527D6A' '#365C55'
 $taskB+=Box 148 145 32 16 41 'url(#pine)' '#527D6A' '#365C55'
 $taskB+=Box 128 113 32 16 34 'url(#snow)' '#AFC6C5' '#839F9F'
 $taskB+=Path 'M75 110l34-18 34 17-13 4-17-3-14 8z M116 104l32-16 32 16-21 8-12-5-18 6z' 'url(#snow)'
 if($taskTree -eq 'pine'){$taskB+=Box 128 73 21 11 24 'url(#snow)' '#AFC6C5' '#839F9F'}
 Asset ('snow_tree_'+$taskTree) 'z1.vegetation.rocks' ('tree_'+$taskTree) idle $taskB @(-13,-8,26,16)
}
$taskRock=(Shadow 42)+(Box 112 202 24 12 30 'url(#snow)' '#A4B2B6' '#71878E')+(Box 148 206 19 10 18 'url(#snow)' '#A4B2B6' '#71878E')+(Box 130 177 19 10 21 'url(#snow)' '#A4B2B6' '#71878E')
Asset snow_rocks 'z1.vegetation.rocks' rocks idle $taskRock @(-23,-12,46,24)
Asset snow_shrub 'z1.vegetation.rocks' shrub idle ((Shadow 28)+(Box 116 204 18 9 14 'url(#pine)' '#527D6A' '#365C55')+(Box 141 207 16 8 21 'url(#snow)' '#AFC6C5' '#839F9F')) @(-14,-7,28,14)
Asset snow_tuft 'z1.vegetation.rocks' tuft idle ((Path 'M112 207l-4-20 12 11 5-25 6 27 13-13-4 22z' '#658F80')+(Line 'M125 182v22' '#B9CFC0')) @(0,0,0,0)
Asset snow_flower 'z1.vegetation.rocks' flower idle ((Path 'M126 208v-31m0 24-12-9m12 5 13-8' none 'stroke="#527D6A" stroke-width="3"')+'<path d="M126 169l7 8-7 8-7-8z" fill="#E7D694" stroke="#887D55"/><circle cx="126" cy="177" r="3" fill="#FFF9D7"/>') @(0,0,0,0)
Asset fallen_log 'z1.vegetation.rocks' log idle ((Shadow 45)+(Path 'M83 180l74-21 21 16-2 20-73 23-22-18z' 'url(#wood)')+'<ellipse cx="95" cy="197" rx="15" ry="17" fill="#D9BA8F"/><ellipse cx="95" cy="197" rx="8" ry="10" fill="none" stroke="#936F51"/>'+(Line 'M109 185l53-16m-51 27 52-16' '#CEAB80')) @(-25,-10,50,20)
foreach($taskState in @('cold','warm')){
 $taskB=(Shadow 108)+(Box 128 205 89 44 67 'url(#wood)' '#916B51' '#6B5147')
 $taskB+=Path 'M39 138l89-82 89 82-89 45z' 'url(#snow)';$taskB+=Path 'M39 138l89 45v10l-89-44zm89 45 89-45v10l-89 45z' '#A5BDBE'
 $taskB+=Path 'M137 177l34-16v56l-34 16z' '#354B50'
 $taskB+=Path 'M72 163l31 16v22l-31-16z' $(if($taskState -eq 'warm'){'url(#warm)'}else{'#739CA9'})
 $taskB+=Line 'M87 171v23m-15-21 31 16' '#C0D4D0'
 Asset ('shelter_'+$taskState) 'z1.vegetation.rocks' shelter $taskState $taskB @(-45,-23,90,46) @{large=$true}
}
# Garden machines retain fuel/fan/mirror identities; fire is not a bypass.
foreach($taskState in @('empty','fueled','active','isolated')){
 $taskB=(Shadow 47)+(Box 128 201 36 18 64 'url(#metal)' '#899A9B' '#526D78')
 $taskB+=Path 'M93 146l34 17v35l-34-17z' '#314953';$taskB+=Path 'M103 159l17 8v20l-17-8z' $(if($taskState -eq 'active'){'url(#warm)'}else{'#775E4B'})
 $taskB+=Path 'M138 145l15-7v-43l-15 7z' 'url(#metal)';$taskB+=Path 'M134 102l19-9 12 6-19 10z' '#DFE8DA'
 foreach($taskX in @(101,110,119)){$taskB+=Line "M$taskX $($taskX+51)v27" '#9FB8B9'}
 if($taskState -ne 'empty'){$taskB+=Path 'M140 190l27-12 11 6-27 15z' 'url(#wood)'}
 if($taskState -eq 'active'){$taskB+=Line 'M159 123l17-8m-13 20 18-5' '#E6A34A' 3}
 if($taskState -eq 'isolated'){$taskB+=Path 'M145 139l23-10 6 8-23 10z' 'url(#brass)';$taskB+=Line 'M148 135l20 8' '#344A52' 3}
 Asset ('heater_'+$taskState) 'z1.heater.fan.mirror' heater $taskState $taskB
}
foreach($taskState in @('off','blocked','turn_a','turn_b')){
 $taskB=(Shadow 41)+(Box 128 205 30 15 8 'url(#metal)' '#899A9B' '#526D78')+(Path 'M122 192v-27h12v27z' 'url(#metal)')+'<circle cx="128" cy="137" r="36" fill="#54717A"/><circle cx="128" cy="137" r="29" fill="#304D57"/>'
 $taskAngle=if($taskState -eq 'turn_b'){45}else{0}
 $taskB+='<g transform="rotate('+$taskAngle+' 128 137)">'
 foreach($taskAngle in @(0,90,180,270)){$taskB+='<path d="M128 137q-24-27-25-8t25 8" fill="url(#metal)" transform="rotate('+$taskAngle+' 128 137)"/>'}
 $taskB+='</g><circle cx="128" cy="137" r="7" fill="url(#brass)"/>'
 if($taskState -eq 'blocked'){$taskB+=Line 'M104 113l48 48m-48 0 48-48' '#8FAEBB' 8}
 Asset ('fan_'+$taskState) 'z1.heater.fan.mirror' fan $taskState $taskB
}
for($taskI=0;$taskI -lt 8;$taskI++){
 $taskB=(Shadow 39)+(Box 128 205 29 15 8 'url(#metal)' '#899A9B' '#526D78')+(Path 'M124 195v-38h8v38z' 'url(#brass)')
 $taskAngle=$taskI*[Math]::PI/4
 $taskDx=[Math]::Round([Math]::Cos($taskAngle)*27,2);$taskDy=[Math]::Round(-[Math]::Sin($taskAngle)*13.5,2)
 if([Math]::Abs($taskDx) -lt 3){$taskDx=3} # Edge-on frame remains legible; no rolled billboard.
 $taskB+=Path "M$(128-$taskDx) $(116-$taskDy)L$(128+$taskDx) $(116+$taskDy)L$(128+$taskDx) $(176+$taskDy)L$(128-$taskDx) $(176-$taskDy)Z" $(if([Math]::Cos($taskAngle) -ge 0){'#BAD8DA'}else{'url(#metal)'}) 'stroke-width="4"'
 $taskB+=Line "M$(130-$taskDx) $(119-$taskDy)L$(127+$taskDx) $(119+$taskDy)" '#F3FEF6' 2
 $taskRayX=[Math]::Sin($taskAngle);$taskRayY=[Math]::Cos($taskAngle)*.5
 $taskTipX=[Math]::Round(128+$taskRayX*29,2);$taskTipY=[Math]::Round(212+$taskRayY*29,2)
 $taskB+=Line "M128 212L$taskTipX $taskTipY" '#B18B4F' 3
 $taskB+='<circle cx="'+$taskTipX+'" cy="'+$taskTipY+'" r="3" fill="#E6A34A"/>'
 Asset ('mirror_'+$taskI) 'z1.heater.fan.mirror' mirror ('orientation_'+$taskI) $taskB @(-18,-10,36,20) @{orientation_index=$taskI;beam_direction_basis=@([Math]::Round($taskRayX,8),[Math]::Round($taskRayY,8));action='restyle';observed_source=('assets/zones/zone_1/flat_v1/props/mirror_'+$taskI+'.tres');science='eight existing 45-degree yaw indices; ground direction cue matches sin(a),cos(a)*.5; art never emits a ray'}
}
Asset interaction_selected 'z1.heater.fan.mirror' interaction selected (Mark selected) @(0,0,0,0) @{layer='overlay; no authority'}
foreach($taskState in @('off','on')){
 $taskB=(Shadow 30)+(Box 128 205 21 11 40 'url(#metal)' '#899A9B' '#526D78')+'<circle cx="128" cy="157" r="15" fill="'+$(if($taskState -eq 'on'){'#E6A34A'}else{'#496573'})+'"/>'+(Line 'M120 150l9-4' '#F9F5DC' 2)
 Asset ('receiver_'+$taskState) 'z1.heater.fan.mirror' receiver $taskState $taskB
}
foreach($taskGate in @('direct','fan','relay')){for($taskI=0;$taskI -lt 5;$taskI++){
 $taskB=if($taskI -lt 4){Ice $taskI 140 106}else{(Pool 80)+(Mark solved)}
 Asset ('barrier_'+$taskGate+'_'+$taskI) 'z1.ice.crystals' ('barrier_'+$taskGate) (@('solid','melting_early','melting_late','liquid','cleared')[$taskI]) $taskB @(-38,-18,76,36) @{science='solid water -> liquid water; no gas, cracks do not substitute for melting';authority=('future adapter '+$taskGate+' conditions, never texture state')}
}}
for($taskI=0;$taskI -lt 6;$taskI++){foreach($taskState in @('locked','warming','ready','collected')){
 $taskB=Shadow 24
 if($taskState -ne 'collected'){
  $taskB+=Path 'M128 124l20 32-7 30-13 11-14-14-6-30z' '#B8A0DC';$taskB+=Path 'M128 124v73l-14-14-6-30z' '#E2D6EE';$taskB+=Line 'M128 128l15 28-15 5-15-8' '#FFF4F9' 2
  # A distinct pip count is shape evidence for six stable existing numeric IDs.
  for($taskP=0;$taskP -le $taskI;$taskP++){$taskB+='<circle cx="'+(108+$taskP*8)+'" cy="216" r="2.5" fill="#62567E" stroke="none"/>'}
  if($taskState -eq 'locked'){$taskB+=Ice 0 61 93}
  if($taskState -eq 'warming'){$taskB+=Ice 2 61 93}
 }else{$taskB+=Mark solved}
 Asset ('crystal'+$taskI+'_'+$taskState) 'z1.ice.crystals' ('crystal'+$taskI) $taskState $taskB @(-11,-6,22,12) @{stable_pickup_id=('crystal'+$taskI);science='warming melts casing; crystal identity and earned pickup remain unchanged'}
}}
# Reuse compatible native bell and winch bodies verbatim, registering old origin into new canvas.
foreach($taskPitch in @('low','mid','high')){foreach($taskState in @('idle','played','wrong','solved')){
 $taskSource='assets/zones/zone_1/frozen_mill/redesign/bell_'+$taskPitch+'.svg'
 $taskInner=(Get-Content -Raw (Join-Path $taskRoot $taskSource)) -replace '^<svg[^>]*>','' -replace '</svg>\s*$',''
 $taskB='<g transform="translate(58 68) scale(1.4)">'+$taskInner+'</g>'
 if($taskState -eq 'played'){$taskB+=Line 'M71 127q-13 20 0 37m114-37q13 20 0 37' '#E6A34A' 4}
 $taskB+=Mark $taskState
 Asset ('bell_'+$taskPitch+'_'+$taskState) 'z1.bells' ('bell_'+$taskPitch) $taskState $taskB @(-28,-12,56,24) @{action='keep';observed_source=$taskSource;reuse='unchanged native SVG body inside registered wrapper; added separate feedback';science='mechanical resonance, not a melting observation'}
}}
foreach($taskState in @('intact','fractured','clear')){
 $taskB=if($taskState -eq 'clear'){(Shadow 50)+(Mark solved)}else{Ice 0 133 66}
 if($taskState -eq 'fractured'){$taskB+=Line 'M90 146l20 19-9 15 22 12m18-50-9 27 21 17' '#4E8398' 3}
 Asset ('bell_bridge_'+$taskState) 'z1.bells' bell_bridge $taskState $taskB @(-36,-17,72,34) @{science='mechanical fracture debris; never award melt evidence from this picture'}
}
foreach($taskName in @('gear','crank','brake_shoe')){
 for($taskI=0;$taskI -lt 4;$taskI++){
  # Metal is drawn AFTER translucent casing to remain clearly solid through every state.
  $taskB=(Ice $taskI 115 108)+'<g transform="translate(128 168) scale(.64) translate(-128 -168)">'+(Part $taskName)+'</g>'
  Asset ($taskName+'_thaw_'+$taskI) 'z1.thaw_sort' ($taskName+'_thaw') (@('solid','melting_early','melting_late','released')[$taskI]) $taskB @(-27,-13,54,26) @{science='water casing shrinks to puddle; identical solid metal geometry every frame';metal_geometry=(Part $taskName);exposure_seconds=4;action='restyle';observed_source='assets/zones/zone_1/frozen_mill/workshop/thaw_sort.png'}
 }
 Asset ($taskName+'_part') 'z1.thaw_sort' ($taskName+'_part') released ((Shadow 30)+(Part $taskName)) @(-18,-9,36,18) @{carry_fit_world=@(15,14);carry_socket='center of opaque bounds; adapter must fit uniformly as existing frozen_split_heat.gd';action='restyle';observed_source='assets/zones/zone_1/frozen_mill/workshop/thaw_sort.png'}
 foreach($taskState in @('empty','wrong','occupied')){
  $taskB=Tray empty ('<g transform="translate(128 181) scale(.58 .36) translate(-128 -168)">'+(Part $taskName '#314B56')+'</g>')
  if($taskState -eq 'occupied'){$taskB+='<g transform="translate(128 181) scale(.58 .36) translate(-128 -168)">'+(Part $taskName)+'</g>';$taskB+=Mark solved}
  if($taskState -eq 'wrong'){$taskB+=Mark wrong}
  Asset ($taskName+'_tray_'+$taskState) 'z1.thaw_sort' ($taskName+'_tray') $taskState $taskB @(-32,-13,64,26)
 }
}
foreach($taskState in @('closed','open')){
 $taskB=(Shadow 72)+(Box 74 208 9 5 92 'url(#metal)' '#899A9B' '#526D78')+(Box 184 208 9 5 92 'url(#metal)' '#899A9B' '#526D78')
 if($taskState -eq 'closed'){$taskB+=Path 'M80 135l98 8v50l-98-8z' 'url(#wood)';$taskB+=Line 'M87 143l82 43m-82-7 82-27' '#D0B182' 4}else{$taskB+=Mark solved}
 Asset ('maintenance_gate_'+$taskState) 'z1.thaw_sort' maintenance_gate $taskState $taskB @(-33,-7,66,14)
}
foreach($taskName in @('heavy','light')){foreach($taskState in @('idle','turning')){
 $taskSource='assets/zones/zone_1/frozen_mill/redesign/'+$taskName+'_winch.svg'
 $taskInner=(Get-Content -Raw (Join-Path $taskRoot $taskSource)) -replace '^<svg[^>]*>','' -replace '</svg>\s*$',''
 $taskB='<g transform="translate(58 68) scale(1.4)">'+$taskInner+'</g>'
 if($taskState -eq 'turning'){$taskB+=Line 'M164 121q20-10 27 8l-8-4m8 4 2-9' '#E6A34A' 3}
 Asset ($taskName+'_winch_'+$taskState) 'z1.freight_lift' ($taskName+'_winch') $taskState $taskB @(-27,-13,54,26) @{action='keep';observed_source=$taskSource;reuse='unchanged native body; registered wrapper feedback'}
}}
foreach($taskWeight in @(1,2,3)){
 $taskB=Shadow 28
 for($taskI=0;$taskI -lt $taskWeight;$taskI++){$taskB+=Box 128 (204-$taskI*16) (18+$taskWeight*3) (9+$taskWeight*2) 16 'url(#metal)' '#899A9B' '#526D78'}
 Asset ('weight_'+$taskWeight) 'z1.freight_lift' weights ('units_'+$taskWeight) $taskB @(-16,-8,32,16) @{units=$taskWeight}
}
for($taskI=0;$taskI -le 7;$taskI++){
 $taskB=(Shadow 45)+(Box 128 205 31 16 7 'url(#metal)' '#899A9B' '#526D78')+(Path 'M109 192v-76l37-16v77z' '#F3E8CB')
 for($taskTick=0;$taskTick -le 7;$taskTick++){$taskB+=Line ('M115 '+(181-$taskTick*8)+'l20-9') $(if($taskTick -eq 5){'#386D62'}else{'#9F9E8A'}) $(if($taskTick -eq 5){4}else{1.5})}
 $taskB+=Path ('M98 '+(186-$taskI*8)+'l13-5-1 11z') '#E6A34A'
 Asset ('load_gauge_'+$taskI) 'z1.freight_lift' load_gauge ('units_'+$taskI) $taskB @(-18,-9,36,18) @{units=$taskI;target_units=5;requires_runtime_count_label=$true}
}
foreach($taskState in @('locked','released')){
 $taskB=(Shadow 30)+(Box 128 203 24 12 34 'url(#metal)' '#899A9B' '#526D78')
 $taskB+=Path $(if($taskState -eq 'locked'){'M94 164l60-12 7 11-60 12z'}else{'M159 139l12-6 9 47-12 6z'}) 'url(#brass)'
 $taskB+=Mark $(if($taskState -eq 'released'){'solved'}else{''})
 Asset ('brake_housing_'+$taskState) 'z1.freight_lift' brake_housing $taskState $taskB @(-17,-9,34,18)
}
Asset brake_pin 'z1.freight_lift' brake_pin pickup ((Shadow 23)+(Path 'M96 167l49-13 7 13-49 13z' 'url(#brass)')+'<circle cx="151" cy="159" r="13" fill="none" stroke="#C99B56" stroke-width="6"/>') @(-15,-6,30,12) @{carry_fit_world=@(15,14);science='brake PIN distinct from curved brake SHOE'}
foreach($taskState in @('lowered','raised','secured')){
 $taskB=(Shadow 107)+(Box 49 210 9 5 137 'url(#metal)' '#899A9B' '#526D78')+(Box 207 210 9 5 137 'url(#metal)' '#899A9B' '#526D78')
 $taskB+=Line 'M49 74l158 0m-131 0v128m106-128v128' '#665D50' 4
 $taskY=if($taskState -eq 'lowered'){205}else{152}
 $taskB+=Box 128 $taskY 67 34 9 'url(#wood)' '#927357' '#685446'
 $taskB+=Line "M68 $($taskY-10)l60 28 60-28" '#DAB68A' 2
 if($taskState -eq 'secured'){$taskB+=Mark solved}
 Asset ('freight_lift_'+$taskState) 'z1.freight_lift' freight_lift $taskState $taskB @(-42,-23,84,46) @{large=$true;support_status='visual only; secured platform support must be granted by later mechanical adapter'}
}
# Tray, water routing and latched support library for L3-L6.
foreach($taskState in @('empty','liquid','freezing','solid','latched','melting','drained')){
 Asset ('cooling_tray_'+$taskState) 'z1.freezing_crossing' cooling_tray $taskState (Tray $taskState) @(-33,-14,66,28) @{science='empty/drained never manufactures water; confirmed solid + mechanical latch precedes traversal';support_status='no live support; use 003 support profile after integration'}
}
foreach($taskState in @('solid','melting','liquid')){Asset ('supply_'+$taskState) 'z1.freezing_crossing' supply $taskState (Ice (@('solid','melting','liquid').IndexOf($taskState)*1.5) 110 86) @(-28,-14,56,28)}
foreach($taskState in @('connected','isolated')){
 $taskB=(Shadow 43)+(Path 'M76 189l43-19 58 20v13l-58-21-43 19z' 'url(#brass)')
 if($taskState -eq 'isolated'){$taskB+=Path 'M115 169l17-7 12 31-18 7z' 'url(#metal)'}else{$taskB+=Line 'M86 190l28-12 42 13' '#E6A34A' 3}
 Asset ('heat_shutter_'+$taskState) 'z1.freezing_crossing' heat_shutter $taskState $taskB @(-26,-10,52,20)
}
foreach($taskState in @('blocked','liquid','frozen','isolated')){
 $taskB=(Shadow 75)+(Box 128 205 70 35 12 'url(#metal)' '#899A9B' '#526D78')
 $taskB+=Path 'M67 181l34-16 88 32-35 17z' 'url(#water)';$taskB+=Line 'M93 180l32 11m15 6 23 8' '#BFE7E7'
 if($taskState -eq 'blocked'){$taskB+=Ice 0 80 54}
 if($taskState -eq 'frozen'){$taskB+=Path 'M67 181l34-16 88 32-35 17z' 'url(#ice)';$taskB+=Line 'M82 181l20-10 70 27' '#F6FFFC' 3}
 if($taskState -eq 'isolated'){$taskB+=Path 'M99 155l27-13v48l-27 13z' 'url(#metal)'}
 Asset ('canal_'+$taskState) 'z1.two_state_canal' canal $taskState $taskB @(-35,-17,70,34) @{science='only liquid channel has flow streaks; frozen side branch must not freeze main wheel branch'}
}
foreach($taskState in @('stopped','turn_a','turn_b')){
 $taskB=(Shadow 57)+(Box 128 207 42 21 10 'url(#wood)' '#927357' '#685446')
 $taskB+='<g transform="translate(128 148) rotate('+$(if($taskState -eq 'turn_b'){22.5}else{0})+')"><ellipse rx="44" ry="49" fill="none" stroke="#7D604D" stroke-width="12"/>'
 for($taskI=0;$taskI -lt 8;$taskI++){$taskB+='<path d="M0-44V44m-8-43h16" fill="none" stroke="#B99A71" stroke-width="5" transform="rotate('+($taskI*45)+')"/>'}
 $taskB+='</g><circle cx="128" cy="148" r="9" fill="url(#brass)"/>'
 Asset ('canal_wheel_'+$taskState) 'z1.two_state_canal' canal_wheel $taskState $taskB @(-28,-15,56,30)
}
foreach($taskState in @('frozen_wrong','thawed','repositioned','latched')){
 $taskB=(Shadow 57)+(Box 128 204 49 25 15 'url(#wood)' '#927357' '#685446')
 if($taskState -eq 'frozen_wrong'){$taskB+=Ice 0 75 42}
 if($taskState -eq 'thawed'){$taskB+=Pool 43}
 if($taskState -in @('repositioned','latched')){$taskB+=Path 'M105 169l13-6v28l-13 6zm32-6 13 6v28l-13-6z' 'url(#metal)'}
 if($taskState -eq 'latched'){$taskB+=Mark solved;$taskB+=Path 'M104 181l46 1v8l-46-1z' 'url(#brass)'}
 Asset ('bridge_lock_'+$taskState) 'z1.two_state_canal' bridge_lock $taskState $taskB @(-28,-14,56,28)
}
foreach($taskState in @('frozen','thawed','open')){
 $taskB=(Shadow 45)+(Box 128 202 37 18 43 'url(#wood)' '#927357' '#685446')
 $taskB+=Path 'M119 175l13-5 8 13-13 5z' 'url(#brass)'
 if($taskState -eq 'frozen'){$taskB+=Ice 0 75 64}
 if($taskState -eq 'thawed'){$taskB+=Pool 48}
 if($taskState -eq 'open'){$taskB+=Path 'M91 140l74-15v-21l-74 15z' 'url(#wood)';$taskB+=Mark solved}
 Asset ('storage_latch_'+$taskState) 'z1.snowbound_workshop' storage_latch $taskState $taskB @(-25,-12,50,24)
}
foreach($taskState in @('empty','liquid','solid','fitted','melting','released','drained')){
 $taskInsert=if($taskState -in @('fitted','melting','released','drained')){'<g transform="translate(128 165) scale(.8) translate(-128 -177)">'+(Plank plank)+'</g>'}else{''}
 $taskB=Tray $taskState $taskInsert
 # Permanent wooden frame, distinct from temporary water-ice jig.
 $taskB+=Path 'M66 181v26l18 9v-26zm105 7v26l18-9v-26z' 'url(#wood)'
 if($taskState -eq 'released'){$taskB+=Pool 45}
 if($taskState -eq 'drained'){$taskB+=Mark solved}
 Asset ('workshop_jig_'+$taskState) 'z1.snowbound_workshop' workshop_jig $taskState $taskB @(-34,-16,68,32) @{science='wood supports sample permanently; water-ice jig is temporary; sample remains local';workpiece_geometry=$taskInsert;workpiece_present=($taskState -in @('fitted','melting','released','drained'))}
}
Asset practice_plank 'z1.snowbound_workshop' practice_plank pickup ((Shadow 41)+(Plank plank)) @(-27,-12,54,24) @{carry_fit_world=@(15,14);local_only=$true}
Asset sample_frame 'z1.snowbound_workshop' sample_frame empty ((Shadow 46)+(Path 'M77 169l66-22 41 21-65 25z' 'url(#wood)')+(Path 'M94 168l48-15 26 14-48 17z' '#DDE8DF')) @(-28,-14,56,28)
foreach($taskState in @('closed','open')){Asset ('drain_'+$taskState) 'z1.snowbound_workshop' drain $taskState ((Tray empty)+(Path 'M113 177l19-8 20 8-19 8z' '#344A52')+$(if($taskState -eq 'closed'){Path 'M113 177l19-8 20 8-19 8z' 'url(#brass)'}else{Line 'M119 176l13-4m-9 8 13-4' '#779DA8'})) @(-30,-13,60,26)}
# Local dock recipe and matching slots. Three bundle IDs remain distinct.
foreach($taskName in @('plank1','plank2','plank3','rope','sailcloth','rudder')){
 $taskType=if($taskName -like 'plank*'){'plank'}else{$taskName}
 $taskB=(Shadow 43)+(Plank $taskType)
 if($taskType -eq 'plank'){$taskB+='<g transform="translate(0 -10)">'+(Plank plank)+'</g>'}
 Asset ('boat_part_'+$taskName) 'z1.boat.recipe' ('boat_part_'+$taskName) pickup $taskB @(-27,-12,54,24) @{recipe_id=$taskName;carry_fit_world=@(15,14)}
 foreach($taskState in @('empty','wrong','committed')){
  $taskB=Tray empty ('<g transform="translate(128 181) scale(.63 .4) translate(-128 -177)" opacity=".5">'+(Plank $taskType)+'</g>')
  if($taskState -eq 'committed'){$taskB+='<g transform="translate(128 181) scale(.63 .4) translate(-128 -177)">'+(Plank $taskType)+'</g>';$taskB+=Mark solved}
  if($taskState -eq 'wrong'){$taskB+=Mark wrong}
  Asset ('recipe_'+$taskName+'_'+$taskState) 'z1.boat.recipe' ('recipe_'+$taskName) $taskState $taskB @(-33,-14,66,28) @{recipe_id=$taskName;remaining_quantity_label='runtime-owned; three plank bundles total'}
 }
 if($taskType -eq 'plank'){
  $taskBundle=(Plank plank)+'<g transform="translate(0 -10)">'+(Plank plank)+'</g>'
  foreach($taskI in @(0,1,2,3)){Asset ($taskName+'_shell_'+$taskI) 'z1.boat.recipe' ($taskName+'_shell') (@('solid','melting_early','melting_late','released')[$taskI]) ((Ice $taskI 123 87)+$taskBundle) @(-31,-16,62,32) @{contents_geometry=$taskBundle;science='same two-plank bundle through all casing states; melting releases wood, never creates extra planks'}}
 }
}
foreach($taskState in @('empty','liquid','solid','hull','rigged','melting','released','test','launched')){
 $taskB=if($taskState -in @('test','launched')){(Path 'M13 184l109-46 123 47-111 51z' 'url(#water)')+(Line 'M25 188l23 9m140 11 33-14' '#B5DEDF' 3)}else{(Shadow 113)+(Box 128 206 107 47 10 'url(#wood)' '#927357' '#685446')}
 if($taskState -in @('liquid','solid','hull','rigged','melting')){$taskB+='<g transform="translate(128 202) scale(1.4 .85) translate(-128 -185)">'+(Tray $(if($taskState -eq 'liquid'){'liquid'}elseif($taskState -eq 'melting'){'melting'}else{'solid'}))+'</g>'}
 if($taskState -in @('hull','rigged','melting','released','test','launched')){
  $taskB+=Path 'M29 162q45-34 147-15l51 31q-17 44-104 44-64-8-94-60z' 'url(#wood)'
  $taskB+=Path 'M37 163q59-22 136-9l44 25q-41 26-95 24-52-6-85-40z' '#C29A6D'
  $taskB+=Path 'M54 165q65-12 115-3l25 15q-67 23-110-1z' '#64554B'
  $taskB+=Line 'M42 176q53 48 165 13m-146-3q59 38 132 16' '#D2AD7E' 2
 }
 if($taskState -in @('rigged','melting','released','test','launched')){
  $taskB+=Path 'M126 184v-139l8-4v145z' 'url(#wood)'
  $taskB+=Path 'M137 54l65 89-65-11z' '#F3E8CB';$taskB+=Path 'M122 79l-52 64 52-13z' '#C8D2C4'
  $taskB+=Line 'M132 48l77 101-77 37m-8-107-64 72 62 36' '#DED0A6' 2
  $taskB+=Path 'M214 181l14 5 2 22-12-1z' 'url(#wood)'
 }
 if($taskState -in @('test','launched')){$taskB+=Line 'M19 226q67 16 119 8m8-7 81-11' '#B9E1DF' 3;$taskB+=Mark solved}
 if($taskState -eq 'test'){$taskB+=Line 'M43 179q-12 12-28 6' '#D8C195' 3}
 if($taskState -eq 'launched'){$taskB+=Line 'M10 210l-6-3m15 17-9 1m226-13 9-3' '#C7E8E5' 3}
 Asset ('boat_assembly_'+$taskState) 'z1.boat.recipe' boat_assembly $taskState $taskB @(-58,-28,116,56) @{large=$true;science='ice jig releases into liquid; permanent wooden hull floats, ice is neither hull nor propulsion';support_status='art only; later craft transaction and launch test own permission'}
}
foreach($taskState in @('idle','boarding')){
 $taskB=(Shadow 110)+(Box 128 205 106 45 13 'url(#wood)' '#927357' '#685446')
 foreach($taskX in @(52,90,128,166,204)){$taskB+=Line "M$taskX $([int](151+[Math]::Abs($taskX-128)*.4))l-26 47" '#6D5849' 2}
 $taskB+=Box 40 216 8 4 44 'url(#metal)' '#899A9B' '#526D78';$taskB+=Box 216 216 8 4 44 'url(#metal)' '#899A9B' '#526D78'
 if($taskState -eq 'boarding'){$taskB+=Line 'M91 203l31-12m-7-4 14 1-5 12' '#F3E8CB' 4}
 Asset ('dock_'+$taskState) 'z1.boat.recipe' dock $taskState $taskB @(-55,-27,110,54) @{large=$true}
}
foreach($taskState in @('frozen','thawed','open')){Asset ('rudder_chest_'+$taskState) 'z1.boat.recipe' rudder_chest $taskState ((Shadow 39)+(Box 128 202 37 18 38 'url(#wood)' '#927357' '#685446')+$(if($taskState -eq 'frozen'){Ice 0 90 66}elseif($taskState -eq 'open'){(Plank rudder)+(Mark solved)}else{Pool 45})) @(-25,-12,50,24)}
# Optional Ice Mold Match: triangle/circle/square remain readable without hue.
foreach($taskShape in @('triangle','circle','square')){
 $taskD=switch($taskShape){triangle {'M128 155l27 37h-54z'};circle {'M128 156a21 18 0 1 1-1 0z'};square {'M105 158h46v36h-46z'}}
 foreach($taskState in @('empty','liquid','freezing','solid','committed','wrong')){
  $taskB=Tray empty (Path $taskD $(if($taskState -eq 'empty'){'#304F5B'}elseif($taskState -in @('liquid','freezing')){'url(#water)'}else{'url(#ice)'}))
  if($taskState -eq 'freezing'){$taskB+=Path 'M116 169l12-9 13 13-17 5z' 'url(#ice)'}
  if($taskState -eq 'committed'){$taskB+=Mark solved}
  if($taskState -eq 'wrong'){$taskB+=Mark wrong}
  Asset ('mold_'+$taskShape+'_'+$taskState) 'z1.ice_mold_match' ('mold_'+$taskShape) $taskState $taskB @(-33,-14,66,28) @{science='same water fills shaped mold; shape matching alone grants no mastery/progression';shape=$taskShape}
 }
 Asset ('mold_'+$taskShape+'_sample') 'z1.ice_mold_match' ('sample_'+$taskShape) solid ((Shadow 26)+(Path $taskD 'url(#ice)')) @(-14,-10,28,20) @{shape=$taskShape;carry_fit_world=@(15,14)}
 Asset ('observation_card_'+$taskShape) 'z1.ice_mold_match' ('observation_'+$taskShape) idle ((Path 'M88 136l65-9 21 72-66 9z' '#F3E8CB')+(Path $taskD '#446675')) @(0,0,0,0) @{shape=$taskShape;label='runtime localized shape/state observation; separate Guides panels in R3 010'}
}
Asset fuel_bundle 'z1.heater.fan.mirror' fuel_bundle pickup ((Shadow 37)+(Plank plank)+(Path 'M114 155l15-5 18 31-15 6z' 'url(#brass)')) @(-23,-10,46,20) @{carry_fit_world=@(15,14)}
foreach($taskState in @('main','side')){
 $taskB=(Shadow 64)+(Path 'M64 180l32-15 33 10 40-18 26 13-40 20 36 13-28 14-37-16-34 14-27-14 35-15z' 'url(#water)')
 $taskB+=Path $(if($taskState -eq 'main'){'M120 173l13-6 29 33-13 7z'}else{'M108 194l46-20 9 9-46 20z'}) 'url(#metal)'
 $taskB+=Line $(if($taskState -eq 'main'){'M74 179l40 14m21 8 30 11'}else{'M75 180l40 12 66-29'}) '#CBEDEC' 3
 Asset ('canal_diverter_'+$taskState) 'z1.two_state_canal' canal_diverter $taskState $taskB @(-34,-16,68,32)
}
$taskB=(Shadow 76)+(Box 128 198 66 29 11 'url(#wood)' '#927357' '#685446')
foreach($taskX in @(75,175)){$taskB+=Path "M$taskX 190v44l12 5v-44z" 'url(#wood)'}
$taskB+=Path 'M76 142v-54l112 11v54z' 'url(#wood)';$taskB+=Line 'M96 106v25m22-22-8 25m36-22-5 23' '#C1D6D5' 5
$taskB+=Box 165 190 14 7 18 'url(#metal)' '#899A9B' '#526D78';$taskB+=Path 'M83 167l51-11 20 18-50 12z' '#D0DFDC'
Asset workshop_bench 'z1.snowbound_workshop' workshop_bench idle $taskB @(-37,-18,74,36)
Asset boat_blueprint 'z1.snowbound_workshop' boat_blueprint unlocked ((Shadow 32)+(Path 'M89 146l62-12 20 64-62 11z' '#526F82')+(Line 'M107 180l29-7 20 13-29 8zm20 6v-31l18 22-18-3' '#E4F0DA' 2)) @(0,0,0,0)
for($taskI=0;$taskI -le 3;$taskI++){
 $taskB=(Shadow 48)+(Box 128 204 41 21 8 'url(#wood)' '#927357' '#685446')+(Path 'M90 191v-67l76 8v68z' '#F3E8CB')
 for($taskP=0;$taskP -lt 3;$taskP++){
  $taskX=103+$taskP*23;$taskY=153-$taskP*9
  $taskB+=Path "M$($taskX-7) $taskY q2-18 7-18q5 0 7 18z" $(if($taskP -lt $taskI){'#527D6A'}else{'#C99B56'})
  if($taskP -lt $taskI){$taskB+=Line "M$($taskX-5) 172l4 5 7-9" '#386D62' 3}
 }
 Asset ('bell_sequence_'+$taskI) 'z1.bells' bell_sequence ('steps_'+$taskI) $taskB @(-24,-12,48,24) @{silent_cue='descending size/height low-mid-high; localized runtime labels required'}
}
$taskCatalog=[ordered]@{schema_version=1;kit_id='phase-quest-r3-zone1-v1';status='R3 004 implemented, visual/user/Android acceptance pending';standard='docs/art/r3-prompt002/production-contract.json';source_builder='tools/art/zone1_v1/build_kit.ps1';coordinate_contract='2 source px/world unit, scale .5; common ground pivot 128,208 (large 192,264); camera 1.55';footprints='Proposed ground placement envelopes. Do not attach as live support/collision automatically.';entries=$taskRows}
$taskCatalog|ConvertTo-Json -Depth 12|Set-Content (Join-Path $taskOut kit_catalog.json) -Encoding utf8
Write-Output ('R3 004 authored '+$taskRows.Count+' SVG assets')
