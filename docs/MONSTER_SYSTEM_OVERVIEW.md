# 怪物系统梳理

本文档用于后续快速、安全地改造所有怪物相关功能。目标不是重复函数索引，而是明确“改什么应该先看哪里、会影响哪些系统、验证什么才算安全”。当前怪物系统已经从早期集中式逻辑拆成数据驱动结构：怪物定义在 `data/enemies.json`，敌方技能定义在 `data/enemy_skills.json`，波次和 Boss encounter 定义在 `data/waves.json`；运行时由 `EnemySpawner` 作为场景门面，委托 `timeline/`、`spawning/`、`behaviors/`、`skills/`、`actions/`、`death/` 等模块完成实际工作。

本文档按 2026-06-12 当前项目代码梳理。后续任何敌人相关需求，优先按下面顺序定位：先判断是数据调参、生成时间线、行为决策、技能动作、伤害应用、死亡副作用，还是跨系统展示/统计；再进入对应文件。不要从 `EnemyBase` 或 `EnemySpawner` 直接扩散改动，除非需求本身就是改生命周期入口或场景门面信号。

## 当前结论

- 当前共有 16 个怪物：11 个 `normal`、4 个 `elite`、1 个 `boss`。
- 当前共有 15 个敌方技能：9 个普通 active 技能，6 个 `boss_phase` 技能。
- 当前共有 8 个普通 wave；Boss 由 `waves.boss_event` 生成，Boss 小怪由 `boss_event.minion_spawn` 控制，不再作为普通 wave 存在。
- 当前行为类型共有 7 个：`chase_player`、`keep_distance_and_shoot`、`explode_near_player`、`summon_and_chase`、`chase_and_cast_pool`、`dash_attack`、`boss_dungeon_heart`。
- 未知或缺失 `behavior.type` 不再回退到默认追击行为；配置校验和运行时都会报错。
- 远程、召唤、毒池、自爆等行为依赖 `enemy_skills.json` action；缺失必需 action 会被 `tools/validate_enemy_configs.js` 拦截。
- Boss phase 必须显式配置在 `enemies.json.behavior.phases`；`phase_thresholds` 和运行时默认三阶段都不再支持。
- 死亡副作用统一走 `EnemyDeathPipeline`；自爆通过 `death_policy.self_explosion` 控制是否掉经验、魂石、死亡效果和击杀事件。

## 改造总原则

| 需求类型 | 优先落点 | 不要优先改 |
| --- | --- | --- |
| 只改数值、出现时间、怪物组合 | `data/enemies.json`、`data/waves.json` | `EnemyBase`、`EnemySpawner` |
| 新增普通/精英怪 | `data/enemies.json` + 复用现有 behavior/skill | 新增硬编码 ID 分支 |
| 新增敌方动作效果 | `data/enemy_skills.json` + `EnemyActionRegistry` | `EnemyActionExecutor` 或行为类里直接实例化效果 |
| 新增行为模式 | `scripts/enemies/behaviors/*` + `EnemyBehaviorRegistry` + 校验脚本 | 在 `EnemyBase._physics_process()` 写分支 |
| 新增 Boss 阶段机制 | `behavior.phases` + `boss_phase` enemy skill/action | 恢复隐式 phase 或按血量写死逻辑 |
| 改敌人受击/承伤 | `DamageSystem`、敌人 application stages、承伤配置 | 直接改 `current_health` |
| 改死亡奖励/击杀触发 | `death_policy`、`EnemyDeathPipeline`、`EnemyRewardController` | 直接 `queue_free()` |
| 地图或活动刷怪 | `EnemySpawner.spawn_map_enemy()`、`EnemySpawnRequest` | 地图脚本手动 instantiate 敌人 |

默认判断方式：

1. 能用 JSON 表达的先用 JSON。
2. 能扩展 action 的不要新增 behavior。
3. 能新增 behavior 的不要扩大 `EnemyBase`。
4. 能走 `EnemySpawnService` 的不要手动实例化。
5. 能走 `EnemyDeathPipeline` 的不要直接释放节点。
6. 新增可配置类型必须同步 `tools/validate_enemy_configs.js`，否则后续改造会失去护栏。

