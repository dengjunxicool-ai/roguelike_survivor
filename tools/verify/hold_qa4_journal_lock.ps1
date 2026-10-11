param(
    [Parameter(Mandatory=$true)][string]$Journal,
    [Parameter(Mandatory=$true)][string]$Root
)
$ErrorActionPreference = 'Stop'
$stream = [IO.File]::Open($Journal, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
try {
    Set-Content -LiteralPath "$Root/lock-ready" -Value 'locked' -Encoding utf8
    $until = (Get-Date).AddSeconds(25)
    while (-not (Test-Path -LiteralPath "$Root/release-lock") -and (Get-Date) -lt $until) {
        Start-Sleep -Milliseconds 50
    }
} finally {
    $stream.Dispose()
    Set-Content -LiteralPath "$Root/lock-released" -Value 'released' -Encoding utf8
}
