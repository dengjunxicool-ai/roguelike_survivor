# SDD ledger — plan: docs/superpowers/plans/2026-10-09-skill-system-rebalance.md

## M4 玩家反馈与调优

- Base: 06e3b373e9279b787dfd5124fe495ba641c4d45d（M3 PR16 已合入）
- Branch: codex/skill-rebalance-m4；既有隔离工作树 E:/codex/skill-rebalance/worktree。
- Spec: docs/superpowers/specs/2026-10-09-skill-system-rebalance-design.md。
- Scope: T14–T16，阶段结束停止；不推送、创建 PR 或合并。
- 所有缓存、用户目录、原始测试输出 E:/codex/skill-rebalance；禁止 C 盘写入。

## Pre-flight

| 消费任务 | 上游产物 | 核对 |
| --- | --- | --- |
| T14 | T1 品质保持、T11 里程碑、T10 复制动作 | 预览使用 TriggerRuleAdapter/EffectAdapter 和实际 resolver；不再复制成长公式 |
| T15 | T3 来源事件、T4 状态、T7–T13 运行时 | 真实事件计量；固定构筑/预算/控制策略；实际 300s 与夹具分开 |
| T16 | T14 UI、T15 样本、144 项覆盖 | 发布清单追溯日志及未通过门槛；人工试玩不可由自动化冒充 |

## Tasks

- Task 14: pending
- Task 15: pending
- Task 16: pending

## Evidence

- Baseline: E:/codex/skill-rebalance/M4-baseline/results.json（运行中）

Ruling T14: 将 7 个旧文案合同的预期状态名本地化，并迁移“无 tooltip”/旧学习说明断言 — M4 明确要求中文状态及可读全量预览；语义文本与行为测试保留 — cost if wrong: 本地化映射可能掩盖文案偏差，新 UI 测试逐项检查 144 项和实际输出对照补充覆盖。

T14 evidence: parity RED missing service → GREEN 18 cast；实际区域/召唤/复制误差≤1，CD≤0.01；UI RED missing feedback → GREEN 12 槽/1280及960/真实替换取消确认；截图 T14-ui-rendered3 已检查。全量初跑 192/202，10 项根因已记录与修复，等待复跑。

Task 14: complete (base 06e3b37, tests T14-verified 202/202 PASS; additionally long-description screenshot fix and bounded card assertions PASS in T14-final-cards). Card summary uses shared adapted actions/area/CD/summon/replay resolvers; core and echo feedback, admission text, rarity retention, all descriptions localized. Screenshots inspected; compact description uses bounded lines and full values remain in tooltip.