## 核心文件

| 层级 | 文件 | 职责 |
| --- | --- | --- |
| 怪物数据 | `data/enemies.json` | 怪物 ID、类型、基础属性、行为、技能引用、死亡策略、视觉配置。 |
| 敌方技能数据 | `data/enemy_skills.json` | 敌方技能定义和 action 参数。普通行为与 Boss phase 都通过这里执行动作。 |
| 波次数据 | `data/waves.json` | 普通 wave、刷怪组、倍率、精英事件、Boss encounter、Boss 小怪和奖励事件。 |
| 配置校验 | `tools/validate_enemy_configs.js` | 校验怪物、技能、波次、Boss phase、死亡策略、必需 action 和跨文件引用。 |
| 场景入口 | `scenes/enemy.tscn`、`scenes/boss.tscn` | 怪物和 Boss 场景。Boss 场景使用 `BossController`，继承 `EnemyBase`。 |
| 刷怪门面 | `scripts/enemies/enemy_spawner.gd` | 场景节点入口，保留 UI 信号、旧私有包装方法、运行修正和地图刷怪入口。 |
| 时间线 | `scripts/enemies/timeline/*` | 普通 wave、Boss encounter、Boss 小怪、清场、经验收集、奖励事件、选组。 |
| 生成服务 | `scripts/enemies/spawning/*` | 统一实例化怪物，写入倍率、分类 meta、来源 meta、奖励策略和位置。 |
| 怪物主体 | `scripts/enemies/enemy_base.gd` | 生命周期聚合点：读取配置、受击、状态、接触伤害、死亡入口、视觉和控制器初始化。 |
| 行为层 | `scripts/enemies/behaviors/*` | 按 `behavior.type` 创建行为对象，每帧驱动移动、预警和触发技能 action。 |
| 技能层 | `scripts/enemies/skills/*` | 读取 `enemy_skills.json`，按 action 类型或 skill id 执行敌方技能。 |
| Action 层 | `scripts/enemies/actions/*` | 执行 projectile、damage_area、summon、自爆、接触状态、Boss phase 等动作。 |
| 死亡层 | `scripts/enemies/death/*` | 统一处理死亡策略、奖励、事件、死亡效果、经验掉落和释放节点。 |
| 奖励/统计副作用 | `scripts/enemies/enemy_reward_controller.gd` | 魂石、协同增伤、Boss 核心减伤、击杀事件、伤害统计。 |
| 伤害包 | `scripts/enemies/combat/enemy_damage_packet_builder.gd` | 构造敌方 DamagePacket，避免吃到玩家输出倍率、暴击等规则。 |

## 主链路

### 启动与数据读取

1. `DataManager.load_all()` 读取 `data/enemies.json`、`data/enemy_skills.json`、`data/waves.json` 并按 id 建索引。
2. `GameData` 是静态数据门面，优先从 `/root/DataManager` 取深拷贝；缺失时直接读 JSON。
3. 运行时不要直接修改 `GameData` 返回的配置 Dictionary。动态倍率应走实例属性、Spawner modifier 或 `EnemySpawnRequest`。

### 单局开始与刷怪

1. `RunSceneCoordinator.start_run()` 创建或复用 `main.tscn`，清理旧怪物、经验晶体和地图 hazard。
2. `EnemySpawner.reset_for_run()` 重置 wave、Boss、奖励事件、运行时间和倍率。
3. `EnemySpawner._physics_process()` 委托 `EnemyTimelineController.process(delta)`。
4. `EnemyTimelineController` 每帧推进 `_elapsed_time`，清理过远怪物，处理奖励事件，处理 Boss 事件；若 Boss 已激活则处理 Boss 小怪，否则处理普通 wave。

### 普通 Wave

