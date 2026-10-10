param([Parameter(Mandatory=$true)][string]$OutputRoot)
$ErrorActionPreference = 'Stop'
$path = [IO.Path]::GetFullPath($OutputRoot).Replace('\','/')
if (-not $path.StartsWith('E:/codex/',[StringComparison]::OrdinalIgnoreCase)) { throw 'Output must be under E:/codex' }
New-Item -ItemType Directory -Force -Path $path | Out-Null
. "$PSScriptRoot/qa_run_status.ps1"
$resultPath = "$path/result.json"
function Check([bool]$ok,[string]$label) { if (-not $ok) { throw $label }; Write-Output "PASS $label" }
Check (-not (Get-QaRunStatus 0 $false $resultPath).passed) 'missing result rejects process exit zero'
'{"exit_code":0,"script_errors":1,"engine_errors":0}' | Set-Content -LiteralPath $resultPath
Check (-not (Get-QaRunStatus 0 $false $resultPath).passed) 'script errors reject process exit zero'
'{"exit_code":0,"script_errors":0,"engine_errors":1}' | Set-Content -LiteralPath $resultPath
Check (-not (Get-QaRunStatus 0 $false $resultPath).passed) 'engine errors reject process exit zero'
'{"exit_code":0,"script_errors":0,"engine_errors":0}' | Set-Content -LiteralPath $resultPath
Check (Get-QaRunStatus 0 $false $resultPath).passed 'clean completed run passes'
Check (-not (Get-QaRunStatus 1 $false $resultPath).passed) 'nonzero launcher exit rejects'
Check ((Get-QaRunStatus 0 $true $resultPath).exit_code -eq 124) 'timeout reported separately'
'{}' | Set-Content -LiteralPath $resultPath
Check (-not (Get-QaRunStatus 0 $false $resultPath).passed) 'incomplete result rejects'
'bad json' | Set-Content -LiteralPath $resultPath
Check (-not (Get-QaRunStatus 0 $false $resultPath).passed) 'malformed result rejects'
