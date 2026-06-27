# 技能系统神系重做实现计划

> **给执行者：** 必须按任务逐项执行。建议使用 `superpowers:subagent-driven-development`，也可以使用 `superpowers:executing-plans`。任务步骤使用 checkbox 跟踪。

**目标：** 用神系技能池替换武器绑定技能流程，定义六个神系，并交付 60 个真实生效的火焰技能和粒子反馈。

**架构：** 新增 `data/gods.json` 和 `data/skills.json` 作为玩家技能数据源；迁移数据加载、开局配置、升级池、技能持有、火焰运行规则和角色选择 UI，使主流程不再依赖武器。伤害和状态继续走现有战斗链路；新增数据驱动的火焰规则层和可复用 `GPUParticles2D` 粒子工厂。

**技术栈：** Godot 4.6 GDScript、JSON 配置、Node.js 验证脚本、现有 `DataManager`、`GameData`、`SkillManager`、`SkillExecutor`、`SkillEventBus`、`SkillActionExecutor`、伤害和状态服务。

---

## 已锁定决策

- 第一批不再保留“主动技能槽上限 5”作为硬限制；后续会接入更科学的限制设置。
- 火焰技能不把等级或主动技能数量硬写死为 5。`max_level` 作为数据字段保留，具体值按技能描述和实现需要设置。
- 被动技能不占主动技能数量限制；如果后续新增全局上限，也必须走统一配置。
- 当前默认初始攻击保留为 `fireball`（当前来自 `fire_staff.starting_skill_id`），但不再从武器解析。`mars_spark_missile` 是火系第一个可学习技能及其粒子表现，不是人物初始攻击。
- 当前工作区不是 git 仓库，因此所有 commit 步骤改为验证检查点。`git status --short` 当前会失败并提示 `fatal: not a git repository`。

## 文件结构

- 新增 `data/gods.json`：六个神系定义。
- 新增 `data/skills.json`：60 个火焰可学习技能定义、粒子和运行时规则；同时用独立的 `starting_skills` 迁移当前开局攻击，它们不进入升级池。
- 修改 `data/characters.json`：添加 `starting_skill_id`，主流程不再使用武器 allowlist。
- 修改 `data/upgrades.json`：删除、禁用或迁移武器标签升级。
- 修改 `scripts/core/data_manager.gd`：加载 gods 和 skills，停止从旧技能文件索引玩家技能。
- 修改 `scripts/game/game_data.gd`：从新数据暴露神系和技能池。
- 修改 `scripts/characters/run_loadout.gd`：loadout 只保留角色。
- 修改 `scripts/characters/character_loadout_service.gd`：只校验角色和初始技能。
- 修改 `scripts/characters/character_run_initializer.gd`：从角色配置授予初始技能。
- 修改 `scripts/characters/character_runtime.gd`：移除本局武器状态依赖。
- 修改 `scripts/player/player_controller.gd`：移除武器系统节点和分支升级分派。
- 修改 `scripts/ui/screens/character_loadout_controller.gd`：移除武器网格，确认信号只带角色。
- 修改 `scripts/ui/screens/character_loadout_view_model_builder.gd`：构建角色-only 视图模型。
- 修改 `scripts/ui/ui_manager.gd`：角色-only loadout 信号和构建路径。
- 修改 `scripts/ui/hud/run_hud_state_provider.gd`：移除武器/分支 HUD 状态。
- 修改 `scripts/debug/dev_debug_panel.gd`：新增火焰技能调试入口，不走主流程升级也能选择技能卡并验证技能生效链路。
- 修改 `scripts/upgrades/upgrade_pool.gd`：新增 dev tools 使用的火焰技能选项生成方法，替换旧武器分支调试选项。
- 修改 `scripts/enemies/enemy_status_display_controller.gd` 或新增敌人生命条控制器：把数字血量展示改为可视化血条。
- 修改 `scripts/enemies/enemy_base.gd`：在 `health_changed`/受击路径中更新敌人血条，保留伤害跳字。
- 修改 `scripts/skills/skill_definition.gd`：解析 `god_id`、`rarity`、`particle`、`runtime_rules`。
- 修改 `scripts/skills/skill_instance.gd`：支持运行时规则状态。
- 修改 `scripts/skills/skill_manager.gd`：支持主动和被动技能。
- 修改 `scripts/skills/skill_executor.gd`：不带武器上下文 tick 技能和火焰规则。
- 修改 `scripts/skills/skill_event_bus.gd`：把全局技能事件路由给主动/被动技能。
- 修改 `scripts/skills/skill_action_executor.gd`：移除武器来源假设，增加粒子 action。
- 新增 `scripts/skills/fire_skill_runtime.gd`：火焰叠层、击杀触发、反击、护盾、复活、冷却返还、强化等规则。
- 新增 `scripts/visual/skill_particle_factory.gd`：可复用 `GPUParticles2D` 工厂。
- 新增 `docs/skills/runtime_families.md`：记录每个运行族的语义、所需字段、支持规则和适配技能；新增运行族时必须更新此文档。
- 新增验证脚本：
  - `tools/verify_gods_and_skills_contract.js`
  - `tools/verify_skill_runtime_no_dead_cards.js`
  - `tools/verify_weapon_system_removed_from_main_flow.js`
  - `tools/verify_fire_skill_upgrade_pool.js`
  - `tools/verify_fire_skill_card_selection_runtime.gd`
  - `tools/verify_fire_skill_dev_tools_entry.gd`
  - `tools/verify_enemy_health_bar.gd`
