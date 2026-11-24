$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$taskOut=Join-Path $taskRoot 'assets/world/navigation/r3_v1'
New-Item -ItemType Directory -Force $taskOut|Out-Null
$taskEntries=@(foreach($taskState in @('locked','available','active')){
 $taskSymbol=switch($taskState){locked {'<rect x="57" y="39" width="14" height="14" rx="2" fill="#E9DFCA"/><path d="M60 39v-5a4 4 0 0 1 8 0v5" fill="none" stroke="#E9DFCA" stroke-width="3"/>'};available {'<path d="M64 31l10 14-10 14-10-14z" fill="#E9DFCA"/>'};active {'<path d="M53 44l8 8 16-18" fill="none" stroke="#F5E5AA" stroke-width="5"/>'}}
 $taskSvg=@"
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<ellipse cx="64" cy="110" rx="34" ry="9" fill="#23313B" opacity=".2"/>
<path d="M32 99l32-17 32 17-32 17z" fill="#788985" stroke="#35494B" stroke-width="2"/>
<path d="M39 91V71l25-13 25 13v20L64 105z" fill="#B3C1C2" stroke="#35494B" stroke-width="2"/>
<path d="M39 71l25 13 25-13-25-13z" fill="#D9DFD9" stroke="#35494B" stroke-width="2"/>
<path d="M64 84v21M64 59V19" stroke="#665141" stroke-width="6"/>
<path d="M44 23h40v42H44z" fill="#435C55" stroke="#E9DFCA" stroke-width="2"/>
$taskSymbol
</svg>
"@
 $taskPath='assets/world/navigation/r3_v1/checkpoint_'+$taskState+'.svg'
 $taskSvg|Set-Content -LiteralPath (Join-Path $taskRoot $taskPath) -Encoding utf8
 [ordered]@{id=('checkpoint_'+$taskState);state=$taskState;path=('res://'+$taskPath);pivot_px=@(64,110);source_size=@(128,128);world_scale=0.5;footprint_world=@(-16,-8,32,16);sorting='ground pivot; caller-owned elevation';collider='none; actual checkpoint provider owns interaction';license='Original project-authored SVG';source='tools/art/gate_a_v1/build.ps1';sha256=(Get-FileHash -LiteralPath (Join-Path $taskRoot $taskPath)).Hash}
})
[ordered]@{schema_version=1;owner='R3 013';entries=$taskEntries;consumers=@('Opt-in art review; later world checkpoint provider');retained=@('Zone1 shelter_cold/shelter_warm','HUD minimap/checkpoint vocabulary','Existing checkpoint statue scene and state providers');ambient=@{scene='Actors/World/RegionAmbientArt.tscn';source='Scripts/World/region_ambient_art.gd';biomes=@('snow','vale','lab');bounds_world=@(240,120);max_marks=24;reduced='zero optional marks; science material/drip/heater/device cues remain in their existing separate presenters';pause='freeze phase; no game outcome';license='Original project-authored GDScript'};status='Art coverage added; user/content/Android acceptance pending'}|ConvertTo-Json -Depth 9|Set-Content (Join-Path $taskOut 'catalog.json') -Encoding utf8
