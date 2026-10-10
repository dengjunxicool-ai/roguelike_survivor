function Get-QaRunStatus {
    param([int]$ProcessExitCode, [bool]$TimedOut, [string]$ResultPath)
    $runtime = $null
    if (Test-Path -LiteralPath $ResultPath) {
        try { $runtime = Get-Content -LiteralPath $ResultPath -Raw | ConvertFrom-Json } catch { $runtime = $null }
    }
    $valid = $null -ne $runtime -and $runtime.PSObject.Properties.Name -contains 'exit_code' -and $runtime.PSObject.Properties.Name -contains 'script_errors' -and $runtime.PSObject.Properties.Name -contains 'engine_errors'
    $passed = -not $TimedOut -and $ProcessExitCode -eq 0 -and $valid -and $runtime.exit_code -eq 0 -and $runtime.script_errors -eq 0 -and $runtime.engine_errors -eq 0
    [pscustomobject]@{
        passed = $passed
        exit_code = $(if ($TimedOut) { 124 } elseif ($passed) { 0 } else { 1 })
        process_exit_code = $ProcessExitCode
        timeout = $TimedOut
        result_valid = $valid
        runtime = $runtime
    }
}
