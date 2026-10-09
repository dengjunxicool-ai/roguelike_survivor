# 技能系统修订 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 执行方式由用户选择；本文件不授权启动子代理或实施。

**Goal:** 修正技能升级、持续效果与事件契约，完成六神系、60融合、构筑供给和战斗反馈的一致性与平衡验收。

**Architecture:** 保留现有JSON→Definition→Trigger/Effect Adapter→Action Family→统一伤害链的结构。复用ModifierStore、TargetingService、CombatTargetRegistry、现有调试/验证框架；新增小型生命周期、事件来源、复制快照和融合交互服务，不把SkillManager或动作支持层变成新的单体模块。四个子项目独立验收，按依赖串行实施，共享数据文件按任务依次修改。

**Tech Stack:** Godot 4.6.3、GDScript、JSON、Node.js静态验证、PowerShell隔离测试。无新增产品依赖。

**Spec:** `../specs/2026-10-09-skill-system-rebalance-design.md`。数值、资格、槽位和技能语义以该规格为准；本文件中的新增接口是拟实施接口，当前源码不保证已有。

**阶段状态（2026-10-09）：** M1（T0–T4）完成；M2（T5–T9）实现及180/180自动检查完成，独立审查8项问题已修复，但五神系无辅助300秒完整局验收尚未通过，停在M2汇报。M3/M4未执行。工作树：`E:/codex/skill-rebalance/worktree`，分支：`codex/skill-rebalance-m2`；详情见`../../skills/skill_rebalance_m2_report.md`和`../../skills/skill_rebalance_m2_progress.md`。

## Global Constraints

- 任何 C 盘文件写入均禁止。
- 缓存、日志、测试用户目录、临时脚本和测试存档放入 `E:/codex/skill-rebalance/`；设计与代码产物放在 E 盘项目目录。
- Godot 测试使用现有 `tools/verify/run_isolated_godot.ps1`，不得直接用会采用默认用户目录的 npm Godot 命令。
- 保留 Godot 4.6、数据驱动定义、六神系、最多两神系、一局一个核心和一个融合，以及 300 秒局长、240 秒 Boss 出场。
- 保留现有 144 个技能 ID 和角色初始技能；先修正确性，再迁移玩法，再调数值。
- 所有输出伤害路径包含直接、区域 tick、连锁、弹幕、复制和召唤，均只应用一次对应等级与品质倍率。
- 核心与融合独立容量；最大技能数12个；不新增品质晋升卡，不开放第三神系。
- 基于行为测试修正已复现问题，不把静态推测当已验证故障；与新设计冲突的旧断言登记替代测试。
- 不覆盖用户已有改动；每个任务保留自己的文件清单和可回退提交；计划编写阶段不提交、不推送、不改产品代码。

## Review Focus

1. 升级卡携带比现有品质更低或缺失品质，实际输出仍不下降（T1）。
2. 同帧冻结、诅咒到期、死亡与状态转移发生竞争，只结算或转移一次（T4、T12）。
3. 暂停、替换取消、重开或来源技能移除，时间与状态正确保持或清理（T2、T5、T10）。
4. 多目标命中、复制、补盾和满层反应相互触发，事件有来源且链有上限（T3、T9、T10、T12）。
5. 槽位满、只有被动或没有有效目标的构筑，抽卡和核心/融合准入没有死牌（T5、T6、T14）。

---

## A. 工作包与验收顺序

| 子项目 | 任务 | 可独立交付的版本 | 前置 |
| --- | --- | --- | --- |
| M1 正确性基础 | T0-T4 | 原技能可玩，品质不倒退，限时效果能结束，状态/事件一致 | 无 |
| M2 构筑与神系闭环 | T5-T9 | 新容量和准入可用，火冰雷咒圣能打完整一局 | M1 |
| M3 混沌、成长与融合 | T10-T13 | 真实复制、18cast里程碑、全部60融合通过行为验证 | M2 |
| M4 玩家反馈与调优 | T14-T16 | 卡片/HUD正确、平衡报告和回归齐备，可交付测试版本 | M3 |

推荐串行执行：多个任务共用skills.json、适配器和事件总线。若选择子代理，每个任务单独分配所有权，不同时编辑这些共享文件；审查可以独立进行，但执行方式需用户选择。

初步工作量为25-40个工程工作日：M1约5-7日，M2约5-8日，M3约10-16日，M4约5-9日；这是包含测试与两轮调参的人工估算，不是代理运行时间承诺。先完成T0后用实际差异修订估算。最小可试玩版本为M2，完整交付必须包括M3/M4，不能只隐藏未完成融合。

## B. 文件职责

现有文件修改范围（任务中的路径均相对于`E:/roguelike_survivor/`）：

