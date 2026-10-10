# 怪物系统实施台账 — plan: docs/superpowers/plans/2026-10-10-monster-system-improvement.md

## 当前范围

用户已授权阶段 C（M8–M12），完成后停止汇报。阶段 A（M1–M3）、B（M4–M7）代码及回归已完成。

## 基线

- 原 HEAD：6dfee02，原分支 main；实施分支 codex/monster-system-stage-a。
- 保留已有未提交的射手距离与可见清理修复、对应测试、package 登记，以及技能系统相关未跟踪文档。
- 所有外部日志、缓存、测试存档、截图仅写 E:/codex。生产存档不读取、不复制、不覆盖。

## 规则裁定

- Ruling: 在现有 E 盘工作区创建独立分支，保持未提交修复为基线，不调用默认可能写 C 盘的托管工作树服务 — 用户禁止 C 盘写入且共享目录已有必要补丁 — 分支不提供文件级隔离，因此每次检查与提交都限定本轮文件，不执行 reset/clean。
- Ruling: 采用项目文档作为持久台账，不运行依赖 Bash 的技能辅助脚本 — 当前环境为 PowerShell，计划任务编号为 M0–M12 且用户未授权提交 — 保持同等的任务简报、RED/GREEN、范围和裁定记录。
- Ruling: 用户要求每阶段停止，覆盖 executing-plans 的整份计划连续执行默认；阶段 A 完成即停止，不推进阶段 B。
- Ruling: 阶段间保留当前分支和未提交修改，不进入整项目合并/发布菜单 — 用户要求逐阶段实施与汇报，后续任务仍依赖当前变更 — 当前改动需要保留到后续阶段，尚无提交快照。
- Ruling: M0 的改动前多分辨率视觉基线未完成，交付当前 1280×720 真渲染、录像与明确限制 — 当前执行已越过改动前采集时点，不能把修改后的画面标为原版基线 — 1920×1080/窄视口的视觉差异尚未比较；后续 M7 投放验收必须补三视口样本。

## 接口预检

- M1 → M2：接触半径与技能范围分离，炸弹引信需要显式禁用接触伤害；不以修改射程解决引信公平性。
- M2 → M3：区域和投射物结束通知携带 spawn_generation；Boss 持续占位匹配节点弱引用与代次，池复用不能释放新技能。
- M2 → M3：所有敌方延迟区域使用统一预警语义；调度从预警创建时占位而非首次伤害时占位。
- M3 → 后续：真实机制上限、施法间隔、阶段共享冷却；核心仅召唤动作占位，核心数量另限 2。
- M4 → M7：召唤物所有权以实例 ID 计数，包含预警实体；创建失败不启动召唤冷却；选位/显形/失败重试只由 spawn service 负责。
- M5 → M6：有效移速统一叠加状态与支援，冲锋/跃击仍使用动作显式速度并经过既有边界限制。
- M7 → 后续 M8：pending 请求带局、波与请求 ID；正常波预算只能收到有效成功回调一次，不提前吞失败预算。

## 阶段 B 执行记录

- 基线：codex/monster-system-stage-b，HEAD 6dfee02；阶段 A 未提交文件已备份到 E:/codex/monster-system/stage-b-baseline，不运行阶段 A 临时 JSON 编辑脚本，避免覆盖阶段 B 配置。
- 当前：阶段 B（M4–M7）完成；独立审查问题全部修复，最终全量 169/169、7 项定向回归和三视口真实渲染通过。按用户要求停止，M8–M12 未执行。
- M4：完成，RED 2 项按预期失败；GREEN 7 项通过（E:/codex/canonical-refactor/monster-m4-green）。射手后撤/滞回、祭司预警/自有上限/无奖励/死亡取消均验证。
- M5：完成。RED 复现无加速、叠加来源缺失与错误伤害池（monster-m5-red）；GREEN 6 项通过（monster-m5-green2），并补充真实 slow 状态叠加与 0.5 秒扫描频率断言（monster-m7-green7）。
- M6：完成。RED 复现未锁定恢复、重复命中、无跃击/分裂及统一旧区域配置（monster-m6-red）；GREEN 5 项通过（monster-m6-green2）。M7 集成后死亡奖励、跃击/分裂和区域配置继续回归。
- M7：实现完成，RED 复现无效选位仍生成和缺少重试（monster-m7-red）；GREEN 8 项通过（monster-m7-green7），包括真实 director 的预算预留/异步成功/重复回调、旧局旧波隔离、取消预警退回请求、孤立实体清理、100 个真实预警实体显形。
- Ruling: M7 的真实预算幂等需要提前修改 wave_director 的计数接口，但不迁移 M8 的阶段调度/密度/强制事件/HUD — 旧接口仅同步累加返回数，无法纳入异步重试成功 — 普通预算改为 spawn_created 回调，pending 单独预留。
- Ruling: 所有出生来源统一预警，旧测试的“特殊来源立即生成”断言改为预警断言，headless 场景显式设置真实大小的视口 — 原 64×64 默认视口不足以容纳安全距离，不能依赖错误兜底点通过测试 — 生产视口仍按实际逆画布选位。
- Ruling: 跃击在实际落地处结算；受边界阻挡导致落点偏离原预警时补完整落点预警 — 不能在未提示的位置立即伤害 — 阻挡场景会延后攻击，不以瞬移纠正路径。
- Ruling: 取消已创建的普通波预警退回一次预算和请求；主动清理及其他来源取消记录独立原因，不自动补回 — 避免显形承诺消失，也避免主动清理的怪物重新出现 — 下一波的事件投放规则仍留待 M8。
- 工具中断：自动审批服务一度因额度错误未执行调用；恢复后核对文件并继续。仅使用 E 盘写入，未请求或执行 C 盘写入。
- Ruling: 支援配置使用 op=multiply、scope={tag:movement}、buff_effects 专用列表 — 当前规范不支持 mul 或 movement domain，effects 已被技能触发动作占用 — 保持规范校验与玩家聚合规则，配置字段与计划简称不同。

