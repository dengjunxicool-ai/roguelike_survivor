# Weapon Combat Scene Checks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build automated combat-scene tests that reproduce fixed battlefield scenes such as `mage + fire_staff + burst/soulburn Lv2 + attack once + small_slime`, then assert damage, status, special rules, and trace fields.

**Architecture:** Add one Godot headless runtime checker under `scripts/debug/` that owns the deterministic scene harness and case catalog. It reuses the existing Dev Mode runtime path (`UIManager.start_developer_debug_run`, real Player, real SkillExecutor, real WeaponBranchSystem, real enemy scene, and `DebugCombatTrace`) instead of fabricating combat actors or reimplementing formulas. Existing Node.js contract scripts remain the static gate.

**Tech Stack:** Godot 4.x headless, GDScript `SceneTree`, existing JSON data files, existing Node.js contract checks.

---

## File Structure

- Create: `scripts/debug/weapon_combat_scene_check.gd`
  - SceneTree test runner.
  - Defines the first fire-staff scene cases.
  - Spawns deterministic player and enemy nodes.
  - Applies weapon branch runtime state.
  - Forces hits and records trace output.
  - Writes text report to `reports/combat-scene-checks/weapon_combat_scene_check.txt`.
- No initial changes: `scripts/skills/skill_special_rule_executor.gd`
  - Only change this if the new runtime tests expose a real mismatch.
- No initial changes: `scripts/combat/status_effect_manager.gd`
  - Use `get_status_snapshot()`, `get_status_stack()`, and `apply_status()` from the existing API.
- No initial changes: `scripts/debug/debug_combat_trace.gd`
  - Use existing `begin_attack_trace()` and `get_records()`.

Current workspace note: `E:\roguelike_survivor` is not a Git repository, so commit steps are intentionally omitted from this plan.

## Execution Revision: Reuse Dev Tool Runtime

The original outline used minimal fake `TestPlayer` / `TestEnemy` actors for early scene checks. After inspecting the current Debug Mode / Dev Tool, implementation should instead reuse the real debug runtime:

- Start the scene through `UIManager.start_developer_debug_run`.
- Keep `developer_mode_enabled`, `debug_control_mode`, and `debug_manual_spawn_only` enabled.
- Spawn fixed enemies by instantiating `res://scenes/enemy.tscn`, not by driving Dev Tool UI widgets.
- Apply branches through the real player `WeaponBranchSystem`.
- Raise weapon level through the real player skill upgrade path.
- Trigger one attack through `SkillExecutor.debug_cast_all_skills(trace_id)`.
- Assert output through `DebugCombatTrace.get_records(root)` and enemy status APIs.

Do not drive `OptionButton`, `SpinBox`, or private UI button handlers from automation. The Dev Tool remains the manual companion; the automated checker reuses its underlying runtime capabilities.

---

### Task 1: Add Runtime Scene Checker Skeleton

**Files:**
- Create: `scripts/debug/weapon_combat_scene_check.gd`

- [ ] **Step 1: Create the SceneTree runner**

Add:

```gdscript
extends SceneTree

const DebugCombatTraceScript: Script = preload("res://scripts/debug/debug_combat_trace.gd")

var _failed: bool = false
var _lines: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.set_meta("developer_mode_enabled", true)
	root.set_meta("debug_control_mode", true)
	_lines.append("[WeaponCombatSceneCheck] start")
	_write_result()
	quit(1 if _failed else 0)

func _expect(condition: bool, message: String, details: Dictionary = {}) -> void:
	if condition:
		_lines.append("[PASS] " + message)
		return
	_failed = true
	_lines.append("[FAIL] " + message)
	for key: Variant in details.keys():
		_lines.append("  %s: %s" % [String(key), str(details[key])])

func _write_result() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/combat-scene-checks"))
	var file: FileAccess = FileAccess.open("res://reports/combat-scene-checks/weapon_combat_scene_check.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines))
		file.close()
	print("\n".join(_lines))
```

- [ ] **Step 2: Run skeleton**

Run:

```powershell
godot --headless --path . --script res://scripts/debug/weapon_combat_scene_check.gd
```

Expected:

```text
[WeaponCombatSceneCheck] start
```

Exit code must be `0`. If Godot crashes with `signal 11`, stop and record the environment blocker.

---

### Task 2: Add Minimal Test Actors

