$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$taskDocs=Join-Path $taskRoot 'docs/art/r3-prompt011'
$taskReview=Join-Path $taskDocs review
$taskEngine=Join-Path $taskRoot '.godot/prompt001-audit/Godot_v4.7-stable_win64_console.exe'
& (Join-Path $taskDocs 'stage.ps1') -BuildOnly
$taskOldApp=$env:APPDATA;$taskOldLocal=$env:LOCALAPPDATA
try{
 $env:APPDATA=Join-Path $taskReview local-user;$env:LOCALAPPDATA=Join-Path $env:APPDATA local
 & $taskEngine --headless --editor --path $taskReview --quit --log-file (Join-Path $taskDocs build-import.log) *> (Join-Path $taskDocs build-import-console.log)
 if($LASTEXITCODE){throw 'Isolated source import failed'}
 & $taskEngine --path $taskReview --script res://tools/art/menu_r3_v1/build_assets.gd --rendering-method gl_compatibility --quit-after 7200 --log-file (Join-Path $taskDocs build.log) *> (Join-Path $taskDocs build-console.log)
 Get-Content -LiteralPath (Join-Path $taskDocs build-console.log) -Tail 14
 if($LASTEXITCODE -or (Get-Content -LiteralPath (Join-Path $taskDocs build.log) -Raw) -notmatch 'R3 011 BUILD PASS'){throw 'Menu asset build failed'}
 foreach($taskFile in Get-ChildItem -LiteralPath (Join-Path $taskReview 'assets/ui/main_menu/r3_v1') -File|Where-Object {$_.Extension -in @('.png','.json') -and $_.Name -ne 'catalog.json'}){Copy-Item -LiteralPath $taskFile.FullName -Destination (Join-Path $taskRoot ('assets/ui/main_menu/r3_v1/'+$taskFile.Name)) -Force}
}finally{$env:APPDATA=$taskOldApp;$env:LOCALAPPDATA=$taskOldLocal}