- 新增 Godot smoke：
  - `tools/verify_fire_skill_runtime_smoke.gd`
- 修改 `package.json`：替换旧武器验证脚本为神系/技能验证脚本。

---

## 任务 1：先写数据契约验证

**文件：**
- 新增：`tools/verify_gods_and_skills_contract.js`
- 测试：`data/gods.json`
- 测试：`data/skills.json`

- [ ] **步骤 1：写失败的验证脚本**

脚本检查：

- `data/gods.json` 必须有 6 个神系：`fire`、`thunder`、`frost`、`curse`、`holy`、`chaos`。
- 神系 id 必须唯一。
- `data/skills.json` 的 `skills` 数组必须有 60 个 `god_id: "fire"` 的火焰可学习技能。
- `fireball` 是从当前默认开局迁移来的初始攻击，只能出现在 `starting_skills`，不能计入火焰 60 个可学习技能。
- `starting_skills` 中的技能必须设置 `offer_in_upgrade_pool: false`，避免作为升级卡重复出现。
- 火焰技能必须包含文档中的 60 个中文技能名。
- 稀有度数量必须是：`common: 24`、`rare: 18`、`epic: 12`、`legendary: 6`。
- 每个火焰技能必须有 `id`、`display_name`、`god_id`、`rarity`、`source_rarity`、`description`、`vfx_description`、`build_hint`、`category`、`runtime_family`、`tags`、`particle`。

- [ ] **步骤 2：运行并确认失败**

运行：

```powershell
node tools\verify_gods_and_skills_contract.js
```

预期：失败，因为 `data/gods.json` 和 `data/skills.json` 还不存在。

- [ ] **步骤 3：记录检查点**

记录失败输出。此任务不改生产代码。

---

## 任务 2：新增神系和火焰技能数据

**文件：**
- 新增：`data/gods.json`
- 新增：`data/skills.json`
- 新增：`docs/skills/runtime_families.md`
- 修改：`data/characters.json`
- 测试：`tools/verify_gods_and_skills_contract.js`

- [ ] **步骤 1：创建 `data/gods.json`**

顶层结构：

```json
{
  "gods": [
    {
      "id": "fire",
      "display_name": "火焰",
      "title": "火之神",
      "description": "以燃烧、爆发、弹体、反击和终局强化为核心的高压输出神系。",
      "tags": ["fire", "burn", "burst", "projectile"],
      "color": [1.0, 0.34, 0.08, 1.0],
      "implemented": true
    }
  ]
}
```

完整文件必须包含六神系。除 `fire` 外，其他神系第一批 `implemented: false`。

- [ ] **步骤 2：创建 `data/skills.json`**

创建火焰 60 个技能。每个技能都必须有 `runtime_family`，并且属于以下运行族之一，保证不是空卡：

```json
[
  "projectile",
  "cone_area",
  "radial_pulse",
  "orbit",
  "targeted_strike",
  "summon",
  "passive_modifier",
  "stack_mark",
  "kill_trigger",
  "damage_taken_trigger",
  "cooldown_reducer",
  "shield",
  "empower_next_fire",
  "delayed_damage",
  "revive_once",
  "fire_skill_count_scaling"
]
```

如果技能描述无法被这些运行族准确表达，必须新增运行族，并同步更新 `docs/skills/runtime_families.md`。新增运行族时需要写清：

```markdown
## runtime_family_id

- 语义：这个运行族表达什么技能行为。
- 必需字段：该族在 `base`、`components`、`events` 或 `runtime_rules` 中需要哪些字段。
- 运行支持：由哪个 action、组件或 runtime rule 实现。
- 适配技能：列出使用该运行族的技能 id 和中文名。
- 第一版简化：如果文档效果被简化，说明简化边界和仍然真实生效的部分。
```

示例技能结构：

```json
{
  "id": "mars_spark_missile",
  "display_name": "火星飞弹",
  "god_id": "fire",
  "rarity": "common",
  "source_rarity": "普通",
  "description": "周期性发射小型火星弹，自动追踪最近敌人。",
  "vfx_description": "小颗橙红火星拖尾飞行。",
  "build_hint": "弹体数量流、燃烧铺垫",
  "category": "active",
  "runtime_family": "projectile",
  "tags": ["fire", "projectile", "homing", "burn_setup"],
  "max_level": 1,
  "base": {
    "damage": 8,
    "damage_type": "direct_magical",
    "element": "fire",
    "cooldown": 1.35,
    "range": 620,
    "projectile_speed": 360,
    "projectile_count": 3,
    "area_radius": 10
  },
  "components": [
    {"type": "cooldown", "params": {"seconds": 1.35}},
    {"type": "targeting", "params": {"mode": "nearest_enemy", "range": 620}}
  ],
  "events": [
    {
      "trigger": "on_cast",
      "actions": [
        {
          "type": "spawn_projectile",
          "params": {
            "projectile_id": "fire_spark_projectile",
            "count": 3,
            "speed": 360,
            "lifetime": 2.0,
            "collision_radius": 10,
            "homing_enabled": true,
            "homing_turn_rate": 8.5,
            "homing_seek_range": 620,
            "damage": 8,
            "damage_origin": "skill",
            "damage_type": "direct_magical",
            "element": "fire",
            "particle_profile": "fire_spark_trail"
          }
        }
      ]
    },
    {
      "trigger": "on_projectile_hit",
      "source_id": "fire_spark_projectile",
      "actions": [
        {
          "type": "deal_damage",
          "params": {
            "amount": 8,
            "damage_type": "direct_magical",
            "element": "fire",
            "can_crit": true,
            "damage_origin": "skill"
          }
        },
        {
          "type": "spawn_particles",
          "params": {
            "profile": "fire_hit_small",
            "position_mode": "target"
          }
        }
      ]
    }
  ],
  "particle": {"profile": "fire_spark_trail"}
}
```

