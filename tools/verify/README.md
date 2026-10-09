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


## M4 隔离验证与采样

自动行为回归：`pwsh -NoProfile -File tools/verify/run_skill_rebalance_suite.ps1 -ProjectPath E:/codex/skill-rebalance/worktree -OutputRoot E:/codex/skill-rebalance/<fresh-suite>`。M4新预览/反馈/计量/协议合同已纳入，共209项。必须使用全新用户目录，脚本级PASS不能覆盖engine/script errors。

`verify_skill_balance_matrix.gd` 不带`--execute`仅核对18预设/15融合前置，不宣称平衡。`verify_skill_rebalance_performance.gd` 不带`--execute`仅核对压力技能清单。

批量固定场景：`pwsh -NoProfile -File tools/verify/run_skill_balance_batch.ps1 -OutputRoot E:/codex/skill-rebalance/<fresh-batch> -Cohort exploration -Mode matrix -Revision <verified-code-sha>`。默认全部10种子；`confirmation`使用20新种子，`fusion`使用5，`outlier`使用20融合种子。`-SeedLimit 1`是预检；`-Mode real`使用真实300秒上限、无生存辅助；早死如实记录。每个worker独立用户目录，输出batch.json、case-N/result.json及data/matrix.json/matrix.csv。固定普通/精英是hold-position，移动Boss/真实局使用声明的避敌控制策略；静止Boss阶段不是不可移动Boss。预设资格Lv6是受控开局资格，技能/品质预算在文件中，实际敌人数据不变。

单例参数必须用PowerShell数组传给包装器，例如：

```powershell
& ./tools/verify/run_isolated_godot.ps1 -ProjectPath E:/codex/skill-rebalance/worktree -OutputRoot E:/codex/skill-rebalance/<fresh-case> -Script res://tools/verify/verify_skill_balance_matrix.gd -EngineArguments @('--fixed-fps','60','--audio-driver','Dummy') -UserArguments @('--execute','--mode=matrix','--cohort=fusion','--seed-limit=1','--preset-start=0','--preset-limit=1','--revision=<verified-sha>')
```

渲染压力测试用包装器`-Rendered -Script res://tools/verify/verify_skill_rebalance_performance.gd -UserArguments @('--execute')`，不加fixed-fps。按T0和M4串行运行同一脚本；实际process_frame墙钟间隔、暖机2秒、固定24怪和前60秒实际波次。12技能初始授予与回满生命只服务压力测试，不计平衡/存活率。各数据的通过范围和缺口见`docs/skills/skill_rebalance_validation.md`。所有临时目录、日志、Godot缓存和存档都必须位于E:/codex；不使用会写默认C盘用户目录的npm Godot命令。

审查补充：`verify_m4_review_previews.gd` 检查事件/冲刺CD、被动与原生融合实际收益、嵌套条件输出、状态时长加成/移除、替换旧新数值及36个具体里程碑；与完整套件同时运行。M4仍为测试版，采样及性能日志的历史版本限制见验证报告。
