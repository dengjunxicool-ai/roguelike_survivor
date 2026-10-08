# 唯一契约重构执行台账

日期：2026-10-08。基线分支 codex/stage7-core-pipeline-evaluation，开始时工作区干净；交付分支 codex/canonical-runtime-refactor，PR 目标为 main。提交前确认远端 main 已合并阶段 7，且与本次重构前基线的内容一致。

设计：[重构文档](PROJECT_CANONICAL_RUNTIME_REFACTOR.md)；步骤：[执行计划](superpowers/plans/2026-10-08-canonical-runtime-refactor.md)。

## 执行裁决

- 用户要求写文档并完成，连续执行已授权工作，不在批次间重复批准。
- 使用 E 盘当前 checkout；测试用户目录、临时目录、日志全部在 E:/codex。未主动向 C 盘写文件，不操作正式存档。
- 默认进程沙箱初始化曾失败，经自动审批执行直接 PowerShell/Godot 命令；不存在仍被审批阻塞的操作。
- schema 明确维护，不保留自动收集现有配置即可放宽校验的生成器。
- 技能范围配置进一步纳入 DataManager，SkillRangeUnit 只转换，84px 保持；消除配置替换后的第二份陈旧缓存。
- amount 与 raw_amount 是不同阶段语义；freeze/frozen 等仍有活跃规则消费者，保留各自独立定义。
- 历史设计文档保留审计用途；当前三份工程文档同步到最终事实。

## 完成状态

配置所有权、技能字段/学习/槽位/继承、怪物分类/属性、严格伤害/查询、Modifier、动作/规则族、调试页面、升级构建与 schema 校验已完成。最终 153 项矩阵全部通过，零脚本错误；真实生命周期装配、诊断路径收口与文档同步均已验收。提交与 PR 标识以交付分支的 Git/GitHub 记录为准。

## 删除与替代证据

| 删除或迁移对象 | 替代入口 | 引用审计与行为证据 |
| --- | --- | --- |
| GameDataAccess、GameData JSON fallback/cache | DataManager + GameData accessor | 全部生产读配置调用迁移；12 owner/facade 门禁保留顺序、源相等、深拷贝与运行消费者断言 |
| get_primary_attack、learn_fire_skill_ 别名、查询层动态学习卡 | get_skill、SkillLearnDefinitionRepository.resolve_upgrade | 技能池/起始攻击/替换/升级门禁；生产门面无旧别名 |
| 技能 name/god_id/type/category/replaces_starting_skill | display_name/school/skill_type/slot_category/replaces_skill | 1 起始技能、144 可学习/融合技能完成迁移；schema 拒绝旧字段 |
| 槽位/学习/继承和卡构建的重复实现 | SkillSlotPolicy、SkillLearningPolicy、SkillRuntimeDefinitionResolver、UpgradeOptionBuilder | 原容量、角色限制、神系与融合行为；固定种子选项/RNG state 相等 |
| 怪物顶层 type/rank/重复属性、enemy_type/is_boss/is_elite | enemy_rank、base_stats、派生 groups | 16 怪物迁移前有效基础数值逐项比对；真实 normal/elite/boss/core 生成与统计 |
| 无消费者 base_stats.defense 副本 | armor | 生产读取/scene/配置审计确认无 base_stats.defense 消费；旧字段被 schema 拒绝 |
| EnemySpawnRequest.wave、_get_spawn_position、_get_array 等无调用辅助 | 显式生成请求与 SpawnService | 全库定义/调用检查；波次、核心、仆从、可见批量生成验证 |
| 旧 _spawn_enemy 编排入口 | spawn_enemy(request) | 先迁 Boss/wave/elite 调用及真实测试，保留警示和生成顺序 |
| numeric damage、from_any、任意 RefCounted/鸭子类型、legacy_damage_type、Normalizer | DamagePacket、Preparation、DamageResult | 严格合同 RED/GREEN、全部神系 smoke、公式、DOT/反应与源身份 |
| modifier for_damage_any 与 source_id/skill_id 回填 | typed ModifierQuery.for_damage、explicit attacker/profile | scope=0.25、目标类别过滤、来源身份及无副作用拒绝断言 |
| source/values/modifiers 混合效果包装与后缀猜测 | stat/op/value/scope/source 效果列表 | 加法、乘法、覆盖、scope、遗物与角色 trait 门禁 |
| 巨型动作/规则方法主体 | 五个 action family、十个 rule family | 实际方法迁移、保留信号/计时器/冷却池；独立逐方法对照与神系行为验证 |
| 空状态参数 helper、无引用冷却池 | 删除 | 无调用审计；规则族门禁与 smoke 保持 |
| DevDebugPanel 页面主体 | 六个 pages 模块、薄宿主委托 | 原按钮/卡片/清技能验证；restart host deferred RED/GREEN |
| debug 下 HotPathProfiler | runtime 下同类并保留 UID | 生产 preload 切换，热点守卫与相关行为门禁 |
| debug 下 DamageTraceContext、DebugCombatTrace、PlayerDebugOverlay、DebugExplosionSiteOverlay | runtime 下同类并保留四个原 UID | 879 处生产资源字面量无悬空路径；运行依赖门禁禁止业务叶子模块加载 debug，仅允许 UIManager 装配 DevDebugPanel |
| 召唤卡摘要与 SkillRangeUnit 独立 JSON helper/cache | GameData.get_summon/get_skill_system_config | 召唤 owner、技能卡文本、范围单位与成长验证 |
| 本次一次性 refactor/build-schema helper | 删除，保留明确离线 canonical 转换工具 | 精确路径检查后删除，生产未引用；schema 不在启动时推断 |