| 路径 | 责任 |
| --- | --- |
| data/skills/skills.json | 技能前置、状态、里程碑、真实触发和效果 |
| data/combat/status_effects.json | 状态刷新、结算、控制转换合同 |
| data/config/skill_system_config.json | 本轮数值、阶段权重、容量及预算参数 |
| data/summons/summons.json | 分身行为、卫士防御、召唤来源 |
| scripts/skills/skill_growth_scaling.gd | 品质/等级纯数值计算 |
| scripts/skills/skill_manager.gd、skill_slot_policy.gd、skill_offer_service.gd、skill_learning_policy.gd | 学习、升级、容量、准入 |
| scripts/skills/skill_event_bus.gd、skill_trigger_rule_adapter.gd、condition_evaluator.gd | 来源、事件、冷却作用域和条件 |
| scripts/skills/skill_effect_adapter.gd、skill_action_*_executor.gd | 单次成长与动作分派 |
| scripts/modifiers/modifier_store.gd、modifier_source.gd、modifier_aggregator.gd | 临时来源、scope与统一属性消费 |
| scripts/combat/status_effect_manager.gd、area_effect.gd、projectile.gd | 状态结算和真实空间事件 |
| scripts/summons/summon_controller.gd、summon_attack_component.gd | 真实复制和召唤行为 |
| scripts/upgrades/upgrade_pool.gd、upgrade_option_builder.gd、skill_learn_option_builder.gd | 卡片生成与权重 |
| scripts/player/player_controller.gd、player_modifier_applier.gd | 学习入口、重开清理和替换事务接入 |
| scripts/ui/hud/run_hud_controller.gd、scripts/skills/skill_effect_summary_builder.gd | 槽位与运行数值展示 |
| scripts/core/content_config_validator.gd、data/config/content_schema.json、tools/validate/validate_content_configs.js | 新字段的双端校验 |
| docs/skills/skills.md、god_skill_integration_lessons.md | 当前设计与迁移说明 |

拟新增模块：`scripts/skills/skill_event_context.gd`（事件来源）、`skill_proc_policy.gd`（派生限制）、`skill_growth_profile.gd`（里程碑纯参数）、`skill_cast_snapshot_service.gd`（允许的输出快照）、`skill_replay_service.gd`（复制执行）、`skill_requirement_policy.gd`（机制依赖）、`skill_replacement_service.gd`（替换事务）、`fusion_interaction_service.gd`（对象交互去重）、`scripts/ui/skill_preview_service.gd`（共享数值预览）、`scripts/runtime/run_combat_clock.gd`（局内统一计时）、`scripts/runtime/skill_balance_metrics.gd`（调试采样）。只有需要接入SceneTree的服务使用Node，其余使用RefCounted。

## C. 验证命令模板与输出

以下命令从E盘项目根目录运行，Godot每个用例使用独立输出目录。`Txx`与文件名在对应任务中列出，禁止复制模板后保留占位符。

```powershell
powershell -NoProfile -File .\tools\verify\run_isolated_godot.ps1 -ProjectPath E:/codex/skill-rebalance/worktree -Script res://tools/verify/verify_skill_upgrade_monotonic.gd -OutputRoot E:/codex/skill-rebalance/T01
```

通过证据：退出码0、用例自身`[verify_*] PASS`、包装器`script_errors=0 engine_errors=0`。Godot日志最后几行没有PASS并不算通过。新增GDScript测试沿用现有SceneTree、`_failed`、断言与退出码结构，不能只验证字符串出现。

静态命令示例：`node tools/validate/validate_content_configs.js`。仅使用已经存在或本任务明确创建的脚本。静态校验不能替代实际触发、状态或UI测试。执行前显式将APPDATA/LOCALAPPDATA/TEMP/TMP/Node工具缓存设为E:/codex/skill-rebalance对应子目录；不经npm运行Godot。

每个任务的最终步骤：运行本任务行为测试→运行相关旧回归→核对git diff只含该任务文件→登记测试日志→提交该任务清单。提交标题建议为`fix/feat/test: ...`，不自动推送。提交前不使用`git add .`，回滚时只处理本任务提交，不重置用户已有工作。

## M1：正确性基础

### T0：建立可复现基线与144技能验收台账

**Files:** 新增`tools/verify/skill_rebalance_baseline.gd`、`tools/verify/verify_skill_rebalance_inventory.js`、`docs/skills/skill_rebalance_coverage.json`；修改`tools/verify/README.md`。调试数据只输出E:/codex。

**Interfaces:** 台账根字段`skills`；每行`id, school, fusion_school, skill_type, task, semantic_cases, legacy_assertions, status`。`status`只能为baseline/proven/migrating/accepted；基础84条、融合60条分别覆盖，初始技能另列不混入144条。