- [ ] **步骤 3：给角色添加现有初始攻击**

把当前默认初始攻击从 `data/primary_attack.json` 迁移到 `data/skills.json` 的独立顶层 `starting_skills` 数组中。第一批迁移 `fireball`，因为当前默认 `fire_staff.starting_skill_id` 是 `fireball`。

迁移后的初始攻击必须包含：

```json
{
  "id": "fireball",
  "category": "active",
  "is_starting_skill": true,
  "offer_in_upgrade_pool": false
}
```

在 `data/characters.json` 每个当前角色对象中加入：

```json
"starting_skill_id": "fireball"
```

`allowed_weapon_ids` 不再作为运行时依赖。不要把 `mars_spark_missile` 用作人物初始攻击；它只属于火焰神系第一个可学习技能及其粒子表现。如果当前任务尚未迁移所有读取方，可以暂时保留 `allowed_weapon_ids` 字段，但后续任务必须移除主流程读取。

- [ ] **步骤 4：运行契约验证**

运行：

```powershell
node tools\verify_gods_and_skills_contract.js
```

预期：通过。

---

## 任务 3：验证没有“只进池不生效”的技能，并模拟选卡攻击

**文件：**
- 新增：`tools/verify_skill_runtime_no_dead_cards.js`
- 新增：`tools/verify_fire_skill_card_selection_runtime.gd`
- 测试：`data/skills.json`
- 测试：代表性火焰技能运行时

- [ ] **步骤 1：写验证脚本**

Node 脚本检查每个火焰技能至少满足其一：

- 有可执行 `events.actions`。
- 有 `skill_modifiers`。
- 有受支持的 `runtime_rules`。
- 有合法 `runtime_family`，并且该族记录在 `docs/skills/runtime_families.md` 中。

支持的第一批规则：

```javascript
[
  "fire_stack_mark",
  "fire_kill_spawn",
  "fire_cooldown_refund",
  "fire_damage_taken_retaliation",
  "fire_shield",
  "fire_empower_next",
  "fire_delayed_echo",
  "fire_revive_once",
  "fire_skill_count_scaling",
  "fire_status_expire_damage",
  "fire_projectile_split",
  "fire_burning_bonus",
  "fire_high_health_bonus"
]
```

- [ ] **步骤 2：运行并确认失败或通过**

运行：

```powershell
node tools\verify_skill_runtime_no_dead_cards.js
```

预期：如果有任何火焰技能没有真实运行效果，则失败。

- [ ] **步骤 3：补齐技能数据**

每个火焰技能必须补成以下之一：

```json
{
  "events": [
    {
      "trigger": "on_cast",
      "actions": [
        {
          "type": "spawn_area",
          "params": {
            "area_id": "fire_pulse_area",
            "damage": 10,
            "element": "fire"
          }
        }
      ]
    }
  ]
}
```

或：

```json
{
  "skill_modifiers": [
    {
      "stat": "damage",
      "op": "multiplier_add",
      "value": 0.08,
      "scope": {
        "domain": "damage",
        "element": ["fire"]
      }
    }
  ]
}
```

或：

```json
{
  "runtime_rules": [
    {
      "type": "fire_cooldown_refund",
      "params": {
        "status_id": "burn",
        "refund_seconds": 0.25
      }
    }
  ]
}
```

- [ ] **步骤 4：再次运行验证**

运行：

```powershell
node tools\verify_skill_runtime_no_dead_cards.js
```

预期：通过。

- [ ] **步骤 5：新增选卡攻击运行时 smoke**

创建 `tools/verify_fire_skill_card_selection_runtime.gd`，模拟以下流程：

```text
创建 DataManager。
创建 Player 和 SkillManager/SkillExecutor/SkillEventBus。
创建一个测试敌人，记录其初始生命。
从 UpgradePool 生成火焰技能卡。
应用一张当前待测技能卡。
触发一次技能攻击。
等待 0.2 到 1.0 秒，让投射物/区域/状态/粒子完成首轮结算。
断言敌人生命下降或状态增加或玩家/技能 runtime 状态发生变化。
断言有 GPUParticles2D 节点被生成。
断言伤害跳字节点或 DebugCombatTrace 记录存在。
断言最终伤害符合现有伤害公式链路输出，而不是直接改血。
```

第一版至少覆盖每个运行族一张代表技能。若某个运行族只在后续新增技能中出现，同步补 smoke case。

- [ ] **步骤 6：运行选卡攻击 smoke**

运行：

```powershell
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_fire_skill_card_selection_runtime.gd
```

预期输出至少包含：

```text
PASS card selected
PASS attack triggered
PASS projectile or particle feedback observed
PASS status or runtime effect observed when expected
PASS damage popup or damage trace observed
PASS damage formula chain used
```

---

## 任务 3.5：在 Dev Tools 增加火焰技能链路调试入口

