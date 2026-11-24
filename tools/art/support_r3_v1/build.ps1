$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$taskDocs=Join-Path $taskRoot 'docs/art/r3-prompt010'
& (Join-Path $taskDocs 'stage.ps1') -ContentOnly
$taskEngine=Join-Path $taskRoot '.godot/prompt001-audit/Godot_v4.7-stable_win64_console.exe'
$taskReview=Join-Path $taskDocs review
$taskOldApp=$env:APPDATA;$taskOldLocal=$env:LOCALAPPDATA
try{
 $env:APPDATA=Join-Path $taskReview local-user;$env:LOCALAPPDATA=Join-Path $env:APPDATA local
 & $taskEngine --headless --path $taskReview --script res://tools/art/support_r3_v1/build_content.gd --log-file (Join-Path $taskDocs build.log) *> (Join-Path $taskDocs build-console.log)
 Get-Content -LiteralPath (Join-Path $taskDocs build-console.log) -Tail 14
 if($LASTEXITCODE -or (Get-Content -LiteralPath (Join-Path $taskDocs build.log) -Raw) -notmatch 'R3 010 CONTENT /'){throw 'Support content export failed'}
 foreach($taskName in @('panels.json','portrait-index.json','retained-content.json')){Copy-Item -LiteralPath (Join-Path $taskReview ('assets/ui/support/r3_v1/'+$taskName)) -Destination (Join-Path $taskRoot ('assets/ui/support/r3_v1/'+$taskName)) -Force}
}finally{$env:APPDATA=$taskOldApp;$env:LOCALAPPDATA=$taskOldLocal}
