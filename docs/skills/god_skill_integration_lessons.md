# 神系技能接入问题复盘与防回归清单

本文沉淀火系和冰系技能接入过程中暴露的问题。后续接入雷系、毒系、圣系、物理系等神系时，必须先按本文检查设计、数据、runtime、视觉、调试工具和验证脚本，避免重复踩坑。

## 核心原则

1. **数据不是生效**
   - `data/skills.json` 里有卡牌，只说明技能能被学习或展示，不说明技能已经介入 runtime。
   - 每个技能必须至少有一个可观测 runtime 结果：伤害变化、状态变化、投射物、区域、召唤物、HUD 冷却、DevTools 状态文本或可见 VFX。
   - 学习技能后必须在真实事件链路里验证，不只用手动构造带完整 target 的测试上下文。

2. **优先复用通用系统**
   - 攻击强化、冲刺、区域、投射物、状态、召唤、HUD、DevTools 都应优先复用现有系统。
   - 相似能力优先给现有数据模型加可选字段，不新建整套平行系统。
   - 单个技能需要的行为如果未来其他神系也可能用到，应沉淀到 `SkillActionExecutor`、`TargetingService`、`AreaEffect`、`Projectile` 或 `Summon` 通用组件。

3. **共享 runtime 改动必须有回归**
   - 修改技能 action、状态、冲刺、召唤、HUD、DevTools 等共享链路后，必须跑已有神系回归。
   - 新神系测试不能只验证新数据存在，还要验证旧神系不会被覆盖或退化。

## 火系接入暴露的问题

### 攻击强化

- 问题：`fire_attack_searing` 学习后伤害意外翻倍。
- 根因：攻击强化既叠加了额外技能逻辑，又没有严格按“替换初始攻击槽”的语义验证。
- 约束：
  - 每个神系的 `*_attack_*` 必须替换初始攻击技能槽，而不是新增独立攻击槽。
  - 伤害增幅必须按配置预期变化，不能因为重复 modifier、重复事件或重复 projectile 结算翻倍。
  - 攻击强化必须沿用或明确替换初始攻击视觉，学习后不能丢失普攻表现。
- 必测：
  - 学习前后攻击槽数量。
  - 学习前后单次命中伤害。
  - 攻击命中状态施加。
  - 攻击 projectile/visual 是否仍然可见。

### 状态施加与 tick

- 问题：`attack_searing` 没有施加 Burning；Burning 后续没有 tick；DevTools 状态文本缺少持续时间/tick 信息。
- 根因：卡牌描述、状态定义、命中事件和 `StatusEffectManager` tick 链路没有一起验收。
- 约束：
  - 每个状态必须验证 apply、stack、duration、tick、death/expire 行为。
  - DOT 状态必须显示层数、每 tick 伤害、剩余时间。
  - 非 DOT 状态也要显示剩余时间，每 tick 伤害显示为 0 或明确空值。
- 必测：
  - `attack_hit`、projectile hit、area tick、summon hit 等所有入口能施加状态。
  - 状态 tick 后层数/持续时间变化符合预期。
  - 状态死亡联动可以触发后续技能效果。

### 冲刺与碰撞

- 问题：冲刺不能穿过怪物，甚至把怪物顶到冲刺终点；dash cooldown 和 HUD 倒计时也出现过缺失。
- 根因：冲刺技能效果和玩家移动/碰撞系统耦合过深，新增效果时没有保持 dash 原有穿怪语义。
- 约束：
  - 神系 dash 技能只能追加路径、投射物、状态、伤害等效果，不能破坏玩家移动穿怪。
  - 敌人在玩家冲刺时应保持原位，玩家能穿过敌人。
  - dash 技能必须有 cooldown，并在 HUD 技能槽显示倒计时蒙层。
  - Debug attack on/off 不能暂停技能冷却。
- 必测：
  - 玩家冲刺穿过敌人。
  - 敌人位置不被顶走。
  - dash cooldown 生效。
  - HUD 倒计时持续推进。

### 区域和视觉

- 问题：烈焰疾行火焰路径没有绘制；流星火雨最初没有陨石/陨石坑视觉；陨石运动方向和伤害范围不符合设计。
- 根因：只验证了逻辑对象或伤害，没有同时验证视觉、轨迹、范围和落点。
- 约束：
  - 每个 area/projectile 都必须同时有逻辑对象、可见视觉、命中/伤害、状态施加。
  - 轨迹类效果必须验证方向、速度、落点和范围。
  - 范围单位必须统一换算。若设计写 `R = 84px`，数据里必须落到实际 px 值。
