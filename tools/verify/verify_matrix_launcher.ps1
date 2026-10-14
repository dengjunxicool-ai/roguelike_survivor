$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$fixtureName = [Guid]::NewGuid().ToString('N')
$fixtureRoot = "E:/codex/playtest-fixes-20261015/matrix-fixtures/$fixtureName"
$batch = "playtest-matrix-negative-$fixtureName"
New-Item -ItemType Directory -Force -Path "$fixtureRoot/tools/verify" | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'run_verification_matrix.ps1') -Destination "$fixtureRoot/tools/verify/run_verification_matrix.ps1"
@{ scripts = [ordered]@{
    'verify:successful-launch' = 'node -e process.exit(0)'
    'verify:missing-launch' = 'missing_playtest_verifier_executable_20261015'
} } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$fixtureRoot/package.json" -Encoding utf8
$shellPath = (Get-Command pwsh -ErrorAction Stop).Source
$process = Start-Process -FilePath $shellPath -ArgumentList @('-NoProfile','-File',"$fixtureRoot/tools/verify/run_verification_matrix.ps1",'-Batch',$batch) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput "$fixtureRoot/output.log" -RedirectStandardError "$fixtureRoot/error.log"
$results = @(Get-Content -Raw -LiteralPath "E:/codex/canonical-refactor/$batch/results.json" | ConvertFrom-Json)
if ($process.ExitCode -ne 1 -or $results.Count -ne 2 -or -not $results[0].passed -or $results[1].passed -or $results[1].exit_code -ne -1) {
    throw 'Verifier launch failure incorrectly inherits a previous successful exit code.'
}
Write-Output 'PASS matrix reports a launch failure after a successful verifier as failure, exit -1'
exit 0
