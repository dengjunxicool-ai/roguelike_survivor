# 人物系统梳理

本文档基于当前项目代码重新梳理人物系统，目标是让后续新增、调整、迁移人物相关功能时，可以快速定位入口、数据、运行态、Trait、Modifier、起始技能、战斗、UI、结算等链路，并避免把人物逻辑散落到其他系统。

## 核心结论

当前人物系统已经形成比较清晰的数据驱动结构：

- 人物定义以 `data/characters.json` 为源头。
- 运行开始以 `RunLoadout` 为唯一人物载体。
- `Player.reset_for_loadout(loadout)` 是玩家重置人物运行态的唯一入口。
- `CharacterRuntime` 保存本局人物定义、起始技能和运行期 modifier。
- `CharacterRunInitializer` 负责把 loadout 应用到 Player，并绑定起始技能和 Trait。
- `CharacterTraitSystem` 只做事件、伤害吸收、modifier 查询的门面，具体 Trait 在 `scripts/characters/traits/*.gd` 中实现。
- 长期生效的数值来源进入 `ModifierStore`，战斗、移动、拾取、技能等系统通过 `ModifierAggregator` 按 scope 查询。
- 起始技能是人物系统与技能系统的边界：人物只声明 `starting_skill_id`，技能执行、升级和表现由技能系统消费。

后续人物改造应优先沿着这条主链路做，不要在 Player、SkillManager、DamageSystem、UI 中新增人物 ID 分支。

## 快速改造原则

后续所有人物相关需求先判断“状态归属”和“消费端”，再选入口：

| 需求类型 | 首选入口 | 不建议入口 |
| --- | --- | --- |
| 新人物、新起始技能 | `data/characters.json` + `CharacterLoadoutService` | UI 里手写技能列表 |
| 人物基础血量、移速、护甲、拾取等静态属性 | `base_stats` + `CharacterRunInitializer.apply_character_setup()` | 在 Player 初始化后零散覆盖属性 |
| 施法、移动、受伤、击杀触发的人物特性 | 具体 `CharacterTrait` 实现 + `TraitRegistry` | `Player` 或 `DamageSystem` 按人物 ID 分支 |
| 长期局内数值来源 | `ModifierStore`，通过 `set_run_modifier_source()` / `merge_run_modifier_source()` 写入 | 直接长期改 Player 快照字段 |
| 单技能数值 | `data/skills.json` 或 `SkillInstance.runtime_modifiers` | 人物系统直接改技能配置原始数据 |
| UI 展示和选择合法性 | `CharacterLoadoutViewModelBuilder` + `CharacterLoadoutText` + `CharacterLoadoutService` | UI 控件直接读散落数据并自行判定 |
| 结算、成长、挑战统计 | `RunResultStateBuilder` + `RunProgressionService` | 战斗中直接写成长存档 |

如果一个改动同时影响多个系统，优先让人物系统只产出“人物身份、起始技能、Trait 事件、modifier”，由消费系统按既有 query 或事件读取，不把消费端规则反向写回人物系统。

## 当前人物

| 人物 | Trait 类型 | 起始技能 |
| --- | --- | --- |
| `mage` | `skill_cast_stack` | `fireball` |
| `ranger` | `moving_bonus` | `fireball` |
| `paladin` | `passive_with_periodic_shield` | `fireball` |
| `alchemist` | `status_kill_random_area` | `fireball` |

`hp_lost_stack` 已注册为可用 Trait 类型，但当前 `characters.json` 中没有人物使用它。

## 分层地图