- 必测：
  - area/projectile 节点生成。
  - 视觉节点或程序化绘制非空。
  - 命中范围与设计数值一致。
  - 伤害和状态都能生效。

### 火系联动

- 问题：火系多个联动初期存在“描述有、runtime 没介入”的情况。
- 根因：只接入了技能卡数据，没有逐项验证 Burning death、skill hit Burning、area standing Burning modifier 等事件。
- 约束：
  - 每个联动都必须映射到明确事件：`attack_hit`、`dash_start`、`area_tick`、`projectile_hit`、`enemy_death`、`skill_damage_hit` 等。
  - 条件必须可测试，例如 target has Burning、enemy died with Burning、target stands on fire area。
  - 共享联动逻辑应放在 special rule 或通用 action，不散落在单个技能脚本。

### Godot 4 类型转换

- 问题：`String(skill.get(...))`、`StringName(String(...))` 在 Godot 4 下对普通字符串触发 `Invalid call 'String' constructor`。
- 根因：沿用了不兼容 Godot 4 的构造式写法。
- 约束：
  - 不使用 `String(value)` 作为转换。
  - 使用 `str(value)`、`StringName(str(value))` 或项目内 helper。
  - shared data parsing、DevTools、offer pool、skill manager 等文件必须有静态扫描。

## 冰系接入暴露的问题

### 自动触发时缺少 target

- 问题：`frost_dash_ice_shard_assault` 没有发射冰片；`frost_cast_glacial_lance` 没有造成伤害；`frost_cast_frost_field` 落在玩家脚下。
- 根因：测试里手动给 context 塞了 `target`，但真实 `dash_start` / `cast_skill` 触发时经常没有显式 target。`spawn_projectile` 和 `spawn_area` 因 target 缺失直接失败或 fallback 到 caster。
- 约束：
  - 自动技能、冲刺技能、周期技能不能假设事件 context 一定有 target。
  - 技能数据需要声明 `targeting` 或 `targeting_mode`。
  - `SkillActionExecutor` 应在 action 层按配置自动索敌，并把 resolved target 写入派生 context。
- 必测：
  - 无显式 target 的 dash/cast 仍能生成 projectile/area。
  - 生成位置不是玩家默认位置，除非技能明确 `position_mode: "caster"`。
  - projectile 带非零 damage packet。

### 目标策略缺口

- 问题：`frost_cast_blizzard_cloud` 固定向右移动，没有朝怪物密集区域移动。
- 根因：数据写了 `targeting: "densest_enemy_cluster"`，但 `TargetingService` 不认识该策略；`towards_target` 没目标时 fallback 到 `Vector2.RIGHT`。
- 约束：
  - 数据中出现的每个 `targeting` 模式必须在 `TargetingService` 有实现或被验证为已支持。
  - 目标点与生成点重合时，移动方向应退回为 caster -> target，而不是默认向右。
  - “最近精英或最高生命”“怪物密集区域”等策略必须通用化。
- 必测：
  - `highest_health_or_nearest_elite` 能选择精英优先，否则最高生命。
  - `densest_enemy_cluster` 能选择怪物密度最高位置。
  - 移动 area 的 `move_direction` 指向目标区域。

### Area expire 上下文

- 问题：`frost_cast_frost_field` 的冰霜路径要求在持续伤害结束后留在敌人脚下，不应在玩家脚下生成。
- 根因风险：expire action 如果不携带 area 当前位置或 impact target，嵌套 `spawn_area` 容易回退到 caster。
- 约束：
  - `AreaEffect` 执行 `actions_on_expire` 时必须携带 `position: global_position`、`area: self`、`source: self`、`target_group`、`skill_instance`、`event_bus` 等上下文。
  - 嵌套 `spawn_area` 默认应优先使用 context position，除非显式声明 `position_mode`。
- 必测：
  - area 到期后生成的后续 area 位于原 area 位置。
  - 后续 area 仍能 tick、施加状态、显示视觉。

### Summon 可视化和生命周期

- 问题：`frost_summon_frost_wolf` 没有可视化霜狼；旧霜狼释放后再次生成时报 `Trying to cast a freed object`。
- 根因：`summon_frost_wolf` 缺少 `visual` 配置；`SummonManager._prune` 对 active 列表里的 freed object 先强转 `Node` 再判活，Godot 在强转处报错。
- 约束：
  - 每个 summon 定义必须有明确 visual 配置，即使第一版只用占位图。
  - 清理 active summon 列表时，必须先 `is_instance_valid(variant)`，再 cast。
  - summon spawn 后应设置 `summon_definition_id` meta，便于测试和调试。
