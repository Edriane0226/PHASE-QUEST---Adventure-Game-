$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$taskOut=Join-Path $taskRoot 'assets/zones/zone_3/world_v1'
New-Item -ItemType Directory -Force (Join-Path $taskOut svg)|Out-Null
$taskRows=[Collections.Generic.List[object]]::new()
$taskDefs=@'
<defs>
<linearGradient id="leaf" x2=".8" y2="1"><stop stop-color="#ADC985"/><stop offset="1" stop-color="#69974F"/></linearGradient>
<linearGradient id="wood" x2=".8" y2="1"><stop stop-color="#BE9667"/><stop offset="1" stop-color="#785B47"/></linearGradient>
<linearGradient id="metal" x2=".85" y2="1"><stop stop-color="#D9DFD9"/><stop offset=".45" stop-color="#8A969B"/><stop offset="1" stop-color="#5C6B75"/></linearGradient>
<linearGradient id="brass" x2=".7" y2="1"><stop stop-color="#F3E0AA"/><stop offset=".5" stop-color="#BFA77F"/><stop offset="1" stop-color="#997449"/></linearGradient>
<linearGradient id="ice" x2=".7" y2="1"><stop stop-color="#EDFDFC"/><stop offset="1" stop-color="#80BCCB"/></linearGradient>
<linearGradient id="water" x2=".4" y2="1"><stop stop-color="#82BEC0"/><stop offset="1" stop-color="#528D9B"/></linearGradient>
<linearGradient id="glass" x2=".8" y2="1"><stop stop-color="#D8EBE0" stop-opacity=".7"/><stop offset="1" stop-color="#8DB6B4" stop-opacity=".24"/></linearGradient>
<linearGradient id="pot" x2=".8" y2="1"><stop stop-color="#D6A37A"/><stop offset="1" stop-color="#A36B50"/></linearGradient>
<linearGradient id="warm" x2="0" y2="1"><stop stop-color="#FFF2B6"/><stop offset="1" stop-color="#D49551"/></linearGradient>
</defs>
'@
function Path([string]$D,[string]$Fill,[string]$Extra=''){return '<path d="'+$D+'" fill="'+$Fill+'" '+$Extra+'/>'}
function Line([string]$D,[string]$Color='#F3E8CB',[double]$Width=2){return Path $D none ('stroke="'+$Color+'" stroke-width="'+$Width+'"')}
function Shadow([int]$Rx=55){return '<ellipse cx="138" cy="212" rx="'+$Rx+'" ry="13" fill="#3D5662" opacity=".18" stroke="none"/>'}
function Mark([string]$State){switch($State){
 solved {return Line 'M199 165l8 8 17-21' '#416D50' 5}
 wrong {return Line 'M200 151l17 17m0-17-17 17' '#AD6650' 5}
 selected {return Line 'M43 212l-10-8 10-8m170 0 10 8-10 8' '#D9A453' 4}
 default {return ''}
}}
function Box([int]$X,[int]$Y,[int]$W,[int]$D,[int]$H,[string]$Top='url(#wood)',[string]$Left='#A17D57',[string]$Right='#785B47'){
 $l=$X-$W;$r=$X+$W;$b=$Y+$D;$z=$Y-$H;$q=$b-$H
 return (Path "M$l $z L$X $q L$X $b L$l $Y Z" $Left)+(Path "M$X $q L$r $z L$r $Y L$X $b Z" $Right)+(Path "M$X $($z-$D) L$r $z L$X $q L$l $z Z" $Top)+(Line "M$l $z L$X $($z-$D) L$r $z" '#E1E9B9' 1.8)
}
function Asset([string]$Id,[string]$Family,[string]$Group,[string]$State,[string]$Body,[double[]]$Foot=@(-26,-13,52,26),[hashtable]$Extra=@{}){
 $taskSize=@(256,256);$taskPivot=@(128,208)
 if($Extra.large){$taskSize=@(384,320);$taskPivot=@(192,264);$Body='<g transform="translate(64 56)">'+$Body+'</g>'}
 if($Extra.wide){$taskSize=@(512,384);$taskPivot=@(256,300);$Body='<g transform="translate(128 92)">'+$Body+'</g>'}
 $taskFile=Join-Path $taskOut ('svg/'+$Id+'.svg')
 $taskSvg='<svg xmlns="http://www.w3.org/2000/svg" width="'+$taskSize[0]+'" height="'+$taskSize[1]+'" viewBox="0 0 '+$taskSize[0]+' '+$taskSize[1]+'">'+$taskDefs+'<g stroke="#394D59" stroke-width="2" stroke-linejoin="round" stroke-linecap="round">'+$Body+'</g></svg>'
 [IO.File]::WriteAllText($taskFile,$taskSvg,[Text.UTF8Encoding]::new($false))
 $taskRow=[ordered]@{id=$Id;family=$Family;group=$Group;state=$State;path=('res://assets/zones/zone_3/world_v1/svg/'+$Id+'.svg');source_size=$taskSize;pivot_px=$taskPivot;world_scale=.5;sorting='ground pivot; caller-owned elevation and y sorting';footprint_world=$Foot;collision_status='proposed placement envelope; visual only, no collision/support';owner='R3 006';consumer='isolated review now; planned R3 018/038-044/045 world/puzzle adapters';dependencies=@('R3 002 measured production contract','R3 003 lab terrain');action='new';source_format='original editable native SVG';license='Original project-authored geometry; no reference extraction';sha256=(Get-FileHash $taskFile -Algorithm SHA256).Hash}
 foreach($taskKey in $Extra.Keys){$taskRow[$taskKey]=$Extra[$taskKey]}
 $taskRows.Add($taskRow)
}
function Droplet([int]$X,[int]$Y,[int]$S=5){
 $top=$Y-$S*2;$bottom=$Y+$S
 return (Path "M$X $top C$($X-$S) $Y $($X-$S) $bottom $X $bottom C$($X+$S) $bottom $($X+$S) $Y $X $top Z" '#528D9B' 'stroke="#375E6A" stroke-width="1.5"')
}
function Pipe([string]$D,[bool]$Active=$false){return (Line $D '#536E69' 12)+(Line $D '#A9BCC1' 8)+$(if($Active){Line $D '#D9E7E4' 2}else{''})}
function GasModel([int]$Y=100){return '<g id="gas_model" fill="none" stroke="#8BA4A0" stroke-dasharray="3 4"><path d="M107 '+$Y+'v-23m21 23v-30m21 30v-23"/></g>'}
function Tray([int]$Level=3,[bool]$Active=$false){
 $b=(Shadow 60)+(Box 128 204 64 27 12 'url(#metal)' '#8A969B' '#6F827A')+(Path 'M76 182l51-22 52 23-52 23z' '#3E5B58')
 if($Level -gt 0){$inset=(3-$Level)*5;$b+=Path "M$(80+$inset) 182l$(47-$inset) $(-19+$inset*.4)l$(48-$inset) $(20-$inset*.4)l$(-48+$inset) $(19-$inset*.4)z" 'url(#water)';$b+=Line 'M103 182l17-7' '#C5E3DE' 2}
 if($Active){$b+='<g id="surface_markers">'+(Line 'M108 168v-15l-3 5m3-5 3 5m18 6v-18l-3 5m3-5 3 5m17 17v-13l-3 4m3-4 3 4' '#9DAD9A' 2)+'</g>'}
 return $b
}
function Belt([string]$State='dry'){
 $b=Path 'M90 148q37-13 76 0l2 34q-34 23-77 7zm12 8v23q27 8 52-2l-1-21q-27-6-51 0z' $(if($State -eq 'wet'){'#648F87'}else{'#B99C6C'}) 'fill-rule="evenodd"'
 $b+=Line 'M94 151q30-9 66-1m-63 34q28 7 61-6' $(if($State -eq 'wet'){'#A8CEC3'}else{'#E8D2A4'}) 2
 if($State -eq 'wet'){$b+='<g id="surface_moisture">'+(Droplet 105 164 3)+(Droplet 143 176 3)+'</g>'}
 return $b
}
function Boiler([string]$State){
 $hot=$State -in @('warm','boil_a','boil_b')
 $b=(Shadow 57)+(Box 128 205 49 24 11 'url(#metal)' '#8A969B' '#6F827A')
 $b+=Path 'M83 95v89q45 29 90 0V95z' 'url(#glass)'
 if($State -ne 'empty'){
  $b+='<g id="vessel_liquid">'+(Path 'M89 126q39 14 78 0v53q-39 23-78 0z' 'url(#water)')+(Line 'M93 128q35 11 70 0' '#D5EAE0' 2)+'</g>'
 }
 if($State -in @('boil_a','boil_b')){
  $b+='<g id="bulk_bubbles" fill="none" stroke="#D7F0DE" stroke-width="2">'
  foreach($point in @(@(101,172),@(128,166),@(153,174),@(112,150),@(146,147),@(128,135))){$dy=if($State -eq 'boil_b'){4}else{0};$b+='<circle cx="'+$point[0]+'" cy="'+($point[1]-$dy)+'" r="4"/>'}
  $b+='</g>'
 }
 $b+='<ellipse cx="128" cy="95" rx="45" ry="16" fill="url(#metal)"/>'
 if($State -eq 'cover_open'){$b+=Path 'M88 77l66-14 18 14-66 15z' 'url(#metal)'}else{$b+=Path 'M111 84v-9l35-1v10z' 'url(#brass)'}
 $b+=Pipe 'M170 103h21v-29'
 # Glass inspection face behind permanent guard rails, all hot states contained.
 $b+=Line 'M83 96v89m90-89v89m-68-71v67m46-67v67' '#6E8175' 3
 $b+=Path 'M101 197l28 12 28-12v11l-28 11-28-11z' $(if($hot){'url(#warm)'}else{'#6F7160'})
 $b+=Path 'M79 185l49 25 49-25v6l-49 25-49-25z' 'url(#brass)'
 return $b
}
function Turbine([string]$State='idle'){
 $b=(Shadow 47)+(Box 128 204 36 18 10 'url(#metal)' '#8A969B' '#6F827A')
 $b+='<circle cx="128" cy="151" r="39" fill="url(#brass)"/><circle cx="128" cy="151" r="32" fill="#638179"/>'
 $angle=if($State -eq 'turn_b'){30}else{0}
 $b+='<g transform="rotate('+$angle+' 128 151)">'
 foreach($a in @(0,60,120,180,240,300)){$b+='<path d="M128 151l-8-28 17 2z" fill="url(#metal)" transform="rotate('+$a+' 128 151)"/>'}
 $b+='</g><circle cx="128" cy="151" r="8" fill="url(#brass)"/>'
 $b+=Pipe 'M90 136H77v-20';$b+=Pipe 'M167 160h15v25'
 $b+=Line 'M101 125l53 53m-53 0 53-53' '#CBD1B6' 2
 if($State -in @('turn_a','turn_b')){$b+='<g id="wheel_motion">'+(Line 'M85 121q-13 26 0 52l-6-3m6 3 2-8' '#AC8C52' 3)+'</g>'}
 if($State -eq 'latched'){$b+=Mark solved}
 return $b
}
function Pane([string]$State='warm'){
 $b=(Shadow 55)+(Box 128 206 44 22 10 'url(#metal)' '#8A969B' '#6F827A')
 $b+=Path 'M84 185V91l85 26v92z' 'url(#glass)' 'stroke-width="4"'
 $b+=Line 'M91 100l24 8m-24 2 38 12' '#E9F4DF' 2
 $b+=Path 'M179 123h12v58h-12z' '#F3E8CB'
 $b+=Line $(if($State -eq 'warm'){'M185 173v-40'}else{'M185 173v-15'}) $(if($State -eq 'warm'){'#D49551'}else{'#528D9B'}) 4
 if($State -in @('droplets','collecting')){
  $b+='<g id="liquid_droplets">'+(Droplet 105 135 4)+(Droplet 139 151 5)+(Droplet 119 173 4)+(Droplet 155 183 4)+'</g>'
 }
 $b+=Pipe 'M84 189l85 26h13v-7'
 if($State -eq 'collecting'){$b+='<g id="falling_liquid">'+(Droplet 183 224 3)+'</g>'}
 return $b
}
function Pack([string]$State){
 $b=(Shadow 36)+(Box 128 204 30 15 8 'url(#metal)' '#8A969B' '#6F827A')
 if($State -ne 'empty'){$b+=Box 128 193 25 13 35 $(if($State -eq 'solid'){'url(#ice)'}else{'url(#water)'}) '#81B1BA' '#528D9B'}
 $b+=Path 'M101 149l8-4v53l-8 4zm47-4 8 4v53l-8-4z' 'url(#metal)'
 if($State -eq 'freezing'){$b+=Path 'M110 163l18-9 19 9-19 10z' 'url(#ice)'}
 return $b
}

