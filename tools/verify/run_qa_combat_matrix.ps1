param(
    [Parameter(Mandatory=$true)][string]$OutputRoot,
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [int[]]$Indices = @(0,15,30,45,60,75,90,105,120,135,150,165,180,195,210,225),
    [int]$SeedOffset = 700,
    [int]$Duration = 300,
    [int]$TimeoutSeconds = 360
)
$ErrorActionPreference = 'Stop'
$qaRoot = [IO.Path]::GetFullPath($OutputRoot).Replace('\','/').TrimEnd('/')
if (-not $qaRoot.StartsWith('E:/codex/',[StringComparison]::OrdinalIgnoreCase)) { throw 'QA output must be under E:/codex' }
if (Test-Path -LiteralPath $qaRoot) { throw 'Use a fresh output directory to prevent stale results' }
if ($Indices.Count -eq 0 -or @($Indices | Where-Object { $_ -lt 0 -or $_ -gt 239 }).Count -gt 0) { throw 'Invalid matrix indices' }
if ($Duration -le 0 -or $TimeoutSeconds -le 0) { throw 'Duration and timeout must be positive' }
New-Item -ItemType Directory -Path $qaRoot | Out-Null
$project = (Resolve-Path -LiteralPath $ProjectPath).Path.Replace('\','/')
$wrapper = "$PSScriptRoot/run_isolated_godot.ps1"
$statusHelper = "$PSScriptRoot/qa_run_status.ps1"
$revision = (& git -C $project rev-parse --short HEAD)
$records = $Indices | Sort-Object -Unique | ForEach-Object -Parallel {
    $index = $_
    $dir = ($using:qaRoot) + "/case-$index"
    New-Item -ItemType Directory -Path $dir | Out-Null
    function Quote-Ps([string]$value) { "'" + $value.Replace("'","''") + "'" }
    $argsLiteral = @("--report-dir=$dir/data",'--limit=1',"--start-index=$index","--seed-offset=$using:SeedOffset","--duration=$using:Duration","--revision=$using:revision") | ForEach-Object { Quote-Ps $_ }
    $launcher = '& ' + (Quote-Ps $using:wrapper) + ' -ProjectPath ' + (Quote-Ps $using:project) + ' -OutputRoot ' + (Quote-Ps $dir) + ' -Script res://tools/verify/sample_monster_combat.gd -EngineArguments @(''--fixed-fps'',''60'',''--audio-driver'',''Dummy'') -UserArguments @(' + ($argsLiteral -join ',') + ")`r`n" + 'exit $LASTEXITCODE' + "`r`n"
    $launcher | Set-Content -LiteralPath "$dir/launch.ps1" -Encoding utf8
    $process = Start-Process powershell.exe -ArgumentList @('-NoProfile','-NonInteractive','-File',"$dir/launch.ps1") -WorkingDirectory $using:project -WindowStyle Hidden -PassThru -RedirectStandardOutput "$dir/stdout.log" -RedirectStandardError "$dir/stderr.log"
    $timedOut = -not $process.WaitForExit(($using:TimeoutSeconds) * 1000)
    if ($timedOut) {
        $all = Get-CimInstance Win32_Process
        $ids = [Collections.Generic.List[int]]::new()
        $ids.Add($process.Id)
        for ($i=0; $i -lt $ids.Count; $i++) { foreach ($child in $all | Where-Object ParentProcessId -eq $ids[$i]) { $ids.Add([int]$child.ProcessId) } }
        for ($i=$ids.Count-1; $i -ge 0; $i--) { Stop-Process -Id $ids[$i] -Force -ErrorAction SilentlyContinue }
    }
    $process.Refresh()
    . $using:statusHelper
    $outerExit = if ($timedOut) { 124 } else { $process.ExitCode }
    $status = Get-QaRunStatus -ProcessExitCode $outerExit -TimedOut $timedOut -ResultPath "$dir/result.json"
    [pscustomobject]@{index=$index; exit_code=$status.exit_code; passed=$status.passed; timeout=$timedOut; process_exit=$outerExit; runtime_exit=$status.runtime.exit_code; result_valid=$status.result_valid; output=$dir}
} -ThrottleLimit 4
$records | Sort-Object index | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$qaRoot/results.json" -Encoding utf8
$records | Sort-Object index | Format-Table
Write-Output "QA matrix passed=$(@($records | Where-Object passed).Count)/$($records.Count) report=$qaRoot/results.json"
if (@($records | Where-Object { -not $_.passed }).Count -gt 0) { exit 1 }
exit 0
