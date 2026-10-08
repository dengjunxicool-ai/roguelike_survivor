param(
    [string]$Batch = 'acceptance',
    [string[]]$Names = @()
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$outputRoot = "E:/codex/canonical-refactor/$Batch"
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$env:APPDATA = "$outputRoot/appdata"
$env:LOCALAPPDATA = "$outputRoot/localappdata"
$env:TEMP = "$outputRoot/tmp"
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA,$env:TEMP | Out-Null
Set-Location -LiteralPath $repo
$package = Get-Content -LiteralPath (Join-Path $repo 'package.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$results = @()
foreach ($entry in $package.scripts.PSObject.Properties) {
    if (-not $entry.Name.StartsWith('verify:')) { continue }
    if ($Names.Count -gt 0 -and $entry.Name -notin $Names) { continue }
    $arguments = $entry.Value -split '\s+'
    $executable = $arguments[0]
    $parameters = @($arguments | Select-Object -Skip 1)
    $logPath = Join-Path $outputRoot (($entry.Name -replace ':','_') + '.log')
    # Godot is launched directly by this PowerShell, never by Node/npm.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $log = & $executable @parameters 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    $log | Out-File -LiteralPath $logPath -Encoding UTF8
    $scriptErrors = @($log | Where-Object { "$_" -match 'SCRIPT ERROR:|Parse Error:|Compile Error:' })
    $passed = $exitCode -eq 0 -and $scriptErrors.Count -eq 0
    $results += [pscustomobject]@{name=$entry.Name; passed=$passed; exit_code=$exitCode; log=$logPath; script_errors=$scriptErrors.Count}
    if ($passed) { Write-Output "PASS $($entry.Name)" }
    else { Write-Output "FAIL $($entry.Name) exit=$exitCode script_errors=$($scriptErrors.Count)"; $log | Select-Object -Last 18 | Write-Output }
}
$results | ConvertTo-Json -Depth 4 | Out-File -LiteralPath (Join-Path $outputRoot 'results.json') -Encoding UTF8
$failed = @($results | Where-Object { -not $_.passed })
Write-Output "MATRIX: $($results.Count) checks, $($failed.Count) failures"
if ($failed.Count -gt 0) { exit 1 }
exit 0
