$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$taskOut=Join-Path $taskRoot 'assets/zones/zone_2/world_v1'
New-Item -ItemType Directory -Force (Join-Path $taskOut svg)|Out-Null
$taskRows=[Collections.Generic.List[object]]::new()
$taskDefs=@'
<defs>
<linearGradient id="leaf" x2=".8" y2="1"><stop stop-color="#ADC985"/><stop offset="1" stop-color="#69974F"/></linearGradient>
<linearGradient id="wood" x2=".8" y2="1"><stop stop-color="#BE9667"/><stop offset="1" stop-color="#785B47"/></linearGradient>
<linearGradient id="metal" x2=".85" y2="1"><stop stop-color="#D6E2D8"/><stop offset=".45" stop-color="#9BA3A0"/><stop offset="1" stop-color="#526C70"/></linearGradient>
<linearGradient id="brass" x2=".7" y2="1"><stop stop-color="#F3E0AA"/><stop offset=".5" stop-color="#D9B56E"/><stop offset="1" stop-color="#997449"/></linearGradient>
<linearGradient id="ice" x2=".7" y2="1"><stop stop-color="#EDFDFC"/><stop offset="1" stop-color="#80BCCB"/></linearGradient>
<linearGradient id="water" x2=".4" y2="1"><stop stop-color="#82BEC0"/><stop offset="1" stop-color="#528D9B"/></linearGradient>
<linearGradient id="glass" x2=".8" y2="1"><stop stop-color="#D8EBE0" stop-opacity=".7"/><stop offset="1" stop-color="#8DB6B4" stop-opacity=".24"/></linearGradient>
<linearGradient id="pot" x2=".8" y2="1"><stop stop-color="#D6A37A"/><stop offset="1" stop-color="#A36B50"/></linearGradient>
<linearGradient id="warm" x2="0" y2="1"><stop stop-color="#FFF2B6"/><stop offset="1" stop-color="#D49551"/></linearGradient>
</defs>
'@
function Path([string]$D,[string]$Fill,[string]$Extra=''){return '<path d="'+$D+'" fill="'+$Fill+'" '+$Extra+'/>'}
function Line([string]$D,[string]$Color='#F3E8CB',[double]$Width=2){return Path $D none ('stroke="'+$Color+'" stroke-width="'+$Width+'"')}
function Shadow([int]$Rx=55){return '<ellipse cx="138" cy="212" rx="'+$Rx+'" ry="13" fill="#385942" opacity=".18" stroke="none"/>'}
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
 $taskSvg='<svg xmlns="http://www.w3.org/2000/svg" width="'+$taskSize[0]+'" height="'+$taskSize[1]+'" viewBox="0 0 '+$taskSize[0]+' '+$taskSize[1]+'">'+$taskDefs+'<g stroke="#3F514A" stroke-width="2" stroke-linejoin="round" stroke-linecap="round">'+$Body+'</g></svg>'
 [IO.File]::WriteAllText($taskFile,$taskSvg,[Text.UTF8Encoding]::new($false))
 $taskRow=[ordered]@{id=$Id;family=$Family;group=$Group;state=$State;path=('res://assets/zones/zone_2/world_v1/svg/'+$Id+'.svg');source_size=$taskSize;pivot_px=$taskPivot;world_scale=.5;sorting='ground pivot; caller-owned elevation and y sorting';footprint_world=$Foot;collision_status='proposed placement envelope; visual only, no collision/support';owner='R3 005';consumer='isolated review now; planned R3 017/031-037/045 world/puzzle adapters';dependencies=@('R3 002 measured production contract','R3 003 grass terrain');action='new';source_format='original editable native SVG';license='Original project-authored geometry; no reference extraction';sha256=(Get-FileHash $taskFile -Algorithm SHA256).Hash}
 foreach($taskKey in $Extra.Keys){$taskRow[$taskKey]=$Extra[$taskKey]}
 $taskRows.Add($taskRow)
}
function Droplet([int]$X,[int]$Y,[int]$S=5){
 $top=$Y-$S*2;$bottom=$Y+$S
 return (Path "M$X $top C$($X-$S) $Y $($X-$S) $bottom $X $bottom C$($X+$S) $bottom $($X+$S) $Y $X $top Z" '#528D9B' 'stroke="#375E6A" stroke-width="1.5"')
}
function Pipe([string]$D,[bool]$Active=$false){return (Line $D '#536E69' 12)+(Line $D '#B7C6A5' 8)+$(if($Active){Line $D '#D8E8BF' 2}else{''})}
function GasModel([int]$Y=100){return '<g id="gas_model" fill="none" stroke="#8BA4A0" stroke-dasharray="3 4"><path d="M107 '+$Y+'v-23m21 23v-30m21 30v-23"/></g>'}
function Tray([int]$Level=3,[bool]$Active=$false){
 $b=(Shadow 60)+(Box 128 204 64 27 12 'url(#metal)' '#9BA3A0' '#6F827A')+(Path 'M76 182l51-22 52 23-52 23z' '#3E5B58')
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
 $b=(Shadow 57)+(Box 128 205 49 24 11 'url(#metal)' '#9BA3A0' '#6F827A')
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
 $b=(Shadow 47)+(Box 128 204 36 18 10 'url(#metal)' '#9BA3A0' '#6F827A')
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
 $b=(Shadow 55)+(Box 128 206 44 22 10 'url(#metal)' '#9BA3A0' '#6F827A')
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
 $b=(Shadow 36)+(Box 128 204 30 15 8 'url(#metal)' '#9BA3A0' '#6F827A')
 if($State -ne 'empty'){$b+=Box 128 193 25 13 35 $(if($State -eq 'solid'){'url(#ice)'}else{'url(#water)'}) '#81B1BA' '#528D9B'}
 $b+=Path 'M101 149l8-4v53l-8 4zm47-4 8 4v53l-8-4z' 'url(#metal)'
 if($State -eq 'freezing'){$b+=Path 'M110 163l18-9 19 9-19 10z' 'url(#ice)'}
 return $b
}
# Sparse original sunny dressing: aligned 2:1 block faces, upper-left light.
foreach($state in @('young','orchard','ripe')){
 $b=(Shadow 50)+(Path 'M127 202l30-7 29 11 16 1 27 17-25 13-30-1-25-15z' '#385942' 'opacity=".16" stroke="none"')+(Box 128 205 10 5 62 'url(#wood)' '#9A7752' '#735A45')
 $b+=Box 109 148 34 17 36 'url(#leaf)' '#7DA356' '#5B8749';$b+=Box 148 143 32 16 39 'url(#leaf)' '#7DA356' '#5B8749';$b+=Box 128 110 32 16 32 'url(#leaf)' '#7DA356' '#5B8749'
 if($state -eq 'ripe'){foreach($point in @(@(91,133),@(151,130),@(132,104))){$b+='<circle cx="'+$point[0]+'" cy="'+$point[1]+'" r="5" fill="#D8B26B"/>'}}
 if($state -eq 'young'){$b='<g transform="translate(128 208) scale(.8) translate(-128 -208)">'+$b+'</g>'}
 Asset ('sun_tree_'+$state) 'z2.vegetation' ('tree_'+$state) idle $b @(-14,-8,28,16)
}
Asset sun_rocks 'z2.vegetation' rocks idle ((Shadow 42)+(Box 112 202 24 12 28 'url(#metal)' '#9BA3A0' '#71847A')+(Box 148 206 19 10 18 'url(#metal)' '#9BA3A0' '#71847A')) @(-23,-12,46,24)
Asset reeds 'z2.vegetation' reeds idle ((Path 'M108 208l-4-26 14 18 5-38 7 37 13-21-4 32z' '#719750')+(Line 'M123 173v29' '#ADC985')) @(0,0,0,0)
Asset flowers 'z2.vegetation' flowers idle ((Line 'M119 210v-28m14 27v-39' '#69974F' 3)+'<path d="M119 176l7 7-7 7-7-7zm14-13 7 7-7 7-7-7z" fill="#E5D58A" stroke="#A6965F"/>') @(0,0,0,0)
Asset orchard_branch 'z2.vegetation' orchard_branch idle ((Shadow 45)+(Path 'M81 184l79-24 17 17-77 28z' 'url(#wood)')+(Line 'M108 178l-5-17m32 7 8-14' '#785B47' 5)+(Line 'M91 186l68-20' '#E3C695')) @(-26,-10,52,20)
foreach($state in @('clear','humid','vented')){
 $b=(Shadow 110)+(Box 128 206 100 44 13 'url(#pot)' '#B78962' '#956C50')
 $b+=Path 'M28 149l100-67 100 67v57l-100 44-100-44z' 'url(#glass)' 'stroke-width="3"'
 $b+=Line 'M28 149l100 45 100-45M128 82v168m-52-70v47m105-47v47m-127-88 74 35 73-35' '#A1B6A0' 3
 if($state -eq 'humid'){$b+=GasModel 139}
 if($state -eq 'vented'){$b+=Path 'M150 117l34-13 18 20-35 14z' '#D4E2C4'}
 Asset ('greenhouse_'+$state) 'z2.vegetation' greenhouse $state $b @(-53,-27,106,54) @{large=$true;gas_model_only=($state -eq 'humid')}
}
# Solar and source-loss evidence. Arrows model surface escape; water vapor is invisible.
foreach($state in @('closed','open')){
 $b=(Shadow 73)+(Box 73 205 7 4 93 'url(#wood)' '#A17D57' '#785B47')+(Box 184 205 7 4 93 'url(#wood)' '#A17D57' '#785B47')
 $b+=Path $(if($state -eq 'closed'){'M66 108l60-27 64 28-63 29z'}else{'M66 108l16-36 60-26-14 36z'}) 'url(#wood)'
 $b+=Mark $(if($state -eq 'open'){'solved'}else{''})
 Asset ('solar_canopy_'+$state) 'z2.sunlit_comparison' solar_canopy $state $b @(-37,-15,74,30)
}
foreach($state in @('closed','open','partial')){
 $b=(Shadow 38)+(Box 128 206 30 15 8 'url(#metal)' '#9BA3A0' '#6F827A')
 for($i=0;$i -lt 4;$i++){$y=112+$i*19;$b+=Path $(if($state -eq 'closed'){"M98 $y l60 15v16l-60-15z"}elseif($state -eq 'open'){"M98 $y l60 15 8-7-60-15z"}else{"M98 $y l60 15 4 4-60-15z"}) 'url(#wood)'}
 Asset ('solar_shutter_'+$state) 'z2.sunlit_comparison' solar_shutter $state $b
}
for($i=0;$i -lt 4;$i++){
 $b=(Shadow 37)+(Box 128 205 29 15 8 'url(#metal)' '#9BA3A0' '#6F827A')+(Path 'M124 193v-37h8v37z' 'url(#brass)')
 $b+='<g transform="translate(128 139) skewY('+(@(-20,-10,10,20)[$i])+')">'+(Path 'M-29-26h58v52h-58z' '#B9D3C4')+(Line 'M-23-21l29 0m-29 6 40 0' '#F6F5D8' 3)+'</g>'
 Asset ('solar_reflector_'+$i) 'z2.sunlit_comparison' solar_reflector ('orientation_'+$i) $b @(-18,-9,36,18) @{orientation_index=$i;orientation_status='proposed solar-only art directions, not existing Z1 mirror IDs'}
}
foreach($state in @('empty','supplied','evap_a','evap_b','low','observed')){
 $level=switch($state){empty{0};supplied{3};evap_a{3};evap_b{2};low{1};observed{1}}
 $active=$state -in @('evap_a','evap_b','low','observed')
 Asset ('solar_tray_'+$state) 'z2.sunlit_comparison' solar_tray $state ((Tray $level $active)+$(if($state -eq 'observed'){Mark solved})) @(-33,-14,66,28) @{process='evaporation';evidence='surface markers, decreasing liquid area; no bulk bubbles';liquid_level=$level;bulk_bubbles=0;surface_escape=$active;gas_is_invisible=$true}
}
foreach($state in @('covered','revealed','latched')){
 $b=Tray $(if($state -eq 'covered'){3}else{1})
 $b+=Path 'M120 174l10-5 10 5-10 5z' 'url(#brass)';if($state -eq 'latched'){$b+=Mark solved}
 Asset ('float_latch_'+$state) 'z2.sunlit_comparison' float_latch $state $b
}
foreach($state in @('empty','filled','cover_open','covered','warm','boil_a','boil_b','cooled')){
 Asset ('boiler_'+$state) 'z2.sunlit_comparison' boiler $state (Boiler $state) @(-31,-16,62,32) @{process='boiling comparison';water_supplied=($state -ne 'empty');cover_closed=($state -ne 'cover_open');external_heat=($state -in @('warm','boil_a','boil_b'));bulk_bubbles=$(if($state -in @('boil_a','boil_b')){6}else{0});gas_is_invisible=$true;science='guarded supplied teaching vessel; warm water is not boiling; visible bubbles throughout liquid only in boiling states'}
}
foreach($state in @('idle','turn_a','turn_b','latched')){Asset ('model_turbine_'+$state) 'z2.drying_orchard' model_turbine $state (Turbine $state) @(-28,-14,56,28) @{contained=$true;science='guarded simplified model driven by routed boiling vapor, not merely warm liquid'}}
# Recall kit kept local: no gameplay or prerequisite changes.
foreach($state in @('frozen','melting','open')){
 $b=(Shadow 44)+(Box 128 202 35 18 41 'url(#wood)' '#A17D57' '#785B47')
 if($state -ne 'open'){$b+=Box 128 202 44 22 $(if($state -eq 'frozen'){72}else{35}) 'url(#ice)' '#9DCBD0' '#6FABB9'}else{$b+=Mark solved}
 if($state -eq 'melting'){$b+=Path 'M75 209q53-19 106 0-53 26-106 0z' 'url(#water)'}
 Asset ('equipment_crate_'+$state) 'z2.sunlit_comparison' equipment_crate $state $b
}
foreach($state in @('empty','liquid','solid','latched')){Asset ('support_tray_'+$state) 'z2.sunlit_comparison' support_tray $state ((Tray $(if($state -eq 'empty'){0}else{3}))+$(if($state -in @('solid','latched')){Path 'M80 182l47-19 48 20-48 19z' 'url(#ice)'})+$(if($state -eq 'latched'){Mark solved})) @(-33,-14,66,28) @{science='recall: supplied water before solid support, mechanical latch required; no automatic walkability'}}
Asset landing_plank 'z2.sunlit_comparison' landing_plank pickup ((Shadow 44)+(Box 128 191 55 17 8 'url(#wood)' '#A17D57' '#785B47')) @(-28,-11,56,22) @{carry_fit_world=@(15,14)}
foreach($state in @('damaged','repaired')){Asset ('landing_'+$state) 'z2.sunlit_comparison' landing $state ((Shadow 65)+(Box 128 204 62 28 10 'url(#wood)' '#A17D57' '#785B47')+$(if($state -eq 'damaged'){Path 'M105 167l23 8-10 23-16-11z' '#45624E'}else{(Line 'M84 183l44 21 44-21' '#DDC297')+(Mark solved)})) @(-34,-17,68,34)}
# Drying racks, belts, airflow: surface moisture with no boiling bubbles.
foreach($state in @('wet','dry','fitted')){
 Asset ('drive_belt_'+$state) 'z2.drying_orchard' drive_belt $state ((Shadow 38)+(Belt $(if($state -eq 'wet'){'wet'}else{'dry'}))+$(if($state -eq 'fitted'){Mark solved})) @(-22,-12,44,24) @{carry_fit_world=@(15,14);surface_moisture=($state -eq 'wet');process='evaporation drying; belt material stays solid'}
}
foreach($state in @('empty','folded','spread_wet','drying','dry','cleared')){
 $b=(Shadow 74)+(Box 128 196 65 24 8 'url(#wood)' '#A17D57' '#785B47')+(Path 'M68 189v39l11 5v-39zm109 0v39l11-5v-39z' 'url(#wood)')
 if($state -notin @('empty','cleared')){$b+='<g transform="translate(128 172) scale(1 .62) translate(-128 -172)">'+(Belt $(if($state -eq 'dry'){'dry'}else{'wet'}))+'</g>'}
 if($state -eq 'folded'){$b+=Path 'M108 153l39-7 7 21-39 10z' '#648F87'}
 if($state -eq 'drying'){$b+='<g id="surface_markers">'+(Line 'M99 152v-13m29 7v-16m28 23v-14' '#9DAD9A')+'</g>'}
 if($state -in @('dry','cleared')){$b+=Mark solved}
 Asset ('drying_rack_'+$state) 'z2.drying_orchard' drying_rack $state $b @(-37,-17,74,34) @{process='surface evaporation; fan airflow is not heat';folded_spread_distinct=$true}
}
foreach($state in @('off','air_a','air_b')){
 $b=(Shadow 37)+(Box 128 205 28 14 9 'url(#metal)' '#9BA3A0' '#6F827A')+(Path 'M123 192v-30h10v30z' 'url(#metal)')+'<circle cx="128" cy="137" r="33" fill="#5C7C6D"/>'
 foreach($a in @(0,90,180,270)){$angle=$a+$(if($state -eq 'air_b'){45}else{0});$b+='<path d="M128 137q-22-24-23-8t23 8" fill="url(#metal)" transform="rotate('+$angle+' 128 137)"/>'}
 $b+='<circle cx="128" cy="137" r="6" fill="url(#brass)"/>'
 if($state -ne 'off'){$b+='<g id="airflow">'+(Line 'M171 129h21m-17 12h23m-25 12h15' '#93AF9F')+'</g>'}
 Asset ('orchard_fan_'+$state) 'z2.drying_orchard' orchard_fan $state $b @(-22,-11,44,22) @{airflow_only=$true;external_heat=$false}
}
foreach($state in @('closed','open')){Asset ('harvest_gate_'+$state) 'z2.drying_orchard' harvest_gate $state ((Shadow 65)+(Box 76 206 8 4 72 'url(#wood)' '#A17D57' '#785B47')+(Box 180 206 8 4 72 'url(#wood)' '#A17D57' '#785B47')+$(if($state -eq 'closed'){Path 'M83 144l90 8v43l-90-8z' 'url(#wood)'}else{Mark solved})) @(-32,-7,64,14)}
foreach($state in @('evaporation','boiling','wrong')){Asset ('tool_choice_'+$state) 'z2.drying_orchard' tool_choice $state ((Path 'M88 129l69-8 15 79-69 9z' '#F3E8CB')+$(if($state -eq 'evaporation'){Line 'M113 183h30m-23-6v-24m15 24v-24' '#69974F' 3}elseif($state -eq 'boiling'){'<g fill="none" stroke="#528D9B" stroke-width="3"><circle cx="116" cy="178" r="5"/><circle cx="138" cy="163" r="5"/><circle cx="122" cy="145" r="5"/></g>'}else{Mark wrong})) @(0,0,0,0)}
# Above-freezing condensation: droplets on pane, gas model source, separate ice pack.
foreach($state in @('warm','cooled','droplets','collecting')){Asset ('cooled_pane_'+$state) 'z2.greenhouse_condensation' cooled_pane $state (Pane $state) @(-30,-16,60,32) @{process='condensation';pane_temperature_celsius=$(if($state -eq 'warm'){24}else{8});ice_on_pane=$false;liquid_droplets=($state -in @('droplets','collecting'));science='humid air loses heat at pane; liquid forms on outside, not through-glass leak or frost';gas_is_invisible=$true}}
foreach($state in @('off','humid')){Asset ('humidity_source_'+$state) 'z2.greenhouse_condensation' humidity_source $state ((Tray 3 ($state -eq 'humid'))+$(if($state -eq 'humid'){GasModel 135})) @(-32,-14,64,28) @{gas_model_only=$true;science='water vapor from evaporation, invisible; model lines are an explanatory overlay'}}
foreach($state in @('straight','elbow','missing','connected','flowing')){
 $b=Shadow 48
 if($state -ne 'missing'){$b+=Pipe $(if($state -eq 'elbow'){'M88 169h40v26h40'}else{'M81 179l94 18'}) ($state -eq 'flowing')}
 if($state -eq 'missing'){$b+=Pipe 'M81 179l25 5';$b+=Pipe 'M149 192l26 5'}
 if($state -eq 'connected'){$b+=Path 'M119 179l15 3v16l-15-3z' 'url(#brass)'}
 if($state -eq 'flowing'){$b+=Droplet 178 213 4}
 Asset ('gutter_'+$state) 'z2.greenhouse_condensation' gutter $state $b @(-27,-10,54,20) @{carry_fit_world=@(15,14);liquid_only=$true}
}
foreach($state in @('empty','collecting','full','float_latched')){
 $level=if($state -eq 'empty'){0}elseif($state -eq 'collecting'){1}else{3}
 $b=(Shadow 42)+(Box 128 204 36 18 7 'url(#metal)' '#9BA3A0' '#6F827A')+(Path 'M93 137l36-17 35 17v61l-35 18-36-18z' 'url(#glass)')
 if($level){$top=194-$level*15;$b+=Path "M99 $top l30-12 29 12V194l-29 15-30-15z" 'url(#water)'}
 $b+=Line 'M141 151l12-5m-12 18 12-5m-12 18 12-5' '#E6EACA' 2
 if($state -eq 'float_latched'){$b+=Path 'M106 149l22-9 19 9-20 9z' 'url(#brass)';$b+=Mark solved}
 Asset ('collector_tank_'+$state) 'z2.greenhouse_condensation' collector_tank $state $b @(-22,-12,44,24) @{liquid_level=$level;process='collected liquid condensate, not ice'}
}
foreach($state in @('empty','liquid','freezing','solid')){Asset ('cooling_pack_'+$state) 'z2.greenhouse_condensation' cooling_pack $state (Pack $state) @(-19,-10,38,20) @{carry_fit_world=@(15,14);separate_cartridge=$true;science='water freezes inside separate cartridge; regulated observation pane stays above 0 C'}}
foreach($state in @('empty','fitted','regulated')){
 $b=(Shadow 42)+(Box 128 204 37 18 38 'url(#metal)' '#9BA3A0' '#6F827A')+(Path 'M102 164l26-12 26 12-26 13z' '#405F58')
 if($state -ne 'empty'){$b+='<g transform="translate(128 176) scale(.65) translate(-128 -185)">'+(Pack solid)+'</g>'}
 if($state -eq 'regulated'){$b+=Path 'M156 153l9-4v39l-9 4z' '#E7DAB1';$b+=Line 'M160 177v-15' '#619795' 3}
 Asset ('cooling_jacket_'+$state) 'z2.greenhouse_condensation' cooling_jacket $state $b @(-24,-12,48,24) @{regulated_pane_above_freezing=$true}
}
# Covered source -> gas model -> cooled collector -> measurable liquid return.
foreach($state in @('frozen','thawed','flowing')){
 $b=(Shadow 51)+(Box 128 205 45 22 10 'url(#metal)' '#9BA3A0' '#6F827A')+(Pipe 'M89 177l79 20' ($state -eq 'flowing'))
 if($state -eq 'frozen'){$b+=Box 128 190 30 15 44 'url(#ice)' '#9DCBD0' '#6FABB9'}else{$b+=Path 'M79 206q49-18 98 0-49 23-98 0z' 'url(#water)'}
 Asset ('stream_inlet_'+$state) 'z2.returning_stream' stream_inlet $state $b @(-27,-12,54,24)
}
foreach($state in @('gap','sealed','gas_a','gas_b','cool_return')){
 $b=(Shadow 68)+(Box 128 204 65 25 8 'url(#metal)' '#9BA3A0' '#6F827A')
 $b+=Path 'M68 182v-45l59-25 60 25v45l-60 25z' 'url(#glass)'
 $b+=Line 'M68 137l59 26 60-26m-60 26v44' '#97B2A0' 2
 if($state -eq 'gap'){$b+=Path 'M117 132l18-8 15 7-18 8z' '#DCE7D8'}else{$b+=Line 'M115 117l12-5 12 5' '#D9B56E' 4}
 if($state -in @('gas_a','gas_b','cool_return')){
  $b+='<g id="gas_model">'+(Line $(if($state -eq 'gas_b'){'M91 154l23 10-7 1m7-1-2-7m18 17 24-10-3 7m3-7-8-2'}else{'M83 151l23 10-7 1m7-1-2-7m20 16 24-10-3 7m3-7-8-2'}) '#608278' 3)+'</g>'
 }
 if($state -eq 'cool_return'){$b+=Droplet 176 187 3}
 Asset ('vapor_channel_'+$state) 'z2.returning_stream' vapor_channel $state $b @(-34,-16,68,32) @{gas_model_only=$true;gas_is_invisible=$true;connected=($state -ne 'gap');science='transparent contained channel; model marks are not a white vapor cloud'}
}
Asset channel_fitting 'z2.returning_stream' channel_fitting pickup ((Shadow 27)+(Pipe 'M104 166h23v26h26')) @(-17,-9,34,18) @{carry_fit_world=@(15,14)}
foreach($state in @('warm','cooled','droplets','returning')){Asset ('return_collector_'+$state) 'z2.returning_stream' return_collector $state (Pane $(if($state -eq 'returning'){'collecting'}else{$state})) @(-30,-16,60,32) @{process='condensation';pane_temperature_celsius=$(if($state -eq 'warm'){24}else{8});ice_on_pane=$false;liquid_droplets=($state -in @('droplets','returning'))}}
foreach($state in @('lowered','raised','locked','departing')){
 $b=(Shadow 104)+(Box 47 210 8 4 133 'url(#metal)' '#9BA3A0' '#6F827A')+(Box 209 210 8 4 133 'url(#metal)' '#9BA3A0' '#6F827A')+(Line 'M47 77h162m-140 0v124m118-124v124' '#877B5D' 4)
 $b+=Box 128 $(if($state -eq 'lowered'){204}else{152}) 67 33 9 'url(#wood)' '#A17D57' '#785B47'
 if($state -in @('locked','departing')){$b+=Mark solved;$b+=Path 'M55 145l24 0v8H55zm124 0h24v8h-24z' 'url(#brass)'}
 if($state -eq 'departing'){$b+=Line 'M118 135v-24l-6 7m6-7 6 7' '#F3E8CB' 4}
 Asset ('water_lift_'+$state) 'z2.returning_stream' water_lift $state $b @(-44,-24,88,48) @{large=$true;support_status='visual only; mechanical lock and world adapter own safe step-off'}
}
foreach($state in @('empty','supplied','returning','full')){
 $b=(Shadow 55)+(Box 128 204 49 24 10 'url(#metal)' '#9BA3A0' '#6F827A')+(Path 'M84 164l44-20 44 20v38l-44 22-44-22z' 'url(#glass)')
 if($state -ne 'empty'){$b+=Path 'M90 178l38-17 38 17v20l-38 19-38-19z' 'url(#water)'}
 if($state -eq 'returning'){$b+='<g id="return_droplets">'+(Droplet 144 142 5)+'</g>'}
 if($state -eq 'full'){$b+=Mark solved}
 Asset ('return_reservoir_'+$state) 'z2.steamworks' return_reservoir $state $b @(-28,-14,56,28) @{science='liquid return recycles water, not energy; external heat still required'}
}
foreach($state in @('empty','fitted','locked')){Asset ('pack_socket_'+$state) 'z2.steamworks' pack_socket $state ((Shadow 40)+(Box 128 204 35 18 13 'url(#metal)' '#9BA3A0' '#6F827A')+$(if($state -ne 'empty'){'<g transform="translate(128 178) scale(.7) translate(-128 -180)">'+(Pack solid)+'</g>'})+$(if($state -eq 'locked'){Mark solved})) @(-24,-12,48,24)}
Asset engine_blueprint 'z2.steamworks' engine_blueprint unlocked ((Path 'M89 135l66-10 18 73-68 11z' '#647D75')+(Line 'M107 176h20v-25h21v37h-20m0-24 20 12m-42 9h44' '#EAF0D2' 2)) @(0,0,0,0)
# Five local recipe parts, sockets, and recovery lockers.
foreach($name in @('boiler_shell','turbine_cartridge','condenser_coil','return_tank','drive_belt')){
 $part=switch($name){
  boiler_shell {(Path 'M94 132q34-21 68 0v55q-34 23-68 0z' 'url(#brass)')+'<ellipse cx="128" cy="132" rx="34" ry="12" fill="#4C675E"/>'}
  turbine_cartridge {'<g transform="translate(128 174) scale(.65) translate(-128 -151)">'+(Turbine idle)+'</g>'}
  condenser_coil {(Pipe 'M97 140h58v12H99v13h56v13H99v13h59')+(Path 'M92 133h10v64H92zm58 0h10v64h-10z' 'url(#metal)')}
  return_tank {(Box 128 192 33 17 47 'url(#metal)' '#A9B39E' '#708676')+(Path 'M112 155l20-9 13 6v31l-20 9-13-6z' 'url(#glass)')}
  drive_belt {Belt dry}
 }
 Asset ('engine_part_'+$name) 'z2.engine.recipe' ('engine_part_'+$name) pickup ((Shadow 38)+$part) @(-22,-12,44,24) @{recipe_id=$name;carry_fit_world=@(15,14);part_geometry=$part}
 foreach($state in @('empty','wrong','committed')){
  $b=(Tray 0)+'<g transform="translate(128 179) scale(.53 .36) translate(-128 -170)" opacity="'+$(if($state -eq 'committed'){'1'}else{'.45'})+'">'+$part+'</g>'
  $b+=Mark $(if($state -eq 'committed'){'solved'}elseif($state -eq 'wrong'){'wrong'}else{''})
  Asset ('engine_socket_'+$name+'_'+$state) 'z2.engine.recipe' ('engine_socket_'+$name) $state $b @(-33,-14,66,28) @{recipe_id=$name;quantity=1;science='visual slot only; atomic consumption/unique-item recovery belongs later adapter'}
 }
}
foreach($state in @('locked','open','empty')){Asset ('parts_locker_'+$state) 'z2.engine.recipe' parts_locker $state ((Shadow 43)+(Box 128 204 34 17 66 'url(#wood)' '#A17D57' '#785B47')+$(if($state -eq 'locked'){Path 'M117 157l19-8v22l-19 8z' 'url(#brass)'}elseif($state -eq 'open'){Path 'M95 137l-24-9v65l24 10z' 'url(#wood)'}else{Mark solved})) @(-25,-13,50,26)}
# Connected engine visualization, not a working machine or a new level/map.
foreach($state in @('frame','assembled','supplied','heated','turning','condensing','returning','tested','off')){
 $b=(Shadow 110)+(Box 128 213 111 45 13 'url(#wood)' '#A17D57' '#785B47')
 if($state -ne 'frame'){
  $b+='<g transform="translate(52 174) scale(.53) translate(-128 -180)">'+(Boiler $(if($state -in @('heated','turning','condensing','returning','tested')){'boil_a'}elseif($state -in @('supplied','off')){'filled'}else{'empty'}))+'</g>'
  $b+='<g transform="translate(128 168) scale(.49) translate(-128 -166)">'+(Turbine $(if($state -in @('turning','condensing','returning','tested')){'turn_a'}else{'idle'}))+'</g>'
  $b+='<g transform="translate(201 171) scale(.5) translate(-128 -180)">'+(Pane $(if($state -in @('condensing','returning','tested')){'collecting'}else{'cooled'}))+'</g>'
  $b+=Pipe 'M78 131h30v-9h63v14';$b+=Pipe 'M180 194h-65v10H61'
  if($state -in @('returning','tested')){$b+='<g id="return_droplets">'+(Droplet 154 200 3)+'</g>'}
  $b+='<g transform="translate(128 173) scale(.46 .8) translate(-128 -170)">'+(Belt dry)+'</g>'
  $b+=Box 174 211 21 11 23 'url(#metal)' '#9BA3A0' '#6F827A'
  $b+=Path 'M162 190l13-6 12 6v15l-13 6-12-6z' $(if($state -in @('returning','tested')){'url(#water)'}else{'url(#glass)'})
 }
 if($state -eq 'tested'){$b+=Mark solved}
 Asset ('engine_assembly_'+$state) 'z2.engine.recipe' engine_assembly $state $b @(-59,-29,118,58) @{large=$true;external_heat=($state -in @('heated','turning','condensing','returning','tested'));water_supplied=($state -notin @('frame','assembled'));wheel_turning=($state -in @('turning','condensing','returning','tested'));liquid_return=($state -in @('returning','tested'));science='external heat -> contained boiling -> guarded turbine -> above-freezing condenser -> liquid return; recycling water never supplies energy'}
}
# Drying Day: three shape identities, wet surface marks and matching committed hooks.
foreach($shape in @('triangle','square','notch')){
 $d=switch($shape){triangle{'M104 134h48l-24 64z'};square{'M104 134h48v58h-48z'};notch{'M104 134h48v64l-24-15-24 15z'}}
 foreach($state in @('wet','drying','dry','carried','committed')){
  $b=(Shadow 30)+(Path $d $(if($state -in @('wet','drying')){'#6A9380'}else{'#D5BD79'}))
  if($state -in @('wet','drying')){$b+='<g id="surface_moisture">'+(Droplet 125 163 4)+'</g>'}
  if($state -eq 'drying'){$b+='<g id="surface_markers">'+(Line 'M114 125v-14m21 10v-16' '#9DAD9A')+'</g>'}
  if($state -eq 'committed'){$b+=Mark solved}
  Asset ('pennant_'+$shape+'_'+$state) 'z2.drying_day' ('pennant_'+$shape) $state $b @(-16,-9,32,18) @{shape=$shape;carry_fit_world=@(15,14);process='evaporation; same cloth silhouette wet and dry';cloth_geometry=$d}
 }
 foreach($state in @('empty','wrong','committed')){
  $b=(Shadow 37)+(Box 128 205 9 5 100 'url(#wood)' '#A17D57' '#785B47')+(Line 'M99 126h60' '#997449' 5)
  $b+='<g transform="translate(0 9)" opacity="'+$(if($state -eq 'committed'){'1'}else{'.3'})+'">'+(Path $d '#D5BD79')+'</g>'
  $b+=Mark $(if($state -eq 'committed'){'solved'}elseif($state -eq 'wrong'){'wrong'}else{''})
  Asset ('pennant_hook_'+$shape+'_'+$state) 'z2.drying_day' ('pennant_hook_'+$shape) $state $b @(-18,-9,36,18) @{shape=$shape;science='optional placement, no new capability or mastery evidence'}
 }
}
# Dew Garden: water stays liquid in marked cups; matching alone grants no new lesson.
foreach($shape in @('triangle','circle','square')){
 $mark=switch($shape){triangle{'M120 183h18l-9-15z'};circle{'M129 168a8 8 0 1 1-1 0z'};square{'M121 169h16v16h-16z'}}
 foreach($state in @('empty','filling','full','carried','placed','poured')){
  $b=(Shadow 30)+(Path 'M105 157q23-12 46 0l-5 41q-18 13-36 0z' 'url(#pot)')+'<ellipse cx="128" cy="157" rx="23" ry="9" fill="'+$(if($state -in @('empty','poured')){'#775D48'}else{'url(#water)'})+'"/>'+(Path $mark '#F3E8CB')
  if($state -eq 'filling'){$b+='<g id="falling_liquid">'+(Droplet 128 135 4)+'</g>'}
  if($state -eq 'placed'){$b+=Mark solved}
  Asset ('dew_cup_'+$shape+'_'+$state) 'z2.dew_garden' ('dew_cup_'+$shape) $state $b @(-16,-9,32,18) @{shape=$shape;carry_fit_world=@(15,14);contains_liquid=($state -notin @('empty','poured'));science='collected condensate remains liquid; poured cup is empty after watering; no freezing or mastery from matching'}
 }
 foreach($state in @('dry','wrong','watered','committed')){
  $b=(Shadow 44)+(Box 128 204 38 20 29 'url(#pot)' '#BD8A62' '#986C50')+(Path 'M95 171l33-16 34 17-34 16z' $(if($state -in @('watered','committed')){'#695D43'}else{'#A18B62'}))+(Path 'M127 173v-31m0 22-15-9m15 2 15-9' none 'stroke="#69974F" stroke-width="4"')+'<g transform="translate(-2 25)">'+(Path $mark '#F3E8CB')+'</g>'
  if($state -eq 'wrong'){$b+=Mark wrong}
  if($state -in @('watered','committed')){$b+='<g id="wet_soil">'+(Line 'M105 174l13-5m20 7 11-5' '#8EC1B8' 2)+'</g>'}
  if($state -eq 'committed'){$b+=Mark solved}
  Asset ('dew_planter_'+$shape+'_'+$state) 'z2.dew_garden' ('dew_planter_'+$shape) $state $b @(-25,-13,50,26) @{shape=$shape;soil_wet=($state -in @('watered','committed'));science='matching cup marks and wet soil; local optional celebration only'}
 }
 Asset ('dew_card_'+$shape) 'z2.dew_garden' ('dew_card_'+$shape) idle ((Path 'M91 134l60-8 17 73-60 9z' '#F3E8CB')+'<g transform="translate(128 171) scale(2) translate(-129 -176)">'+(Path $mark '#5F8273')+'</g>') @(0,0,0,0) @{shape=$shape;localized_observation='water vapor cooled -> liquid drops -> cup -> planter; explanatory UI belongs R3 010'}
}
Asset interaction_selected 'z2.sunlit_comparison' interaction selected (Mark selected) @(0,0,0,0) @{layer='overlay only'}
$taskCatalog=[ordered]@{schema_version=1;kit_id='phase-quest-r3-zone2-v1';status='R3 005 Implemented—needs verification; external acceptance pending';standard='docs/art/r3-prompt002/production-contract.json';source_builder='tools/art/zone2_v1/build_kit.ps1';coordinate_contract='2 source px/world unit; scale .5; measured camera1.55; default ground pivot128,208, large192,264';footprints='proposed art placement only, no live physics/support';entries=$taskRows}
$taskCatalog|ConvertTo-Json -Depth 14|Set-Content (Join-Path $taskOut kit_catalog.json) -Encoding utf8
Write-Output ('R3 005 authored '+$taskRows.Count+' SVG assets')