- [x] 写库存验证：断言144个不重复ID、84基础/60融合、六神系各14基础，每15神系组合各4融合，规格18cast ID全部存在。
- [x] 用现有角色/同一地图/同一永久成长采集基线，并在100P夹具中复现品质倒退、buff过期、Cursed事件；实际结果写入台账，不能预填“失败”。
- [x] 读取并登记受新规则影响的旧断言，重点包括`verify_skill_growth_scaling.gd`、`verify_burning_status_stack_decay_devtools.gd`、`verify_burn_status_table.js`、`verify_fusion_skill_numeric_contract.js`。每条旧断言关联后续替代行为测试。
- [x] 运行`node tools/verify/verify_skill_rebalance_inventory.js`和隔离`skill_rebalance_baseline.gd`，OutputRoot=`E:/codex/skill-rebalance/T00`；前者PASS，后者完整输出基线而不把已知失败静默当PASS。
- [x] 仅提交台账与基线工具；基线战斗日志不入仓库。

### T1：升级品质单调与一次成长

**Files:** 修改`skill_growth_scaling.gd`、`skill_manager.gd`、`skill_effect_adapter.gd`、`skill_trigger_rule_adapter.gd`、`upgrade_pool.gd`、`upgrade_option_builder.gd`及`data/config/skill_system_config.json`；测试新增`tools/verify/verify_skill_upgrade_monotonic.gd`、`verify_skill_damage_growth_paths.gd`，迁移现有成长测试。

**Interfaces:** `SkillGrowthScaling.keep_highest_rarity(current: String, requested: String) -> String`；保留`stat_multiplier(instance, stat_kind)`入口。新增`rarity_applies_to(stat_kind: String) -> bool`；品质保留在学习与升级入口统一处理，不交给UI猜测。

- [x] 写失败用例：传奇Lv1选普通Lv2卡后实例品质仍传奇；空品质保留；满级拒绝不改变品质；普通到稀有仅显式请求才升品质。
- [x] 写成长用例：cast Lv2传奇直接与tick伤害倍率均`1.12×1.50=1.68`；冷却倍率0.96、半径1.05、持续1.06；core固定1；弹幕/连锁/召唤各命中一次不得重复乘1.68。
- [x] 运行新测试证明旧行为失败，OutputRoot分别`T01-monotonic`、`T01-growth`。
- [x] 实现规格第3节；首次抽取与普通升级分开；保持所有伤害经过DamagePacket和统一来源/减伤，不引入直接扣血捷径。修正`spawn_projectile_burst`等遗漏路径和调度/规则双重CD缩放。
- [x] 跑新测试、`verify_skill_growth_scaling.gd`、`verify_skill_growth_rule_adapter.gd`、`verify_skill_growth_summon_runtime.gd`；记录旧断言变更原因后提交。

### T2：临时增益生命周期、scope与一次性强化

**Files:** 修改`modifier_store.gd`、`modifier_source.gd`、`modifier_aggregator.gd`、`skill_action_modifier_executor.gd`、`skill_manager.gd`、`player_controller.gd`及buff技能数据；测试新增`verify_skill_timed_modifiers.gd`、`verify_skill_modifier_consumption.gd`。

**Interfaces:** `ModifierStore.set_timed_source(source_id: Variant, effects: Array, scopes: Array, duration: float, refresh: StringName = &"replace") -> void`；`tick_timed_sources(delta: float) -> void`；`clear_skill_sources(skill_id: StringName) -> void`。沿用`collect`/`clear_all`，时长用游戏delta而非系统时钟；一次性施法加成记录独立充能，在T3成功施放事件中消费。

- [x] 写测试：过热加成对另一个cast生效而不作用attack；到5.01s回到基线；2s时重新授予5s后仅刷新不相加；暂停推进0s仍保留；移除技能或重开立即清除。
- [x] 写属性消费测试：高频放电真正减少雷电cast冷却；寒意延展影响Chilled/Frozen；冰封易伤影响合格目标；庇护仅有盾时增伤；未知stat导致内容验证失败。比较实际数值，不只检查属性字典。
- [x] 红灯后接入ModifierStore；把数据stat/scope迁移到被实际读取的标准键，保留静态与限时来源区分。
- [x] 写灵魂收割一份充能只强化一次完整释放、不会强化后续普通命中；消费接入T3时补齐测试，不在M1验收中忽略未接接口。
- [x] 运行隔离测试，OutputRoot=`T02-timed`/`T02-consumption`；回归`verify_modifier_effect_contract.gd`与既有玩家属性测试，提交。

### T3：真实事件来源、成功施放与派生限制

**Files:** 新增`skill_event_context.gd`、`skill_proc_policy.gd`、`scripts/runtime/run_combat_clock.gd`；修改`skill_event_bus.gd`、`skill_component_runner.gd`、`skill_action_executor.gd`、`skill_trigger_rule_adapter.gd`、`condition_evaluator.gd`、`damage_trace_context.gd`及伤害扩展登记；测试`verify_skill_event_provenance.gd`、`verify_skill_proc_chain_limits.gd`。