**Files:**
- Modify: `scripts/debug/weapon_combat_scene_check.gd`

- [ ] **Step 1: Add test player and target classes**

Insert below constants:

```gdscript
const DamageApplicationServiceScript: Script = preload("res://scripts/combat/damage_application_service.gd")
const StatusEffectManagerScript: Script = preload("res://scripts/combat/status_effect_manager.gd")

class TestPlayer:
	extends Node2D

	var character_id: StringName = &"mage"
	var selected_weapon_id: StringName = &"fire_staff"
	var damage_multiplier: float = 1.0
	var attack_speed_multiplier: float = 1.0
	var skill_area_multiplier: float = 1.0
	var status_duration_multiplier: float = 1.0
	var crit_chance: float = 0.0
	var crit_damage: float = 1.5

class TestEnemy:
	extends Node2D

	signal health_changed(current_health: int, max_health: int)

	var enemy_id: StringName = &"small_slime"
	var max_health: int = 18
	var current_health: int = 18
	var armor: int = 0
	var defense: int = 0
	var resistances: Dictionary = {}
	var damage_taken_multiplier: float = 1.0
	var _is_dead: bool = false
	var last_damage_amount: int = 0
	var last_damage_result: Dictionary = {}
	var last_damage_packet: Variant = null
	var status_manager: StatusEffectManager

	func _ready() -> void:
		if status_manager == null:
			status_manager = StatusEffectManagerScript.new()
			status_manager.name = "StatusEffectManager"
			add_child(status_manager)

	func take_damage(amount_or_packet: Variant, damage_type: Variant = &"") -> void:
		DamageApplicationServiceScript.apply_enemy_damage(self, amount_or_packet, damage_type)

	func apply_status(status_id: Variant, params: Dictionary = {}) -> bool:
		return status_manager.apply_status(status_id, params)

	func get_status_stack(status_id: Variant) -> int:
		return status_manager.get_status_stack(status_id)

	func consume_status_stack(status_id: Variant, stack_count: int = 1) -> bool:
		return status_manager.consume_status_stack(status_id, stack_count)

	func get_status_snapshot() -> Array[Dictionary]:
		return status_manager.get_status_snapshot()

	func _apply_damage_synergies(amount: int, _damage_type: Variant) -> int:
		return amount

	func _record_damage_done(amount: int, damage_result: Dictionary, source_packet: Variant) -> void:
		last_damage_amount = amount
		last_damage_result = damage_result.duplicate(true)
		last_damage_packet = source_packet

	func _show_debug_damage_number(_amount: int, _damage_result: Dictionary) -> void:
		pass

	func _update_debug_health_display() -> void:
		pass

	func _get_damage_source_key(source_packet: Variant, damage_result: Dictionary) -> String:
		if source_packet is Dictionary:
			return String((source_packet as Dictionary).get("source_instance_id", damage_result.get("source_instance_id", "scene_check")))
		return "scene_check"

	func _die() -> void:
		_is_dead = true
```

- [ ] **Step 2: Add spawn helpers**

Insert before `_expect()`:

```gdscript
func _spawn_player(character_id: StringName, weapon_id: StringName) -> TestPlayer:
	var player: TestPlayer = TestPlayer.new()
	player.character_id = character_id
	player.selected_weapon_id = weapon_id
	player.name = "TestPlayer"
	player.add_to_group(&"player")
	root.add_child(player)
	return player

func _spawn_enemy(enemy_id: StringName, position: Vector2, max_hp: int = 18) -> TestEnemy:
	var enemy: TestEnemy = TestEnemy.new()
	enemy.enemy_id = enemy_id
	enemy.max_health = max_hp
	enemy.current_health = max_hp
	enemy.global_position = position
	enemy.name = "TestEnemy_%s_%d" % [String(enemy_id), root.get_child_count()]
	enemy.add_to_group(&"enemies")
	root.add_child(enemy)
	return enemy
```

- [ ] **Step 3: Run skeleton with actors**

Run:

```powershell
godot --headless --path . --script res://scripts/debug/weapon_combat_scene_check.gd
```

Expected: exit code `0`.

---

### Task 3: Add Branch Runtime State Builder

**Files:**
- Modify: `scripts/debug/weapon_combat_scene_check.gd`

- [ ] **Step 1: Add skill-instance double**

Insert below actor classes:

```gdscript
class TestSkillInstance:
	extends RefCounted

	var id: StringName = &"fireball"
	var current_level: int = 1
	var definition: Dictionary = {}
	var runtime_modifiers: Array = []
	var runtime_events: Array = []
	var runtime_tags: Array[StringName] = []
	var runtime_special_rules: Dictionary = {}

	func add_runtime_modifiers(modifiers: Array) -> void:
		runtime_modifiers.append_array(modifiers)

	func add_runtime_events(events: Array) -> void:
		runtime_events.append_array(events)

	func add_runtime_tags(tags: Array) -> void:
		for tag_variant: Variant in tags:
			runtime_tags.append(StringName(String(tag_variant)))

	func add_runtime_special_rules(rules: Dictionary) -> void:
		for key: Variant in rules.keys():
			runtime_special_rules[String(key)] = rules[key]
```

- [ ] **Step 2: Add JSON helpers and branch application**

Insert before spawn helpers:

```gdscript
func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _primary_attack(skill_id: StringName) -> Dictionary:
	for item: Variant in _load_json("res://data/primary_attack.json").get("primary_attacks", []):
		if item is Dictionary and StringName(String((item as Dictionary).get("id", ""))) == skill_id:
			return (item as Dictionary).duplicate(true)
	return {}

func _branch(branch_id: StringName) -> Dictionary:
	for item: Variant in _load_json("res://data/weapon_branches.json").get("branches", []):
		if item is Dictionary and StringName(String((item as Dictionary).get("id", ""))) == branch_id:
			return (item as Dictionary).duplicate(true)
	return {}

func _make_fireball_skill(branch_id: StringName, branch_level: int) -> TestSkillInstance:
	var skill: TestSkillInstance = TestSkillInstance.new()
	skill.id = &"fireball"
	skill.definition = _primary_attack(&"fireball")
	skill.current_level = branch_level
	var branch_data: Dictionary = _branch(branch_id)
	var level_path: Dictionary = branch_data.get("level_path", {})
	for level: int in range(2, branch_level + 1):
		var level_config: Dictionary = level_path.get(String(level), {})
		skill.add_runtime_modifiers(level_config.get("modifiers", []))
		skill.add_runtime_events(level_config.get("events_added", []))
		skill.add_runtime_tags(level_config.get("tags_added", []))
		skill.add_runtime_special_rules(level_config.get("special_rules", {}))
	return skill
```

- [ ] **Step 3: Add runtime state assertions**

Insert:

```gdscript
func _assert_skill_has_rule(skill: TestSkillInstance, rule_id: String, case_id: String) -> void:
	_expect(skill.runtime_special_rules.has(rule_id), "%s has special rule %s" % [case_id, rule_id], {
		"case": case_id,
		"expected": rule_id,
		"actual_rules": skill.runtime_special_rules.keys()
	})
```

- [ ] **Step 4: Run checker**

Run:

```powershell
godot --headless --path . --script res://scripts/debug/weapon_combat_scene_check.gd
```

Expected: exit code `0`.

---

### Task 4: Implement Soulburn Lv2 Small Slime Scene

**Files:**
- Modify: `scripts/debug/weapon_combat_scene_check.gd`

- [ ] **Step 1: Add event bus execution helper**

Insert constants:

```gdscript
const SkillEventBusScript: Script = preload("res://scripts/skills/skill_event_bus.gd")
```

Insert helper:

```gdscript
func _emit_projectile_hit(skill: TestSkillInstance, caster: TestPlayer, target: TestEnemy, trace_id: int) -> void:
	var event_bus: RefCounted = SkillEventBusScript.new()
	var context: Dictionary = {
		"caster": caster,
		"owner": caster,
		"target": target,
		"skill_instance": skill,
		"skill_id": skill.id,
		"source_weapon_id": caster.selected_weapon_id,
		"source_id": &"fireball_projectile",
		"source_type": "projectile",
		"source_instance_id": "%s:test:projectile" % String(skill.id),
		"target_group": &"enemies",
		"parent": root,
		"debug_attack_trace_id": trace_id
	}
	event_bus.call("emit_skill_event", &"on_projectile_hit", context)
```

- [ ] **Step 2: Add Case 1 runner**

Replace `_run()` body with:

```gdscript
func _run() -> void:
	root.set_meta("developer_mode_enabled", true)
	root.set_meta("debug_control_mode", true)
	_run_soulburn_lv2_small_slime()
	_write_result()
	quit(1 if _failed else 0)
```

