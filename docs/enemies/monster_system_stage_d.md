# SDD ledger — plan: docs/superpowers/plans/2026-10-10-monster-system-improvement.md

## 阶段 D：真实生命战斗初筛

依据 M11/M12 补齐 240 条件自动战斗观测，保留真实生命、冷却与伤害；计时采用 1 倍游戏时钟、60 Hz 固定步长。真人完整试玩 16 局仍须真实玩家执行。

Pre-flight: 初筛复用 C 阶段合法构筑与真实 UI 生命周期；必须覆盖父类补血和墙钟驱动，否则新数据无效。仅改验证工具与文档，不改变怪物数值。

Ruling: 沿用现有 checkout 并保存待改文件至 E:/codex/monster-system/stage-d-baseline — 保留 A/B/C 未提交成果 — 若错误，须按阶段基线恢复工具。

Ruling: 三构筑是当前合法技能组成的实验初始 loadout，自动选卡按稀有度与已学技能升级排序 — 提供可复现的战斗初筛 — 不能据此推导自然成长或真人胜率。

Ruling: 300 秒观察窗到期记为 censored，死亡为正常观测结果；从首次生命下降至死亡测 TTK，未死亡保留删失样本 — 排除寻敌等待与假击杀 — 幸存击杀仍有选择偏差，不单独判定平衡通过。

任务：观测器 RED→GREEN；正常生命驱动与 240 条件采样；分条件分析与真人记录表；一次独立审查、回归与阶段汇报。

Ruling: 修订的 survival_assist 标签写入独立 normalized_samples.json，保留原始样本并记录其 SHA256、原值和修订原因 — 原驱动没有补血，问题是父类恒定 true 的报告标签，重采不会改变实际行为证据 — 若此判断错误，正常生命结论失效；分析器拒绝加速/高血量/代杀数据的标签修订。

Ruling: 对已观察到存活时间 66–168 秒波动的 mage/abandoned_dungeon/build2 追加至 20 种子（618–637） — 检查五种子波动 — 仍属于机器人样本，不能完成真人体验验收；其他异常条件继续列为待扩样。

Final: fixed 时长字段 elapsed_seconds 与真实 duration_seconds 不匹配 — 真实输出格式测试 RED→GREEN，加入无效数值检查。
Final: fixed 生存辅助标签矛盾 — 真实 JSON 断言 RED→GREEN，驱动显式 false，分析器校验。
Final: fixed 批次仅检查完成索引无法保护运行/失败证据 — 目录冲突测试 RED→GREEN，任何旧目录拒绝并以 CreateNew 原子锁防止并发同名启动。
Final review: 独立 stage_d_review，一次审查、一次修复；Declined-to-judge 无；Deferred minors 无。

## 验证证据

- 观测器：E:/codex/monster-system/stage-d-red（6 条预期失败，无解析错误）→stage-d-green（通过）。首次命中、治疗、重复退出、删失与快照独立性均覆盖。
- 审查修复：真实 duration_seconds 格式断言和批次目录冲突断言先失败；原始正常生命 JSON 的 survival_assist=true 断言失败；修订后 stage-d-tag-green2 实际 JSON 为 false，初始生命 75。完整回归 E:/codex/canonical-refactor/monster-stage-d-final2/results.json：180/180，0 脚本/engine 错误。早期 final 批次在测试修改期间有一项失败，原结果保留，最终以 final2 为准。
- 追加 mage/abandoned_dungeon/build2：20 个不同种子、20 次机器人死亡，首个精英覆盖 15 局，无 Boss；存活中位 96.033 秒，范围 66.083–168.217 秒，最后伤害类别 ranged 10、enemy 8、contact 2。完整分构筑 TTK 分组见 E:/codex/monster-system/stage-d-variance-summary/summary.json。
- 真人记录表：docs/enemies/monster_system_human_playtest.md，16 格均待真人填写。正常生命自动移动和选卡仍不能代替真人体验。
- 五个配置 SHA256 与 C 阶段一致，E:/codex/monster-system/stage-d-artifacts/config_version.json。本阶段不调整 HP/伤害/奖励，不重复将 headless FPS 当作渲染性能。渲染及串行性能证据沿用 C 阶段，未改变产品运行时代码。

正式 240 条件已完成：4 角色×4 图×3 合法实验构筑×种子 618–622，48 条件各 5 种子，身份无重复。四分片退出码均 0、stderr 为空；规范化分析 issues=[]，隔离 save.cfg 残留 0。

240 次均为机器人死亡，65 局遇到精英、4 次完成精英击杀、0 局进入 Boss。记录 27395 次首伤后伤害击杀、2117 条已受伤但未完成击杀的删失观察，按构筑、成长选择、阶段与等级拆成 3262 组；无首伤节点不混入 TTK。0 秒首伤后击杀表示一击击杀，不能直接等同于从攻击意图开始的真人击杀耗时。

文件：E:/codex/monster-system/stage-d-final/combat_summary.json、conditions.csv、ttk.csv；每局原始 latest_samples.json 原样保留，normalized_samples.json 附来源 SHA256 和标签修订，四个 normalized_screening.json 指向规范化证据。运行命令：`node tools/verify/analyze_monster_combat.js E:/codex/monster-system/stage-d-final --normalize-assist-label --expect-240`。

任务状态：观测器、240 初筛、一个异常条件的 20 种子扩样、独立审查与 180/180 回归完成。16 局真人、Boss 正常生命完整战斗、其余高波动条件的 20 种子扩样保持开放；不标记 M11 体验完成或发布候选。本轮未提交、未推送，保留阶段 C 工作区。

Task D: complete（阶段为初筛与工具验收）；180/180 全矩阵通过，240 原始文件 SHA256 及规范化数据逐对象对照通过，所有测量值不变。回退清单 13 项（4 修改、9 新增），保存在 E:/codex/monster-system/stage-d-artifacts/rollback_manifest.json；C 清单的 27 个产品文件未改变。本阶段证据保留，不删阶段 A/B/C 或其他计划的文件。