**Interfaces:** `SkillEventContext.from_context(context: Dictionary, event_name: StringName) -> Dictionary`；`SkillProcPolicy.can_generate(context: Dictionary, proc_id: StringName) -> bool`；`child_context(context: Dictionary, proc_id: StringName) -> Dictionary`。事件字段固定`origin_skill_id, listener_skill_id, event_id, parent_event_id, proc_depth, is_copy, can_generate_secondary_proc, combat_seconds`；有效动作执行后发`skill_cast_succeeded`。`RunCombatClock.tick(delta: float) -> void`、`now_seconds() -> float`、`reset() -> void`；仅运行态推进，重开归零，后续资源窗口和对象对ICD消费同一时钟。

- [x] 测试圣锤事件被其他技能监听后origin仍圣锤；无目标失败创建不发成功施放；一次3陨石仅计1次cast；监听器不能把来源改成自身。
- [x] 测试二重落雷/复制产生的派生伤害不会继续计数自身；护盾-雷击-补盾链有限结束；65个队列事件第1帧64、第2帧1，不丢事件且顺序不变。
- [x] 冷却可配置`cooldown_scope=skill/target/object_pair`，默认skill；按目标ICD必须包含目标实例，按对象对包含稳定对象实例ID，不能因换监听器失去原始ID。补测试：暂停10s不缩短6sICD，恢复后只消耗运行delta，重开不继承旧时间。
- [x] 接入成功施放和一次性增伤消费；原先`on_cast`动作分派保留，但计数/复制不得监听未确认成功的广播。
- [x] 隔离两项新测试，OutputRoot=`T03-source`/`T03-proc`；跑现有严格伤害与来源上下文回归，完成M1事件接口提交。

### T4：燃烧、诅咒与控制状态行为

**Files:** 修改`status_effects.json`、`status_effect_manager.gd`、`status_effect_tick_helper.gd`、`skill_action_status_executor.gd`；新增`verify_skill_status_lifecycle_v2.gd`、`verify_skill_status_race_conditions.gd`。

**Interfaces:** `StatusEffectManager.resolve_cursed(reason: StringName) -> bool`，输出T3事件字段及`resolution_id, stacks, resolved_damage, resolution_reason`；`pause_status(status_id: StringName, source_id: StringName) -> void`、`resume_status(...) -> void`；冻结阈值通过统一玩家属性读取。已有`consume_status_duration`保持bool入口，强制到期走同一结算函数。

- [x] 写100P测试：1层燃烧每1s36伤害且tick后仍1层；5层每tick180；重复施加只刷新；到期与最后tick同一时刻按预定顺序结算最后tick后移除，4s总量144/720。
- [x] 写Cursed测试：t0一层、t2加一层，t3只结算150伤害；叠满不续时；强制引爆只结算一次；死亡后不再结算；固定期限不能被全局status_duration增益偷偷延长。
- [x] 写冻结测试：7层/核心5层成功、消费Chilled、普通1.2s/精英0.5s/Boss0.15s；免疫期不重复触发；冻结与Cursed到期同帧采用冻结暂停；死亡转移只能走一个分支。
- [x] 实现每状态显式refresh_rule；对持续时间为0的instant状态保留原规则；保留状态来源与有效Power，不改变无关poison/bleed规则。
- [x] 跑两项新测试与现有燃烧、冰霜状态回归，OutputRoot=`T04-lifecycle`/`T04-race`；迁移旧燃烧衰减断言并登记替代测试，验收M1。

## M2：构筑与神系闭环

### T5：独立核心/融合容量与一次替换事务

**Files:** 修改`skill_slot_policy.gd`、`skill_manager.gd`、`skill_offer_service.gd`、`player_controller.gd`、`run_hud_controller.gd`；新增`skill_replacement_service.gd`、`scripts/ui/skill_replacement_view.gd`、`verify_skill_slot_capacity_v2.gd`、`verify_skill_replacement_transaction.gd`。

**Interfaces:** `SkillSlotPolicy.capacity_group(definition: Dictionary) -> StringName`返回attack/dash/ordinary/passive/core/fusion；`SkillReplacementService.begin(player: Node, new_skill_id: StringName, rarity: String) -> Dictionary`；`confirm(player: Node, transaction_id: String, old_skill_id: StringName) -> bool`；`cancel(transaction_id: String) -> void`。事务快照只暂存选项，不先删旧技能。

- [x] 测试5普通主动满仍可学1核心、1融合；第二核心/融合拒绝；总容量及HUD为12；attack/dash不占普通槽；主动执行列表包含新增独立类别。
- [x] 测试替换取消不消耗升级/机会/神系；确认移除旧状态、召唤、buff、复制快照的来源，原子新增新技能；新技能失效则回退；每局最多确认一次。
- [x] 接入升级选项和最小可用替换UI；核心/融合显示独立位置，避免等T14才出现看不见的技能。
- [x] 隔离测试，OutputRoot=`T05-slots`/`T05-replace`；跑`verify_skill_slot_capacity_rules.gd`、`verify_run_hud_skill_slots.gd`、`verify_attack_skill_replacement.gd`，提交。

