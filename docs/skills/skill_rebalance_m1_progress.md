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
T1: complete; new monotonic/growth and four legacy growth tests PASS, exit=0, script_errors=0, engine_errors=0. Config validator PASS after adding the new schema root fields. T2 RED timed lifecycle: three expected behavior failures. Ruling: burst already had top-level growth; the defect was nested normalization, not missing top-level scaling.

T0: complete; 144 unique IDs (84 base, 60 fusion), six schools ×14, 15 pairs ×4 and 18 cast IDs verified. Original headless/script baseline: 157/157 PASS (`suite-baseline/results.json`); two scene-driven baseline cases also exit=0 with no script/engine errors (`baseline-scene-area`, `baseline-scene-fireball`). Total original registered checks: 159.
T0: actual short-run characterization used mage / abandoned_dungeon / seed618 / fresh isolated save / no movement or survival assistance. Original and M1 both observed RESULT_DEFEAT, 21 physics frames, sampled elapsed1.6667s, health0, Power24, enemies15. Logs: `T00-gameplay-original2` and `T00-gameplay-m1`; this is a stationary characterization, not a 300-second playability or balance acceptance.

T2: timed lifecycle RED3 and attribute consumption RED4 expected assertions, then GREEN (no script/engine errors). Tests cover cast-only damage, refresh without stacking, expiration, zero-delta pause, source removal/restart, real thunder CD, direct/natural freeze duration, actual existing Frozen vulnerability runtime regression and shield-conditional holy damage query. Unknown modifier stat rejected by both content validators; Node mutation test retained. Charge acquisition now uses actual EnemyRewardController death notifications; 11 cursed kills uncharged, 12th grants1.35; failed cast retains charge and full successful release consumes once, including real delayed projectile hit and area tick.
T3: provenance RED7 and policy/clock RED6 expected assertions, then GREEN. Added real owned listener source-tag check, actual shield→lightning→post-hit chain, final derived DamagePacket fields, stable target/object-pair ICD, actual SceneTree pause, reset and 64/65 FIFO behavior. Real freed-node condition repro produced `Trying to cast a freed object`; dispatch now purges invalid references while death eligibility uses the captured status snapshot. Inherited packet creation timestamps no longer freeze ICD: new events stamp the current bus clock; actual area events re-open after0.4s.
T4: lifecycle RED12 and race RED12 expected assertions, then GREEN. 100P Burning totals144/720, no stack decay, refresh at cap, final tick before removal, and large delta cannot tick beyond lifetime. Cursed t0/t2→t3 gives150, full-stack refresh still225 at the first deadline; forced/reentrant/dead target cases resolve at most once. Freeze threshold7/core5, tier durations1.2/0.5/0.15; natural/shatter/forced endings start immunity, and independent pause sources keep Cursed paused until last release.

Review: fresh-context read-only reviewer found six concrete lifecycle/provenance gaps and a follow-up delayed clock regression. All addressed; final read-only assessment found no remaining concrete M1 blocker. Evidence folders: `review-freeze-red/green`, `review-death-red`, `review-delayed-red3/green`, `review-queue-node-red2`, `review-proc-final`, `review-shatter-red/green`, `review-clock-red/green`, `review-real-area-icd`, `review-acquisition-final`, `review-status-final`.
Ruling: positive passive duration/range effects retain passive level growth but do not receive quality scaling, as specified. Legendary chill extension was reproduced RED (1.56s Frozen), then GREEN (1.44s direct and natural); logs `review-duration-quality-red/green`.
Ruling: T2/T3 share action/manager interfaces; task commits are retained in dependency order, but standalone intermediate commits are not individual release candidates. Accept M1 at the final combined revision. Review fixes are assigned to their owning task below.

Legacy assertion migrations (all remain runnable):

