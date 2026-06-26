# 冰系技能系统整体技术方案

## 目标

接入第一版冰系神系技能，使 `frost` 从规划状态变为可学习、可运行、可在 DevTools 中验证的完整神系。技能名称和描述以本次表格为准，整体实现沿用最初技能系统设计文档：技能以数据驱动为主，通过 `SkillDefinition`、`trigger_rules`、`effects`、状态系统、区域/投射物/召唤物系统组合实现，避免为每张技能卡硬写独立逻辑。

第一版范围只覆盖 14 个冰系基础技能：

| 技能名 | 描述 |
| --- | --- |
| 寒霜攻击 | 攻击变强，并施加 Chilled；对已 Chilled 敌人额外提高冻结效率 |
| 冰片突袭 | 冲刺时向周围投掷冰片，造成伤害并施加 Chilled |
| 冰霜领域 | 在敌人脚下生成冰霜区域，造成持续伤害，并留下冰霜路径，使经过敌人 Chilled |
| 极寒冰矛 | 向生命最高或最近精英发射穿透冰矛；命中 Frozen 敌人时产生碎冰溅射 |
| 暴雪云团 | 在怪物密集区域生成移动暴雪，持续施加 Chilled，并降低敌人移动速度 |
| 霜狼 | 冰狼协助作战，攻击命中敌人时施加 Chilled；优先扑击 Frozen 目标 |
| 冰晶守卫 | 召唤固定冰晶守卫，周期性释放冰脉冲，减速附近敌人 |
| 碎冰处决 | Chilled / Frozen 敌人低于一定生命阈值时，直接碎裂死亡 |
| 冰封易伤 | 被 Frozen、定身或强控的敌人受到更多伤害 |
| 寒意延展 | Chilled 和 Frozen 持续时间提高；冰霜区域持续时间提高 |
| 霜环反冲 | 周围敌人数量过多或冲刺结束时，有概率从自身释放冰霜环，伤害并冻结敌人 |
| 冰裂连锁 | Frozen 敌人受到重击或技能伤害时，向周围发射碎冰片 |
| 冰雾护身 | 每冻结一定数量敌人，获得一层冰雾护盾；护盾破裂时冻结附近敌人 |
| 绝对零度 | 敌人被冻结所需的 Chilled 层数降低；每隔数秒，全场敌人获得一层 Chilled；Frozen 敌人碎裂时会在原地生成小型冰霜领域 |

冰系与其他神系的融合技能不纳入本阶段，保留后续扩展入口。

## 现有系统复用

当前项目已经具备冰系接入所需的大部分基础设施：

- `data/skills.json`：火系技能已经按 `school`、`type`、`tags`、`offer_rule`、`trigger_rules`、`effects` 数据驱动接入。
- `data/status_effects.json`：已有 `chilled` 与 `frozen` 状态。`chilled` 最大 7 层，满层转为 `frozen`；`frozen` 是强控状态，普通/精英/Boss 有不同持续时间。
- `scripts/combat/status_effect_manager.gd`：负责状态施加、层数、持续时间、满层转状态、状态事件、状态快照和视觉。
- `scripts/skills/skill_event_bus.gd` 与 `skill_trigger_rule_adapter.gd`：负责把 `trigger_rules` 转成运行时事件，并执行条件与 action。
- `scripts/skills/skill_action_executor.gd`：已有伤害、状态、区域、投射物、召唤、护盾、状态消耗等 action。
- `data/summons.json` 与 `scripts/summons/*`：已有通用召唤物系统，并且已经存在 `summon_frost_wolf` 示例。
- `data/combat_objects.json`、`AreaEffect`、`Projectile`：可承载冰霜区域、冰霜路径、暴雪、冰片、冰矛、碎冰片等对象。
- DevTools 技能卡页面已按神系读取 `data/gods.json` 与 `data/skills.json`，只需要把 `frost` 标为 implemented 并补齐技能数据即可显示。

因此冰系接入应以“补数据 + 少量通用 runtime 能力”为主。

