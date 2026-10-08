# 阶段 6：小步收口数据入口——收尾设计

## 状态

本规格记录已经确认的阶段 6 收尾架构和详细设计。它只授权形成规格文档，不授权继续修改生产代码；后续实现必须先形成书面实施计划，并由用户确认执行方式。

本文中的“阶段 6 批次”只是阶段 6 内部的可验证、可回滚工作单元，不是新的阶段编号。不得使用“5E”“6A”“6B”等名称代替路线图中的正式阶段编号。

## 目标

阶段 6 的唯一目标是小步收口运行时数据访问入口：

- `DataManager` 保持运行时数据所有者和索引中心；
- `GameData` 保持稳定兼容门面；
- 正式运行消费者通过公开门面读取数据；
- JSON 继续作为兼容 fallback；
- 不修改玩法、配置语义、数据顺序、存档或视觉表现。

阶段 6 不试图消除所有直接 JSON 读取。独立服务、调试工具以及尚未由 `DataManager` 持有的数据域可以保留现有入口，但必须有明确理由。

## 已完成和当前批次

已经合入的阶段 6 数据访问批次包括：

- 状态池；
- 进度目标文档；
- 每日和每周挑战池；
- 升级分类池与稀有度权重。

当前工作树中的遗物数据访问批次已经实现并完成验证，但尚未提交。它将 `RelicManager` 的定义读取统一到 `GameData` 的遗物池和单条查询门面，同时保留 `DataManager` 优先和 JSON fallback。

这些工作均属于阶段 6，不属于阶段 5，也不构成额外的子阶段编号。

## 统一架构边界

正常数据流为：

```text
业务消费者 -> GameData 稳定门面 -> DataManager 运行时权威
                              \-> JSON 兼容 fallback
```

### `DataManager`

- 在启动阶段加载并索引已声明的数据域；
- 对需要保持配置顺序的数据保存有序池；
- accessor 返回深拷贝，避免调用方修改共享状态；
- 不承接业务规则、UI、存档或战斗行为。

### `GameData`

- 为消费者提供稳定的公开读取接口；
- 正常运行时优先调用 `DataManager`；
- `DataManager` 缺失、缺少 accessor 或返回空结果时使用现有 JSON fallback；
- 返回值保持与现有调用方兼容；
- 不暴露 `_load_document()` 等私有加载细节给业务消费者。

### 业务消费者

- 不自行检查 `/root/DataManager`；
- 不为同一数据域重复实现 JSON fallback；
- 只负责消费定义和执行自身业务职责；
- 不因本阶段改变缓存、选择、排序或默认值语义。

## 剩余批次和顺序

### 1. 遗物数据访问批次

完成当前已经实现的遗物收口，统一文档和测试中的阶段名称。不得修改遗物触发、modifier、奖励、UI、存档或局内状态逻辑。

### 2. 角色定义批次

`CharacterRuntime` 只调用 `GameData.get_character()`，删除其内部对 `DataManager` 的重复判断。角色初始化、特质和属性结果保持不变。

### 3. 敌人技能批次

`EnemySkillRepository` 通过现有 `GameData.get_enemy_skill_pool()` 获取定义，删除仓库内部重复的 DataManager/JSON 双路径。仓库缓存和技能构造结果保持不变。

### 4. 融合技能批次

新增 `GameData.get_synergy_pool()`，优先调用现有 `DataManager.get_synergy_definitions()`，否则读取 `synergies.json.synergies`。`SynergyManager` 只消费该门面。融合条件、ID 和配置顺序保持不变。

### 5. 战斗对象定义批次

新增 `GameData.get_combat_object(object_id)`，优先调用现有 `DataManager.get_combat_object_definition()`，否则按 ID 查询 `combat_objects.json.combat_objects`。`SkillEffectSummaryBuilder` 仅将战斗对象定义读取切换到该门面。

召唤物数据不在本批次范围内，因为它当前不属于 `DataManager` 的既有所有权范围。

### 6. 技能与初始技能池批次

`SkillManager` 只通过 `GameData.get_skill()` 查询技能定义，删除后续重复 JSON 扫描。

新增以下有序池接口：

- `DataManager.get_starting_skill_definitions() -> Array[Dictionary]`
- `GameData.get_starting_skill_pool() -> Array[Dictionary]`

`DataManager` 必须单独保存 `skills.json.starting_skills` 的有序深拷贝，不能从技能索引字典反推顺序。`CharacterRunInitializer` 使用 `GameData.get_starting_skill_pool()` 获取第一个有效配置 ID，不再调用私有 `GameData._load_document()`。

### 7. 状态单项查询批次

最后新增 `GameData.get_status(status_id)`，优先调用现有 `DataManager.get_status_definition()`，否则按 ID 查询 `status_effects.json.statuses`。`StatusEffectManager` 保留本地定义缓存，只替换缓存未命中时的数据来源。

该批次不得修改状态应用、叠层、tick、元素反应、伤害或移除逻辑。

### 8. 阶段 6 总体验收

审计正式运行代码中的 DataManager/JSON 重复读取。对保留的直接读取逐项记录其属于独立服务、调试用途、兼容入口或尚未纳入 DataManager 所有权的数据域。完成总体验收后才允许重新评估阶段 7。

## 公开接口契约

