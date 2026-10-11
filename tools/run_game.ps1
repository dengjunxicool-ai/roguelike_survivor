param(
    [string]$GodotPath = 'D:/Godot/Godot_v4.6.3-stable_win64_console.exe',
    [string]$RuntimeRoot = 'E:/codex/roguelike-survivor',
    [string[]]$EngineArguments = @()
)
$ErrorActionPreference = 'Stop'
$runtimePath = [IO.Path]::GetFullPath($RuntimeRoot).Replace('\','/').TrimEnd('/')
if (-not $runtimePath.StartsWith('E:/codex/', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Game saves and caches must be stored under E:/codex.'
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}
$env:APPDATA = "$runtimePath/appdata"
$env:LOCALAPPDATA = "$runtimePath/localappdata"
$env:TEMP = "$runtimePath/tmp"
$env:TMP = $env:TEMP
$env:__GL_SHADER_DISK_CACHE_PATH = "$runtimePath/shader-cache"
$env:MESA_SHADER_CACHE_DIR = "$runtimePath/shader-cache"
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA,$env:TEMP,$env:MESA_SHADER_CACHE_DIR | Out-Null
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
# Run as an independent game window: embedding in the editor blocks fullscreen.
& $GodotPath --path $projectPath @EngineArguments
exit $LASTEXITCODE
