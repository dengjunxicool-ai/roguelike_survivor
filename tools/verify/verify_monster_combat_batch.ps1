$ErrorActionPreference='Stop'
. "$PSScriptRoot/run_monster_combat_shards.ps1"
$testRoot='E:/codex/monster-system/stage-d-guard-'+[guid]::NewGuid().ToString('N')
New-Item -ItemType Directory -Path $testRoot | Out-Null
$rejected=$false
try {Claim-MonsterCombatBatch $testRoot} catch {$rejected=$true}
if (-not $rejected) {throw 'Existing partial batch directory must be rejected'}
$fresh=$testRoot+'-fresh'
Claim-MonsterCombatBatch $fresh
$rejected=$false
try {Claim-MonsterCombatBatch $fresh} catch {$rejected=$true}
if (-not $rejected) {throw 'Second claim must be rejected'}
if (-not (Test-Path "$fresh.batch-lock")) {throw 'Atomic batch lock missing'}
Write-Output '[monster_combat_batch] PASS'
