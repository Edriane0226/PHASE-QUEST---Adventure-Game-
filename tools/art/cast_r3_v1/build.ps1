$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
& (Join-Path $taskRoot 'docs/art/r3-prompt007/run-review.ps1') -BuildOnly