| 层级 | 文件 | 职责 |
| --- | --- | --- |
| 人物数据 | `data/characters.json` | 定义人物 ID、展示名、定位、基础属性、起始技能、解锁、视觉、Trait。 |
| 人物文案 | `data/character_texts.json` | 定义人物选择界面的 Trait、短板、难度、起始技能展示文案。 |
| 数据校验 | `tools/verify/verify_gods_and_skills_contract.js` + `tools/validate/validate_enemy_configs.js` | 校验当前技能、神系、敌人和波次配置入口。 |
| 冒烟校验 | `tools/verify/verify_fire_skill_runtime_smoke.gd` 等神系 runtime smoke | 验证起始技能、技能触发和关键运行链路。 |
| Loadout 服务 | `scripts/characters/character_loadout_service.gd` | 校验人物和起始技能合法性、生成 `RunLoadout`。 |
| Loadout 载体 | `scripts/characters/run_loadout.gd` | 本局人物的不可散参载体。 |
| 开局协调 | `scripts/game/run_scene_coordinator.gd` | 接收 `run_loadout`，创建运行场景，重置 spawner 和 player。 |
| 玩家宿主 | `scripts/player/player_controller.gd` | 持有人物运行节点、基础属性快照、移动拾取查询、受伤入口。 |
| 人物初始化 | `scripts/characters/character_run_initializer.gd` | 初始化 runtime、Trait、基础属性、起始技能、事件订阅。 |
| 人物运行态 | `scripts/characters/character_runtime.gd` | 保存人物定义、起始技能、运行期 modifier。 |
| Trait 门面 | `scripts/characters/character_trait_system.gd` | 对 Player 暴露 Trait 事件、伤害吸收、modifier 查询。 |
| Trait 控制器 | `scripts/characters/character_trait_controller.gd` | 创建具体 Trait、转发事件、同步 debug state。 |
| Trait 策略 | `scripts/characters/traits/*.gd` | 每个 `trait.type` 的独立行为实现。 |
| Trait 事件 | `scripts/characters/character_event_bridge.gd`, `scripts/characters/events/*.gd` | 标准化移动、施法、受伤、击杀和吸收事件。 |
| Modifier 查询 | `scripts/modifiers/modifier_query.gd` | 定义 `player`、`skill`、`movement`、`pickup`、`damage` scope。 |
| Modifier 存储 | `scripts/modifiers/modifier_store.gd` | 按来源和 scope 保存运行期 modifier。 |
| Modifier 聚合 | `scripts/modifiers/modifier_aggregator.gd` | 汇总 store、技能 runtime、技能被动、人物 Trait、遗物技能 modifier。 |
| 战斗伤害 | `scripts/combat/damage_system.gd`, `scripts/combat/application_stages/*.gd` | 计算输出伤害、玩家受伤、Trait 吸收和受伤完成事件。 |
| UI 入口 | `scripts/ui/ui_manager.gd`, `scripts/ui/screens/character_loadout_controller.gd` | 选择人物，构建 loadout，进入地图选择和开局。 |
| UI 展示 | `scripts/ui/screens/character_loadout_view_model_builder.gd`, `scripts/ui/screens/character_loadout_text.gd` | 把人物和起始技能数据组装成选择界面展示模型。 |
| 结算成长 | `scripts/game/run_progression_service.gd`, `data/progression_goals.json`, `data/challenges.json` | 按本局人物、地图记录成长、挑战、人物专精。 |

## 开局主链路

1. 人物选择界面持有 `selected_character_id`。
2. `CharacterLoadoutController` 展示当前人物和 `starting_skill_id` 对应的起始技能。
3. 确认选择后，`UIManager._on_loadout_confirmed()` 保存人物 ID。
4. 开始战斗时，`UIManager._start_run()` 调用 `CharacterLoadoutService.build_loadout()`。
5. `RunSceneCoordinator.start_run()` 只接受合法 `run_loadout`，不再接受人物散参。
6. `RunSceneCoordinator._reset_runtime_sources()` 调用 `Player.reset_for_loadout(loadout)`。
7. `Player.reset_for_loadout()` 重置基础运行状态，并确保 `CharacterRuntime`、`CharacterTraitSystem`、`ModifierStore`、`SkillManager`、`SkillExecutor` 等节点存在。
8. `CharacterRunInitializer.initialize_loadout()` 初始化 `CharacterRuntime` 和 `CharacterTraitSystem`。
9. `CharacterRuntime.initialize(character_id)` 读取人物定义，并暴露 `get_starting_skill_id()` 给起始技能绑定使用。
10. `CharacterRunInitializer.apply_character_setup()` 把人物 `base_stats`、视觉、run config 应用到 Player，并刷新 modifier 快照。
11. `CharacterRunInitializer.configure_starting_skills()` 读取人物 `starting_skill_id` 并加入 `SkillManager`，再把 `SkillEventBus.on_cast` 接到 `CharacterTraitSystem.handle_skill_bus_event()`。