Insert case:

```gdscript
func _run_soulburn_lv2_small_slime() -> void:
	var case_id: String = "mage_fire_staff_soulburn_lv2_small_slime_attack_once"
	var trace_id: int = DebugCombatTraceScript.begin_attack_trace(root)
	var player: TestPlayer = _spawn_player(&"mage", &"fire_staff")
	var target: TestEnemy = _spawn_enemy(&"small_slime", Vector2(160, 0), 18)
	var skill: TestSkillInstance = _make_fireball_skill(&"fire_staff_branch_soulburn", 2)
	_assert_skill_has_rule(skill, "soul_ember_on_direct_hit", case_id)

	_emit_projectile_hit(skill, player, target, trace_id)

	_expect(target.current_health == 2, "%s target HP after direct hit" % case_id, {
		"case": case_id,
		"expected": 2,
		"actual": target.current_health,
		"source": "data/primary_attack.json fireball.events.on_projectile_hit.deal_damage.amount"
	})
	_expect(target.last_damage_amount == 16, "%s direct hit final damage" % case_id, {
		"case": case_id,
		"expected": 16,
		"actual": target.last_damage_amount
	})
	_expect(target.get_status_stack(&"soul_ember") == 1, "%s soul_ember stacks" % case_id, {
		"case": case_id,
		"expected": 1,
		"actual": target.get_status_stack(&"soul_ember"),
		"source": "data/weapon_branches.json fire_staff_branch_soulburn.level_path.2.special_rules.soul_ember_on_direct_hit"
	})
	_expect(target.get_status_stack(&"burn") == 0, "%s no burn at Lv2" % case_id, {
		"case": case_id,
		"expected": 0,
		"actual": target.get_status_stack(&"burn")
	})
	_assert_damage_record(case_id, trace_id, {
		"source_skill_id": "fireball",
		"damage_origin": "primary_attack",
		"damage_type": "direct_magical",
		"element": "fire",
		"final_amount": 16
	})
```

- [ ] **Step 3: Add damage record assertion**

Insert:

```gdscript
func _assert_damage_record(case_id: String, trace_id: int, expected: Dictionary) -> void:
	var found: Dictionary = {}
	for record_variant: Variant in DebugCombatTraceScript.get_records(root):
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) == "damage" and int(record.get("trace_id", 0)) == trace_id:
			found = record
			break
	_expect(not found.is_empty(), "%s has damage trace" % case_id, {
		"case": case_id,
		"expected": "damage record",
		"actual": DebugCombatTraceScript.get_records(root)
	})
	if found.is_empty():
		return
	for key: Variant in expected.keys():
		_expect(str(found.get(key, "")) == str(expected[key]), "%s trace %s" % [case_id, String(key)], {
			"case": case_id,
			"expected": expected[key],
			"actual": found.get(key, null)
		})
```

- [ ] **Step 4: Run Case 1**

Run:

```powershell
godot --headless --path . --script res://scripts/debug/weapon_combat_scene_check.gd
```

Expected:

```text
[PASS] mage_fire_staff_soulburn_lv2_small_slime_attack_once has special rule soul_ember_on_direct_hit
[PASS] mage_fire_staff_soulburn_lv2_small_slime_attack_once target HP after direct hit
[PASS] mage_fire_staff_soulburn_lv2_small_slime_attack_once direct hit final damage
[PASS] mage_fire_staff_soulburn_lv2_small_slime_attack_once soul_ember stacks
[PASS] mage_fire_staff_soulburn_lv2_small_slime_attack_once no burn at Lv2
```

---

### Task 5: Implement Burst Fireball Lv2 Single-Slime Scene

**Files:**
- Modify: `scripts/debug/weapon_combat_scene_check.gd`

- [ ] **Step 1: Add Case 2A call**

In `_run()`, after `_run_soulburn_lv2_small_slime()`, add:

```gdscript
	_clear_scene_nodes()
	_run_burst_lv2_single_slime()
```

Insert helper:

```gdscript
func _clear_scene_nodes() -> void:
	for node: Node in root.get_children():
		if node is TestPlayer or node is TestEnemy:
			root.remove_child(node)
			node.queue_free()
	DebugCombatTraceScript.clear(root)
```

- [ ] **Step 2: Add Case 2A runner**

Insert:

```gdscript
func _run_burst_lv2_single_slime() -> void:
	var case_id: String = "mage_fire_staff_burst_lv2_single_slime_attack_once"
	var trace_id: int = DebugCombatTraceScript.begin_attack_trace(root)
	var player: TestPlayer = _spawn_player(&"mage", &"fire_staff")
	var target: TestEnemy = _spawn_enemy(&"small_slime", Vector2(160, 0), 18)
	var skill: TestSkillInstance = _make_fireball_skill(&"fire_staff_branch_burst", 2)
	_assert_skill_has_rule(skill, "explosion_multi_hit_burn", case_id)

	_emit_projectile_hit(skill, player, target, trace_id)

	_expect(target.last_damage_amount == 16, "%s direct hit final damage" % case_id, {
		"case": case_id,
		"expected": 16,
		"actual": target.last_damage_amount
	})
	_expect(target.get_status_stack(&"burn") == 0, "%s no burn below 3 explosion hits" % case_id, {
		"case": case_id,
		"expected": 0,
		"actual": target.get_status_stack(&"burn"),
		"source": "data/weapon_branches.json fire_staff_branch_burst.level_path.2.special_rules.explosion_multi_hit_burn"
	})
	_assert_explosion_record(case_id, trace_id, {
		"skill_id": "fireball",
		"radius_min": 94.2,
		"damage_origin": "reaction",
		"damage_type": "area_direct",
		"element": "fire"
	})
```

- [ ] **Step 3: Add explosion record assertion**

Insert:

```gdscript
func _assert_explosion_record(case_id: String, trace_id: int, expected: Dictionary) -> void:
	var found: Dictionary = {}
	for record_variant: Variant in DebugCombatTraceScript.get_records(root):
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) == "explosion" and int(record.get("trace_id", 0)) == trace_id:
			found = record
			break
	_expect(not found.is_empty(), "%s has explosion trace" % case_id, {
		"case": case_id,
		"expected": "explosion record",
		"actual": DebugCombatTraceScript.get_records(root)
	})
	if found.is_empty():
		return
	_expect(float(found.get("radius", 0.0)) >= float(expected.get("radius_min", 0.0)), "%s explosion radius" % case_id, {
		"case": case_id,
		"expected_min": expected.get("radius_min", 0.0),
		"actual": found.get("radius", 0.0)
	})
	var packet: Dictionary = found.get("damage_packet", {})
	for key: String in ["damage_origin", "damage_type", "element"]:
		_expect(str(packet.get(key, "")) == str(expected.get(key, "")), "%s explosion packet %s" % [case_id, key], {
			"case": case_id,
			"expected": expected.get(key, ""),
			"actual": packet.get(key, "")
		})
```

- [ ] **Step 4: Run Case 1 + Case 2A**

Run:

```powershell
godot --headless --path . --script res://scripts/debug/weapon_combat_scene_check.gd
```

Expected: all Case 1 and Case 2A assertions pass.

---

### Task 6: Implement Burst Fireball Lv2 Burn Threshold Scene

**Files:**
- Modify: `scripts/debug/weapon_combat_scene_check.gd`

- [ ] **Step 1: Add Case 2B call**

In `_run()`, after Case 2A:

```gdscript
	_clear_scene_nodes()
	_run_burst_lv2_three_slime_burn_threshold()
```

- [ ] **Step 2: Add Case 2B runner**

Insert:

```gdscript
func _run_burst_lv2_three_slime_burn_threshold() -> void:
	var case_id: String = "mage_fire_staff_burst_lv2_three_slime_burn_threshold"
	var trace_id: int = DebugCombatTraceScript.begin_attack_trace(root)
	var player: TestPlayer = _spawn_player(&"mage", &"fire_staff")
	var impact: TestEnemy = _spawn_enemy(&"small_slime", Vector2(160, 0), 999)
	var splash_a: TestEnemy = _spawn_enemy(&"small_slime", Vector2(184, 0), 999)
	var splash_b: TestEnemy = _spawn_enemy(&"small_slime", Vector2(208, 0), 999)
	var skill: TestSkillInstance = _make_fireball_skill(&"fire_staff_branch_burst", 2)

	_emit_projectile_hit(skill, player, impact, trace_id)

	_expect(impact.get_status_stack(&"burn") == 1, "%s impact burn stack" % case_id, {
		"case": case_id,
		"expected": 1,
		"actual": impact.get_status_stack(&"burn")
	})
	_expect(splash_a.get_status_stack(&"burn") == 1, "%s splash A burn stack" % case_id, {
		"case": case_id,
		"expected": 1,
		"actual": splash_a.get_status_stack(&"burn")
	})
	_expect(splash_b.get_status_stack(&"burn") == 1, "%s splash B burn stack" % case_id, {
		"case": case_id,
		"expected": 1,
		"actual": splash_b.get_status_stack(&"burn")
	})
```

