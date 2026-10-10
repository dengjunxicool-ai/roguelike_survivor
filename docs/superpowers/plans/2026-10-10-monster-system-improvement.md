# 怪物系统分阶段执行方案

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 本文件是待审阅的执行方案，M0–M12 均未执行；不因保存本方案而自动开始改动、调用子代理、提交、推送或合并。

**Goal:** 修正无法合理躲避的伤害和失效行为，让怪物形成清晰的战术分工，让地图、波次和奖励与玩家看到的提示一致。

**Architecture:** 保留 EnemyBase 聚合根、behavior registry、enemy action registry、统一 DamagePacket、生成服务和死亡奖励管线。距离规则由公共解析入口统一；预警和伤害生命周期由战斗对象管理；Boss 的持续机制由独立调度器登记；波次与地图使用同一份遭遇配置。先修实现缺陷，再补职责，最后调数值，不重写整个怪物系统。

**Tech Stack:** Godot 4.6.3、GDScript、JSON、Node.js、PowerShell；沿用现有验证矩阵，不新增产品依赖。

**Spec:** 本文件第 1–5 节是本轮建议采用的设计规格，第 6 节是实施任务，第 7–9 节是验收与交付要求。承接本次怪物系统审查；本文件里的候选数值尚未经过平衡验证，不能标记为已批准或已上线。

## Global Constraints

- 用户要求：不允许向 C 盘写入任何文件。项目文档和代码位于 `E:/roguelike_survivor/`；日志、缓存、截图、隔离存档和测试报告放在 `E:/codex/monster-system/` 或现有矩阵工具使用的 `E:/codex/canonical-refactor/monster-*`。
- 开始实施前读取 `codex.md`、`docs/PROJECT_ENGINEERING_GUIDELINES.md`、`docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`；以实施时实际代码为准重新核对基线。
- 当前工作区包含此前的预警清理、射手距离修复及其验证，也包含其他未跟踪的技能文档。保留所有现有改动，不覆盖、不清理、不将无关文件纳入提交。
- 保留现有角色、技能系统、怪物 ID、enemy_rank 分类、来源归因、正式存档和掉落结算入口。新增字段同步 schema、加载校验和工具校验。
- 伤害只走 DamagePacket 和 take_damage；不在行为或表现脚本中直接改血量。死亡、分裂、经验、灵魂和击杀统计继续经过死亡奖励管线。
- 缓存和存档隔离必须在启动 Godot 前完成；受控环境中通过 PowerShell 直接启动 Godot，不能将 npm/Node 二级启动崩溃当作测试结果。
- 普通怪总预算不因拥挤被静默裁剪；不恢复已经移除的全局 40 只存活限制。功能提交与数值调参分别记录，逐任务验证。
- 本轮不新增 300 秒强制失败条件，不重做六神系、核心与融合成长。技能与怪物同时调参时，必须固定其中一侧的版本。

## Review Focus

1. 相机缩放、偏移、窄视口或玩家踩入出生预警时，不能让可见怪物被清理，也不能为完成预算而强行贴身激活：M0、M7。
2. 预警中暂停、目标死亡、施法者死亡、场景重开或对象池复用时，不能提前命中、留下调度占位或沿用上一轮状态：M2、M3、M12。
3. 同一帧跨 Boss 血量阶段、投射物仍在场以及技能生成失败时，并发上限仍有效，失败不占冷却、不泄漏名额：M3。
4. 玩家卡在射程边缘、贴近射手或面对减速和支援加速时，行为不能抖动，增益不能累乘，冲锋不能重复命中同一目标：M4–M6。
5. 提前清场、预算已投完但精英事件未到、转场残留怪和召唤物未死时，不能丢失事件、重复奖励或永久卡住波次：M8–M10。

---

## 1. 范围与成功标准

本轮分为三个可独立验收的阶段：

| 阶段 | 任务 | 目标 | 阶段交付 |
| --- | --- | --- | --- |
| A：公平性与可靠性 | M0–M3、M7 的基础安全规则 | 修正远距离直接扣血、预警错误、并发失效与危险激活 | 怪物与 Boss 的攻击可解释、可验证 |
| B：职责与地图 | M4–M6、M9；依赖 M8 的事件接口 | 射手、召唤、支援、冲锋、封锁精英各有明确应对 | 怪物角色表、四地图遭遇与对应试玩样本 |
| C：节奏与平衡 | M8、M10–M12 | 分段投放、稀有奖励、统计采样、调参和全局回归 | 功能验收报告、平衡报告、发布候选版本 |

工程依赖决定实际顺序：`M0 → M1 → M2 → M3 → M4 → M5 → M6 → M7 → M8 → M9 → M10 → M11 → M12`。

阶段可以交付可玩版本，但不得将阶段 A 的功能通过描述为全部平衡通过。M8 要先于 M9 实施，是因为地图精英需要独立事件预算。

### 首轮不做

- 不增加一批新怪物；先让已有 16 种怪物发挥作用。
- 不制作新 Boss 全套资源；四图先共享地牢之心，地图变体技能作为后续迭代。
- 不为回避时序问题重写生成、伤害、状态或死亡系统。
- 不直接增加普通怪全局移速、伤害或血量；先完成行为，再测平衡。
- 深渊回廊本轮采用方向性出怪来形成夹击；实体墙壁和完整关卡碰撞不在首轮范围。

## 2. 攻击与生命周期规格

### 2.1 距离分离

- `base_stats.attack_range` 表示普通近身攻击范围，不再同时代表施法范围；非近战 Boss 设为 0，禁止直接范围攻击。
- 接触半径只取双方碰撞半径之和加 2 个世界单位；单独判断普通近身攻击，不与接触检测合并。
- 射手用 `behavior.preferred_distance`，召唤用 `summon_range`，施法用 `cast_range`，冲锋用 `dash_trigger_range`，Boss 用 `skill_range`。
- 上述行为必须填写专用距离；缺失、非正数、退避阈值倒置等配置在加载时拒绝，并指明 monster ID 与字段。
- 技能范围不修改碰撞体；伤害命中由弹体、区域或实际冲锋接触决定。

### 2.2 预警契约

攻击过程为 `warning → active → finished`。预警期间伤害为 0；地面预警锁定开始时的目标位置，攻击开始后不追踪玩家脚下。圆、冲锋通道、弹幕缺口有不同轮廓，不能只用颜色区分。