所有实际删除均扫描 scripts、data、scenes、resources、tools 中的静态引用及相关 signal/动态 registry，再以真实行为门禁复核。回滚方式为对当前 Git diff 反向应用或恢复基线；跨配置与消费者的批次必须整体回滚，不逐字段恢复旧兼容代码。未改稳定持久化 ID，不需要操作正式存档。

## 实际缺陷修正

1. 遗物负面效果 Array 被旧 Dictionary accessor 丢弃：按显式效果列表生效，RED/GREEN 验证。
2. corrosion_nameplate 悬空 corrosion 状态：改 acid_mark；酸事件触发、无关事件拒绝，稳定遗物 ID 不变。
3. 非法 DamagePacket 在拒绝前消耗护盾：提前验证；克隆保留 _input_errors，当前 scalar/scaling/depth 重新校验。
4. 波次、进度和有序池发布共享调用方引用：深拷贝输入，污染外部字典不改变 owner。
5. 缺少嵌套类型/必需字段、引用数组/神系及资源路径格式校验：独立 probe 复现后补失败用例与双端校验。
6. 调试页面 call_deferred 指向不存在方法：改宿主 deferred，真实页面方法测试通过。

## 夹具迁移记录

- 数据访问测试曾在批量编辑中误剪正常断言，已从 HEAD 原文恢复并精确迁移；保留源相等、顺序、深拷贝与运行消费者断言。移除的仅是已删除的历史 fallback 行为预期，空 owner 改为 authoritative emptiness。
- 混沌 smoke 显式放大测试实例槽位以装配全部 14 卡，生产容量保持原值且独立验证；注册真实 CombatTargetRegistry 目标，保留全部效果/选敌断言。
- 血条夹具开启并恢复 developer mode；标题/稀有度夹具 deferred 等真实 autoload ready。
- 技能定义与 DamagePacket 夹具改唯一字段/显式 source_instance_id，保留数值断言。
- Soulburn 同时断言每层 2.08 与两层总量 4.16；未修改生产 DOT 数值。
- 移动方法后静态门禁读取真实 family/policy 源码，增加派发/委托断言，保留原行为约束。

## 验证与审查

