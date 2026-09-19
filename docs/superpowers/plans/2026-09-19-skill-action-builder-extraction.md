# Skill Action Builder Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the approved deterministic projectile and instant-area parameter transformations from `SkillActionExecutor` into the existing Builder classes without changing runtime behavior or external interfaces.

**Architecture:** `SkillActionExecutor` remains the runtime facade and continues resolving modifiers, scene dependencies, cast identity, special rules, and side effects. `SkillActionProjectileBuilder` and `SkillActionAreaBuilder` receive explicit resolved inputs and return deterministic values; the executor retains its existing helper names as thin forwarding methods.

**Tech Stack:** Godot 4.6.3, typed GDScript, Node.js CommonJS validation scripts, PowerShell verification on Windows.

**Spec:** `docs/superpowers/specs/2026-09-19-skill-action-builder-extraction-design.md`

## Global Constraints

- Do not change gameplay rules, skill behavior, damage formulas, numerical balance, drops, UI, visuals, configuration IDs, JSON schemas, save data, signals, node paths, or public methods.
- Keep `SkillActionExecutor.execute_action(action: Dictionary, context: Dictionary) -> Variant` and its action dispatch unchanged.
- Builders must not access the SceneTree, autoloads, factories, pools, modifier services, skill metadata, or cast-ID generators.
- Keep all named executor compatibility helpers; turn them into delegates rather than deleting them.
- Do not move DamagePacket construction, modifier-backed stat resolution, special rules, metadata consumption, factory calls, or runtime node mutation.
- Implement each production change only after its focused test has been observed failing for the expected missing-interface or missing-delegation reason.
- Run Godot tests sequentially on this Windows host.
- Do not commit, push, merge, or create a PR unless the user explicitly authorizes that action for the implementation batch.

## File Structure

- Modify `scripts/skills/skill_action_projectile_builder.gd`: own the approved deterministic repeated-hit, status normalization, and resolved runtime-data transformations.
- Modify `scripts/skills/skill_action_area_builder.gd`: own instant-area visual-parameter merging.
- Modify `scripts/skills/skill_action_executor.gd`: retain runtime responsibilities and convert approved helper bodies to Builder delegates.
- Create `tools/verify/verify_skill_action_builder_pure_data.gd`: direct runtime behavior and non-mutation tests for both Builders.
- Create `tools/verify/verify_skill_action_builder_boundary.js`: architectural delegation contract for the executor/Builder boundary.
- Modify `package.json`: expose the new focused verifiers.
- Modify `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`: record the completed Stage 3 boundary without claiming a performance improvement.

## Review Focus

- A negative repeated-hit index must behave like the first hit: zero delay and no damage-only filtering; Task 1 tests `-1` explicitly.
- Nested `actions_on_hit` dictionaries must be deep-copied when filtered so mutation of the result cannot alter configuration input; Task 1 mutates the returned nested damage params and checks the source literal.
- Duplicate status IDs must preserve order and multiplicity rather than being deduplicated; Task 1 asserts `[burning, frozen, burning]` exactly.
- Runtime-data defaults must preserve exact types, including `StringName` and an empty typed status array; Task 1 checks values and `get_typed_builtin()`.
- Missing instant-area color keys in both action params and combat-object definition must remain absent rather than acquiring new defaults; Task 2 checks key absence.

---

### Task 1: Extract Projectile Pure Transformations

**Files:**
- Create: `tools/verify/verify_skill_action_builder_pure_data.gd`
- Create: `tools/verify/verify_skill_action_builder_boundary.js`
- Modify: `scripts/skills/skill_action_projectile_builder.gd`
- Modify: `scripts/skills/skill_action_executor.gd:466-524`
- Modify: `package.json`

