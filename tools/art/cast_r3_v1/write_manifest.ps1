$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$taskOut=Join-Path $taskRoot 'assets/characters/professors/r3_v1'
Add-Type -AssemblyName System.Drawing
$taskSourceFiles=@(Get-ChildItem $PSScriptRoot -Filter '*-source.png')
$taskProductFiles=@(Get-ChildItem $taskOut -Recurse -File|Where-Object {$_.Extension -in @('.png','.tres','.json') -and $_.Name -ne 'production-manifest.json'})
$taskRows=@(foreach($taskFile in $taskSourceFiles+$taskProductFiles){
 $taskRecord=[ordered]@{path=[IO.Path]::GetRelativePath($taskRoot,$taskFile.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $taskFile.FullName -Algorithm SHA256).Hash;bytes=$taskFile.Length;kind=$(if($taskFile.DirectoryName -eq $PSScriptRoot){'generated_source'}else{'production_export'})}
 if($taskFile.Extension -eq '.png'){$taskImage=[Drawing.Image]::FromFile($taskFile.FullName);try{$taskRecord.dimensions=@($taskImage.Width,$taskImage.Height)}finally{$taskImage.Dispose()}}
 $taskRecord
})
[ordered]@{schema_version=1;owner='R3 007';registry='assets/characters/professors/r3_v1/cast_registry.json';source_provenance='tools/art/cast_r3_v1/generation.md';producer='docs/art/r3-prompt007/review/build_cast.gd';consumer='Actors/Characters/CastActor.tscn opt-in; future world/dialogue consumers remain Priority3';dependencies=@('R3 002 measured character contract','existing original cast/device resources','six original generated inputs');retirement_eligible=$false;review_status='Implemented—needs verification; external approval pending';files=$taskRows}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $taskOut 'production-manifest.json') -Encoding utf8
Write-Output ('R3 007 production manifest / '+$taskSourceFiles.Count+' sources / '+$taskProductFiles.Count+' exports')
