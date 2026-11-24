$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$taskOut=Join-Path $taskRoot 'assets/ui/hud/r3_v1'
$taskArt=[ordered]@{
 'circle_frame'='<circle cx="64" cy="66" r="59" fill="#101b19" opacity=".35"/><circle cx="64" cy="64" r="58" fill="url(#glass)" stroke="#23332a" stroke-width="5"/><circle cx="64" cy="64" r="56" fill="none" stroke="#e8e9d7" stroke-width="2"/><circle cx="64" cy="64" r="51" fill="none" stroke="#869b7a" stroke-width="1"/><path d="M21 35A52 52 0 0 1 104 34" fill="none" stroke="#fffceb" stroke-width="2" opacity=".45"/>'
 'hex_frame'='<path d="M64 5 115 34 115 94 64 123 13 94 13 34Z" fill="#18271f" stroke="#142018" stroke-width="7"/><path d="M64 5 115 34 115 94 64 123 13 94 13 34Z" fill="url(#glass)" stroke="#ecdfb5" stroke-width="3"/><path d="M64 13 108 38 108 90 64 115 20 90 20 38Z" fill="none" stroke="#9caa87" stroke-width="1"/>'
 'guides'='<path d="M19 28Q39 20 61 31V98Q39 86 19 93ZM109 28Q89 20 67 31V98Q89 86 109 93Z"/><path d="M28 40Q41 36 51 41M28 51Q41 47 51 52M77 41Q90 36 101 40M77 52Q90 47 101 51" fill="none" stroke="#52654c" stroke-width="3"/>'
 'pause'='<rect x="32" y="24" width="21" height="80" rx="6"/><rect x="75" y="24" width="21" height="80" rx="6"/>'
 'jump'='<path d="M64 15 106 60H80V109H48V60H22Z"/>'
 'interact'='<path d="M44 63V28Q44 17 52 17T60 28V53 20Q60 10 68 10T76 20V55 29Q76 20 84 20T92 29V67 48Q92 40 100 40T108 48V80Q106 106 83 115H55L23 79Q15 68 24 63T44 75Z"/>'
 'warning'='<path d="M64 15 117 111H11Z" fill="none" stroke="#f5d97f" stroke-width="9"/><path d="M64 43V75" stroke="#f5d97f" stroke-width="10"/><circle cx="64" cy="93" r="6" fill="#f5d97f"/>'
 'lock'='<rect x="29" y="55" width="70" height="58" rx="9"/><path d="M42 55V34A22 22 0 0 1 86 34V55" fill="none" stroke="#fff5d8" stroke-width="10"/><circle cx="64" cy="77" r="7" fill="#33453a"/><path d="M64 80V95" stroke="#33453a" stroke-width="5"/>'
 'player_marker'='<path d="M64 12 103 108 64 88 25 108Z" fill="#edc7ee" stroke="#fff9eb" stroke-width="7"/>'
}
foreach($taskKey in $taskArt.Keys){
 $taskSvg='<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><defs><linearGradient id="glass" x2="0" y2="1"><stop stop-color="#e7efd2" stop-opacity=".16"/><stop offset=".5" stop-color="#28432a" stop-opacity=".18"/><stop offset="1" stop-color="#162d1e" stop-opacity=".48"/></linearGradient></defs><g fill="#fff5d8" stroke-linecap="round" stroke-linejoin="round">'+$taskArt[$taskKey]+'</g></svg>'
 [IO.File]::WriteAllText((Join-Path $taskOut ($taskKey+'.svg')),$taskSvg,[Text.UTF8Encoding]::new($false))
}
Write-Output ('R3 009 / '+$taskArt.Count+' original editable SVG assets; existing mode/run/portrait/font sources retained')