### T6：机制前置、阶段供给与保底

**Files:** 新增`skill_requirement_policy.gd`；修改`skill_offer_service.gd`、`skill_learning_policy.gd`、`upgrade_pool.gd`、`upgrade_offer_policy.gd`、`skill_definition.gd`、配置加载/校验及技能offer_rule；测试`verify_skill_requirements_v2.gd`、`verify_skill_offer_progression_v2.gd`。

**Interfaces:** `SkillRequirementPolicy.evaluate(player: Node, definition: Dictionary) -> Dictionary`返回`available: bool, missing_requirements: Array[String], capability_sources: Dictionary`；能力标签包括apply_burning/apply_chilled/apply_conductive/apply_cursed/apply_judgment/apply_instability/fire_ground/frost_area/chaos_rift/divine_barrier/overload/divine_punishment/fission/copyable_cast/copyable_attack。

- [x] 测试仅火攻击+冰被动不能开融合；火2技能+冰状态来源1技能且Lv6可开纯状态融合；专属冰矛融合缺冰矛不能开；核心Lv7拒绝、Lv8且3同系技能与必要反应准入。
- [x] 测试首次神系选择至少1张有即时收益；拥有两神系后第三系永不出现；已学可升级保底；核心连续3次未展示第4次展示；只有被动/满槽/无有效核心不制造死牌。
- [x] 用固定RNG种子测选项序列和权重统计；类别权重与品质概率分开，不要求随机卡顺序等于新概率表某一固定顺序。
- [x] 实现资格共享给Dev、学习入口和UI，禁止抽卡准入与实际学习入口各维护一套规则。新增字段经GDScript和Node双端validator校验；能力映射来自已验证行为而非名字猜测。迁移尚未完成的融合设offer_enabled=false，T12/T13逐张通过行为合同后启用；这是阶段迁移措施，不能用于最终验收绕过60张完整要求。
- [x] 跑新测试、`verify_god_school_learning_rules.gd`、`verify_upgrade_pool_active_skill_guarantee.gd`及现有学习选项测试，OutputRoot=`T06-requirements`/`T06-offers`，提交。

### T7：火焰/诅咒闭环与Boss充能

**Files:** 修改两神系28技能、`skill_action_status_executor.gd`、`skill_trigger_rule_adapter.gd`；新增`scripts/skills/skill_resource_counter.gd`、`verify_fire_curse_cycle_v2.gd`、`verify_fire_curse_boss_cycle.gd`。

**Interfaces:** `SkillResourceCounter.add(skill: RefCounted, key: StringName, amount: float, threshold: float) -> int`返回达到门槛次数并保留余量；`clear(skill: RefCounted) -> void`。死亡/状态结算计数由T3稳定event_id去重。

- [x] 测试5次Boss燃烧tick为火循环+1、12点燃爆/20点核心；死亡+1与同次tick不双计；诅咒Boss2次结算+1点；传播后的死亡不导致同尸体重复事件。
- [x] 测试引燃只消耗cast命中的1s燃烧；焦土仅真实火地提高燃烧；燃爆连锁最多初代+2派生；死亡契约死亡1.8P、到期0.9P且只爆一次。
- [x] 调整28张的描述/条件/属性；亡骸等击杀召唤保留短板，不能为每项收益都加Boss无条件补偿；只为核心资源和契约加规格规定的补偿。
- [x] 跑两项新测试和`verify_fire_skill_runtime_smoke.gd`、`verify_curse_skill_runtime_smoke.gd`，OutputRoot=`T07-cycle`/`T07-boss`；提交。

### T8：冰霜控制、处决与专项技能

**Files:** 修改14冰系技能、`skill_action_status_executor.gd`、控制转换/伤害profile读取处；新增`verify_frost_control_v2.gd`、`verify_frost_execute_tiers.gd`。

**Interfaces:** `SkillActionStatusExecutor._execute_policy(target: Node, params: Dictionary, context: Dictionary) -> Dictionary`返回`mode, eligible, threshold, bonus_amount, cooldown`；阶级来自现有统一目标profile，不新增组名猜测。命中前状态保存在T3事件context中。

- [x] 测试寒霜攻击首次1层、已有Chilled后额外1层；冰矛未冻结无溅射、Frozen有溅射；霜环冲刺/8人拥挤共享6sICD；核心阈值5真正生效。
- [x] 测试普通10%/精英4%处决；Boss低于10%仅额外`min(0.8P,1%maxHP)`且5sICD，不直接杀死；不可移动Boss不被拉扯，仍受到合法伤害。
- [x] 测试Boss冻结破绽0.5s/10%、ICD2s、总减速≤30%，普通怪保持原冰冻反馈。
- [x] 实现并跑新测试、`verify_frost_skill_runtime_smoke.gd`、`verify_frost_frozen_vulnerability_runtime.gd`，OutputRoot=`T08-control`/`T08-execute`，提交。

