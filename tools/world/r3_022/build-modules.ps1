$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$out=Join-Path $root 'assets/world/modular_v1'
New-Item -ItemType Directory -Force $out|Out-Null
$entries=@()
$palettes=@(
 @{id='snow';owner='004';wall='#9a7761';shade='#755e52';floor='#e2ebe5';roof='#b9cbd0';accent='#c9a66c'},
 @{id='vale';owner='005';wall='#9fbeb0';shade='#6d9387';floor='#c1c8a0';roof='#85aaa0';accent='#d8b880'},
 @{id='lab';owner='006';wall='#b4c6cc';shade='#819aa6';floor='#bdccd0';roof='#7797ac';accent='#d0ae71'}
)
foreach($p in $palettes){
 foreach($kind in @('floor','wall_u','wall_v','window_u','window_v','door_v','roof')){
  $id="$($p.id).$kind";$parts=@();$width=1;$depth=1;$height=3
  switch($kind){
   'floor' {$height=0;$parts+=('<path fill="'+$p.floor+'" d="M32 96 52 106 32 116 12 106Z"/>');$parts+=('<path fill="'+$p.shade+'" opacity=".18" d="M32 96 34 97 14 107 12 106Z"/>')}
   'roof' {$height=0;$parts+=('<path fill="'+$p.roof+'" d="M32 96 52 106 32 116 12 106Z"/>');$parts+=('<path fill="'+$p.wall+'" opacity=".22" d="M32 96 52 106 50 107 30 97Z"/>')}
   'door_v' {$width=.15;$depth=3;$parts+=('<path fill="'+$p.shade+'" d="M32 96 28 98 28 38 -24 64 -24 124 -28 126 -28 66 -28 56 32 26Z"/>');$parts+=('<path fill="'+$p.accent+'" d="M32 26 -28 56 -28 66 32 36Z"/>')}
   default {
    $isU=$kind.EndsWith('_u');$width=if($isU){1}else{.15};$depth=if($isU){.15}else{1}
    $edge=if($isU){'32 96 52 106 52 46 32 36Z'}else{'32 96 12 106 12 46 32 36Z'}
    $parts+=('<path fill="'+$(if($isU){$p.wall}else{$p.shade})+'" d="M'+$edge+'"/>')
    $parts+=('<path fill="'+$p.accent+'" opacity=".75" d="M'+$(if($isU){'32 37 52 47 52 50 32 40Z'}else{'32 37 12 47 12 50 32 40Z'})+'"/>')
    if($kind.StartsWith('window')){$parts+=('<path fill="#cce8e5" d="M'+$(if($isU){'35 50 49 57 49 76 35 69Z'}else{'29 50 15 57 15 76 29 69Z'})+'"/>')}
   }
  }
  # Door has wider left padding; common logical origin remains (32,96) in viewBox.
  $svg='<svg xmlns="http://www.w3.org/2000/svg" width="96" height="128" viewBox="-32 0 96 128">'+($parts -join '')+'</svg>'
  if($kind -in @('floor','roof')){$width=1;$depth=1}
  elseif($kind -eq 'door_v'){$width=0.225;$depth=3}
  elseif($kind.EndsWith('_v')){$width=0.225;$depth=1}
  else{$width=1;$depth=0.225}
  $path=Join-Path $out "$id.svg";[IO.File]::WriteAllText($path,$svg)
  $entries+=@{id=$id;path="res://assets/world/modular_v1/$id.svg";owner="R3 $($p.owner) scoped 022 correction";footprint_cubes=@($width,$depth);height_layers=$height;pivot_px=@(64,96);world_scale=1;assembly_offset_cubes=@(0,0,3*([int]($kind -eq 'roof')));overhang_cubes=0;collision=$(if($kind -match 'wall|window'){'independent ground segment; layer1, Fire1|2|8'}elseif($kind -eq 'door_v'){'posts only; supported open three-cell threshold'}else{'none; existing stacked terrain owns support'});sorting='ground midpoint; art-only elevation; floor z=-1, roof z=2';sha256=(Get-FileHash $path).Hash}
 }
}
@{version=1;cube_unit_px=20;cap_px=@(40,20);rise_px=20;source='tools/world/r3_022/build-modules.ps1';license='Original project-authored editable SVG geometry';entries=$entries}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $out catalog.json)
Write-Output "$($entries.Count) separate editable building modules generated."
