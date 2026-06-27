# Dev Tools God Skill Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the Dev Tools `Fire Skills` workflow into `Skill Cards`, add six god filter buttons, and show data-driven god skill cards with name, description, VFX description, and effect summary.

**Architecture:** Keep the implementation inside `scripts/debug/dev_debug_panel.gd` and reuse the existing fire skill debug chain instead of creating a second runtime path. `data/gods.json` drives the six buttons, `data/skills.json` drives card contents, and `UpgradePool.generate_debug_fire_skill_options(player, god_id)` remains the source for clickable debug learn/cast options.

**Tech Stack:** Godot 4.6 GDScript, existing DevDebugPanel UI helpers, existing UpgradePool debug option generation, Node/Godot smoke tests in `tools/`.

---

## File Structure

- Modify `scripts/debug/dev_debug_panel.gd`
  - Remove the standalone `Fire Skills` category button/page.
  - Add god skill controls under the existing `Skill Cards` page.
  - Load `gods.json` and `skills.json` for display data.
  - Render six god buttons and a scrollable skill-card list.
  - Keep `debug_run_fire_skill_chain()` as a compatibility wrapper over the new god skill chain.
- Modify `scripts/upgrades/upgrade_pool.gd`
  - Generalize debug god option generation enough for future god ids while preserving current fire behavior.
- Modify `tools/verify_fire_skill_dev_tools_entry_static.js`
  - Update static assertions from “Fire Skills category exists” to “Skill Cards owns god skill controls”.
- Modify `tools/verify_fire_skill_dev_tools_entry.gd`
  - Verify the new `Skill Cards` god button/card API and the existing fire skill chain.
- Create `tools/verify_devtools_god_skill_cards_static.js`
  - Validate six gods, card text fields, removal of standalone Fire Skills, and data-driven card rendering.

---

### Task 1: Add Static Contract Test For The New UI Shape

**Files:**
- Create: `tools/verify_devtools_god_skill_cards_static.js`
- Modify: `tools/verify_fire_skill_dev_tools_entry_static.js`

- [ ] **Step 1: Create the static test**

Create `tools/verify_devtools_god_skill_cards_static.js` with:

```javascript
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(relativePath) {
  return JSON.parse(read(relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const panel = read("scripts/debug/dev_debug_panel.gd");
const gods = readJson("data/gods.json").gods || [];
const skills = readJson("data/skills.json").skills || [];

assert(gods.length === 6, `expected 6 gods, got ${gods.length}`);
for (const god of gods) {
  assert(typeof god.id === "string" && god.id.length > 0, "each god must have an id");
}

assert(
  !panel.includes('_add_category_button(category_grid, "fire_skills", "Fire Skills")'),
  "Fire Skills must no longer be a standalone Dev Tools category"
);
assert(
  panel.includes('_add_category_button(category_grid, "skill_cards", "Skill Cards")'),
  "Skill Cards category must remain available"
);
assert(panel.includes("GodSkillButtons"), "Skill Cards page must create the god button row");
assert(panel.includes("GodSkillCardsScroll"), "Skill Cards page must create the god skill card scroll area");
assert(panel.includes("func _populate_god_skill_buttons()"), "DevDebugPanel must populate god skill buttons");
assert(panel.includes("func _refresh_god_skill_cards()"), "DevDebugPanel must refresh god skill cards");
assert(panel.includes("func _format_god_skill_card_text"), "DevDebugPanel must format god skill card text");
assert(panel.includes("vfx_description"), "God skill cards must display vfx_description");
assert(panel.includes("effect_description"), "God skill cards must prefer effect_description when available");
assert(panel.includes("debug_run_god_skill_chain"), "DevDebugPanel must expose a god skill debug chain API");

const fireSkills = skills.filter((skill) => skill.god_id === "fire" && skill.offer_in_upgrade_pool === true);
assert(fireSkills.length === 60, `expected 60 fire skill cards, got ${fireSkills.length}`);
assert(fireSkills.some((skill) => skill.id === "mars_spark_missile"), "mars_spark_missile must be in fire cards");

console.log("[verify_devtools_god_skill_cards_static] PASS");
```

- [ ] **Step 2: Update the existing static fire debug test**

In `tools/verify_fire_skill_dev_tools_entry_static.js`, replace the old category assertion:

```javascript
assert(panel.includes('_add_category_button(category_grid, "fire_skills", "Fire Skills")'), "DevDebugPanel must expose Fire Skills category");
```