敌方区域新增可选 `warning_time`；持续时间 `duration` 从 active 阶段开始计时，首个周期命中在 active 开始时，随后按 tick_interval 命中，不在结束边界额外补一跳。`delayed_area_blast`、`shockwave` 转为预警后单次命中；`corruption_gaze` 转为预警后的持续区域。

该新语义只用于显式启用新生命周期的敌方区域。玩家技能和地图现有区域仍走原接口与原时序，避免连带修改所有区域。敌方 action params 统一保存 warning_time；迁移所有敌方 delay/warning_time 配置引用后再删除已无引用的旧参数，不能保留两套敌方参数优先级。

炸弹怪开始引信后停止普通接触攻击，0.8 秒后在半径 76 内只结算一次爆炸；击杀打断且遵循原有死亡奖励策略。闪烁应用于实际显示的精灵，另绘制爆炸范围。暂停冻结引信，失去目标不撤销已点燃的引信。

### 2.3 Boss 规则

- 删除 Boss 行为中的直接远距离伤害调用；Boss 基础接触伤害仅在真实碰撞半径内生效。
- 阶段一持续主要机制上限 1，阶段二和阶段三上限 2；预警也占名额。
- 地面爆发、冲击波、凝视和环形弹幕登记真实生命周期。环形弹幕等待属于本次释放的所有投射物结束；核心只在召唤动作期间占名额，核心存活由独立数量上限控制。
- 带 `mechanic_group = area_denial` 的地面封锁机制同时最多 1 个；禁止红圈、凝视、冲击波同时覆盖玩家原位置。
- 每次成功开始释放后，至少间隔 0.4 秒再尝试下一个技能；阻塞的技能保留待执行资格，不重复排队。
- 血量切换阶段不清除仍有效的占位，不让同一技能因阶段键变化连续重复释放；以 skill_id 保存共享冷却。
- 环形弹幕先预警 0.6 秒，展示安全扇区；安全缺口从环形 RNG 选择并处理跨 0 号索引，保持固定种子可复现。首次不同时改变弹速、数量和伤害。
- 本轮不启用狂暴。现有 rage_after_seconds 不视为已工作的机制；文档和 HUD 不展示未执行的狂暴承诺，后续采样后另立任务。

## 3. 怪物职责与首轮参数

下面参数为功能实现的首轮配置，M11 可以依据采样调整；验收测试读取配置和规则，不能锁死任意平衡数值。

| 怪物 | 职责 | 首轮行为参数 | 玩家应对 |
| --- | --- | --- | --- |
| 小史莱姆、骷髅兵 | 填充与成长 | 保持追逐和基础数值 | 移动清怪 |
| 蝙蝠 | 快速补位 | 首轮保留移速；后续按采样决定是否增加侧向接近 | 避免停留与堵路 |
| 弓箭骷髅 | 后排射击 | 射程 420；小于 220 开始后撤，达到 280 停止后撤；射程外超过 460 才转为追逐；预警 0.45 秒、冷却 2.2 秒 | 横移躲箭、突入后排 |
| 骷髅祭司 | 后排召唤 | summon_range 400；召唤前摇 0.8 秒；冷却 5 秒；每次 2 只；自身存活召唤物上限 4 | 优先击杀召唤者 |
| 战鼓哥布林 | 友军加速支援 | support_aura 行为；半径 220；每 0.5 秒刷新；增益残留 0.6 秒；普通友军移速 ×1.15；不强化自身、其他鼓手、精英、Boss、核心 | 优先切断支援 |
| 炸弹怪 | 迫使立即离开 | 引信 0.8 秒、爆炸半径 76；引信期间无普通接触伤害 | 及时拉开距离或击杀 |
| 暗影猎手 | 短前摇冲锋 | 触发 180；预警 0.6 秒；速度 360；时长 0.4 秒；冷却 4.5 秒；方向锁定 | 侧向闪避 |
| 骷髅队长 | 重型冲锋精英 | 触发 260；预警 0.9 秒；速度 420；时长 0.6 秒；恢复 0.7 秒；冷却 6 秒；每次冲锋对同一目标只命中一次 | 躲冲锋后输出 |
| 巨型史莱姆 | 跃击精英 | leap_and_slam 行为；触发 220；预警 1 秒；锁定跃击方向；速度 280、时长 0.6 秒；落地范围 110；恢复 0.8 秒；冷却 5 秒 | 躲落点并利用恢复期 |
| 毒雾母体 | 长持续区域封锁 | cast_range 360；预警 0.9 秒；半径 96；持续 4 秒；周期 1 秒；冷却 7 秒；同一施法者最多 1 个区域 | 保留退路、离开毒区 |
| 熔岩魔像 | 高威胁单次爆发 | cast_range 280；预警 1.1 秒；半径 110；单次命中；冷却 6 秒；恢复 0.8 秒 | 识别前摇、及时撤离 |
| 宝石史莱姆 | 有风险的奖励机会 | flee_player 行为；朝远离玩家方向移动；不主动攻击；存活 12 秒后逃离；一局最多 2 次事件 | 决定是否离开安全路线追击 |

毒、熔岩和跃击首轮沿用当前可归因的伤害量，不同时增加伤害；熔岩从多跳转单次后，单次使用原来一跳的伤害作为保守起点，M11 再调整。

巨型史莱姆死亡分裂为 3 只小史莱姆，子体不再分裂，不掉经验、不奖灵魂；父体死亡奖励只发一次。召唤物也不掉经验或灵魂，保留伤害、击杀事件的合法来源，避免祭司成为无限经验农场。

## 4. 波次、地图与奖励规格

### 4.1 时间模式

本方案推荐离散波次：提前清场可进入下一波，Boss 在第 8 波结束后登场。240 秒是正常推进的目标登场时间，不是固定触发时刻；300 秒保留为标准目标局长，不新增超时失败。计时统计应记录真实已用时间，不在 300 秒后冻结。

采用以下名义波长，使 8 波时长合计 226 秒，加 7 次 2 秒转场约为 240 秒：

