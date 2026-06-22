# Weapon System Overview

当前武器系统是数据驱动的：`data/weapons.json` 定义武器身份，`data/primary_attack.json` 定义真正执行的主武器攻击，`data/weapon_branches.json` 定义 Lv2-Lv5 分支成长，`data/combat_objects.json` 定义 projectile / area / orbit_object 的通用表现。运行时只维护一个主武器槽位：`CharacterRuntime.main_weapon_slot`，槽位对象为 `WeaponRuntimeSlot`。

终式进化功能已移除。后续武器达到 Lv5 后不再检测终式条件，不再生成进化升级选项，也不会切换到 `_evolved` 技能。

## 当前规则

1. 武器本身不是攻击执行器。运行时真正执行的是 `weapons.json.starting_skill_id` 对应的 `primary_attack` 技能。
2. 单把武器的数值、目标、命中行为和分支成长优先改 JSON：`weapons.json`、`primary_attack.json`、`weapon_branches.json`、`combat_objects.json`。
3. 每把武器固定 4 条分支，每条分支提供 Lv2-Lv5 的成长。
4. Lv5 是分支成长终点。Lv5 后继续升级时只走普通升级池规则，不做终式检测。
5. `data/weapon_evolutions.json` 保留为空表，不能再放入有效进化配置。

## 数据规模

| 类型 | 数量 |
| --- | ---: |
| 武器 | 13 |
| 主攻击技能 | 13 |
| 分支 | 52 |
| 进化 | 0 |

## 关键文件

| 模块 | 文件 | 责任 |
| --- | --- | --- |
| 武器身份 | `data/weapons.json` | 武器 ID、名称、标签、起始技能。 |
| 主攻击 | `data/primary_attack.json` | 主武器实际执行的攻击定义。 |
| 分支成长 | `data/weapon_branches.json` | Lv2-Lv5 分支选择、修正器、事件追加、标签追加。 |
| Combat Object | `data/combat_objects.json` | projectile / area / orbit_object 的碰撞、生命周期、视觉和伤害参数。 |
| 数据索引 | `scripts/core/data_manager.gd` | 启动时索引武器、主攻击、分支和 combat object。 |
| 数据访问 | `scripts/game/game_data.gd` | 对 runtime 暴露武器、主攻击、分支等查询接口。 |
| 槽位状态 | `scripts/weapons/weapon_runtime_slot.gd` | 保存本局主武器 ID、当前技能 ID、分支 ID、分支等级。 |
| 分支系统 | `scripts/weapons/weapon_branch_system.gd` | 应用分支 Lv2-Lv5 的修正器、事件和标签。 |
| 升级池 | `scripts/upgrades/upgrade_pool.gd` | 生成分支选择、主攻升级和普通升级选项。 |
| 玩家聚合根 | `scripts/player/player_controller.gd` | 开局初始化、应用升级、调用分支系统。 |

## 战斗链路

1. 开局选择角色后，`Player.initialize_from_character()` 读取角色默认武器。
2. `GameData.get_weapon_definition()` 读取武器配置。
3. `weapons.json.starting_skill_id` 绑定到 `primary_attack.json` 中的主攻击技能。
4. `CharacterRuntime.equip_main_weapon()` 创建 `WeaponRuntimeSlot`。
5. `SkillManager.add_skill()` 创建 `SkillInstance`。
6. 自动攻击流程读取 `SkillInstance.definition`，根据 components / events / actions 生成 projectile、area 或 orbit_object。
7. 命中后由 `PrimaryAttackExecutor` 和 combat object 事件执行伤害、爆炸、DOT、击退、召唤等效果。
8. 升级时 `UpgradePool.generate_options()` 根据当前主武器等级和分支状态生成候选。
9. 选择分支或升级后，`Player.apply_upgrade()` 调用 `WeaponBranchSystem` 或 `SkillManager.upgrade_skill()`。

## 运行时状态

`WeaponRuntimeSlot` 当前只保存主武器运行必需状态：

| 字段 | 含义 |
| --- | --- |
| `weapon_id` | 当前装备武器 ID。 |
| `base_skill_id` | 武器初始技能 ID。 |
| `current_skill_id` | 当前实际执行技能 ID。终式移除后通常与 `base_skill_id` 保持一致。 |
| `selected_branch_id` | 已选择的分支 ID。 |
| `branch_level` | 当前分支等级，未选择分支前为 1，选择后成长到 5。 |
| `branch_modifiers` | 已应用的分支修正器列表。 |
| `branch_event_additions` | 已应用的分支事件追加。 |
| `branch_tags` | 已应用的分支标签。 |