## 数据改动

### `data/gods.json`

将 `frost` 标记为已实现：

- `implemented: true`
- `description` 更新为“以 Chilled、Frozen、碎冰、护盾和控场为核心的冰系神系”
- `tags` 从 `planned` 调整为包含 `implemented`

DevTools 的神系按钮会因此把 frost 视为可用神系。

### `data/skills.json`

新增 14 个 `school: "frost"` 的技能定义。命名建议统一使用：

| 技能名 | 建议 ID | 类型 | 排他组 |
| --- | --- | --- | --- |
| 寒霜攻击 | `frost_attack_frostbite` | `attack` | `attack_school` |
| 冰片突袭 | `frost_dash_ice_shard_assault` | `dash` | `dash_school` |
| 冰霜领域 | `frost_cast_frost_field` | `cast` | null |
| 极寒冰矛 | `frost_cast_glacial_lance` | `cast` | null |
| 暴雪云团 | `frost_cast_blizzard_cloud` | `cast` | null |
| 霜狼 | `frost_summon_frost_wolf` | `summon` | null |
| 冰晶守卫 | `frost_summon_ice_crystal_guard` | `summon` | null |
| 碎冰处决 | `frost_power_shatter_execute` | `power` | null |
| 冰封易伤 | `frost_passive_frozen_vulnerability` | `passive` | null |
| 寒意延展 | `frost_passive_chill_extension` | `passive` | null |
| 霜环反冲 | `frost_power_frost_ring_counter` | `power` | null |
| 冰裂连锁 | `frost_power_ice_crack_chain` | `power` | null |
| 冰雾护身 | `frost_power_ice_mist_guard` | `power` | null |
| 绝对零度 | `frost_core_absolute_zero` | `core` | `core_school` |

所有 14 个技能必须写入 `description` 字段，不再使用 `effect_description`。

### `data/combat_objects.json`

新增冰系战斗对象：

- `frost_field`：冰霜区域，周期性伤害并施加 `chilled`
- `frost_path`：冰霜路径，低伤害或无伤害，重点施加 `chilled`
- `ice_shard_projectile`：冲刺投掷冰片
- `glacial_lance_projectile`：穿透冰矛
- `shatter_splash`：命中 Frozen 后的碎冰溅射
- `blizzard_cloud`：移动暴雪区域，持续施加 `chilled`
- `frost_ring`：围绕玩家释放的环形冰霜冲击
- `ice_crack_shard`：冰裂连锁碎片
- `absolute_zero_field`：Frozen 碎裂后生成的小型冰霜领域

对象视觉可以第一版使用现有贴图/简单几何 VFX，后续再替换资源。

### `data/summons.json`

冰系召唤物可以复用当前项目中的通用 Summon 系统，不需要新建一套 FrostSummon 或单独的宠物系统。现有 `SummonManager`、`SummonController`、`SummonTargetingComponent`、`SummonMovementComponent`、`SummonAttackComponent` 已经覆盖召唤、owner 绑定、跟随、索敌、攻击冷却、持续时间、最大数量和命中状态施加等核心能力。冰系只需要在现有数据模型上补配置字段，并在 runtime 里补少量通用分支。

复用并完善现有 `summon_frost_wolf`：

- `attack.on_hit_effects` 施加 `chilled`
- `targeting` 支持优先 Frozen 目标，若现有通用 targeting 不支持，新增 `target_priority: "frozen_first_then_nearest"`
- `movement` 继续使用移动召唤物逻辑，保持跟随玩家、追击敌人、超出牵引距离返回。
- `attack` 继续使用现有 melee / projectile 攻击模型，霜狼第一版建议用 melee，并把扑击 Frozen 目标表现为目标优先级和攻击视觉，而不是另起独立行为树。

新增 `ice_crystal_guard`：

- 固定召唤物，不主动追击
- 周期性释放冰脉冲
- 对范围内敌人造成 frost 伤害并施加 `chilled`
- 使用同一个 `scene_path: "res://scenes/summon_controller.tscn"`，通过配置驱动固定站桩与范围脉冲。