### 阶段 B 最终审查修复

- 独立审查：5 个 Important、0 个 Critical、0 个 Minor；本轮全部修复，不推进阶段 C。
- Final: fixed 异步 Boss 创建没有登记活跃状态或绑定胜利信号 — 同步和重试共用 on_boss_spawned，重复通知不会重复绑定；真实 Boss 死亡只报告一次胜利。
- Final: fixed 核心排队请求在 Boss 死亡后仍交付，以及异步核心没有生成统计 — 核心携带 source_owner 弱引用，创建和重试都验证来源；统计移到实际创建成功处，取消不计数，重试交付只计一次。
- Final: fixed 跃击重复应用波次伤害倍率 — 继承已缩放的 contact_damage，单次区域不走周期池倍增规则；真实倍率 1.28 时基础 16 → 区域与实际命中 DamagePacket 均为 20。
- Final: fixed 冲锋被近身移动限制提前截停 — 仅突进/跃击运动阶段允许穿过目标，邻居限制仍保留；真实物理路径验证队长移动 252 单位并穿过原目标位置，同一目标只命中一次。
- Final: fixed 射手后撤及锁定突进/跃击可穿出地图 — 出生和移动共用 DungeonBackground 边界，按真实碰撞半径留边；弱引用缓存背景，避免每只怪物每帧遍历场景树；跃击预告落点同样裁到合法区域。
- RED：monster-b-review-source-red 复现异步 Boss 活跃状态/胜利通知/核心来源失效 3 个失败断言；monster-b-review-physical-red 复现实际冲锋路径、跃击倍率与三种敌人地图边界 5 个失败断言（0 脚本错误）。
- GREEN：E:/codex/canonical-refactor/monster-b-review-final-green/results.json，7/7 通过；含真实 freeze 状态在预警/运动中暂停，解除后继续剩余动作、不补偿瞬移，以及核心异步统计。
- 验证修正：核心请求允许 clearance=0，阻挡测试改为选位入口明确失败；DamageArea 保存的是伤害模板字典，最终断言读取 _get_damage_payload 生成的 DamagePacket，而非字典不存在的 amount。编译失败和无效测试夹具结果均不作为完成证据。
- Ruling: 异步 Boss/核心完成通知纳入 M7 生命周期修复，不迁移 M8 的 Boss 准备节奏 — 统一失败重试暴露了旧同步路径的依赖 — 原事件时机与数量保留，补充成功登记及失效取消。
- Ruling: 单次跃击继承伤害只缩放一次，不扩展修改现有毒池/熔岩显式伤害规则 — 本轮审查问题来自新跃击路径 — 周期池倍率与既有显式伤害接口保持兼容。
- 最终全量：E:/codex/canonical-refactor/monster-stage-b-final/results.json，169 项通过，0 失败、0 脚本错误、0 引擎 ERROR；Godot 均由 PowerShell 直接启动。首次全量的重开与 Boss 核心夹具仍按旧即时出生/64×64 默认视口运行，已改为生产显形入口及真实视口尺寸后重新验证，没有放宽奖励或核心上限断言。
- 完成检查：1341 个文本文件 UTF-8、内容 schema/引用/资源、16 怪物/16 技能/8 波次、规范 Modifier effects、git diff --check 全部通过。
- 工作区：codex/monster-system-stage-b，HEAD 6dfee02，未提交、未推送；阶段 A 修改、既有射手/清理修复及其他技能文档均保留。缓存、日志、测试用户目录、截图与录像均位于 E:/codex。
- 最终矩阵与三次最终渲染的隔离 save.cfg 已清理，残留为 0；只删除本轮 E:/codex 测试目录内的存档，未操作正式存档。