| 波次 | 时长 | 普通怪初始预算 | 主职责 | 精英事件 |
| --- | --- | --- | --- | --- |
| 1 | 23 秒 | 35 | 单一填充，教会出生预警 | 无 |
| 2 | 28 秒 | 50 | 两类填充，形成围堵 | 无 |
| 3 | 28 秒 | 65 | 蝙蝠补位与追逐组合 | 无 |
| 4 | 28 秒 | 80 | 首次远程与重甲组合 | 波内 5 秒，地图精英 A |
| 5 | 33 秒 | 95 | 远程、毒虫、炸弹混合 | 无 |
| 6 | 33 秒 | 110 | 召唤与封锁压力 | 波内 5 秒，地图精英 B |
| 7 | 33 秒 | 125 | 支援与冲锋组合 | 无 |
| 8 | 20 秒 | 140 | 复合怪潮，随后 Boss | 无；宝石怪从普通池移除 |

每波按普通怪预算分为引入 25%、主压力 50%、收尾 25%。先计算 `delivery_window = duration - 8 秒 - spawn_warning_duration`，三个投放阶段覆盖该窗口的 0–25%、25–65%、65–100%；阶段起止比例均相对于 delivery_window。最后一批在窗口截止前创建，完成 1.5 秒显形后仍有完整 8 秒收尾。整数预算使用最大余数法，三段总数必须等于本波预算；密度加成先算总预算，再分段。

每批最多 15 只不变。投放仍使用 1.5 秒出生预警；空场只能加速当前阶段预算，不能越过阶段开始边界将全波提前灌入。阶段截止是投放目标，位置不可用时保留待投预算，不能以重叠出生完成指标。

正常期限尚有待投预算时进入最多 3 秒的 delivery_grace，停止创建新的精英/奖励事件、只完成既有待投请求并等待预警结束；仍无法完成则记录 wave_delivery_failed 并在验收报告判失败。生产流程在宽限结束后标记本波 incomplete 并进入带残留怪的转场，将未交付预算及原因写入结算诊断，不永久卡住，也不伪造全预算完成。正常地图必须通过全预算按期或宽限内完成的测试。这样目标 240 秒不是在异常拥挤条件下的保证。

清场休息与超时转场区分：

- 普通预算和所有强制精英事件已完成、没有阻止清场的敌人及预警时，可以提前清场；2 秒内没有新出生、敌方弹体和伤害区域，清理它们不发击杀奖励。
- 超时转场保留残留普通怪和精英，提示“下一波接近，残余敌人仍在”；继续战斗，不声称安全。召唤物与奖励怪不阻止提前清场，但进入清场休息时按回收策略清理，不走击杀掉落。
- Boss 出场前进入明确准备流程，清理残留普通怪、召唤物、敌方弹体与伤害区域；已有精英的策略固定为无奖励回收，避免场面叠加，击杀统计不得增加。然后显示 Boss 出生预警。

注意：既有技能持续改进计划写有“240 秒 Boss 出场”。实施 M8 前，应同步说明其时间模式为本方案的目标登场时间，并调整相关 HUD/验证期望，不能同时维护固定时间与离散波次两套规则。该同步属于本轮的明确范围决策，不代表已修改另一份计划。

### 4.2 组合控制

每个角色组独立设置权重，不再在一个 enemy_ids 列表里等概率混合所有职责。初始角色权重：填充 55%、追击 20%、远程 15%、支援 10%；某波没有某职责时按其明确配置重新分配，不运行时隐式添加怪物。

采用角色占场限制：远程最多 6、支援最多 3、冲锋最多 4；预警中的怪也占名额。某角色满额时，只从本波仍可用的填充/追击组重抽，保留总预算；全部不可用则延期。这里限制的是职责比例，不裁剪普通怪总数。

精英事件预算独立于普通怪预算，每个事件最多执行一次；普通预算投完不能阻止精英事件。强制事件未执行时不能提前结束波次。

### 4.3 地图遭遇

`data/maps/maps.json` 新增 `encounter`，包括 `group_weight_overrides`、`elite_events` 和 `spawn_pattern`。保留地图 ID 和 unlock；预览精英由 encounter.elite_events 派生，迁移消费者后移除独立 elite_preview_ids，防止两份名单漂移。

| 地图 | 普通池调整 | 第 4 / 第 6 波精英 | 出怪模式 |
| --- | --- | --- | --- |
| 废弃地牢 | 标准组合 | 巨型史莱姆 / 骷髅队长 | 视口安全区均匀采样 |
| 瘴毒墓园 | 毒虫、祭司组权重 ×1.5，重归一化 | 巨型史莱姆 / 毒雾母体 | 标准采样，避开正在生效的地图毒区 |
| 熔火神殿 | 炸弹、重甲组权重 ×1.5，重归一化 | 骷髅队长 / 熔岩魔像 | 标准采样，避开生效熔岩区 |
| 深渊回廊 | 追击、冲锋组权重 ×1.5，重归一化 | 骷髅队长 / 骷髅队长 | 在视口左右各 25% 的侧带交替投放 |

深渊回廊保留已有数量 +12% 作为待测候选，但改为真实作用于可见采样的模式；预览不再把普通暗影猎手标为精英。地图 difficulty 暂作为展示评级，不假定它会自动加倍率；M11 验证实际难度排序后再调整评级文案。

### 4.4 宝石事件

第 3 波与第 7 波各有一次 35% 的宝石事件抽签，抽签使用独立派生 RNG；整局最多 2 只。波内第 5 秒执行一次抽签，不因预算已投完而跳过，不因重试反复抽签。宝石怪不计普通预算，不阻止波次结束。

保留现有 24 点基础经验作为首轮奖励。自然逃离、转场回收和出生失败均无掉落、无灵魂、无击杀；玩家击杀才执行原死亡奖励。到 Boss 准备阶段回收未击杀的宝石怪。

## 5. 文件边界与拟新增接口

下表中的新文件均为拟创建，不表示当前已经存在。