1. `WaveDirector.start_wave(index)` 读取 `waves[index]`，设置当前 wave id、持续时间、总生成数量和 UI 计时信号。
2. `WaveDirector.process_wave_spawn()` 按 `spawn_interval`、`max_alive`、全局 `_max_normal_enemies_alive` 和剩余总量决定是否刷怪。
3. `SpawnGroupPicker` 先按 group weight 选组，再从 `enemy_ids` 中随机选一个怪物 id。
4. `EnemySpawner._spawn_from_group_config()` 计算本次刷怪数量，叠加 `enemy_multipliers` 后调用 `_spawn_enemy()`。
5. `_spawn_enemy()` 组装 `EnemySpawnRequest`，交给 `EnemySpawnService.spawn()` 统一实例化。

### Boss Encounter

1. 普通 wave 走完后 `EnemySpawner._finish_normal_phase()` 标记普通阶段完成，并自动收集经验晶体。
2. `BossEncounterController.process_boss_event()` 读取 `waves.boss_event`，可按配置先清理普通怪和 Boss 小怪。
3. Boss 通过 `_spawn_enemy(boss_id, use_boss_scene=true, ..., enemy_type_override="boss", source_type="boss")` 生成，并连接 `died` 信号到 `EnemySpawner._on_boss_died()`。
4. Boss 激活后 `process_boss_minion_spawn(delta)` 按 `boss_event.minion_spawn` 刷 Boss 小怪。Boss 小怪 `enemy_type` 为 `boss_minion`，默认不走普通 wave 计数。
5. Boss 死亡时 Spawner 发出 `boss_defeated(elapsed_time)`，UI 和结算链路据此进入胜利。

### 怪物实例初始化

1. `EnemySpawnService.spawn()` 在 add_child 前写入 `enemy_id`、倍率、分类 override、来源 meta、奖励策略等 pre-ready 值。
2. `EnemyBase._ready()` 把节点加入 `enemy` 和 `enemies` group，初始化视觉、状态、行为、技能、奖励、死亡等控制器。
3. `EnemyBase._apply_enemy_config()` 从 `GameData.get_enemy(enemy_id)` 读取配置，写入基础属性、行为配置、技能引用、死亡策略、死亡效果、视觉配置和碰撞半径。
4. `_apply_classification_metadata()` 写入 `enemy_type`、`enemy_rank`、`is_boss`、`is_elite`，并将 Boss/Elite 加入 `bosses`/`elites` group。
5. `EnemyBehaviorController.setup()` 根据 `behavior.type` 创建行为对象；`EnemySkillController.setup()` 解析 `skills[].skill_id` 到 `enemy_skills.json` 定义。

### 行为与技能

1. `EnemyBase._physics_process()` 每帧处理状态、冻结、技能 tick、目标寻找、行为 tick、移动、视觉和接触伤害。
2. 行为对象只负责“什么时候做事”和“怎么移动”；具体 projectile、damage_area、summon、自爆等动作由 `EnemySkillController` 和 `EnemyActionRegistry` 执行。
3. `EnemyBehavior._execute_required_action()` 是普通行为触发必需 action 的统一入口。执行失败会报错，不会回退旧动作。
4. Boss 行为 `BossDungeonHeartBehavior` 会调用 `_update_boss_skill_cooldowns()` 和 `_process_boss_phase_skills()`；Boss phase 通过 `skill_id` 调用 `EnemySkillController.execute_skill_id()`。
5. `EnemyActionRegistry` 当前支持：`projectile`、`damage_area`、`summon`、`self_explode`、`dash`、`contact_status`、`ring_projectiles`、`delayed_area_blast`、`shockwave`、`corruption_gaze`、`corrupted_cores`。

### 受击、状态和死亡

