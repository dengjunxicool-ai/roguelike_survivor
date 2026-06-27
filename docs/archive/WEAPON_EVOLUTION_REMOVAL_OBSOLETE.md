# Weapon Evolution Removal Notes

## Decision

终式进化功能已全量移除。武器分支到 Lv5 后不再检测终式进化，不再生成终式候选，不再切换到 `_evolved` 技能。

## Former Chain

旧链路大致如下：

1. 分支 Lv5 配置 `enable_evolution_check=true`。
2. `WeaponBranchSystem` 把该标记写入 `SkillInstance` meta。
3. `UpgradePool` 调用终式系统查询可用进化，并生成 `evolution:<skill_id>:<evolution_id>` 候选。
4. `Player.apply_upgrade()` 识别 evolution 升级 ID。
5. `WeaponEvolutionSystem.apply_evolution()` 替换当前技能定义和 skill_id。
6. `WeaponRuntimeSlot` / `CharacterRuntime` 保存 evolved 状态。
7. UI、DebugPanel、Codex、结算解锁等模块展示或触发终式相关内容。

## Current Chain

当前链路只保留：

1. Lv2 选择 4 条武器分支之一。
2. Lv2-Lv5 逐级应用分支配置。
3. Lv5 作为分支 capstone，不再触发额外系统。
4. 升级池只生成分支、主攻升级、普通技能、奖励、诅咒等非终式候选。

## Removed Runtime Surface

| Area | Removed |
| --- | --- |
| Data | 有效 `weapon_evolutions` 配置、`_evolved` 主攻击、`_evolved` legacy skill。 |
| Branch | `enable_evolution_check` 配置字段和 meta 写入。 |
| Upgrade | 终式候选构建、debug 终式候选、`evolution:` 升级 ID。 |
| Player | 终式系统 preload、终式应用入口、`skill_evolved` signal。 |
| Runtime State | `evolution_id`、`is_evolved`、`mark_weapon_evolved()`、终式查询接口。 |
| UI / Debug | 终式 modal、Codex 终式页、DebugPanel 强制进化按钮。 |
| Tools | weapon graph / scaffold / authoring template 中的终式生成与校验。 |

## Guardrail

使用下面命令确认项目没有重新引入终式链路：

```bash
node tools/validate_no_weapon_evolution.js
```

完整武器配置验证：

```bash
node tools/validate_weapon_authoring_pipeline.js
```