**文件：**
- 修改：`scripts/debug/dev_debug_panel.gd`
- 修改：`scripts/upgrades/upgrade_pool.gd`
- 新增：`tools/verify_fire_skill_dev_tools_entry.gd`
- 测试：当前 dev tools 的技能选择、授予、施放和反馈链路

- [ ] **步骤 1：先写失败的 Dev Tools smoke**

创建 `tools/verify_fire_skill_dev_tools_entry.gd`。脚本必须在不进入普通升级流程的情况下完成：

```gdscript
extends SceneTree

func _init() -> void:
	root.set_meta("developer_mode_enabled", true)
	root.set_meta("debug_control_mode", true)
	root.set_meta("debug_manual_spawn_only", true)

	var ui_manager: Node = root.get_node_or_null("UIManager")
	_assert(ui_manager != null and ui_manager.has_method("start_developer_debug_run"), "UIManager developer debug run exists")
	ui_manager.call("start_developer_debug_run", {"character_id": "mage", "map_id": "default", "debug": true})
	await process_frame
	await process_frame

	var panel: Node = root.find_child("DevDebugPanel", true, false)
	_assert(panel != null, "DevDebugPanel exists")
	_assert(panel.has_method("debug_run_fire_skill_chain"), "DevDebugPanel exposes Fire skill chain debug method")

	var result: Dictionary = panel.call("debug_run_fire_skill_chain", &"mars_spark_missile")
	_assert(bool(result.get("option_generated", false)), "Fire skill debug option generated")
	_assert(bool(result.get("granted", false)), "Fire skill granted through debug card path")
	_assert(int(result.get("cast_count", 0)) >= 1, "Fire skill debug cast count")
	_assert(int(result.get("damage_record_count", 0)) >= 1, "Fire skill debug damage recorded")
	_assert(int(result.get("particle_count", 0)) >= 1, "Fire skill debug particles spawned")
	_assert(int(result.get("damage_popup_count", 0)) >= 1, "Fire skill debug damage popup shown")
	quit(0)


func _assert(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	push_error("FAIL %s" % label)
	quit(1)
```

运行：

```powershell
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_fire_skill_dev_tools_entry.gd
```

预期：失败，因为 DevDebugPanel 还没有 `debug_run_fire_skill_chain()`。

- [ ] **步骤 2：给 UpgradePool 增加 dev 火焰技能选项生成**

在 `scripts/upgrades/upgrade_pool.gd` 新增：

```gdscript
func generate_debug_fire_skill_options(player: Node, god_id: StringName = &"fire") -> Array:
	var options: Array = []
	for skill: Dictionary in GameData.get_learnable_skill_pool():
		if StringName(String(skill.get("god_id", ""))) != god_id:
			continue
		if bool(skill.get("offer_in_upgrade_pool", true)) == false:
			continue
		options.append(_make_skill_learn_option(player, skill))
	return options
```

如果现有实现中学习卡构造函数不叫 `_make_skill_learn_option()`，先在任务 7 中新增并复用同一个函数；dev tools 不能自己伪造一套不同的授予逻辑。

- [ ] **步骤 3：在 DevDebugPanel 增加 Fire Skill Debug 页面能力**

在 `scripts/debug/dev_debug_panel.gd` 的 `Skill Cards` 页面新增：

- 一个火焰技能 `OptionButton`，显示 60 个火焰可学习技能。
- `Grant Fire Skill` 按钮：调用和升级卡相同的授予路径，不直接改字典状态。
- `Spawn Target` 按钮：复用现有 `_spawn_debug_enemy()`。
- `Cast Selected Fire Skill` 按钮：只触发当前选择技能一次。
- `Run Fire Skill Chain` 按钮：执行完整链路并把结果写入日志。

新增公开调试方法：

```gdscript
func debug_run_fire_skill_chain(skill_id: StringName) -> Dictionary:
	# 供 DevDebugPanel 按钮和 headless smoke 共用。
	# 返回真实统计值：option_generated、granted、cast_count、damage_record_count、particle_count、damage_popup_count。
	return {}
```

最终实现必须返回真实统计值，不能保留空字典。统计来源：

- `option_generated`：来自 `UpgradePool.generate_debug_fire_skill_options()`。
- `granted`：来自技能卡选择/授予路径。
- `cast_count`：来自 `SkillExecutor.debug_cast_all_skills(trace_id)` 或等价的单技能 debug cast。
- `damage_record_count`：来自 `DebugCombatTrace.get_records(root)` 中 `type == "damage"` 的记录数。
- `particle_count`：统计本次 trace 后场景中新生成的 `GPUParticles2D` 数量。
- `damage_popup_count`：统计敌人受击后产生的伤害跳字节点或敌人调试显示记录。

- [ ] **步骤 4：运行 Dev Tools smoke**

```powershell
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_fire_skill_dev_tools_entry.gd
```

预期输出包含：

```text
PASS UIManager developer debug run exists
PASS DevDebugPanel exists
PASS DevDebugPanel exposes Fire skill chain debug method
PASS Fire skill debug option generated
PASS Fire skill granted through debug card path
PASS Fire skill debug cast count
PASS Fire skill debug damage recorded
PASS Fire skill debug particles spawned
PASS Fire skill debug damage popup shown
```

---

## 任务 4：迁移 DataManager 和 GameData

**文件：**
- 修改：`scripts/core/data_manager.gd`
- 修改：`scripts/game/game_data.gd`
- 测试：`tools/verify_gods_and_skills_contract.js`

- [ ] **步骤 1：扩展 DataManager 常量和索引**

加入：