如果当前 Summon 系统只支持移动宠物，优先把缺口补成通用配置能力：`movement.movement_mode: "stationary"` 让召唤物不执行 Follow/Chase/Return 位移，`attack.attack_type: "area_pulse"` 让攻击组件按冷却对范围内敌人结算伤害和 `chilled`。只有在实现风险明显过高时，冰晶守卫第一版才允许临时用 `spawn_area` 模拟，但技能数据仍保留 summon 类型，后续可以无缝切回 Summon。

## Runtime 能力补充

### 状态系统

`Chilled` / `Frozen` 已存在，第一版只需要补两个通用能力：

1. **冻结效率 modifier**
   - 寒霜攻击和绝对零度都涉及“更容易冻结”。
   - 推荐通过状态参数支持 `max_stacks` 覆盖，而不是新增新状态。
   - 绝对零度生效时，对 `chilled` 的满层阈值从 7 降低到例如 5。

2. **Frozen 事件语义**
   - 现有 `status_max_stack_reached` 可用于 Chilled 满层。
   - 冰裂连锁、冰雾护身、绝对零度需要监听 `status_applied` 或 `status_max_stack_reached`，判断 `status_id == frozen`。

### SkillActionExecutor 通用 action

优先复用现有 action。若不够，需要新增以下通用 action：

- `execute_low_hp_enemy`
  - 参数：`statuses`, `hp_threshold`, `damage_type`, `source_type`
  - 用于“碎冰处决”
  - 实现上可先调用高额 true/special damage，避免直接 `queue_free`

- `add_modifier` 扩展
  - 支持 `chilled_duration_multiplier`
  - 支持 `frozen_duration_multiplier`
  - 支持 `frost_area_duration_multiplier`
  - 支持 `frozen_damage_taken_multiplier`

- `grant_shield` 已存在，但冰雾护身需要可堆叠护盾源：
  - `shield_type: "ice_mist"`
  - `max_stacks`
  - `on_break` 可触发 `spawn_area` 或 `frost_ring`

- `spawn_area` / `spawn_projectile` 需要支持选择策略：
  - `targeting: "highest_health_or_nearest_elite"`
  - `targeting: "densest_enemy_cluster"`
  - 若当前 `TargetingService` 已支持类似策略则复用，否则加通用策略。

### Summon 系统

冰系召唤物全部走数据驱动 Summon：

- 霜狼：移动召唤物，Follow/Chase/Attack/Return 复用现有状态机。
- 冰晶守卫：固定召唤物，复用同一套 Summon 生命周期和攻击冷却；行为差异通过 movement / attack 配置表达。

复用边界：

- 不新增独立的冰系召唤物管理器，所有召唤仍由 `SummonManager.spawn_summon()` 入口创建。
- 不新增专门的 FrostWolfController 或 IceCrystalGuardController；如需视觉差异，优先通过 scene 子节点、贴图、VFX 或配置字段处理。
- 不替换现有召唤物数据模型，只在 `movement`、`targeting`、`attack` 内增加可选字段，旧召唤物不填这些字段时保持当前行为。
- `owner`、`player_power`、`duration`、`max_count`、`on_hit_effects` 继续沿用现有 SummonDefinition 语义。

建议新增召唤物配置字段：

```json
{
  "movement": {
    "movement_mode": "stationary"
  },
  "targeting": {
    "target_priority": "frozen_first_then_nearest"
  },
  "attack": {
    "attack_type": "area_pulse",
    "pulse_radius": 180
  }
}
```

推荐第一版实现优先级：

1. 霜狼直接接入现有 `summon_frost_wolf`，只补 Frozen 优先目标与 chilled 命中效果校验。
2. 冰晶守卫在 Summon 系统上补 `stationary` 和 `area_pulse`，作为通用能力沉淀，未来火系、雷系、防御塔式召唤物都可以复用。
3. 若时间不足，冰晶守卫可临时降级为 summon 技能触发 `spawn_area`，但文档和数据模型仍按 Summon 目标设计。