1. 玩家技能、投射物、区域效果和状态 DOT 最终调用 `EnemyBase.take_damage()` 或 `EnemyBase.apply_status()`。
2. `take_damage()` 进入 `DamageApplicationService.apply_enemy_damage()`，再走敌人伤害流水线：预检查、伤害计算、协同修正、Boss 核心减伤、扣血。
3. 敌人扣血阶段会写入 `last_damage_*` meta，记录伤害统计，显示伤害数字，血量归零时调用 `_die()`。
4. `_die()` 调用 `_finish_death("damage")`；自爆 action 调用 `_finish_death("self_explosion")`。
5. `EnemyDeathPipeline.execute()` 按 policy 决定是否播放死亡视觉、记录 Boss 核心、发魂石、触发击杀事件、发 `died` 信号、执行死亡效果、掉经验晶体和 `queue_free()`。
6. 召唤怪通过 `EnemySpawnRequest.summon()` 写入 `reward_policy.award_soul=false`，经验倍率默认为 `0.25`；自爆默认不掉经验、不发魂石、不跑死亡效果，但保留击杀事件和 `died` 信号。

## 数据契约

### `data/enemies.json`

| 字段 | 消费方 | 改造注意 |
| --- | --- | --- |
| `id` | `GameData`、wave、地图预览、技能和调试工具 | 稳定主键。改名必须同步所有引用。 |
| `display_name` | 图鉴、地图预览、调试面板 | 仅展示，不参与逻辑。当前部分中文内容已有乱码风险，修改时必须保持 UTF-8。 |
| `type` | `EnemyBase._apply_classification_metadata()` | 支持 `normal`、`elite`、`boss`。会写入 `enemy_type` 和默认 `enemy_rank`。 |
| `base_stats.max_hp` | `EnemyBase` | 生成时乘 `health_multiplier`，至少为 1。 |
| `base_stats.move_speed` | 行为移动、状态减速 | 生成时乘 `move_speed_multiplier`；Boss 核心会在 post-ready 设置为 0。 |
| `base_stats.contact_damage` | 接触、近战、默认敌方技能伤害 | 生成时乘 `damage_multiplier`。 |
| `base_stats.attack_range` | 近战、行为范围、Boss 技能范围 fallback | 缺失时会按行为类型从 `behavior` 推导，但配置校验要求存在。 |
| `base_stats.contact_interval` / `damage_interval` | 接触伤害冷却 | 运行时优先读 `contact_interval`，再兼容 `damage_interval`。 |
| `base_stats.armor` / `defense` | DamageSystem、调试、显示 | `EnemyBase` 当前写入 `armor`；`defense` 主要作为配置兼容字段。 |
| `base_stats.resistances` | DamageSystem | 影响元素/类型抗性。改 Boss/Elite 抗性时要测 DOT、区域、反应、真实伤害。 |
| `base_stats.exp_drop` | `EnemyDeathPipeline` | 生成时乘 `experience_multiplier`；死亡后掉经验晶体。 |
| `base_stats.soul_drop` | `EnemyRewardController` | 按玩家 `soul_gain_multiplier` 结算到 SaveManager。 |
| `base_stats.collision_radius` | `EnemyBase._apply_collision_radius()` | 直接改 `CollisionShape2D` 圆半径。 |
| `behavior.type` | `EnemyBehaviorController` | 必填且必须注册。未知类型会报错。 |
| `behavior.*` | 对应行为类 | 行为参数仍是弱类型 Dictionary；新增字段要同步文档和校验。 |
| `skills` | `EnemySkillController` | 引用 `enemy_skills.json.enemy_skills[].id`。行为必需 action 由校验器强制覆盖。 |
| `death_policy` | `EnemyDeathPipeline` | 按 cause 覆盖死亡副作用。当前 cause：`default`、`damage`、`self_explosion`。 |
| `death_effect` | `EnemyActionExecutor.apply_death_effect()` | 当前支持 `poison_pool`、`spawn_enemies`。复杂死亡效果建议后续 action 化。 |
| `visual` | `EnemyVisualController` | 空配置使用场景默认视觉；非空配置按状态播放。 |

### `data/enemy_skills.json`