```gdscript
const GODS_PATH: String = "res://data/gods.json"
const SKILLS_PATH: String = "res://data/skills.json"
const GODS_KEY: String = "gods"
const SKILLS_KEY: String = "skills"

var _god_definitions: Dictionary = {}
```

- [ ] **步骤 2：加载新数据**

`load_all()` 中清空并加载：

```gdscript
_god_definitions.clear()

var gods_document: Dictionary = _load_json_document(GODS_PATH)
_index_definitions(gods_document, GODS_KEY, "id", _god_definitions, GODS_PATH)

var skills_document: Dictionary = _load_json_document(SKILLS_PATH)
_index_definitions(skills_document, SKILLS_KEY, "id", _skill_definitions, SKILLS_PATH)
_index_skill_upgrade_definitions(skills_document, SKILLS_PATH)
_index_definitions(skills_document, COMBAT_OBJECTS_KEY, "id", _combat_object_definitions, SKILLS_PATH)
```

停止从 `primary_attack.json` 和 `learnable_skills.json` 索引玩家技能。

- [ ] **步骤 3：新增神系 getter**

```gdscript
func get_god_definition(god_id: Variant) -> Dictionary:
	return _get_definition(_god_definitions, god_id)


func get_god_definitions() -> Array[Dictionary]:
	return _get_definition_values(_god_definitions)
```

- [ ] **步骤 4：从 skills 派生学习卡**

新增 `_index_skill_upgrade_definitions()`，为每个 `offer_in_pool != false` 的技能生成：

```gdscript
{
	"id": "learn_skill:%s" % skill_id,
	"display_name": skill.display_name,
	"description": skill.description,
	"rarity": skill.rarity,
	"tags": skill.tags,
	"enabled": true,
	"max_level": 1,
	"learn_skill_id": skill_id
}
```

- [ ] **步骤 5：同步 GameData**

新增 `GODS_PATH`、`SKILLS_PATH`、`get_god()`、`get_god_pool()`。

`get_skill()` fallback 改为：

```gdscript
static func get_skill(skill_id: StringName) -> Dictionary:
	var data: Dictionary = _get_definition_from_data_manager("get_skill_definition", skill_id)
	if not data.is_empty():
		return data
	return _find_by_id(_get_array(SKILLS_PATH, "skills"), skill_id)
```

`get_skill_pool()`、`get_level_up_upgrade_pool()`、`get_upgrade()` 也改为使用 `data/skills.json`。

- [ ] **步骤 6：运行验证**

```powershell
node tools\verify_gods_and_skills_contract.js
node tools\verify_skill_runtime_no_dead_cards.js
```

预期：全部通过。

---

## 任务 5：开局配置改为角色-only，并保留初始技能

**文件：**
- 修改：`scripts/characters/run_loadout.gd`
- 修改：`scripts/characters/character_loadout_service.gd`
- 修改：`scripts/characters/character_run_initializer.gd`
- 修改：`scripts/characters/character_runtime.gd`
- 修改：`data/characters.json`
- 新增/测试：`tools/verify_weapon_system_removed_from_main_flow.js`

- [ ] **步骤 1：先写静态守卫**

新增 `tools/verify_weapon_system_removed_from_main_flow.js`，检查这些文件不再包含主流程武器依赖：

- `scripts/characters/run_loadout.gd`
- `scripts/characters/character_loadout_service.gd`
- `scripts/characters/character_run_initializer.gd`
- `scripts/player/player_controller.gd`
- `scripts/upgrades/upgrade_pool.gd`

禁止模式包括：

```text
weapon_id
weapon_data
weapon_definition
WeaponSkillBinding
WeaponEquipSystem
bind_starting_skill
lock_equipped_weapon
WeaponBranchSystem
branch_choice
get_equipped_weapon
```

- [ ] **步骤 2：运行并确认失败**

```powershell
node tools\verify_weapon_system_removed_from_main_flow.js
```

预期：失败，因为当前代码仍有武器依赖。

- [ ] **步骤 3：重写 RunLoadout**

`RunLoadout` 只保留：

```gdscript
var character_id: StringName = &""
var character_data: Dictionary = {}
var character_definition: RefCounted
```

`is_valid()` 只校验角色。

- [ ] **步骤 4：重写 CharacterLoadoutService**

`validate_loadout(character_id)` 只检查：

- 角色 id 非空。
- 角色存在。
- 角色有 `starting_skill_id`。
- `starting_skill_id` 能从新 `skills.json` 加载。

`build_loadout(character_id)` 返回角色-only `RunLoadout`。

- [ ] **步骤 5：更新 CharacterRunInitializer**

`initialize_loadout()` 只初始化角色 runtime。

`configure_starting_skills()`：

- 清空技能。
- 从角色配置读取 `starting_skill_id`。
- 调用 `SkillManager.add_skill(starting_skill_id)`。
- 连接 trait 技能事件。

- [ ] **步骤 6：更新 CharacterRuntime**

`initialize()` 只接收 `character_id`，移除本局装备武器字段和 getter 的主流程依赖。

- [ ] **步骤 7：运行静态守卫**

```powershell
node tools\verify_weapon_system_removed_from_main_flow.js
```

预期：此时可能仍失败，因为 Player 和 UpgradePool 会在任务 6、7 迁移。

---

## 任务 6：从 Player 和 UI 移除武器流程

