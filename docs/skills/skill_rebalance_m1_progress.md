# SDD ledger — plan: docs/superpowers/plans/2026-10-09-skill-system-rebalance.md

执行范围：M1（T0–T4），阶段完成后暂停汇报。工作树：E:/codex/skill-rebalance/worktree；分支：codex/skill-rebalance-m1；起点：6dfee02。测试输出：E:/codex/skill-rebalance/。

Ruling: 原生工作树工具未提供 E 盘路径参数，使用 git 在 E:/codex 建立工作树 — 遵守用户禁止 C 盘写入的要求 — 此工作树由 git 管理，不自动合入 main。
Ruling: Windows 下以 PowerShell 手工维护 brief/ledger，代替技能的 Bash 辅助脚本 — 防止默认临时目录写入 C 盘 — 保留任务、基线提交、红绿灯及验收记录。
Ruling: 包装器默认 ProjectPath 在当前 PowerShell 解析失败，所有验证显式指定 ProjectPath — 未更改产品逻辑 — 命令比原模板多一个参数。

Pre-flight: T1→T2 使用单次成长的动作参数与标准 ModifierQuery；临时增益不得再写永久 runtime_modifiers。
Pre-flight: T2→T3 一次性充能先锁定释放快照，只有成功施放才消费；失败必须保留。
Pre-flight: T3→T4 状态保留事件源和 proc 字段，结算移除状态后再发事件以避免重入重复。
Pre-flight: T3 时钟与 T2 计时均消费运行 delta；暂停不推进，重开清零。

T0: in progress；导入基线 PASS（exit=0, script_errors=0, engine_errors=0）。
T0: fixture baseline observed rarity downgrade (0.574358974), permanent buff, Cursed refresh delay; growth legacy baseline 3/3 PASS. T1 RED: monotonic 11 assertions FAIL, growth 10 assertions FAIL (no script errors). Ruling: chain uses nested actions, not an unsupported direct damage field; corrected the test fixture before implementation.