- [ ] **Step 3: Run Case 2B**

Run:

```powershell
godot --headless --path . --script res://scripts/debug/weapon_combat_scene_check.gd
```

Expected: all three normal targets get `burn` x1.

---

### Task 7: Add Lv3 And Lv5 Soulburn Regression Scenes

**Files:**
- Modify: `scripts/debug/weapon_combat_scene_check.gd`

- [ ] **Step 1: Add Lv3 conversion case**

Add a case that creates `fire_staff_branch_soulburn` Lv3, emits two direct hits with cooldown time advanced or cooldown storage cleared, and asserts:

```text
soul_ember stack after first hit: 1
soul_ember stack after second valid hit: 0
burn stack after second valid hit: 1
second direct damage reflects -15% primary_attack modifier
```

The assertion source paths are:

```text
data/weapon_branches.json fire_staff_branch_soulburn.level_path.3.modifiers.damage=-0.15
data/weapon_branches.json fire_staff_branch_soulburn.level_path.3.special_rules.soul_ember_to_burn_on_full_stack_hit
```

- [ ] **Step 2: Add Lv5 full burn case**

Add a case that creates `fire_staff_branch_soulburn` Lv5, preloads `burn` x5 on `small_slime`, emits one direct hit, and asserts:

```text
burn stacks after hit: 0
soulburn burst trace exists
raw true-percent amount: 0.54
rule does not crit
rule does not use primary attack damage bonuses
```

The assertion source path is:

```text
data/weapon_branches.json fire_staff_branch_soulburn.level_path.5.special_rules.soulburn_burst_on_full_burn_direct_hit
```

- [ ] **Step 3: Run Lv3/Lv5 scenes**

Run:

```powershell
godot --headless --path . --script res://scripts/debug/weapon_combat_scene_check.gd
```

Expected: Case 1, Case 2A, Case 2B, Lv3, and Lv5 assertions pass.

---

### Task 8: Add Static + Runtime Batch Command Documentation

**Files:**
- Modify: `docs/archive/superpowers/specs/2026-06-18-main-gameplay-combat-test-design.md`
- Optional create: `reports/combat-scene-checks/README.md`

- [ ] **Step 1: Add final command set to spec**

Add this command block to the spec if it is missing:

```powershell
node tools\validate_weapon_authoring_pipeline.js
node tools\validate_branch_design_alignment.js
node tools\verify_fire_staff_branch_table.js
node tools\verify_soulburn_lv3_rule.js
node tools\verify_soulburn_lv4_rule.js
node tools\verify_soulburn_lv5_rule.js
godot --headless --path . --script res://scripts/debug/weapon_combat_scene_check.gd
godot --headless --path . --script res://scripts/debug/full_flow_autoplay.gd
```

- [ ] **Step 2: Run static gate**

Run:

```powershell
node tools\validate_weapon_authoring_pipeline.js
node tools\validate_branch_design_alignment.js
node tools\verify_fire_staff_branch_table.js
node tools\verify_soulburn_lv3_rule.js
node tools\verify_soulburn_lv4_rule.js
node tools\verify_soulburn_lv5_rule.js
```

Expected: every command exits `0`.

- [ ] **Step 3: Run runtime gate**

Run:

```powershell
godot --headless --path . --script res://scripts/debug/weapon_combat_scene_check.gd
```

Expected: exit `0` and report contains only `[PASS]` lines.

---

## Self-Review

Spec coverage:

- Fixed battlefield scenes: Task 4, Task 5, Task 6, Task 7.
- Damage assertions: Task 4 and Task 5.
- Status assertions: Task 4, Task 6, Task 7.
- Special rules: Task 3, Task 4, Task 5, Task 6, Task 7.
- Trace fields: Task 4 and Task 5.
- Static contract gate: Task 8.

No placeholders are intentionally left. The only conditional branch is the existing known Godot headless crash blocker; if it occurs, the runtime tests cannot execute and the blocker must be reported.
