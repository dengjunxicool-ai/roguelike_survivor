param(
 [ValidateSet('combat-pair','flow-pilot','flow-matrix','performance','boss-render','map-render','hud-render')][string]$Mode,
 [string]$Batch='final',
 [ValidateSet('both','before','after')][string]$PerformanceVersion='both'
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$baseline='E:/codex/monster-system/stage-c-baseline'
$godot='D:/Godot/Godot_v4.6.3-stable_win64_console.exe'
$output="E:/codex/monster-system/stage-c-$Batch"
New-Item -ItemType Directory -Force -Path $output | Out-Null
$jobs=@()
switch($Mode){
 'combat-pair' {
  foreach($version in @('before','after')){$jobs+=@{name=$version;path=$(if($version -eq 'before'){$baseline}else{$repo});script='sample_monster_screening.gd';headless=$true;extra=@('--limit=1','--duration=300')}}
 }
 'flow-pilot' {$jobs+=@{name='flow-pilot';path=$repo;script='sample_monster_screening.gd';headless=$true;extra=@('--limit=2','--duration=300','--flow-assist','--disable-player-attack','--time-scale=16')}}
 'flow-matrix' {$jobs+=@{name='flow-matrix';path=$repo;script='sample_monster_screening.gd';headless=$true;extra=@('--limit=240','--duration=300','--flow-assist','--disable-player-attack','--time-scale=16')}}
 'performance' {
  $versions=if($PerformanceVersion -eq 'both'){@('before','after')}else{@($PerformanceVersion)}
  foreach($version in $versions){foreach($scenario in @('normal','boss')){
   $extra=@('--disable-player-attack','--survival-health=100000',"--duration=$(if($scenario -eq 'boss'){90}else{180})")
   if($scenario -eq 'boss'){$extra+='--boss-pressure'}
   $jobs+=@{name="$version-$scenario";path=$(if($version -eq 'before'){$baseline}else{$repo});script='sample_monster_performance.gd';headless=$false;extra=$extra}
  }}
 }
 'boss-render' {$jobs+=@{name='boss-render';path=$repo;script='capture_monster_stage_a.gd';headless=$false;extra=@()}}
 'map-render' {$jobs+=@{name='map-render';path=$repo;script='capture_monster_stage_c.gd';headless=$false;extra=@()}}
 'hud-render' {$jobs+=@{name='hud-render';path=$repo;script='capture_monster_stage_c_hud.gd';headless=$false;extra=@()}}
}
if($Mode -in @('combat-pair','performance')){
 foreach($driver in @('sample_monster_screening.gd','sample_monster_performance.gd')){Copy-Item -LiteralPath "$repo/tools/verify/$driver" -Destination "$baseline/tools/verify/$driver" -Force}
}
$manifest=@()
foreach($job in $jobs){
 $destination="$output/$($job.name)"
 New-Item -ItemType Directory -Force -Path $destination,"$destination/appdata","$destination/localappdata","$destination/tmp" | Out-Null
 $env:APPDATA="$destination/appdata"; $env:LOCALAPPDATA="$destination/localappdata"; $env:TEMP="$destination/tmp"; $env:TMP=$env:TEMP
 $arguments=@('--path',$job.path,'--script',"res://tools/verify/$($job.script)")
 if($job.headless){$arguments+=@('--headless','--fixed-fps','60')}else{$arguments+=@('--rendering-method','gl_compatibility','--resolution','1280x720')}
 $arguments+=@('--',"--report-dir=$destination",'--seed=618',"--revision=stage-c-$($job.name)")+ $job.extra
 Write-Output "START $($job.name)"
 $process=Start-Process -FilePath $godot -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput "$destination/stdout.log" -RedirectStandardError "$destination/stderr.log"
 $diagnostics=[string](Get-Content -LiteralPath "$destination/stderr.log" -Raw)
 $passed=$process.ExitCode -eq 0 -and $diagnostics -notmatch 'SCRIPT ERROR:|^ERROR:|Invalid DamagePacket'
 $manifest+=@{name=$job.name;exit_code=$process.ExitCode;passed=$passed;directory=$destination}
 Write-Output "END $($job.name) exit=$($process.ExitCode) passed=$passed"
 if(-not $passed){Get-Content -LiteralPath "$destination/stderr.log" -Tail 18}
 $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$output/manifest.json" -Encoding UTF8
}
if(@($manifest|Where-Object{-not $_.passed}).Count -gt 0){exit 1}
exit 0