这条链路是人物系统的主干。新增人物、切换人物、调试开局、推荐 loadout 都应该通过 `RunLoadout` 和 `reset_for_loadout()` 进入。

## 数据契约

`data/characters.json` 的人物定义应使用当前字段：

- `id`
- `display_name`
- `description`
- `role`
- `base_stats`
- `starting_skill_id`
- `unlock`
- `visual`
- `trait`

不应重新引入这些旧字段或旧 key：

- `character_id`
- `stats`
- `talent`
- `allowed_weapons`
- `allowed_weapon_ids`
- `unlock_condition`
- `crit_rate_add`
- `pickup_range_multiplier_add`
- `pickup_range_add`

拾取范围使用 `pickup_radius_*`，暴击使用 `crit_chance_*`。

`starting_skill_id` 是人物起始技能的唯一权威来源。UI、loadout 校验、冒烟测试都会围绕它运行。

## Trait 链路

`CharacterTraitSystem` 是 Player 下的轻量门面，内部由 `CharacterTraitController` 创建具体 Trait。

Trait 事件入口如下：

| 事件 | 入口 | 当前来源 |
| --- | --- | --- |
| 移动中或停止 | `CharacterTraitSystem.handle_movement()` | `Player._physics_process()` |
| 技能施放 | `CharacterTraitSystem.handle_skill_bus_event()` | `SkillEventBus.on_cast` |
| 玩家受伤前吸收 | `CharacterTraitSystem.request_damage_absorb()` | `PlayerAbsorbApplicationStage` |
| 玩家受伤完成 | `CharacterTraitSystem.handle_player_damaged()` | `PlayerHealthApplicationStage` |
| 敌人击杀 | `CharacterTraitSystem.handle_enemy_killed()` | `EnemyRewardController.notify_enemy_killed_synergies()` |
| modifier 查询 | `CharacterTraitSystem.get_modifiers(query)` | `ModifierAggregator` |

当前 Trait 映射：

| `trait.type` | 实现 | 行为重点 |
| --- | --- | --- |
| `skill_cast_stack` | `skill_cast_stack_trait.gd` | 技能施法叠层，受伤掉层，满层可额外 modifier。 |
| `moving_bonus` | `moving_bonus_trait.gd` | 持续移动获得加成，停止或受伤触发惩罚。 |
| `passive_with_periodic_shield` | `periodic_shield_trait.gd` | 周期护盾、受伤吸收、护盾存在时 modifier。 |
| `status_kill_random_area` | `status_kill_random_area_trait.gd` | 击杀带状态敌人时概率生成区域伤害。 |
| `hp_lost_stack` | `hp_lost_stack_trait.gd` | 按已损生命叠加 modifier。 |

新增 Trait 类型时，只做这些事：

1. 在 `scripts/characters/traits/` 新增 Trait 文件，继承 `CharacterTrait`。
2. 实现需要的 `setup()`、`process()`、`handle_event()`、`get_modifiers()`、`absorb_damage()`、`get_debug_state()`。
3. 在 `scripts/characters/traits/trait_registry.gd` 注册 `trait.type`。
4. 在对应数据契约或专项验证脚本中补充参数校验。
5. 在 `data/character_texts.json` 中补充展示文案。
6. 必要时扩展现有神系 runtime smoke 或新增专项验证。

不要在 `Player`、`CharacterTraitSystem`、`SkillManager` 或 `DamageSystem` 中按人物 ID 写 Trait 分支。

