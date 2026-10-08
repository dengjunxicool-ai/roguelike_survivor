# 阶段 7 高风险核心链路评估 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用两个确定性的 Godot 运行时契约补齐怪物死亡奖励与终局持久化证据，并据此决定五条高风险核心链路是否继续冻结。

**Architecture:** 阶段 7 只新增 dev-only 验证脚本、验证入口和验收文档，生产代码作为只读被测对象。先记录既有核心门禁，再分别验证死亡 pipeline 幂等性和终局持久化；任何失败都先分类，只有证实生产缺陷后才停止本计划并另立修复设计。

**Tech Stack:** Godot 4.6、GDScript、Node.js 验证脚本、PowerShell、Git

**Spec:** `docs/superpowers/specs/2026-10-08-phase-7-high-risk-core-pipeline-evaluation-design.md`

## Global Constraints

- 不修改 `scripts/`、`scenes/`、`resources/` 或 `data/` 下的生产文件。
- 不改变玩法、伤害、状态、死亡、奖励、生成、UI 或存档 schema。
- 新增 Godot 验证必须直接调用 `D:\Godot\Godot_v4.6.3-stable_win64_console.exe`，不得经 npm 在沙箱中间接启动。
- 所有 `user://` 写入必须通过独立的 `APPDATA` 和 `LOCALAPPDATA` 定向到 `E:\codex\godot-phase7`。
- 不读取、复制或覆盖玩家正式 `save.cfg`，不向 C 盘写入缓存、报告或临时文件。
- 现有测试或新增契约失败时停止扩大范围，不修改断言、阈值或玩法规则来取得绿色结果。
- 每次只提交一个可独立审核的测试批次；执行提交步骤前仍需用户明确授权。
- 不推送、不创建 PR，除非用户另行授权。

## Review Focus

- 同一个敌人收到重复死亡请求时，魂石、击杀事件、死亡信号和经验必须只发生一次；由 Task 2 的幂等性场景覆盖。
- `self_explosion` 与部分 `reward_policy` 覆盖组合不能意外恢复被抑制的副作用；由 Task 2 的策略场景覆盖。
- 玩家死亡与 Boss 击败在相邻帧到达时，首个终局结果必须保持且进度只能写一次；由 Task 3 的终局竞争场景覆盖。
- 结算页面重复刷新或调用 progression 记录入口时，不得重复增加总局数、胜负或 Boss 击杀；由 Task 3 的重复刷新场景覆盖。
- 测试存档目录缺失、已有旧测试存档或测试中断时，不得回退到正式用户目录；由 Task 1 的路径探针和 Task 3 的清理断言覆盖。

---

### Task 1: 建立阶段 7 基线与存档隔离门禁

**Files:**
- Read: `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`
- Read: `package.json`
- Read: `scripts/game/save_manager.gd`
- Create outside repository: `E:\codex\godot-phase7\baseline\`（仅测试运行数据）

**Interfaces:**
- Consumes: 现有 `verify:*` 脚本和 Godot `user://` 路径解析。
- Produces: 一组可重复的阶段 7 基线结果，以及确认位于 E 盘的隔离 `user://` 路径。

- [ ] **Step 1: 确认现场和目标路径**

运行：

```powershell
git status --short
git branch --show-current
git log -1 --oneline
```

预期：工作区没有用户未提交修改；如果存在修改，记录并保护，禁止覆盖。

- [ ] **Step 2: 创建精确的 E 盘测试目录**

仅创建以下目录，不使用 `%TEMP%` 或任何 C 盘位置：

```text
E:\codex\godot-phase7\baseline\AppData
E:\codex\godot-phase7\baseline\LocalAppData
```

运行 Godot 前设置：

```powershell
$env:APPDATA = 'E:\codex\godot-phase7\baseline\AppData'
$env:LOCALAPPDATA = 'E:\codex\godot-phase7\baseline\LocalAppData'
```

- [ ] **Step 3: 运行 user 路径探针**

直接运行一次 Godot headless 启动，并检查新生成文件只位于上一步的两个目录下。

