# Verification Scripts

技能修订 M1：`run_skill_rebalance_suite.ps1` 汇总执行 package 中适合 headless 的检查和 M1 新增行为测试。
M1 验收：169/169（74 Node、93 Godot 脚本、2 Godot 场景），记录见 `docs/skills/skill_rebalance_m1_progress.md`。场景验证使用包装器的 `-Scene res://...tscn`；仍显式传 `-ProjectPath` 和 E 盘 `-OutputRoot`。
禁止直接使用默认用户目录的 npm Godot 命令；以 `run_isolated_godot.ps1 -ProjectPath E:/codex/skill-rebalance/worktree -OutputRoot E:/codex/skill-rebalance/<unique-case> -Script res://tools/verify/<case>.gd` 执行，日志/缓存/存档均在 E 盘。
`skill_rebalance_baseline.gd` 与 `skill_rebalance_run_sample.gd` 输出观测，不将已知缺陷标为验收通过。台账见 `docs/skills/skill_rebalance_coverage.json`。

`package.json` is the source of truth for runnable verification commands.

Most standalone `.js` and `.gd` checks in this directory have a matching
`npm run verify:*` entry. Scene-driven checks are registered through their
`.tscn` entry when the scene owns the script lifecycle:

- `verify_area_effect_visual_mode_runtime_scene.tscn`
- `verify_fireball_impact_target_explosion_runtime_scene.tscn`

`verify_fire_skill_card_selection_runtime.gd` covers the current DevTools card
selection contract: selecting a fire skill grants it, can cast once, and does
not spawn debug targets or enemies just to manufacture damage traces.