## 14 个技能映射方案

### 寒霜攻击

类型：`attack`

效果：

- 替换初始普攻槽，规则与 `fire_attack_searing` 一致，不新增额外技能槽。
- 添加 `primary_attack_damage_multiplier_add`。
- `attack_hit` 时施加 `chilled`。
- 若目标已 `chilled`，额外施加 1 层或使用较低满层阈值，提高冻结效率。

### 冰片突袭

类型：`dash`

效果：

- 触发：`dash_start` 或 `dash_tick`
- 向周围发射多枚 `ice_shard_projectile`
- 命中造成 frost 伤害并施加 `chilled`
- 复用冲刺 cooldown/HUD 倒计时，不影响当前 dash 穿怪逻辑

### 冰霜领域

类型：`cast`

效果：

- CD 自动释放
- 在目标敌人脚下生成 `frost_field`
- 区域 tick 造成 frost 伤害并施加 `chilled`
- 区域结束或 tick 时留下 `frost_path`

### 极寒冰矛

类型：`cast`

效果：

- 选择生命最高敌人或最近精英
- 发射穿透 `glacial_lance_projectile`
- 命中造成 frost 伤害并施加 `chilled`
- 若命中目标是 `frozen`，生成 `shatter_splash`

### 暴雪云团

类型：`cast`

效果：

- 在怪物密集区域生成 `blizzard_cloud`
- 暴雪缓慢移动，优先朝敌人密集处漂移
- tick 施加 `chilled`
- 通过 `chilled` 的减速效果降低敌人移动速度

### 霜狼

类型：`summon`

效果：

- 生成 `summon_frost_wolf`
- 跟随玩家，自动索敌
- 攻击施加 `chilled`
- 目标优先级：Frozen 目标 > 最近敌人

### 冰晶守卫

类型：`summon`

效果：

- 生成固定冰晶守卫
- 周期性释放冰脉冲
- 脉冲造成 frost 伤害并施加 `chilled`
- 不追击敌人，不跟随玩家移动

### 碎冰处决

类型：`power`

效果：

- 触发：技能伤害命中、状态 tick 或定期扫描
- 条件：目标有 `chilled` 或 `frozen`，且生命低于阈值
- 执行：造成一次高额 frost/special damage 或直接走死亡流程

### 冰封易伤

类型：`passive`

效果：

- 对 `frozen`、定身、强控目标增加受到伤害
- 第一版至少覆盖 `frozen`
- 若保留旧控制状态，则也覆盖 `freeze/stun/paralyze/root`

### 寒意延展

类型：`passive`

效果：

- `chilled` 持续时间提高
- `frozen` 持续时间提高
- frost area 持续时间提高

### 霜环反冲

类型：`power`

效果：

- 触发 A：冲刺结束
- 触发 B：附近敌人数量达到阈值
- 生成以玩家为中心的 `frost_ring`
- 造成 frost 伤害并施加 `chilled`，可配置概率或满层直接 Frozen

### 冰裂连锁

类型：`power`

效果：

- 条件：Frozen 敌人受到重击或技能伤害
- 生成若干 `ice_crack_shard`
- 碎片命中造成 frost 伤害并施加 `chilled`

### 冰雾护身

类型：`power`

效果：

- 监听冻结计数
- 每冻结一定数量敌人，给玩家一层 `ice_mist` 护盾
- 护盾破裂时生成小范围 frost ring 或 apply `frozen/chilled`

### 绝对零度

类型：`core`

效果：

- 降低敌人被冻结所需的 `chilled` 层数
- 周期性给全场敌人施加 1 层 `chilled`
- Frozen 敌人碎裂/死亡时生成 `absolute_zero_field`

## DevTools 与 HUD

DevTools：

