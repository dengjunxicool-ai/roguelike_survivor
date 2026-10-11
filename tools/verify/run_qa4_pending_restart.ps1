param(
    [Parameter(Mandatory=$true)][string]$OutputRoot,
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [switch]$LockOnly
)
$ErrorActionPreference = 'Stop'
$qaRoot = [IO.Path]::GetFullPath($OutputRoot).Replace('\','/').TrimEnd('/')
if (-not $qaRoot.StartsWith('E:/codex/', [StringComparison]::OrdinalIgnoreCase)) { throw 'OutputRoot must be under E:/codex' }
if (Test-Path -LiteralPath $qaRoot) { throw 'Use a fresh output directory' }
New-Item -ItemType Directory -Path $qaRoot | Out-Null
$results = @()

function Run-Phase([string]$scenario, [string]$phase) {
    $scenarioRoot = "$qaRoot/$scenario"
    $output = & "$PSScriptRoot/run_isolated_godot.ps1" -ProjectPath $ProjectPath -OutputRoot $scenarioRoot -Script res://tools/verify/verify_qa4_persistence.gd -EngineArguments @('--fixed-fps','60','--audio-driver','Dummy') -UserArguments @("--phase=$phase", "--evidence-dir=$scenarioRoot")
    $runnerExit = $LASTEXITCODE
    $result = Get-Content -LiteralPath "$scenarioRoot/result.json" -Raw | ConvertFrom-Json
    Copy-Item -LiteralPath "$scenarioRoot/result.log" -Destination "$scenarioRoot/$phase.log"
    $passed = $runnerExit -eq 0 -and $result.exit_code -eq 0 -and $result.script_errors -eq 0 -and $result.engine_errors -eq 0
    $script:results += [pscustomobject]@{scenario=$scenario;phase=$phase;passed=$passed;exit_code=$result.exit_code;script_errors=$result.script_errors;engine_errors=$result.engine_errors;log="$scenarioRoot/$phase.log"}
    $script:results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$qaRoot/results.json" -Encoding utf8
    Write-Output "QA4 $scenario/$phase passed=$passed"
    if (-not $passed) {
        $output | Select-Object -Last 12 | Write-Output
        throw "QA4 persistence phase failed: $scenario/$phase"
    }
}

if (-not $LockOnly) {
    foreach ($phase in @('missing-local','legacy-missing-writable','summary-order','legacy-future-summary','receipt-errors','new-user','new-user-failed-first','settings-economy','normal-save-with-pending','reset-with-stage')) {
        Run-Phase $phase $phase
    }
    foreach ($scenario in @(
    @{name='missing-restart'; phases=@('missing-prepare','missing-recover')},
    @{name='deleted-restart'; phases=@('deleted-prepare','missing-recover')},
    @{name='new-user-failed-restart'; phases=@('new-user-failed-prepare','new-user-failed-recover')},
    @{name='new-user-base-restart'; phases=@('new-user-base-prepare','new-user-base-recover')},
    @{name='old-journal-restart'; phases=@('old-journal-prepare','old-journal-recover')},
    @{name='staged-first-save-restart'; phases=@('staged-first-save-prepare','staged-first-save-recover')},
    @{name='staged-finalize-restart'; phases=@('staged-finalize-prepare','staged-finalize-recover')},
    @{name='staged-main-moved-restart'; phases=@('staged-main-moved-prepare','staged-main-moved-recover')},
    @{name='stage-write-failure-restart'; phases=@('stage-write-failure-prepare','stage-write-failure-recover')},
    @{name='journal-restart'; phases=@('journal-prepare','journal-recover','journal-replay')},
    @{name='summary-restart'; phases=@('summary-prepare','summary-recover')},
    @{name='reset-restart'; phases=@('reset-prepare','reset-recover')},
    @{name='partial-restart'; phases=@('partial-prepare','partial-recover')}
    )) {
        foreach ($phase in $scenario.phases) { Run-Phase $scenario.name $phase }
    }
}

$lockRoot = "$qaRoot/journal-lock-restart"
Run-Phase 'journal-lock-restart' 'journal-lock-prepare'
$journal = Get-ChildItem -LiteralPath "$lockRoot/appdata" -Recurse -Filter pending_rewards.cfg | Select-Object -First 1 -ExpandProperty FullName
if (-not $journal) { throw 'Journal fixture missing before lock test' }
$env:APPDATA = "$lockRoot/appdata"
$env:LOCALAPPDATA = "$lockRoot/localappdata"
$env:TEMP = "$lockRoot/tmp"
$env:TMP = $env:TEMP
$helper = Start-Process -FilePath (Join-Path $PSHOME 'pwsh.exe') -WindowStyle Hidden -PassThru -ArgumentList @('-NoProfile','-File',"$PSScriptRoot/hold_qa4_journal_lock.ps1",'-Journal',$journal,'-Root',$lockRoot)
try {
    $until = (Get-Date).AddSeconds(10)
    while (-not (Test-Path -LiteralPath "$lockRoot/lock-ready") -and (Get-Date) -lt $until) { Start-Sleep -Milliseconds 50 }
    if (-not (Test-Path -LiteralPath "$lockRoot/lock-ready")) { throw 'Exclusive lock helper did not start' }
    Run-Phase 'journal-lock-restart' 'journal-lock-recover'
    $helper.WaitForExit(1000) | Out-Null
    Run-Phase 'journal-lock-restart' 'journal-replay'
} finally {
    if (-not $helper.HasExited) {
        Set-Content -LiteralPath "$lockRoot/release-lock" -Value 'release' -Encoding utf8
        $helper.WaitForExit(2000) | Out-Null
    }
}
Write-Output "QA4 persistence phases passed=$($results.Count)/$($results.Count) report=$qaRoot/results.json"