运行：

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --quit
```

预期：退出码为 0；本批次新产生的 Godot 用户数据位于 `E:\codex\godot-phase7\baseline`。

- [ ] **Step 4: 运行阶段 7 现有基线**

依次运行：

```powershell
node tools\validate\check_text_encoding.js
node tools\validate\validate_enemy_configs.js
node tools\verify\verify_no_numeric_damage_inputs.js
node tools\verify\verify_fire_status_contract.js
node tools\verify\verify_status_scheduler_contract.js
node tools\verify\verify_tick_damage_interval_contract.js
node tools\verify\verify_enemy_update_hot_path_contract.js
node tools\verify\verify_result_screen_diagnostic_call.js
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_damage_formula.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_burn_status_runtime_scene.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_frost_frozen_vulnerability_runtime.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_enemy_visible_batch_spawn.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_result_unlock_cache_lifetime.gd
```

预期：所有命令退出码为 0。已知且不影响断言的诊断警告必须原样记录，不能自行解释为通过或失败。

- [ ] **Step 5: 分类任何基线失败**

按环境问题、测试隔离问题或既有生产失败分类。任一未解释失败都停止 Task 2，不修改生产代码。

本任务不产生仓库提交。

---

### Task 2: 新增怪物死亡与奖励契约

**Files:**
- Create: `tools/verify/verify_enemy_death_reward_pipeline.gd`
- Modify: `package.json`
- Read only: `scripts/enemies/death/enemy_death_pipeline.gd`
- Read only: `scripts/enemies/enemy_base.gd`
- Read only: `scripts/enemies/enemy_reward_controller.gd`

**Interfaces:**
- Consumes: `EnemyDeathPipeline.new().execute(enemy: Node, context: Dictionary) -> void`。
- Produces: `verify:enemy-death-reward-pipeline` 验证入口，退出码 0 表示幂等性、调用顺序和策略分支均满足现有契约。

- [ ] **Step 1: 建立最小记录型敌人替身**

在新验证脚本内定义 `DeathTestEnemy extends Node2D`：

- 声明 `signal died`；
- 提供 `_is_dead: bool`、`calls: Array[String]` 和 `dead_state_violations: int`；
- `_award_soul_stones()` 记录 `award_soul`；
- `_notify_enemy_killed_synergies()` 记录 `notify_kill`；
- `_apply_death_effect()` 记录 `death_effect`；
- `_drop_experience_crystal()` 记录 `drop_experience`；
- 每个副作用方法检查 `_is_dead == true`，否则增加 `dead_state_violations`；
- `died` 信号连接到记录 `died` 的回调。

替身不得实现奖励数值、伤害公式或死亡业务规则。

- [ ] **Step 2: 添加正常死亡顺序与幂等性场景**

新增 `_verify_normal_death_is_ordered_and_idempotent() -> void`，断言：

```gdscript
enemy.calls == ["award_soul", "notify_kill", "died", "death_effect", "drop_experience"]
enemy.dead_state_violations == 0
enemy.get("_is_dead") == true
```

同一帧再次调用 `execute()` 后，`calls` 必须完全不变。

- [ ] **Step 3: 添加 self-explosion 策略场景**

新增 `_verify_self_explosion_defaults() -> void`，使用 `{"cause": "self_explosion"}`，断言只记录：

```gdscript
["notify_kill", "died"]
```

不得出现魂石、死亡效果或经验掉落。

- [ ] **Step 4: 添加 reward_policy 部分覆盖场景**

将敌人 metadata `reward_policy` 设置为：

```gdscript
{"award_soul": false, "drop_experience": false}
```

普通死亡断言仍记录 `notify_kill`、`died` 和 `death_effect`，但不记录魂石与经验；这证明未指定键继续使用默认值。

- [ ] **Step 5: 运行新契约并分类结果**

使用 Task 1 的 E 盘环境变量直接运行：

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_enemy_death_reward_pipeline.gd
```

预期：退出码为 0。如果断言暴露生产行为与规格不一致，停止本计划并提交缺陷证据，不修改 production pipeline。

- [ ] **Step 6: 登记验证入口**

在 `package.json` 的 `scripts` 中新增：

```json
"verify:enemy-death-reward-pipeline": "D:\\Godot\\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_enemy_death_reward_pipeline.gd"
```

不要调整其他脚本的名称或内容。

- [ ] **Step 7: 运行相关回归**

