. (Join-Path $PSScriptRoot 'svg_support.ps1')
function Frost([int]$Size=17,[string]$Pattern='branch'){
 $d=switch($Pattern){
  branch {"M128 $(142-$Size)V$(142+$Size)M$(128-$Size) 142H$(128+$Size)M$(128-$Size*.7) $(142-$Size*.7)L$(128+$Size*.7) $(142+$Size*.7)M$(128-$Size*.7) $(142+$Size*.7)L$(128+$Size*.7) $(142-$Size*.7)"}
  star {"M128 $(142-$Size)L128 $(142+$Size)M$(128-$Size) $(142-$Size*.5)L$(128+$Size) $(142+$Size*.5)M$(128-$Size) $(142+$Size*.5)L$(128+$Size) $(142-$Size*.5)"}
  grid {"M$(128-$Size) $(142-$Size)H$(128+$Size)V$(142+$Size)H$(128-$Size)ZM128 $(142-$Size)V$(142+$Size)M$(128-$Size) 142H$(128+$Size)"}
 }
 return '<g id="solid_frost">'+(Line $d '#6E9BA9' 6)+(Line $d '#E9F4EF' 3)+'</g>'
}
function Chamber([string]$Process,[int]$Stage=0,[string]$Pattern='branch'){
 $b=(Shadow 65)+(Box 128 205 55 27 12 'url(#metal)' '#8A969B' '#5C6B75')
 $b+=Path 'M77 184V89l51-23 51 23v95l-51 26z' 'url(#glass)' 'stroke-width="3"'
 # Dry liquid sensor tray is independent of sample/frost and remains visible in every direct route.
 $b+='<g id="liquid_sensor_empty">'+(Path 'M97 187l31-12 31 12-31 13z' '#6E8590')+(Line 'M105 187l23-8 23 8' '#C4D4D5' 2)+'</g>'
 $gas=0;$frost=0
 if($Process -eq 'sublimation'){
  if($Stage -lt 3){$w=@(23,18,11)[$Stage];$h=@(43,29,15)[$Stage];$b+='<g id="source_solid">'+(Box 128 165 $w ([int]($w*.5)) $h 'url(#ice)' '#A3CED5' '#79A6B7')+'</g>'}
  $gas=[Math]::Min(3,$Stage)*15
 }
 if($Process -eq 'melting'){
  if($Stage -lt 3){$w=@(23,18,11)[$Stage];$h=@(43,29,15)[$Stage];$b+='<g id="source_solid">'+(Box 128 165 $w ([int]($w*.5)) $h 'url(#ice)' '#A3CED5' '#79A6B7')+'</g>'}
  if($Stage -gt 0){$b+='<g id="intermediate_liquid">'+(Path 'M101 187l27-10 27 10-27 10z' 'url(#water)')+'</g>'}
 }
 if($Process -in @('deposition','resublimation')){
  $b+=Path 'M101 112l54-2v58l-54 2z' '#6D8C98'
  $frost=if($Process -eq 'resublimation'){@(20,14,8,0)[[Math]::Min(3,$Stage)]}else{switch($Stage){0{0};1{0};2{8};3{14};4{20};5{26};6{20}}}
  if($frost){$b+=Frost $frost $Pattern}
  $b+='<g id="optical_target">'+(Line 'M99 123h60' '#C2A877' 2)+'</g>'
  $gas=if($Process -eq 'resublimation'){[Math]::Min(3,$Stage)*15}else{switch($Stage){0{0};1{45};2{32};3{16};default{0}}}
 }
 if($gas -gt 0){
  $b+='<g id="gas_model" fill="none" stroke="#91A6B0" stroke-width="2" stroke-dasharray="3 3"><path d="M97 119l12 6m9-8 12 7m9-7 14 7"/></g>'
 }
 $b+=Path 'M187 114h13v64h-13z' '#DCE4DE'
 if($gas -gt 0){$b+='<g id="captured_gas_indicator">'+(Path "M190 $(175-$gas)h7v$gas h-7z" '#B8A0DC')+'</g>'}
 $b+=Line 'M190 129h7m-7 16h7m-7 16h7' '#6E8590' 1
 # Fixed opaque frame, cap, base, gasket and bolts remain in all process states.
 $b+='<g id="containment_frame">'+(Box 128 90 55 25 10 'url(#metal)' '#8A969B' '#5C6B75')+(Line 'M77 89v95m102-95v95m-102 0 51 26 51-26' '#55717E' 4)+(Line 'M85 95v81m86-81v81' '#D9E7E4' 1.5)+'<circle cx="79" cy="110" r="3" fill="#BFA77F"/><circle cx="177" cy="110" r="3" fill="#BFA77F"/>'+(Path 'M107 207l21 9 21-9v6l-21 9-21-9z' '#BFA77F')+'</g>'
 $b+=Pipe 'M77 143H64v-22';$b+=Pipe 'M179 145h28v-19'
 if($Process -ne 'melting'){$b+='<g id="condition_heat_exchange">'+(Line $(if($Process -in @('sublimation','resublimation')){'M42 145h19l-5-4m5 4-5 4'}else{'M61 149H42l5-4m-5 4 5 4'}) $(if($Process -in @('sublimation','resublimation')){'#E6A34A'}else{'#80B7CE'}) 3)+'</g>'}
 return $b
}
function Direct-Extra([string]$Process,[int]$Stage){
 return @{process=$Process;stage=$Stage;sealed=$true;intermediate_liquid=$false;liquid_sensor='empty';gas_is_invisible=$true;gas_model_only=$true;supports_player=$false;frost_is_sample=$true;conditions='suitable regulated sealed chamber with supplied water sample/vapor and controlled heat exchange; never arbitrary-room automatic transformation'}
}
# Sparse lab dressing. Surfaces remain independent from actual traversal/support.
foreach($state in @('plain','service','glass')){
 $b=(Shadow 77)+(Box 128 205 70 24 82 'url(#metal)' '#A7B4B9' '#738994')
 if($state -eq 'service'){$b+=Path 'M85 139l37 14v41l-37-15z' '#5C7583';$b+=Line 'M90 150l26 10m-26 1 26 10m-26 1 26 10' '#B3C1C2'}
 if($state -eq 'glass'){$b+=Path 'M140 155l43-17v43l-43 18z' 'url(#glass)';$b+=Line 'M146 159l25-10' '#E9F4EF'}
 Asset ('lab_wall_'+$state) 'z3.lab_environment' lab_wall $state $b @(-37,-15,74,30)
}
foreach($state in @('clear','sample','tools')){
 $b=(Shadow 68)+(Box 128 191 63 27 10 'url(#metal)' '#8A969B' '#5C6B75')+(Path 'M71 191v39l10 5v-39zm104 0v39l10-5v-39z' '#738994')
 if($state -eq 'sample'){$b+='<g transform="translate(128 177) scale(.48) translate(-128 -180)">'+(Chamber sublimation 0)+'</g>'}
 if($state -eq 'tools'){$b+=Line 'M99 168l18 9m8-15 10 7m8-10 16 9' '#BFA77F' 4}
 Asset ('worktop_'+$state) 'z3.lab_environment' worktop $state $b @(-35,-17,70,34)
}
Asset glass_boundary 'z3.lab_environment' glass_boundary idle ((Shadow 61)+(Path 'M69 185V103l118 34v82z' 'url(#glass)' 'stroke-width="4"')+(Line 'M77 113l32 10m-32 1 43 14' '#E9F4EF')) @(-31,-10,62,20)
foreach($state in @('covered','open')){Asset ('cable_cover_'+$state) 'z3.lab_environment' cable_cover $state ((Shadow 54)+(Box 128 205 48 15 10 'url(#metal)' '#8A969B' '#5C6B75')+$(if($state -eq 'open'){Line 'M88 191l79 18' '#536C7D' 5}else{Line 'M90 193l76 18' '#D9E7E4' 2})) @(-26,-9,52,18)}
Asset permanent_step 'z3.lab_environment' permanent_step idle ((Shadow 56)+(Box 128 205 50 25 20 'url(#metal)' '#8A969B' '#5C6B75')+(Line 'M91 180l37-18 37 18' '#E9F4EF')) @(-27,-14,54,28) @{science='permanent metal step; frost never supplies this support';supports_player=$false}
foreach($state in @('closed','open')){Asset ('lab_gate_'+$state) 'z3.lab_environment' lab_gate $state ((Shadow 67)+(Box 76 205 9 5 94 'url(#metal)' '#8A969B' '#5C6B75')+(Box 182 205 9 5 94 'url(#metal)' '#8A969B' '#5C6B75')+$(if($state -eq 'closed'){Path 'M85 120l87 11v69l-87-11z' 'url(#glass)' 'stroke-width="3"'}else{Mark solved})) @(-34,-8,68,16)}
foreach($state in @('closed','open','isolated')){
 $b=(Shadow 43)+(Pipe 'M82 179l93 20' ($state -eq 'open'))+'<circle cx="128" cy="155" r="20" fill="#718895"/>'+(Line $(if($state -eq 'open'){'M110 155h36'}else{'M128 137v36'}) '#BFA77F' 5)
 if($state -eq 'isolated'){$b+=Path 'M147 173l10-5 9 17-10 5z' 'url(#metal)'}
 Asset ('lab_valve_'+$state) 'z3.lab_environment' lab_valve $state $b @(-27,-10,54,20)
}
foreach($state in @('normal','low','regulated','unsuitable')){
 $b=(Shadow 34)+(Box 128 205 25 13 11 'url(#metal)' '#8A969B' '#5C6B75')+(Path 'M123 194v-29h10v29z' 'url(#metal)')+'<circle cx="128" cy="141" r="28" fill="#E7EEEA"/>'
 $b+=Line 'M109 151l-2-7m7-15 3 4m22-3-3 4m11 11-2 6' '#839AA3' 2
 $b+=Line $(switch($state){low{'M128 141l-14 8'};normal{'M128 141v-19'};regulated{'M128 141l15-10'};unsuitable{'M128 141l18 8'}}) '#B89D77' 3
 if($state -eq 'unsuitable'){$b+=Mark wrong}
 Asset ('condition_gauge_'+$state) 'z3.lab_environment' condition_gauge $state $b @(-18,-9,36,18) @{numeric_conditions='runtime labels/actual phase-region controls remain later integration, not inferred from pointer'}
}
foreach($state in @('off','heat_in','heat_out')){
 $b=(Shadow 47)+(Box 128 204 37 18 55 'url(#metal)' '#8A969B' '#5C6B75')
 for($i=0;$i -lt 4;$i++){$y=155+$i*10;$b+=Line "M97 $y l62 4" '#B3D7DC' 4}
 if($state -ne 'off'){$b+=Line $(if($state -eq 'heat_in'){'M78 130h27l-6-5m6 5-6 5'}else{'M105 130H78l6-5m-6 5 6 5'}) $(if($state -eq 'heat_in'){'#E6A34A'}else{'#80B7CE'}) 3}
 Asset ('heat_exchanger_'+$state) 'z3.lab_environment' heat_exchanger $state $b @(-23,-12,46,24)
}
Asset lab_planter 'z3.lab_environment' lab_planter idle ((Shadow 31)+(Box 128 204 25 13 23 'url(#metal)' '#8A969B' '#5C6B75')+(Path 'M128 177v-33m0 17-16-9m16 3 15-10' none 'stroke="#718A76" stroke-width="5"')) @(-18,-9,36,18)
# Existing four preview frames: new resource wrappers, unchanged original PNG pixels.
New-Item -ItemType Directory -Force (Join-Path $taskOut reused)|Out-Null
for($i=0;$i -lt 4;$i++){
 $id=@('preview_source_solid','preview_captured_gas','preview_supplied_vapor','preview_deposited_frost')[$i]
 $rx=($i%2)*128;$ry=[int][Math]::Floor($i/2)*128
 $file=Join-Path $taskOut ('reused/'+$id+'.tres')
 $resource="[gd_resource type=`"AtlasTexture`" load_steps=2 format=3]`n`n[ext_resource type=`"Texture2D`" path=`"res://assets/effects/chamber/v1/atlas.png`" id=`"source`"]`n`n[resource]`natlas = ExtResource(`"source`")`nregion = Rect2($rx, $ry, 128, 128)`nfilter_clip = true`n"
 [IO.File]::WriteAllText($file,$resource,[Text.UTF8Encoding]::new($false))
 $taskRows.Add([ordered]@{id=$id;family='z3.chamber.preview';group='existing_preview';state=@('source_solid','captured_gas','supplied_vapor','deposited_frost')[$i];path=('res://assets/zones/zone_3/world_v1/reused/'+$id+'.tres');source_size=@(128,128);pivot_px=@(64,113);world_scale=.5;footprint_world=@(-22,-10,44,20);collision_status='preview reference only, no physics/support';owner='R3 006';consumer='isolated compatibility review; existing previews unchanged; R3 008 device review later';dependencies=@('R3 003','existing chamber/v1 resource');action='keep';source_format='AtlasTexture wrapper over unchanged native PNG frame';observed_source='assets/effects/chamber/v1/atlas.png';source_region=@($rx,$ry,128,128);license='Existing original generation provenance tools/art/chamber_v1/generation.md retained';sha256=(Get-FileHash $file -Algorithm SHA256).Hash;sealed=$true;intermediate_liquid=$false;supports_player=$false;frost_is_sample=$true;sorting='selected ground registration for review, not a migrated campaign transform'})
}
# Direct source transition: shrinking solid + rising captured-gas indicator, empty liquid sensor.
foreach($stage in @(0,1,2,3)){
 $state=@('solid','shrinking_early','shrinking_late','captured_gas')[$stage]
 Asset ('sublimation_'+$state) 'z3.vanishing_ice' sublimation $state (Chamber sublimation $stage) @(-33,-16,66,32) (Direct-Extra sublimation $stage)
}
foreach($state in @('frozen','clearing','clear')){Asset ('sample_slot_'+$state) 'z3.vanishing_ice' sample_slot $state ((Chamber sublimation (@(0,2,3)[@('frozen','clearing','clear').IndexOf($state)]))+$(if($state -eq 'clear'){Mark solved})) @(-33,-16,66,32) (Direct-Extra sublimation (@(0,2,3)[@('frozen','clearing','clear').IndexOf($state)]))}
foreach($state in @('wet','drying','dry')){Asset ('utility_seal_'+$state) 'z3.vanishing_ice' utility_seal $state ((Shadow 31)+(Path 'M98 153l47-9 13 43-47 12z' '#CABCA1')+$(if($state -eq 'wet'){Droplet 127 169 5}elseif($state -eq 'drying'){Line 'M113 139v-18m25 12v-18' '#8FA3AA' 3}else{Mark solved})) @(-18,-9,36,18) @{process='evaporation recall, not sublimation of cloth'}}
foreach($state in @('filled','warm','boil_a','boil_b','cooled')){Asset ('utility_boiler_'+$state) 'z3.vanishing_ice' utility_boiler $state (Boiler $state) @(-31,-16,62,32) @{process='boiling recall';sealed=$true;bulk_bubbles=$(if($state -in @('boil_a','boil_b')){6}else{0});liquid_in_path=$true;intermediate_liquid=$false}}
foreach($state in @('warm','cooled','droplets','collecting')){Asset ('recovery_condenser_'+$state) 'z3.sample_sorting' recovery_condenser $state (Pane $state) @(-30,-16,60,32) @{process='condensation after captured gas';pane_temperature_celsius=$(if($state -eq 'warm'){24}else{8});ice_on_pane=$false;liquid_droplets=($state -in @('droplets','collecting'))}}
foreach($state in @('empty','filling','full')){Asset ('utility_tank_'+$state) 'z3.vanishing_ice' utility_tank $state ((Tray $(if($state -eq 'empty'){0}elseif($state -eq 'filling'){1}else{3}))+$(if($state -eq 'filling'){Droplet 128 154 5})+$(if($state -eq 'full'){Mark solved})) @(-32,-14,64,28) @{process='liquid collection from separate utility recall, never an intermediate in direct source path'}}
foreach($stage in @(0,1,2,3)){
 $state=@('solid','melting_early','melting_late','liquid')[$stage]
 Asset ('normal_warmer_'+$state) 'z3.sample_sorting' normal_warmer $state (Chamber melting $stage) @(-33,-16,66,32) @{process='melting';stage=$stage;sealed=$true;liquid_in_path=($stage -gt 0);intermediate_liquid=$false;liquid_sensor=$(if($stage -gt 0){'detected'}else{'empty'});supports_player=$false;conditions='normal-pressure water-ice comparison, not direct solid-to-gas'}
}
foreach($sensor in @('solid','liquid','gas')){foreach($state in @('empty','detected','wrong')){
 $b=(Shadow 31)+(Box 128 205 25 13 38 'url(#metal)' '#8A969B' '#5C6B75')
 $glyph=switch($sensor){solid{Path 'M116 154h24v24h-24z' '#C9E6EA'};liquid{Droplet 128 166 6};gas{'<g fill="none" stroke="#B8A0DC" stroke-width="2"><circle cx="118" cy="158" r="3"/><circle cx="138" cy="168" r="3"/><circle cx="121" cy="178" r="3"/></g>'}}
 $b+=$glyph
 $b+=Mark $(if($state -eq 'detected'){'solved'}elseif($state -eq 'wrong'){'wrong'}else{''})
 Asset ('phase_sensor_'+$sensor+'_'+$state) 'z3.sample_sorting' ('phase_sensor_'+$sensor) $state $b @(-18,-9,36,18) @{measures=$sensor;gas_model_only=($sensor -eq 'gas');science='separate phase evidence; disappearing source alone is not proof'}
}}
foreach($path in @('liquid','direct_gas')){foreach($state in @('closed','wrong','open')){Asset ('route_lock_'+$path+'_'+$state) 'z3.sample_sorting' ('route_lock_'+$path) $state ((Shadow 36)+(Box 128 205 28 14 52 'url(#metal)' '#8A969B' '#5C6B75')+$(if($path -eq 'liquid'){Droplet 128 157 5}else{GasModel 169})+(Mark $(if($state -eq 'open'){'solved'}elseif($state -eq 'wrong'){'wrong'}else{''}))) @(-20,-10,40,20) @{requires_observed_path=$path}}}
# Frostprint: direct deposition is a small measured sample behind glass, never ground.
foreach($stage in @(0,1,2,3,4,5,6)){
 $state=@('empty','supplied_vapor','early_frost','growing','target','overgrown','isolated')[$stage]
 Asset ('deposition_'+$state) 'z3.frostprint' deposition $state (Chamber deposition $stage) @(-33,-16,66,32) (Direct-Extra deposition $stage)
}
foreach($state in @('warm','cooled','droplets','collecting')){Asset ('dew_comparison_'+$state) 'z3.frostprint' dew_comparison $state (Pane $state) @(-30,-16,60,32) @{process='condensation comparison';pane_temperature_celsius=$(if($state -eq 'warm'){24}else{8});ice_on_pane=$false;liquid_in_path=$true;intermediate_liquid=$false}}
foreach($state in @('below','at_target','above','cleared')){Asset ('optical_sensor_'+$state) 'z3.frostprint' optical_sensor $state ((Shadow 32)+(Box 128 205 24 12 48 'url(#metal)' '#8A969B' '#5C6B75')+(Line 'M112 159h31' '#BFA77F' 3)+$(if($state -ne 'cleared'){'<g transform="translate(128 170) scale(.55) translate(-128 -142)">'+(Frost $(if($state -eq 'below'){10}elseif($state -eq 'above'){27}else{19}))+'</g>'})+(Mark $(if($state -in @('at_target','cleared')){'solved'}else{''}))) @(-17,-9,34,18) @{supports_player=$false;frost_is_sample=$true;science='optical target/absence signal only; permanent floor is separate'}}
foreach($stage in @(0,1,2,3)){Asset ('frost_removal_'+$stage) 'z3.reversible_circuit' frost_removal (@('target','shrinking_early','shrinking_late','captured_gas')[$stage]) (Chamber resublimation $stage) @(-33,-16,66,32) (Direct-Extra resublimation $stage)}
foreach($receiver in @('a','b')){foreach($state in @('empty','target','cleared')){
 $b=if($state -eq 'cleared'){Chamber resublimation 3}else{Chamber deposition $(if($state -eq 'target'){4}else{0})}
 $b+=Line $(if($receiver -eq 'a'){'M116 226h24'}else{'M116 223h24m-24 5h24'}) '#B8A0DC' 3
 Asset ('receiver_'+$receiver+'_'+$state) 'z3.reversible_circuit' ('receiver_'+$receiver) $state $b @(-33,-16,66,32) @{receiver_id=$receiver;sealed=$true;intermediate_liquid=$false;supports_player=$false;frost_is_sample=$true;science='distinct receiver marks; vapor transfer not liquid; actual geography/addressing later'}
}}
# Reversible circuit: two contained vessels with explicit gas-only transfer route.
foreach($state in @('disconnected','ready','transfer','target_a','isolated','resublimating','transfer_b','target_b','complete')){
 $b=(Shadow 110)+(Box 128 215 113 42 12 'url(#metal)' '#8A969B' '#5C6B75')
 $sourceStage=switch($state){disconnected{0};ready{0};transfer{1};default{3}}
 $receiveStage=switch($state){target_a{4};isolated{6};resublimating{3};transfer_b{1};target_b{4};complete{6};default{0}}
 $b+='<g transform="translate(61 181) scale(.56) translate(-128 -180)">'+(Chamber sublimation $sourceStage)+'</g>'
 $b+='<g transform="translate(197 181) scale(.56) translate(-128 -180)">'+$(if($state -eq 'resublimating'){Chamber resublimation 1}else{Chamber deposition $receiveStage})+'</g>'
 $b+=Pipe $(if($state -eq 'disconnected'){'M94 133h24m25 0h21'}else{'M94 133h70'}) ($state -in @('transfer','transfer_b'))
 if($state -in @('transfer','transfer_b')){$b+='<g id="gas_model">'+(Line 'M113 123h24l-6-4m6 4-6 4' '#849AA5' 3)+'</g>'}
 if($state -eq 'isolated'){$b+=Path 'M123 123h12v20h-12z' 'url(#brass)'}
 if($state -eq 'complete'){$b+=Mark solved}
 Asset ('reversible_circuit_'+$state) 'z3.reversible_circuit' reversible_circuit $state $b @(-60,-29,120,58) @{large=$true;process='sublimation/deposition';sealed=$true;intermediate_liquid=$false;supports_player=$false;gas_is_invisible=$true;frost_is_sample=$true;second_target='separately addressed receiver/sensor in later world adapter, no liquid pipe or structural frost'}
}
# Seven paths: vaporization has two separate observed routes.
$taskRoutes=@('melting','freezing','evaporation','boiling','condensation','sublimation','deposition')
foreach($route in $taskRoutes){foreach($state in @('unobserved','observed')){
 $sourceGlyph=switch($route){melting{'solid'};freezing{'liquid'};evaporation{'liquid'};boiling{'liquid'};condensation{'gas'};sublimation{'solid'};deposition{'gas'}}
 $destGlyph=switch($route){melting{'liquid'};freezing{'solid'};evaporation{'gas'};boiling{'gas'};condensation{'liquid'};sublimation{'gas'};deposition{'solid'}}
 $b=Path 'M80 122l92-4 10 88-92 8z' '#E5EADD'
 foreach($g in @(@($sourceGlyph,103),@($destGlyph,153))){$x=$g[1];$b+=switch($g[0]){solid{Path "M$($x-8) 151h16v20h-16z" '#C9E6EA'};liquid{Droplet $x 159 5};gas{'<g fill="none" stroke="#9F93BB" stroke-width="2"><circle cx="'+($x-5)+'" cy="153" r="2.5"/><circle cx="'+($x+5)+'" cy="162" r="2.5"/></g>'}}}
 $b+=Line 'M118 161h20l-5-4m5 4-5 4' '#637F8C' 2
 if($route -in @('sublimation','deposition')){$b+=Line 'M103 181h50' '#B8A0DC' 2}
 if($route -eq 'evaporation'){$b+=Line 'M94 193h17m-13-3v-9m9 9v-9' '#637F8C' 2}
 if($route -eq 'boiling'){$b+='<g fill="none" stroke="#528D9B"><circle cx="101" cy="187" r="3"/><circle cx="111" cy="198" r="3"/></g>'}
 if($state -eq 'observed'){$b+=Mark solved}
 Asset ('path_card_'+$route+'_'+$state) 'z3.observatory' ('path_card_'+$route) $state $b @(0,0,0,0) @{process=$route;initial_state=$sourceGlyph;final_state=$destGlyph;liquid_in_path=($route -notin @('sublimation','deposition'));intermediate_liquid=$false;heat_direction=$(if($route -in @('melting','evaporation','boiling','sublimation')){'in'}else{'out'});labels='localized route/state/heat words belong later learning UI; glyphs are not sole evidence'}
}}
foreach($route in $taskRoutes){foreach($state in @('ready','observed')){
 $content=switch($route){melting{Chamber melting $(if($state -eq 'observed'){3}else{0})};freezing{Pack $(if($state -eq 'observed'){'solid'}else{'liquid'})};evaporation{Tray $(if($state -eq 'observed'){1}else{3}) ($state -eq 'observed')};boiling{Boiler $(if($state -eq 'observed'){'boil_a'}else{'warm'})};condensation{Pane $(if($state -eq 'observed'){'collecting'}else{'cooled'})};sublimation{Chamber sublimation $(if($state -eq 'observed'){3}else{0})};deposition{Chamber deposition $(if($state -eq 'observed'){4}else{1})}}
 Asset ('exhibit_'+$route+'_'+$state) 'z3.observatory' ('exhibit_'+$route) $state $content @(-33,-16,66,32) @{process=$route;liquid_in_path=($route -notin @('sublimation','deposition'));intermediate_liquid=$false;sealed=($route -in @('melting','boiling','sublimation','deposition'));supports_player=$false;frost_is_sample=($route -eq 'deposition')}
}}
foreach($room in @('solid_liquid','liquid_gas','solid_gas')){foreach($state in @('locked','ready','complete')){Asset ('exhibit_sign_'+$room+'_'+$state) 'z3.observatory' ('exhibit_sign_'+$room) $state ((Shadow 32)+(Box 128 205 8 4 85 'url(#metal)' '#8A969B' '#5C6B75')+(Path 'M94 123l69 8v41l-69-8z' '#D9DFD9')+(Line 'M108 142h39l-6-4m6 4-6 4' '#8BA2AD' 3)+(Mark $(if($state -eq 'complete'){'solved'}elseif($state -eq 'locked'){'wrong'}else{''}))) @(-18,-9,36,18) @{room=$room;labels='world room title/learning progress remain later adapter'}}}
Asset cartridge_blueprint 'z3.observatory' cartridge_blueprint unlocked ((Path 'M89 134l64-9 19 73-66 11z' '#687F8F')+(Line 'M109 158l30-8 10 32-30 8zm9 8 20-5m-13 19 15-4' '#D9E7E4' 2)) @(0,0,0,0)
# Phaseworks Core local recipe; ice sample always carried inside holder.
foreach($name in @('housing','collector_plate','vapor_tube','calibrated_sensor','water_ice_sample')){
 $part=switch($name){housing{(Box 128 195 34 16 54 'url(#metal)' '#8A969B' '#5C6B75')+(Path 'M111 145l18-8 16 8v40l-18 8-16-8z' '#566F7C')};collector_plate{(Box 128 193 36 17 6 'url(#metal)' '#A4BEC6' '#718E9E')+(Line 'M103 172l25-12 25 12' '#B3D7DC' 3)};vapor_tube{Pipe 'M93 157h23v26h42'};calibrated_sensor{(Box 128 197 22 11 49 'url(#metal)' '#8A969B' '#5C6B75')+'<circle cx="129" cy="154" r="14" fill="#D9E7E4"/>'+(Line 'M129 154l7-8' '#BFA77F' 3)};water_ice_sample{'<g transform="translate(128 174) scale(.57) translate(-128 -160)">'+(Chamber sublimation 0)+'</g>'}}
 Asset ('cartridge_part_'+$name) 'z3.cartridge.recipe' ('cartridge_part_'+$name) pickup ((Shadow 38)+$part) @(-22,-11,44,22) @{recipe_id=$name;carry_fit_world=@(15,14);science='mechanical holder bears load; supplied water-ice remains contained, never handheld dry ice'}
 foreach($state in @('empty','wrong','committed')){Asset ('cartridge_slot_'+$name+'_'+$state) 'z3.cartridge.recipe' ('cartridge_slot_'+$name) $state ((Tray 0)+'<g transform="translate(128 179) scale(.53 .36) translate(-128 -170)" opacity="'+$(if($state -eq 'committed'){'1'}else{'.4'})+'">'+$part+'</g>'+(Mark $(if($state -eq 'committed'){'solved'}elseif($state -eq 'wrong'){'wrong'}else{''}))) @(-32,-14,64,28) @{recipe_id=$name;quantity=1;atomic_commit='future adapter only'}}
}
foreach($state in @('liquid','solid','fitted','released')){Asset ('assembly_jig_'+$state) 'z3.cartridge.recipe' assembly_jig $state ((Tray 3)+$(if($state -in @('solid','fitted')){Path 'M80 182l47-19 48 20-48 19z' 'url(#ice)'})+$(if($state -in @('fitted','released')){Box 128 168 30 15 6 'url(#metal)' '#A4BEC6' '#718E9E'})) @(-32,-14,64,28) @{science='recall water freezes/melts around temporary jig; permanent metal plate remains solid';plate_present=($state -in @('fitted','released'))}}
foreach($state in @('frozen','clearing','open')){Asset ('delivery_port_'+$state) 'z3.cartridge.recipe' delivery_port $state ((Chamber sublimation (@(0,2,3)[@('frozen','clearing','open').IndexOf($state)]))+$(if($state -eq 'open'){Mark solved})) @(-33,-16,66,32) (Direct-Extra sublimation (@(0,2,3)[@('frozen','clearing','open').IndexOf($state)]))}
foreach($state in @('empty','sealed','source_solid','source_shrinking','vapor_captured','depositing','target','verified','inserted','frost_removed')){
 $stage=switch($state){depositing{3};target{4};verified{6};inserted{6};default{0}}
 $b=if($state -eq 'frost_removed'){Chamber resublimation 3}elseif($state -in @('source_solid','source_shrinking','vapor_captured')){Chamber sublimation (@{source_solid=0;source_shrinking=1;vapor_captured=3}[$state])}else{Chamber deposition $stage}
 if($state -in @('verified','inserted','frost_removed')){$b+=Mark solved}
 Asset ('cartridge_'+$state) 'z3.cartridge.recipe' cartridge $state $b @(-33,-16,66,32) @{process='solid -> gas -> solid -> gas';sealed=$true;intermediate_liquid=$false;supports_player=$false;frost_is_sample=$true;recipe_committed=($state -notin @('empty','sealed'));science='housing bears load; deposited frost is measured sample, final scanner removes it directly into captured gas'}
}
foreach($state in @('empty','inserted','conditions_ready','removing','absence_signal','exit_allowed')){
 $b=(Shadow 93)+(Box 128 210 83 39 14 'url(#metal)' '#8A969B' '#5C6B75')+(Box 128 192 68 28 91 'url(#metal)' '#8A969B' '#5C6B75')
 $b+=Path 'M88 124l40-18 40 18v67l-40 20-40-20z' '#536D7C'
 if($state -ne 'empty'){$b+='<g transform="translate(128 177) scale(.52) translate(-128 -180)">'+$(if($state -in @('removing','absence_signal','exit_allowed')){Chamber resublimation $(if($state -eq 'removing'){1}else{3})}else{Chamber deposition 4})+'</g>'}
 if($state -in @('absence_signal','exit_allowed')){$b+=Mark solved}
 Asset ('exit_scanner_'+$state) 'z3.cartridge.recipe' exit_scanner $state $b @(-46,-23,92,46) @{large=$true;sealed=$true;intermediate_liquid=$false;supports_player=$false;frost_is_sample=$true;science='powered sealed scanner establishes suitable sublimation conditions; absence signal follows frost removal; Finn6/6 not implemented'}
}
foreach($state in @('locked','allowed')){Asset ('final_exit_'+$state) 'z3.cartridge.recipe' final_exit $state ((Shadow 64)+(Box 78 205 9 5 100 'url(#metal)' '#8A969B' '#5C6B75')+(Box 178 205 9 5 100 'url(#metal)' '#8A969B' '#5C6B75')+(Line 'M78 104h100' '#BFA77F' 5)+(Mark $(if($state -eq 'allowed'){'solved'}else{'wrong'}))) @(-33,-8,66,16) @{science='final campaign exit only; no Zone4 created'}}
# Optional Sample Match uses observed path evidence, not size/disappearance or color alone.
foreach($route in @('melting','sublimation')){foreach($state in @('empty','wrong','committed')){Asset ('sample_match_'+$route+'_'+$state) 'z3.sample_match' ('sample_match_'+$route) $state ((Tray 0)+$(if($route -eq 'melting'){Droplet 128 175 6}else{GasModel 186})+(Mark $(if($state -eq 'committed'){'solved'}elseif($state -eq 'wrong'){'wrong'}else{''}))) @(-32,-14,64,28) @{requires_observation=$route;science='optional comparison matching grants no new mastery; relevant path cards are shared observatory art'}}}
# Optional Frost Gallery: contained patterns and committed displays, never physical ground.
foreach($pattern in @('branch','star','grid')){
 foreach($state in @('empty','early','growing','target','isolated')){
  $stage=@{empty=0;early=2;growing=3;target=4;isolated=6}[$state]
  Asset ('gallery_collector_'+$pattern+'_'+$state) 'z3.frost_gallery' ('gallery_collector_'+$pattern) $state (Chamber deposition $stage $pattern) @(-33,-16,66,32) @{pattern=$pattern;sealed=$true;intermediate_liquid=$false;supports_player=$false;frost_is_sample=$true;science='direct deposition pattern inside collector; no liquid stage, no structural platform'}
 }
 foreach($state in @('carried','placed')){Asset ('gallery_sample_'+$pattern+'_'+$state) 'z3.frost_gallery' ('gallery_sample_'+$pattern) $state ('<g transform="translate(128 178) scale(.6) translate(-128 -170)">'+(Chamber deposition 4 $pattern)+'</g>'+$(if($state -eq 'placed'){Mark solved})) @(-21,-11,42,22) @{pattern=$pattern;sealed=$true;intermediate_liquid=$false;supports_player=$false;frost_is_sample=$true;carry_fit_world=@(15,14)}}
 foreach($state in @('empty','wrong','committed')){
  $insert=if($state -eq 'committed'){'<g transform="translate(128 174) scale(.5) translate(-128 -180)">'+(Chamber deposition 4 $pattern)+'</g>'}else{'<g transform="translate(128 182) scale(.55 .4) translate(-128 -142)">'+(Frost 19 $pattern)+'</g>'}
  Asset ('gallery_slot_'+$pattern+'_'+$state) 'z3.frost_gallery' ('gallery_slot_'+$pattern) $state ((Tray 0)+$insert+(Mark $(if($state -eq 'committed'){'solved'}elseif($state -eq 'wrong'){'wrong'}else{''}))) @(-32,-14,64,28) @{pattern=$pattern;sealed=($state -eq 'committed');supports_player=$false;frost_is_sample=$true;science='empty/wrong show matching diagram; committed displays sealed holder, never traversable frost'}
 }
 Asset ('gallery_card_'+$pattern) 'z3.frost_gallery' ('gallery_card_'+$pattern) idle ((Path 'M89 126l69-5 17 83-70 9z' '#E5EADD')+'<g transform="translate(128 167) scale(.9) translate(-128 -142)">'+(Frost 21 $pattern)+'</g>') @(0,0,0,0) @{pattern=$pattern;supports_player=$false;frost_is_sample=$true;localized_observation='gas -> solid, heat leaves; optional pattern matching never awards new mastery'}
}
Asset interaction_selected 'z3.lab_environment' interaction selected (Mark selected) @(0,0,0,0) @{layer='overlay only'}
$taskCatalog=[ordered]@{schema_version=1;kit_id='phase-quest-r3-zone3-v1';status='R3 006 Implemented—needs verification; external acceptance pending';standard='docs/art/r3-prompt002/production-contract.json';source_builder='tools/art/zone3_v1/build_kit.ps1';coordinate_contract='2 source px/world unit, scale.5, camera1.55; new256x256/pivot128,208; large384x320/pivot192,264; existing preview128/pivot64,113';footprints='proposed visual placement only; no live physics/support';entries=$taskRows}
$taskCatalog|ConvertTo-Json -Depth 14|Set-Content (Join-Path $taskOut kit_catalog.json) -Encoding utf8
Write-Output ('R3 006 authored '+$taskRows.Count+' asset states')