with:

```javascript
assert(!panel.includes('_add_category_button(category_grid, "fire_skills", "Fire Skills")'), "DevDebugPanel must not expose Fire Skills as a standalone category");
assert(panel.includes("debug_run_god_skill_chain"), "DevDebugPanel must expose generalized god skill chain");
assert(panel.includes("GodSkillButtons"), "Skill Cards page must host god skill controls");
```

Keep the existing assertions for `_grant_fire_skill_option`, `_spawn_fire_skill_debug_target`, `_cast_fire_skill_once`, `debug_run_fire_skill_chain`, particle counts, and damage popup counts so the runtime chain remains covered.

- [ ] **Step 3: Run static tests and verify they fail before implementation**

Run:

```powershell
node tools\verify_devtools_god_skill_cards_static.js
node tools\verify_fire_skill_dev_tools_entry_static.js
```

Expected before implementation:

```text
Error: Fire Skills must no longer be a standalone Dev Tools category
```

and/or missing `GodSkillButtons`, `debug_run_god_skill_chain`, or god card functions.

---

### Task 2: Move Fire Skills Controls Into Skill Cards

**Files:**
- Modify: `scripts/debug/dev_debug_panel.gd`

- [ ] **Step 1: Add fields for god skill UI state**

Near the existing DevDebugPanel member fields, add:

```gdscript
const GODS_DATA_PATH: String = "res://data/gods.json"
const SKILLS_DATA_PATH: String = "res://data/skills.json"

var _god_skill_buttons: Dictionary = {}
var _god_skill_cards_scroll: ScrollContainer
var _god_skill_cards: VBoxContainer
var _selected_god_id: StringName = &"fire"
var _god_skill_options: Array[Dictionary] = []
var _god_skill_definitions: Array[Dictionary] = []
```

Keep `_fire_skill_chain_log_label` and `_debug_fire_skill_options` so the existing fire debug helper functions continue to work.

- [ ] **Step 2: Remove the standalone Fire Skills page from `_build_panel()`**

Delete the block that creates:

```gdscript
var fire_skills_page: VBoxContainer = _add_category_page(page_root, "fire_skills", "Fire Skill Debug")
_fire_skill_option = _add_option_row(fire_skills_page, "Fire Skill")
```

and its Grant, Spawn Target, Cast Selected, Run Chain, Refresh, and `_fire_skill_chain_log_label` setup rows.

- [ ] **Step 3: Add god skill controls inside the Skill Cards page**

Immediately after `_runtime_upgrade_chart` is added and before `_runtime_upgrade_cards_scroll` is created, add:

```gdscript
var god_skill_button_row: HBoxContainer = _add_row(skill_cards_page)
god_skill_button_row.name = "GodSkillButtons"

_god_skill_cards_scroll = ScrollContainer.new()
_god_skill_cards_scroll.name = "GodSkillCardsScroll"
_god_skill_cards_scroll.custom_minimum_size = Vector2(440, 180)
_god_skill_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
_god_skill_cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
skill_cards_page.add_child(_god_skill_cards_scroll)

_god_skill_cards = VBoxContainer.new()
_god_skill_cards.name = "GodSkillCards"
_god_skill_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
_god_skill_cards.add_theme_constant_override("separation", 6)
_god_skill_cards_scroll.add_child(_god_skill_cards)

var god_skill_action_row: HBoxContainer = _add_row(skill_cards_page)
_add_button(god_skill_action_row, "Spawn Target", Callable(self, "_spawn_fire_skill_debug_target"), 132)
_add_button(god_skill_action_row, "Run Selected", Callable(self, "_run_selected_god_skill_chain"), 132)
_add_button(god_skill_action_row, "Refresh Gods", Callable(self, "_refresh_god_skill_cards"), 112)

_fire_skill_chain_log_label = Label.new()
_fire_skill_chain_log_label.name = "GodSkillChainLogLabel"
_fire_skill_chain_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
_fire_skill_chain_log_label.add_theme_font_size_override("font_size", 12)
_fire_skill_chain_log_label.text = "God skill chain: idle."
skill_cards_page.add_child(_fire_skill_chain_log_label)
```

- [ ] **Step 4: Stop populating the removed Fire Skill option row**

In `_populate_options()`, replace:

```gdscript
_populate_fire_skill_options()
```

with:

```gdscript
_populate_god_skill_buttons()
_refresh_god_skill_cards()
```

- [ ] **Step 5: Run static check-only**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'E:\roguelike_survivor' --check-only --script res://scripts/debug/dev_debug_panel.gd
```

Expected:

```text
Godot Engine v4.6.3.stable.official...
```

with exit code `0`.

---

### Task 3: Add Six God Buttons And Data-Driven Skill Cards

**Files:**
- Modify: `scripts/debug/dev_debug_panel.gd`

- [ ] **Step 1: Add god/skill data loaders**

Add these helper functions near the existing option population helpers:

```gdscript
func _load_json_document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


func _get_god_definitions() -> Array[Dictionary]:
	var document: Dictionary = _load_json_document(GODS_DATA_PATH)
	var gods_variant: Variant = document.get("gods", [])
	var gods: Array[Dictionary] = []
	if gods_variant is Array:
		for god_variant: Variant in gods_variant:
			if god_variant is Dictionary:
				gods.append((god_variant as Dictionary).duplicate(true))
	if not gods.is_empty():
		return gods
	return [
		{"id": "fire", "display_name": "火焰"},
		{"id": "thunder", "display_name": "雷霆"},
		{"id": "frost", "display_name": "寒霜"},
		{"id": "curse", "display_name": "诅咒"},
		{"id": "holy", "display_name": "神圣"},
		{"id": "chaos", "display_name": "混沌"}
	]


func _get_god_skill_definitions(god_id: StringName) -> Array[Dictionary]:
	var document: Dictionary = _load_json_document(SKILLS_DATA_PATH)
	var skills_variant: Variant = document.get("skills", [])
	var skills: Array[Dictionary] = []
	if skills_variant is Array:
		for skill_variant: Variant in skills_variant:
			if not (skill_variant is Dictionary):
				continue
			var skill: Dictionary = (skill_variant as Dictionary).duplicate(true)
			if StringName(String(skill.get("god_id", ""))) != god_id:
				continue
			if not bool(skill.get("offer_in_upgrade_pool", false)):
				continue
			skills.append(skill)
	return skills
```

- [ ] **Step 2: Add god button population and selection**

Add:

```gdscript
func _populate_god_skill_buttons() -> void:
	var row: HBoxContainer = find_child("GodSkillButtons", true, false) as HBoxContainer
	if row == null:
		return
	_clear_children(row)
	_god_skill_buttons.clear()
	for god: Dictionary in _get_god_definitions():
		var god_id: StringName = StringName(String(god.get("id", "")))
		if god_id == &"":
			continue
		var label: String = String(god.get("display_name", god_id))
		var button: Button = _add_button(row, label, Callable(self, "_select_god_skill_cards").bind(god_id), 72)
		button.name = "GodSkillButton_%s" % String(god_id)
		_god_skill_buttons[god_id] = button
	if not _god_skill_buttons.has(_selected_god_id) and not _god_skill_buttons.is_empty():
		_selected_god_id = _god_skill_buttons.keys()[0]
	_update_god_skill_button_states()


func _select_god_skill_cards(god_id: StringName) -> void:
	_selected_god_id = god_id
	_update_god_skill_button_states()
	_refresh_god_skill_cards()


func _update_god_skill_button_states() -> void:
	for god_id_variant: Variant in _god_skill_buttons.keys():
		var god_id: StringName = StringName(String(god_id_variant))
		var button: Button = _god_skill_buttons[god_id] as Button
		if button == null:
			continue
		button.button_pressed = god_id == _selected_god_id
```

- [ ] **Step 3: Add skill card list rendering**

Add:

```gdscript
func _refresh_god_skill_cards() -> void:
	if _god_skill_cards == null:
		return
	_clear_children(_god_skill_cards)
	_god_skill_definitions = _get_god_skill_definitions(_selected_god_id)
	_god_skill_options = _build_debug_god_skill_options(_selected_god_id)
	if _god_skill_definitions.is_empty():
		var empty_label: Label = Label.new()
		empty_label.name = "GodSkillCardsEmpty"
		empty_label.text = "No skill cards for this god yet."
		empty_label.add_theme_font_size_override("font_size", 12)
		_god_skill_cards.add_child(empty_label)
		return
	for index: int in range(_god_skill_definitions.size()):
		_add_god_skill_card(_god_skill_cards, _god_skill_definitions[index], index)


