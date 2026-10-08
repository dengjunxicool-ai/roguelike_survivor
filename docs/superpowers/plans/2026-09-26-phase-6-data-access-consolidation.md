# 阶段 6 数据入口收口实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变玩法、配置、顺序、UI 或存档结果的前提下，完成阶段 6 剩余正式运行数据域的稳定门面收口。

**Architecture:** `DataManager` 保持运行时权威数据所有者，`GameData` 提供 manager-first 且保留 JSON fallback 的稳定门面，业务消费者不再重复判断 autoload 或直接读取同一 JSON。计划按数据域逐批执行，每批均先建立失败边界、实施最小修改、完成独立验证并停下汇报。

**Tech Stack:** Godot 4.6.3、GDScript、Node.js 静态验证脚本、JSON 配置、PowerShell。

**Spec:** `docs/superpowers/specs/2026-09-26-phase-6-data-access-consolidation-design.md`

## Global Constraints

- 所有工作均属于正式路线图的阶段 6；“批次”和“任务”不是新的阶段编号，不得使用 5E、6A、6B 等名称。
- 不修改玩法规则、技能行为、伤害公式、数值平衡、掉落概率、UI/视觉表现或存档结果。
- 不修改 JSON schema、配置 ID、字段值或有序配置的排列顺序。
- `DataManager` 是运行时数据所有者；`GameData` 是稳定兼容门面；JSON fallback 必须保留。
- 每个数据域独立实施、验证、汇报和回滚；上一批未获用户确认时不得进入下一批。
- 未经用户对该批次明确授权，不得提交、推送或创建 PR。
- 不覆盖、还原或格式化与本批次无关的未提交修改。
- 不允许向 C 盘写入任何文件。所有 Godot 临时数据必须定向到 `E:\codex\godot-phase6`。
- Godot 验证使用直接可执行文件，不通过 npm 子进程启动。
- 每批开始前执行 `git status --short`，结束前执行文本编码检查和 `git diff --check`。

## Review Focus

- `/root/DataManager` 完全缺失或暂时改名时，门面必须使用 JSON fallback；由每个数据域的运行时验证覆盖。
- `DataManager` 存在但 accessor 缺失、返回错误类型或返回空结果时，门面必须安全 fallback；由各运行时验证的不可用 manager 替身覆盖。
- 调用方修改返回值的嵌套数组或字典后，不得污染 owner、缓存或下一次查询；由各运行时验证的深拷贝断言覆盖。
- 融合技能和初始技能等有序池必须与 JSON 顺序完全一致；由融合技能和技能批次的顺序断言覆盖。
- 未知 ID、缓存命中和缓存未命中不得改变现有空值与默认值路径；由角色、战斗对象、技能和状态批次的专项断言覆盖。

## 执行协议

在运行任何 Godot 命令前，在当前 PowerShell 会话中设置：

```powershell
$godotCacheRoot = 'E:\codex\godot-phase6'
New-Item -ItemType Directory -Force -Path (Join-Path $godotCacheRoot 'appdata'),(Join-Path $godotCacheRoot 'localappdata') | Out-Null
$env:APPDATA = Join-Path $godotCacheRoot 'appdata'
$env:LOCALAPPDATA = Join-Path $godotCacheRoot 'localappdata'
```