| 文件/目录 | 责任 | 所属任务 |
| --- | --- | --- |
| `scripts/enemies/enemy_config_helper.gd`、`enemy_base.gd` | 公共距离解析、真实接触、少量组件编排 | M1 |
| `scripts/combat/damage_area.gd`、`scenes/combat/damage_area.tscn`、`scripts/combat/projectile.gd` | 敌方预警、命中、实例代次与池结束通知 | M2–M3 |
| 新建 `scripts/enemies/combat/enemy_attack_telegraph.gd` | 只绘制圆、冲锋通道、扇区与阶段变化，不结算伤害 | M2 |
| 新建 `scripts/enemies/skills/boss_mechanic_scheduler.gd` | 占位、真实持续机制、冷却和阶段切换 | M3 |
| `scripts/enemies/behaviors/` | 移动和行为状态，新增 support_aura、leap_and_slam、flee_player | M4–M6、M10 |
| 新建 `scripts/enemies/enemy_support_buff_controller.gd` | 来源租约、规范 Modifier effects 的聚合和到期清理 | M5 |
| `scripts/enemies/spawning/`、`timeline/` | 安全出生、预算、事件、阶段和角色选择 | M7–M10 |
| 新建 `scripts/maps/map_encounter_resolver.gd` | 将地图遭遇覆盖合成有效波次，供 runtime 与预览共用 | M9 |
| `scripts/game/run_stats_tracker.gd` | 分怪物/技能归因和波次指标，不反向依赖 DevTools | M11 |
| `data/enemies/`、`data/waves/`、`data/maps/`、`data/config/content_schema.json` | 玩法配置和合法字段 | 对应任务 |
| `tools/validate/`、`tools/verify/`、`package.json` | 配置校验、行为断言与矩阵登记 | 每个任务 |

## 6. 逐任务执行

每个代码任务采用以下闭环：写能够复现旧问题的验证 → 确认失败原因 → 实现本任务最小改动 → 本任务验证与相关旧验证通过 → 检查 diff → 记录交付。只有获得提交指令时才进行按任务提交；不得把功能任务和全局倍率调整混为一个提交。

### M0：建立当前版本的可重复基线

**文件：** 读取现有生成、射程、死亡、波次验证；在 `docs/enemies/monster_system_validation.md` 新建执行台账。报告放在 E:/codex，不保存测试存档到项目或正式用户目录。

**输入/输出：** 输入实际 HEAD、工作区 diff、当前配置；输出基线版本标识、未提交补丁清单、定向矩阵、固定种子及真实渲染样本。

- [ ] 记录已存在的预警显形保护、可见区域清理保护、射手 preferred_distance=420，不重复实施此前修复。
- [ ] 运行第 7 节的基线命令，确认生成生命周期、射程、死亡奖励、波次人口和严格伤害接口通过。
- [ ] 采集 1280×720、1920×1080、窄视口三种场景；保存预警结束、射手射击和 Boss 首次伤害的样本。
- [ ] 明确基线中已存在的失败；后续比较使用同一角色、地图、构筑、RNG 和渲染设置，不将旧失败算作本轮已解决。

**完成条件：** 日志与版本对应；已存在的两项修复有回归证据；没有写入 C 盘或正式存档。预计 0.5–1 人日。

### M1：拆开接触、近身攻击和行为距离

**修改：** `scripts/enemies/enemy_base.gd`、`enemy_config_helper.gd`、`behaviors/boss_dungeon_heart_behavior.gd`、`data/enemies/enemies.json`、`data/config/content_schema.json`、`tools/validate/validate_enemy_configs.js`。

**验证：** 新建 `tools/verify/verify_enemy_attack_range_contract.gd`，登记 `verify:enemy-attack-range-contract`；扩展现有 `verify_enemy_ranged_attack_distance.gd` 和内容校验验证。

**接口：** 保留 `EnemyConfigHelper.behavior_attack_range(behavior: Dictionary, attack_range: float) -> float`；新增 `EnemyBase._get_contact_radius() -> float`。`_is_target_touching_contact_radius()` 只用后者；Boss tick 不调用 `_apply_range_attack_damage()`。

- [ ] 写失败场景：Boss 与玩家距离 500，阶段技能暂时禁用，推进 3 秒；HP 不应减少。距离进入双方碰撞半径内时按原接触间隔伤害。
- [ ] 写距离解析场景：祭司 400、毒母 360、魔像 280、队长 260；缺失专用距离的配置应明确拒绝；普通追逐怪的近身攻击保持。
- [ ] 确认旧版本失败来自距离复用或回退，而不是错误夹具。
- [ ] 将专用距离补齐，Boss 基础 attack_range 改为 0，保留 skill_range=760；基础 HP、移速、伤害不在此任务调参。
- [ ] 运行新增验证、原射程验证、enemy canonical、damage packet 和配置校验；用实际 Boss 场景再看一次无技能条件下的远距离受击。

**完成条件：** 范围 760 不再意味着直接扣血；射程设置不能扩大真实接触半径。预计 1–1.5 人日。

### M2：实现敌方攻击预警生命周期并修正炸弹

**修改：** `scripts/combat/damage_area.gd`、`scenes/combat/damage_area.tscn`、`scripts/enemies/actions/enemy_action_registry.gd`、`enemy_base.gd`、`enemy_visual_controller.gd`、`behaviors/explode_near_player_behavior.gd`、`data/enemies/enemy_skills.json`、敌方技能/区域 schema 与 validator。

**新建/验证：** `scripts/enemies/combat/enemy_attack_telegraph.gd`；`tools/verify/verify_enemy_attack_telegraph_lifecycle.gd` → `verify:enemy-attack-telegraph-lifecycle`；`verify_enemy_bomber_fuse.gd` → `verify:enemy-bomber-fuse`。

**接口：** DamageArea 的敌方配置增加 `warning_time: float`、`activation_mode: StringName`（single/periodic）和 `use_enemy_lifecycle: bool`；新增 `spawn_generation: int`（每次配置生成时递增）与 `signal enemy_attack_finished(generation: int)`。所有结束路径包括对象池回收，必须对当前代次只通知一次。不改现有玩家 setup 默认语义。表现对象提供 `configure(shape: StringName, params: Dictionary) -> void`、`set_progress(value: float) -> void`。

- [ ] 写失败断言：预警 0.9 秒的单次区域在 0.89 秒前无伤害，激活只命中一次；凝视预警 1.2 秒不能在 1 秒命中。
- [ ] 写炸弹场景：真实 AnimatedSprite2D 的视觉变化可见；引信期间接触伤害为 0；爆炸只一次；引信中死亡不再爆炸。
- [ ] 补暂停、目标消失、施法者死亡、区域提前回收、对象池复用的时序断言；复用后 warning、age、tick、命中集合都重新初始化。
- [ ] 实现第 2.2 节的显式生命周期，迁移敌方配置；替换敌方区域 icon.svg 占位显示为代码绘制的准确圆形/扇区表现，玩家区域保持现状。
- [ ] 对敌方区域统一设置锁定位置；普通地面攻击同一施法者最多 1 个活动区域。施法者死后：尚未激活的预警取消，已激活的非持续引导区域完成原生命周期。
- [ ] 运行两项新增验证以及已有 area motion、player dash、伤害接口验证；真实渲染检查轮廓、边界、层级和高密度可读性。

