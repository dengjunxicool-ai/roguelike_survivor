# 唯一运行时契约重构设计

日期：2026-10-08

授权：用户要求根据已讨论方案写重构文档并完成重构，按该方案连续执行。

## 目标和约束

以单一配置所有者、唯一字段定义和明确运行接口替代历史 fallback、字段推断和重复实现。保持既有技能容量、学习资格、替换行为、数值公式、死亡奖励顺序及首个终局结果锁定。运行数据与定义分离，查询保持深拷贝及原有顺序。所有主动写入的文件均在 E 盘，测试用户目录、缓存、日志均在 E:\codex；不触碰玩家正式存档。

本设计针对本次迁移取代工程指南中的兼容接口保留要求；阶段 7 的行为门禁继续生效。Git 是回滚来源，不在生产目录保存旧实现。

## 配置所有权

DataManager 持有全部玩法配置，补齐 summons、gods 和 skill_system_config；GameData 只查询 owner，不读取 JSON、不持有第二套缓存。LocalizationService、UIThemeService 保留展示域专用配置所有权。SkillRangeUnit 改为纯范围转换服务，从 GameData 查询范围单位，避免配置替换后独立缓存陈旧；单位仍为 84px。DataManager 加载并校验完整批次成功后才发布，不把错误降级为合法空集合。查询不存在的可选 ID 返回空定义；初始化失败和必需引用不存在必须明确诊断。

动态 learn_skill_ 选项由升级构建模块生成；移除 learn_fire_skill_、primary attack 配置别名。独立 headless 夹具显式创建真实 DataManager 或从相同加载器构造定义，不用生产 fallback。

## 唯一字段契约

- 技能：display_name、school、skill_type、fusion_school、replaces_skill；删除 name/god_id/type 读取别名。category 如仍承担槽位事实，显式迁移为 slot_category，不能与 skill_type 混淆。is_starting_skill 表达获取方式，不用具体 fireball ID 推断。runtime_rules 只接受 Dictionary。融合神系与元素保留独立语义。
- 怪物：enemy_rank 是分类事实来源，groups 只是派生索引；基础数值只在 base_stats。召唤/生成来源与奖励策略独立。
- 伤害：生产入口只接收 DamagePacket。raw_amount 是原始量；其他实际使用且不等价的数值字段必须保留语义。来源 identity、flags、scaling、反应准备继续有效。数字输入、任意 RefCounted 鸭子类型和 legacy_damage_type 移除。扩展字段登记并校验。
- Modifier：配置统一为结构化效果记录，操作和 scope 显式表达。聚合输出仍可为平铺快照，不能把其误判为旧输入；保持加法、乘法、覆盖与应用顺序。

## 职责边界

SkillManager 管生命周期；学习资格/替换规则/运行定义解析移至专用模块。SkillActionExecutor 分发，按 projectile/area/status/summon/modifier family 执行。特殊规则按规则族拆分，保留有行为的特殊规则。UpgradePool 编排资格、权重和选项；选项构建独立。DevDebugPanel 作为页面宿主；通用 profiler 从 debug 移到 runtime，生产不反向依赖 debug。StatusEffectManager 的数据输入收敛，不能为拆文件改变 scheduler/叠层/DOT 行为。

## 删除证据

删除对象必须检查代码引用、JSON 引用、场景资源、signal、动态 registry 和导出资源。每项记录替代入口、验证和回滚方式；有行为的包装先迁移消费者再删。历史设计文档可保留作审计记录，当前工程指南和系统概览更新到新事实。

## 验收

先复跑基线，修复混沌 smoke 的夹具容量问题，不改变生产容量。新增唯一字段/引用校验与防兼容回流测试。复跑 package.json 全部 verify 及配置 validator，Godot 直接启动，不经 Node 子进程。死亡奖励、终局持久化、伤害公式、DOT/反应必须通过；增加开局/终局/重新开局装配验证。旧兼容测试转换为唯一 owner 与严格接口测试，保留行为断言。不宣称未经测量的性能提升。

## 持久化

不清空存档、不变更持久化稳定 ID。若发现必须改存档引用，先提供独立副本转换与验证，生产只读取新版本；本次不得自动操作正式 save.cfg。
