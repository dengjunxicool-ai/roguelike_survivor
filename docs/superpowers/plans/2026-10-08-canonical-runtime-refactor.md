# 唯一运行时契约 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Independent domains may use superpowers:dispatching-parallel-agents.

**Goal:** 删除运行时历史兼容，使配置、技能、怪物和伤害使用唯一契约。

**Architecture:** 按域完成数据迁移、消费者切换、旧实现删除和门禁更新。共享入口由主执行者整合，独立域并行，最后全量验证。

**Tech Stack:** Godot 4.6.3、GDScript、JSON、Node.js、PowerShell。

**Spec:** docs/superpowers/specs/2026-10-08-canonical-runtime-refactor-design.md

## Global Constraints

- 所有主动写入均在 E 盘；测试用户目录、临时缓存、日志均在 E:\codex，Godot 项目导入缓存保留在 E 盘仓库。
- 保持技能容量、学习/替换行为、伤害公式与顺序、死亡奖励幂等、首个终局结果锁定。
- 不操作玩家正式存档，不变更稳定持久化 ID。
- Godot 经 PowerShell 直接启动；每个验证保持 package.json 的真实入口，默认沙箱初始化失败时使用经自动审批的执行路径。
- 数据返回深拷贝，配置池原有顺序保持。

## Review Focus

- 空池与配置加载失败的区别：失败不能启动玩法。
- 起始攻击继承与槽位替换：配置字段迁移不能改变容量或继承。
- 怪物召唤与 rank override：来源与分类独立，奖励策略保持。
- DOT source identity 与反应深度：不串池、不增加额外反应。
- 重复结果刷新及重开：单次结算、清空局内状态、不读取正式存档。

## Task 1: 基线与唯一契约校验

**Files:** tools/validate/validate_content_configs.js; tools/verify/verify_canonical_content_contract.js; tools/verify/verify_content_validation.js; scripts/core/content_config_validator.gd; data/config/content_schema.json; tools/verify/verify_chaos_skill_runtime_smoke.gd; docs/PROJECT_REFACTOR_LEDGER.md。

**Interfaces:** JS 校验器提供 loadAndValidate(root) 与 validateDocuments(documents,schema)；Godot 共用同一 schema，CLI 非零退出报告文件/ID/字段。

- [x] 记录全量验证基线并修复混沌夹具容量隔离。
- [x] 添加旧字段、重复 ID、引用、路径、非法类型及数值的失败用例并执行 RED。
- [x] 实现共享 schema 校验及防回流测试，执行 GREEN。

## Task 2: 配置单一所有权

**Files:** scripts/core/data_manager.gd; scripts/core/game_data_access.gd; scripts/game/game_data.gd; scripts/summons/*; scripts/upgrades/skill_learn_definition_repository.gd; tools/verify/verify_data_access_*。

**Interfaces:** DataManager accessor 保持查询 API、顺序和深拷贝；新增 get_summon_definition/get_summon_definitions。GameData 查询 owner，不触发文件读取。

- [x] 添加 owner 缺失、合法空池、配置污染和召唤定义测试，执行 RED。
- [x] 接入 summons，完成加载校验；删除 fallback/缓存/无调用别名；迁移 headless 夹具。
- [x] 更新原三路径测试为 owner/facade 双路径行为和隔离验证，执行 GREEN。

## Task 3: 技能字段和职责

**Files:** data/skills/skills.json; scripts/skills/skill_definition.gd; skill_manager.gd; skill_offer_service.gd; scripts/upgrades/*; scripts/ui/* 的技能消费者；对应验证。

**Interfaces:** display_name/school/skill_type/slot_category/replaces_skill 是唯一字段；学习 ID 为 learn_skill_。

- [x] 添加起始/替换/融合/学习结构测试，执行 RED。
- [x] 离线迁移 JSON 和全部消费者，删除旧 name/god_id/type/category 推断。
- [x] 拆分学习资格、替换策略和明确运行定义继承，保持槽位与成长测试 GREEN。

## Task 4: 怪物分类与基础属性

**Files:** data/enemies/enemies.json; scripts/enemies/*; scripts/combat/target_damage_profile_resolver.gd; rank 消费者；scripts/runtime/hot_path_profiler.gd；对应验证。

**Interfaces:** enemy_rank 为唯一分类；EnemySpawnRequest 为生成入口，属性来自 base_stats。

- [x] 增加普通/精英/Boss/召唤覆盖与冲突字段失败测试，执行 RED。
- [x] 迁移分类与重复属性，删除旧 meta 和包装；profiler 移到 runtime 并切换引用。
- [x] 复跑生成、热点、死亡奖励、选敌与统计验证 GREEN。

## Task 5: 伤害严格接口与动作执行

**Files:** scripts/combat/damage_packet*.gd; damage_system.gd; damage_application_service.gd; scripts/skills/skill_action_executor.gd 及 family executors；全部伤害生产者和测试夹具。

**Interfaces:** calculate(packet: DamagePacket, target: Node) -> DamageResult；take_damage 只接受 packet。结构扩展保留明确语义。

- [x] 先记录公式/反应/DOT 基线，新增严格 packet 和来源身份测试 RED。
- [x] 切换所有生产者，删除 numeric/legacy/鸭子类型入口；分离反应准备。
- [x] 按 action family 抽离 executor，保持 factory 副作用顺序。
- [x] 伤害公式、所有神系 smoke、死亡与终局验证 GREEN。

## Task 6: Modifier、调试及升级职责

**Files:** scripts/modifiers/*; data/characters/*; data/upgrades/*; data/relics/*; data/skills/*；scripts/debug/dev_debug_panel.gd 及 pages；scripts/upgrades/upgrade_pool.gd。

**Interfaces:** 配置为效果列表，聚合快照为 Dictionary；页面宿主只分发，构建器不消费 RNG。

- [x] 增加加法/乘法/覆盖、scope、选项顺序和页面操作验证 RED。
- [x] 迁移配置输入，删除混合解析；拆分页面与选项构建职责。
- [x] 相关 modifier、技能卡、devtools、升级验证 GREEN。

## Task 7: 全量验收与文档

**Files:** docs/PROJECT_ENGINEERING_GUIDELINES.md; PROJECT_STABILITY_AND_BOUNDARY_REPORT.md; PROJECT_SYSTEMS_OVERVIEW.md; PROJECT_REFACTOR_LEDGER.md; package.json。

- [x] 删除台账逐项闭环，扫描代码、配置、场景与动态 registry 引用。
- [x] 全部配置 validator 与 package verify 直接运行，记录命令/退出码/失败原因。
- [x] 验证开局、终局、重开并检查测试存档隔离。
- [x] 进行独立代码审查并修复实际问题；更新文档为最终事实。

## 执行记录

执行与裁决见 docs/PROJECT_REFACTOR_LEDGER.md。用户已要求完成重构，按授权连续执行，不在批次间重复索取批准。