| Tests | Reason / behavioral replacement |
| --- | --- |
| growth scaling/rule adapter/summon/manager | New quality multipliers, quality excludes geometry/time, DOT grows once; monotonic and damage-path tests |
| burn table/fire status contract/burn runtime/stack devtools | Keep stacks and0.36P per stack; lifecycle and actual enemy mitigation (180 raw,117 Boss) |
| learning policies/missing rarity/responsibility boundary | Upgrade cards preserve quality and consume no RNG; explicit promotion only |
| skill card numeric/reference layout | Lv2 rare20% attack modifier=20%×1.08×1.15=24.84% |
| first fire card/holy contract/fire trigger registry | Overheat shares12s ICD and explicit low-HP entry; devotion is shield overflow; successful cast event registered |
| fusion runtime source fixture | Source name alone cannot imply frost area; explicit frost-area provenance produces output; 60 full semantics remain M3 |
| fire/frost smoke fixtures | Supply real caster Power and restore the independent pulse test target after the prior lethal-execute test |
| soulburn legacy runtime | Compatibility Power fallback uses0.36 coefficient and never final hit damage; old explicit numerical contract preserved |

Final acceptance: complete — `suite-m1-acceptance/results.json`:169/169 PASS (74 Node checks,93 Godot scripts,2 Godot scene checks;10 new M1 checks). All95 Godot results confirmed exit=0, script_errors=0, engine_errors=0. Final Godot editor import also PASS (`M1-import-final`). `git diff --check` clean. Stage M1 completed; stopped before M2 as requested.

Supplementary pause assertion: actual paused clock physics handler receives10.0s delta, clock still2.0s; complete proc suite PASS (`review-pause10-final`). No production changes after the169-case acceptance run.

Local rollback checkpoints (no push/merge):

| Task | Commit | File ownership |
| --- | --- | --- |
| T0 | a423de8 | Inventory/coverage, baseline fixture/tool, approved plan/spec copies |
| T1 | d71ed58 | Growth/upgrade/adapter/config and first growth regression migrations |
| T2 | e0338d5 | Scoped/timed ModifierStore, canonical attribute consumption, charge storage, validator registry, timed/consumption tests; includes reviewed passive rarity boundary |
| T3 | 0f63345 | Bus/context/proc/clock, DamagePacket and death provenance, charge snapshot consumption, real delayed-output and queue tests |
| T4 | 8c84ac3 | Status definitions/lifecycle/query, effective Power compatibility, Burning/freeze/race tests |
| Regression tooling | 548cf1e | Remaining intentional old-contract migrations, real-run sample, script/scene isolation and169-case runner |

Each commit's exact file list is available with `git show --name-only <commit>`; preserve the complete M1 chain for acceptance. This ledger and plan checkbox/state updates are a final documentation checkpoint. Original `E:/roguelike_survivor` tracked source was not modified; user's untracked plan/spec files remain there. Implemented version is in the E:/codex worktree.

Deferred deliberately: M2–M4, independent core/fusion capacity and replacement, prerequisites/offers, six-school redesign, actual copy/replay, 18 cast milestones, full60 fusion semantics, HUD/preview and 300-second balance/performance tuning. Coverage rows remain baseline; none of these skills are labeled fully accepted from a common M1 regression.

PR preflight (2026-10-09): initial fresh run `suite-pr-m1/results.json` passed168/169; holy runtime smoke retained4 rather than2 Judgment stacks. Independent reproduction failed the same assertion. Diagnostics showed the shared target already had2 stacks, the five incremental applications ended at4, and later area/summon physics could change it back to2. The fixture now uses a fresh distant target, applies exactly5 stacks, and asserts a newly created punishment area plus2 retained stacks before advancing the frame. No production rules changed. Targeted isolated runs `pr-holy-isolated1/2` both PASS. Fresh complete verification `suite-pr-m1-final/results.json`:169/169 PASS (74 Node,93 Godot scripts,2 scenes); all95 Godot reports exit=0, script_errors=0, engine_errors=0. `git diff --check main` clean. User authorized pushing M1 and creating a PR; M2–M4 remain unexecuted.
