# 合并后稳定性收尾 Implementation Plan

> **For agentic workers:** 使用 superpowers:executing-plans 连续执行；修复采用 systematic-debugging/test-driven-development，结束进行独立审查。

**Goal:** 在已合并的唯一契约重构上闭环相机/波次检查，补充真实渲染完整局和受控性能对比。

**Architecture:** 保留生产相机和玩法决策，检查当前消费者可见行为；测试与性能采样使用隔离用户目录，结果记录可复跑条件与限制。

**Tech Stack:** Godot 4.6.3、GDScript、PowerShell、Node.js。

**Spec:** 用户授权“合并后稳定性收尾”；边界见 docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md。

## Global Constraints

- 基线 main=6726527；当前 E 盘 checkout 创建 codex/post-merge-stability 分支。用户禁止 C 盘写入，复用 E 盘 checkout，测试用户目录、日志和基线副本放 E:/codex。
- 不改变生产相机缩放、战斗数值、波次或持久化 ID，不读取正式 save.cfg。
- Godot 由 PowerShell 直接启动；真实性能运行不与其他 Godot 验证并发。
- 自动驾驶、加速、存活和 Boss 辅助明确记录；渲染截图检查不冒充真人游玩或无辅助通关。
- CI 与完整特殊规则参数 schema 不属于本次收尾。

## Review Focus

- 宽屏/竖屏与地图四角相机不能露出背景外区域。
- deferred 添加的经验晶体被收集后，奖励仍可能在下一物理帧才发布；应验证最终到账和单次发放。
- 结算和重开记录必须幂等，隔离存档清理不能覆盖正式存档。
- 性能报告必须注明版本、种子、渲染器、分辨率、时长及辅助，不能直接将异条件历史数据解释为重构收益。
- 性能采样和截图输出失败、脚本错误不能被 exit 0 掩盖。

## Task 1: 相机与波次门禁

**Files:** scripts/debug/wave_system_check.gd; package.json。

- [x] 同步 main，复现失败并核查场景历史：bb02c7b 删除固定 zoom，测试仍要求 >1；同时捕获 deferred XP 偶发失败。
- [x] 检查活跃相机、正有限缩放、背景限位、宽屏/竖屏四角可视区域；经验断言等待真实奖励队列并验证幂等。
- [x] RED/GREEN 与错误相机限位变异验证；将完整波次检查登记 package 门禁。

## Task 2: 渲染完整局与性能

**Files:** tools/verify/verify_mage_full_run_autoplay.gd; tools/verify/verify_performance_run.gd; tools/verify/verify_run_restart_contract.gd; docs/PROJECT_POST_MERGE_STABILITY.md。

- [x] 为采样与截图工具补充明确 seed/output 参数、隔离路径与存档清理，保留原流程。
- [x] 在真实渲染器运行 mage 完整局，检查角色/HUD/Boss/结算截图，并渲染验证死亡与重开。
- [x] 在 E:/codex 提取重构前 45facd3 副本，同一测量夹具、种子、渲染器、分辨率、time_scale=1 串行采样前后各 180 秒。
- [x] 记录帧耗时、对象/节点/内存、负载差异；诚实解释波动和辅助限制。

## Task 3: 验收与文档

**Files:** docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md; PROJECT_POST_MERGE_STABILITY.md; PROJECT_REFACTOR_LEDGER.md。

- [x] 独立审查并闭环实质问题。
- [x] 完整验收矩阵、配置/编码/暂存前差异检查通过，测试存档残留为零。
- [x] 更新已知限制、证据、复跑命令和计划完成状态。

## 执行裁决与记录

- Ruling: 用户已选择并授权执行收尾，连续推进，不在计划/批次间再次索取许可。
- Ruling: 6 月固定缩放删除是现有产品决策，修复过期检查并增加实际视口边界验证；不为通过旧断言恢复缩放。
- Ruling: 渲染验收实际捕获显形 Tween 的释放参数错误，纳入最小生产修复与 RED/GREEN 生命周期门禁。
- Ruling: 首对性能数据发现 Windows 异步恢复窗口造成实际分辨率偏离，保留原数据审计；补实际视口确认，重跑相同夹具的 180 秒串行对比。
- Review: 已闭环私有随机流未固定和报告打开失败未退出两项实质问题；异步窗口确认与加载遮罩完成等待复核通过。
- 结果与后续裁决记录在 PROJECT_POST_MERGE_STABILITY.md。