- 必测：
  - 召唤物生成后存在 `SummonVisual` 或等价视觉节点。
  - summon duration 结束或手动释放后，下一次 spawn 不报错。
  - `max_count` 在清理 freed object 后仍正确。

### 测试上下文失真

- 问题：早期冰系 smoke test 给所有事件都传入 `_enemy` 作为 target，导致真实无 target 触发的问题没被测出。
- 根因：测试为了方便构造“理想 context”，没有模拟真实玩家事件。
- 约束：
  - 每个自动触发技能都至少有一条无显式 target 的 smoke test。
  - 测试既要覆盖 action 直接执行，也要覆盖真实 event bus。
  - 对 `dash_start`、`on_cast`、`enemy_death`、`area expire` 等事件，测试 context 要贴近真实事件。

## 新神系接入前检查清单

### 数据层

- [ ] `data/gods.json` 已标记 `implemented: true`。
- [ ] 所有技能使用 `description`，不使用 `effect_description`。
- [ ] 每个技能有明确 `type`、`tags`、`offer_rule`、`trigger_rules` 或 `effects`。
- [ ] attack/dash/core 等互斥技能设置正确 `exclusive_group`。
- [ ] 所有 `targeting` / `targeting_mode` 在 `TargetingService` 有实现。
- [ ] 所有 area/projectile/summon 引用的 ID 都能在对应数据文件找到。
- [ ] 范围数值已换算成 px 或有统一换算声明。

### Runtime 层

- [ ] 攻击强化替换初始攻击槽，不新增攻击槽。
- [ ] 自动技能无显式 target 时也能按配置索敌。
- [ ] 投射物生成后带非零 damage、damage type、source skill id。
- [ ] area 生成位置、tick、expire、嵌套 action 都携带正确 context。
- [ ] 状态 apply、stack、duration、tick、death/expire 联动都可观测。
- [ ] 召唤物 owner、player_power、max_count、duration、visual、cleanup 都可验证。
- [ ] Debug attack on/off 不影响技能冷却推进。

### 视觉层

- [ ] 每个 projectile 有可见飞行表现。
- [ ] 每个 area 有可见地面/范围表现。
- [ ] 每个 summon 有可见主体。
- [ ] 轨迹类效果验证方向，不允许无目标时默认向右或默认原地。
- [ ] 视觉和伤害/状态同测，不接受只做一边。

### DevTools 与 HUD

- [ ] DevTools 对应神系能显示全部技能卡。
- [ ] 学习第一个技能不报错。
- [ ] 状态面板能显示状态名称、层数、每 tick 伤害、剩余时间。
- [ ] HUD 技能槽显示技能名称、CD、倒计时蒙层。
- [ ] dash cooldown 在 HUD 中可见。

### 回归验证

新神系接入至少需要新增：

- [ ] `<school>` 技能数据合同测试。
- [ ] `<school>` runtime smoke test。
- [ ] `<school>` summon contract 或 summon runtime test。
- [ ] `<school>` no-regression static guard，扫描已知 Godot 4 转换问题和旧神系回归点。

共享回归至少运行：

- [ ] `npm run verify:skill-definition-schema`
- [ ] `npm run verify:skill-rule-adapters`
- [ ] `npm run verify:player-dash`
- [ ] `npm run verify:run-hud-skill-slots`
- [ ] `npm run verify:summon-system-contract`
- [ ] `npm run verify:summon-system-behavior`
- [ ] 已完成神系的 runtime smoke，例如 `verify:fire-skill-runtime-smoke`、`verify:frost-skill-runtime-smoke`
- [ ] 已完成状态的 runtime/DevTools 测试，例如 Burning、Chilled/Frozen
- [ ] `git diff --check`

## 推荐接入流程

1. 先写静态合同，确认技能数量、名称、描述、互斥组、combat object、summon object 都正确。
2. 再写 runtime smoke，至少覆盖每个技能类别：attack、dash、cast、summon、passive、power、core。
3. smoke test 必须包含真实事件路径和无 target 触发路径。
4. 补数据和最小通用 runtime 能力。
5. 跑新神系测试。
6. 跑所有共享回归和已完成神系回归。
7. 只有测试覆盖到视觉、伤害、状态、HUD/DevTools 后，才认为第一版接入完成。