**Interfaces:**
- Consumes: existing `SkillActionProjectileBuilder` static-method style and existing executor helpers `_same_target_projectile_spawn_delay`, `_projectile_params_for_same_target_hit`, `_damage_only_actions`, `_build_projectile_runtime_data`, and `_get_projectile_runtime_statuses_on_hit`.
- Produces: `resolve_same_target_spawn_delay(params: Dictionary, same_target_hit_index: int) -> float`, `build_same_target_hit_params(params: Dictionary, same_target_hit_index: int) -> Dictionary`, `filter_damage_actions(actions: Array) -> Array`, `normalize_status_ids(values: Array) -> Array[StringName]`, and `build_runtime_data(input: Dictionary) -> Dictionary`.

- [ ] **Step 1: Create the failing projectile behavior verifier**

Create `tools/verify/verify_skill_action_builder_pure_data.gd` with the projectile cases below. Each expected value is a hand-derived literal; no expected value is calculated through the Builder.

```gdscript
extends SceneTree


const ProjectileBuilderScript: Script = preload("res://scripts/skills/skill_action_projectile_builder.gd")
const AreaBuilderScript: Script = preload("res://scripts/skills/skill_action_area_builder.gd")


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_projectile_helpers()
	if not _failed:
		print("[verify_skill_action_builder_pure_data] PASS")
	quit(1 if _failed else 0)


func _verify_projectile_helpers() -> void:
	_expect_close(ProjectileBuilderScript.resolve_same_target_spawn_delay({"same_target_spawn_delay": 0.15}, -1), 0.0, "negative hit index has no delay")
	_expect_close(ProjectileBuilderScript.resolve_same_target_spawn_delay({"same_target_spawn_delay": 0.15}, 0), 0.0, "first hit has no delay")
	_expect_close(ProjectileBuilderScript.resolve_same_target_spawn_delay({"same_target_spawn_delay": 0.15}, 2), 0.3, "later hit delay scales by index")
	_expect_close(ProjectileBuilderScript.resolve_same_target_spawn_delay({"same_target_spawn_delay": -0.25}, 3), 0.0, "negative configured delay clamps to zero")

	var unchanged: Dictionary = {"same_target_repeat_damage_only": false, "actions_on_hit": [{"type": "apply_status"}]}
	var unchanged_result: Dictionary = ProjectileBuilderScript.build_same_target_hit_params(unchanged, 2)
	_expect(is_same(unchanged_result, unchanged), "disabled filtering preserves the original dictionary")
	_expect(is_same(ProjectileBuilderScript.build_same_target_hit_params(unchanged, -1), unchanged), "negative index preserves the original dictionary")

	var source: Dictionary = {
		"same_target_repeat_damage_only": true,
		"actions_on_hit": [
			{"type": "deal_damage", "params": {"damage": 12}},
			{"type": "apply_status", "params": {"status_id": "burning"}},
			"invalid",
			{"type": "deal_damage", "params": {"damage": 7}},
		]
	}
	var filtered: Dictionary = ProjectileBuilderScript.build_same_target_hit_params(source, 1)
	var filtered_actions: Array = filtered.get("actions_on_hit", [])
	_expect(not is_same(filtered, source), "enabled filtering returns a new dictionary")
	_expect(filtered_actions.size() == 2, "enabled filtering keeps only damage actions", filtered_actions)
	_expect(str((filtered_actions[0] as Dictionary).get("type", "")) == "deal_damage", "first retained action is damage", filtered_actions)
	_expect(str((filtered_actions[1] as Dictionary).get("type", "")) == "deal_damage", "second retained action is damage", filtered_actions)
	var returned_damage_action: Dictionary = filtered_actions[0] as Dictionary
	var returned_damage_params: Dictionary = returned_damage_action.get("params", {}) as Dictionary
	returned_damage_params["damage"] = 99
	_expect(int(((source["actions_on_hit"][0] as Dictionary)["params"] as Dictionary)["damage"]) == 12, "filtered actions are deep copies", source)
	_expect((source["actions_on_hit"] as Array).size() == 4, "filtering does not mutate the source array", source)

	var statuses: Array[StringName] = ProjectileBuilderScript.normalize_status_ids(["burning", &"frozen", "burning"])
	_expect(statuses == [&"burning", &"frozen", &"burning"], "status normalization preserves order and duplicates", statuses)
	_expect(statuses.get_typed_builtin() == TYPE_STRING_NAME, "status normalization returns a typed StringName array", statuses.get_typed_builtin())
	var empty_statuses: Array[StringName] = ProjectileBuilderScript.normalize_status_ids([])
	_expect(empty_statuses.is_empty(), "empty status normalization remains empty", empty_statuses)
	_expect(empty_statuses.get_typed_builtin() == TYPE_STRING_NAME, "empty status normalization remains typed", empty_statuses.get_typed_builtin())

	var parent: Node = Node.new()
	var runtime_data: Dictionary = ProjectileBuilderScript.build_runtime_data({
		"speed": 510.0,
		"pierce": 3,
		"radius": 14.0,
		"lifetime": 4.5,
		"damage": 27,
		"source_id": &"test_projectile",
		"statuses_on_hit": ["burning", &"frozen"],
		"parent": parent,
		"cast_instance_id": "cast-17",
	})
	_expect(runtime_data.size() == 9, "runtime data exposes exactly nine fields", runtime_data)
	_expect_close(float(runtime_data.get("speed", 0.0)), 510.0, "runtime speed is preserved")
	_expect(int(runtime_data.get("pierce", -1)) == 3, "runtime pierce is preserved", runtime_data)
	_expect_close(float(runtime_data.get("radius", 0.0)), 14.0, "runtime radius is preserved")
	_expect_close(float(runtime_data.get("lifetime", 0.0)), 4.5, "runtime lifetime is preserved")
	_expect(int(runtime_data.get("damage", -1)) == 27, "runtime damage is preserved", runtime_data)
	_expect(runtime_data.get("source_id") is StringName and runtime_data.get("source_id") == &"test_projectile", "runtime source id is a StringName", runtime_data)
	_expect(runtime_data.get("parent") == parent, "runtime parent is preserved", runtime_data)
	_expect(str(runtime_data.get("cast_instance_id", "")) == "cast-17", "runtime cast id is preserved", runtime_data)
	var runtime_statuses: Array = runtime_data.get("statuses_on_hit", [])
	_expect(runtime_statuses == [&"burning", &"frozen"], "runtime statuses are normalized", runtime_statuses)

	var defaults: Dictionary = ProjectileBuilderScript.build_runtime_data({})
	_expect(defaults.size() == 9, "runtime defaults expose exactly nine fields", defaults)
	_expect_close(float(defaults.get("speed", 0.0)), 420.0, "default speed is unchanged")
	_expect(int(defaults.get("pierce", -1)) == 0, "default pierce is unchanged", defaults)
	_expect_close(float(defaults.get("radius", 0.0)), 10.0, "default radius is unchanged")
	_expect_close(float(defaults.get("lifetime", 0.0)), 2.0, "default lifetime is unchanged")
	_expect(int(defaults.get("damage", -1)) == 0, "default damage is unchanged", defaults)
	_expect(defaults.get("source_id") is StringName and defaults.get("source_id") == &"", "default source id is an empty StringName", defaults)
	_expect(defaults.get("parent") == null, "default parent is null", defaults)
	_expect(str(defaults.get("cast_instance_id", "missing")) == "", "default cast id is empty", defaults)
	var default_statuses: Array = defaults.get("statuses_on_hit", [])
	_expect(default_statuses.is_empty() and default_statuses.get_typed_builtin() == TYPE_STRING_NAME, "default statuses are an empty typed array", default_statuses)
	parent.free()


func _expect_close(actual: float, expected: float, label: String) -> void:
	_expect(is_equal_approx(actual, expected), label, actual)


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_skill_action_builder_pure_data] FAIL %s actual=%s" % [label, str(actual)])
```