### 阶段 B 真实渲染

- 最终输出目录：E:/codex/monster-system/stage-b-1280-final、stage-b-1920-final、stage-b-narrow-final；实际 PNG 分辨率依次 1280×720、1920×1080、960×540。NVIDIA OpenGL 3.3，seed 618，三次进程 exit=0、stderr 为空。
- 每种视口均采四种精英单体及混合普通怪场景（8 个），另采出生 zoom=1/0.75/1.5、相机偏移与玩家主动踩入中心（3 个）；每种视口 41 张 PNG，共 123 张。
- 三视口全部 9 个出生样本均确认重新选位、完整预警重播、结束后激活。已逐图检查冲锋矩形、跃击圆环、毒区/爆发区、支援标记与重新选位后的圆环中心。
- 每次 stage_b.avi 均录制 1158 帧/30 FPS，时长 38.6 秒；Movie Maker 编码尺寸受启动时项目默认值影响，三份视频实际均为 1152×648，不标记为三种视口分辨率录像。视口差异以原尺寸 PNG 与 samples.json 为证。
- 这是合成场景与自动移动的无敌受击体，使用真实怪物/区域/投放服务；尚未进行四张地图的完整关卡真人试玩，不据此宣称整体平衡通过。没有本轮改动前视觉对照。

## 阶段 C 执行记录

- 当前：codex/monster-system-stage-c，HEAD 6dfee02。M8–M10 与 M11 统计实现完成，240 条件流程采样完成；M12 工程回归、渲染采样和固定场景性能复测完成。正常战斗初筛与真人体验保持开放，不标发布候选。按用户要求在阶段 C 工程汇报后停止，不自动调参、提交或发布。阶段 B 完整文件与导入缓存备份在 E:/codex/monster-system/stage-c-baseline，可用于产品文件对照和独立运行；仅额外放入相同采样驱动供前后对照，未修改其产品代码。
- 基线 6/6：monster-stage-c-baseline，波次/人口/重开/死亡奖励/结算/投放安全通过。先采阶段 B 的 180 秒普通压力与 90 秒 Boss 压力，再使用相同驱动采阶段 C。
- Ruling: 延续既有 E 盘工作区并创建阶段 C 分支，保留全部未提交文件 — 阶段 C 依赖阶段 A/B 且用户禁止 C 盘写入 — 文件级基线用 E:/codex 完整备份提供，不通过提交/清理隔离。
- Ruling: 本文件执行台账承接既有批准；原计划首页“待审阅/未执行”是编写时状态，第 1–5 节是可达设计规格 — 用户已逐阶段授权落地且 A/B 已实施 — 不重新要求审批已同意的设计，按本轮阶段边界执行。
- Pre-flight M8→M9：统一波次快照、role 与独立精英事件；地图 resolver 返回深拷贝有效波次，UI 从同一事件派生预览。
- Pre-flight M8/M9→M10：奖励 RNG 与普通 RNG 分开，成功创建不占普通预算；清场阻挡与无奖励回收依据来源及生命周期。
- Pre-flight M8/M10→M11：完成/显形/取消、攻击来源与死亡原因只从生产信号记录，统计不反向驱动玩法。
- Pre-flight M11→M12：自动采样只能验证流程/性能，真人体验需要真实操控样本；缺少真人样本时保留开放项，不标记发布候选。
- Ruling: 性能对照固定 mage 初始构筑并禁用自动攻击，使用高血量移动辅助，保留同驱动的 dash 动作 — 保证普通阶段和 Boss 均可采满且初始 loadout 相同 — 只反映该固定场景压力，不用于正常胜率、完整玩家输出性能或平衡结论。

### 阶段 C 已实现内容