**完成条件：** 每次高威胁攻击都存在可见安全反应时间，预警期绝不结算伤害；玩家区域回归通过。预计 2–3 人日。

### M3：Boss 持续机制调度与弹幕安全扇区

**修改：** `enemy_base.gd`、`behaviors/boss_dungeon_heart_behavior.gd`、`actions/enemy_action_registry.gd`、`skills/enemy_skill_controller.gd`、`scripts/combat/projectile.gd`、Boss phases 与敌方技能配置；在现有死亡/场景清理入口解除 owned mechanisms。

**新建/验证：** `scripts/enemies/skills/boss_mechanic_scheduler.gd`；`tools/verify/verify_boss_mechanic_concurrency.gd` → `verify:boss-mechanic-concurrency`；`verify_boss_attack_fairness.gd` → `verify:boss-attack-fairness`。

**接口：** 调度器 `setup(owner: Node) -> void`、`try_reserve(skill_id: StringName, group: StringName, cap: int) -> int`（-1 表示拒绝）、`attach(token: int, node: Node) -> void`、`commit(token: int) -> void`、`cancel(token: int) -> void`、`tick(delta: float) -> void`、`reset() -> void`。先 reserve，动作内部登记实例，全部创建完成再 commit；生成失败则 cancel。projectile 新增与 M2 区域相同的 spawn_generation 和 enemy_attack_finished(generation: int) 通知，调度器 attach 时保存弱引用及代次；结束事件必须匹配代次，不能被复用实例误释放。共同的 projectile 只增加生命周期通知，不改变玩家弹体命中与移动。

- [ ] 写失败场景：跨连续帧释放三个持续技能、预警跨帧、阶段一切阶段二、0 号索引跨界安全缺口；断言真实占位不超过阶段 cap、封锁组不超过 1。
- [ ] 写生成失败场景：动作失败不启动技能冷却且 active token 为 0；核心数量达到 2 时不继续召唤，也不永久阻塞其他技能。环形弹幕部分创建失败时，取消本次已创建实例并撤销 token，不能留下未登记的半套攻击。
- [ ] 将 Boss 每帧局部 active_count 替换为调度器；phase 冷却以 skill_id 共享；建立 0.4 秒释放间隔，切阶段不重置有效机制。
- [ ] 环形弹幕预警 0.6 秒后释放，固定种子选择缺口；登记所有本次投射物，最后一个结束后释放 token。
- [ ] 验证 Boss 死亡、暂停、重开、池回收后调度无残留；保留已有 Boss 短时间伤害重叠保护，不将其作为并发控制的替代品。
- [ ] 运行两项新增验证及 strict damage、死亡奖励、重开验证；录制三个阶段各至少 30 秒，确认地面封锁不会形成无法撤离的同时覆盖。

**完成条件：** 并发约束跨帧有效，安全区可辨识，阶段切换不会瞬间灌入全部机制。预计 2–3 人日。

### M4：射手距离状态与祭司召唤约束

**修改：** `behaviors/keep_distance_shoot_behavior.gd`、`summon_and_chase_behavior.gd`、`enemy_action_executor.gd`、`actions/enemy_action_registry.gd`、`spawning/enemy_spawn_request.gd`、相关怪物与技能配置。

**新建/验证：** `tools/verify/verify_enemy_ranged_spacing.gd` → `verify:enemy-ranged-spacing`；`verify_enemy_summon_limits.gd` → `verify:enemy-summon-limits`。

**接口：** 射手行为维护 chase/hold/retreat/warning 四种状态，不将状态写入 JSON。召唤请求增加 `summoner_instance_id`，存活统计包含尚未显形的自有召唤物；召唤动作返回至少一只成功创建时才启动冷却。使用弱引用或树退出事件删除失效登记。

- [ ] 断言玩家距离 210 时射手退避、280 时结束退避；415/425 来回不反复取消预警，超过 460 才追逐；不得在后撤中无预警射击。
- [ ] 断言祭司在 350 距离开始 0.8 秒召唤预警；两次共 4 只，第三次不超限；一只死亡后可补到上限；两个祭司互不占用对方名额。
- [ ] 实现第 3 节参数与状态切换；后撤仍经过现有运动限制，边界处阻挡时允许停止射击，不能穿出地图。
- [ ] 召唤物无经验/灵魂奖励；死亡仍遵循合法管线；施法者死亡取消尚未完成的召唤，已生效的子体留到本波回收。
- [ ] 运行两项验证及原射程、运动邻居限制、死亡奖励、spawn reveal lifecycle 验证。

**完成条件：** 射手产生切入后排的价值，祭司在后排形成有限召唤压力，不能无限刷经验。预计 1.5–2 人日。

### M5：战鼓哥布林改为友军支援

**修改：** behavior registry、action registry、EnemyBase 的有效移速解析、战鼓技能和怪物配置、内容 schema/validator；不修改玩家 ModifierStore 的聚合规则。

**新建/验证：** `behaviors/support_aura_behavior.gd`、`enemy_support_buff_controller.gd`；`tools/verify/verify_enemy_support_aura.gd` → `verify:enemy-support-aura`。

**接口：** buff controller `refresh(source: Node, effects: Array[Dictionary], duration: float) -> void`、`tick(delta: float) -> void`、`get_move_speed_multiplier() -> float`、`clear() -> void`。effects 使用规范 stat/op/value/scope/source；本轮只支持 move_speed/mul/1.15/movement/war_drum，沿用已有 movement scope，仅在所属敌人的支援组件中聚合。增益来源逐个登记，同类取最强，不累乘，不向玩家 ModifierStore 注入效果。新增 enemy action `ally_buff`，行为显式请求此动作。

- [ ] 断言正常友军在半径 220 内受到 1.15 倍移速，离开后最多 0.6 秒恢复；两个鼓手不会得到 1.3225 倍；鼓手死亡立即移除其来源，无其他来源则恢复。
- [ ] 断言自身、其他鼓手、精英、Boss、核心不受强化；减速和支援组合按 `base_speed × status_multiplier × support_multiplier` 计算，不覆盖 base_speed。
- [ ] 将 war_drum 从 damage_area 改为 ally_buff；移除该怪对玩家脚下放物理伤害池的行为；保留真实接触伤害。
- [ ] 刷新按 0.5 秒执行而不是每帧全场扫描；增加明显鼓点和友军脚下增益标记，预警与敌方伤害区域外观不同。
- [ ] 运行新增验证、modifier 校验、敌人 hot path 和 movement 验证；高密度场景确认扫描开销。