- [ ] **Step 2: Create the failing projectile boundary contract**

Create `tools/verify/verify_skill_action_builder_boundary.js` using the project `readTextFile` helper. It verifies interfaces and delegation without matching exact formatting.

```javascript
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const projectileBuilder = readTextFile(path.join(root, "scripts", "skills", "skill_action_projectile_builder.gd"));
const areaBuilder = readTextFile(path.join(root, "scripts", "skills", "skill_action_area_builder.gd"));
const executor = readTextFile(path.join(root, "scripts", "skills", "skill_action_executor.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name) {
  const start = source.indexOf(`func ${name}`);
  if (start < 0) return "";
  const next = source.indexOf("\nfunc ", start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

function staticFunctionBody(source, name) {
  const start = source.indexOf(`static func ${name}`);
  if (start < 0) return "";
  const next = source.indexOf("\nstatic func ", start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

for (const method of [
  "resolve_same_target_spawn_delay",
  "build_same_target_hit_params",
  "filter_damage_actions",
  "normalize_status_ids",
  "build_runtime_data",
]) {
  assert(staticFunctionBody(projectileBuilder, method) !== "", `SkillActionProjectileBuilder.${method} must exist.`);
}

const projectileDelegates = new Map([
  ["_same_target_projectile_spawn_delay", "resolve_same_target_spawn_delay"],
  ["_projectile_params_for_same_target_hit", "build_same_target_hit_params"],
  ["_damage_only_actions", "filter_damage_actions"],
  ["_build_projectile_runtime_data", "build_runtime_data"],
  ["_get_projectile_runtime_statuses_on_hit", "normalize_status_ids"],
]);

for (const [executorMethod, builderMethod] of projectileDelegates) {
  const body = functionBody(executor, executorMethod);
  assert(body !== "", `SkillActionExecutor.${executorMethod} must remain as a compatibility helper.`);
  assert(body.includes(`SkillActionProjectileBuilderScript.${builderMethod}`), `${executorMethod} must delegate to ${builderMethod}.`);
}

const executeAction = functionBody(executor, "execute_action");
assert(executeAction.includes('"spawn_projectile"'), "execute_action must retain spawn_projectile dispatch.");
assert(executeAction.includes('"spawn_projectiles_at_targets"'), "execute_action must retain spawn_projectiles_at_targets dispatch.");
assert(executeAction.includes('"spawn_area"'), "execute_action must retain spawn_area dispatch.");
assert(executeAction.includes('"instant_area_hit"'), "execute_action must retain instant_area_hit dispatch.");

console.log("[verify_skill_action_builder_boundary] PASS");
```

