param(
    [Parameter(Mandatory=$true)][string]$OutputRoot,
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)
$ErrorActionPreference = 'Stop'
$qaRoot = [IO.Path]::GetFullPath($OutputRoot).Replace('\','/').TrimEnd('/')
if (-not $qaRoot.StartsWith('E:/codex/',[StringComparison]::OrdinalIgnoreCase)) { throw 'OutputRoot must be under E:/codex' }
if (Test-Path -LiteralPath $qaRoot) { throw 'Use a fresh output directory to prevent stale restart fixtures' }
New-Item -ItemType Directory -Path $qaRoot | Out-Null
$results = @()
foreach ($scenario in @(
    @{name='cleanup-replay'; phases=@('prepare','recover','replay')},
    @{name='unreadable-main'; phases=@('prepare-unreadable','recover-unreadable')}
)) {
    $scenarioRoot = "$qaRoot/$($scenario.name)"
    foreach ($phase in $scenario.phases) {
        # Reuse userdata between actual Godot processes, retain each phase's evidence separately.
        & "$PSScriptRoot/run_isolated_godot.ps1" -ProjectPath $ProjectPath -OutputRoot $scenarioRoot -Script res://tools/verify/verify_qa3_pending_lifecycle.gd -EngineArguments @('--fixed-fps','60','--audio-driver','Dummy') -UserArguments @("--phase=$phase")
        $result = Get-Content -LiteralPath "$scenarioRoot/result.json" -Raw | ConvertFrom-Json
        Copy-Item -LiteralPath "$scenarioRoot/result.log" -Destination "$scenarioRoot/$phase.log"
        $passed = $result.exit_code -eq 0 -and $result.script_errors -eq 0 -and $result.engine_errors -eq 0
        $results += [pscustomobject]@{scenario=$scenario.name;phase=$phase;passed=$passed;exit_code=$result.exit_code;script_errors=$result.script_errors;engine_errors=$result.engine_errors;log="$scenarioRoot/$phase.log"}
        $results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$qaRoot/results.json" -Encoding utf8
        if (-not $passed) { throw "Restart verification failed: $($scenario.name) / $phase" }
    }
}
Write-Output "QA3 restart phases passed=$($results.Count)/$($results.Count) report=$qaRoot/results.json"