- M8：三段最大余数分配，普通预算完整计数、待投和显形占场；职责上限远程 6、支援 3、冲锋 4。第 4/6 波独立必达精英事件；投放异常最多 3 秒宽限后记 wave_delivery_failed，不伪造完成。提前清场安全休息、超时携带残留战斗转场，第 8 波后 2 秒准备再进入 Boss 出生预警；实际时钟可超过 300 秒，祝福随准备态触发一次。
- M9：四地图通过同一 resolver 合成职责权重和精英事件，UI 预览读取地图事件；深渊左右视口侧带经逆 canvas transform 取位；毒/熔岩地图选位避开活跃危害。运行时与 CLI 同时拒绝非法职责、阶段比例、地图精英与奖励参数。
- M10：宝石史莱姆从普通预算移出，第 3/7 波各独立抽签；独立抽签/位置 RNG，不污染普通怪序列；最多保留两个中奖机会，失败重试不重抽。逃离玩家、不接触攻击、激活后 12 秒自然退出无奖励；玩家击杀仍掉落一颗 24 XP 晶体，通知一次。转场取消未创建请求，安全休息/Boss 准备无奖励回收辅助实体。
- M11：get_summary 扩展怪物/技能/动作伤害、创建/显形/取消/死亡/逃离/回收、波次预算和角色组成、精英耗时，以及 HUD 采样的 Boss 阶段时长/并发。统计只观察玩法，不反向影响投放。重开代次标记拒绝上一局节点污染新局。
- M12：真实生产路径连续五次重开覆盖召唤、Buff、Boss token、宝石计数、投放队列和统计清零；所有新增验证已登记，最终全量、渲染和性能证据见后续记录。
- RED：monster-m8-red、monster-m10-red4、monster-m10-context-red、monster-m10-validation-red、monster-m11-red、monster-m12-reset-red2 均复现对应功能缺失；无效夹具/命令/编译错误不计 RED 证据。
- GREEN：monster-m9-green3 5/5、monster-m10-green2 7/7、monster-m11-green2 5/5、monster-m12-reset-green 3/3。各批 results.json 位于 E:/codex/canonical-refactor/<批次>/。
- 最初全量 monster-stage-c-pre-review 为 174/175：wave-system 旧残留怪夹具被真实玩家杀死；改为高血量残留实体、预算已投满，并断言同一实体存活，monster-stage-c-wave-compat 3/3。未放宽生产交付规则。
- Ruling: 阶段 C 覆盖 M8–M12，按阶段 B 已交付的“下一阶段”约定执行 — 原计划首页三阶段与后半四阶段编号冲突 — 若边界判断错误，会多执行统计/验收工程，但不擅自增加数值调参或发布。
- Ruling: 宝石抽签和位置分别使用私有 RNG，中奖立即预留一个机会，取消也不返还抽签额度 — 避免重试/取消反复抽签且保持普通 RNG 状态 — 拥挤时可能少于两只实际奖励怪，需在诊断中区分中奖、排队、创建。
- Ruling: 自动高血量战斗对照与击杀辅助流程矩阵分别报告，后者不算正常战斗平衡样本 — 辅助击杀能覆盖投放、死亡奖励和转场，但移除了输出与躲避约束 — 240 个流程条件不能满足 240 局正常战斗初筛，后者及至少 16 局真人仍开放。

### 阶段 C 独立审查与修复

