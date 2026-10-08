# Phase 6 Relic Data Access Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route every `RelicManager` configuration read through manager-first `GameData` relic facades while preserving relic gameplay, signals, modifiers, fallback behavior, and data isolation.

**Architecture:** `DataManager` remains the unchanged normal-runtime owner. `GameData` gains a single-relic facade and hardens the existing pool fallback; `RelicManager` keeps its run state and local index but stops selecting between DataManager and JSON itself. Dedicated static and runtime contracts pin both the facade and consumer boundaries before production code changes.

**Tech Stack:** Godot 4.6.3, typed GDScript, Node.js CommonJS verification scripts, JSON configuration, Git.

**Spec:** `docs/superpowers/specs/2026-09-19-relic-data-access-consolidation-design.md`

## Global Constraints

- Do not change relic gameplay, IDs, order, values, probabilities, UI, visuals, signals, save results, or JSON schema.
- Do not modify `scripts/core/data_manager.gd`, `data/relics/relics.json`, any other `data/` file, any scene, or any resource.
- Do not modify `SynergyManager`, `SkillManager`, `StatusEffectManager`, Player, UI, modifier aggregation, damage, death, reward, or save pipelines.
- Preserve every existing public `RelicManager` method and the `relic_added` then `relics_changed` emission order.
- Preserve `RelicManager`'s local definition index and cache-miss refresh behavior.
- Keep JSON compatibility fallbacks and make their returned nested data mutation-safe.
- Change the generic `GameDataAccess` helpers only through a separately approved design; this Phase 6 batch must not touch them.
- Run Godot commands one at a time as direct executable invocations, never through npm, Node.js, Python, `cmd /c`, or nested PowerShell.
- Treat a sandbox-only Godot `signal 11` / `0xC0000005` crash according to the documented direct-command diagnostic control.
- Do not delete generated or untracked UID files without first resolving and verifying each exact path.
- Do not modify, format, restore, or stage unrelated user changes.
- Do not create a commit, push, or PR unless the user explicitly authorizes that action.

## Review Focus

- Empty or missing relic IDs must return `{}` and remain impossible to acquire; Task 1 pins both facade cases and Task 2 pins acquisition.
- A non-empty manager sentinel must be preferred without touching the JSON cache; Task 1 tests both pool and single-definition facades.
- An empty manager relic index must cause independent JSON fallback whose nested dictionaries cannot contaminate later reads; Task 1 tests both paths.
- A `RelicManager` local miss after initial loading must use the single-definition facade and cache an isolated copy; Task 2 tests the late-definition case.
- Successful, duplicate, missing, and over-capacity acquisitions must preserve signal count/order and modifier behavior; Task 2 exercises all four cases with a minimal parent probe.

---

### Task 1: Add and Prove the Manager-First GameData Relic Facades

**Files:**
- Create: `tools/verify/verify_data_access_relics.gd`
- Create: `tools/verify/verify_data_access_relics_boundary.js`
- Modify: `package.json:2-3`
- Modify: `scripts/game/game_data.gd:84-88`

**Interfaces:**
- Consumes: `DataManager.get_relic_definition(relic_id: Variant) -> Dictionary`, `DataManager.get_relic_definitions() -> Array[Dictionary]`, `GameDataAccess` helper methods, and `DataPaths.RELICS_PATH`.
- Produces: `GameData.get_relic(relic_id: StringName) -> Dictionary` and a mutation-safe existing `GameData.get_relic_pool() -> Array[Dictionary]`.

- [ ] **Step 1: Recheck the protected worktree and exact source anchors**

Run:

```powershell
git status --short
git rev-parse --abbrev-ref HEAD
rg -n "static func get_relic_pool|func get_relic_definition|func get_relic_definitions" scripts/game/game_data.gd scripts/core/data_manager.gd
```

Expected: only the approved Phase 6 relic-batch specification and plan are untracked or modified; no protected production file has a diff. If unrelated user changes exist, record and preserve them before continuing.

