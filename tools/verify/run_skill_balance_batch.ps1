param(
 [string]$ProjectPath='E:/codex/skill-rebalance/worktree',
 [Parameter(Mandatory=$true)][string]$OutputRoot,
 [ValidateSet('exploration','confirmation','fusion','outlier')][string]$Cohort='exploration',
 [ValidateSet('matrix','real')][string]$Mode='matrix',
 [int]$SeedLimit=0,
 [int]$WorkerIndex=-1,
 [int]$Throttle=4,
 [string]$Revision='unspecified'
)
$ErrorActionPreference='Stop'
$resolved=[IO.Path]::GetFullPath($OutputRoot).Replace('\','/')
if(-not $resolved.StartsWith('E:/codex/',[StringComparison]::OrdinalIgnoreCase)){throw 'OutputRoot must be E:/codex'}
$env:APPDATA="$resolved/appdata"; $env:LOCALAPPDATA="$resolved/localappdata"; $env:TEMP="$resolved/tmp"; $env:TMP=$env:TEMP
New-Item -ItemType Directory -Force -Path $resolved,$env:TEMP | Out-Null
if($WorkerIndex -ge 0){
 & "$ProjectPath/tools/verify/run_isolated_godot.ps1" -ProjectPath $ProjectPath -Script res://tools/verify/verify_skill_balance_matrix.gd -OutputRoot $resolved -EngineArguments @('--fixed-fps','60','--audio-driver','Dummy') -UserArguments @('--execute',"--mode=$Mode","--cohort=$Cohort","--seed-limit=$SeedLimit","--preset-start=$WorkerIndex",'--preset-limit=1',"--revision=$Revision")
 exit $LASTEXITCODE
}
$count=if($Cohort -in @('fusion','outlier')){15}else{18}
$script="$ProjectPath/tools/verify/run_skill_balance_batch.ps1"
$results=0..($count-1) | ForEach-Object -Parallel {
 $index=$_
 $dir="$($using:resolved)/case-$index"
 New-Item -ItemType Directory -Force -Path $dir | Out-Null
 $arguments=@('-NoProfile','-File',($using:script),'-ProjectPath',($using:ProjectPath),'-OutputRoot',$dir,'-Cohort',($using:Cohort),'-Mode',($using:Mode),'-SeedLimit',($using:SeedLimit),'-WorkerIndex',$index,'-Revision',($using:Revision))
 $p=Start-Process pwsh.exe -ArgumentList $arguments -WorkingDirectory ($using:ProjectPath) -WindowStyle Hidden -RedirectStandardOutput "$dir/cli.log" -RedirectStandardError "$dir/cli.err" -PassThru
 $p.WaitForExit()
 $p.Refresh()
 [pscustomobject]@{index=$index;exit_code=$p.ExitCode;path=$dir}
} -ThrottleLimit $Throttle
$results | Sort-Object index | ConvertTo-Json | Set-Content -LiteralPath "$resolved/batch.json" -Encoding utf8
$bad=@($results | Where-Object exit_code -ne 0)
Write-Output "BATCH cases=$($results.Count) failed=$($bad.Count) output=$resolved"
if($bad.Count -gt 0){exit 1}