- 一次独立只读审查：3 Important、2 Minor、0 Critical；按实际效果复核，三项 Important 均进入同一修复轮，不派发重复审查。
- Final: fixed Boss 准备状态不退出、地图机制整场暂停 — 准备倒计时结束进入 boss_reveal，投放服务真实 activated 通知后进入 boss_active；准备与显形暂停地图机制，战斗恢复。wave-event-budget RED→GREEN。
- Final: fixed 实际爆炸/冲锋伤害统计与施放身份不一致 — 爆炸读取实际配置的技能 ID（bomber 为 self_explode），伤害类别 explosion；冲锋预警结束记录 charge/start，命中 charge，与普通 contact 分开。monster-design-metrics 执行真实引信、实际伤害接收和冲锋入口，RED→GREEN；手工 bug_explosion 包仅用于通用归因接口测试。
- Final: fixed 遭遇数组非法成员静默通过与两语言形状不一致 — 非对象 groups/elite_events 成员产生字段路径错误，JS 拒绝数组形状的 group_weight_overrides；共享 JSON 非法夹具在 Godot/Node 两侧执行。map-enemy-encounters、monster-encounter-shapes RED→GREEN。
- RED 最终有效证据：monster-c-review-red2 共 7 个预期失败断言、0 脚本错误；Node 非法 override 数组探针亦失败。前一次测试回调参数/局部类型错误已修正，不作功能失败证据。
- GREEN：monster-c-review-green2 6/6；含 bomber fuse 与 elite mechanics 原有真实路径回归。
- Final: minor (deferred): 当前合法 elite_events=[] 会显示空精英预览，但 resolver 继承基础第 4/6 波精英；现有四图均显式配置两次精英，不触发此漂移。未来支持空配置时需统一空配置语义。
- Final: minor (deferred): boss_phase_metrics.peak_mechanisms 为 HUD 0.25 秒采样峰值，可能漏过短暂 token，阶段时长也不是精确阶段事件日志；不得用它证明实际并发上限。上限以 scheduler 生产断言及逐帧渲染采样为证，后续可改为事件统计。
- Final: Ruling: 审查未判断进行中的 240 条件、渲染和性能结果 — 只在实际日志/产物完成后登记，通过审查不替代这些证据 — 若采样失败，必须保留开放项而不能据审查宣称完成。
- Final: Ruling: 真人体验、胜率和地图难度排序保持开放，不调整 HP/伤害/奖励数值、不标发布候选 — 没有正常操控完整样本，辅助驾驶不能回答这些问题 — 后续试玩可能要求重调组合与数值。
- Final: Ruling: A/B 工程接口以本轮完整自动矩阵及真实动作渲染回归 — 独立审查没有重认证全部 A/B 玩法体验 — 仍不能替代全关卡真人逃生验证。
- Final: Ruling: 未启用的 legacy 死亡毒池不扩展改造 — 当前怪物配置不使用此效果，审查未发现本轮实际玩法影响 — 若将来启用，须补敌方清理组与转场测试。
- 真实 HUD 采样发现 M8 显示仍为 00:00：controller 的字典调用未读取 state.run_seconds。新增生产 update(tree,state) 路径 301 秒→05:01 断言，monster-c-hud-red 复现；改为优先读取状态字段，monster-c-hud-green 3/3（HUD/压力/宝石）。这是验收发现的具体显示问题，纳入 M8/M12，不改时间推进。
- 宝石奖励测试纠正 experience_crystals 为真实 experience_crystal 分组，并验证自然退出零掉落、击杀恰好一颗晶体，避免无效分组掩盖漏奖励。
- 自动采样工具记录：最初辅助包缺少 source_instance_id，被严格校验拒绝；已补合法来源，并保留原失败日志。64 倍时间试验每局出现 8 次投放失败，作为无效采样设置保留，不调整生产规则迎合；正式流程采样使用 16 倍/固定 60 FPS，并将任何 wave_delivery_failed 标为 FAILED。
- 最终工程矩阵（含 HUD 显示修复）：E:/codex/canonical-refactor/monster-stage-c-final2/results.json，176/176、0 失败、0 脚本错误、0 engine ERROR。
- 内容 schema/ID/引用/资源通过，16 怪物/16 敌方技能/8 波次通过，规范 Modifier 通过，1359 个文本文件 UTF-8 通过，git diff --check 通过（package 仅换行提示）。
- 最终配置 SHA256 与阶段 B→C 文件对照：E:/codex/monster-system/stage-c-artifacts/config_version.json、rollback_manifest.json；后者最终 50 项，保留新增/修改类型和前后哈希（含方向缓存及其回归）。公共采样驱动曾复制到快照供同驱动执行，不把这些工具当成原始阶段 B 文件。
- Ruling: 用阶段 B 产品文件快照提供整体 C 回退点，逐任务清单说明依赖边界，不宣称存在中间阶段提交 — A/B/C 都未提交且需保留已有工作 — 单任务回退仍需审查共享文件；全局 reset/clean 会丢失 A/B，禁止以它替代文件回退。
- 240 条件首次运行全程无投放失败、八波齐全且完成 Boss，但分析预算发现深渊仅首波 +12%，总预算 704 而非设计 784。根因是 MapVariableRuntime 借用角色 apply_run_modifiers 写入地图压力，角色属性刷新覆盖该值。
- 验收修复：数量修正从地图上下文独立读取，再与角色加成相加；地图 setup 不再覆盖角色修正。monster-c-density-red 复现八波丢失地图压力和地图/角色组合共 9 个失败断言、0 脚本错误；monster-c-density-green 4/4（地图/压力/人口/五次重开）。切换回地牢后不保留深渊压力。
- 原性能先导 stage-c-performance-final 已中止；stage-c-performance-final2 的基线自动选卡改变了构筑，也已中止。两者不计最终性能证据。修复后补采深渊 60 条件并重跑全量，最终性能采用 stage-c-performance-fixed-final 的同驱动、固定构筑串行样本。正式流程汇总保留其他三图 180 条件，并以新深渊 60 条件替换旧配置效果样本，原始 JSON/日志不删除。
- Ruling: 深渊 +12% 从地图上下文独立合成，不随角色刷新覆盖 — 240 条件采样证明原共享修正入口只在首波生效，修复是兑现既定候选配置 — 后续波次压力会比旧异常实现高，仍需正常操控试玩决定是否保留候选。
- 最终补采完成：stage-c-abyss-final 四进程均 exit=0、stderr 空；与三图 180 条件合并后为 240 唯一条件、0 问题。普通预算与交付合计地牢/墓园/神殿各 42000，深渊 47040；每图创建宝石 12。summary.json/CSV 的每条记录都指向原始 loadout 与生产统计 JSON。
- 最终工程矩阵（含深渊压力修复）：E:/codex/canonical-refactor/monster-stage-c-final3/results.json，176/176、0 失败、0 脚本错误、0 engine ERROR。上一 final2 是修复前已通过的历史记录，不替代本次最终结果。
- Ruling: 固定构筑性能基准跳过升级/奖励选卡，Boss 等待激活时清空准备奖励待办，两个版本使用同一夹具规则并记录初末 loadout — 基线先导确实学会了新技能，且新版准备祝福会阻塞激活等待，原先导不能证明同构筑 — 此基准不覆盖成长/祝福后的性能变化；真实选卡与祝福仍由 240 条件和准备弹窗验证。
- 固定构筑首轮：stage-c-performance-fixed-final 四进程 exit=0、stderr 空，初末 loadout 相同；普通阶段 p99 14.228→15.719 ms（+10.479%）触发复测门槛，comparison.json 记录 regression，不能将运行 PASS 当作性能通过。Boss p99 6.761→5.671 ms。当前波次解析/快照各 10,000 次微测平均 70.28/76.65 微秒，只排查该无实体路径，不推断整场瓶颈；用现有 enemy_profile 在 stage-c-performance-profile 前后各重采 180 秒普通阶段。
- 分段复测：前后均 exit=0、stderr 空；p50/p95/p99 0.843/7.538/12.892→0.942/7.400/15.477 ms，p50 +11.744%、p99 +20.051%。累计 behavior 8.985→10.605 秒、visual 5.273→8.834 秒；其余分段多数累计下降。计时有自身开销、职责组合与执行次数不同，只定位增长区间，不将累计值当因果证明。
- visual 动画方向选择微测：同一真实 small_slime 配置连续 100,000 次调用，重复状态可用性解析平均 3.766 微秒，缓存字典读取 0.060 微秒。新增 verify:enemy-visual-state-cache 以真实状态解析入口断言同配置不重复查询、方向独立、零移动保留方向、换配置重新解析并正确回退；monster-c-visual-cache-red 的重复查询断言失败，0 脚本错误。
- 验收优化：EnemyVisualController 仅缓存每份自身视觉配置的四个方向可用状态，apply_enemy_config 清空缓存；不改变 LOD/动画更新频率、预警或战斗参数。monster-c-visual-cache-green 6/6，优化后同入口微测 0.614 微秒/次；该微测不代替整场性能复测。
- Ruling: 只减少已测到的动画方向重复解析，不通过降低更新频率或修改怪物数量跨过性能门槛 — 分段 visual 明显增长、真实方向入口存在重复资源状态查询 — 配置替换若未失效可能选错动画，已补独立方向与换配置回退测试；整场是否改善仍需重新采样。
- monster-stage-c-final4：176/177，通过项含全部产品路径；wave-system 再次暴露夹具竞态。其只关 set_process、未关物理更新，且边界测试把玩家留在角落而残留实体固定在中心，可被真实距离清理。改夹具为停止自动物理波次驱动、将残留实体放玩家旁；未改变生产回收规则，monster-c-wave-fixture-green 3/3。
- 优化后性能使用 stage-c-performance-cache-final：保留 stage-c-performance-fixed-final 已采满的两个 before 样本，并记录 source.json 原目录；阶段 B 产品与采样驱动未变，不声称重新采集基线。当前版本重采普通 180 秒与 Boss 90 秒，关闭分段计时，与原基线同条件比较。
- 最终工程回归（含方向缓存和波次夹具修正）：E:/codex/canonical-refactor/monster-stage-c-final5/results.json，177/177、0 失败、0 脚本错误、0 engine ERROR。final4 的夹具失败保留；final3 的 176/176 为优化前历史结果。
- Ruling: 优化后复用未变的阶段 B 产品/驱动所采满的基线，只重采当前版本普通与 Boss 场景，并保留原目录引用 — 没有改变基线代码或采样条件，避免无原因重复已完成的旧版测量 — 同机负载仍可能随时间波动，单轮对照不能证明多轮稳定性能或所有构筑达标。
- 最终性能：stage-c-performance-cache-final/comparison.json，regressions=[]，初末完整技能相同。当前普通 180.000 秒、Boss 90.000 秒，exit=0、stderr 空。普通 p50/p95/p99 0.912/6.737/14.476 ms，相对基线 +0.55/+5.25/+1.74%；Boss 0.742/3.027/5.376 ms，相对 −3.13/−38.69/−20.49%，未超过关键分位退化门槛。慢帧、最大帧、节点/区域/投射物/静态内存峰值完整列于平衡报告，未隐藏普通 223 个 >33ms 帧及 Boss 90.323ms 最大帧。
- 性能适用范围：含相同采样驱动开销，Boss 压力仅观察到阶段 1；不推断完整三阶段、正常输出、成长构筑、所有地图或多轮稳定性。已有三阶段逐帧渲染是机制上限证据，不是三阶段性能对照。微测证明方向查询减少，整场变化不全归因缓存。
- 最终内容/schema/引用/资源、16 怪物/16 敌方技能/8 波次与 Modifier 校验通过；1306 个非二进制文本文件严格 UTF-8 通过，git diff --check 通过（package 仅换行提示）。早先 1359 是另一文件筛选范围的历史记录，不作为最终统计口径。
- 四图/Boss/HUD PNG 在方向缓存优化前采集；优化后普通/Boss 原速 OpenGL 采样运行完毕，缓存行为由方向与配置替换回归验证，未把旧 PNG 标成缓存改动后重采。
- 本轮隔离验证/采样目录的 save.cfg 已核对并清理，残留 0；仅移除 E:/codex 下明确的先导测试存档，不操作正式存档。最终工作区未提交、未推送，阶段 A/B 和其他技能系统文档保留。