**文件：**
- 修改：`scripts/player/player_controller.gd`
- 修改：`scripts/ui/screens/character_loadout_controller.gd`
- 修改：`scripts/ui/screens/character_loadout_view_model_builder.gd`
- 修改：`scripts/ui/screens/character_loadout_text.gd`
- 修改：`scripts/ui/ui_manager.gd`
- 修改：`scripts/ui/hud/run_hud_state_provider.gd`
- 测试：`tools/verify_weapon_system_removed_from_main_flow.js`

- [ ] **步骤 1：移除 PlayerController 的武器子系统**

删除这些 preload 和节点创建：

```gdscript
WeaponEquipSystemScript
WeaponSkillBindingScript
WeaponBranchSystemScript
WeaponVisualScript
```

`_ready()` 使用：

```gdscript
var default_loadout: RefCounted = CharacterLoadoutServiceScript.build_loadout(selected_character_id)
```

`reset_for_loadout()` 只设置 `selected_character_id`。

- [ ] **步骤 2：移除分支升级分派**

`apply_upgrade()` 删除 `branch_choice:` 处理。

`_upgrade_skill()` 只调用 `SkillManager.upgrade_skill()`，不再调用 `WeaponBranchSystem`。

- [ ] **步骤 3：角色选择 UI 改成只确认角色**

`CharacterLoadoutController`：

```gdscript
signal loadout_confirmed(character_id: StringName)
```

删除武器网格、武器详情、武器切换、武器校验。

- [ ] **步骤 4：角色选择 ViewModel 去掉武器**

`CharacterLoadoutViewModelBuilder.build()` 改为：

```gdscript
func build(character_id: StringName, carousel_index: int, sync_index_from_selected: bool) -> Dictionary:
```

返回角色、角色详情、初始技能文案和按钮状态。不再返回 `weapon_id` 或 `weapons`。

- [ ] **步骤 5：更新 UIManager 信号链**

`loadout_confirmed` 的连接和 handler 只传 `character_id`。

构建 loadout：

```gdscript
CharacterLoadoutServiceScript.build_loadout(character_id)
```

- [ ] **步骤 6：HUD 移除武器状态**

`RunHudStateProvider` 删除武器名、分支、进化、当前武器技能字段。已有主动技能展示可以保留。

- [ ] **步骤 7：运行静态守卫**

```powershell
node tools\verify_weapon_system_removed_from_main_flow.js
```

预期：如果 UpgradePool 尚未迁移，仍会失败；否则通过。

---

## 任务 7：升级池改为技能优先

**文件：**
- 修改：`scripts/upgrades/upgrade_pool.gd`
- 修改：`scripts/upgrades/upgrade_offer_policy.gd`
- 修改：`data/upgrades.json`
- 新增：`tools/verify_fire_skill_upgrade_pool.js`
- 测试：`tools/verify_weapon_system_removed_from_main_flow.js`

- [ ] **步骤 1：写升级池验证**

`tools/verify_fire_skill_upgrade_pool.js` 检查：

- `data/upgrades.json` 的 `level_up_upgrades` 不再带 `weapon` 标签。
- 不再有 `required_weapon_tags`。
- 60 个火焰技能没有被 `offer_in_pool: false` 禁掉。

- [ ] **步骤 2：运行并确认失败**

```powershell
node tools\verify_fire_skill_upgrade_pool.js
```

预期：失败，因为当前升级配置仍含武器标签。

- [ ] **步骤 3：删除 UpgradePool 分支阶段逻辑**

删除：

- `_build_branch_choice_options`
- `_select_branch_choice_stage_options`
- `_get_weapon_branch_system`
- `_get_current_weapon_id`
- `_get_current_weapon_skill_id`
- `_is_current_weapon_skill`
- 武器 full matrix debug 选项

`generate_options()` 改为始终走成长池：

```gdscript
func generate_options(player: Node, count: int = 3) -> Array:
	var requested_count: int = maxi(count, 0)
	if requested_count <= 0:
		return []
	return _select_growth_stage_options(player, requested_count)
```

- [ ] **步骤 4：从技能池生成学习/升级卡**

未拥有技能学习卡：

```gdscript
"id": "level_up_upgrade:learn_skill:%s" % String(skill.get("id", ""))
```

已拥有可升级技能卡：

```gdscript
"id": "skill_level_up:%s" % String(skill_id)
```

- [ ] **步骤 4.5：放开主动技能数量硬上限**

`UpgradePool` 和 `SkillManager` 不能再因为“主动技能已有 5 个”而停止提供学习技能卡。第一版可以采用：

```gdscript
@export_range(1, 999, 1, "or_greater") var max_active_skills: int = 999
```

或改为读取后续可配置规则。无论采用哪种方式，都不要在升级池中写死 `5`。如果保留 `is_active_skill_full()`，它必须基于配置值，而不是固定 5。

- [ ] **步骤 5：保持稀有度权重**

继续使用：

```gdscript
var rarity_weights: Dictionary = {
	"common": 60.0,
	"rare": 28.0,
	"epic": 10.0,
	"legendary": 2.0
}
```

- [ ] **步骤 6：清理 upgrades 数据**

删除、禁用或迁移武器专属升级。保留不要求武器标签的生存和通用 meta 升级。

- [ ] **步骤 7：运行验证**

```powershell
node tools\verify_fire_skill_upgrade_pool.js
node tools\verify_weapon_system_removed_from_main_flow.js
```

预期：通过。

---

## 任务 8：支持被动技能和火焰运行规则