## Modifier 管线

当前 modifier 以 scope 区分使用场景：

| Scope | 用途 | 主要消费者 |
| --- | --- | --- |
| `player` | 基础人物属性快照和通用玩家属性 | `Player._apply_modifiers()` |
| `movement` | 移速运行期查询 | `Player._get_modifier_move_speed_multiplier()` |
| `pickup` | 拾取半径运行期查询 | `Player.get_effective_pickup_radius()` |
| `skill` | 技能数值计算 | `SkillStatService` |
| `damage` | 输出伤害计算 | `DamageSystem` |

`Player.set_run_modifier_source()` 和 `Player.merge_run_modifier_source()` 会根据 modifier key 推断 scope：

- 输出伤害类 key 进入 `damage` scope。
- 移动类 key 进入 `movement` scope。
- 拾取类 key 进入 `pickup` scope。
- 所有来源默认仍保留 `player` scope。

动态 scope key 不会写入 Player 快照，避免输出伤害、移动、拾取被重复应用。典型动态 key：

- `damage_multiplier`
- `damage_multiplier_add`
- `crit_chance_add`
- `crit_damage_add`
- `*_damage_multiplier_add`
- `move_speed_multiplier`
- `move_speed_multiplier_add`
- `pickup_radius_multiplier_add`
- `pickup_radius_add`

`ModifierAggregator.collect()` 的顺序和边界：

1. 先收集 `ModifierStore` 中匹配 scope 的来源。
2. `skill` scope 额外收集 `SkillInstance.runtime_modifiers`。
3. `skill` scope 额外收集 `SkillManager.passive_modifiers`。
4. 非 `damage` scope 收集人物 Trait modifier。
5. `skill` scope 额外收集 `RelicManager.get_relic_modifiers_for_skill()`。

注意：`damage` scope 不直接收集 Trait modifier，避免技能伤害包和 Trait provider 重复计算。人物如果需要影响输出伤害，应通过 Trait 在 `skill` scope 影响技能包，或通过长期 modifier 来源进入 `ModifierStore` 的 `damage` scope。

## 起始技能边界

人物系统拥有“当前人物从哪个技能开始”的运行态，但不直接负责技能完整成长逻辑。

### 起始技能

`CharacterRunInitializer.configure_starting_skills(player)` 优先读取 `data/characters.json.starting_skill_id`，找不到时回退到 `data/skills.json.starting_skills` 的第一项，然后调用 `SkillManager.add_skill()`。

后续人物相关技能改造，应优先通过 `CharacterRuntime.get_starting_skill_id()` 和技能系统的公开入口访问状态，不要外部直接拼散参。

## 战斗边界

人物系统和战斗系统的边界分为两类：输出伤害和玩家受伤。

### 输出伤害

技能、区域、反应等输出伤害最终通过 `DamageSystem.calculate()` 计算。人物相关输出 modifier 通过 `ModifierQuery.for_damage()` 或技能数值链路进入：

- 技能面板和冷却等数值通过 `SkillStatService.get_combined_modifiers()` 走 `skill` scope。
- 实际伤害计算通过 `DamageSystem._get_attacker_damage_modifiers_for_context()` 走 `damage` scope。
- 人物 Trait 不在 damage scope 里再次收集，避免重复。

### 玩家受伤

玩家受伤应用走 `DamageApplicationPipeline` 的玩家分支：

1. `Player.take_damage()` 调用 `DamageApplicationService.apply_player_damage()`。
2. `PlayerAbsorbApplicationStage` 调用 `CharacterTraitSystem.request_damage_absorb()`。
3. Trait 返回 `DamageAbsorbResult`，例如圣骑士护盾可以吸收伤害。
4. 剩余伤害进入 `DamageSystem.calculate()` 的玩家 incoming pipeline。
5. `PlayerHealthApplicationStage` 扣血，并调用 `CharacterTraitSystem.handle_player_damaged()`。