### 阶段 C 真实渲染

- 四图最终目录：E:/codex/monster-system/stage-c-render-final/map-render。36 张 1280×720 PNG；实际四图背景、地图变量、独立精英事件、普通远程/支援与宝石事件，四份 3×3 联系表已逐图检查。第一次驱动的 Arena 绘图覆盖背景，不能当成四图背景证据；最终改为普通 world 与真实 ResponsiveBackground 重采，exit=0、stderr 空。
- Boss 最终目录：E:/codex/monster-system/stage-c-boss-render-final/boss-render。各阶段 30 秒、12 张截图及引信/环形密度图；逐帧实际最大机制 1/2/2，最大封锁组 1/1/1。exit=0、stderr 空；角标沿用共享 Stage A 驱动，代码为本轮当前版本，不标为阶段 A 旧证据或前后对照。
- HUD 最终目录：E:/codex/monster-system/stage-c-hud-final3/hud-render，两张实际应用画面，301 秒→05:01 与 Boss 准备阶段的真实祝福卡弹窗。最早两次夹具在加载遮罩或计时未读取状态时采到 00:00，不用来证明通过；最终等待加载完成，修复生产字典入口后重采。
- 均为 OpenGL Compatibility/NVIDIA GeForce RTX 5060 真渲染；合成受击体、自动控制、强制中奖/时间属于画面夹具，不计正常完整关卡、真人胜率或可躲性样本。没有本轮改动前新采视觉对照；本轮没有新增录像，以 PNG/时序 JSON 为证。