运行新契约、`verify_damage_formula.gd`、`verify_burst_fireball_death_explosion_debug_trace.js`、文本编码检查和 `git diff --check`。

预期：全部退出码为 0；`scripts/` 下没有差异。

- [ ] **Step 8: 用户授权后提交本批次**

建议提交内容仅包括新验证脚本和 `package.json`，建议提交信息：

```text
test: cover enemy death reward pipeline
```

---

### Task 3: 新增终局结算与持久化契约

**Files:**
- Create: `tools/verify/verify_run_terminal_progression.gd`
- Modify: `package.json`
- Read only: `scripts/ui/ui_manager.gd`
- Read only: `scripts/ui/run_result_state_builder.gd`
- Read only: `scripts/game/run_progression_service.gd`
- Read only: `scripts/game/save_manager.gd`

**Interfaces:**
- Consumes: `UIManager._on_player_died() -> void`、`UIManager._on_boss_defeated(elapsed_time: float) -> void`、`RunProgressionService.record_run_result(state: String, run_state: Dictionary) -> Dictionary`、`SaveManager.get_last_run_summary() -> Dictionary`。
- Produces: `verify:run-terminal-progression` 验证入口，退出码 0 表示终局状态、单次记录、计数和摘要隔离满足契约。

- [ ] **Step 1: 建立测试存档守卫**

验证脚本启动时取得 `ProjectSettings.globalize_path("user://save.cfg")`，断言其标准化绝对路径位于 `E:/codex/godot-phase7/` 下。断言失败时立即以非零退出码结束，不执行任何删除或写入。

只有路径守卫通过后，才允许删除本次隔离目录中的精确 `save.cfg`，为测试建立空存档。

- [ ] **Step 2: 添加进度服务失败场景**

调用 `RunProgressionService.record_run_result("RESULT_DEFEAT", run_state)`，其中固定输入包括：

```gdscript
{
  "selected_character_id": &"mage",
  "selected_map_id": &"abandoned_dungeon",
  "selected_map_name": "Dungeon",
  "run_seconds": 120.0,
  "kill_count": 7,
  "run_souls_earned": 3,
  "main_attack_level": 2,
  "run_stats": {}
}
```

断言摘要为失败、`total_runs == 1`、`defeats == 1`、`victories == 0`、`total_kills == 7`，且角色与地图 runs 均为 1。

- [ ] **Step 3: 添加进度服务胜利场景**

清理隔离存档后，用相同基础输入调用 `RESULT_VICTORY`，断言 `victories == 1`、`boss_kills == 1`、`defeats == 0`，地图 clears 为 1，最后摘要的 `victory == true`。

- [ ] **Step 4: 添加摘要深拷贝场景**

读取 `SaveManager.get_last_run_summary()`，修改返回字典及其嵌套 `run_stats`，再次读取后断言持久化内容未变化。

- [ ] **Step 5: 添加 UI 终局竞争与单次记录场景**

实例化 `res://scenes/app/app_bootstrap.tscn`，等待 UI 初始化，使用隔离存档并设置确定性的运行状态。分别验证：

- RUNNING 状态调用 `_on_player_died()` 后进入 `RESULT_DEFEAT`；
- RUNNING 状态调用 `_on_boss_defeated(240.0)` 后进入 `RESULT_VICTORY`；
- 已进入任一结果状态后再发送另一终局回调，`current_state` 不改变；
- 连续两次调用 `_refresh_result_screen(current_state)`，`total_runs` 仍为 1；
- debug run 调用 `_on_player_died()` 时不进入正式失败结算。

每个结果分支使用新实例并先清理隔离 `save.cfg`，避免测试之间共享进度。

- [ ] **Step 6: 运行新契约并分类结果**

为本测试使用独立目录：

```powershell
$env:APPDATA = 'E:\codex\godot-phase7\terminal-progression\AppData'
$env:LOCALAPPDATA = 'E:\codex\godot-phase7\terminal-progression\LocalAppData'
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_run_terminal_progression.gd
```

预期：路径守卫、失败、胜利、深拷贝、终局竞争、重复刷新和调试局断言全部通过，退出码为 0。

- [ ] **Step 7: 登记验证入口**