| 字段 | 消费方 | 改造注意 |
| --- | --- | --- |
| `id` | `enemies.json.skills[].skill_id`、Boss phase `skill_id` | 稳定主键。校验器会检查引用存在。 |
| `runtime` | 校验器、Boss phase 约束 | 默认 `active`；Boss phase 技能必须显式为 `boss_phase`。 |
| `cooldown` | `EnemySkillController.get_cooldown_for_action()` | 怪物实例 `skills[].cooldown` 可覆盖技能默认冷却。 |
| `actions[].type` | `EnemyActionRegistry` | 新增 action 必须同时扩展 registry 和校验 schema。 |
| `actions[].params.element` / `damage_type` | `EnemyDamagePacketBuilder` | 敌方 projectile 和 area 必须显式表达元素和伤害类型，避免吃错玩家规则。 |

### `data/waves.json`

| 字段 | 消费方 | 改造注意 |
| --- | --- | --- |
| `run.duration_seconds` | UI、统计、时间线 | 总时长。普通阶段仍以 wave 是否走完为主。 |
| `run.boss_spawn_time` | `EnemySpawner._apply_timeline_config()` | 会被限制在普通阶段时长内。 |
| `waves[].duration_seconds` | `WaveDirector.start_wave()` | 当前使用离散 wave，每个 wave 独立计时。 |
| `waves[].spawn_interval` | `WaveDirector.process_wave_spawn()` | 刷怪冷却。 |
| `waves[].max_alive` | `WaveDirector`、`EnemyCleanupService` | 单 wave 存活上限，同时受全局 `_max_normal_enemies_alive` 限制。 |
| `waves[].groups` | `SpawnGroupPicker` | 按 weight 选组，组内从 `enemy_ids` 随机选一个 id。 |
| `count_min/count_max` | `_spawn_from_group_config()` | 单次刷怪数量范围；未配默认 1。 |
| `enemy_multipliers` | `EnemySpawnMultipliers` | 支持 `hp`、`damage`、`speed`/`move_speed`、`exp`、`defense_add`。 |
| `events[].type=spawn_elite` | `EnemySpawner._start_wave_event()` | 当前实际刷怪事件是 `spawn_elite`；其它事件主要广播 UI。 |
| `boss_event.boss_id` | `BossEncounterController` | Boss 怪物 id，必须存在且 `type=boss`。 |
| `boss_event.clear_normal_enemies_on_spawn` | `EnemyCleanupService` | Boss 出现前是否清普通怪和 Boss 小怪。 |
| `boss_event.minion_spawn` | `BossEncounterController` | Boss 小怪配置，包含启用、上限、间隔、倍率和 groups。 |

## 当前怪物与行为分布

| 怪物 | 类型 | 行为 | 技能 |
| --- | --- | --- | --- |
| `small_slime` | normal | `chase_player` | 无 |
| `skeleton` | normal | `chase_player` | 无 |
| `bat` | normal | `chase_player` | 无 |
| `archer_skeleton` | normal | `keep_distance_and_shoot` | `arrow_shot` |
| `toxic_bug` | normal | `chase_player` | `poison_contact` |
| `bomber` | normal | `explode_near_player` | `self_explode` |
| `armored_skeleton` | normal | `chase_player` | 无 |
| `skeleton_priest` | normal | `summon_and_chase` | `minor_summon` |
| `war_drum_goblin` | normal | `chase_and_cast_pool` | `war_drum` |
| `gem_slime` | normal | `chase_player` | 无 |
| `shadow_hunter` | normal | `dash_attack` | `shadow_dash` |
| `giant_slime` | elite | `chase_player` | 无 |
| `skeleton_captain` | elite | `dash_attack` | `captain_charge` |
| `toxic_matriarch` | elite | `chase_and_cast_pool` | `toxic_pool` |
| `lava_golem` | elite | `chase_and_cast_pool` | `lava_pool` |
| `dungeon_heart` | boss | `boss_dungeon_heart` | `red_circle`、`ring_bullets`、`summon_minions`、`shockwave`、`corruption_gaze`、`corrupted_cores` |

## 跨系统边界