## 任务状态与证据

- M0：定向基线完成，11 项通过、0 失败。输出 E:/codex/canonical-refactor/monster-stage-a-baseline/results.json。真实渲染在阶段交付统一补采，缺少本轮改动前新采的视觉对照，不冒充已采集。
- M1：完成。RED 复现 Boss 500 距离直接伤害、接触范围扩大及 4 个行为距离缺失；日志 E:/codex/monster-system/m1-red/output.log。GREEN 6 项通过，输出 E:/codex/canonical-refactor/monster-m1-green/results.json。
- M2：完成。RED 区域提前命中与池复用缺失结束通知、炸弹动画不可见且引信期接触伤害；日志 E:/codex/monster-system/m2-red/。GREEN 验证显式预警、首跳/结束边界、提前回收、复用、暂停、目标消失、施法者离树、已生效区域独立存续、真实配置→registry、锁定位置和普通施法者单区域上限；最终全部纳入 164 项矩阵。
- M3：完成。RED 复现阶段切换重复释放、缺少跨帧占位、无环形预警、安全缺口跨零索引漏一弹和核心超上限；日志 E:/codex/monster-system/m3-red/。GREEN 验证并发 1/2/2、封锁组最多 1、共享冷却、0.4 秒间隔、失败不占冷却与 token、池代次隔离、Boss 死亡清理、固定种子缺口、部分环形失败全撤回、最后一弹回收才释放占位。