- [ ] **Step 2: Register the two Phase 6 relic-batch verification commands**

Add these entries near the other data-access scripts in `package.json`:

```json
"verify:data-access-relics": "D:\\Godot\\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_relics.gd",
"verify:data-access-relics-boundary": "node tools\\verify\\verify_data_access_relics_boundary.js",
```

Preserve valid JSON and do not reorder unrelated scripts.

- [ ] **Step 3: Write the failing facade boundary contract**

Create `tools/verify/verify_data_access_relics_boundary.js` using the project helpers:

```js
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const gameData = readTextFile(path.join(root, "scripts", "game", "game_data.gd"));
const relicManager = readTextFile(path.join(root, "scripts", "relics", "relic_manager.gd"));
const dataManager = readTextFile(path.join(root, "scripts", "core", "data_manager.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const pool = functionBody(gameData, "get_relic_pool", "static func ");
for (const marker of [
  '_get_pool_from_data_manager("get_relic_definitions")',
  "if not data.is_empty()",
  "return data",
  '_get_dictionary_array(RELICS_PATH, "relics").duplicate(true)',
]) assert(pool.includes(marker), `relic pool facade missing ${marker}`);

const lookup = functionBody(gameData, "get_relic", "static func ");
for (const marker of [
  '_get_definition_from_data_manager("get_relic_definition", relic_id)',
  "if not data.is_empty()",
  "return data",
  '_find_by_id(_get_array(RELICS_PATH, "relics"), relic_id).duplicate(true)',
]) assert(lookup.includes(marker), `single relic facade missing ${marker}`);

assert(dataManager.includes("func get_relic_definition(relic_id: Variant) -> Dictionary:"), "owner lookup must remain available");
assert(dataManager.includes("func get_relic_definitions() -> Array[Dictionary]:"), "owner pool must remain available");
assert(relicManager.includes("signal relic_added(relic_id: StringName)"), "relic_added contract must remain");
assert(relicManager.includes("signal relics_changed"), "relics_changed contract must remain");

console.log("[verify_data_access_relics_boundary] PASS");
```

This first RED version deliberately checks only the facade contract. Task 2 extends the same file with the consumer-boundary assertions.

- [ ] **Step 4: Run the facade boundary contract and confirm the intended RED**

Run:

```powershell
node tools/verify/verify_data_access_relics_boundary.js
```

Expected: non-zero exit because `get_relic()` is absent and/or the pool fallback is not deeply duplicated. A syntax error, missing helper, or unrelated assertion is not the intended RED and must be corrected before production code changes.

- [ ] **Step 5: Write the runtime facade contract**

Create `tools/verify/verify_data_access_relics.gd` with this executable structure:

```gdscript
extends SceneTree

const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")
const GameDataScript := preload("res://scripts/game/game_data.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: Node = root.get_node_or_null("DataManager")
	_expect(manager != null, "DataManager autoload exists")
	if manager == null:
		_finish()
		return

	var source: Array[Dictionary] = _source_relics()
	_expect(not source.is_empty(), "source relic pool is non-empty")
	_verify_owner_and_facade(manager, source)
	_verify_manager_source_and_fallback(manager, source)
	_verify_full_fallback(manager, source)
	_finish()


func _source_relics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in JsonDataLoaderScript.load_array(DataPathsScript.RELICS_PATH, "relics", "verify_data_access_relics"):
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func _verify_owner_and_facade(manager: Node, source: Array[Dictionary]) -> void:
	var owner_pool: Array[Dictionary] = _to_dictionary_array(manager.call("get_relic_definitions"))
	var facade_pool: Array[Dictionary] = GameDataScript.get_relic_pool()
	_expect(_ids(owner_pool) == _ids(source), "owner IDs and order match source")
	_expect(owner_pool == source, "owner pool matches source")
	_expect(facade_pool == source, "facade pool matches source")
	for definition: Dictionary in source:
		var relic_id: StringName = StringName(String(definition.get("id", "")))
		_expect(manager.call("get_relic_definition", relic_id) == definition, "owner lookup matches %s" % relic_id)
		_expect(GameDataScript.get_relic(relic_id) == definition, "facade lookup matches %s" % relic_id)
	_expect(GameDataScript.get_relic(&"").is_empty(), "empty relic ID stays empty")
	_expect(GameDataScript.get_relic(&"__missing_phase6_relic__").is_empty(), "missing relic ID stays empty")

	var owner_probe: Array[Dictionary] = _to_dictionary_array(manager.call("get_relic_definitions"))
	var facade_probe: Array[Dictionary] = GameDataScript.get_relic_pool()
	_expect(_mutate_nested_relic(owner_probe, "__phase6_relic_owner__"), "owner pool exposes nested mutation probe")
	_expect(_mutate_nested_relic(facade_probe, "__phase6_relic_facade__"), "facade pool exposes nested mutation probe")
	_expect(_to_dictionary_array(manager.call("get_relic_definitions")) == source, "owner pool is isolated")
	_expect(GameDataScript.get_relic_pool() == source, "facade pool is isolated")
	var lookup_probe: Dictionary = GameDataScript.get_relic(StringName(String(source[0].get("id", ""))))
	_mutate_definition(lookup_probe, "__phase6_relic_lookup__")
	_expect(GameDataScript.get_relic(StringName(String(source[0].get("id", "")))) == source[0], "single facade lookup is isolated")


func _verify_manager_source_and_fallback(manager: Node, source: Array[Dictionary]) -> void:
	var original: Dictionary = manager.get("_relic_definitions").duplicate(true)
	var sentinel_id: StringName = &"__phase6_relic_manager__"
	var sentinel: Dictionary = {
		"id": String(sentinel_id),
		"trigger_condition": {"event": "phase6_relic"},
		"modifiers": [{"scope": {"domain": "phase6_relic"}}],
		"unlock": {"type": "phase6_relic"}
	}
	manager.set("_relic_definitions", {sentinel_id: sentinel.duplicate(true)})
	GameDataScript._document_cache.clear()
	_expect(GameDataScript.get_relic_pool() == [sentinel], "pool facade prefers manager sentinel")
	_expect(GameDataScript.get_relic(sentinel_id) == sentinel, "lookup facade prefers manager sentinel")
	_expect(not GameDataScript._document_cache.has(DataPathsScript.RELICS_PATH), "manager path avoids JSON cache")

	manager.set("_relic_definitions", {})
	GameDataScript._document_cache.clear()
	var fallback_pool: Array[Dictionary] = GameDataScript.get_relic_pool()
	var fallback_lookup: Dictionary = GameDataScript.get_relic(StringName(String(source[0].get("id", ""))))
	_expect(fallback_pool == source, "empty owner pool falls back")
	_expect(fallback_lookup == source[0], "empty owner lookup falls back")
	_expect(GameDataScript._document_cache.has(DataPathsScript.RELICS_PATH), "fallback uses relic document cache")
	_mutate_nested_relic(fallback_pool, "__phase6_relic_pool_fallback__")
	_mutate_definition(fallback_lookup, "__phase6_relic_lookup_fallback__")
	_expect(GameDataScript.get_relic_pool() == source, "pool fallback is isolated")
	_expect(GameDataScript.get_relic(StringName(String(source[0].get("id", "")))) == source[0], "lookup fallback is isolated")

	manager.set("_relic_definitions", original)
	GameDataScript._document_cache.clear()


func _verify_full_fallback(manager: Node, source: Array[Dictionary]) -> void:
	var original_name: StringName = manager.name
	var original_cache: Dictionary = GameDataScript._document_cache.duplicate(true)
	manager.name = &"Phase6RelicUnavailableDataManager"
	GameDataScript._document_cache.clear()
	var fallback_pool: Array[Dictionary] = GameDataScript.get_relic_pool()
	var first_id: StringName = StringName(String(source[0].get("id", "")))
	var fallback_lookup: Dictionary = GameDataScript.get_relic(first_id)
	var loaded: bool = GameDataScript._document_cache.has(DataPathsScript.RELICS_PATH)
	_mutate_nested_relic(fallback_pool, "__phase6_relic_full_pool__")
	_mutate_definition(fallback_lookup, "__phase6_relic_full_lookup__")
	var fresh_pool: Array[Dictionary] = GameDataScript.get_relic_pool()
	var fresh_lookup: Dictionary = GameDataScript.get_relic(first_id)
	manager.name = original_name
	GameDataScript._document_cache.clear()
	GameDataScript._document_cache.merge(original_cache, true)

	_expect(loaded, "full fallback loads relic document")
	_expect(fresh_pool == source, "full pool fallback is isolated")
	_expect(fresh_lookup == source[0], "full lookup fallback is isolated")


func _mutate_nested_relic(pool: Array[Dictionary], marker: String) -> bool:
	if pool.is_empty():
		return false
	_mutate_definition(pool[0], marker)
	return true


func _mutate_definition(definition: Dictionary, marker: String) -> void:
	var modifiers: Array = definition.get("modifiers", []) as Array
	if not modifiers.is_empty() and modifiers[0] is Dictionary:
		var modifier: Dictionary = modifiers[0]
		var scope: Dictionary = modifier.get("scope", {}) as Dictionary
		scope[marker] = true
	var trigger: Dictionary = definition.get("trigger_condition", {}) as Dictionary
	trigger[marker] = true
	var unlock: Dictionary = definition.get("unlock", {}) as Dictionary
	unlock[marker] = true


func _ids(pool: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for item: Dictionary in pool:
		result.append(String(item.get("id", "")))
	return result


func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item: Variant in value:
			if item is Dictionary:
				result.append(item as Dictionary)
	return result


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_data_access_relics] FAIL %s" % label)


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_relics] PASS")
	quit(1 if _failed else 0)
```

