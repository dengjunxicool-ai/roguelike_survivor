param(
    [string]$ProjectPath = 'E:/codex/skill-rebalance/worktree',
    [string]$OutputRoot = 'E:/codex/skill-rebalance/suite',
    [switch]$LegacyOnly
)
$ErrorActionPreference = 'Stop'
$resolved = [IO.Path]::GetFullPath($OutputRoot).Replace('\','/')
if (-not $resolved.StartsWith('E:/codex/', [StringComparison]::OrdinalIgnoreCase)) { throw 'OutputRoot must be under E:/codex' }
$env:APPDATA = "$resolved/appdata"
$env:LOCALAPPDATA = "$resolved/localappdata"
$env:TEMP = "$resolved/tmp"
$env:TMP = $env:TEMP
$env:npm_config_cache = "$resolved/npm-cache"
New-Item -ItemType Directory -Force -Path $resolved,$env:APPDATA,$env:LOCALAPPDATA,$env:TEMP | Out-Null
$package = Get-Content -LiteralPath "$ProjectPath/package.json" -Raw | ConvertFrom-Json
$cases = @()
foreach ($property in $package.scripts.PSObject.Properties) {
    $command = [string]$property.Value
    if ($command -match '^node (tools[\\/](?:verify|validate)[\\/][\w-]+\.js)$') {
        $cases += [pscustomobject]@{name=$property.Name; kind='node'; path=$Matches[1].Replace('\','/')}
    } elseif ($command -match '--headless.*--script (res://[\w/.-]+\.gd)') {
        $cases += [pscustomobject]@{name=$property.Name; kind='godot'; path=$Matches[1]}
    } elseif ($command -match '--headless.* (res://[\w/.-]+\.tscn)$') {
        $cases += [pscustomobject]@{name=$property.Name; kind='scene'; path=$Matches[1]}
    }
}
if (-not $LegacyOnly) {
    foreach ($name in @('verify_skill_upgrade_monotonic','verify_skill_damage_growth_paths','verify_skill_timed_modifiers','verify_skill_modifier_consumption','verify_skill_event_provenance','verify_skill_proc_chain_limits','verify_skill_status_lifecycle_v2','verify_skill_status_race_conditions','verify_skill_slot_capacity_v2','verify_skill_replacement_transaction','verify_skill_requirements_v2','verify_skill_offer_progression_v2','verify_fire_curse_cycle_v2','verify_fire_curse_boss_cycle','verify_frost_control_v2','verify_frost_execute_tiers','verify_thunder_proc_v2','verify_holy_shield_time_v2','verify_m2_review_regressions','verify_chaos_replay_v2','verify_chaos_mutation_v2','verify_skill_level_milestones_v2','verify_fusion_semantics_v2','verify_fusion_geometry_v2','verify_fusion_spatial_runtime_v2')) {
        $cases += [pscustomobject]@{name=$name; kind='godot'; path="res://tools/verify/$name.gd"}
    }
    foreach ($name in @('verify_skill_rebalance_inventory','verify_skill_modifier_stat_validation')) {
        $cases += [pscustomobject]@{name=$name; kind='node'; path="tools/verify/$name.js"}
    }
}
$wrapper = "$PSScriptRoot/run_isolated_godot.ps1"
$results = $cases | ForEach-Object -Parallel {
    $case = $_
    $project = $using:ProjectPath
    $dir = ($using:resolved) + '/' + $case.name.Replace(':','-')
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $arguments = if ($case.kind -eq 'node') { @("$project/$($case.path)") } else { @('-NoProfile','-NonInteractive','-File',($using:wrapper),'-ProjectPath',$project,($(if ($case.kind -eq 'scene') {'-Scene'} else {'-Script'})),$case.path,'-OutputRoot',"$dir/godot") }
    $exe = if ($case.kind -eq 'node') { 'node.exe' } else { 'powershell.exe' }
    $process = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $project -WindowStyle Hidden -RedirectStandardOutput "$dir/stdout.log" -RedirectStandardError "$dir/stderr.log" -PassThru
    $timedOut = -not $process.WaitForExit(90000)
    if ($timedOut) {
        $all = Get-CimInstance Win32_Process
        $ids = [Collections.Generic.List[int]]::new()
        $ids.Add($process.Id)
        for ($i=0; $i -lt $ids.Count; $i++) { foreach ($child in $all | Where-Object ParentProcessId -eq $ids[$i]) { $ids.Add([int]$child.ProcessId) } }
        for ($i=$ids.Count-1; $i -ge 0; $i--) { Stop-Process -Id $ids[$i] -Force -ErrorAction SilentlyContinue }
    }
    $process.Refresh()
    $code = if ($timedOut) { 124 } else { $process.ExitCode }
    [pscustomobject]@{name=$case.name; path=$case.path; kind=$case.kind; exit_code=$code; timeout=$timedOut; output=$dir}
} -ThrottleLimit 4
$results | Sort-Object name | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$resolved/results.json" -Encoding utf8
$failed = @($results | Where-Object exit_code -ne 0)
Write-Output "SUITE total=$($results.Count) passed=$($results.Count-$failed.Count) failed=$($failed.Count) report=$resolved/results.json"
$failed | Select-Object name,exit_code,timeout,output | Format-Table -AutoSize
if ($failed.Count -gt 0) { exit 1 }
exit 0