## 最终审查与回归

- 独立只读审查：1 个 Important、0 个 Critical。Important 为目标消失后主更新提前返回导致已点燃引信暂停，已补真实 `_physics_process_profiled` 路径断言。
- Final: fixed 目标消失后引信暂停 — verify:enemy-bomber-fuse RED→GREEN（E:/codex/canonical-refactor/monster-final-review-red3 与 monster-final-review-green），完整矩阵 164/164。
- Final: minor (deferred): 给同一 DamageArea 从敌方模式切回 legacy 玩家模式增加直接复用断言；当前玩家 dash、区域、共享伤害回归均通过，但此模式切换尚无专门断言。
- 全量验证：E:/codex/canonical-refactor/monster-stage-a-final/results.json，164 项通过、0 失败、0 脚本/引擎错误。最初全量运行遇到新增引信边界失败，其结果保留在 monster-stage-a-full，不用于完成判定。
- UTF-8、内容引用/schema、16 怪物/15 技能/8 波次及 Modifier 校验通过；git diff --check 通过。
- 未提交、未推送。其他技能计划文档和既有射手/清理补丁保留。

## 渲染证据与限制

- E:/codex/monster-system/stage-a-render/samples.json：NVIDIA OpenGL 真渲染，seed 618，Boss 三阶段各 30 秒，最大机制并发 1/2/2、最大封锁组数 1/1/1，12 张阶段截图及 fuse_ring_density.png；stderr 为空。
- 这是使用真实 Enemy/DamageArea/Projectile 节点、固定 Boss 位置和无敌移动受击体的场景验证。没有使用真人操作或完整地图关卡，不能证明整体关卡平衡或所有布局均可逃离。
- 缺少本轮改动前新采的视觉基线；保留此限制，不把当前截图标为前后对比。
- 视频：E:/codex/monster-system/stage-a-movie-launch/boss_stage_a.avi，Godot Movie Maker 实际输出 2707 帧/30 FPS，时长 90.23 秒、165326768 字节；输出日志确认录制结束，stderr 为空。配套第二次场景采样在 E:/codex/monster-system/stage-a-movie-samples/。视频只证明上述测试场景的时序与呈现，不作为全关卡逃生/平衡结论。

## 阶段 A 交付时的下一阶段（历史记录）

- 阶段 C：M8–M12，分段投放与独立精英事件、地图遭遇、稀有奖励怪、归因统计及全局平衡验收。
- M7 已覆盖选位失败重试、预算成功计数、显形安全复检与取消原因；未来阶段仍需覆盖独立事件预算和转场节奏，不将本轮结果描述为完整关卡平衡完成。

功能验证与真实渲染分别报告；辅助驾驶不等于真人试玩，阶段 A 不宣称整体平衡已通过。

## 阶段 D：初筛验证完成，体验保留开放（2026-10-10）

- 详细决策与唯一独立审查：monster_system_stage_d.md。审查三项重要问题均 RED→GREEN 修复，未设置待处理 minor。
- 正常生命 240 条件：4×4×3×5 固定种子，四分片 exit=0、stderr 为空，完整覆盖检查和数据 issues=[]；结果为 240 次机器人死亡。65 局遇精英、4 次精英击杀、0 局 Boss。正常生命、1 倍游戏时间和固定 60 Hz 不能替代真人；自动移动/选卡仍只作诊断。
- 一异常条件扩样到 20 种子：额外 15 次实际战斗，保持正常伤害/冷却，无代杀；全部机器人死亡。其余 15 条大范围波动条件未扩满 20，明确留待后续，不声称 M11 体验通过。
- 原始报告的生存辅助标签错误已修复驱动；已有样本另存 normalized_samples.json，附来源 SHA256 与修订原因，原文件和测量值不改。
- 最终功能回归：E:/codex/canonical-refactor/monster-stage-d-final2/results.json，180/180、0 脚本/engine 错误。配置与 C 同版，产品代码未改，不新增玩法或调整数值。
- 16 局真人记录和 Boss 正常生命战斗仍开放，记录表 monster_system_human_playtest.md；不标记发布候选。按用户要求在本阶段完成后停止。