### T9：雷电反应和神圣防御时间契约

**Files:** 修改28技能、`area_effect.gd`、`skill_action_area_executor.gd`、`skill_action_modifier_executor.gd`、召唤卫士配置与玩家吸收伤害阶段；新增`verify_thunder_proc_v2.gd`、`verify_holy_shield_time_v2.gd`。

**Interfaces:** `area_step`含`area_instance_id, elapsed, origin_skill_id, position, radius`，不含虚构敌人target；反击通过同技能共享cooldown_key；卫士防御通过现有吸收伤害pipeline添加来源，不直接回补已扣掉的生命。

- [x] 测试二重落雷仅3次初代正雷伤命中触发；过载最多传播4邻居且排除原目标；高频/静电影响真实CD；派生落雷不会自我循环。
- [x] 测试神圣结界0/1/24敌人时补盾均每秒1%最大生命；玩家离区无补盾；护盾上限35%；溢出触发虔诚但不堆无限加成；破盾与同击受重伤只触发一次反击。
- [x] 测试卫士2s内只挡一次，最多10%最大生命；guard移除后不再挡；“短暂无敌或护盾”统一文案为护盾，不新增未设计的无敌。
- [ ] 实现、新测试、雷/圣runtime_smoke及召唤system_behavior已通过（180/180）；阶段完整局实战验收未通过，M2暂不勾选整体验收。详见M2报告。

## M3：混沌、成长与融合

### T10：真实复制与混沌可预判变化

**Files:** 新增`skill_cast_snapshot_service.gd`、`skill_replay_service.gd`；修改14混沌技能、`skill_action_modifier_executor.gd`、`summon_controller.gd`、`summon_attack_component.gd`、`summons.json`；测试`verify_chaos_replay_v2.gd`、`verify_chaos_mutation_v2.gd`。

**Interfaces:** `SkillCastSnapshotService.record(context: Dictionary, actions: Array) -> bool`；`get_last(filter: Dictionary = {}) -> Dictionary`；`clear_origin(skill_id: StringName) -> void`；`SkillReplayService.replay(snapshot: Dictionary, context: Dictionary, damage_scale: float) -> bool`。快照字段`version, origin_skill_id, school, actions, base_growth_applied`，纯序列化数据，无Node/Callable。

- [x] 用冰矛/火雨验证回声真正重放弹道/区域，0.4伤害倍率只一次；分身每2s按0.35复制；奇点复制非混沌cast0.5；不能复制heal/shield/summon/core/fusion。
- [x] 测试复制不推进自身计数；空快照不生成固定假弹幕；来源技能移除清快照；失效目标重选有效目标；暂停不耗时；分身消失清pending动作。
- [x] 测试熵增4分支轮换、最多最近2种、5s结束；几何变化每代最多一次；反常稳定每5次合格混沌cast充能，第6次+25%，未成功释放不消费。
- [x] 实现记录/纯参数重放，排除任何有业务副作用动作；原始状态传播允许但使用T3派生限制；奇点2s后爆发而非与吸附同时立即爆发。
- [x] 隔离新测试及`verify_chaos_skill_runtime_smoke.gd`、召唤/死亡重开回归，OutputRoot=`T10-replay`/`T10-mutation`，提交。

### T11：18cast关键等级与统一成长预览数据

**Files:** 新增`skill_growth_profile.gd`；修改`skill_definition.gd`、`skill_effect_adapter.gd`、`skill_component_runner.gd`、18cast数据和validator；测试`verify_skill_level_milestones_v2.gd`。

**Interfaces:** `SkillGrowthProfile.resolve_actions(definition: Dictionary, level: int) -> Array`、`describe_next_milestone(definition: Dictionary, level: int) -> Dictionary`；按effect_id定位覆盖，不依赖效果数组位置；先应用里程碑的基础覆盖，再统一等级/品质计算，额外乘法明确只有一次。

- [x] 按规格第7.1节为18项建立Lv1/Lv3/Lv5三组断言；相同实例重复请求Lv5参数结果相同，不能再加一枚弹体；Lv2→3→4保持Lv3效果但不再次叠加。
- [x] 测试火雨3/4/4枚，伤害按同目标衰减；冰矛6/8/8穿透；CD变更与加弹体不能误修改全部规则；copy重放该等级最终动作且不再套一次成长。
- [x] 对`thunder_cast_emp_ring`等全部ID先通过T0清单验证，任何不存在的名称必须改为已有真实ID，不创建另一个技能来掩盖拼写错误。
- [x] 实现规格表，测试每项输出对象数、有效伤害、状态、最终CD；没有改动的66基础技能验证通用成长并保留Lv1动作。
- [x] 跑新测试和成长适配回归，OutputRoot=`T11-milestones`，提交。

### T12：30代表融合的真实交互