`CharacterRuntime` 对外提供：

| 方法 | 用途 |
| --- | --- |
| `get_equipped_weapon_id()` | 当前主武器 ID。 |
| `get_equipped_weapon_skill_id()` | 当前主武器技能 ID。 |
| `get_equipped_weapon_branch_id()` | 当前分支 ID。 |
| `get_equipped_weapon_branch_level()` | 当前分支等级。 |
| `set_weapon_branch(branch_id)` | 选择分支。 |
| `set_weapon_branch_level(level)` | 设置分支等级。 |
| `add_weapon_branch_modifiers(modifiers)` | 累积分支修正器。 |
| `add_weapon_branch_events(events)` | 累积分支事件追加。 |
| `add_weapon_branch_tags(tags)` | 累积分支标签。 |

## 分支升级链路

1. 主武器 Lv1 升 Lv2 时，`UpgradePool` 生成 4 个分支候选。
2. 选择分支后，`WeaponBranchSystem.apply_branch_selection()` 应用该分支 Lv2。
3. 后续主武器升级到 Lv3-Lv5 时，`WeaponBranchSystem.apply_branch_level()` 应用对应等级配置。
4. 分支配置可以追加结构化 modifier、事件和标签。
5. Lv5 配置只作为 capstone 成长，不再写入任何终式检测标记。

## 已移除的终式链路

以下能力已从当前 runtime 和工具链移除：

| 旧能力 | 当前状态 |
| --- | --- |
| `WeaponEvolutionSystem` | 已删除，不再检查或应用终式。 |
| `evolution:<skill_id>:<evolution_id>` 升级选项 | 已删除，升级池不再生成。 |
| `enable_evolution_check` | 已从 runtime 配置和设计配置移除。 |
| `_evolved` 主攻击技能 | 已从 `primary_attack.json` 移除。 |
| `WeaponRuntimeSlot.is_evolved` / `evolution_id` | 已删除。 |
| 终式 UI / Debug 强制进化按钮 / Codex 进化页 | 已移除。 |
| `GameData.get_weapon_evolution*` / `DataManager.get_weapon_evolution*` | 已删除。 |

## 修改武器时的最短路径

### 调整基础攻击

1. 找 `data/weapons.json` 的武器 ID 和 `starting_skill_id`。
2. 到 `data/primary_attack.json` 修改对应技能的 base、components、events 或 actions。
3. 如果改 projectile / area / orbit_object 的通用参数，同步修改 `data/combat_objects.json`。
4. 运行 `node tools/validate_weapon_authoring_pipeline.js`。

### 调整武器视觉

1. 找 `data/weapons.json` 的 `visual`。
2. `visual.icon` 用于 UI 图标，`visual.texture` 用于玩家身上的武器贴图。
3. `visual.scale` 控制贴图缩放，`visual.rotation` 控制贴图初始旋转角度，单位为度。
4. `visual.rotation` 只影响 `WeaponVisual` 显示，不影响弹体、碰撞、索敌或伤害方向。

### 调整分支

1. 找 `data/weapon_branches.json` 的 `weapon_id + archetype`。
2. 修改 `level_path.2` 到 `level_path.5`。
3. 修正器必须使用统一结构：`{ "stat": "...", "op": "...", "value": ..., "scope": {...} }`。
4. 需要新增事件时写入 `events_added`，并确认 action executor 已支持对应动作。
5. Lv5 不要添加 `enable_evolution_check`，也不要引用 `_evolved` 技能。
6. 运行 `node tools/validate_no_weapon_evolution.js` 和 `node tools/validate_weapon_authoring_pipeline.js`。

## 验证

终式移除后的核心不变量由 `tools/validate_no_weapon_evolution.js` 固化：

- `data/weapon_evolutions.json` 不能包含有效进化配置。
- `data/primary_attack.json` 不能包含 `_evolved` 主攻击。
- `data/weapon_branches.json` 和 `docs/weapon_design_configs/*.json` 不能包含 `enable_evolution_check`。
- 当前 `.gd` / `.js` 运行代码不能引用终式系统、终式升级 ID 或终式状态接口。

完整配置流水线使用：

```bash
node tools/validate_weapon_authoring_pipeline.js
```