通用运行时命令格式：

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/<verifier>.gd
```

每个任务完成后必须停下，报告行为不变量、改动文件、实际命令、结果、已知噪音和回滚方式。只有用户明确批准，才能提交该任务并开始下一任务。

---

### Task 1: 收口并交付当前遗物数据访问批次

**Files:**
- Modify: `scripts/game/game_data.gd:84-95`
- Modify: `scripts/relics/relic_manager.gd:1-190`
- Modify: `package.json:2-5`
- Test: `tools/verify/verify_data_access_relics.gd`
- Test: `tools/verify/verify_data_access_relics_boundary.js`
- Modify: `docs/PROJECT_ENGINEERING_GUIDELINES.md`
- Modify: `docs/PROJECT_SYSTEMS_OVERVIEW.md`
- Modify: `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`
- Modify: `docs/superpowers/specs/2026-09-19-relic-data-access-consolidation-design.md`
- Modify: `docs/superpowers/plans/2026-09-19-relic-data-access-consolidation.md`

**Interfaces:**
- Consumes: `DataManager.get_relic_definition(id: Variant) -> Dictionary`、`DataManager.get_relic_definitions() -> Array[Dictionary]`
- Produces: `GameData.get_relic(id: StringName) -> Dictionary`、`GameData.get_relic_pool() -> Array[Dictionary]`

- [ ] **Step 1: 保护当前工作树并核对差异范围**

运行 `git status --short` 和目标文件 diff。确认当前遗物实现、测试和文档全部保留，且没有把用户其他修改纳入本批次。

- [ ] **Step 2: 确认阶段命名已经统一**

运行：

```powershell
rg -ni "stage.?5|阶段.?5|5e|stage5e" docs/PROJECT_ENGINEERING_GUIDELINES.md docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md docs/PROJECT_SYSTEMS_OVERVIEW.md docs/superpowers/specs/2026-09-19-relic-data-access-consolidation-design.md docs/superpowers/plans/2026-09-19-relic-data-access-consolidation.md tools/verify/verify_data_access_relics.gd
```

Expected: 无输出；路线图仍明确当前是阶段 6。

- [ ] **Step 3: 运行遗物聚焦门禁**

运行静态边界验证和 `verify_data_access_relics.gd`。Expected: 两者均打印 `PASS`。

- [ ] **Step 4: 运行阶段 6 已完成批次回归**

依次运行现有 status pool、progression goals、challenge pools、upgrade catalog 的静态和运行时验证。Expected: 全部 `PASS`。

- [ ] **Step 5: 运行全局安全检查**

运行：

```powershell
node tools\validate\check_text_encoding.js
node tools\validate\validate_enemy_configs.js
node tools\verify\verify_no_numeric_damage_inputs.js
git diff --check
```

随后直接运行 Godot headless 启动。Expected: 所有命令退出码为 0，无新增脚本错误。

- [ ] **Step 6: 停下汇报并请求提交授权**

未经用户明确授权不得执行提交。若授权，只暂存本任务列出的文件并使用提交信息：

```powershell
git commit -m "refactor: consolidate phase 6 relic data access"
```

---

### Task 2: 角色定义消费者收口

**Files:**
- Modify: `scripts/characters/character_runtime.gd:82-89`
- Create: `tools/verify/verify_data_access_characters_boundary.js`
- Create: `tools/verify/verify_data_access_characters.gd`
- Modify: `package.json`
- Modify: the three engineering documents only after tests pass

**Interfaces:**
- Consumes: `GameData.get_character(character_id: StringName) -> Dictionary`
- Produces: `CharacterRuntime._get_character_data(character_id)` 只委托给 `GameData`

- [ ] **Step 1: 写静态失败测试**

创建 `verify_data_access_characters_boundary.js`，断言 `character_runtime.gd` 不包含 `/root/DataManager`、`get_character_definition` 或直接 JSON 加载，并包含 `GameData.get_character(`。

- [ ] **Step 2: 运行静态测试并确认 RED**

运行 `node tools\verify\verify_data_access_characters_boundary.js`。Expected: 因当前仍直接访问 DataManager 而失败。

- [ ] **Step 3: 写角色运行时契约测试**

覆盖已知角色、未知 ID、manager-first、完整 fallback、缺少 accessor fallback 和嵌套修改隔离；同时断言 `CharacterRuntime` 返回的角色 ID 和基础定义与修改前一致。

- [ ] **Step 4: 实施最小消费者修改**

将 `_get_character_data(character_id: StringName) -> Dictionary` 改为只返回 `GameData.get_character(character_id)`；不改角色运行时其他方法。

- [ ] **Step 5: 运行 GREEN 和角色回归**

运行两个新验证器、`verify_character_select_ui.gd`、`verify_run_hud_skill_slots.gd`、文本编码、headless 启动和 `git diff --check`。Expected: 全部通过。

- [ ] **Step 6: 停下汇报并请求提交授权**

若授权，提交信息：`refactor: route character definitions through game data`。

---

### Task 3: 敌人技能仓库收口

**Files:**
- Modify: `scripts/enemies/skills/enemy_skill_repository.gd:1-55`
- Create: `tools/verify/verify_data_access_enemy_skills_boundary.js`
- Create: `tools/verify/verify_data_access_enemy_skills.gd`
- Modify: `package.json`
- Modify: the three engineering documents only after tests pass

**Interfaces:**
- Consumes: `GameData.get_enemy_skill_pool() -> Array[Dictionary]`
- Produces: `EnemySkillRepository._load_skill_data() -> Array[Dictionary]` 只委托给 `GameData`

- [ ] **Step 1: 写并运行静态 RED 测试**

断言仓库不再包含 DataManager 查找、`JsonDataLoader` 或 enemy skills 路径常量，并使用 `GameData.get_enemy_skill_pool()`。Expected: 修改前失败。

- [ ] **Step 2: 写运行时契约测试**

覆盖 manager-first、完整 fallback、缺少 accessor fallback、池顺序/ID 一致、深拷贝隔离，以及仓库对已知和未知技能 ID 的现有结果。

- [ ] **Step 3: 实施最小仓库修改**

预加载 `GameData`，令 `_load_skill_data()` 返回 `GameData.get_enemy_skill_pool()`；删除只服务于重复 fallback 的依赖、常量和 helper。

- [ ] **Step 4: 运行 GREEN 和敌人技能回归**

运行新验证器、敌人配置 validator、相关 enemy skill/runtime smoke、文本编码、headless 启动和 `git diff --check`。

- [ ] **Step 5: 停下汇报并请求提交授权**

若授权，提交信息：`refactor: route enemy skill repository through game data`。

---

### Task 4: 融合技能池收口

**Files:**
- Modify: `scripts/game/game_data.gd:1-165`
- Modify: `scripts/skills/synergy_manager.gd:92-115`
- Create: `tools/verify/verify_data_access_synergies_boundary.js`
- Create: `tools/verify/verify_data_access_synergies.gd`
- Modify: `package.json`
- Modify: the three engineering documents only after tests pass

**Interfaces:**
- Consumes: `DataManager.get_synergy_definitions() -> Array[Dictionary]`
- Produces: `GameData.get_synergy_pool() -> Array[Dictionary]`

- [ ] **Step 1: 写静态 RED 测试**

断言 `GameData` 声明 `get_synergy_pool()`，`SynergyManager` 只使用该门面且不包含 DataManager/JSON 双路径。Expected: 因门面缺失及消费者仍自建 fallback 而失败。

- [ ] **Step 2: 写运行时契约测试**

覆盖 manager-first、完整 fallback、缺少 accessor fallback、错误类型 fallback、深拷贝隔离，并逐项比较 JSON 与门面的融合技能数量、ID 和顺序。

- [ ] **Step 3: 实施 `GameData.get_synergy_pool()`**

签名：`static func get_synergy_pool() -> Array[Dictionary]`。使用 `_get_pool_from_data_manager("get_synergy_definitions")`，空结果时读取 `SYNERGIES_PATH` 的 `synergies` 数组并返回深拷贝。

- [ ] **Step 4: 收口 `SynergyManager`**

保持 `_index_synergy_definitions()` 与所有融合行为不变，只将定义来源替换为 `GameData.get_synergy_pool()`，删除重复加载依赖。

- [ ] **Step 5: 运行 GREEN 和融合技能回归**

运行新验证器、fusion system contract、fusion numeric contract、fusion runtime smoke、文本编码、headless 启动和 `git diff --check`。Expected: 全部通过且融合顺序一致。

- [ ] **Step 6: 停下汇报并请求提交授权**

若授权，提交信息：`refactor: consolidate synergy data access`。

---

### Task 5: 战斗对象定义读取收口

**Files:**
- Modify: `scripts/game/game_data.gd:1-165`
- Modify: `scripts/skills/skill_effect_summary_builder.gd:219-224,307-308`
- Create: `tools/verify/verify_data_access_combat_objects_boundary.js`
- Create: `tools/verify/verify_data_access_combat_objects.gd`
- Modify: `package.json`
- Modify: the three engineering documents only after tests pass

**Interfaces:**
- Consumes: `DataManager.get_combat_object_definition(object_id: Variant) -> Dictionary`
- Produces: `GameData.get_combat_object(object_id: StringName) -> Dictionary`

- [ ] **Step 1: 写静态 RED 测试**

断言 `GameData` 暴露单项门面，`SkillEffectSummaryBuilder._get_combat_object()` 使用该门面，且战斗对象读取不再经过其 `_load_array()`。保留召唤物读取原路径。Expected: 修改前失败。

- [ ] **Step 2: 写运行时契约测试**

覆盖已知和未知 ID、manager-first、完整 fallback、缺少 accessor fallback、错误类型 fallback 和嵌套修改隔离。

- [ ] **Step 3: 实施单项门面和消费者修改**

新增 `static func get_combat_object(object_id: StringName) -> Dictionary`；消费者仅替换 `_get_combat_object()`，不得修改 `_get_summon()` 或通用摘要规则。

- [ ] **Step 4: 运行 GREEN 和文本一致性回归**

运行新验证器与 `verify_skill_card_effect_summary.gd`，比较既有样例生成的说明文本；再运行文本编码、headless 启动和 `git diff --check`。

- [ ] **Step 5: 停下汇报并请求提交授权**

若授权，提交信息：`refactor: route combat object definitions through game data`。

---

### Task 6: 技能查询与有序初始技能池收口

**Files:**
- Modify: `scripts/core/data_manager.gd:43-59,68-135,138-223`
- Modify: `scripts/game/game_data.gd:25-145`
- Modify: `scripts/skills/skill_manager.gd:501-529`
- Modify: `scripts/characters/character_run_initializer.gd:97-110`
- Create: `tools/verify/verify_data_access_skills_boundary.js`
- Create: `tools/verify/verify_data_access_skills.gd`
- Modify: `package.json`
- Modify: the three engineering documents only after tests pass

**Interfaces:**
- Consumes: `DataManager.get_skill_definition(skill_id: Variant) -> Dictionary`
- Produces: `DataManager.get_starting_skill_definitions() -> Array[Dictionary]`
- Produces: `GameData.get_starting_skill_pool() -> Array[Dictionary]`
- Preserves: `GameData.get_skill(skill_id: StringName) -> Dictionary`

- [ ] **Step 1: 写静态 RED 测试**

断言 `SkillManager` 不再直接访问 DataManager 或 `skills.json`，`CharacterRunInitializer` 不再调用 `GameData._load_document()`，并要求两个有序池 accessor 存在。Expected: 修改前失败。

- [ ] **Step 2: 写运行时契约测试**

覆盖初始技能池 manager-first、完整 fallback、缺少 accessor fallback、错误类型 fallback、深拷贝隔离；逐项断言 JSON 的初始技能数量、ID 和顺序；断言默认首个有效技能 ID 与修改前一致；断言 `GameData.get_skill()` 仍可查询初始和普通技能。

- [ ] **Step 3: 为 `DataManager` 保存有序初始技能池**

新增 `_starting_skill_definitions: Array[Dictionary]`，在 `load_all()` 清空并从 `skills_document.starting_skills` 深拷贝赋值；新增 `func get_starting_skill_definitions() -> Array[Dictionary]` 返回深拷贝。现有统一技能索引继续保留。

- [ ] **Step 4: 新增 `GameData.get_starting_skill_pool()`**

签名：`static func get_starting_skill_pool() -> Array[Dictionary]`。优先 `get_starting_skill_definitions`，否则读取 `skills.json.starting_skills`，并保持顺序和深拷贝隔离。

- [ ] **Step 5: 收口两个消费者**

`SkillManager` 的定义查询只使用 `GameData.get_skill()`；`CharacterRunInitializer._first_configured_starting_skill_id()` 遍历 `GameData.get_starting_skill_pool()`。删除因此失去用途的私有 JSON helper、依赖和常量。

- [ ] **Step 6: 运行 GREEN 和技能回归**

运行新验证器、skill definition schema、skill slot capacity rules、skill growth skill manager、attack skill replacement、god school learning rules、各神系 contract、文本编码、headless 启动和 `git diff --check`。

- [ ] **Step 7: 停下汇报并请求提交授权**

若授权，提交信息：`refactor: consolidate skill data access`。

---

### Task 7: 状态定义单项查询收口

**Files:**
- Modify: `scripts/game/game_data.gd:154-165`
- Modify: `scripts/combat/status_effect_manager.gd:883-916`
- Create: `tools/verify/verify_data_access_status_lookup_boundary.js`
- Create: `tools/verify/verify_data_access_status_lookup.gd`
- Modify: `package.json`
- Modify: the three engineering documents only after tests pass

**Interfaces:**
- Consumes: `DataManager.get_status_definition(status_id: Variant) -> Dictionary`
- Produces: `GameData.get_status(status_id: StringName) -> Dictionary`
- Preserves: `StatusEffectManager._status_definition_cache`

- [ ] **Step 1: 写静态 RED 测试**

断言 `GameData.get_status()` 存在，`StatusEffectManager` 的缓存未命中路径只调用该门面，不再直接访问 DataManager 或私有 `_load_document()`。Expected: 修改前失败。

- [ ] **Step 2: 写运行时契约测试**

覆盖已知和未知状态、manager-first、完整 fallback、缺少 accessor fallback、错误类型 fallback、深拷贝隔离、首次缓存未命中和后续缓存命中。断言缓存返回值不共享可变嵌套数据。

- [ ] **Step 3: 实施状态门面**

新增 `static func get_status(status_id: StringName) -> Dictionary`；优先 `get_status_definition`，否则从 `status_effects.json.statuses` 按 ID 查询并返回独立副本。

- [ ] **Step 4: 只替换状态管理器的数据来源**

保留 `_get_status_definition()` 的缓存键、存入和返回语义；删除 `_get_status_definition_from_game_data()`，缓存未命中时改为 `GameData.get_status(status_id)`。不得触碰状态 tick、叠层、反应或伤害代码。

- [ ] **Step 5: 运行 GREEN 和高风险回归**

运行新验证器、status pool 既有验证、status scheduler contract、status visual refresh coalescing、各神系 runtime smoke、fusion runtime smoke、damage formula、no numeric damage inputs、文本编码、headless 启动和 `git diff --check`。

- [ ] **Step 6: 检查既有测试噪音**

若 `verify_damage_formula.gd` 再次出现无场景树的 `RuntimePoolRegistry._resolve_tree()` 诊断，确认退出码、断言结果和堆栈均未指向本批次改动；不得通过删除断言或放宽验证掩盖新回归。

- [ ] **Step 7: 停下汇报并请求提交授权**

若授权，提交信息：`refactor: consolidate status definition lookup`。

---

### Task 8: 阶段 6 总体验收与文档闭环

**Files:**
- Modify: `docs/PROJECT_SYSTEMS_OVERVIEW.md`
- Modify: `docs/PROJECT_ENGINEERING_GUIDELINES.md`
- Modify: `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`
- Verify only: all Phase 6 production, test, package, spec and plan files

**Interfaces:**
- Consumes: Task 1 through Task 7 verified facades and consumer boundaries
- Produces: documented Phase 6 completion evidence; no runtime interface

- [ ] **Step 1: 审计剩余正式运行直接读取**

使用 `rg` 搜索运行时脚本中的 `/root/DataManager`、`JsonDataLoader`、`GameData._load_document` 和 `DataPaths` 配置直读。逐项分类为：稳定门面内部、独立服务、debug-only、兼容入口、尚未由 DataManager 持有的数据域或未解决债务。

- [ ] **Step 2: 对未解决债务执行完成标准判断**

若仍存在“已由 DataManager 持有的数据域 + 正式消费者重复 fallback”，阶段 6 不得宣告完成；为该数据域补独立批次设计。独立服务、debug-only 和召唤物等排除项只记录理由，不扩大范围。

- [ ] **Step 3: 更新三份工程文档**

记录实际完成的数据域、稳定门面、保留 fallback 的理由和阶段 6 完成边界。不得预先写入未通过验证的结论，不得把内部批次写成新阶段编号。

- [ ] **Step 4: 运行完整阶段 6 门禁**

运行所有 `verify:data-access-*` 静态和运行时验证、配置 validator、文本编码、no numeric damage inputs、damage formula、相关技能/状态 smoke、直接 Godot headless 启动和 `git diff --check`。Expected: 所有断言通过；任何已知环境噪音均有独立证据证明与阶段 6 无关。

- [ ] **Step 5: 审查最终 diff**

确认无 JSON、资源、UI、数值、伤害公式、状态行为、生成规则或无关格式化变化；确认没有新增循环依赖或新的重复 fallback。

- [ ] **Step 6: 输出阶段 6 完成报告**

按照项目要求输出：本批次结果、修改范围、保持不变、验证证据、性能对比“不适用”、遗留风险和最多三个下一步选项。只有全部完成标准满足时，才建议进入阶段 7。

- [ ] **Step 7: 停下并请求最终提交/推送授权**

未经明确授权不得提交、推送或创建 PR。若用户授权整合剩余文档，只暂存阶段 6 审批范围内文件。

## 回滚顺序

发生回归时只回滚当前数据域：恢复消费者原入口，删除该批次新增门面/accessor、验证器和 package 脚本，再恢复该批次文档。不得回滚已通过并获批的前序批次，也不得覆盖用户其他未提交修改。