| 数据域 | `GameData` 接口 | `DataManager` 接口 | 空结果 | 顺序要求 |
|---|---|---|---|---|
| 角色 | `get_character(id)` | `get_character_definition(id)` | `{}` | 不适用 |
| 敌人技能 | `get_enemy_skill_pool()` | `get_enemy_skill_definitions()` | `[]` | 保持现有结果 |
| 融合技能 | `get_synergy_pool()` | `get_synergy_definitions()` | `[]` | 必须保持配置顺序 |
| 战斗对象 | `get_combat_object(id)` | `get_combat_object_definition(id)` | `{}` | 不适用 |
| 技能 | `get_skill(id)` | `get_skill_definition(id)` | `{}` | 不适用 |
| 初始技能 | `get_starting_skill_pool()` | `get_starting_skill_definitions()` | `[]` | 必须保持 JSON 顺序 |
| 状态定义 | `get_status(id)` | `get_status_definition(id)` | `{}` | 不适用 |

所有新增门面必须返回独立数据副本。调用方修改返回的嵌套字典或数组后，不得影响后续查询或 `DataManager` 内部数据。

## fallback 和错误处理

每个门面按以下顺序处理：

1. 查找 `/root/DataManager`；
2. 检查对应 accessor 是否存在；
3. 接受类型正确且非空的权威数据；
4. 否则读取既有 JSON 数据源；
5. 无有效数据时返回约定的空结果。

本阶段不新增异常机制、不改变现有 JSON 加载器的报告级别，也不新增业务默认配置。消费者继续使用原有的空值和默认值处理路径。

## 行为不变量

阶段 6 必须保持：

- JSON schema、配置 ID、字段和值不变；
- 初始技能、融合技能和其他有序配置的顺序不变；
- 技能释放、目标选择、资源路径和生成顺序不变；
- 角色属性、特质、初始技能选择和随机规则不变；
- 敌人技能构造、AI、生成、死亡和奖励流程不变；
- 状态应用、叠层、tick、伤害和元素反应不变；
- 遗物效果、获取、modifier、UI 和存档结果不变；
- 公开方法、信号、节点路径和存档格式兼容；
- headless 和无 autoload 的验证场景仍可使用 JSON fallback。

## 明确排除

阶段 6 不处理：

- `DamageApplicationService` 和伤害结算链；
- 状态行为或怪物死亡 pipeline；
- 波次、Boss、敌人数量或生成算法；
- UI、视觉、音效和资源调整；
- 配置内容和 schema 修改；
- debug-only 数据浏览入口；
- `LocalizationService`、`UIThemeService` 等独立服务；
- 尚未由 `DataManager` 持有的召唤物数据；
- 没有独立证据的通用加载器重构。

## 每批次测试要求

每个新增或复用的稳定门面至少验证：

1. `DataManager` 存在时优先采用权威数据；
2. `DataManager` 缺失时 JSON fallback 正常；
3. `DataManager` 缺少 accessor 时 JSON fallback 正常；
4. 未知 ID 返回约定的空结果；
5. 返回值深拷贝隔离；
6. 目标消费者不再直接访问 DataManager 或重复读取对应 JSON；
7. 原配置 ID、数量和顺序保持一致。

专项验证包括：

- 融合技能定义数量、ID 和顺序一致；
- 战斗对象生成的技能说明文本一致；
- 默认初始技能 ID 与修改前一致；
- 状态缓存命中、已知状态和未知状态结果一致；
- 遗物现有运行时、fallback 和隔离测试继续通过。

每个批次还必须运行文本编码、对应静态边界验证、对应 Godot 运行时契约验证、相关现有 validator、Godot headless 启动和 `git diff --check`。状态批次追加伤害公式和状态相关回归。

## 批次文件边界

| 批次 | 允许涉及的主要文件 |
|---|---|
| 遗物 | 当前遗物门面、`RelicManager`、遗物验证器及相关文档 |
| 角色 | `character_runtime.gd` 和角色数据访问验证器 |
| 敌人技能 | `enemy_skill_repository.gd` 和敌人技能数据访问验证器 |
| 融合技能 | `game_data.gd`、`synergy_manager.gd` 和融合技能验证器 |
| 战斗对象 | `game_data.gd`、`skill_effect_summary_builder.gd` 和战斗对象验证器 |
| 技能 | `data_manager.gd`、`game_data.gd`、`skill_manager.gd`、`character_run_initializer.gd` 和技能验证器 |
| 状态 | `game_data.gd`、`status_effect_manager.gd` 和状态验证器 |

`package.json` 只允许登记对应验证入口，不得调整已有验证脚本语义。

## 回滚

每个数据域必须能单独回滚：

1. 恢复该消费者原读取入口；
2. 删除该批次新增的 `GameData` 门面；
3. 如果适用，删除该批次新增的 `DataManager` accessor 和有序池；
4. 删除该批次验证器和 `package.json` 入口；
5. 恢复该批次工程文档描述；
6. 重新运行上一个稳定批次的完整门禁。

不得通过回滚一个批次撤销其他批次或用户已有修改。

## 完成标准

阶段 6 只有在以下条件全部满足时才完成：

- 当前遗物批次和所有剩余批次均独立通过验证；
- 已由 `DataManager` 持有的正式运行数据域通过稳定门面访问；
- 保留的直接 JSON 读取均有明确的服务、调试或所有权理由；
- 没有修改玩法、配置、顺序、UI、资源或存档结果；
- 没有新增循环依赖或重复 fallback；
- 工程文档与真实实现一致；
- 工作树差异中没有无关格式化和用户资产覆盖；
- 每个批次都有清晰回滚路径；
- 未经用户明确授权，没有提交、推送或创建 PR。