**完成条件：** 鼓手的威胁来自强化队伍，击杀它能够立即减轻压力；没有永久加速。预计 1.5–2 人日。

### M6：实现精英机制差异

**修改：** `behaviors/dash_attack_behavior.gd`、behavior registry、enemy action registry、敌方技能/怪物配置、死亡分裂生成的奖励请求；保留原死亡 pipeline。

**新建/验证：** `behaviors/leap_slam_behavior.gd`；`tools/verify/verify_enemy_elite_mechanics.gd` → `verify:enemy-elite-mechanics`。

**接口：** 冲锋每次开始生成独立 attack generation，并记录本次已命中目标；跃击使用 warning/leap/impact/recovery 状态。分裂动作继续复用 spawn_enemies，但其请求明确 reward_policy，子体 source_type 为 death_split。

- [ ] 断言队长在距离 240 触发冲锋，预警方向锁定，移动距离足以穿过原目标位置；同一冲锋接触多帧只扣一次，恢复期不产生新的冲锋伤害。
- [ ] 断言巨型史莱姆落点按锁定方向推进，落地只生成一个范围攻击，死亡分裂只发生一次、只有 3 个子体且无重复奖励。
- [ ] 断言毒母采用持续毒区、魔像采用单次爆发，各自最多 1 个区域；其延迟、持续和冷却读取真实配置，不被公共 damage_area 默认值覆盖。
- [ ] 实现第 3 节的精英状态和参数；冲锋、跃击仍经过现有边界/运动约束；冻结和暂停不让动作瞬移补偿。
- [ ] 运行新增验证及死亡奖励、area 生命周期、运动邻居限制；录制每种精英单体和与普通怪混合的场景。

**完成条件：** 四种精英要求不同应对，不能主要依赖血量体现差异。预计 2–3 人日。

### M7：出生安全、预警一致性与失败重试

**修改：** `spawning/enemy_spawn_service.gd`、`enemy_spawn_request.gd`、`enemy_spawner.gd`、`timeline/enemy_cleanup_service.gd`；保留此前 viewport 可见保护和 pending reveal 保护。

**新建/验证：** `tools/verify/verify_enemy_spawn_safety.gd` → `verify:enemy-spawn-safety`；扩展现有 visible batch / visible cleanup / spawn reveal 验证。

**接口：** 新增选位方法 `try_find_spawn_position(request: Dictionary) -> Dictionary`，结果为 `{ok: bool, position: Vector2, reason: StringName}`；失败不得返回最后一个无效点当作成功。pending 请求由生成服务持有，创建成功才通知预算计数。请求携带 run_generation、wave_id、spawn_request_id，成功回调按请求 ID 幂等，只有所属局与波次仍有效时更新预算；独立召唤/奖励请求不写普通波次预算。

- [ ] 断言所有候选被占用时 spawn 返回失败且预算不增加；释放空间后重试只成功一次；位置无效不能默认为玩家附近。
- [ ] 激活前检查玩家与怪物真实接触半径：玩家进入危险范围时重新选位并重新播放完整出生预警，不能仅移动实体却保留旧预警点；失败则保留等待或释放实体回队列。
- [ ] 出生预警设为普通怪 1.5 秒、精英 0.8 秒、Boss 1.5 秒、召唤物 0.6 秒；所有来源都在预警中禁用行为、碰撞和伤害。
- [ ] 断言 zoom、相机偏移、窗口切换、转场清理和预警取消不产生“警告消失但预算计为已出怪”；有意回收须带独立原因并记录统计。
- [ ] 运行新增与已有生成/清理验证，并录制玩家主动站到预警中心的场景。

**完成条件：** 安全选位失败不会强行激活或吞预算，已有两项修复保持有效。预计 1.5–2 人日。

### M8：分段投放、独立精英事件与明确转场

**修改：** `timeline/wave_director.gd`、`enemy_timeline_controller.gd`、`boss_encounter_controller.gd`、`spawn_group_picker.gd`、`reward_event_director.gd`、`enemy_spawner.gd`、`data/waves/waves.json`、波次 schema/validator、`scripts/ui/hud/run_hud_state_provider.gd`、`run_hud_controller.gd`；同步第 4.1 节时间模式说明。

**新建/验证：** `tools/verify/verify_wave_pressure_schedule.gd` → `verify:wave-pressure-schedule`；`verify_wave_event_budget.gd` → `verify:wave-event-budget`；更新 `scripts/debug/wave_system_check.gd` 中明确受规格变更影响的预期，不删除残留怪检查。

**接口：** 波次新增 `spawn_stages: Array[Dictionary]`（start_ratio、end_ratio、budget_ratio；起止比例基于第 4.1 节 delivery_window）、group 的 role；公开阶段状态 active/delivery_grace/clear_rest/combat_transition/boss_prepare。新增 `get_wave_progress_snapshot() -> Dictionary`，统一返回 normal_spawned、normal_budget、mandatory_events_remaining、pending_spawn_count、transition_kind；HUD 和统计读取同一快照。

- [ ] 写失败断言：普通预算耗尽后精英仍按时出场一次且不减普通预算；第 6 波存在第二场精英；未完成强制事件时不能提前清场。
- [ ] 断言 35、50、65、80、95、110、125、140 及 +12% 密度后的三段整数总和不变；空场加速不提前消费未来阶段预算；末批完成显形后仍有收尾时间。
- [ ] 断言角色限额包含预警实体；满额时重抽合法填充组而非丢弃预算；完全无合法位置时进入宽限并报告失败，不伪造完成。宽限结束取消旧波尚未创建的请求、记录未交付数；旧局/旧波回调不能扣入下一波预算，已显形或正在显形的残留实体按超时转场策略处理。
- [ ] 实现第 4.1–4.2 节；清场休息与超时残留转场使用不同提示；无奖励回收使用现有清理入口而非 take_damage。
- [ ] Boss 在第 8 波完成后经准备流程出场；run_seconds 记录实际时间；HUD 文案为“第 8 波后 Boss 登场”，不展示固定 240 秒倒计时。将现有 220 秒 builtin_final_blessing 提示迁移为进入 boss_prepare 时触发一次，保留已有祝福奖励规则和幂等键，避免提前推进后在 Boss 战中才提示“Boss 前祝福”。
- [ ] 运行新增验证、wave system/population、run result/terminal、spawn reveal、重开验证。