- [ ] **Step 3: Add package scripts and run both tests to observe RED**

Add these entries to `package.json`:

```json
"verify:skill-action-builder-pure-data": "D:\\Godot\\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_skill_action_builder_pure_data.gd",
"verify:skill-action-builder-boundary": "node tools\\verify\\verify_skill_action_builder_boundary.js"
```

Run sequentially:

```powershell
npm run verify:skill-action-builder-boundary
npm run verify:skill-action-builder-pure-data
```

Expected:

- boundary verifier exits non-zero because `SkillActionProjectileBuilder.resolve_same_target_spawn_delay` does not exist;
- Godot verifier exits non-zero because the new projectile Builder interface does not exist;
- neither failure may be caused by a path typo or malformed test file.

- [ ] **Step 4: Implement the five projectile Builder methods**

Append the following public static methods before the private conversion helpers in `skill_action_projectile_builder.gd`:

```gdscript
static func resolve_same_target_spawn_delay(params: Dictionary, same_target_hit_index: int) -> float:
	if same_target_hit_index <= 0:
		return 0.0
	return maxf(float(params.get("same_target_spawn_delay", 0.0)), 0.0) * float(same_target_hit_index)


static func build_same_target_hit_params(params: Dictionary, same_target_hit_index: int) -> Dictionary:
	if same_target_hit_index <= 0 or not bool(params.get("same_target_repeat_damage_only", false)):
		return params
	var adjusted: Dictionary = params.duplicate(true)
	adjusted["actions_on_hit"] = filter_damage_actions(_get_array(params.get("actions_on_hit", [])))
	return adjusted


static func filter_damage_actions(actions: Array) -> Array:
	var adjusted: Array = []
	for action_variant: Variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		if str(action.get("type", "")) == "deal_damage":
			adjusted.append(action.duplicate(true))
	return adjusted


static func normalize_status_ids(values: Array) -> Array[StringName]:
	var statuses: Array[StringName] = []
	for value: Variant in values:
		statuses.append(StringName(str(value)))
	return statuses


static func build_runtime_data(input: Dictionary) -> Dictionary:
	return {
		"speed": float(input.get("speed", 420.0)),
		"pierce": int(input.get("pierce", 0)),
		"radius": float(input.get("radius", 10.0)),
		"lifetime": float(input.get("lifetime", 2.0)),
		"damage": int(input.get("damage", 0)),
		"source_id": StringName(str(input.get("source_id", &""))),
		"statuses_on_hit": normalize_status_ids(_get_array(input.get("statuses_on_hit", []))),
		"parent": input.get("parent"),
		"cast_instance_id": str(input.get("cast_instance_id", "")),
	}
```