因此，新增“受伤前护盾、格挡、吸收”应放在 Trait 的 `absorb_damage()`；新增“受伤后掉层、触发惩罚、记录状态”应放在 Trait 的 `handle_event(PLAYER_DAMAGED)`。

### 击杀事件

`CharacterTraitSystem.handle_enemy_killed()` 和 `status_kill_random_area_trait.gd` 已经支持击杀事件。当前 UI 的敌人死亡连接主要用于击杀计数和 run stats。若新增依赖击杀的 Trait，需要确认敌人死亡桥接会把击杀事件显式转发到 `CharacterTraitSystem.handle_enemy_killed()`，否则 Trait 不会收到事件。

## UI 和结算边界

人物选择 UI 不应自己判断复杂规则：

- 起始技能来自 `data/characters.json.starting_skill_id`。
- 确认前合法性来自 `CharacterLoadoutService.get_validation_errors()`。
- 展示文本来自 `CharacterLoadoutText` 和 `character_texts.json`。

结算和成长系统读取本局结果中的：

- `selected_character_id`
- `starting_skill_id`
- `selected_map_id`
- `run_stats`

`RunProgressionService` 会更新人物专精、地图挑战和固定挑战。人物 ID 是存档、挑战、成长、推荐 loadout 的连接键，已发布 ID 不应直接改名。

## 常见改造路径

### 先定位影响面

改人物前先按下面顺序查影响面，可以最快判断是否会碰到其他系统：

1. 数据源：`data/characters.json`、`data/character_texts.json`、`data/progression_goals.json`、`data/challenges.json`。
2. 开局链路：`CharacterLoadoutService.build_loadout()`、`RunSceneCoordinator.start_run()`、`Player.reset_for_loadout()`。
3. 运行态：`CharacterRuntime` 是否已有 getter 或写入方法可复用。
4. 触发源：移动看 `Player._update_trait_movement()`，施法看 `SkillEventBus.on_cast`，受伤看玩家 damage application stage，击杀看 `EnemyRewardController.notify_enemy_killed_synergies()`。
5. 数值消费端：技能数值看 `SkillStatService` 的 `skill` scope，最终伤害看 `DamageSystem` 的 `damage` scope，移动和拾取看 Player 的运行期查询。
6. UI 和结算：选择页看 `CharacterLoadoutViewModelBuilder`，地图页只展示 loadout 摘要，结算成长看 `RunProgressionService`。

这个顺序能把改动限制在“数据、Trait、modifier、消费端”四个明确位置，避免为了一个人物效果同时改 Player、UI、战斗和存档。

### 新增人物，复用已有 Trait

1. 在 `data/characters.json` 添加人物。
2. 使用当前字段，尤其是 `id`、`base_stats`、`starting_skill_id`、`trait`。
3. 确认 `starting_skill_id` 对应 `data/skills.json.starting_skills` 中的技能。
4. 在 `data/character_texts.json` 添加人物展示文案。
5. 在 `data/progression_goals.json` 添加人物专精目标。
6. 如挑战引用新人物，在 `data/challenges.json` 添加对应配置。
7. 运行校验和冒烟测试。

### 新增人物，新增 Trait 类型

1. 先完成“新增 Trait 类型”的代码和校验。
2. 再在 `characters.json` 中使用新的 `trait.type`。
3. 给 Trait 参数加严格 schema，避免运行时靠默认值吞错。
4. 如果 Trait 跨到战斗对象、状态、敌人死亡、玩家受伤，补充专项 smoke 或验证脚本。

### 调整人物基础数值

1. 修改 `data/characters.json` 的 `base_stats`。
2. 如果是输出伤害类字段，确认它属于 Player 快照还是 damage scope。
3. 如果是移动或拾取字段，确认 key 是否会被动态 scope 排除。
4. 跑人物配置校验和 smoke。

### 新增人物运行期增益

优先选择下面的入口：