**完成条件：** 预算、精英和提示一致；名义 Boss 登场约 240 秒，提前清场可提前推进；无事件丢失。预计 2–3 人日。

### M9：地图遭遇与预览同源

**修改：** `data/maps/maps.json`、`scripts/maps/map_variable_runtime.gd`、`scripts/ui/screens/map_select_controller.gd`、波次装配入口、content schema/validator。

**新建/验证：** `scripts/maps/map_encounter_resolver.gd`；`tools/verify/verify_map_enemy_encounters.gd` → `verify:map-enemy-encounters`；扩展 `verify:map-select-ui`。

**接口：** resolver `resolve_wave(map_data: Dictionary, wave_data: Dictionary) -> Dictionary` 返回不修改原配置的合成波次；`get_elite_preview_ids(map_data: Dictionary) -> Array[StringName]` 仅从实际事件派生。所有地图覆盖必须在 DataManager 发布前验证 ID、role 和事件波次。

- [ ] 固定种子验证四图第 4/6 波精英准确出场，预览与出场 ID 相同，预览不得标记 normal 怪为 elite。
- [ ] 验证瘴毒与熔火权重覆盖的归一化和实际抽样方向；不存在无效怪物 ID、空组或负权重。
- [ ] 深渊回廊的视口左右侧带采样经过逆 canvas transform，受 safe radius 与空间占用约束；不能只修改被可见采样绕过的旧 spawn_radius。
- [ ] 迁移 elite_preview_ids 使用者到 resolver，确认引用迁移完整后删除旧展示列表；同一 resolver 同时供 UI 和 runtime 使用。
- [ ] 运行新增验证、map select、内容 owner/validation、visible spawn、背景/相机边界相关旧验证；四图各完成一次真实试玩。

**完成条件：** 地图说明、精英预览与实际遭遇一致；回廊确实产生左右夹击。预计 1–1.5 人日。

### M10：宝石史莱姆改为独立奖励事件

**修改：** behavior registry、怪物配置、waves 奖励事件、`timeline/reward_event_director.gd`、生成与回收原因登记；移除最终普通池中的 gem_slime。

**新建/验证：** `behaviors/flee_player_behavior.gd`；`tools/verify/verify_enemy_treasure_event.gd` → `verify:enemy-treasure-event`。

**接口：** 奖励事件支持配置 `spawn_treasure`（wave_index、wave_time、chance、enemy_id、max_per_run、lifetime）；奖励事件自己的 RNG 用 run seed 派生，不改变普通出怪随机流。flee 行为经过已有运动边界限制，受阻时沿边界切向移动。

- [ ] 断言普通池中没有宝石怪，事件最多两次且每次只抽签一次；生成重试不重复抽签、不突破上限。
- [ ] 断言宝石怪远离玩家且不主动攻击；12 秒逃离无经验、灵魂、击杀；玩家击杀仅一次原有奖励。
- [ ] 断言奖励怪不阻止清场或 Boss 准备，转场无奖励回收；事件不能扰动普通波次 RNG 序列。
- [ ] 实现第 4.4 节；提示“宝石史莱姆出现”，与危险精英提示区分。
- [ ] 运行新增验证和死亡奖励、reward event、wave event budget、run result 验证。

**完成条件：** 奖励来自有风险的追击机会，不是高概率普通经验怪。预计 1–1.5 人日。

### M11：统计、试玩与有限数值调优

**修改：** `scripts/game/run_stats_tracker.gd`、已有来源归因的统计接入、必要的 DevTools 展示；配置调参单独变更。

**新建/验证：** `tools/verify/verify_monster_design_metrics.gd` → `verify:monster-design-metrics`；`docs/enemies/monster_system_balance_report.md`；采样 JSON/CSV 位于 E:/codex。

**接口：** 新增 `record_enemy_attack_event(enemy_id: StringName, skill_id: StringName, phase: StringName, hit: bool) -> void` 和 `record_wave_snapshot(snapshot: Dictionary) -> void`；get_summary 增加 monster_metrics 和 wave_metrics，不改变已有字段语义。伤害归因取现有 packet.source_origin_id/source_skill_id，不将所有怪物合成一个 enemy 桶。

- [ ] 断言按怪物、技能和动作类别分别统计；接触与爆炸不混合；死亡、自然逃离和回收分开；重开清零。
- [ ] 记录每波预算/实际投放/显形/取消数、角色构成、活跃密度、强制事件完成、精英击杀时间、Boss 各阶段时长与最大并发。
- [ ] 先做同构筑前后对照，再测不同构筑。4 角色 × 4 地图 × 3 种合法构筑 × 5 固定种子＝240 局初筛；构筑来自实施时合法技能配置并记录完整 loadout，不写死旧技能版本。
- [ ] 至少 16 局真人/正常操控完整试玩：每角色 4 局覆盖四图；自动移动、高血量、无敌或自动选卡局只证明流程/性能，不能计为胜率或躲避体验样本。
- [ ] 首轮体验目标：基础填充怪击杀中位数 0.5–2 秒，重甲 2–4 秒；精英 12–25 秒；Boss 35–65 秒。记录测量构筑与阶段，不能跨配置直接比较；这些目标不是自动失败硬断言。
- [ ] 每轮仅调整一类：先怪物组合/角色比例，再 HP，再伤害，再奖励；单次数值调整不超过原值 15%，每轮记录问题、改动、结果、是否保留。出现不可躲机制先退回功能任务，不以降伤掩盖。
- [ ] 初筛发现高方差、角色明显失衡或地图难度逆序时，对相关条件追加到至少 20 个种子；报告样本数量、失败方式和区间，不用 5 局证明平衡。

**完成条件：** 所有数值变更能对应测量问题；缺少真人样本时明确将体验验收保留为开放项。预计 3–5 人日，视实际试玩与自动化能力调整。

### M12：全矩阵、性能、重开与发布候选

**修改：** 仅修复验收发现的具体问题；补齐 package 中新增验证登记、两份台账文档。不能在收尾阶段插入新玩法。

**输入/输出：** 输入 M0 的基线、M1–M11 的版本与报告；输出功能矩阵、真实渲染、性能对照、开放问题、最终配置版本及逐任务回退清单。