**文件：**
- 修改：`scripts/skills/skill_definition.gd`
- 修改：`scripts/skills/skill_instance.gd`
- 修改：`scripts/skills/skill_manager.gd`
- 修改：`scripts/skills/skill_executor.gd`
- 修改：`scripts/skills/skill_event_bus.gd`
- 新增：`scripts/skills/fire_skill_runtime.gd`
- 测试：`tools/verify_skill_runtime_no_dead_cards.js`

- [ ] **步骤 1：扩展 SkillDefinition**

新增字段：

```gdscript
var god_id: StringName = &""
var rarity: String = "common"
var particle: Dictionary = {}
var runtime_rules: Array[Dictionary] = []
var skill_modifiers: Array[Dictionary] = []
```

在 `_init()` 中解析对应 JSON 字段。

- [ ] **步骤 2：SkillManager 支持被动技能**

新增：

```gdscript
var passive_skills: Dictionary = {}
```

`add_skill()` 遇到 `category == "passive"` 时：

- 加入 `passive_skills`。
- 标记 learned。
- 应用 `skill_modifiers`。
- 发出 `skill_added` 和 `skill_changed`。
- 不占主动技能槽。

同时放开主动技能数量硬上限。`max_active_skills` 不能再默认表达“最多 5 个主动技能”；第一版可以改为较大的配置值，或让 `is_active_skill_full()` 在没有配置规则时返回 `false`。

新增：

```gdscript
func get_owned_skill_instances() -> Array:
	var owned: Array = []
	owned.append_array(active_skills.values())
	owned.append_array(passive_skills.values())
	return owned
```

- [ ] **步骤 3：新增 FireSkillRuntime**

`scripts/skills/fire_skill_runtime.gd` 负责：

- tick 周期性规则。
- 响应 `on_projectile_hit`、`on_enemy_killed`、`on_player_damaged` 等事件。
- 执行 `runtime_rules`。
- 所有伤害、状态、区域、粒子都通过现有 action 或服务，不直接改敌人 HP。

- [ ] **步骤 4：接入 SkillExecutor 和 SkillEventBus**

`SkillExecutor` tick 主动技能后 tick 火焰运行规则。

`SkillEventBus.emit_skill_event()` 把支持的事件转发给火焰运行规则。

- [ ] **步骤 5：验证无死卡**

```powershell
node tools\verify_skill_runtime_no_dead_cards.js
```

预期：通过。

---

## 任务 9：新增粒子工厂和粒子 action

**文件：**
- 新增：`scripts/visual/skill_particle_factory.gd`
- 修改：`scripts/skills/skill_action_executor.gd`
- 修改：`data/skills.json`
- 测试：`tools/verify_skill_runtime_no_dead_cards.js`

- [ ] **步骤 1：创建粒子工厂**

`SkillParticleFactory.spawn(parent, position, profile)` 创建 `GPUParticles2D`：

- `amount`
- `lifetime`
- `one_shot`
- `ParticleProcessMaterial`
- 初速度
- spread
- scale
- modulate 颜色
- finished 后 `queue_free`

- [ ] **步骤 2：SkillActionExecutor 增加 `spawn_particles`**

`execute_action()` 增加：

```gdscript
"spawn_particles":
	return _spawn_particles(params, context)
```

`_spawn_particles()` 调用 `SkillParticleFactory.spawn()`。

- [ ] **步骤 3：给火焰技能挂粒子**

每个火焰技能都必须有 `particle` profile，并至少在施放、命中、脉冲、触发或复活时播放一次可见粒子。

角色初始攻击 `fireball` 第一版可以使用简单圆形或矩形粒子/形状 profile；`mars_spark_missile` 仍按火系第一个可学习技能的火星飞弹粒子表现处理。例如：

```json
{
  "profile": "fire_starting_circle",
  "shape": "circle",
  "color": [1.0, 0.38, 0.08, 0.95],
  "amount": 18,
  "lifetime": 0.35
}
```

不要为初始技能引入额外美术资源依赖。

- [ ] **步骤 4：运行验证**

```powershell
node tools\verify_skill_runtime_no_dead_cards.js
```

预期：通过。

---

## 任务 10：敌人可视化血条和扣血缓动

**文件：**
- 修改：`scripts/enemies/enemy_status_display_controller.gd` 或新增 `scripts/enemies/enemy_health_bar_controller.gd`
- 修改：`scripts/enemies/enemy_base.gd`
- 新增：`tools/verify_enemy_health_bar.gd`
- 测试：敌人受击显示

- [ ] **步骤 1：新增或扩展敌人血条控制器**

将当前数字血量展示替换为可视化血条。血条至少包含：

```text
背景条：深色，表示总血量。
即时血量条：受击后立即更新到 current_health / max_health。
缓动血量条：受击后延迟/平滑追到即时血量，用于表现扣血反馈。
```

建议尺寸：

```gdscript
const BAR_SIZE: Vector2 = Vector2(46.0, 5.0)
const BAR_OFFSET: Vector2 = Vector2(-23.0, -42.0)
```

用 `ColorRect` 或 `TextureProgressBar` 均可。保持实现轻量，不引入图片资源。

- [ ] **步骤 2：接入 EnemyBase 血量变化**

在 `EnemyBase` 中把 `health_changed(current_health, max_health)` 接到血条控制器。

受击后：

```text
即时条马上变化。
缓动条用 Tween 或 `_process(delta)` 平滑追赶。
伤害跳字仍保留，不被血条替代。
死亡时血条隐藏或随敌人节点销毁。
```