- 人物 Trait 的动态效果：写在具体 Trait 的 `get_modifiers()`。
- 长期 run 来源：调用 `Player.set_run_modifier_source()` 或 `merge_run_modifier_source()`。
- 单技能局部变化：写入 `SkillInstance.runtime_modifiers`。
- 起始技能或可学习技能变化：优先修改 `data/skills.json`，运行期临时变化再写 `SkillInstance.runtime_modifiers`。

不要直接长期写 Player 属性，也不要绕过 `ModifierStore`。

### 新增人物和怪物或战斗交互

1. 如果是输出伤害，优先确认伤害包字段、`skill` scope、`damage` scope。
2. 如果是受伤前吸收，写 Trait 的 `absorb_damage()`。
3. 如果是受伤后效果，写 Trait 的 `handle_event(PLAYER_DAMAGED)`。
4. 如果是击杀触发，确保死亡事件桥接到 `CharacterTraitSystem.handle_enemy_killed()`。
5. 如果要生成区域、召唤物或弹体，参考 `status_kill_random_area_trait.gd` 通过战斗对象工厂创建，不要在 Player 里生成。

## 不应做的事

- 不要恢复 `reset_for_run(character_id)` 或其他人物散参入口。
- 不要让 `RunSceneCoordinator.start_run()` 接受散参人物。
- 不要把具体人物 ID 分支写进 `Player`、`SkillManager`、`DamageSystem`、`UIManager`。
- 不要把 Trait 类型分支写回 `CharacterTraitSystem`，新增 Trait 应走 `TraitRegistry`。
- 不要直接访问旧的 `runtime_modifiers` 公共字段，使用 `CharacterRuntime.add_runtime_modifiers()`、`clear_temporary_modifiers()`。
- 不要把输出伤害 modifier 只写入 Player 快照，应进入 `damage` scope。
- 不要把移动、拾取、伤害动态 key 当作普通 player 快照字段使用。
- 不要重新引入 `allowed_weapons`、`talent`、`stats`、`character_id` 等旧数据结构。

## 风险点

1. 人物 ID 关联存档、成长、挑战、UI 推荐，不能随意改名。
2. `starting_skill_id` 是人物起始技能唯一权威来源，技能侧不要再维护另一套角色默认技能。
3. `CharacterRuntime` 保存人物定义和起始技能查询，改它会影响起始技能、Trait 查询和 HUD 展示。
4. `ModifierAggregator` 在 `damage` scope 排除了 Trait provider，改这个规则容易造成伤害重复计算。
5. `Player._apply_modifiers()` 是属性快照刷新器，不是新增长期数值系统的首选入口。
6. `status_kill_random_area` 跨到敌人状态、击杀事件、区域伤害和 run stats，改动时要联测战斗对象创建和击杀桥接。
7. `passive_with_periodic_shield` 参与受伤吸收，改动时要联测玩家受伤 pipeline。
8. 当前环境未发现可用 Godot CLI，脚本编译仍需要在编辑器或可用 Godot 命令行环境中确认。

## 验证清单

人物相关改造后至少运行：

```powershell
node tools\verify\verify_gods_and_skills_contract.js
node tools\verify\verify_skill_definition_schema.js
node tools\verify\verify_skill_rule_adapters.js
node tools\validate\validate_enemy_configs.js
```

涉及起始技能或神系运行时时，额外运行：

```powershell
node tools\verify\verify_fire_skill_system_contract.js
node tools\verify\verify_frost_skill_system_contract.js
node tools\verify\verify_thunder_skill_system_contract.js
```

涉及伤害公式时，额外在 Godot 环境中运行或打开对应验证：

```powershell
tools\verify\verify_damage_formula.gd
```

最终还需要在 Godot 编辑器中至少手动验证：

- 每个人物都能进入战斗。
- 每个人物起始技能展示正确。
- 起始技能能正常施放。
- Trait 的核心触发条件有效。
- 技能升级不会丢失当前人物运行态。
- 受伤、死亡、结算和人物成长记录正常。