**Files:** 新增`fusion_interaction_service.gd`、`tools/verify/fusion_semantic_cases.json`、`verify_fusion_semantics_v2.gd`、`verify_fusion_geometry_v2.gd`；修改`projectile.gd`、`area_effect.gd`、`combat_target_registry.gd`、30融合数据、offer_rule和原numeric合同。

**Interfaces:** `FusionInteractionService.observe_projectile_area(projectile: Node2D, area: Node2D, context: Dictionary) -> void`；`observe_area_overlap(first: Node2D, second: Node2D, context: Dictionary) -> void`；`reserve(pair_id: String, interaction_id: StringName, cooldown: float) -> bool`；`clear_object(instance_id: int) -> void`。用空间索引候选和真实形状相交，不做所有对象全组合扫描。

- [x] 为规格第9节首批30张逐张写案例：正确来源/状态/几何触发1次；错误来源、缺状态、无重叠分别0次；命中前后状态变化不混淆；计数、ICD和派生标记符合规格。
- [x] 专项测试：咒文回声监听cursed_resolved；太阳圣锤非圣锤神圣伤害不触发；审判冰矛非冰矛冰伤不触发；跃迁雷球无裂隙不传送；蒸灼雾域只建1份伤害区。
- [x] 空间测试覆盖擦边、不相交、穿越、同对象第二次进入、传送出入口、对象销毁/池复用；每条几何测试真实推进物理帧。
- [x] 实现真实交互、冻结暂停/结算、目标选择和对象对ICD；offer_enabled只在对应语义案例全部通过后启用；其他融合暂保留迁移状态，不删ID。
- [x] 同步原文案和数值表，只保留原语义对应的一套伤害；更新旧“字段包含某个数值”断言并增加实际每秒总伤害断言。
- [x] 跑两新测试与融合runtime_smoke，OutputRoot=`T12-semantics`/`T12-geometry`；首批30accepted后提交。

### T13：剩余30融合与全技能覆盖

**Files:** 修改剩余30融合数据、`fusion_semantic_cases.json`、`skill_rebalance_coverage.json`；复用T12服务，仅缺原语义动作时扩展对应动作族；新增`verify_skill_rebalance_coverage.gd`。

**Interfaces:** 每融合case固定`skill_id, required_skills, positive_fixture, negative_fixtures, expected_damage, expected_statuses, expected_spawn_count, max_trigger_count`；fixture包含形状/位置/来源/原始状态/生命阶级，无“任意配置即可触发”的占位用例。

- [x] 按规格第9表第二批逐张写真实正反案例；黑雷收束只第5次本法阵落雷；冰棺契约死亡仅转移不双结算；裂火分叉必须有火弹进入裂隙；圣雷裁决反应链有限。
- [x] 调整事件与依赖至符合各自描述，补全原设计的形状、传送、下一次充能、延时与定向选敌；每完成一个神系组合4张就跑组合回归。
- [x] 全量台账检查：144个ID仍存在、144条accepted、60融合全部offer_enabled；每项至少1正例和1语义负例，必要专项负例依T12；任何未完成项阻止完整交付。
- [x] 跑T12两测试和全覆盖测试，OutputRoot=`T13-coverage`；六神系runtime_smoke全回归，完成M3提交。

## M4：玩家反馈与调优

### T14：卡片、HUD、替换和说明一致性

**Files:** 新增`scripts/ui/skill_preview_service.gd`；修改`skill_effect_summary_builder.gd`、`upgrade_option_builder.gd`、`skill_learn_option_builder.gd`、`run_hud_controller.gd`、`skill_replacement_view.gd`、实际拥有卡片渲染职责的UI文件和gods.json；测试`verify_skill_preview_runtime_parity.gd`、`verify_skill_rebalance_ui.gd`。

**Interfaces:** `SkillPreviewService.build(player: Node, skill_id: StringName, level: int, rarity: String) -> Dictionary`返回`damage, dps, cooldown, radius, duration, statuses, shield_amount, next_milestone, requirements`；使用T1/T11及运行时resolver，不再次实现公式。卡片消费预览字段，不读取内部proc字段展示给玩家。

- [ ] 在100P夹具断言预览与实际直接/区域/召唤/复制输出误差≤取整1点、冷却误差≤0.01s；多目标倍率与未知未来命中不伪装成单体DPS。
- [ ] UI测试正常与较窄窗口、中文长描述、满12技能、核心/融合独立槽、替换取消和确认、Lv5无下一里程碑；卡片明确品质保持而非随机变化。
- [ ] 更新全部基础/融合说明，Burning等内部名以中文呈现；移除已实现神系“规划中”描述；显示核心充能、回声就绪，但不显示代码ID。
- [ ] 隔离headless合同测试与Rendered视觉测试，OutputRoot=`T14-parity`/`T14-ui`；Rendered使用隔离脚本`-Rendered`，截图只能写E:/codex；检查截图后提交。

### T15：同条件平衡矩阵与性能预算