- [ ] **步骤 3：创建血条验证 smoke**

创建 `tools/verify_enemy_health_bar.gd`，模拟：

```text
生成敌人。
确认血条节点存在。
记录满血时即时条和缓动条比例为 1。
对敌人造成一次伤害。
确认即时条比例立刻下降。
等待缓动时间。
确认缓动条最终追到即时条。
确认伤害跳字或 DebugCombatTrace 仍存在。
```

- [ ] **步骤 4：运行验证**

运行：

```powershell
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_enemy_health_bar.gd
```

预期输出：

```text
PASS enemy health bar exists
PASS immediate health bar updates
PASS eased health bar catches up
PASS damage number remains available
```

---

## 任务 11：运行时 smoke 测试

**文件：**
- 新增：`tools/verify_fire_skill_runtime_smoke.gd`
- 修改：`package.json`
- 测试：火焰技能运行时和粒子工厂

- [ ] **步骤 1：创建 Godot smoke 脚本**

初版检查：

- `DataManager` 能加载 6 个神系。
- `mars_spark_missile` 能从 `skills.json` 的火焰可学习技能中加载，且 `god_id == "fire"`。
- `fireball` 能作为迁移后的 `starting_skills` 初始攻击加载，且不进入升级池。

后续扩展为：

- 实例化玩家。
- 添加代表性火焰技能。
- 生成 dummy enemy。
- 调用 `debug_cast_all_skills()`。
- 断言伤害、状态、粒子存在。

- [ ] **步骤 2：运行 smoke**

```powershell
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_fire_skill_runtime_smoke.gd
```

预期：通过。

- [ ] **步骤 3：更新 package.json**

新增：

```json
{
  "scripts": {
    "validate:skills": "node tools\\verify_gods_and_skills_contract.js && node tools\\verify_skill_runtime_no_dead_cards.js && node tools\\verify_fire_skill_upgrade_pool.js && node tools\\verify_weapon_system_removed_from_main_flow.js",
    "test:skills:runtime": ".\\roguelike_survivor.console.exe --headless --path . --script tools\\verify_fire_skill_runtime_smoke.gd",
    "test:skills:card": ".\\roguelike_survivor.console.exe --headless --path . --script tools\\verify_fire_skill_card_selection_runtime.gd",
    "test:skills:devtools": ".\\roguelike_survivor.console.exe --headless --path . --script tools\\verify_fire_skill_dev_tools_entry.gd",
    "test:enemy:healthbar": ".\\roguelike_survivor.console.exe --headless --path . --script tools\\verify_enemy_health_bar.gd",
    "test:skills": "npm run validate:skills && npm run test:skills:runtime && npm run test:skills:card && npm run test:skills:devtools && npm run test:enemy:healthbar"
  }
}
```

如果 Windows 命令转义导致 `package.json` 无法稳定运行，保留 `validate:skills`，并在最终验证中直接报告三个 Godot smoke 命令。

---

## 任务 12：最终验证

**文件：**
- 所有本计划涉及文件

- [ ] **步骤 1：运行数据和静态验证**

```powershell
node tools\verify_gods_and_skills_contract.js
node tools\verify_skill_runtime_no_dead_cards.js
node tools\verify_fire_skill_upgrade_pool.js
node tools\verify_weapon_system_removed_from_main_flow.js
```

预期：全部通过。

- [ ] **步骤 2：运行 Godot smoke**

```powershell
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_fire_skill_runtime_smoke.gd
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_fire_skill_card_selection_runtime.gd
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_fire_skill_dev_tools_entry.gd
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_enemy_health_bar.gd
```

预期输出包含：

```text
PASS six gods load
PASS first Fire learnable skill loads
PASS migrated starting attack loads
PASS character-only run starts
PASS Fire skill option generated
PASS Fire skill deals damage
PASS Fire status skill applies status
PASS Fire particles spawned
PASS Fire skill debug option generated
PASS Fire skill granted through debug card path
PASS Fire skill debug damage recorded
PASS no weapon branch option generated
PASS enemy health bar eases after damage
```

- [ ] **步骤 3：手动游戏 smoke**

启动项目并检查：

```text
不需要选择武器。
开局自动获得 `fireball` 初始攻击。
升级选项包含火焰技能，并使用当前稀有度权重。
Dev Tools 中可以选择火焰技能并一键验证授予、施放、伤害、状态、粒子和伤害跳字。
选择火焰技能后出现 GPUParticles2D 粒子。
敌人通过正常伤害链路扣血。
敌人血量用可视化血条展示，扣血时有缓动。
伤害跳字仍正常出现。
没有武器、分支或进化 UI。
```

- [ ] **步骤 4：检查工作区状态**

```powershell
git status --short
```

当前预期：`fatal: not a git repository`。最终汇报中说明无法提交，因为工作区没有 `.git` 仓库。

---

## 计划自审

- 规格覆盖：计划覆盖 `gods.json`、`skills.json`、火焰 60 技能真实生效、运行族文档、粒子、角色-only 开局、保留初始技能、升级池稀有度、武器主流程移除、敌人可视化血条和验证。
- 死卡检查：计划要求每个可选火焰技能都必须有 action、modifier 或受支持 runtime rule，禁止只进升级池不影响对局。
- 类型一致性：`god_id`、`rarity`、`runtime_rules`、`particle`、`starting_skill_id`、升级选项前缀在数据、加载器、管理器和升级池任务中保持一致。
