# 项目稳定性与边界报告

日期：2026-10-08；对应唯一运行时契约重构。

## 结论与证据范围

配置所有权、技能与怪物字段、严格伤害输入、Modifier 配置以及动作/规则/调试/选项构建职责已完成迁移。最终完整矩阵为 153 项通过、零失败、零脚本错误；包含真实开局、两局结算与重开装配，以及运行时诊断依赖收口检查。隔离测试存档残留为零，独立启动检查通过。

本文替代此前将 JSON fallback、numeric damage、enemy_type 等描述为当前接口的报告。历史阶段报告和日志保留作审计资料；本次证据均重新运行，不沿用历史通过结论。未执行画面人工体验或性能收益基准，不宣称性能提升。

## 运行时边界

| 系统 | 当前边界 | 长期守卫 |
| --- | --- | --- |
| 配置 | 16 份玩法文档按唯一 schema 校验后原子发布；GameData 只查询 | 字段/嵌套类型、必需值、重复 ID、引用列表、资源路径、输入污染、合法空池 |
| 技能 | display_name/school/skill_type/slot_category/replaces_skill | 起始攻击、替换继承、槽位容量、角色限制、两神系上限及融合 |
| 升级 | 构建器纯数据；随机抽样仍在编排器原位置 | 列表顺序、稀有度与固定种子 RNG state |
| 伤害 | typed DamagePacket 输入，DamageResult 输出；事件记录为显式视图 | 公式/取整、来源 identity、DOT、反应、非法输入无副作用 |
| Modifier | 配置结构化效果列表，平铺字典仅为聚合快照 | 加法/乘法/覆盖、scope、遗物负面数值 |
| 怪物 | enemy_rank 唯一分类；来源与奖励独立；属性集中 base_stats | 真实生成、Boss 核心覆盖、仆从计数、统计、血条和死亡奖励 |
| 调试 | 页面模块持有弱宿主引用；通用诊断在 runtime | 清技能、技能卡、刷新、重开宿主 deferred |
| 终局 | 首个结果锁定，结算记录幂等 | 胜负摘要、重复刷新、重开与存档隔离 |

## 实际行为修正

- 遗物 negative_modifier 原为 Array，旧消费端只读取 Dictionary，负面效果被丢弃。现在按结构化效果消费，负面属性实际生效。
- 遗物 corrosion_nameplate 的条件改用现有 acid_mark 状态；遗物稳定 ID 保持，酸系事件可触发，无关状态不能触发。
- 非法伤害包在护盾/命中保护前拒绝，Intent 与反应准备克隆保留解析错误；修改后的 scaling 和反应深度也重新校验。
- 配置发布隔离输入文档及有序池，调用方改变原字典不会污染 owner。
- 调试重开页 deferred 调用改为宿主方法，避免不存在方法错误。

这些修正经过独立 RED/GREEN 或审查 probe 复验，不归为纯数值等价搬迁。

## 验证记录

| 批次 | 结果 | 证据 |
| --- | --- | --- |
| 原始基线 | 137 项，4 项失败 | E:/codex/canonical-refactor/baseline/results.json |
| 首轮整合 | 151 项，6 项失败，定位为旧字段/来源/生命周期夹具及静态读取 | E:/codex/canonical-refactor/acceptance/results.json |
| 完整复跑 | 151 项，0 失败，0 脚本错误 | E:/codex/canonical-refactor/final/results.json |
| 最终交付矩阵 | 153 项，0 失败，0 脚本错误，0 隔离 save.cfg 残留 | E:/codex/canonical-refactor/final-delivery/results.json |
| 提交前完整复跑 | 153 项，0 失败，0 脚本错误，0 隔离 save.cfg 残留；暂存区差异检查与 UTF-8 校验通过 | E:/codex/canonical-refactor/pre-pr/results.json |
| 配置校验 | content、enemy、modifier 校验通过；16 怪物、15 敌方技能、8 波次 | tools/validate 与 E:/codex/canonical-refactor/schema-final |
| 独立审查 | 配置嵌套/引用/路径/隔离和伤害克隆/当前值校验缺陷均修复 | E:/codex/canonical-refactor/independent-review、damage-query-final、debug-review-green |
| 额外 Power 场景 | 2.2P=52.8，最终伤害 57，通过 | E:/codex/damage-contract/source-fixture-power/output.log |
| Timeline 检查 | 实际场景通过，包括 Boss 仆从来源计数 | E:/codex/canonical-refactor/title-systemcheck/timeline/check.log |
| 真实重开装配 | 45 项断言通过，0 脚本错误；真实开局、死亡奖励幂等、重复结算、重开清理与第二局结算 | E:/codex/canonical-refactor/run-restart-contract/green.log |
| 诊断依赖收口 | Godot 导入及 9 项相关检查通过，保留四个迁移 UID | E:/codex/canonical-refactor/diagnostic-boundary |
| 独立启动 | Godot 主项目 headless 启动 exit 0，0 脚本错误 | E:/codex/canonical-refactor/startup-final/result.log |
| 静态收尾 | 1302 个文本文件 UTF-8 合法；879 处生产资源路径无悬空引用；git diff --check 通过 | 编码校验、资源字面量扫描与 Git 工作区检查 |

基线的四项问题分别为：终局测试限定旧目录、血条夹具未开启开发模式、混沌夹具超过生产槽位并缺失目标 registry 装配、Soulburn 将两层总伤害与每层期望混比。保留生产槽位和全部行为断言；修正夹具容量、注册与明确每层/总量断言。

独立审查对照 HEAD 与 worktree，核查动作/规则方法、动态信号、计时器与资源工厂副作用顺序，未留下未处理的实质 P1/P2。

## 已知限制

额外运行未登记于 package.json 的 scripts/debug/wave_system_check.gd：波次启动、上限、经验收集、timeout 等相关断言通过，整体 exit 1 来自 camera is close enough for run exploration。该相机距离断言此前已记录在 docs/perf/REAL_FULL_RUN_PERFORMANCE_ANALYSIS.md，未修改断言或生产相机规则。它不包含在完整 package 门禁的通过计数中。

内容 schema 校验当前已登记的定义字段、基础属性、Modifier 和引用规则，不是所有特殊规则参数的完整形式化证明；规则族仍依赖各神系行为门禁。Headless 自动化不替代人工视觉验收。

## 复跑与隔离

```powershell
node tools/validate/check_text_encoding.js
node tools/validate/validate_content_configs.js
node tools/validate/validate_enemy_configs.js
node tools/validate/validate_modifier_effects.js
& tools/verify/run_verification_matrix.ps1 -Batch final-delivery
```

Godot 由 PowerShell 直接启动，不经 npm/Node 子进程。矩阵将 APPDATA、LOCALAPPDATA、TEMP、TMP 指向 E:/codex 下独立目录，保存逐项日志与退出码；非零退出或 SCRIPT/Parse/Compile ERROR 均判失败。测试不读取、复制、覆盖正式 save.cfg；终局和重开测试先检查隔离路径，结束清理自己的测试存档。

删除与回滚细节见 [执行台账](PROJECT_REFACTOR_LEDGER.md)，维护入口见 [工程规范](PROJECT_ENGINEERING_GUIDELINES.md)、[系统概览](PROJECT_SYSTEMS_OVERVIEW.md) 和 [重构文档](PROJECT_CANONICAL_RUNTIME_REFACTOR.md)。