Before accepting this test, verify that all temporarily changed manager fields, the manager name, and `_document_cache` are restored before `_finish()` can execute.

- [ ] **Step 6: Run the runtime contract and confirm the intended RED**

Run the direct executable from the repository root:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_relics.gd
```

Expected: non-zero exit with a parse/runtime failure identifying missing `GameData.get_relic()` or a failed fallback-isolation assertion. If the process crashes only inside the sandbox with `signal 11` / `0xC0000005`, repeat the identical direct command outside the sandbox before classifying it as a test failure.

- [ ] **Step 7: Implement the minimal GameData change**

Change the relic section of `scripts/game/game_data.gd` to this shape:

```gdscript
static func get_relic(relic_id: StringName) -> Dictionary:
	var data: Dictionary = _get_definition_from_data_manager("get_relic_definition", relic_id)
	if not data.is_empty():
		return data
	return _find_by_id(_get_array(RELICS_PATH, "relics"), relic_id).duplicate(true)


static func get_relic_pool() -> Array[Dictionary]:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_relic_definitions")
	if not data.is_empty():
		return data
	return _get_dictionary_array(RELICS_PATH, "relics").duplicate(true)
```

Do not change helper implementations or adjacent domain facades.

- [ ] **Step 8: Run the focused facade gate**

Run:

```powershell
node tools/verify/verify_data_access_relics_boundary.js
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_relics.gd
git diff --check
```

Expected: both Phase 6 relic-batch verifiers print `PASS`; `git diff --check` emits no output. Inspect Godot output for `SCRIPT ERROR` and unexpected `ERROR` lines rather than relying only on exit code.

- [ ] **Step 9: Stop at the Task 1 review checkpoint**

Review only the facade, verifier, and package-entry diff. Confirm that `DataManager`, configuration files, and consumers have no diff. Do not commit unless the user has explicitly authorized commits. If authorized, stage only Task 1 files and use:

```powershell
git add package.json scripts/game/game_data.gd tools/verify/verify_data_access_relics.gd tools/verify/verify_data_access_relics_boundary.js
git commit -m "refactor: add relic data facades"
```

### Task 2: Migrate RelicManager to the Stable Facade

**Files:**
- Modify: `tools/verify/verify_data_access_relics.gd`
- Modify: `tools/verify/verify_data_access_relics_boundary.js`
- Modify: `scripts/relics/relic_manager.gd:1-145`

**Interfaces:**
- Consumes: `GameData.get_relic_pool() -> Array[Dictionary]` and `GameData.get_relic(relic_id: StringName) -> Dictionary` from Task 1.
- Produces: the unchanged public `RelicManager` API backed exclusively by `GameData`, plus the unchanged local `_relic_definitions` index.

- [ ] **Step 1: Extend the static verifier with the consumer boundary**

Append these assertions before the final PASS log in `verify_data_access_relics_boundary.js`:

```js
const loadRelics = functionBody(relicManager, "_load_relic_definitions");
const getRelic = functionBody(relicManager, "_get_relic_definition");

