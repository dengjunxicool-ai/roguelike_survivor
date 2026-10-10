param([ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Batch='final',[ValidateRange(1,60)][int]$Limit=60,[ValidateRange(0,59)][int]$Offset=0,[ValidateRange(0,100)][int]$SeedOffset=0,[ValidateRange(0,3)][int[]]$Shards=@(0,1,2,3))
function Claim-MonsterCombatBatch([string]$OutputPath) {
    $resolved=[System.IO.Path]::GetFullPath($OutputPath).Replace('\','/')
    if (-not $resolved.StartsWith('E:/codex/',[System.StringComparison]::OrdinalIgnoreCase)) {throw 'Batch must be under E:/codex'}
    if (Test-Path $resolved) {throw 'Use a fresh batch name; preserving all existing evidence'}
    # CreateNew is atomic: a competing launcher cannot acquire the same batch.
    $claim=[System.IO.File]::Open("$resolved.batch-lock",[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::Write,[System.IO.FileShare]::None)
    $claim.Dispose()
    New-Item -ItemType Directory -Path $resolved | Out-Null
}
if ($MyInvocation.InvocationName -eq '.') {return}
$ErrorActionPreference='Stop'
if ($Offset+$Limit -gt 60) {throw 'Offset and limit must stay within each character block'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$output="E:/codex/monster-system/stage-d-$Batch"
$tasks=@()
Claim-MonsterCombatBatch $output
foreach ($index in ($Shards | Select-Object -Unique)) {
    $destination="$output/shard-$index"
    $env:APPDATA="$destination/appdata"
    $env:LOCALAPPDATA="$destination/localappdata"
    $env:TEMP="$destination/tmp"
    $env:TMP=$env:TEMP
    New-Item -ItemType Directory -Force $destination,$env:APPDATA,$env:LOCALAPPDATA,$env:TEMP | Out-Null
    $arguments=@('--path',$repo,'--script','res://tools/verify/sample_monster_combat.gd','--headless','--fixed-fps','60','--',"--report-dir=$destination",'--seed=618',"--limit=$Limit","--start-index=$($index*60+$Offset)","--seed-offset=$SeedOffset",'--duration=300')
    $process=Start-Process 'D:/Godot/Godot_v4.6.3-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$destination/stdout.log" -RedirectStandardError "$destination/stderr.log"
    $tasks+=@{process=$process;output=$destination}
}
$manifest=@()
foreach ($task in $tasks) {
    $task.process.WaitForExit()
    $task.process.Refresh()
    $errors=[string](Get-Content "$($task.output)/stderr.log" -Raw)
    $hasReport=Test-Path "$($task.output)/screening.json"
    $caseCount=0
    if ($hasReport) {$caseCount=@((Get-Content "$($task.output)/screening.json" -Raw | ConvertFrom-Json).cases).Count}
    $passed=$task.process.ExitCode -eq 0 -and $errors -notmatch 'SCRIPT ERROR:|ERROR:|InvalidDamagePacket' -and $caseCount -eq $Limit
    $manifest+=@{output=$task.output;passed=$passed;exit_code=$task.process.ExitCode}
    Write-Output "$($task.output) exit=$($task.process.ExitCode) passed=$passed"
}
$manifest | ConvertTo-Json -Depth 5 | Out-File "$output/manifest.json" -Encoding utf8
if (@($manifest | Where-Object {-not $_.passed}).Count -gt 0) {exit 1}
