param(
    [string]$Script = '',
    [string]$Scene = '',
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [switch]$Rendered,
    [switch]$Import,
    [string[]]$UserArguments = @(),
    [string[]]$EngineArguments = @()
)
$ErrorActionPreference = 'Stop'
$outputPath = [System.IO.Path]::GetFullPath($OutputRoot).Replace('\','/').TrimEnd('/')
if (-not $outputPath.StartsWith('E:/codex/', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Isolated verification output must be under E:/codex'
}
$env:APPDATA = "$outputPath/appdata"
$env:LOCALAPPDATA = "$outputPath/localappdata"
$env:TEMP = "$outputPath/tmp"
$env:TMP = $env:TEMP
$env:__GL_SHADER_DISK_CACHE_PATH = "$outputPath/shader-cache"
$env:MESA_SHADER_CACHE_DIR = "$outputPath/shader-cache"
New-Item -ItemType Directory -Force -Path $outputPath,$env:APPDATA,$env:LOCALAPPDATA,$env:TEMP,$env:MESA_SHADER_CACHE_DIR | Out-Null
$godotArguments = @('--path', $ProjectPath) + $EngineArguments
if ($Import) { $godotArguments += @('--headless','--editor','--quit') }
else {
    if ($Script -eq '' -and $Scene -eq '') { throw 'A script or scene is required outside import mode' }
    if ($Scene -ne '') { $godotArguments += $Scene }
    else { $godotArguments += @('--script', $Script) }
    if ($Rendered) { $godotArguments += @('--resolution','1280x720','--disable-vsync','--rendering-method','mobile') }
    else { $godotArguments += '--headless' }
    if ($UserArguments.Count -gt 0) { $godotArguments += '--'; $godotArguments += $UserArguments }
}
# Invoke Godot directly from PowerShell, never through Node/npm.
$ErrorActionPreference = 'Continue'
$log = & 'D:/Godot/Godot_v4.6.3-stable_win64_console.exe' @godotArguments 2>&1
$exitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
$log | Out-File -LiteralPath "$outputPath/result.log" -Encoding utf8
$scriptErrors = @($log | Where-Object { "$_" -match 'SCRIPT ERROR:|Parse Error:|Compile Error:' })
$engineErrors = @($log | Where-Object { "$_" -match '^ERROR:' })
$result = [pscustomobject]@{exit_code=$exitCode; script_errors=$scriptErrors.Count; engine_errors=$engineErrors.Count; log="$outputPath/result.log"; project=$ProjectPath; script=$Script; rendered=[bool]$Rendered; arguments=$UserArguments}
$result | ConvertTo-Json -Depth 4 | Out-File -LiteralPath "$outputPath/result.json" -Encoding utf8
$log | Select-Object -Last 16 | Write-Output
Write-Output "GODOT exit=$exitCode script_errors=$($scriptErrors.Count) engine_errors=$($engineErrors.Count) log=$outputPath/result.log"
if ($exitCode -ne 0 -or $scriptErrors.Count -gt 0 -or $engineErrors.Count -gt 0) { exit 1 }
exit 0
