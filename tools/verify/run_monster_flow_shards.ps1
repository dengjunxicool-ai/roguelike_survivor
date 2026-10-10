param([string]$Batch='flow-shards-final',[int]$Limit=60,[int]$Offset=0)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$output="E:/codex/monster-system/stage-c-$Batch"
$tasks=@()
foreach($index in 0..3){
 $destination="$output/shard-$index"
 New-Item -ItemType Directory -Force -Path $destination,"$destination/appdata","$destination/localappdata","$destination/tmp" | Out-Null
 $env:APPDATA="$destination/appdata"; $env:LOCALAPPDATA="$destination/localappdata"; $env:TEMP="$destination/tmp"; $env:TMP=$env:TEMP
 $arguments=@('--path',$repo,'--script','res://tools/verify/sample_monster_screening.gd','--headless','--fixed-fps','60','--',"--report-dir=$destination",'--seed=618',"--limit=$Limit","--start-index=$($index*60+$Offset)",'--duration=300','--flow-assist','--disable-player-attack','--time-scale=16')
 $process=Start-Process -FilePath 'D:/Godot/Godot_v4.6.3-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$destination/stdout.log" -RedirectStandardError "$destination/stderr.log"
 $tasks+=@{process=$process;directory=$destination;index=$index}
 Write-Output "START shard=$index pid=$($process.Id)"
}
$manifest=@()
foreach($task in $tasks){
 $task.process.WaitForExit(); $task.process.Refresh()
 $diagnostics=[string](Get-Content -LiteralPath "$($task.directory)/stderr.log" -Raw)
 $passed=$task.process.ExitCode -eq 0 -and $diagnostics -notmatch 'SCRIPT ERROR:|ERROR:|Invalid DamagePacket'
 $manifest+=@{shard=$task.index;exit_code=$task.process.ExitCode;passed=$passed;directory=$task.directory}
 Write-Output "END shard=$($task.index) exit=$($task.process.ExitCode) passed=$passed"
}
$manifest|ConvertTo-Json -Depth 4|Set-Content -LiteralPath "$output/manifest.json" -Encoding UTF8
if(@($manifest|Where-Object{-not $_.passed}).Count -gt 0){exit 1}
exit 0