assert(relicManager.includes('preload("res://scripts/game/game_data.gd")'), "RelicManager must preload GameData");
assert(loadRelics.includes("GameDataScript.get_relic_pool()"), "initial relic load must use GameData pool facade");
assert(getRelic.includes("GameDataScript.get_relic(relic_id)"), "local miss must use GameData lookup facade");
for (const forbidden of [
  "DataManager",
  "DataPathsScript",
  "JsonDataLoaderScript",
  "RELIC_DATA_PATH",
  "_load_relics_from_file",
]) assert(!relicManager.includes(forbidden), `RelicManager retains forbidden data dependency ${forbidden}`);

for (const marker of [
  "var owned_relics: Array[StringName] = []",
  "var _relic_definitions: Dictionary = {}",
  "var _trigger_counts: Dictionary = {}",
  "var _cooldown_until: Dictionary = {}",
  "func add_relic(relic_id: Variant) -> bool:",
  "func get_relic_definition(relic_id: Variant) -> Dictionary:",
  "func handle_combat_event(event_name: Variant, payload: Dictionary = {}) -> void:",
  "const ModifierSourceScript: Script",
]) assert(relicManager.includes(marker), `RelicManager public/runtime contract missing ${marker}`);
```

- [ ] **Step 2: Run the static verifier and confirm consumer RED**

Run:

```powershell
node tools/verify/verify_data_access_relics_boundary.js
```

Expected: non-zero exit because `RelicManager` still contains direct DataManager and JSON dependencies. The Task 1 facade assertions must remain green.

- [ ] **Step 3: Extend the runtime verifier with a minimal RelicManager parent probe**

Add this preload and call:

```gdscript
const RelicManagerScript := preload("res://scripts/relics/relic_manager.gd")
```

Call `_verify_relic_manager_contract(manager, source)` after the facade isolation checks and before `_finish()`. Add these helpers:

```gdscript
func _verify_relic_manager_contract(manager: Node, source: Array[Dictionary]) -> void:
	var original: Dictionary = manager.get("_relic_definitions").duplicate(true)
	var host: Node = Node.new()
	root.add_child(host)
	var relic_manager: Node = RelicManagerScript.new()
	host.add_child(relic_manager)
	relic_manager.call("_load_relic_definitions")
	_expect(relic_manager.get("_relic_definitions").size() == source.size(), "RelicManager indexes the complete facade pool")

	var first_id: StringName = StringName(String(source[0].get("id", "")))
	var definition_probe: Dictionary = relic_manager.call("get_relic_definition", first_id)
	_mutate_definition(definition_probe, "__phase6_relic_local__")
	_expect(relic_manager.call("get_relic_definition", first_id) == source[0], "RelicManager definition query is isolated")

	var events: Array[String] = []
	relic_manager.relic_added.connect(func(_id: StringName) -> void: events.append("relic_added"))
	relic_manager.relics_changed.connect(func() -> void: events.append("relics_changed"))
	_expect(bool(relic_manager.call("add_relic", first_id)), "valid relic can be added")
	_expect(events == ["relic_added", "relics_changed"], "successful acquisition preserves signal order")
	_expect(not bool(relic_manager.call("add_relic", first_id)), "duplicate relic stays rejected")
	_expect(not bool(relic_manager.call("add_relic", &"__missing_phase6_relic__")), "missing relic stays rejected")
	_expect(events == ["relic_added", "relics_changed"], "failed acquisitions emit no signals")

	var late_id: StringName = &"__phase6_relic_late__"
	var late_definition: Dictionary = {"id": String(late_id), "modifiers": [], "negative_modifier": []}
	var late_index: Dictionary = original.duplicate(true)
	late_index[late_id] = late_definition.duplicate(true)
	manager.set("_relic_definitions", late_index)
	_expect(relic_manager.call("get_relic_definition", late_id) == late_definition, "local miss resolves through facade lookup")
	var late_probe: Dictionary = relic_manager.call("get_relic_definition", late_id)
	late_probe["id"] = "mutated"
	_expect(relic_manager.call("get_relic_definition", late_id) == late_definition, "late cached definition is isolated")

	var capacity_manager: Node = RelicManagerScript.new()
	capacity_manager.set("max_relics", 1)
	host.add_child(capacity_manager)
	capacity_manager.call("_load_relic_definitions")
	_expect(bool(capacity_manager.call("add_relic", first_id)), "capacity probe accepts first relic")
	var second_id: StringName = StringName(String(source[1].get("id", "")))
	_expect(not bool(capacity_manager.call("add_relic", second_id)), "capacity probe rejects second relic")

	manager.set("_relic_definitions", original)
	host.queue_free()
