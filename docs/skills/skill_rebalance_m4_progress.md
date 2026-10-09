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

- Task 14: complete (8be02b3 + supplemental feedback regression)
- Task 15: implementation and pilot in progress; balance acceptance open
- Task 16: regression/documentation/rollback in progress; human acceptance open

## Evidence

- Baseline: E:/codex/skill-rebalance/M4-baseline/results.json（199/199 PASS）

Ruling T14: 将 7 个旧文案合同的预期状态名本地化，并迁移“无 tooltip”/旧学习说明断言 — M4 明确要求中文状态及可读全量预览；语义文本与行为测试保留 — cost if wrong: 本地化映射可能掩盖文案偏差，新 UI 测试逐项检查 144 项和实际输出对照补充覆盖。

T14 evidence: parity RED missing service → GREEN 18 cast；实际区域/召唤/复制误差≤1，CD≤0.01；UI RED missing feedback → GREEN 12 槽/1280及960/真实替换取消确认；截图 T14-ui-rendered3 已检查。全量初跑 192/202，10 项根因已记录与修复，等待复跑。

Task 14: complete (base 06e3b37, tests T14-verified 202/202 PASS; additionally long-description screenshot fix and bounded card assertions PASS in T14-final-cards). Card summary uses shared adapted actions/area/CD/summon/replay resolvers; core and echo feedback, admission text, rarity retention, all descriptions localized. Screenshots inspected; compact description uses bounded lines and full values remain in tooltip.


T14 supplemental: inherited attack hit / echo charge versus snapshot / final HUD cooldown RED 3 → GREEN 3 (T14-feedback-red, T14-feedback-green3). Tooltip preserves complete bounded-card description. Initial supplemental edit had an indentation parse error; M4-regression-1 198/208 is invalid for acceptance; corrected and awaiting a fresh stable-tree run.

T15 instrumentation: opt-in HP-clamped effective damage/overkill/status damage, shield generation/absorption, matched rule execution/denial, resource crossings and Boss-qualified rule execution. Buff uptime in episodes is the integral of active timed ModifierStore sources (source-seconds). No metric is a player win-rate proxy. Calibration RED missing service → GREEN exact 100P/1000HP actual enemy pipeline plus shield 25/10. Logs T15-metrics-runtime2.

T15 protocol: headless default viewport 64×64 excluded actual targets. T15-protocol-red → T15-protocol-green proves normal 1280×720 targeting. Invalid pilot T15-smoke-real2 and early fixed pilots are excluded. Corrected pilot-exploration: 18 builds × 1 seed × 6 scenes = 108 rows; 18/18 workers exit 0. Normal clears: 18/18 single, 18/18 eight, 9/18 twentyfour. All 36 Boss rows die early. These are preflight observations, not the requested 10/20-seed acceptance.

Ruling: 不对预检暴露的巨大跨度盲目调整技能数值，保留测试版资格与统计门槛未通过 — 单体清怪跨度3.4、8怪36.29、24怪16.43，Boss样本均早死；≤10%单维改动不能证明能修正这些差距，需先校准控制器和场景适配 — cost if wrong: 延后完成10探索/20确认及融合异常扩样，当前版本不能宣称已平衡。

Ruling: 不可移动Boss暂记录为独立未通过项，现有唯一真实Boss的静止攻击阶段仅作为代理场景 — 规格禁止为实际平衡采样改变敌人参数，当前数据没有永久不可移动Boss；M2的不可移动夹具只证明机制边界 — cost if wrong: 缺少真实不可移动Boss的平衡证据，不能用代理补齐验收计数。

Performance: first M4 rendered run overlapped regression jobs, excluded from baseline comparison. Serial reruns use the same copied script at T0 6dfee02 and M4; fixed24 replenishment and 60s actual waves, 12 forced skills, normal Lv3, seed618, survival assistance explicitly limited to stress profiling. Full-run balance evidence never uses this assistance.


Stable regression: 208/208 PASS in M4-stable-regression; final contract probes T15-final-contract/T15-final-perf-contract PASS. Supplemental UI commit1ff2d2c; T15 tooling commite433e9a. Corrected real upper300s pilot: early defeat102.95s, effective10897, status2907, completed300s=false (T15-real-corrected).

T15 paired fusion pilot: 15 pairs × 1 seed × 6 scenes × 2 variants =180; all15 workers exit0; actualfusion-attributed effective damage874. This does not satisfy5/20seed cohorts or utility acceptance. No numeric tuning commits.

Ruling: 因M4尚无数值调参提交，在独立演练分支回退并恢复最近含数值的混合提交cc80738 — 完成可逆回滚验证，避免对M4运行中分支和用户main操作 — cost if wrong: 该回滚会同时撤回语义功能，不能冒充线上精细数值回滚；清单明确这个限制。

Rollback: cc80738 →5a54041 →6f735c2; tree814363fc8b29b0b4711809362d59ceafc98c5833 before/after identical. Content and144ID inventory PASS both states. Output rollback-reports/result.json; E:/codex/skill-rebalance/rollback-rehearsal preserved for review.

Ruling: 用PowerShell/Python维护阶段台账和审查包，替代技能的POSIX临时脚本 — 保证所有可控写入留在E盘并符合当前Windows环境 — cost if wrong: 辅助记录流程与技能脚本不完全相同，提交/日志/审查范围在文件中显式记录。

T16: test-version documentation and rollback complete;208/208 fresh regression. Manual6×2 absent; statistical/performance/full-run gates unaccepted. Independent whole-M4review remains pending. This line does not mark complete acceptance.


Final performance protocol correction: capture process_frame wall intervals after2s warmup, not physics_frame intervals. Valid serial logs T15-performance/T0-frame-serial andM4-frame-serial. Fixed24: T0p95=2.321ms/10990frames, M4=3.602ms/4253frames (+55.19%, relative gateFAIL). Actualfirst60swaves:1.334→1.420ms (+6.45%, gatesPASSforwindowonly). Object peaks1384/1424; pending18/0. Full late dense-wave, starvation and infinite-growth acceptance remainopen. Numeric balance targets accepted=[] in release manifest.


T16 final UI: Rendered T16-ui-final PASS/noengineerrors; cards960 and replacement screenshots inspected; HUD1280/960 captured. Static content/Modifier/UTF8 checks PASS. Release manifest has144accepted behavior IDs,208validated checks,108/180pilot rows,0complete300s,0human games andemptyaccepted_balance_targets.