func _build_debug_god_skill_options(god_id: StringName) -> Array[Dictionary]:
	var player: Node = _get_player()
	if player == null:
		return []
	if not _upgrade_pool.has_method("generate_debug_fire_skill_options"):
		return []
	var options: Array[Dictionary] = []
	var seen: Dictionary = {}
	for option_variant: Variant in _upgrade_pool.call("generate_debug_fire_skill_options", player, god_id):
		var option: Dictionary = _upgrade_option_to_dictionary(option_variant)
		var skill_id: StringName = _get_option_learn_skill_id(option)
		if skill_id == &"" or seen.has(skill_id):
			continue
		seen[skill_id] = true
		options.append(option)
	return options


func _add_god_skill_card(parent: VBoxContainer, skill: Dictionary, skill_index: int) -> void:
	var button: Button = Button.new()
	button.name = "GodSkillCard_%s" % String(skill.get("id", skill_index))
	button.text = _format_god_skill_card_text(skill)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 118)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = String(skill.get("description", ""))
	UIButtonSkin.apply(button)
	button.pressed.connect(Callable(self, "_run_god_skill_card").bind(StringName(String(skill.get("id", "")))))
	parent.add_child(button)
```

- [ ] **Step 4: Add card text formatting**

Add:

```gdscript
func _format_god_skill_card_text(skill: Dictionary) -> String:
	var skill_name: String = String(skill.get("display_name", skill.get("id", "")))
	var description: String = String(skill.get("description", ""))
	var vfx_description: String = String(skill.get("vfx_description", ""))
	var effect_description: String = _get_god_skill_effect_description(skill)
	return "%s\n描述：%s\n特效：%s\n效果：%s" % [
		skill_name,
		description,
		vfx_description,
		effect_description
	]


func _get_god_skill_effect_description(skill: Dictionary) -> String:
	var configured: String = String(skill.get("effect_description", ""))
	if configured != "":
		return configured
	var parts: Array[String] = []
	var category: String = String(skill.get("category", ""))
	var runtime_family: String = String(skill.get("runtime_family", ""))
	var rarity: String = String(skill.get("rarity", ""))
	if category != "":
		parts.append(category)
	if runtime_family != "":
		parts.append(runtime_family)
	if rarity != "":
		parts.append(rarity)
	var events: Array = _get_array(skill.get("events", []))
	for event_variant: Variant in events:
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		var trigger: String = String(event.get("trigger", ""))
		var actions: Array = _get_array(event.get("actions", []))
		if trigger != "" and not actions.is_empty():
			parts.append("%s:%d actions" % [trigger, actions.size()])
	return " / ".join(parts) if not parts.is_empty() else "No effect summary."
```

- [ ] **Step 5: Run static and check-only tests**

Run:

```powershell
node tools\verify_devtools_god_skill_cards_static.js
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'E:\roguelike_survivor' --check-only --script res://scripts/debug/dev_debug_panel.gd
```

Expected:

```text
[verify_devtools_god_skill_cards_static] PASS
Godot Engine v4.6.3.stable.official...
```

both with exit code `0`.

---

### Task 4: Wire Card Clicks To The Existing Debug Chain

**Files:**
- Modify: `scripts/debug/dev_debug_panel.gd`
- Modify: `scripts/upgrades/upgrade_pool.gd`

- [ ] **Step 1: Add generalized debug chain methods**

In `scripts/debug/dev_debug_panel.gd`, add:

```gdscript
func debug_select_god_skill_cards(god_id: StringName) -> Dictionary:
	_select_god_skill_cards(god_id)
	return {
		"god_id": god_id,
		"card_count": _god_skill_definitions.size(),
		"button_count": _god_skill_buttons.size()
	}


func debug_run_god_skill_chain(skill_id: StringName) -> Dictionary:
	return await _run_god_skill_card(skill_id)


func _run_selected_god_skill_chain() -> void:
	if _god_skill_definitions.is_empty():
		_log_warn("No god skill card selected.")
		return
	var first_skill: Dictionary = _god_skill_definitions[0]
	var skill_id: StringName = StringName(String(first_skill.get("id", "")))
	var result: Dictionary = await _run_god_skill_card(skill_id)
	_update_fire_skill_chain_log(result)