| 系统 | 连接点 | 安全边界 |
| --- | --- | --- |
| 玩家受击 | 敌人接触、敌方 projectile、敌方 damage_area 最终调用 `Player.take_damage()` | 敌方伤害必须用 `EnemyDamagePacketBuilder` 或等价字段，不能吃玩家倍率和暴击。 |
| 玩家技能选怪 | `TargetingService` 扫描 `enemies` group，并检查 `_is_dead`、`current_health` | 新怪必须从 `EnemyBase._ready()` 正常进入 group；不要手动绕过初始化。 |
| 状态系统 | `EnemyStatusFacade` 代理 `StatusEffectManager` | 新控制效果优先扩展状态系统，行为层只消费冻结、减速、易伤结果。 |
| 伤害系统 | `DamageApplicationService`、`DamageSystem`、application stages | 改护甲、抗性、Boss/Elite 减免时要测直接伤害、DOT、区域、反应和 Boss 核心。 |
| 击杀事件 | `EnemyDeathPipeline` -> `EnemyRewardController.notify_enemy_killed_synergies()` | 不能直接 `queue_free()` 杀怪，否则协同、角色特质、技能事件会丢。 |
| UI/HUD | Spawner 信号、敌人 `died` 信号、`RunSceneUIBridge` | 改 wave、Boss 胜利、死亡信号时要检查 UI 是否仍能记录击杀和结算。 |
| 统计 | `RunStatsTracker` | 伤害统计由受击流水线记录，击杀统计由 UI 连接 `died` 后记录，Boss 核心由奖励控制器记录。 |
| 地图变量 | `MapVariableRuntime` | 地图可通过 `apply_run_modifiers()` 改刷怪压力，或调用 `spawn_map_enemy()` 走 Spawner。 |
| 地图预览/图鉴 | `MapSelectController`、`CodexViewModelBuilder` | 新怪若要展示，需要同步地图预览 id、视觉图标和文案。 |
| 调试工具 | `DevDebugPanel`、`scripts/debug/*_check.gd` | 新行为、新 action、新 Boss 机制建议补 debug 检查，避免后续改造失去护栏。 |

## 功能定位索引

| 要改的功能 | 先看 | 需要同步 | 必跑验证 |
| --- | --- | --- | --- |
| 敌人基础属性 | `data/enemies.json.base_stats` | `tools/validate_enemy_configs.js` 必填字段 | `node tools\validate_enemy_configs.js` |
| 敌人移动/攻击节奏 | 对应 `scripts/enemies/behaviors/*`、`behavior` 参数 | 行为必需 action、冷却字段、预警表现 | `enemy_skill_system_check.gd` |
| 敌人远程弹幕 | `enemy_skills.json` 的 `projectile`/`ring_projectiles` action | `EnemyActionRegistry`、`EnemyDamagePacketBuilder` 参数 | `enemy_skill_system_check.gd` |
| 敌人地面范围 | `enemy_skills.json` 的 `damage_area`/Boss area action | action 参数 schema、元素/伤害类型 | `enemy_skill_system_check.gd` |
| 召唤物 | `summon` action、`EnemySpawnRequest.summon()` | 奖励策略、经验倍率、source meta | `enemy_skill_system_check.gd` |
| 自爆怪 | `explode_near_player`、`self_explode` action、`death_policy.self_explosion` | 是否掉经验/魂石/击杀事件 | `enemy_skill_system_check.gd` |
| 普通波次 | `data/waves.json.waves[]`、`WaveDirector` | wave UI 信号、经验自动收集、生成上限 | `wave_system_check.gd` |
| 精英事件 | `waves[].events[]`、`EnemySpawner._start_wave_event()` | `VALID_WAVE_EVENT_TYPES`、event 倍率 | `validate_enemy_configs.js` |
| Boss 出场 | `data/waves.json.boss_event`、`BossEncounterController` | Boss 死亡信号、UI 胜利、Boss 小怪 | `enemy_timeline_system_check.gd` |
| Boss 阶段技能 | `enemies.json.behavior.phases`、`enemy_skills.json` 的 `boss_phase` | `checkBossBehaviorConfig()`、action schema | `enemy_skill_system_check.gd` |
| 敌人承伤 | `DamageApplicationPipeline._enemy_stages()`、`EnemyRewardController` | 统计、弹字、Boss 核心减伤 | 伤害专项 + `wave_system_check.gd` |
| 死亡奖励/击杀事件 | `EnemyDeathPipeline`、`EnemyRewardController`、`death_policy` | 经验晶体、魂石、协同、角色特质、技能事件 | `enemy_timeline_system_check.gd` |
| 地图刷怪压力 | `EnemySpawner.apply_run_modifiers()`、`spawn_map_enemy()` | `MapVariableRuntime`、地图配置、source type | 地图相关 smoke + `validate_enemy_configs.js` |