- 基线：137 项 / 4 失败，baseline/results.json。
- 首轮整合：151 项 / 6 失败；全部定位并修复夹具/静态读取，acceptance/results.json。
- 完整复跑：151 项 / 0 失败 / 0 脚本错误，E:/codex/canonical-refactor/final/results.json。
- 最终交付矩阵：153 项 / 0 失败 / 0 脚本错误，E:/codex/canonical-refactor/final-delivery/results.json；该批次结束后 save.cfg 残留数为 0。
- 提交前完整复跑：153 项 / 0 失败 / 0 脚本错误 / 0 测试存档残留，E:/codex/canonical-refactor/pre-pr/results.json；暂存区 git diff --cached --check 与 UTF-8 校验通过。
- 真实重开装配：45 项断言 / 0 脚本错误，E:/codex/canonical-refactor/run-restart-contract/green.log。覆盖真实开局、普通/精英死亡奖励幂等、终局单次记录、同 Main 重开和第二局结算；结束删除隔离 save.cfg。
- 诊断依赖收口：Godot 导入与 9 项相关检查通过，四个迁移 UID 保留，E:/codex/canonical-refactor/diagnostic-boundary。
- 独立审查：owner/技能/升级/敌人和伤害/动作/Modifier/debug 两个互不自审域；实质 P1/P2 均复验闭环，independent-review 与 damage-query-final。
- 额外 timeline、Power 伤害、meteor 场景通过；wave debug 检查的历史相机距离断言仍失败，波次相关断言通过，未计入 package 通过数。
- 内容、怪物、Modifier 校验通过；1302 个文本文件 UTF-8 合法，879 处生产资源路径字面量全部存在；Git diff --check 通过。独立主项目启动 exit 0 / 0 脚本错误，E:/codex/canonical-refactor/startup-final/result.log。

完整命令、限制与日志入口见 [稳定性报告](PROJECT_STABILITY_AND_BOUNDARY_REPORT.md)。

## PR #11 合并后稳定性收尾

PR #11 已合并到 main=6726527；在 E 盘当前 checkout 创建 codex/post-merge-stability 分支进行收尾。上述 153 项与历史相机失败记录为合并前事实，当前结果以 [收尾报告](PROJECT_POST_MERGE_STABILITY.md) 为准。

- 删除过期 zoom>1 假设，新增活跃相机、三种视口及四角实际边界验证；生产相机保持原值。
- 波次夹具等待真实经验物理队列并检查重复收集幂等；显形夹具等待真实 Tween 完成，消除固定计时器的同帧竞态。
- 渲染捕获 Tween 绑定已释放敌人而使警示残留，最小修复为 WeakRef 与 warning 绑定；新增存活/早释放/取消门禁。
- 渲染与测量工具固定七条 RNG、等待实际窗口尺寸、检测报告/截图输出失败与普通 ERROR，隔离输出和存档限于 E 盘。
- 自动驾驶处理连续奖励弹窗，在实际战斗画面绘制后保存 HUD/Boss 截图；Boss 扣血辅助等待首张战斗图完成。
- 最终矩阵 155 项通过，0 失败 / 0 脚本错误 / 0 engine ERROR；两个新门禁另连续 5 批通过。测试 save.cfg 残留为 0。
- 1280×720 真渲染完成辅助胜利局（260.5 秒）和两局死亡/重开（60 项断言）；四张完整局图片已查看。现有 Boss/HP 面板局部重叠列入后续 UI 项，不宣称全界面无缺陷。
- E 盘提取 45facd3，并仅补同一显形修复，以 SHA256 相同夹具串行采样前后各 180 秒；结果见版本管理的性能 JSON。保留早期分辨率偏离样本与不利结果；单对样本不证明性能收益。
- 三个隔离环境拒绝 probe 按预期失败，已有测试存档保持哈希后清理；独立审查发现的私有种子、报告失败、截图释放竞态均已通过实证闭环。新增/修改后最终完整局复验 exit 0 / 0 脚本错误 / 0 engine ERROR。

## 追加刷怪与结算修复

用户四项反馈已落实：空场提前刷下一批，删除普通怪/波次/Boss 仆从存活上限，显式八波预算 35→140，结算补齐真实统计与最终技能。距离清理不再吞掉警示中的实体，动态学习卡应用使用既有学习仓库而非静态升级表。新增长期门禁 `verify:wave-population-progression` 和 `verify:run-result-diagnostics`；最终矩阵 157 项全部通过。750 HP 渲染失败局作为失败页证据保留，10000 HP 辅助压力局完成 261.8 秒胜利流程；不宣称无辅助通关。详情、日志与新密度性能记录见 [收尾报告](PROJECT_POST_MERGE_STABILITY.md)。
