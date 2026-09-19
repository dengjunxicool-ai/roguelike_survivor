# Dev Debug Effects Page Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the complete developer Effects page from `DevDebugPanel` into a focused `DevDebugEffectsPage` component without changing its UI, VFX behavior, logging, or compatibility entry points.

**Architecture:** `DevDebugPanel` remains the developer-toolbar shell and compatibility facade. A new `VBoxContainer` page owns the Effect dropdown, both buttons, option data, scene resources, dispatch, spawning, and position calculations; it receives player/enemy lookup callables and reports messages through a signal.

**Tech Stack:** Godot 4.6, GDScript, Node.js static contract verification, Godot headless runtime verification.

**Spec:** `docs/superpowers/specs/2026-09-19-dev-debug-effects-page-design.md`

## Global Constraints

- Do not change gameplay, combat state, damage, skills, enemy behavior, saves, configuration schemas, production UI, or VFX resources.
- Preserve category ID `effects`, title `Effects`, label `Effect`, button text `持续发射` and `单次发射`, and button width `116`.
- Preserve option IDs `fire_tornado` and `mars_spark_missile` and their current labels.
- Preserve Fire Tornado and Mars Spark Missile scenes, spawn positions, parent preference, continuous/single mode, and log messages.
- Keep all existing `DevDebugPanel` compatibility methods as thin delegates in this batch.
- Do not create a generic page framework or change any other Debug page.
- Do not overwrite or reformat Stage 1 changes already present in the worktree.
- Do not commit, push, or create a PR without explicit user authorization.

## Review Focus

- Repeated `build()` or `populate_options()` calls must not duplicate controls, options, or signal connections; Task 1 runtime verification exercises both calls twice.
- Invalid lookup callables must not crash; Task 1 triggers an effect with invalid callables and asserts a warning.
- A player with no parent and no current scene must not leak the newly instantiated effect; Task 1 asserts an error and no retained effect node.
- An unknown selected option ID must not spawn anything; Task 1 replaces selected metadata and asserts a warning.
- Continuous and single Mars modes must remain distinguishable; Task 1 presses both real buttons and inspects the spawned effect's `_continuous` state.

---

## File Structure

- Create `scripts/debug/pages/dev_debug_effects_page.gd`
  - Owns the complete Effects page content, option state, scene dependencies, dispatch, spawning, and position calculation.
- Modify `scripts/debug/dev_debug_panel.gd`
  - Mounts the page, supplies lookup callables, forwards logs, maintains `_effect_option`, and retains thin compatibility delegates.
- Create `tools/verify/verify_dev_debug_effects_page_boundary.js`
  - Guards page ownership and Panel delegation without depending on implementation line numbers.
- Create `tools/verify/verify_dev_debug_effects_page.gd`
  - Exercises layout idempotence, option identity, dispatch modes, spawn positions, and failure paths in Godot headless mode.
- Modify `tools/verify/verify_dev_effects_panel_vfx.js`
  - Follows implementation ownership from the Panel facade into the new page.
- Modify `tools/verify/verify_fire_tornado_debug_vfx.js`
  - Verifies Fire Tornado scene ownership and spawn-position logic in the new page while keeping the Panel delegate contract.
- Modify `package.json`
  - Adds named static and runtime verification commands for the new boundary.

---

### Task 1: Add RED Boundary And Runtime Verification

**Files:**
- Create: `tools/verify/verify_dev_debug_effects_page_boundary.js`
- Create: `tools/verify/verify_dev_debug_effects_page.gd`
- Modify: `package.json`

**Interfaces:**
- Consumes: the approved interface in `docs/superpowers/specs/2026-09-19-dev-debug-effects-page-design.md`.
- Produces: `verify:dev-debug-effects-page-boundary` and `verify:dev-debug-effects-page-runtime` commands that Task 2 must make pass.

- [ ] **Step 1: Write the static boundary verifier**

Create `tools/verify/verify_dev_debug_effects_page_boundary.js` with these exact ownership checks:

```javascript
const fs = require("fs");
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const pagePath = path.join(root, "scripts", "debug", "pages", "dev_debug_effects_page.gd");
const panelPath = path.join(root, "scripts", "debug", "dev_debug_panel.gd");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function read(filePath) {
  return readTextFile(filePath);
}

function functionBody(source, name) {
  const start = source.indexOf(`func ${name}`);
  if (start < 0) return "";
  const next = source.indexOf("\nfunc ", start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

assert(fs.existsSync(pagePath), "DevDebugEffectsPage script must exist.");

const page = read(pagePath);
const panel = read(panelPath);

assert(page.includes("extends VBoxContainer"), "DevDebugEffectsPage must be a VBoxContainer.");
assert(page.includes("class_name DevDebugEffectsPage"), "DevDebugEffectsPage must declare its class name.");
assert(page.includes("signal log_requested(level: StringName, message: String)"), "Effects page must expose structured logging.");
assert(page.includes('preload("res://scenes/effects/fire_tornado_effect.tscn")'), "Effects page must own the Fire Tornado scene.");
assert(page.includes('preload("res://scenes/effects/mars_spark_missile_effect.tscn")'), "Effects page must own the Mars Spark Missile scene.");

for (const method of [
  "setup",
  "build",
  "populate_options",
  "start_continuous_effect",
  "fire_single_effect",
  "trigger_selected_effect",
  "spawn_fire_tornado_effect",
  "spawn_mars_spark_missile_effect",
  "resolve_fire_tornado_spawn_position",
  "resolve_mars_spark_missile_spawn_position",
  "resolve_mars_spark_missile_target_position",
  "get_effect_option",
]) {
  assert(functionBody(page, method) !== "", `DevDebugEffectsPage.${method} must exist.`);
}

assert(panel.includes('preload("res://scripts/debug/pages/dev_debug_effects_page.gd")'), "DevDebugPanel must preload the Effects page.");
assert(/var\s+_effects_page\s*:\s*VBoxContainer/.test(panel), "DevDebugPanel must retain the mounted Effects page.");
assert(/var\s+_effect_option\s*:\s*OptionButton/.test(panel), "DevDebugPanel must retain the effect-option compatibility alias.");

const buildPage = functionBody(panel, "_build_effects_page");
assert(buildPage.includes('DevDebugEffectsPageScript.new()'), "DevDebugPanel must instantiate DevDebugEffectsPage.");
assert(buildPage.includes('_add_category_page(page_root, "effects", "Effects")'), "Panel shell must retain the Effects category wrapper.");
assert(buildPage.includes('Callable(self, "_get_player")'), "Effects page must receive the existing player lookup.");
assert(buildPage.includes('Callable(self, "_get_nearest_enemy")'), "Effects page must receive the existing nearest-enemy lookup.");
assert(buildPage.includes('get_effect_option'), "Panel must assign its compatibility option alias from the page.");

const delegates = new Map([
  ["_populate_effect_options", "populate_options"],
  ["_start_continuous_effect_fire", "start_continuous_effect"],
  ["_fire_single_effect", "fire_single_effect"],
  ["_trigger_selected_effect", "trigger_selected_effect"],
  ["_spawn_fire_tornado_effect", "spawn_fire_tornado_effect"],
  ["_spawn_mars_spark_missile_effect", "spawn_mars_spark_missile_effect"],
  ["_resolve_fire_tornado_spawn_position", "resolve_fire_tornado_spawn_position"],
  ["_resolve_mars_spark_missile_spawn_position", "resolve_mars_spark_missile_spawn_position"],
  ["_resolve_mars_spark_missile_target_position", "resolve_mars_spark_missile_target_position"],
]);

for (const [panelMethod, pageMethod] of delegates) {
  const body = functionBody(panel, panelMethod);
  assert(body.includes(`_effects_page.call("${pageMethod}"`), `${panelMethod} must delegate to ${pageMethod}.`);
}

assert(!panel.includes("FIRE_TORNADO_EFFECT_SCENE"), "Panel must not retain the Fire Tornado scene dependency.");
assert(!panel.includes("MARS_SPARK_MISSILE_EFFECT_SCENE"), "Panel must not retain the Mars Spark Missile scene dependency.");
assert(!page.includes("GameData"), "Effects page must not depend on gameplay data services.");

console.log("[verify_dev_debug_effects_page_boundary] PASS");
```

- [ ] **Step 2: Add named package scripts**

Add these entries next to the existing Dev Effects verification scripts in `package.json`:

```json
"verify:dev-debug-effects-page-boundary": "node tools\\verify\\verify_dev_debug_effects_page_boundary.js",
"verify:dev-debug-effects-page-runtime": "D:\\Godot\\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_dev_debug_effects_page.gd",
```

- [ ] **Step 3: Run the static verifier and confirm RED**

Run:

```powershell
npm run verify:dev-debug-effects-page-boundary
```

Expected: exit `1` with `DevDebugEffectsPage script must exist.`

- [ ] **Step 4: Write the Godot headless runtime verifier**

Create `tools/verify/verify_dev_debug_effects_page.gd` as a `SceneTree` test. It must:

```gdscript
extends SceneTree

const DevDebugEffectsPageScript: Script = preload("res://scripts/debug/pages/dev_debug_effects_page.gd")

var _failed: bool = false
var _world: Node2D
var _player: Node2D
var _enemy: Node2D
var _orphan_player: Node2D
var _logs: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_world = Node2D.new()
	_world.name = "EffectsPageWorld"
	root.add_child(_world)
	_player = Node2D.new()
	_player.name = "EffectsPagePlayer"
	_player.global_position = Vector2(40.0, 60.0)
	_world.add_child(_player)
	_enemy = Node2D.new()
	_enemy.name = "EffectsPageEnemy"
	_enemy.global_position = Vector2(240.0, 60.0)
	_world.add_child(_enemy)

	var page: VBoxContainer = DevDebugEffectsPageScript.new() as VBoxContainer
	root.add_child(page)
	page.call("setup", Callable(self, "_get_player"), Callable(self, "_get_nearest_enemy"))
	page.connect("log_requested", Callable(self, "_on_log_requested"))
	page.call("build")
	page.call("build")
	page.call("populate_options")
	page.call("populate_options")

	var option: OptionButton = page.call("get_effect_option") as OptionButton
	_expect(option != null, "effect option exists")
	_expect(option.item_count == 2, "effect options stay idempotent", option.item_count)
	_expect(option.get_item_text(0) == "Fire Tornado", "fire option label", option.get_item_text(0))
	_expect(String(option.get_item_metadata(0)) == "fire_tornado", "fire option id", option.get_item_metadata(0))
	_expect(option.get_item_text(1) == "火星飞弹", "mars option label", option.get_item_text(1))
	_expect(String(option.get_item_metadata(1)) == "mars_spark_missile", "mars option id", option.get_item_metadata(1))
	_expect(_count_button_text(page, "持续发射") == 1, "continuous button stays unique")
	_expect(_count_button_text(page, "单次发射") == 1, "single button stays unique")
	var continuous_button: Button = _find_button_text(page, "持续发射")
	var single_button: Button = _find_button_text(page, "单次发射")
	_expect(continuous_button != null, "continuous button is bound")
	_expect(single_button != null, "single button is bound")

	option.select(0)
	if single_button != null:
		single_button.pressed.emit()
	await process_frame
	var tornado: Node2D = _find_child_by_script_suffix(_world, "fire_tornado_effect.gd")
	_expect(tornado != null, "fire tornado spawns")
	if tornado != null:
		_expect(tornado.global_position.is_equal_approx(Vector2(136.0, 60.0)), "fire tornado keeps spawn position", tornado.global_position)
		tornado.queue_free()
	await process_frame

	option.select(1)
	if continuous_button != null:
		continuous_button.pressed.emit()
	await process_frame
	var continuous_mars: Node = _find_child_by_script_suffix(_world, "mars_spark_missile_effect.gd")
	_expect(continuous_mars != null and bool(continuous_mars.get("_continuous")), "continuous button enables continuous mode")
	if continuous_mars != null:
		continuous_mars.queue_free()
	await process_frame

	if single_button != null:
		single_button.pressed.emit()
	await process_frame
	var single_mars: Node = _find_child_by_script_suffix(_world, "mars_spark_missile_effect.gd")
	_expect(single_mars != null and not bool(single_mars.get("_continuous")), "single button disables continuous mode")
	if single_mars != null:
		single_mars.queue_free()
	await process_frame

	option.set_item_metadata(option.selected, &"unknown_effect")
	_logs.clear()
	page.call("fire_single_effect")
	_expect(_has_log_level(&"warning"), "unknown effect emits warning")

	var isolated_page: VBoxContainer = DevDebugEffectsPageScript.new() as VBoxContainer
	root.add_child(isolated_page)
	isolated_page.connect("log_requested", Callable(self, "_on_log_requested"))
	isolated_page.call("setup", Callable(), Callable())
	isolated_page.call("build")
	isolated_page.call("populate_options")
	_logs.clear()
	isolated_page.call("fire_single_effect")
	_expect(_has_log_level(&"warning"), "invalid player lookup emits warning")

	_orphan_player = Node2D.new()
	var orphan_page: VBoxContainer = DevDebugEffectsPageScript.new() as VBoxContainer
	root.add_child(orphan_page)
	orphan_page.connect("log_requested", Callable(self, "_on_log_requested"))
	orphan_page.call("setup", Callable(self, "_get_orphan_player"), Callable())
	orphan_page.call("build")
	orphan_page.call("populate_options")
	_logs.clear()
	orphan_page.call("fire_single_effect")
	await process_frame
	_expect(_has_log_level(&"error"), "missing spawn parent emits error")
	_expect(_find_child_by_script_suffix(root, "fire_tornado_effect.gd") == null, "missing-parent effect is not retained")
	_orphan_player.free()

	if not _failed:
		print("[verify_dev_debug_effects_page] PASS")
	quit(1 if _failed else 0)
```

Add the small helpers used above in the same test file with these exact responsibilities:

```gdscript
func _get_player() -> Node2D:
	return _player

func _get_nearest_enemy() -> Node2D:
	return _enemy

func _get_orphan_player() -> Node2D:
	return _orphan_player

func _on_log_requested(level: StringName, message: String) -> void:
	_logs.append({"level": level, "message": message})

func _has_log_level(level: StringName) -> bool:
	for entry: Dictionary in _logs:
		if StringName(String(entry.get("level", ""))) == level:
			return true
	return false

func _count_button_text(node: Node, text: String) -> int:
	var count: int = 0
	for child: Node in node.find_children("*", "Button", true, false):
		if child is OptionButton:
			continue
		if child is Button and (child as Button).text == text:
			count += 1
	return count

func _find_button_text(node: Node, text: String) -> Button:
	for child: Node in node.find_children("*", "Button", true, false):
		if child is Button and not child is OptionButton and (child as Button).text == text:
			return child as Button
	return null

func _find_child_by_script_suffix(parent: Node, suffix: String) -> Node:
	for child: Node in parent.get_children():
		var script: Script = child.get_script() as Script
		if script != null and script.resource_path.ends_with(suffix):
			return child
	return null

func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_dev_debug_effects_page] FAIL %s actual=%s" % [label, str(actual)])
```

- [ ] **Step 5: Run the runtime verifier and confirm RED**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_dev_debug_effects_page.gd
```

Expected: non-zero exit because `res://scripts/debug/pages/dev_debug_effects_page.gd` does not exist.

---

### Task 2: Implement The Complete Effects Page And Panel Facade

**Files:**
- Create: `scripts/debug/pages/dev_debug_effects_page.gd`
- Modify: `scripts/debug/dev_debug_panel.gd`
- Test: `tools/verify/verify_dev_debug_effects_page_boundary.js`
- Test: `tools/verify/verify_dev_debug_effects_page.gd`

**Interfaces:**
- Consumes: lookup callbacks `Callable() -> Node2D` for player and nearest enemy.
- Produces: the exact page interface defined in the spec and a `log_requested(level: StringName, message: String)` signal.

- [ ] **Step 1: Create `DevDebugEffectsPage` with owned UI and dependencies**

Implement `scripts/debug/pages/dev_debug_effects_page.gd` with:

```gdscript
extends VBoxContainer
class_name DevDebugEffectsPage

signal log_requested(level: StringName, message: String)

const FIRE_TORNADO_EFFECT_SCENE: PackedScene = preload("res://scenes/effects/fire_tornado_effect.tscn")
const MARS_SPARK_MISSILE_EFFECT_SCENE: PackedScene = preload("res://scenes/effects/mars_spark_missile_effect.tscn")
const UIButtonSkinScript: Script = preload("res://scripts/ui/ui_button_skin.gd")

var _get_player_callback: Callable
var _get_nearest_enemy_callback: Callable
var _effect_option: OptionButton
var _built: bool = false

func setup(get_player: Callable, get_nearest_enemy: Callable) -> void:
	_get_player_callback = get_player
	_get_nearest_enemy_callback = get_nearest_enemy

func build() -> void:
	if _built:
		return
	_built = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 7)
	var option_row: HBoxContainer = _add_row()
	var label: Label = Label.new()
	label.text = "Effect"
	label.custom_minimum_size = Vector2(104, 30)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	option_row.add_child(label)
	_effect_option = OptionButton.new()
	_effect_option.custom_minimum_size = Vector2(300, 30)
	_effect_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_row.add_child(_effect_option)
	var actions_row: HBoxContainer = _add_row()
	_add_button(actions_row, "持续发射", Callable(self, "start_continuous_effect"), 116.0)
	_add_button(actions_row, "单次发射", Callable(self, "fire_single_effect"), 116.0)
	populate_options()

func populate_options() -> void:
	if not _built:
		build()
	if _effect_option == null:
		return
	_effect_option.clear()
	_add_option_item("Fire Tornado", "fire_tornado")
	_add_option_item("火星飞弹", "mars_spark_missile")
	_effect_option.select(0)

func get_effect_option() -> OptionButton:
	return _effect_option

func _add_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	return row

func _add_button(parent: HBoxContainer, text: String, action: Callable, width: float) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 30)
	UIButtonSkinScript.apply(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _add_option_item(text: String, id: String) -> void:
	var index: int = _effect_option.item_count
	_effect_option.add_item(text)
	_effect_option.set_item_metadata(index, StringName(id))
```

- [ ] **Step 2: Implement dispatch, spawning, and failure reporting**

Continue the same file with the exact behavior-preserving methods:

```gdscript
func start_continuous_effect() -> void:
	trigger_selected_effect(true)

func fire_single_effect() -> void:
	trigger_selected_effect(false)

func trigger_selected_effect(continuous: bool) -> void:
	match _get_selected_effect_id():
		&"fire_tornado":
			spawn_fire_tornado_effect()
		&"mars_spark_missile":
			spawn_mars_spark_missile_effect(continuous)
		_:
			_emit_log(&"warning", "No effect selected.")

func spawn_fire_tornado_effect() -> void:
	var player: Node2D = _resolve_player()
	if player == null:
		_emit_log(&"warning", "Cannot spawn Fire Tornado: player not found.")
		return
	if FIRE_TORNADO_EFFECT_SCENE == null:
		_emit_log(&"error", "Cannot spawn Fire Tornado: scene failed to load.")
		return
	var effect: Node2D = FIRE_TORNADO_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		_emit_log(&"error", "Cannot spawn Fire Tornado: scene root is not Node2D.")
		return
	var parent: Node = _resolve_spawn_parent(player)
	if parent == null:
		effect.queue_free()
		_emit_log(&"error", "Cannot spawn Fire Tornado: no scene parent available.")
		return
	parent.add_child(effect)
	effect.global_position = resolve_fire_tornado_spawn_position(player)
	_emit_log(&"info", "Spawned Fire Tornado VFX.")

func spawn_mars_spark_missile_effect(continuous: bool) -> void:
	var player: Node2D = _resolve_player()
	if player == null:
		_emit_log(&"warning", "Cannot spawn Mars Spark Missile: player not found.")
		return
	if MARS_SPARK_MISSILE_EFFECT_SCENE == null:
		_emit_log(&"error", "Cannot spawn Mars Spark Missile: scene failed to load.")
		return
	var effect: Variant = MARS_SPARK_MISSILE_EFFECT_SCENE.instantiate()
	if not (effect is Node2D):
		_emit_log(&"error", "Cannot spawn Mars Spark Missile: scene root is not MarsSparkMissileEffect.")
		return
	var parent: Node = _resolve_spawn_parent(player)
	if parent == null:
		(effect as Node).queue_free()
		_emit_log(&"error", "Cannot spawn Mars Spark Missile: no scene parent available.")
		return
	parent.add_child(effect)
	var origin: Vector2 = resolve_mars_spark_missile_spawn_position(player)
	var target: Vector2 = resolve_mars_spark_missile_target_position(player, origin)
	effect.configure(origin, target, false)
	effect.set_continuous(continuous)
	_emit_log(&"info", "Spawned %s Mars Spark Missile VFX." % ("continuous" if continuous else "single"))
```

Add the three public position methods with the current formulas and the private dependency helpers exactly as follows:

```gdscript
func resolve_fire_tornado_spawn_position(player: Node2D) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var nearest_enemy: Node2D = _resolve_nearest_enemy()
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		var to_enemy: Vector2 = nearest_enemy.global_position - player.global_position
		if to_enemy.length_squared() > 0.0001:
			direction = to_enemy.normalized()
	return player.global_position + direction * 96.0

func resolve_mars_spark_missile_spawn_position(player: Node2D) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var nearest_enemy: Node2D = _resolve_nearest_enemy()
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		direction = player.global_position.direction_to(nearest_enemy.global_position)
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
	return player.global_position + direction.normalized() * 32.0

func resolve_mars_spark_missile_target_position(player: Node2D, origin: Vector2) -> Vector2:
	var nearest_enemy: Node2D = _resolve_nearest_enemy()
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		return nearest_enemy.global_position
	var direction: Vector2 = Vector2.RIGHT
	if player != null:
		direction = player.global_position.direction_to(origin)
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
	return origin + direction.normalized() * 360.0

func _resolve_player() -> Node2D:
	if not _get_player_callback.is_valid():
		return null
	var candidate: Variant = _get_player_callback.call()
	if candidate is Node2D and is_instance_valid(candidate):
		return candidate as Node2D
	return null

func _resolve_nearest_enemy() -> Node2D:
	if not _get_nearest_enemy_callback.is_valid():
		return null
	var candidate: Variant = _get_nearest_enemy_callback.call()
	if candidate is Node2D and is_instance_valid(candidate):
		return candidate as Node2D
	return null

func _resolve_spawn_parent(player: Node2D) -> Node:
	if player != null and player.get_parent() != null:
		return player.get_parent()
	if get_tree() != null and get_tree().current_scene != null:
		return get_tree().current_scene
	return null

func _get_selected_effect_id() -> StringName:
	if _effect_option == null or _effect_option.item_count <= 0:
		return &""
	var selected_index: int = clampi(_effect_option.selected, 0, _effect_option.item_count - 1)
	return StringName(String(_effect_option.get_item_metadata(selected_index)))

func _emit_log(level: StringName, message: String) -> void:
	log_requested.emit(level, message)
```

- [ ] **Step 3: Mount the page from `DevDebugPanel`**

In `scripts/debug/dev_debug_panel.gd`:

```gdscript
const DevDebugEffectsPageScript: Script = preload("res://scripts/debug/pages/dev_debug_effects_page.gd")

var _effects_page: VBoxContainer
```

Remove the two VFX scene constants from the Panel. Replace `_build_effects_page()` with:

```gdscript
func _build_effects_page(page_root: VBoxContainer) -> void:
	var effects_category: VBoxContainer = _add_category_page(page_root, "effects", "Effects")
	_effects_page = DevDebugEffectsPageScript.new() as VBoxContainer
	_effects_page.name = "DevDebugEffectsPage"
	effects_category.add_child(_effects_page)
	_effects_page.call("setup", Callable(self, "_get_player"), Callable(self, "_get_nearest_enemy"))
	if not _effects_page.is_connected("log_requested", Callable(self, "_on_effects_page_log_requested")):
		_effects_page.connect("log_requested", Callable(self, "_on_effects_page_log_requested"))
	_effects_page.call("build")
	_effect_option = _effects_page.call("get_effect_option") as OptionButton
```

Add log forwarding:

```gdscript
func _on_effects_page_log_requested(level: StringName, message: String) -> void:
	match level:
		&"error":
			_log_error(message)
		&"warning":
			_log_warn(message)
		_:
			_log(message)
```

- [ ] **Step 4: Replace old Effects implementations with thin delegates**

Keep every compatibility method named by the spec. Replace their bodies with these exact guarded delegates:

```gdscript
func _populate_effect_options() -> void:
	if _effects_page != null:
		_effects_page.call("populate_options")

func _start_continuous_effect_fire() -> void:
	if _effects_page != null:
		_effects_page.call("start_continuous_effect")

func _fire_single_effect() -> void:
	if _effects_page != null:
		_effects_page.call("fire_single_effect")

func _trigger_selected_effect(continuous: bool) -> void:
	if _effects_page != null:
		_effects_page.call("trigger_selected_effect", continuous)

func _spawn_fire_tornado_effect() -> void:
	if _effects_page != null:
		_effects_page.call("spawn_fire_tornado_effect")

func _spawn_mars_spark_missile_effect(continuous: bool) -> void:
	if _effects_page != null:
		_effects_page.call("spawn_mars_spark_missile_effect", continuous)

func _resolve_fire_tornado_spawn_position(player: Node2D) -> Vector2:
	if _effects_page == null:
		return Vector2.ZERO
	var result: Variant = _effects_page.call("resolve_fire_tornado_spawn_position", player)
	return result if result is Vector2 else Vector2.ZERO

func _resolve_mars_spark_missile_spawn_position(player: Node2D) -> Vector2:
	if _effects_page == null:
		return Vector2.ZERO
	var result: Variant = _effects_page.call("resolve_mars_spark_missile_spawn_position", player)
	return result if result is Vector2 else Vector2.ZERO

func _resolve_mars_spark_missile_target_position(player: Node2D, origin: Vector2) -> Vector2:
	if _effects_page == null:
		return Vector2.ZERO
	var result: Variant = _effects_page.call("resolve_mars_spark_missile_target_position", player, origin)
	return result if result is Vector2 else Vector2.ZERO
```

Do not change any of these signatures.

- [ ] **Step 5: Run the new static and runtime verifiers and confirm GREEN**

Run:

```powershell
npm run verify:dev-debug-effects-page-boundary
npm run verify:dev-debug-effects-page-runtime
```

Expected:

```text
[verify_dev_debug_effects_page_boundary] PASS
[verify_dev_debug_effects_page] PASS
```

---

### Task 3: Update Existing VFX Contracts To Follow The New Boundary

**Files:**
- Modify: `tools/verify/verify_dev_effects_panel_vfx.js`
- Modify: `tools/verify/verify_fire_tornado_debug_vfx.js`
- Test: both modified verifier files.

**Interfaces:**
- Consumes: Panel facade methods and `scripts/debug/pages/dev_debug_effects_page.gd` produced by Task 2.
- Produces: existing VFX contracts that verify behavior at its new owner instead of requiring implementation inside the facade.

- [ ] **Step 1: Run both existing contracts and record RED**

Run:

```powershell
npm run verify:dev-effects-panel-vfx
npm run verify:fire-tornado-debug-vfx
```

Expected: both fail because scene constants and spawning implementations moved out of `DevDebugPanel`.

- [ ] **Step 2: Update the Dev Effects contract**

In `verify_dev_effects_panel_vfx.js`, change the verifier signature to `expectPanelContract(panel, effectsPage, failures)`. In `main()`, read `scripts/debug/pages/dev_debug_effects_page.gd` with the existing `readText(relativePath, failures)` helper, require both sources before calling the contract, and call `expectPanelContract(panel, effectsPage, failures)`. Keep category-wrapper and facade assertions against the Panel. Replace the current Panel-owned option, dispatch, and Mars-spawn assertions with these page-owned checks:

```javascript
const effectsPage = readText("scripts/debug/pages/dev_debug_effects_page.gd", failures);
const effectsFunctions = collectFunctionBlocks(effectsPage);
const pagePopulate = findFunction(effectsFunctions, "populate_options");
const pageDispatch = findFunction(effectsFunctions, "trigger_selected_effect");
const pageMarsSpawn = findFunction(effectsFunctions, "spawn_mars_spark_missile_effect");

if (!effectsPage.includes("MARS_SPARK_MISSILE_EFFECT_SCENE")) {
  failures.push("DevDebugEffectsPage must preload the Mars Spark Missile effect scene");
}
if (!pagePopulate || !hasCallWithArgs(pagePopulate.body, "_add_option_item", ['"火星飞弹"', '"mars_spark_missile"'])) {
  failures.push("DevDebugEffectsPage must expose 火星飞弹/mars_spark_missile");
}
if (!pageDispatch || !pageDispatch.body.includes('&"mars_spark_missile"') || !pageDispatch.body.includes("spawn_mars_spark_missile_effect(continuous)")) {
  failures.push("DevDebugEffectsPage must dispatch the selected Mars effect");
}
if (!pageMarsSpawn || !/MARS_SPARK_MISSILE_EFFECT_SCENE\s*\.\s*instantiate\s*\(/.test(pageMarsSpawn.body)) {
  failures.push("DevDebugEffectsPage must instantiate MARS_SPARK_MISSILE_EFFECT_SCENE");
}
```

Replace old Panel implementation assertions with delegate assertions. Keep all scene, script, particle, and material assertions unchanged.

The retained Panel assertions must require `_build_effects_page()` to mount `DevDebugEffectsPageScript`, `_populate_effect_options()` to call `populate_options`, both action callbacks to call their corresponding page methods, `_trigger_selected_effect(continuous)` to delegate the boolean, and `_spawn_mars_spark_missile_effect(continuous)` to delegate the boolean. Do not keep assertions that require the option list, scene preload, dispatch match, or instantiate call to live in `DevDebugPanel`.

- [ ] **Step 3: Update the Fire Tornado contract**

In `verify_fire_tornado_debug_vfx.js`, read the new page and assert:

```javascript
const effectsPagePath = path.join(root, "scripts/debug/pages/dev_debug_effects_page.gd");
assert(fs.existsSync(effectsPagePath), "Effects page script must exist");
const effectsPage = readText("scripts/debug/pages/dev_debug_effects_page.gd");
assert(effectsPage.includes("FIRE_TORNADO_EFFECT_SCENE"), "Effects page must preload the fire tornado scene");
assert(effectsPage.includes('"Fire Tornado"'), "Effects page must expose Fire Tornado");
assert(effectsPage.includes("func spawn_fire_tornado_effect() -> void:"), "Effects page must implement fire tornado spawning");
const resolveSpawnBody = extractGdFunctionBody(
  effectsPage,
  "func resolve_fire_tornado_spawn_position(player: Node2D) -> Vector2:"
);
assert(resolveSpawnBody.includes("_resolve_nearest_enemy()"), "Effects page spawn position must use nearest enemy direction");
assert(debugPanel.includes('DevDebugEffectsPageScript.new()'), "Debug panel must mount the Effects page");
assert(extractGdFunctionBody(debugPanel, "func _spawn_fire_tornado_effect() -> void:").includes('call("spawn_fire_tornado_effect")'), "Debug panel fire tornado method must delegate");
```

Keep all Fire Tornado scene and effect-script assertions unchanged.

- [ ] **Step 4: Run both updated contracts and confirm GREEN**

Run:

```powershell
npm run verify:dev-effects-panel-vfx
npm run verify:fire-tornado-debug-vfx
```

Expected:

```text
Dev effects panel VFX verified.
Fire tornado debug VFX verified.
```

---

### Task 4: Adjacent Runtime And Debug Regression Checks

**Files:**
- No implementation changes expected.

**Interfaces:**
- Consumes: the complete Task 2 component and Task 3 contracts.
- Produces: verification evidence for the Effects page, its VFX scenes, and unaffected DevDebugPanel capabilities.

- [ ] **Step 1: Run JavaScript syntax and text checks**

Run:

```powershell
node --check tools\verify\verify_dev_debug_effects_page_boundary.js
node --check tools\verify\verify_dev_effects_panel_vfx.js
node --check tools\verify\verify_fire_tornado_debug_vfx.js
node tools\validate\check_text_encoding.js
```

Expected: all exit `0`; encoding output reports every checked text file as valid UTF-8.

- [ ] **Step 2: Run focused static contracts**

Run:

```powershell
npm run verify:dev-debug-effects-page-boundary
npm run verify:dev-effects-panel-vfx
npm run verify:fire-tornado-debug-vfx
npm run verify:devtools-god-skill-cards-static
npm run verify:fire-skill-dev-tools-entry-static
```

Expected: all exit `0` and print their PASS/verified message.

- [ ] **Step 3: Run focused Godot runtime verification sequentially**

Run each command separately to avoid the previously observed Windows Godot concurrency crash:

```powershell
npm run verify:dev-debug-effects-page-runtime
npm run verify:fire-tornado-effect-runtime
npm run verify:mars-spark-missile-effect-runtime
npm run verify:devtools-clear-skills
npm run verify:fire-skill-dev-tools-entry
```

Expected: every command exits `0` with no new error or warning.

- [ ] **Step 4: Run Godot parse and startup checks**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/debug/pages/dev_debug_effects_page.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/debug/dev_debug_panel.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --quit
```

Expected: all exit `0` without new parse errors or startup errors.

---

### Task 5: Stage 1 Baseline And Scope Audit

**Files:**
- No implementation changes expected.

**Interfaces:**
- Consumes: all previous tasks.
- Produces: final evidence that Stage 2A preserved the established Stage 1 baseline and stayed within scope.

- [ ] **Step 1: Re-run the Stage 1 static contracts**

Run:

```powershell
npm run verify:skill-retarget-dead-target
npm run verify:offscreen-target-filter
npm run verify:skill-definition-schema
npm run verify:enemy-motion-neighbor-limit
node tools\verify\verify_pr1_ui_churn_contract.js
node tools\verify\verify_pr2_runtime_pool_contract.js
node tools\verify\verify_pr3_combat_scene_pool_contract.js
node tools\verify\verify_pr4_pickup_pool_contract.js
node tools\verify\verify_pr5_status_tick_observability_contract.js
```

Expected: all exit `0`.

- [ ] **Step 2: Re-run the Stage 1 Godot runtime baseline sequentially**

Run the following 11 scripts one at a time:

```text
verify_homing_projectile_swept_hit.gd
verify_mars_spark_missile_effect_runtime.gd
verify_crimson_dragon_summon_behavior.gd
verify_summon_system_behavior.gd
verify_fire_skill_runtime_smoke.gd
verify_frost_skill_runtime_smoke.gd
verify_thunder_skill_runtime_smoke.gd
verify_curse_skill_runtime_smoke.gd
verify_holy_skill_runtime_smoke.gd
verify_fusion_skill_runtime_smoke.gd
verify_player_dash.gd
```

Expected: `11/11` exit `0`.

- [ ] **Step 3: Audit the final diff**

Run:

```powershell
git diff --check
git status --short
git diff --stat
git diff --name-only
```

Expected Stage 2A additions or modifications are limited to:

```text
docs/superpowers/specs/2026-09-19-dev-debug-effects-page-design.md
docs/superpowers/plans/2026-09-19-dev-debug-effects-page-implementation.md
scripts/debug/pages/dev_debug_effects_page.gd
scripts/debug/dev_debug_panel.gd
tools/verify/verify_dev_debug_effects_page_boundary.js
tools/verify/verify_dev_debug_effects_page.gd
tools/verify/verify_dev_effects_panel_vfx.js
tools/verify/verify_fire_tornado_debug_vfx.js
package.json
```

The existing 13 Stage 1 test-file changes remain present and unchanged. No gameplay, numeric, save, configuration, VFX resource, scene, or unrelated formatting files may appear.

- [ ] **Step 4: Report without committing**

Report the modified files, preserved invariants, exact verification results, real residual risks, and rollback instructions. Do not stage, commit, push, or create a PR.