在 `package.json` 的 `scripts` 中新增：

```json
"verify:run-terminal-progression": "D:\\Godot\\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_run_terminal_progression.gd"
```

不要修改任何现有验证入口。

- [ ] **Step 8: 运行相关回归**

运行新契约、`verify_result_unlock_cache_lifetime.gd`、`verify_result_screen_diagnostic_call.js`、Godot headless 启动、文本编码检查和 `git diff --check`。

预期：全部退出码为 0；测试结束后隔离存档可被精确删除，玩家正式存档未被读取或修改。

- [ ] **Step 9: 用户授权后提交本批次**

建议提交内容仅包括新验证脚本和 `package.json`，建议提交信息：

```text
test: cover run terminal progression
```

---

### Task 4: 阶段 7 总体验收与文档闭环

**Files:**
- Modify: `docs/PROJECT_ENGINEERING_GUIDELINES.md`
- Modify: `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`
- Modify: `docs/PROJECT_SYSTEMS_OVERVIEW.md`
- Read: `docs/superpowers/specs/2026-10-08-phase-7-high-risk-core-pipeline-evaluation-design.md`
- Read: `tools/verify/verify_enemy_death_reward_pipeline.gd`
- Read: `tools/verify/verify_run_terminal_progression.gd`

**Interfaces:**
- Consumes: Task 1 基线、Task 2 死亡奖励契约和 Task 3 终局持久化契约的实际输出。
- Produces: 阶段 7 的证据表、冻结结论、遗留风险和未来重新开启条件。

- [ ] **Step 1: 运行完整阶段 7 验证矩阵**

使用全新的 `E:\codex\godot-phase7\acceptance` 环境，复跑 Task 1 的全部门禁、Task 2 和 Task 3 新契约，以及 Godot headless 启动。

预期：每条命令实际退出码为 0。不得用早先运行结果替代本次验收证据。

- [ ] **Step 2: 检查仓库边界**

运行：

```powershell
git diff --name-only
git diff --check
git status --short
```

预期：生产目录无差异；只包含两个验证脚本、`package.json` 和三份工程文档的预期修改。

- [ ] **Step 3: 更新工程指南**

在 `docs/PROJECT_ENGINEERING_GUIDELINES.md` 增加阶段 7 守护规则：

- 死亡 pipeline 和终局 progression 契约是长期门禁；
- 核心链路没有失败证据时保持冻结；
- 所有存档类测试必须使用 E 盘隔离用户目录；
- npm 不用于在沙箱内间接启动 Godot。

- [ ] **Step 4: 更新稳定性报告**

在 `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md` 记录：

- 新增契约覆盖的行为；
- 实际验证命令与结果；
- 五条高风险链路的冻结或问题分类；
- 已知诊断警告和真实遗留风险；
- 未来只有明确缺陷、性能数据或扩展需求才重新开启核心链路。

- [ ] **Step 5: 更新系统概览**

在 `docs/PROJECT_SYSTEMS_OVERVIEW.md` 补充死亡奖励和终局持久化门禁位置，不改变系统职责描述或数据流。

- [ ] **Step 6: 运行最终文档与差异检查**

运行：

```powershell
node tools\validate\check_text_encoding.js
git diff --check
```

重新运行两个新增契约，确认文档修改没有影响验证入口。

预期：编码、差异和两个契约全部通过。

- [ ] **Step 7: 输出阶段 7 完成报告**

按项目格式输出：本批次结果、修改范围、保持不变、验证证据、性能对比“不适用”、遗留风险和最多三个下一步选项。只有全部门禁通过时才能建议结束阶段 7。

- [ ] **Step 8: 用户授权后提交验收文档批次**

建议提交内容为三份工程文档，建议提交信息：

```text
docs: complete phase 7 core pipeline evaluation
```

不得自动推送或创建 PR。

## 实施后的独立回滚

- Task 2 可通过删除死亡奖励验证脚本及其 package 入口单独回滚。
- Task 3 可通过删除终局持久化验证脚本及其 package 入口单独回滚。
- Task 4 可单独恢复三份工程文档，不影响两个验证契约。
- 回滚后必须复跑 Task 1 基线；不得删除或回滚阶段 6 的数据入口提交。