- [ ] **Step 5: Convert the executor projectile helpers to delegates**

Replace only the five approved helper bodies in `skill_action_executor.gd`:

```gdscript
func _same_target_projectile_spawn_delay(params: Dictionary, same_target_hit_index: int) -> float:
	return SkillActionProjectileBuilderScript.resolve_same_target_spawn_delay(params, same_target_hit_index)


func _projectile_params_for_same_target_hit(params: Dictionary, same_target_hit_index: int) -> Dictionary:
	return SkillActionProjectileBuilderScript.build_same_target_hit_params(params, same_target_hit_index)


func _damage_only_actions(actions: Array) -> Array:
	return SkillActionProjectileBuilderScript.filter_damage_actions(actions)


func _build_projectile_runtime_data(projectile_stats: Dictionary, params: Dictionary, context: Dictionary) -> Dictionary:
	return SkillActionProjectileBuilderScript.build_runtime_data({
		"speed": projectile_stats.get("speed", 420.0),
		"pierce": projectile_stats.get("pierce", 0),
		"radius": projectile_stats.get("radius", 10.0),
		"lifetime": projectile_stats.get("lifetime", 2.0),
		"damage": projectile_stats.get("damage", 0),
		"source_id": projectile_stats.get("source_id", &""),
		"statuses_on_hit": _get_statuses_on_hit(params, context),
		"parent": _get_parent_node(context),
		"cast_instance_id": _next_cast_instance_id(context),
	})


func _get_projectile_runtime_statuses_on_hit(runtime_data: Dictionary) -> Array[StringName]:
	return SkillActionProjectileBuilderScript.normalize_status_ids(_get_array(runtime_data.get("statuses_on_hit", [])))
```

Do not change `_resolve_projectile_runtime_stats()`, projectile factory calls, damage packets, cast identity, parent lookup, or any call site.

- [ ] **Step 6: Run the focused tests to verify GREEN**

Run sequentially:

```powershell
npm run verify:skill-action-builder-boundary
npm run verify:skill-action-builder-pure-data
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/skills/skill_action_projectile_builder.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/skills/skill_action_executor.gd
```

Expected: every command exits `0`; the two new verifiers print `PASS`; parse checks emit no errors.

- [ ] **Step 7: Run projectile regression checks**

Run sequentially:

```powershell
npm run verify:skill-retarget-dead-target
npm run verify:offscreen-target-filter
npm run verify:projectile-physics-flush-safe
npm run verify:curved-projectile-spawn-angles
npm run verify:homing-projectile-swept-hit
npm run verify:projectile-factory-physics-frame
```

Expected: all six commands exit `0` and report `PASS` or their existing success message.

- [ ] **Step 8: Audit Task 1 diff**

Run:

```powershell
git diff --check
git diff -- scripts/skills/skill_action_projectile_builder.gd scripts/skills/skill_action_executor.gd tools/verify/verify_skill_action_builder_pure_data.gd tools/verify/verify_skill_action_builder_boundary.js package.json
```

Confirm no unrelated executor method, numerical literal, action dispatch case, resource, configuration, or formatting block changed.

- [ ] **Step 9: Commit only if explicitly authorized**

Suggested command after user authorization:

```powershell
git add package.json scripts/skills/skill_action_projectile_builder.gd scripts/skills/skill_action_executor.gd tools/verify/verify_skill_action_builder_pure_data.gd tools/verify/verify_skill_action_builder_boundary.js
git commit -m "refactor: extract projectile action builder data"
```

Without explicit authorization, leave Task 1 verified and uncommitted.

---

### Task 2: Extract Instant-Area Visual Parameter Merging

**Files:**
- Modify: `tools/verify/verify_skill_action_builder_pure_data.gd`
- Modify: `tools/verify/verify_skill_action_builder_boundary.js`
- Modify: `scripts/skills/skill_action_area_builder.gd`
- Modify: `scripts/skills/skill_action_executor.gd:662-674`

**Interfaces:**
- Consumes: Task 1 verifiers and the existing executor `_instant_area_hit_visual_params(params, area_source_id, radius)` compatibility method.
- Produces: `SkillActionAreaBuilder.build_instant_hit_visual_params(params: Dictionary, definition: Dictionary, radius: float) -> Dictionary`.

- [ ] **Step 1: Extend the behavior verifier with failing area cases**

Add `_verify_area_visual_params()` to `verify_skill_action_builder_pure_data.gd` and call it from `_run()` after `_verify_projectile_helpers()`:

```gdscript
func _verify_area_visual_params() -> void:
	var explicit_params: Dictionary = {
		"visual_duration": 0.35,
		"duration": 9.0,
		"visual_color": Color(0.9, 0.2, 0.1, 0.8),
	}
	var definition: Dictionary = {
		"visual_color": Color(0.1, 0.2, 0.9, 0.5),
		"visual_ring_color": Color(0.3, 0.8, 1.0, 0.9),
	}
	var explicit_result: Dictionary = AreaBuilderScript.build_instant_hit_visual_params(explicit_params, definition, 72.0)
	_expect_close(float(explicit_result.get("radius", 0.0)), 72.0, "instant visual radius is preserved")
	_expect_close(float(explicit_result.get("duration", 0.0)), 0.35, "visual_duration takes precedence over duration")
	_expect(explicit_result.get("visual_color") == Color(0.9, 0.2, 0.1, 0.8), "explicit visual color wins", explicit_result)
	_expect(explicit_result.get("visual_ring_color") == Color(0.3, 0.8, 1.0, 0.9), "definition supplies missing ring color", explicit_result)
	_expect(explicit_params.size() == 3 and definition.size() == 2, "visual merge does not mutate either input", [explicit_params, definition])

	var fallback_result: Dictionary = AreaBuilderScript.build_instant_hit_visual_params({"duration": 0.6}, definition, 48.0)
	_expect_close(float(fallback_result.get("duration", 0.0)), 0.6, "duration is the visual-duration fallback")
	_expect(fallback_result.get("visual_color") == Color(0.1, 0.2, 0.9, 0.5), "definition supplies visual color", fallback_result)

	var minimal_result: Dictionary = AreaBuilderScript.build_instant_hit_visual_params({}, {}, 36.0)
	_expect(minimal_result.size() == 2, "missing optional colors remain absent", minimal_result)
	_expect_close(float(minimal_result.get("duration", 0.0)), 0.12, "default visual duration is unchanged")
	_expect(not minimal_result.has("visual_color") and not minimal_result.has("visual_ring_color"), "minimal result does not invent color keys", minimal_result)
```

Production mutation caught: reversing precedence, losing definition fallback, adding default colors, changing duration defaults, or mutating source dictionaries.

- [ ] **Step 2: Extend the boundary contract with the area delegation and observe RED**

Add to `verify_skill_action_builder_boundary.js` before its final `console.log`:

```javascript
assert(
  staticFunctionBody(areaBuilder, "build_instant_hit_visual_params") !== "",
  "SkillActionAreaBuilder.build_instant_hit_visual_params must exist.",
);

const instantVisual = functionBody(executor, "_instant_area_hit_visual_params");
assert(instantVisual !== "", "SkillActionExecutor._instant_area_hit_visual_params must remain as a compatibility helper.");
assert(
  instantVisual.includes("SkillActionAreaBuilderScript.build_instant_hit_visual_params"),
  "_instant_area_hit_visual_params must delegate to SkillActionAreaBuilder.",
);
```