```

Ensure `source.size() >= 2` is asserted before accessing `source[1]`. The parent probe intentionally exposes none of the modifier-store methods; current `_register_modifier_block()` safely no-ops when those optional methods are absent, allowing acquisition behavior to be isolated without changing production code.

- [ ] **Step 4: Run the runtime verifier before migration**

Run:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_relics.gd
```

Expected before migration: the runtime behavior may remain green because the existing direct source path is compatible; the required consumer RED is the static boundary failure from Step 2. Do not manufacture a runtime failure by weakening or falsifying behavior assertions.

- [ ] **Step 5: Replace only RelicManager's data-source selection**

At the top of `scripts/relics/relic_manager.gd`, replace the direct data dependencies with:

```gdscript
extends Node
class_name RelicManager
const GameDataScript: Script = preload("res://scripts/game/game_data.gd")


const ModifierSourceScript: Script = preload("res://scripts/modifiers/modifier_source.gd")
```

Replace `_load_relic_definitions()` with:

```gdscript
func _load_relic_definitions() -> void:
	_relic_definitions.clear()
	for relic: Dictionary in GameDataScript.get_relic_pool():
		var relic_id: StringName = _to_relic_id(relic.get("id", ""))
		if relic_id != &"":
			_relic_definitions[relic_id] = relic
```

Delete `_load_relics_from_file()` completely. Replace only the local-miss block in `_get_relic_definition()` with:

```gdscript
	if not _relic_definitions.has(relic_id):
		var relic: Dictionary = GameDataScript.get_relic(relic_id)
		if not relic.is_empty():
			_relic_definitions[relic_id] = relic.duplicate(true)
```

Leave the empty-index load, final missing-ID return, and final `duplicate(true)` return unchanged. Do not edit acquisition, triggers, modifiers, helper functions, or formatting outside the removed dependency block.

- [ ] **Step 6: Run the focused Phase 6 relic-batch gate**

Run:

```powershell
node tools/verify/verify_data_access_relics_boundary.js
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_relics.gd
node tools/validate/check_text_encoding.js
node tools/validate/validate_modifier_effects.js
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_upgrade_pool_no_relic_fireball_god_mix.gd
git diff --check
```