- [ ] 运行第 7 节完整矩阵；检查 exit code、SCRIPT/Parse/Compile ERROR、engine ERROR 和隔离存档残留。
- [ ] 真实渲染验收普通预警、射手/祭司、四种精英、三阶段 Boss、四地图和宝石事件；保存画面与动作时间，不能用 headless 验证替代视觉验收。
- [ ] 连续 5 次重开，验证旧召唤登记、Buff 来源、Boss token、宝石计数和投放队列都清零；局内暂停前后计时和动作一致。
- [ ] 同机同渲染、同分辨率、同构筑、同种子串行性能对照：180 秒普通阶段及单独 90 秒 Boss 压力；记录 p50/p95/p99 帧时间、>33ms/50ms 帧数、节点/区域/投射物峰值和内存。
- [ ] 任一关键帧时间分位相对基线恶化超过 10% 时定位原因并复测；不能直接判定为“怪多所以正常”。支援扫描、区域画面和并发对象重点排查。
- [ ] 检查每阶段可回退到上一交付版本；玩法回退不读取或覆盖正式存档。仅功能和体验均达到条件后标记发布候选；不自动发布或合并。

**完成条件：** 自动化无失败、无脚本/engine 错误；关键玩法与视觉通过；性能对照有证据；开放的平衡项如实列出。预计 1–2 人日。

## 7. 验证命令与输出要求

所有命令从 `E:/roguelike_survivor` 运行。以下是实施时使用的命令，保存本计划不表示已经执行这些玩法验证。

文档与配置检查：

```powershell
node tools/validate/check_text_encoding.js
node tools/validate/validate_content_configs.js
node tools/validate/validate_enemy_configs.js
node tools/validate/validate_modifier_effects.js
```

M0 基线矩阵：

```powershell
& tools/verify/run_verification_matrix.ps1 -Batch monster-baseline -Names @(
  'verify:enemy-visible-batch-spawn',
  'verify:enemy-visible-cleanup',
  'verify:enemy-ranged-attack-distance',
  'verify:spawn-reveal-lifecycle',
  'verify:enemy-death-reward-pipeline',
  'verify:enemy-canonical-runtime',
  'verify:damage-packet-contract',
  'verify:wave-system',
  'verify:wave-population-progression',
  'verify:run-result-diagnostics',
  'verify:debug-run-restart'
)
```

每任务新增验证在 package 登记后用同一 runner，例如：

```powershell
& tools/verify/run_verification_matrix.ps1 -Batch monster-m3 -Names @(
  'verify:boss-mechanic-concurrency',
  'verify:boss-attack-fairness',
  'verify:enemy-attack-telegraph-lifecycle',
  'verify:damage-packet-contract',
  'verify:enemy-death-reward-pipeline',
  'verify:debug-run-restart'
)
```

阶段 A、B 完成及 M12 跨系统验收：

```powershell
& tools/verify/run_verification_matrix.ps1 -Batch monster-final
```

runner 默认已经将 APPDATA、LOCALAPPDATA、TEMP、TMP 放在 `E:/codex/canonical-refactor/<Batch>/`，并直接启动 Godot。任何新增采样命令也必须在启动前使用 E:/codex 隔离目录。含完整局的验证继续使用 `tools/verify/verification_run_environment.gd` 检查 user://save.cfg 路径和新鲜隔离存档。

成功输出是对应项 PASS、矩阵失败数 0、脚本错误 0、engine ERROR 0。RED 阶段必须检查明确的断言失败，不以引擎崩溃或加载错误作为缺陷复现证据。

新增行为测试使用真实 registry、配置、场景、动作和 DamagePacket；只在伤害接收器记录入包和结果，不构造与生产行为脱节的替代 AI。表格中的候选数值以配置驱动，规则、边界、次数、时序和奖励幂等性需要硬断言。

## 8. 里程碑、工作量与回退

工作量为单名熟悉项目的开发者加可用策划/QA的估算，不是完成时间保证：

| 里程碑 | 内容 | 估算 | 通过后可交付 |
| --- | --- | --- | --- |
| A | 基线、距离、预警、Boss 调度 | 5.5–8.5 人日 | 公平性修复候选 |
| B | 射手/召唤、支援、精英、出生安全 | 6.5–9 人日 | 有职责差异的可玩候选 |
| C | 波次、地图、宝石事件 | 4–6 人日 | 完整遭遇节奏候选 |
| D | 统计、试玩调参、回归与性能 | 4–7 人日 | 验收后的发布候选 |

合计约 20–31 人日；高质量美术与音频制作另计。首轮使用现有精灵与代码绘制预警，不将资源采购作为修复前置条件。

每任务交付记录：问题、涉及文件、接口、玩法改变、验证命令/日志、真人样本、性能影响、开放项。功能与纯数值分别记录版本；波次/地图/宝石配置和对应 schema 必须一起回退，不能只回退 JSON 留下不匹配 runtime。

## 9. 最终验收清单

- [ ] 玩家躲开 Boss 技能且未真实接触 Boss 时，不会被基础远距离攻击扣血。
- [ ] Boss 的预警和活动机制真实计入并发，跨阶段与对象池复用不破坏限制。
- [ ] 炸弹引信可见、引信期无普通接触伤害；区域预警、伤害与边界一致。
- [ ] 射手保持有效距离；祭司在后排召唤且不越过自身上限；战鼓强化可以随来源死亡解除。
- [ ] 巨型史莱姆、队长、毒母、魔像在实机中要求不同应对。
- [ ] 出生位置失败保留预算，玩家踩预警不遭遇无提示强行激活；可见怪物不会被距离清理误删。
- [ ] 普通预算准确，精英独立且只执行一次；强制事件不会被提前清场或预算耗尽跳过。
- [ ] 清场休息安全，带残留怪转场提示准确；Boss 前清理不发伪击杀或奖励。
- [ ] 四地图的精英预览与实际一致，地图组合和回廊侧向压力可感知。
- [ ] 宝石怪通过独立事件出现，逃离/回收无奖励，击杀奖励只一次。
- [ ] 同条件性能对照、实际渲染、真人试玩、完整回归均有记录；功能通过与平衡通过分别说明。

### 编写完成时状态

本方案已对照当前文件入口和已有验证命令整理，尚未执行 M0–M12。此前两项怪物修复仍作为当前工作区基线保留。本轮只新增本计划文档，不将建议数值或设计选择写入生产配置。