Run sequentially:

```powershell
npm run verify:skill-action-builder-boundary
npm run verify:skill-action-builder-pure-data
```

Expected:

- boundary verifier exits non-zero because `build_instant_hit_visual_params` does not exist;
- Godot verifier exits non-zero for the same missing interface;
- existing projectile assertions remain green up to the area failure.

- [ ] **Step 3: Implement the area Builder method**

Add to `skill_action_area_builder.gd` before its private conversion helpers:

```gdscript
static func build_instant_hit_visual_params(params: Dictionary, definition: Dictionary, radius: float) -> Dictionary:
	var visual_params: Dictionary = {
		"radius": radius,
		"duration": float(params.get("visual_duration", params.get("duration", 0.12))),
	}
	for key: String in ["visual_color", "visual_ring_color"]:
		if params.has(key):
			visual_params[key] = params[key]
		elif definition.has(key):
			visual_params[key] = definition[key]
	return visual_params
```

- [ ] **Step 4: Convert the executor visual helper to a delegate**

Replace only `_instant_area_hit_visual_params()`:

```gdscript
func _instant_area_hit_visual_params(params: Dictionary, area_source_id: StringName, radius: float) -> Dictionary:
	return SkillActionAreaBuilderScript.build_instant_hit_visual_params(
		params,
		_get_combat_object_definition(area_source_id),
		radius
	)
```

Keep `_get_combat_object_definition()`, `_play_instant_area_hit_visual()`, pool use, metadata assignment, and visual setup unchanged.

- [ ] **Step 5: Run focused tests and parse checks to verify GREEN**

Run sequentially:

```powershell
npm run verify:skill-action-builder-boundary
npm run verify:skill-action-builder-pure-data
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/skills/skill_action_area_builder.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/skills/skill_action_executor.gd
```

Expected: every command exits `0`; both focused verifiers report `PASS`; parse checks emit no errors.

- [ ] **Step 6: Run area regression checks**

Run sequentially:

```powershell
npm run verify:dash-area-path-filter
npm run verify:area-effect-motion
npm run verify:area-effect-max-targets
npm run verify:area-effect-visual-mode
npm run verify:area-effect-visual-mode-runtime
npm run verify:fire-tornado-effect-runtime
npm run verify:mars-spark-missile-effect-runtime
```

Expected: all seven commands exit `0` and report their existing success messages.

- [ ] **Step 7: Audit Task 2 diff**

Run:

```powershell
git diff --check
git diff -- scripts/skills/skill_action_area_builder.gd scripts/skills/skill_action_executor.gd tools/verify/verify_skill_action_builder_pure_data.gd tools/verify/verify_skill_action_builder_boundary.js
```

Confirm the executor still owns DataManager lookup and all runtime side effects, and that no other area resolver moved.

- [ ] **Step 8: Commit only if explicitly authorized**

Suggested command after user authorization:

```powershell
git add scripts/skills/skill_action_area_builder.gd scripts/skills/skill_action_executor.gd tools/verify/verify_skill_action_builder_pure_data.gd tools/verify/verify_skill_action_builder_boundary.js
git commit -m "refactor: extract instant area visual parameters"
```

Without explicit authorization, leave Task 2 verified and uncommitted.

---

### Task 3: Document the Boundary and Run Full Regression

**Files:**
- Modify: `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md:112-129`
- Verify: all Stage 3 production and test files from Tasks 1–2

**Interfaces:**
- Consumes: the five projectile Builder methods and one area Builder method implemented in Tasks 1–2.
- Produces: a documented stable boundary and complete verification evidence for the Stage 3 batch.

- [ ] **Step 1: Update the stability report without changing roadmap scope**

In `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`, update the `SkillActionExecutor` recommendation and safe-change notes to state:

```markdown
- Stage 3 has moved deterministic repeated-projectile, resolved runtime-data, status-normalization, and instant-area visual-parameter transformations into the existing projectile/area Builders.
- `SkillActionExecutor` still owns action dispatch, modifier resolution, special rules, damage packets, runtime identity, factory calls, and side effects.
- Future action-family extraction remains deferred and requires separate behavior coverage.
```

Do not claim fewer allocations, faster frames, or any other unmeasured performance result.

- [ ] **Step 2: Run encoding, package, and focused Stage 3 checks**

Run:

```powershell
node --check tools/verify/verify_skill_action_builder_boundary.js
node tools/validate/check_text_encoding.js
npm run verify:skill-action-builder-boundary
npm run verify:skill-action-builder-pure-data
```

Expected: Node syntax exits `0`; encoding reports every text file valid UTF-8; both Stage 3 verifiers report `PASS`.

- [ ] **Step 3: Run the Stage 1 static baseline**

Run these nine commands; they may execute in parallel because they are read-only Node validators:

```powershell
npm run verify:skill-retarget-dead-target
npm run verify:offscreen-target-filter
npm run verify:skill-definition-schema
npm run verify:enemy-motion-neighbor-limit
node tools/verify/verify_pr1_ui_churn_contract.js
node tools/verify/verify_pr2_runtime_pool_contract.js
node tools/verify/verify_pr3_combat_scene_pool_contract.js
node tools/verify/verify_pr4_pickup_pool_contract.js
node tools/verify/verify_pr5_status_tick_observability_contract.js
```

Expected: `9/9 PASS`.

- [ ] **Step 4: Run the complete 11-test Godot baseline sequentially**

Run each command in this order and stop on the first failure:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_homing_projectile_swept_hit.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_mars_spark_missile_effect_runtime.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_crimson_dragon_summon_behavior.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_summon_system_behavior.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_fire_skill_runtime_smoke.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_frost_skill_runtime_smoke.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_thunder_skill_runtime_smoke.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_curse_skill_runtime_smoke.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_holy_skill_runtime_smoke.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_fusion_skill_runtime_smoke.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_player_dash.gd
```

Expected: `11/11 PASS` with no new warnings or engine errors.

- [ ] **Step 5: Run final parse, startup, and diff checks**

Run sequentially:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/skills/skill_action_projectile_builder.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/skills/skill_action_area_builder.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/skills/skill_action_executor.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --quit
git diff --check
git status --short
git diff --stat origin/main
git diff --name-only origin/main
```

Expected:

- all three scripts parse;
- project startup exits `0` without new errors;
- `git diff --check` prints nothing;
- changed files are limited to the approved Stage 3 spec, plan, Builders, executor delegates, focused verifiers, package scripts, and stability report.

- [ ] **Step 6: Perform the final whole-branch review**

Review against the specification and these failure classes:

1. changed defaults or types in runtime dictionaries;
2. shallow copies that allow nested input mutation;
3. moved runtime dependencies or side effects entering a Builder;
4. deleted/renamed compatibility helpers or action dispatch cases;
5. unrelated numerical, configuration, resource, UI, or formatting changes.

Critical or Important findings require one TDD fix pass followed by the complete suite. Minor findings are recorded and deferred rather than expanded into this batch.

- [ ] **Step 7: Commit documentation and any remaining verified implementation only if explicitly authorized**

If Tasks 1–2 were intentionally left uncommitted and the user now authorizes one complete Stage 3 commit, use:

```powershell
git add docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md docs/superpowers/plans/2026-09-19-skill-action-builder-extraction.md package.json scripts/skills/skill_action_projectile_builder.gd scripts/skills/skill_action_area_builder.gd scripts/skills/skill_action_executor.gd tools/verify/verify_skill_action_builder_pure_data.gd tools/verify/verify_skill_action_builder_boundary.js
git commit -m "refactor: extract skill action builder data"
```

If Tasks 1–2 already have authorized commits, commit only the report and plan:

```powershell
git add docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md docs/superpowers/plans/2026-09-19-skill-action-builder-extraction.md
git commit -m "docs: record stage 3 action builder boundary"
```

Do not push or create a PR without separate user authorization.