## 快速改造路径

### 新增普通怪或精英怪

1. 在 `data/enemies.json.monsters` 增加唯一 `id`、`type`、`base_stats`、`behavior`、`skills`、`visual`。
2. 如果复用现有行为，只改 `behavior` 参数和 `skills` 引用。
3. 如果需要新动作，先在 `data/enemy_skills.json` 增加 action，再在怪物 `skills` 中引用。
4. 如果需要新行为，新建 `scripts/enemies/behaviors/xxx_behavior.gd`，在 `EnemyBehaviorRegistry` 注册，并在 `tools/validate_enemy_configs.js` 加入合法类型和必需 action。
5. 在 `data/waves.json` 的 `groups[].enemy_ids` 或 `events[]` 中引用新怪。
6. 需要地图预览时，补 `data/maps.json` 的 `enemy_preview_ids`、`elite_preview_ids` 或 `boss_id`。
7. 跑 `node tools/validate_enemy_configs.js` 和相关 Godot debug check。

### 新增敌方技能或 action

1. 优先在 `data/enemy_skills.json` 新增技能，不要把具体动作写回 `EnemyBase`。
2. 现有 action 能表达时只加数据：`projectile`、`damage_area`、`summon`、`contact_status`、`self_explode`、Boss phase action 等。
3. 现有 action 不够时，扩展 `EnemyActionRegistry.execute()` 和参数执行逻辑。
4. 同步扩展 `tools/validate_enemy_configs.js` 的 `VALID_ENEMY_ACTION_TYPES` 和 `ENEMY_ACTION_PARAM_SCHEMAS`。
5. 如某行为必须依赖该 action，同步扩展 `REQUIRED_ACTIONS_BY_BEHAVIOR`。
6. 补 `scripts/debug/enemy_skill_system_check.gd` 或新增专门检查。

### 新增 Boss 或 Boss 阶段机制

1. 在 `data/enemies.json` 增加 `type="boss"` 怪物。
2. 复用 `boss_dungeon_heart` 时，必须配置显式 `behavior.phases`；每个 phase 的 `skills[].skill_id` 必须引用 `runtime="boss_phase"` 的 enemy skill。
3. 如果是全新 Boss 行为，新建 behavior 类并注册，不要在 `EnemyBase` 增加 Boss 专用分发。
4. 在 `data/waves.json.boss_event.boss_id` 指向新 Boss，必要时调整 `boss_multipliers`、`fairness` 和 `minion_spawn`。
5. 验证 Boss `died` 信号能触发 `EnemySpawner._on_boss_died()` 和 UI 胜利结算。

### 调整波次节奏

1. 小幅调数优先改 `waves[].enemy_multipliers`、`spawn_interval`、`max_alive`、`count_min/count_max`。
2. 调怪物组成改 `groups[].enemy_ids` 和 `weight`。
3. 插入精英事件改 `events[]`，当前真正生成逻辑是 `spawn_elite`。
4. 改 Boss 时间时同时看 `run.duration_seconds`、`run.boss_spawn_time`、所有 wave `duration_seconds`、`BossEncounterController` 和 UI 计时。

### 调整怪物承伤

