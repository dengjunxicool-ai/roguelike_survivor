# Automated Game Test Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用现有自动化入口验证当前游戏主流程、配置契约、核心数值公式、技能成长、敌人系统、debug trace 和长流程运行稳定性，并把代码覆盖率 `>= 95%` 作为发布门禁。

**Architecture:** 测试分五层执行：覆盖率采集门禁、Node.js 静态配置契约、Godot 纯公式/结构检查、Godot 运行时系统检查、自动游玩主流程。数值正确性优先验证 DamagePacket、伤害公式、武器分支表、技能升级池、敌方伤害包、状态 DOT 和波次倍率。

**Tech Stack:** Godot 4.x headless, GDScript `SceneTree` checks, Node.js JSON contract scripts, PowerShell command execution.

---

### Task 0: 覆盖率门禁接入

**Files:**
- Create or modify: coverage runner/tooling file chosen after tool decision
- Read: `scripts/**/*.gd`
- Read: `tools/**/*.gd`
- Read: `tools/**/*.js`

- [ ] **Step 1: 确认覆盖率采集能力**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --help
rg -n "coverage|gdunit|gut" . -g "*.gd" -g "*.js" -g "*.json" -g "*.md" -S
```

Expected:

```text
如果 Godot 或测试框架提供可执行 coverage 输出，则采用原生覆盖率。
如果没有原生 coverage 输出，则不能把现有测试结果声明为 95% 覆盖率；必须先接入项目级覆盖率采集工具。
```

- [ ] **Step 2: 定义覆盖率口径**

Use this gate:

```text
line coverage >= 95%
function coverage >= 95%
branch coverage: 如果工具支持，则 >= 90%；如果不支持，必须在报告中明确“不采集 branch coverage”
统计范围：scripts/**/*.gd、tools/**/*.gd、tools/**/*.js
排除范围：*.uid、.godot/**、assets/**、docs/**、data/**/*.json、生成物、纯文档脚本
```

- [ ] **Step 3: 覆盖率不足时禁止通过**

Expected behavior:

```text
覆盖率报告不存在：FAIL
line coverage < 95%：FAIL
function coverage < 95%：FAIL
任何测试命令失败：FAIL
```

- [ ] **Step 4: 覆盖率补齐策略**

If coverage is below 95%, add tests in this order:

```text
1. DamageSystem / DamageApplicationService / DamagePacketBuilder：直接数值单测，覆盖公式分支。
2. SkillActionExecutor / SkillSpecialRuleExecutor：构造技能 action 输入，验证 packet、状态、爆炸、区域、反应。
3. StatusEffectManager / ReactionService：覆盖 DOT、层数、持续时间、反应限制。
4. UpgradePool / WeaponBranchSystem：覆盖所有武器 Lv2-Lv5 分支与 debug 全量池差异。
5. EnemyActionRegistry / EnemyDamagePacketBuilder / WaveDirector：覆盖敌方技能、波次倍率、Boss/Elite 参数。
6. UI state machine / Developer Mode：覆盖主流程状态切换和 debug tool 行为。
```

### Task 1: 环境与脚本入口确认

**Files:**
- Read: `README.md`
- Read: `tools/*.js`
- Read: `tools/*.gd`
- Read: `scripts/debug/*.gd`

- [ ] **Step 1: 确认 Godot 可执行文件**

Run:

```powershell
& 'C:\Users\dengj\Desktop\Godot.exe' --version
```

Expected: exit code `0`，输出 Godot 版本号。

- [ ] **Step 2: 确认 Node.js 可用**

Run:

```powershell
node --version
```

Expected: exit code `0`，输出 Node.js 版本号。

### Task 2: 静态配置与表驱动数值契约

**Files:**
- Test: `tools/check_text_encoding.js`
- Test: `tools/validate_character_configs.js`
- Test: `tools/validate_enemy_configs.js`
- Test: `tools/validate_modifier_effects.js`
- Test: `tools/validate_no_weapon_evolution.js`
- Test: `tools/validate_weapon_authoring_pipeline.js`
- Test: `tools/validate_weapon_graph.js`
- Test: `tools/validate_branch_design_alignment.js`
- Test: `tools/verify_*_branch_table.js`
- Test: `tools/verify_primary_attack_config.js`
- Test: `tools/verify_area_effect_max_targets.js`
- Test: `tools/verify_weapon_authoring_templates.js`
- Test: `tools/verify_weapon_runtime_slot_wiring.js`
- Test: `tools/verify_weapon_runtime_state_access.js`
- Test: `tools/smoke_character_system.js`

- [ ] **Step 1: 执行 Node.js 配置契约测试**

Run each command from the repository root:

```powershell
node tools\check_text_encoding.js
node tools\validate_character_configs.js
node tools\validate_enemy_configs.js
node tools\validate_modifier_effects.js
node tools\validate_no_weapon_evolution.js
node tools\validate_weapon_authoring_pipeline.js
node tools\validate_weapon_graph.js
node tools\validate_branch_design_alignment.js
node tools\verify_primary_attack_config.js
node tools\verify_area_effect_max_targets.js
node tools\verify_weapon_authoring_templates.js
node tools\verify_weapon_runtime_slot_wiring.js
node tools\verify_weapon_runtime_state_access.js
node tools\smoke_character_system.js
node tools\verify_acid_sprayer_branch_table.js
node tools\verify_cross_relic_branch_table.js
node tools\verify_fire_oil_canister_branch_table.js
node tools\verify_fire_staff_branch_table.js
node tools\verify_frost_staff_branch_table.js
node tools\verify_holy_shield_branch_table.js
node tools\verify_hunter_bow_branch_table.js
node tools\verify_lightning_whip_branch_table.js
node tools\verify_spellbook_branch_table.js
node tools\verify_throwing_knife_belt_branch_table.js
node tools\verify_toxic_vial_branch_table.js
node tools\verify_trap_kit_branch_table.js
node tools\verify_warhammer_branch_table.js
```

Expected: 每条命令 exit code `0`。重点关注武器分支 Lv2-Lv5 的数值、状态 id、伤害类型、范围、冷却、目标数和特殊规则字段。

### Task 3: Godot 编译、公式与 UI 结构检查

**Files:**
- Test: `tools/verify_damage_formula.gd`
- Test: `tools/verify_ui_architecture.gd`
- Test: `tools/verify_title_screen_runtime.gd`
- Test: `tools/verify_title_screen_font.gd`

- [ ] **Step 1: 执行 Godot 项目加载检查**

Run:

```powershell
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --quit
```

Expected: exit code `0`，无脚本 parse error。

- [ ] **Step 2: 执行伤害公式专项**

Run:

```powershell
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --script res://tools/verify_damage_formula.gd
```

Expected: exit code `0`。重点覆盖玩家打怪、怪打玩家、DOT 小数池、反应伤害、真实伤害、暴击、防御、抗性、DamagePacket builder、敌方 packet builder、application pipeline。

- [ ] **Step 3: 执行 UI 与标题流程专项**

Run:

```powershell
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --script res://tools/verify_ui_architecture.gd
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --script res://tools/verify_title_screen_runtime.gd
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --script res://tools/verify_title_screen_font.gd
```

Expected: 每条命令 exit code `0`，UI 状态机、标题入口、字体资源加载正常。

### Task 4: Godot 运行时系统检查

**Files:**
- Test: `scripts/debug/progression_service_check.gd`
- Test: `scripts/debug/skill_progression_check.gd`
- Test: `scripts/debug/wave_system_check.gd`
- Test: `scripts/debug/enemy_skill_system_check.gd`
- Test: `scripts/debug/enemy_timeline_system_check.gd`
- Test: `scripts/debug/visual_config_check.gd`

- [ ] **Step 1: 执行成长与技能升级池检查**

Run:

```powershell
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --script res://scripts/debug/progression_service_check.gd
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --script res://scripts/debug/skill_progression_check.gd
```

Expected: 每条命令 exit code `0`。重点关注升级池数量、Lv2 分支锁定、Lv3-Lv5 升级、Lv5 后进化选项。

- [ ] **Step 2: 执行敌人、波次、timeline 检查**

Run:

```powershell
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --script res://scripts/debug/enemy_skill_system_check.gd
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --script res://scripts/debug/enemy_timeline_system_check.gd
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --script res://scripts/debug/wave_system_check.gd
```

Expected: 每条命令 exit code `0`。重点关注敌方 DamagePacket 不吃玩家倍率、精英/Boss 波次参数、奖励波、Boss phase、刷怪倍率。

- [ ] **Step 3: 执行可视化与 Dev Tool 回归检查**

Run:

```powershell
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --script res://scripts/debug/visual_config_check.gd
```

Expected: exit code `0`。重点关注 Developer Mode、F12、Dev Tool 悬浮、攻击范围、爆炸范围、伤害 record 卡片、Status 按钮施加的 DOT trace。

### Task 5: 自动游玩主流程

**Files:**
- Test: `scripts/debug/full_flow_autoplay.gd`

- [ ] **Step 1: 执行 90 秒主流程自动游玩**

Run:

```powershell
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --script res://scripts/debug/full_flow_autoplay.gd
```

Expected: exit code `0`。主流程可以从标题、选人、选武器、选地图进入对局；运行期间自动处理升级/诅咒/进化弹窗；90 秒内不因脚本错误中断。若提前胜利或失败，脚本应记录结果状态并 exit code `0`。

### Task 6: 结果判定与缺陷分级

**Files:**
- Read: command outputs from Tasks 1-5

- [ ] **Step 1: 汇总通过项**

Record each command as `PASS` only when exit code is `0` and output does not contain explicit `FAIL`/`ERROR` assertion.

- [ ] **Step 2: 汇总失败项**

Classify failures:

```text
P0: 主流程无法启动、伤害公式错误、角色/敌人无法造成或承受伤害、自动游玩脚本崩溃。
P1: 升级池、分支、状态、波次或 Boss 数值与配置表不一致。
P2: Debug/可视化/文案/字体/测试脚本 stale，但不阻断主流程。
```

- [ ] **Step 3: 给出后续处理建议**

For each failure, include:

```text
命令：
失败摘要：
涉及系统：
数值影响：
建议处理：
```