Expected: all verifiers print `PASS`, encoding validation reports valid UTF-8, modifier validation succeeds, and the diff check emits no output. Godot output must contain no script parse error or unexplained error.

- [ ] **Step 7: Inspect the production diff against scope**

Run:

```powershell
git diff -- scripts/game/game_data.gd scripts/relics/relic_manager.gd
git diff -- scripts/core/data_manager.gd data/relics/relics.json scripts/relics/synergy_manager.gd scripts/skills/skill_manager.gd scripts/combat/status_effect_manager.gd scripts/player/player_controller.gd scripts/ui/ui_manager.gd scripts/ui/ui_command_dispatcher.gd scripts/modifiers/modifier_aggregator.gd
```

Expected: the first diff contains only facade addition, fallback isolation, and data-source delegation. The second command emits no output.

- [ ] **Step 8: Stop at the Task 2 review checkpoint**

Do not commit unless the user has explicitly authorized commits. If authorized, stage only Task 2 files and use:

```powershell
git add scripts/relics/relic_manager.gd tools/verify/verify_data_access_relics.gd tools/verify/verify_data_access_relics_boundary.js
git commit -m "refactor: route relic manager through game data"
```

### Task 3: Update Engineering Records and Run the Complete Phase 6 Relic-Batch Gate

**Files:**
- Modify: `docs/PROJECT_SYSTEMS_OVERVIEW.md`
- Modify: `docs/PROJECT_ENGINEERING_GUIDELINES.md`
- Modify: `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`
- Verify only: all Phase 6 relic-batch production, test, package, specification, and plan files

**Interfaces:**
- Consumes: the verified Phase 6 relic facade and consumer boundary from Tasks 1 and 2.
- Produces: accurate project records, full regression evidence, a protected-file-clean diff, and a review-ready working tree.

- [ ] **Step 1: Update the systems overview with implemented ownership**

Add a concise Phase 6 relic-batch statement in the data-loading section:

```markdown
The Phase 6 relic data access batch routes `RelicManager` definition reads exclusively through the manager-first `GameData` relic pool and lookup facades. `DataManager` remains the normal-runtime owner, JSON remains an independent compatibility fallback, and relic run state and effect behavior remain owned by `RelicManager`.
```

Do not claim that all relic/synergy consumers or all duplicate fallbacks have been migrated.

- [ ] **Step 2: Update engineering guidance and the stability report**

Record these facts in the existing Phase 6 status sections, adapting grammar to the surrounding Chinese documentation without changing their meaning:

```markdown
- 阶段 6 的遗物数据访问批次已收口 `RelicManager` 的直接 `DataManager`/JSON 读取；遗物定义通过 `GameData` 的池与单条门面进入本局索引。
- 其他消费端自建 fallback 仍须按领域、证据和风险单独处理。
- 阶段 6 的遗物数据访问批次不修改遗物触发、modifier、奖励、UI、存档或配置行为，也不声明性能提升。
```

Keep `StatusEffectManager`, damage, death, and enemy-spawn warnings unchanged.

- [ ] **Step 3: Run the complete prior-stage data-access regression gate**

Run each command separately:

```powershell
node tools/verify/verify_data_access_status_pool_boundary.js
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_status_pool.gd
node tools/verify/verify_data_access_progression_goals_boundary.js
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_progression_goals.gd
node tools/verify/verify_data_access_challenge_pools_boundary.js
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_challenge_pools.gd
node tools/verify/verify_data_access_upgrade_catalog_boundary.js
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_upgrade_catalog.gd
```

Expected: all eight prior-stage verifiers print `PASS` with no script error or unexplained runtime error.

- [ ] **Step 4: Run the complete Phase 6 relic-batch and related behavior gate**

Run each command separately:

```powershell
node tools/validate/check_text_encoding.js
node tools/validate/validate_enemy_configs.js
node tools/validate/validate_modifier_effects.js
node tools/verify/verify_data_access_relics_boundary.js
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_relics.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_upgrade_pool_no_relic_fireball_god_mix.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_damage_formula.gd
node tools/verify/verify_no_numeric_damage_inputs.js
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --quit
git diff --check
```

Expected: all validators and verifiers pass; direct startup exits normally; output contains no `SCRIPT ERROR` and no unexplained `ERROR`; diff check emits no output. This is an architecture batch, so performance comparison is `不适用` and no timing claim is recorded.

- [ ] **Step 5: Verify protected files and exact scope**

Run:

```powershell
git diff --name-only
git status --short
git diff -- scripts/core/data_manager.gd scripts/relics/synergy_manager.gd scripts/skills/skill_manager.gd scripts/combat/status_effect_manager.gd scripts/player/player_controller.gd scripts/ui/ui_manager.gd scripts/ui/ui_command_dispatcher.gd scripts/modifiers/modifier_aggregator.gd data scenes resources
```

Expected modified or new paths are limited to:

```text
scripts/game/game_data.gd
scripts/relics/relic_manager.gd
package.json
tools/verify/verify_data_access_relics.gd
tools/verify/verify_data_access_relics_boundary.js
docs/PROJECT_SYSTEMS_OVERVIEW.md
docs/PROJECT_ENGINEERING_GUIDELINES.md
docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md
docs/superpowers/specs/2026-09-19-relic-data-access-consolidation-design.md
docs/superpowers/plans/2026-09-19-relic-data-access-consolidation.md
```

The protected-file diff command must emit no output. Any additional path stops completion until it is explained and separately approved or removed without disturbing user work.

- [ ] **Step 6: Perform the required whole-branch review**

Compare the complete Phase 6 relic-batch diff against the approved specification. Review specifically for:

- source-selection changes beyond relic definitions;
- loss of the cache-miss lookup behavior;
- shallow-copy leaks from the JSON cache or local index;
- signal, modifier, acquisition, or capacity behavior changes;
- protected-file or formatting noise;
- cleanup gaps after runtime sentinel tests.

Resolve every verified Critical or Important issue with focused RED-to-GREEN evidence, then rerun the affected command and the complete Phase 6 relic-batch gate. Record Minor findings without expanding scope unless they invalidate a stated contract.

- [ ] **Step 7: Stop at the final authorization checkpoint**

Report the batch using the required headings:

```markdown
## 本批次结果
## 修改范围
## 保持不变
## 验证证据
## 性能对比
## 遗留风险
## 下一步建议
```

Set `性能对比` to `不适用`. Do not commit, push, or create a PR without explicit user authorization. If one combined Phase 6 relic-batch commit is authorized, stage exactly the approved paths and use:

```powershell
git add package.json scripts/game/game_data.gd scripts/relics/relic_manager.gd tools/verify/verify_data_access_relics.gd tools/verify/verify_data_access_relics_boundary.js docs/PROJECT_SYSTEMS_OVERVIEW.md docs/PROJECT_ENGINEERING_GUIDELINES.md docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md docs/superpowers/specs/2026-09-19-relic-data-access-consolidation-design.md docs/superpowers/plans/2026-09-19-relic-data-access-consolidation.md
git commit -m "refactor: consolidate relic data access"
```

Push and PR creation remain separate authorization points unless the user's instruction explicitly includes them.

## Rollback Procedure

If the Phase 6 relic batch must be reverted before integration:

1. restore the previous `GameData.get_relic_pool()` fallback return;
2. remove `GameData.get_relic()`;
3. restore `RelicManager`'s direct DataManager/JSON path and `_load_relics_from_file()`;
4. remove the two relic-batch package scripts and verifier files;
5. revert only the Phase 6 relic-batch statements in the three engineering documents;
6. rerun the previously completed Phase 6 data-access gates and direct headless startup.

No configuration, save, scene, or resource migration needs reversal.