1. 基础生存改 `base_stats.max_hp`、`armor`、`resistances`。
2. 波次成长改 `waves[].enemy_multipliers.hp` 和 `defense_add`。
3. Boss/Elite 特殊减免看 `DamageSystem`、`TargetDamageProfileResolver` 和 `EnemyRewardController.apply_boss_core_damage_reduction()`。
4. 每次改承伤都至少验证：直接伤害、DOT、区域伤害、反应伤害、Boss 核心状态。

### 调整怪物对玩家伤害

1. 接触/近战改 `base_stats.contact_damage`、`attack_range`、`contact_interval`。
2. 远程改 `enemy_skills.json` projectile action；前摇、预警宽度、预警距离在 `behavior` 参数里。
3. 区域伤害改 `enemy_skills.json` damage_area action；元素、damage_type、颜色都放在 action params。
4. Boss 技能改 `behavior.phases[].skills[]` 的显式参数和对应 `boss_phase` skill action。

### 调整死亡奖励或击杀触发

1. 经验改 `base_stats.exp_drop` 或 wave `enemy_multipliers.exp`。
2. 魂石改 `base_stats.soul_drop`。
3. 自爆、召唤、Boss 核心等特殊掉落改 `death_policy` 或生成时 `reward_policy`。
4. 死亡特效改 `death_effect`；复杂死亡机制建议后续迁入 action 化结构。
5. 不要绕过 `EnemyDeathPipeline`，否则击杀事件、技能事件、统计和奖励会不完整。

## 风险点

1. `enemy_type` 和 `enemy_rank` 都在使用。`EnemyBase` 会写二者，但外部系统有的读 `enemy_type`，有的读 `enemy_rank`，有的读 group。新增分类时要验证三者一致。
2. `EnemySpawner` 仍保留很多旧私有包装方法给 debug、UI 和测试调用。不要把新主逻辑继续塞回 Spawner；应该下沉到 timeline、spawning 或对应服务。
3. `EnemyActionExecutor` 当前仍承担自爆爆炸、死亡效果、召唤实例、Boss 核心生成等工具职责。普通技能动作主链路已经在 `EnemyActionRegistry`；新增普通攻击不要扩展 executor。
4. 自爆怪默认通过 `death_policy.self_explosion` 不掉经验、不发魂石、不跑死亡效果，但会触发击杀事件和 `died` 信号。改这个行为会影响资源产出和 UI 统计。
5. 召唤怪通过 `EnemySpawnRequest.summon()` 默认 `award_soul=false`，经验倍率为 `0.25`。改召唤收益前要评估刷资源风险。
6. Boss 小怪不在普通 wave 中，校验器会阻止 `boss_minions` 作为普通 wave 回来。
7. `display_name` 和部分文档/数据中文在终端中存在乱码表现。改中文文案时要先确认文件编码，跑 `node tools/check_text_encoding.js`。
8. `wave_system_check` 和 `visual_config_check` 覆盖了一些时序行为。改经验自动收集、调试刷怪、远程预警时要复跑它们。

## 验证清单

基础校验：

```powershell
node tools\validate_enemy_configs.js
node tools\check_text_encoding.js
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --quit
```

怪物链路校验：

```powershell
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . -s res://scripts/debug/enemy_skill_system_check.gd
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . -s res://scripts/debug/enemy_timeline_system_check.gd
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . -s res://scripts/debug/wave_system_check.gd
& 'C:\Users\dengj\Desktop\Godot.exe' --headless --path . --script res://tools/verify_enemy_health_lag_bar_runtime.gd
```

改造完成前至少确认：

1. 新怪物 id、技能 id、wave 引用全部通过校验。
2. 新行为已注册，缺失 `behavior.type` 或必需 action 会失败。
3. 新 action 已进入 `EnemyActionRegistry` 和校验 schema。
4. 怪物能被玩家技能选中，能受击、受状态、死亡、掉落或按 policy 不掉落。
5. Boss 死亡、普通击杀、召唤怪死亡、自爆死亡分别不会破坏 UI、统计和奖励。
6. 文档和校验脚本同步更新，后续改造不用靠猜。