- Frost 神系按钮可选。
- Frost 卡牌显示 14 张技能。
- 卡牌文本显示 `name` 与 `description`。
- Status 页面继续显示 `Chilled` / `Frozen`。
- Debug 状态文本使用当前格式：`状态名(层数, 每tick伤害, 剩余时间)`；非 DOT 状态每 tick 伤害显示 0.0。

HUD：

- 技能槽显示已学习 frost 技能名称。
- 自动技能和召唤技能显示 cooldown 倒计时。
- dash 技能沿用 dash cooldown 显示。

## 火系接入问题复盘与冰系防错规则

后续所有神系接入都必须先阅读并执行通用清单：[神系技能接入问题复盘与防回归清单](../../skills/god_skill_integration_lessons.md)。该文档集中沉淀火系与冰系接入中已经出现过的问题，包括攻击强化替换、状态 tick、dash 穿怪、视觉/伤害同步验收、Godot 4 类型转换、无 target 自动索敌、Area expire 上下文、Summon freed object 清理等。本文保留冰系实现阶段的局部要求，通用清单作为后续神系接入的前置规范。

火系接入过程中出现过“数据写进去了但 runtime 没生效”“状态没有实际施加或 tick”“技能槽行为不符合预期”“视觉对象未绘制”“冲刺破坏碰撞移动”“范围单位后期返工”“Godot 4 类型转换报错”等问题。冰系接入必须把这些问题前置成实现约束和验收项。

1. **数据不等于生效**
   - 每个 frost 技能都必须有 runtime 可观测结果：数值变化、状态变化、投射物、区域、召唤物、HUD 倒计时或 DevTools 状态变化。
   - 不能只补 `data/skills.json` 卡牌定义就视为完成。

2. **攻击强化替换初始攻击槽**
   - `frost_attack_frostbite` 必须替换基础攻击技能槽，行为与修正后的 `fire_attack_searing` 一致。
   - 不能新增额外攻击技能槽，不能造成普攻伤害意外翻倍。
   - 寒霜攻击必须沿用当前基础攻击视觉或明确配置新的 frost 视觉，避免学习后攻击表现丢失。

3. **状态链路必须实测**
   - `attack_hit`、区域 tick、投射物命中、召唤物命中这些入口都要实际施加 `chilled`。
   - `chilled` 要能按层数叠加，满层转 `frozen`；绝对零度降低冻结层数时也必须可测。
   - DevTools 状态文本继续显示 `状态名(层数, 每tick伤害, 剩余时间)`，非 DOT 状态每 tick 伤害显示 0.0。

4. **冲刺技能不能破坏移动系统**
   - `frost_dash_ice_shard_assault` 只能追加冰片投射与 `chilled` 效果。
   - 不能影响 dash 穿怪，不能把敌人顶走，不能让 dash cooldown 或 HUD 倒计时失效。
   - Debug attack on/off 不应暂停技能冷却倒计时。

5. **视觉和伤害必须同时验收**
   - 冰片、冰霜领域、冰霜路径、冰矛、暴雪云团、霜环、冰晶守卫脉冲都要验证对象生成、可见绘制、伤害范围、命中和状态施加。
   - 不能出现只有伤害没有视觉，或有视觉但没有伤害/状态的半成品。

6. **范围单位一次性落准**
   - 冰系范围配置必须明确使用 px 或项目通用单位换算，不允许在数据里混用未解释的倍率。
   - 若沿用火系的 `R = 84px` 语义，必须在数据或注释里体现换算后的实际半径。

7. **Godot 4 类型转换要避坑**
   - 不使用 `String(value)` 这类会在 Godot 4 报错的构造写法。
   - 统一使用 `str(value)`、`StringName(...)` 或项目已有 helper 进行转换。

8. **回归测试必须覆盖已修火系行为**
   - 冰系实现后必须跑 Fire、HUD、Summon、Burning tick、dash 穿怪相关回归。
   - 修改共享 runtime 时，要优先证明没有覆盖掉火系已经修好的逻辑。

## 验证方案

新增或扩展以下验证：