func _run_god_skill_card(skill_id: StringName) -> Dictionary:
	if skill_id == &"":
		return {"skill_id": skill_id, "option_generated": false, "granted": false, "error": "Missing skill id."}
	if _selected_god_id != &"fire":
		_select_god_skill_cards(_selected_god_id)
	var option: Dictionary = _get_god_skill_option(skill_id)
	if option.is_empty():
		var fallback: Dictionary = _build_fire_skill_chain_result(skill_id)
		fallback["option_generated"] = false
		fallback["error"] = "No god skill debug option for %s." % String(skill_id)
		_update_fire_skill_chain_log(fallback)
		return fallback
	var selected_skill_id: StringName = _get_option_learn_skill_id(option)
	var result: Dictionary = _build_fire_skill_chain_result(selected_skill_id)
	result["option_generated"] = true
	result["option_id"] = String(option.get("id", ""))
	result["granted"] = _grant_fire_skill_option(option)
	if not bool(result.get("granted", false)):
		result["error"] = "Could not grant %s." % String(selected_skill_id)
		_update_fire_skill_chain_log(result)
		return result
	var target: Node2D = _spawn_fire_skill_debug_target()
	result["target_spawned"] = target != null
	if target == null:
		result["error"] = "Could not spawn target."
		_update_fire_skill_chain_log(result)
		return result
	await _wait_debug_frames(3, false)
	_prepare_fire_skill_debug_target(target)
	var cast_result: Dictionary = await _cast_fire_skill_once(selected_skill_id)
	for key_variant: Variant in cast_result.keys():
		result[key_variant] = cast_result[key_variant]
	result["skill_id"] = selected_skill_id
	result["option_id"] = String(option.get("id", ""))
	result["option_generated"] = true
	result["granted"] = true
	result["target_spawned"] = true
	_update_fire_skill_chain_log(result)
	return result


func _get_god_skill_option(skill_id: StringName) -> Dictionary:
	if _god_skill_options.is_empty():
		_god_skill_options = _build_debug_god_skill_options(_selected_god_id)
	for option: Dictionary in _god_skill_options:
		if _get_option_learn_skill_id(option) == skill_id:
			return option.duplicate(true)
	return {}
```

- [ ] **Step 2: Keep fire chain API compatible**

Replace the body of `debug_run_fire_skill_chain(skill_id: StringName)` with:

```gdscript
func debug_run_fire_skill_chain(skill_id: StringName) -> Dictionary:
	_select_god_skill_cards(&"fire")
	return await debug_run_god_skill_chain(skill_id)
```

Keep `_grant_selected_fire_skill()` and `_cast_selected_fire_skill()` if they are still referenced by old tests or tooling, but they can use `_get_god_skill_option()` when `_fire_skill_option` is null.

- [ ] **Step 3: Generalize UpgradePool debug option function naming without breaking calls**

In `scripts/upgrades/upgrade_pool.gd`, keep:

```gdscript
func generate_debug_fire_skill_options(player: Node, god_id: StringName = &"fire") -> Array:
```

Do not rename it yet, because existing smoke tests and DevDebugPanel call it. It already accepts `god_id`, so no runtime change is required for this task.

- [ ] **Step 4: Run Godot check-only**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'E:\roguelike_survivor' --check-only --script res://scripts/debug/dev_debug_panel.gd
```

Expected exit code `0`.

---

### Task 5: Extend Godot Smoke For Six Buttons And Card Chain

**Files:**
- Modify: `tools/verify_fire_skill_dev_tools_entry.gd`

- [ ] **Step 1: Add Skill Cards god UI checks to the smoke**

In `_run()`, after the first fire chain result assertions, call a new helper:

```gdscript
await _run_god_skill_cards_ui_case()
```

Add this helper:

```gdscript
func _run_god_skill_cards_ui_case() -> void:
	var app_scene: PackedScene = load(APP_BOOTSTRAP_PATH) as PackedScene
	if app_scene == null:
		_fail("app bootstrap scene loads for god skill cards", APP_BOOTSTRAP_PATH)
		return
	var app: Node = app_scene.instantiate()
	root.add_child(app)
	current_scene = app
	await _wait_process_frames(3)
	var ui_manager: Node = app.find_child("UIManager", true, false)
	if ui_manager == null or not ui_manager.has_method("start_developer_debug_run"):
		_fail("UIManager.start_developer_debug_run exists for god skill cards", "missing")
		return
	ui_manager.call("start_developer_debug_run", {
		"character_id": CHARACTER_ID,
		"weapon_id": WEAPON_ID,
		"map_id": MAP_ID
	})
	root.set_meta("developer_mode_enabled", true)
	root.set_meta("debug_control_mode", true)
	root.set_meta("debug_manual_spawn_only", true)
	root.set_meta("debug_enemy_forced_state", "idle")
	await _wait_for_player(90)
	await _wait_process_frames(5)
	var panel: Node = app.find_child("DevDebugPanel", true, false)
	if panel == null:
		panel = root.find_child("DevDebugPanel", true, false)
	if panel == null:
		_fail("DevDebugPanel exists for god skill cards", "missing")
		return
	var button_row: Node = panel.find_child("GodSkillButtons", true, false)
	_expect(button_row != null and button_row.get_child_count() >= 6, "six god buttons are visible", button_row.get_child_count() if button_row != null else 0)
	if panel.has_method("debug_select_god_skill_cards"):
		var fire_selection: Variant = panel.call("debug_select_god_skill_cards", &"fire")
		if fire_selection is Dictionary:
			_expect(int((fire_selection as Dictionary).get("card_count", 0)) >= 1, "fire god skill cards are visible", fire_selection)
		var thunder_selection: Variant = panel.call("debug_select_god_skill_cards", &"thunder")
		if thunder_selection is Dictionary:
			_expect(int((thunder_selection as Dictionary).get("button_count", 0)) >= 6, "empty god selection remains stable", thunder_selection)
	app.queue_free()
	current_scene = null
	await _wait_process_frames(3)
```

- [ ] **Step 2: Update fire chain call if needed**

Keep this existing line:

```gdscript
var result_variant: Variant = await panel.call("debug_run_fire_skill_chain", skill_id)
```

It should still pass because `debug_run_fire_skill_chain()` is a compatibility wrapper.

- [ ] **Step 3: Run smoke and verify it fails before implementation completion**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'E:\roguelike_survivor' --script res://tools/verify_fire_skill_dev_tools_entry.gd
```

Expected before implementation completion: failure on missing `GodSkillButtons` or `debug_select_god_skill_cards`.

---

### Task 6: Final Verification

**Files:**
- Verify only.

- [ ] **Step 1: Run static tests**

Run:

```powershell
node tools\verify_devtools_god_skill_cards_static.js
node tools\verify_fire_skill_dev_tools_entry_static.js
```

Expected:

```text
[verify_devtools_god_skill_cards_static] PASS
[verify_fire_skill_dev_tools_entry_static] PASS
```

- [ ] **Step 2: Run Godot script checks**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'E:\roguelike_survivor' --check-only --script res://scripts/debug/dev_debug_panel.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'E:\roguelike_survivor' --check-only --script res://tools/verify_fire_skill_dev_tools_entry.gd
```

Expected: both exit `0`.

- [ ] **Step 3: Run Godot smoke**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'E:\roguelike_survivor' --script res://tools/verify_fire_skill_dev_tools_entry.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'E:\roguelike_survivor' --script res://tools/verify_fire_skill_card_selection_runtime.gd
```

Expected:

```text
[verify_fire_skill_dev_tools_entry] PASS
[verify_fire_skill_card_selection_runtime] PASS
```

Warnings about `damage_type 'fire' is an old element value` and missing `damage_scaling.skill_level_coefficients` are acceptable if exit code is `0`, because they pre-exist and do not fail the smoke.

- [ ] **Step 4: Check for stray Godot console processes**

Run:

```powershell
Get-Process | Where-Object { $_.ProcessName -like 'roguelike_survivor*' -or ($_.Path -like 'D:\Godot\*' -and $_.ProcessName -like '*console*') } | Select-Object Id,ProcessName,Path
```

Expected: no rows. If a process from the smoke remains and its path is `D:\Godot\Godot_v4.6.3-stable_win64_console.exe`, stop that process by id.

---

## Self-Review

- Spec coverage: the plan removes the standalone `Fire Skills` category, adds six god buttons under `Skill Cards`, renders god-filtered skill cards from `gods.json` and `skills.json`, includes required text fields, preserves the existing fire debug chain, and verifies empty god selections.
- Completion scan: no unresolved filler steps are present.
- Type consistency: all new GDScript methods use `StringName` god/skill ids, `Array[Dictionary]` card data, existing `Button`, `VBoxContainer`, and `ScrollContainer` controls, and existing DevDebugPanel helpers.
- Repository note: `E:\roguelike_survivor` is not currently a git repository, so execution should skip commit steps unless a git repository is later made available.