**Files:** 新增`scripts/runtime/skill_balance_metrics.gd`、`tools/verify/verify_skill_balance_matrix.gd`、`tools/verify/verify_skill_rebalance_performance.gd`、`tools/verify/skill_balance_presets.json`；修改既有`real_full_run_profiler.gd`按需接采样，最后调整skills/status/system_config数值。报告`docs/skills/skill_rebalance_validation.md`，原始CSV/JSON仅E:/codex。

**Interfaces:** `SkillBalanceMetrics.record(event: Dictionary) -> void`；`snapshot() -> Dictionary`；`reset() -> void`。预设包含`character_id,map_id,meta_state,seed,skills,levels,rarities,controller_policy`，计量含actual_damage/overkill/status_damage/trigger_count/denied_reason/buff_uptime/shield_generated/shield_absorbed/object_peak/frame_p95。

- [ ] 建立规格六种固定战斗场景；每神系3构筑×10探索种子，确认使用20个独立固定种子；15融合组合与无融合对照各5种子，异常扩20；固定选择策略、同升级预算。
- [ ] 先跑100P无随机夹具验证计量正确，再跑真实300s局；报告单体、清群、存活、资源循环、Boss有效触发、控制与防御收益，不能只汇总DPS。
- [ ] 以单体跨度≤1.5、清群≤1.8、融合增益15%-35%为试调目标，超标逐项解释并改一个维度≤10%；两轮仍超标回到语义/资源设计，不继续盲调。
- [ ] 测12技能、24敌人和实际密集波次；与T0同机基线比较p95劣化≤10%，p95≤16.7ms目标；基线已超标时明确性能欠项。无无限对象增长、队列饥饿或池复用污染。
- [ ] 输出统计与日志索引，OutputRoot=`T15-matrix`/`T15-performance`；报告写明样本量、自动控制限制、未达到目标项；每轮调参单独提交。

### T16：回归、文档发布与回滚演练

**Files:** 修改`docs/skills/skills.md`、`god_skill_integration_lessons.md`、`skill_rebalance_validation.md`、台账和`tools/verify/README.md`。本任务不得引入未测的新玩法。

**Interfaces:** 发布清单包含`source_revision, config_revision, validated_scripts, log_paths, coverage_counts, accepted_balance_targets, remaining_risks, rollback_commits`。

- [ ] 从隔离用户目录全新启动，跑六神系/融合runtime_smoke、成长、槽位、供给、伤害、状态、召唤、HUD、暂停和重开回归；所有新测试全跑。静态跑内容/Modifier/严格伤害/边界校验。
- [ ] 人工试玩至少6神系各2局，覆盖最小可成型构筑、满12技能、移动Boss、不可移动Boss、替换取消；记录卡片预测、触发画面和实际收益一致性。
- [ ] 按台账核对144项，检查每条旧断言的替代行为证据，移除迁移中提示；凡未完成不标记完整交付。
- [ ] 在执行期隔离worktree/分支中演练回退最近数值提交，再恢复；不得对用户主工作区使用reset --hard。缓存/用户文件始终留在E盘，不清理用户其他目录。
- [ ] 输出可运行测试版本、文档、实际测试证据与遗留项。未达平衡或性能目标可交付“测试版”，但不能宣称已平衡/生产就绪。用户未要求发布时不上传、不合并、不推送。

## D. 最终验收清单

- [ ] 品质升级与所有输出路径均单调；倍率只算一次。
- [ ] 限时效果结束、刷新、暂停、来源移除、重开五种生命周期有行为证据。
- [ ] 144技能ID保留；84基础、60融合均有对应行为案例和条件拒绝案例。
- [ ] 普攻1、冲刺1、普通主动5、被动3、核心1、融合1实际学习/执行/HUD一致。
- [ ] 两神系限制、核心Lv8前置、融合Lv6前置、具体能力依赖和保底均通过。
- [ ] 燃烧、诅咒、冻结、过载、神罚、裂变不重入无限循环；Boss不被直接处决。
- [ ] 复制保留输出形态但不复制业务副作用；源技能移除或目标失效无悬空引用。
- [ ] 18cast的Lv3/Lv5变化可见、可测且无累加污染。
- [ ] 卡片数值与运行时一致；玩家无需猜测英文状态或隐含门槛。
- [ ] 平衡/性能报告有基线、样本量与日志，试调数值未达目标的项明确列出。
- [ ] C盘无本任务主动写入；运行时所有可控输出路径为E:/codex；产品变更均在E盘。

## E. 实施前交接

这份方案的设计决策尚待用户审阅。推荐由同一执行者按M1→M4串行实施，因为事件、成长、状态和共享JSON互相依赖；每个阶段结束再进行独立审查。若用户选择子代理方式，按任务交接并明确文件所有权、共享工作区及不得撤销他人修改。

实施时首先复核工作区差异与本方案，不把本轮“输出执行方案”的授权解释为已经授权产品改造。用户确认方案并选择执行方式后，使用相应执行技能开始T0。