- `tools/verify_frost_skill_system_contract.js`
  - `data/gods.json` 中 frost 已 implemented。
  - 14 个 frost 技能都存在。
  - 每个技能 `name` / `description` 与本次表格一致。
  - `frost_attack_frostbite` 是 `attack` 且使用 `exclusive_group: "attack_school"`。
  - `frost_core_absolute_zero` 是 `core` 且使用 `exclusive_group: "core_school"`。
  - frost 技能只使用 `description` 字段，不回退到 `effect_description`。
  - 范围字段必须是明确 px 数值，或在数据中通过统一换算字段声明来源。

- `tools/verify_frost_status_runtime.gd`
  - `chilled` 可叠层。
  - 满层后转为 `frozen`。
  - `frozen` 进入状态快照。
  - `frost_passive_chill_extension` 可延长持续时间。
  - 寒霜攻击、冰霜领域、冰片、霜狼命中都能施加 `chilled`。
  - 绝对零度生效时，冻结所需 `chilled` 层数降低并可触发 `frozen`。

- `tools/verify_frost_skill_runtime_smoke.gd`
  - 学习 14 个 frost 技能不报错。
  - 寒霜攻击命中施加 `chilled`。
  - 寒霜攻击替换基础攻击槽，不新增攻击槽，伤害增幅不意外翻倍。
  - 冰片突袭生成冰片投射物。
  - 冰片突袭不破坏 dash 穿怪、敌人位置、dash cooldown 和 HUD 倒计时。
  - 冰霜领域生成 frost area。
  - 冰霜领域、冰霜路径、暴雪云团、霜环同时具备视觉节点、伤害和 `chilled` 施加。
  - 霜狼通过 Summon 系统生成。
  - 绝对零度周期性施加 Chilled。

- `tools/verify_frost_summons_contract.js`
  - `summon_frost_wolf` 和 `ice_crystal_guard` 存在。
  - 霜狼 on hit 施加 `chilled`。
  - 冰晶守卫使用固定/脉冲行为配置。

- 现有回归：
  - `npm run verify:skill-definition-schema`
  - `npm run verify:fire-status-contract`
  - `npm run verify:summon-system-contract`
  - `npm run verify:summon-system-behavior`
  - `npm run verify:fire-skill-runtime-smoke`
  - Burning tick 行为和 DevTools 状态显示保持不变。
  - dash 穿怪行为保持不变。

## 风险与约束

- `Chilled` 满层转 `Frozen` 已存在，但“降低冻结所需层数”可能需要让 `StatusEffectManager.apply_status()` 支持状态定义的运行时阈值覆盖。
- 冰晶守卫如果强行作为召唤物实现，需要 SummonMovement/Attack 支持 stationary 与 area pulse；若风险过高，第一版可以用 `spawn_area` 模拟。
- “生命最高或最近精英”“怪物密集区域”依赖 targeting 策略。应优先扩展通用 `TargetingService`，不要写在单个技能里。
- “直接碎裂死亡”必须走现有死亡流程，避免跳过掉落、统计、死亡事件。
- 冰系引入强控后，要验证 Boss/Elite 持续时间缩放仍生效。

## 第一版验收标准

- Frost 神系在 DevTools 中显示为可用。
- DevTools Frost 技能卡显示 14 张，名称和描述与本次表格一致。
- 学习寒霜攻击会替换初始攻击槽，而不是新增攻击槽。
- 寒霜攻击不会让基础攻击伤害意外翻倍，且命中一定施加 Chilled。
- Chilled 能正常叠层，满层转 Frozen。
- 冰片突袭不会影响 dash 穿怪、dash 冷却和 HUD 倒计时。
- 冰霜领域、冰霜路径、冰矛、暴雪云团、霜环、霜狼、冰晶守卫都有可见 runtime 效果。
- 冰系至少具备攻击、冲刺、自动技能、召唤、被动、特殊能力、神系质变的 runtime 可见效果。
- Frost 技能不会破坏现有 Fire 技能、HUD 技能槽、Summon 系统和 Burning tick 行为。
