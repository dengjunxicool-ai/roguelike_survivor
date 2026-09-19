# Stage 5D Data Access Upgrade Catalog Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `DataManager` the normal-runtime owner of all three ordered upgrade category pools and rarity weights while preserving every `GameData` facade, JSON fallback, selection rule, UI flow, and save result.

**Architecture:** `DataManager.load_all()` continues to parse `upgrades.json` once, retains the existing ID indexes, and additionally stores three explicit ordered pools plus a rarity-weight dictionary. The five existing `GameData` entry points become manager-first and independently fall back to deeply duplicated JSON data. Upgrade consumers remain unchanged and are protected by focused runtime regressions.

**Tech Stack:** Godot 4.6.3, typed GDScript, Node.js CommonJS verification scripts, JSON configuration, direct Godot headless verification on Windows.

**Spec:** `docs/superpowers/specs/2026-09-19-data-access-upgrade-catalog-consolidation-design.md`

## Global Constraints

- Do not modify `data/upgrades/upgrades.json` or change any upgrade ID, category, order, rarity, weight, modifier, description, maximum level, or numeric value.
- Do not modify `scripts/upgrades/upgrade_pool.gd`, `scripts/upgrades/upgrade_selection_helper.gd`, `scripts/game/save_manager.gd`, `scripts/ui/modals/run_choice_modal_controller.gd`, `scripts/ui/screens/meta_upgrade_view_model_builder.gd`, or `scripts/player/player_controller.gd`.
- Preserve `GameData.get_curse_choice_pool()`, `get_level_up_upgrade_pool()`, `get_permanent_upgrade_pool()`, `get_permanent_upgrade(id)`, and `get_rarity_weights()`.
- Preserve the existing combined `_upgrade_definitions` and `_level_up_upgrade_definitions` indexes.
- Preserve JSON fallback independently for every category and for rarity weights when its manager result is unavailable or empty.
- Manager, facade, and fallback outputs must deeply isolate nested dictionaries and arrays.
- Do not introduce `get_upgrade_pool(category)`, a repository layer, a resource migration, or a new generic data-access abstraction.
- Do not change random-number generation, selection order, guarantee logic, UI behavior, player application, or save schema.
- Run Godot commands one at a time as direct executable invocations outside the managed sandbox when the known sandbox crash path is present.
- In a fresh worktree, generate the ignored Godot global-class cache with one `--headless --editor --path . --quit` scan before ordinary headless verification.
- Inspect and remove only exact newly generated untracked `.gd.uid` files; never blanket-delete UID files.
- Do not commit implementation, push, or create a pull request without explicit user authorization.

## Review Focus

- A facade that invokes a manager method but discards its value must fail normal-path cache and sentinel-source checks.
- Mutating nested `modifiers`, `level_modifiers`, `scope`, or a rarity weight from manager, facade, or fallback output must not affect a later read.
- Empty data in one manager category must fall back only that category; empty rarity weights must not alter any pool source.
- Category arrays must preserve exact JSON order, while `get_permanent_upgrade(id)` fallback must reject IDs from curse and level-up categories.
- Runtime probes must restore the autoload name, every temporary manager field, and the original `GameData` cache before reporting completion.

## Final-review correction (normative)

Independent whole-branch review exposed that the combined upgrade index is not category-safe for `get_permanent_upgrade(id)`. The final implementation therefore searches the manager-owned permanent-upgrade pool rather than the combined index. The final runtime verifier also supersedes the initial Step 6 skeleton by rejecting both curse and level-up IDs on manager and fallback paths, proving a permanent lookup sentinel comes from the manager pool, keeping an empty category in place while checking the other manager-backed categories, checking all pools while rarity is empty, and probing `modifiers` and `level_modifiers` independently. These corrections preserve the approved behavioral invariants and close test gaps without expanding consumer or gameplay scope.

---

### Task 1: Add the Upgrade-Catalog Contract and Minimal Ownership Path

**Files:**
- Create: `tools/verify/verify_data_access_upgrade_catalog_boundary.js`
- Create: `tools/verify/verify_data_access_upgrade_catalog.gd`
- Modify: `package.json`
- Modify: `scripts/core/data_manager.gd`
- Modify: `scripts/game/game_data.gd`
- Verify unchanged: every protected file listed in Global Constraints

**Interfaces:**
- Consumes: `DataPaths.UPGRADES_PATH`, `DataManager._load_json_document()`, `DataManager._get_dictionary_array()`, `GameData._get_pool_from_data_manager()`, `GameData._get_definition_from_data_manager()`, and `GameData._document_cache`.
- Produces: `DataManager.get_curse_choice_definitions() -> Array[Dictionary]`, ordered `DataManager.get_level_up_upgrade_definitions() -> Array[Dictionary]`, `DataManager.get_permanent_upgrade_definitions() -> Array[Dictionary]`, `DataManager.get_rarity_weights() -> Dictionary`, unchanged `GameData` signatures, and the two `verify:data-access-upgrade-catalog*` commands.

- [ ] **Step 1: Confirm the isolated starting state**

Run:

```powershell
git branch --show-current
git status --short
git log -3 --oneline --decorate
git diff origin/main...HEAD --stat
```

Expected:

- branch is `codex/stage5d-upgrade-catalog`;
- `bfc3625` is the only Stage 5D commit;
- the branch contains only the approved specification;
- any unexpected change stops implementation and is not overwritten.

- [ ] **Step 2: Prepare a fresh worktree for Godot without changing tracked files**

Check:

```powershell
Test-Path .godot\global_script_class_cache.cfg
git status --short
```

If the cache is absent, run this command once outside the managed sandbox:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --editor --path . --quit
```

Then run:

```powershell
git status --short
```

If exact new `.gd.uid` files appear, inspect each file and delete only those untracked generated files. Do not remove tracked UIDs, user files, `.godot` broadly, or any directory recursively. Expected final status: clean.

- [ ] **Step 3: Record the complete pre-change baseline**

Run Node/static checks:

```powershell
node tools/validate/check_text_encoding.js
node tools/validate/validate_enemy_configs.js
node tools/validate/validate_modifier_effects.js
npm run verify:data-access-status-pool-boundary
npm run verify:data-access-progression-goals-boundary
npm run verify:data-access-challenge-pools-boundary
```

Run every Godot command separately outside the managed sandbox:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_status_pool.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_progression_goals.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_challenge_pools.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_skill_growth_upgrade_pool.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_upgrade_pool_no_relic_fireball_god_mix.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_upgrade_pool_missing_rarity.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_result_unlock_cache_lifetime.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --quit
```

Expected: all commands exit `0`; all verifier scripts print `PASS`; startup output contains neither `SCRIPT ERROR` nor `ERROR`.

- [ ] **Step 4: Write the static boundary verifier**

Create `tools/verify/verify_data_access_upgrade_catalog_boundary.js` with this structure:

```javascript
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const dataManager = readTextFile(path.join(root, "scripts", "core", "data_manager.gd"));
const gameData = readTextFile(path.join(root, "scripts", "game", "game_data.gd"));
const upgradePool = readTextFile(path.join(root, "scripts", "upgrades", "upgrade_pool.gd"));
const saveManager = readTextFile(path.join(root, "scripts", "game", "save_manager.gd"));
const curseModal = readTextFile(path.join(root, "scripts", "ui", "modals", "run_choice_modal_controller.gd"));
const metaBuilder = readTextFile(path.join(root, "scripts", "ui", "screens", "meta_upgrade_view_model_builder.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const loadAll = functionBody(dataManager, "load_all");
const ownerCases = [
  ["_curse_choice_pool", "get_curse_choice_definitions"],
  ["_level_up_upgrade_pool", "get_level_up_upgrade_definitions"],
  ["_permanent_upgrade_pool", "get_permanent_upgrade_definitions"],
];

for (const [field, method] of ownerCases) {
  assert(dataManager.includes(`var ${field}: Array[Dictionary] = []`), `missing owner field ${field}`);
  assert(loadAll.includes(`${field}.clear()`), `reload must clear ${field}`);
  assert(functionBody(dataManager, method).includes(`return ${field}.duplicate(true)`), `${method} must deep-copy ${field}`);
}
assert(dataManager.includes("var _rarity_weights: Dictionary = {}"), "missing rarity owner field");
assert(loadAll.includes("_rarity_weights.clear()"), "reload must clear rarity weights");
assert(functionBody(dataManager, "get_rarity_weights").includes("return _rarity_weights.duplicate(true)"), "rarity accessor must deep-copy");
assert((loadAll.match(/_load_json_document\(UPGRADES_PATH\)/g) || []).length === 1, "upgrade document must load exactly once");
for (const marker of [
  "_curse_choice_pool = _get_dictionary_array(upgrades_document, CURSE_CHOICES_KEY, UPGRADES_PATH)",
  "_level_up_upgrade_pool = _get_dictionary_array(upgrades_document, LEVEL_UP_UPGRADES_KEY, UPGRADES_PATH)",
  "_permanent_upgrade_pool = _get_dictionary_array(upgrades_document, PERMANENT_UPGRADES_KEY, UPGRADES_PATH)",
  "_rarity_weights = rarity_weights_data.duplicate(true)",
  "_index_upgrade_definitions(upgrades_document, upgrade_key, UPGRADES_PATH)",
]) assert(loadAll.includes(marker), `load_all missing ${marker}`);
assert(!dataManager.includes("func get_upgrade_pool("), "do not introduce a string-keyed category facade");

const poolFacades = [
  ["get_curse_choice_pool", "get_curse_choice_definitions", "curse_choices"],
  ["get_level_up_upgrade_pool", "get_level_up_upgrade_definitions", "level_up_upgrades"],
  ["get_permanent_upgrade_pool", "get_permanent_upgrade_definitions", "permanent_upgrades"],
];
for (const [facade, owner, key] of poolFacades) {
  const body = functionBody(gameData, facade, "static func ");
  const manager = `_get_pool_from_data_manager("${owner}")`;
  const fallback = `_get_dictionary_array(UPGRADES_PATH, "${key}").duplicate(true)`;
  for (const marker of [manager, "if not data.is_empty()", "return data", fallback]) {
    assert(body.includes(marker), `${facade} missing ${marker}`);
  }
  assert(body.indexOf(manager) < body.indexOf(fallback), `${facade} must be manager-first`);
}

const permanent = functionBody(gameData, "get_permanent_upgrade", "static func ");
assert(permanent.includes('_get_pool_from_data_manager("get_permanent_upgrade_definitions")'), "permanent lookup must use the category-restricted manager pool");
assert(permanent.includes('return _find_by_id(data, upgrade_id)'), "permanent manager lookup must remain category-restricted");
assert(permanent.includes('_find_by_id(_get_array(UPGRADES_PATH, "permanent_upgrades"), upgrade_id).duplicate(true)'), "permanent fallback must stay category-scoped and isolated");

const rarity = functionBody(gameData, "get_rarity_weights", "static func ");
for (const marker of [
  '_get_data_manager()',
  'has_method("get_rarity_weights")',
  'data_manager.call("get_rarity_weights")',
  'if not weight_data.is_empty()',
  'return weight_data',
  '_load_document(UPGRADES_PATH)',
  'return fallback_weights.duplicate(true)',
]) assert(rarity.includes(marker), `rarity facade missing ${marker}`);

assert(upgradePool.includes("GameData.get_level_up_upgrade_pool()"), "UpgradePool must keep the level-up facade");
assert(upgradePool.includes("GameData.get_rarity_weights()"), "UpgradePool must keep the rarity facade");
assert(saveManager.includes("GameData.get_permanent_upgrade_pool()"), "SaveManager must keep the permanent pool facade");
assert(saveManager.includes("GameData.get_permanent_upgrade(upgrade_id)"), "SaveManager must keep the permanent lookup facade");
assert(curseModal.includes("GameData.get_curse_choice_pool()"), "curse UI must keep its facade");
assert(metaBuilder.includes("GameData.get_permanent_upgrade_pool()"), "meta UI must keep its facade");
for (const source of [upgradePool, saveManager, curseModal, metaBuilder]) {
  assert(!source.includes("DataManager"), "consumers must not depend directly on DataManager");
}

console.log("[verify_data_access_upgrade_catalog_boundary] PASS");
```

- [ ] **Step 5: Register both Stage 5D commands**

Add these entries beside the other data-access scripts in `package.json`:

```json
"verify:data-access-upgrade-catalog": "D:\\Godot\\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_upgrade_catalog.gd",
"verify:data-access-upgrade-catalog-boundary": "node tools\\verify\\verify_data_access_upgrade_catalog_boundary.js",
```

Run:

```powershell
npm run verify:data-access-upgrade-catalog-boundary
```

Expected RED: non-zero exit with `missing owner field _curse_choice_pool` or another missing Stage 5D owner contract. Syntax errors are not the intended failure.

- [ ] **Step 6: Write the runtime contract before production code**

Create `tools/verify/verify_data_access_upgrade_catalog.gd`. Use these exact cases and helpers; keep all mutations inside dedicated probe functions and restore state before assertions:

```gdscript
extends SceneTree

const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")
const GameDataScript := preload("res://scripts/game/game_data.gd")

const POOL_CASES: Array[Dictionary] = [
	{"key": "curse_choices", "field": "_curse_choice_pool", "owner": "get_curse_choice_definitions", "facade": "get_curse_choice_pool"},
	{"key": "level_up_upgrades", "field": "_level_up_upgrade_pool", "owner": "get_level_up_upgrade_definitions", "facade": "get_level_up_upgrade_pool"},
	{"key": "permanent_upgrades", "field": "_permanent_upgrade_pool", "owner": "get_permanent_upgrade_definitions", "facade": "get_permanent_upgrade_pool"},
]

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = root.get_node_or_null("DataManager")
	_expect(manager != null, "DataManager autoload exists")
	if manager == null:
		_finish()
		return
	for case: Dictionary in POOL_CASES:
		_expect(manager.has_method(String(case["owner"])), "owner exposes %s" % case["owner"])
	_expect(manager.has_method("get_rarity_weights"), "owner exposes get_rarity_weights")
	if _failed:
		_finish()
		return

	var document: Dictionary = JsonDataLoaderScript.load_dictionary(DataPathsScript.UPGRADES_PATH, "verify_data_access_upgrade_catalog")
	var sources: Dictionary = {}
	for case: Dictionary in POOL_CASES:
		sources[case["key"]] = _to_dictionary_array(document.get(case["key"], []))
	var source_weights: Dictionary = _dictionary(document.get("rarity_weights", {})).duplicate(true)
	GameDataScript._document_cache.clear()

	for case: Dictionary in POOL_CASES:
		var source: Array[Dictionary] = _to_dictionary_array(sources[case["key"]])
		var owner_pool: Array[Dictionary] = _owner_pool(manager, String(case["owner"]))
		var facade_pool: Array[Dictionary] = _facade_pool(String(case["facade"]))
		_expect(not source.is_empty(), "%s source is non-empty" % case["key"])
		_expect(owner_pool == source, "%s owner matches source" % case["key"])
		_expect(_ids(owner_pool) == _ids(source), "%s order matches source" % case["key"], _ids(owner_pool))
		_expect(facade_pool == source, "%s facade matches source" % case["key"])
	_expect(_owner_weights(manager) == source_weights, "owner rarity weights match source")
	_expect(GameDataScript.get_rarity_weights() == source_weights, "rarity facade matches source")
	_expect(not GameDataScript._document_cache.has(DataPathsScript.UPGRADES_PATH), "normal facades avoid JSON cache")

	var permanent_source: Array[Dictionary] = _to_dictionary_array(sources["permanent_upgrades"])
	for item: Dictionary in permanent_source:
		_expect(GameDataScript.get_permanent_upgrade(StringName(String(item.get("id", "")))) == item, "permanent lookup matches source")
	_expect(not GameDataScript._document_cache.has(DataPathsScript.UPGRADES_PATH), "normal permanent lookup avoids JSON cache")
	var permanent_probe: Dictionary = GameDataScript.get_permanent_upgrade(StringName(String(permanent_source[0].get("id", ""))))
	var permanent_probe_pool: Array[Dictionary] = [permanent_probe]
	_expect(_mutate_first_scope(permanent_probe_pool, "__stage5d_permanent_manager__"), "permanent manager lookup has nested scope")
	_expect(GameDataScript.get_permanent_upgrade(StringName(String(permanent_source[0].get("id", "")))) == permanent_source[0], "permanent manager lookup is isolated")
	_expect(GameDataScript.get_permanent_upgrade(&"__missing_stage5d__").is_empty(), "missing permanent lookup stays empty")

	_verify_manager_and_facade_isolation(manager, sources, source_weights)
	_verify_manager_source_and_independent_fallback(manager, sources, source_weights)
	_verify_full_fallback(manager, sources, source_weights)
	_finish()

func _verify_manager_and_facade_isolation(manager: Node, sources: Dictionary, source_weights: Dictionary) -> void:
	for case: Dictionary in POOL_CASES:
		var owner_probe: Array[Dictionary] = _owner_pool(manager, String(case["owner"]))
		var facade_probe: Array[Dictionary] = _facade_pool(String(case["facade"]))
		_expect(_mutate_first_scope(owner_probe, "__stage5d_owner__"), "%s owner has nested scope" % case["key"])
		_expect(_mutate_first_scope(facade_probe, "__stage5d_facade__"), "%s facade has nested scope" % case["key"])
		_expect(_owner_pool(manager, String(case["owner"])) == sources[case["key"]], "%s owner is isolated" % case["key"])
		_expect(_facade_pool(String(case["facade"])) == sources[case["key"]], "%s facade is isolated" % case["key"])
	var owner_weights: Dictionary = _owner_weights(manager)
	var facade_weights: Dictionary = GameDataScript.get_rarity_weights()
	_mutate_first_weight(owner_weights)
	_mutate_first_weight(facade_weights)
	_expect(_owner_weights(manager) == source_weights, "owner weights are isolated")
	_expect(GameDataScript.get_rarity_weights() == source_weights, "facade weights are isolated")

func _verify_manager_source_and_independent_fallback(manager: Node, sources: Dictionary, source_weights: Dictionary) -> void:
	var originals: Dictionary = {}
	for case: Dictionary in POOL_CASES:
		originals[case["field"]] = _owner_pool(manager, String(case["owner"]))
	var original_weights: Dictionary = _owner_weights(manager)

	for target: Dictionary in POOL_CASES:
		var sentinel: Array[Dictionary] = [{"id": "__stage5d_%s__" % target["key"], "modifiers": [{"scope": {"domain": "stage5d"}}]}]
		manager.set(String(target["field"]), sentinel.duplicate(true))
		GameDataScript._document_cache.clear()
		_expect(_facade_pool(String(target["facade"])) == sentinel, "%s facade returns manager sentinel" % target["key"])
		_expect(not GameDataScript._document_cache.has(DataPathsScript.UPGRADES_PATH), "%s manager path avoids cache" % target["key"])
		manager.set(String(target["field"]), (originals[target["field"]] as Array).duplicate(true))

	for target: Dictionary in POOL_CASES:
		var empty_pool: Array[Dictionary] = []
		manager.set(String(target["field"]), empty_pool)
		GameDataScript._document_cache.clear()
		_expect(_facade_pool(String(target["facade"])) == sources[target["key"]], "%s empty owner falls back" % target["key"])
		_expect(GameDataScript._document_cache.has(DataPathsScript.UPGRADES_PATH), "%s fallback uses cache" % target["key"])
		manager.set(String(target["field"]), (originals[target["field"]] as Array).duplicate(true))
		for other: Dictionary in POOL_CASES:
			if other["key"] == target["key"]:
				continue
			GameDataScript._document_cache.clear()
			_expect(_facade_pool(String(other["facade"])) == sources[other["key"]], "%s remains manager-backed" % other["key"])
			_expect(not GameDataScript._document_cache.has(DataPathsScript.UPGRADES_PATH), "%s avoids unrelated fallback" % other["key"])

	manager.set("_rarity_weights", {"__stage5d_weight__": 7})
	GameDataScript._document_cache.clear()
	_expect(GameDataScript.get_rarity_weights() == {"__stage5d_weight__": 7}, "rarity facade returns manager sentinel")
	_expect(not GameDataScript._document_cache.has(DataPathsScript.UPGRADES_PATH), "rarity manager path avoids cache")
	manager.set("_rarity_weights", {})
	GameDataScript._document_cache.clear()
	_expect(GameDataScript.get_rarity_weights() == source_weights, "empty owner weights fall back")
	_expect(GameDataScript._document_cache.has(DataPathsScript.UPGRADES_PATH), "rarity fallback uses cache")
	manager.set("_rarity_weights", original_weights.duplicate(true))
	GameDataScript._document_cache.clear()

func _verify_full_fallback(manager: Node, sources: Dictionary, source_weights: Dictionary) -> void:
	var original_name: StringName = manager.name
	var original_cache: Dictionary = GameDataScript._document_cache.duplicate(true)
	manager.name = &"Stage5DUnavailableDataManager"
	GameDataScript._document_cache.clear()
	var fallback_pools: Dictionary = {}
	for case: Dictionary in POOL_CASES:
		fallback_pools[case["key"]] = _facade_pool(String(case["facade"]))
	var fallback_weights: Dictionary = GameDataScript.get_rarity_weights()
	var loaded: bool = GameDataScript._document_cache.has(DataPathsScript.UPGRADES_PATH)
	var curse_source: Array[Dictionary] = _to_dictionary_array(sources["curse_choices"])
	var permanent_source: Array[Dictionary] = _to_dictionary_array(sources["permanent_upgrades"])
	var curse_id: StringName = StringName(String(curse_source[0].get("id", "")))
	var rejected_cross_category: bool = GameDataScript.get_permanent_upgrade(curse_id).is_empty()
	var permanent_id: StringName = StringName(String(permanent_source[0].get("id", "")))
	var fallback_permanent: Dictionary = GameDataScript.get_permanent_upgrade(permanent_id)
	var fallback_permanent_pool: Array[Dictionary] = [fallback_permanent]
	var permanent_mutated: bool = _mutate_first_scope(fallback_permanent_pool, "__stage5d_permanent_fallback__")
	for case: Dictionary in POOL_CASES:
		_mutate_first_scope(_to_dictionary_array(fallback_pools[case["key"]]), "__stage5d_fallback__")
	_mutate_first_weight(fallback_weights)
	var fresh_pools: Dictionary = {}
	for case: Dictionary in POOL_CASES:
		fresh_pools[case["key"]] = _facade_pool(String(case["facade"]))
	var fresh_weights: Dictionary = GameDataScript.get_rarity_weights()
	var fresh_permanent: Dictionary = GameDataScript.get_permanent_upgrade(permanent_id)
	manager.name = original_name
	GameDataScript._document_cache.clear()
	GameDataScript._document_cache.merge(original_cache, true)

	_expect(loaded, "full fallback loads upgrade document")
	_expect(rejected_cross_category, "permanent fallback rejects curse IDs")
	_expect(permanent_mutated, "permanent fallback exposes nested scope probe")
	_expect(fresh_permanent == permanent_source[0], "permanent lookup fallback is isolated")
	for case: Dictionary in POOL_CASES:
		_expect(fresh_pools[case["key"]] == sources[case["key"]], "%s fallback is isolated" % case["key"])
	_expect(fresh_weights == source_weights, "rarity fallback is isolated")

func _facade_pool(method_name: String) -> Array[Dictionary]:
	match method_name:
		"get_curse_choice_pool": return GameDataScript.get_curse_choice_pool()
		"get_level_up_upgrade_pool": return GameDataScript.get_level_up_upgrade_pool()
		"get_permanent_upgrade_pool": return GameDataScript.get_permanent_upgrade_pool()
	return []

func _owner_pool(manager: Node, method_name: String) -> Array[Dictionary]:
	return _to_dictionary_array(manager.call(method_name))

func _owner_weights(manager: Node) -> Dictionary:
	return _dictionary(manager.call("get_rarity_weights")).duplicate(true)

func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item: Variant in value:
			if item is Dictionary:
				result.append(item as Dictionary)
	return result

func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}

func _ids(pool: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for item: Dictionary in pool:
		result.append(String(item.get("id", "")))
	return result

func _mutate_first_scope(pool: Array[Dictionary], marker: String) -> bool:
	for item: Dictionary in pool:
		for list_key: String in ["modifiers", "level_modifiers"]:
			var outer: Array = item.get(list_key, []) as Array
			if outer.is_empty():
				continue
			var candidates: Array = outer[0] as Array if outer[0] is Array else outer
			if not candidates.is_empty() and candidates[0] is Dictionary:
				var modifier: Dictionary = candidates[0]
				var scope: Dictionary = modifier.get("scope", {}) as Dictionary
				scope[marker] = true
				return true
	return false

func _mutate_first_weight(weights: Dictionary) -> bool:
	if weights.is_empty():
		return false
	weights[weights.keys()[0]] = -999
	return true

func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_data_access_upgrade_catalog] FAIL %s actual=%s" % [label, str(actual)])

func _finish() -> void:
	if not _failed:
		print("[verify_data_access_upgrade_catalog] PASS")
	quit(1 if _failed else 0)
```

- [ ] **Step 7: Run the runtime verifier and observe RED**

Run directly outside the managed sandbox:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_upgrade_catalog.gd
```

Expected RED: exit `1` reporting missing `get_curse_choice_definitions`, `get_permanent_upgrade_definitions`, or `get_rarity_weights`. Parser errors, missing class-cache errors, and native crashes are not the intended RED.

- [ ] **Step 8: Add explicit owner state to `DataManager`**

Modify only the existing constant, field, clear, upgrade-load, and accessor groups in `scripts/core/data_manager.gd`.

Add canonical keys and reuse them in `UPGRADE_KEYS`:

```gdscript
const CURSE_CHOICES_KEY: String = "curse_choices"
const LEVEL_UP_UPGRADES_KEY: String = "level_up_upgrades"
const PERMANENT_UPGRADES_KEY: String = "permanent_upgrades"
const RARITY_WEIGHTS_KEY: String = "rarity_weights"
const UPGRADE_KEYS: Array[String] = [CURSE_CHOICES_KEY, LEVEL_UP_UPGRADES_KEY, PERMANENT_UPGRADES_KEY]
```

Add fields without removing either existing index:

```gdscript
var _curse_choice_pool: Array[Dictionary] = []
var _level_up_upgrade_pool: Array[Dictionary] = []
var _permanent_upgrade_pool: Array[Dictionary] = []
var _rarity_weights: Dictionary = {}
```

Clear them at the beginning of `load_all()`:

```gdscript
_curse_choice_pool.clear()
_level_up_upgrade_pool.clear()
_permanent_upgrade_pool.clear()
_rarity_weights.clear()
```

Immediately after the single existing `upgrades_document` load, populate all owner values and retain the indexing loop:

```gdscript
var upgrades_document: Dictionary = _load_json_document(UPGRADES_PATH)
_curse_choice_pool = _get_dictionary_array(upgrades_document, CURSE_CHOICES_KEY, UPGRADES_PATH)
_level_up_upgrade_pool = _get_dictionary_array(upgrades_document, LEVEL_UP_UPGRADES_KEY, UPGRADES_PATH)
_permanent_upgrade_pool = _get_dictionary_array(upgrades_document, PERMANENT_UPGRADES_KEY, UPGRADES_PATH)
var rarity_weights_value: Variant = upgrades_document.get(RARITY_WEIGHTS_KEY, {})
if rarity_weights_value is Dictionary:
	var rarity_weights_data: Dictionary = rarity_weights_value
	_rarity_weights = rarity_weights_data.duplicate(true)
else:
	push_error("[DataManager] Expected %s.%s to be an object." % [UPGRADES_PATH, RARITY_WEIGHTS_KEY])
for upgrade_key: String in UPGRADE_KEYS:
	_index_upgrade_definitions(upgrades_document, upgrade_key, UPGRADES_PATH)
```

Add or replace accessors:

```gdscript
func get_curse_choice_definitions() -> Array[Dictionary]:
	return _curse_choice_pool.duplicate(true)

func get_level_up_upgrade_definitions() -> Array[Dictionary]:
	return _level_up_upgrade_pool.duplicate(true)

func get_permanent_upgrade_definitions() -> Array[Dictionary]:
	return _permanent_upgrade_pool.duplicate(true)

func get_rarity_weights() -> Dictionary:
	return _rarity_weights.duplicate(true)
```

Do not delete `_level_up_upgrade_definitions`, change `DataDefinitionIndex`, or alter `get_upgrade_definition()`.

- [ ] **Step 9: Make all five `GameData` entry points manager-first**

Replace only the named method bodies in `scripts/game/game_data.gd`:

```gdscript
static func get_curse_choice_pool() -> Array[Dictionary]:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_curse_choice_definitions")
	if not data.is_empty():
		return data
	return _get_dictionary_array(UPGRADES_PATH, "curse_choices").duplicate(true)

static func get_level_up_upgrade_pool() -> Array[Dictionary]:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_level_up_upgrade_definitions")
	if not data.is_empty():
		return data
	return _get_dictionary_array(UPGRADES_PATH, "level_up_upgrades").duplicate(true)

static func get_permanent_upgrade(upgrade_id: StringName) -> Dictionary:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_permanent_upgrade_definitions")
	if not data.is_empty():
		return _find_by_id(data, upgrade_id)
	return _find_by_id(_get_array(UPGRADES_PATH, "permanent_upgrades"), upgrade_id).duplicate(true)

static func get_permanent_upgrade_pool() -> Array[Dictionary]:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_permanent_upgrade_definitions")
	if not data.is_empty():
		return data
	return _get_dictionary_array(UPGRADES_PATH, "permanent_upgrades").duplicate(true)

static func get_rarity_weights() -> Dictionary:
	var data_manager: Node = _get_data_manager()
	if data_manager != null and data_manager.has_method("get_rarity_weights"):
		var data: Variant = data_manager.call("get_rarity_weights")
		if data is Dictionary:
			var weight_data: Dictionary = data
			if not weight_data.is_empty():
				return weight_data
	var document: Dictionary = _load_document(UPGRADES_PATH)
	var weights: Variant = document.get("rarity_weights", {})
	if weights is Dictionary:
		var fallback_weights: Dictionary = weights
		return fallback_weights.duplicate(true)
	return {}
```

Do not modify `GameDataAccess`, any consumer, or any other facade.

- [ ] **Step 10: Run focused GREEN verification**

Run:

```powershell
npm run verify:data-access-upgrade-catalog-boundary
```

Then run separately outside the sandbox:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_upgrade_catalog.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_status_pool.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_progression_goals.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_challenge_pools.gd
```

Expected: new static/runtime verifiers and Stage 5A–5C runtime verifiers print `PASS`.

- [ ] **Step 11: Inspect Task 1 scope**

Run:

```powershell
git diff --check
git status --short
git diff -- package.json scripts/core/data_manager.gd scripts/game/game_data.gd tools/verify/verify_data_access_upgrade_catalog_boundary.js tools/verify/verify_data_access_upgrade_catalog.gd
git diff -- scripts/upgrades/upgrade_pool.gd scripts/upgrades/upgrade_selection_helper.gd scripts/game/save_manager.gd scripts/ui/modals/run_choice_modal_controller.gd scripts/ui/screens/meta_upgrade_view_model_builder.gd scripts/player/player_controller.gd data/upgrades/upgrades.json
```

Expected: the protected-file diff is empty and no generated UID file is staged. If explicitly authorized, commit only Task 1 files with:

```powershell
git commit -m "refactor: consolidate upgrade catalog data access"
```

Without explicit authorization, leave the verified work uncommitted.

### Task 2: Update Engineering Records and Run the Full Stage 5D Gate

**Files:**
- Modify: `docs/PROJECT_SYSTEMS_OVERVIEW.md`
- Modify: `docs/PROJECT_ENGINEERING_GUIDELINES.md`
- Modify: `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`
- Verify only: all Stage 5D production, test, plan, and specification files

**Interfaces:**
- Consumes: the four verified `DataManager` accessors and five unchanged manager-first `GameData` entry points from Task 1.
- Produces: accurate Stage 5D engineering records, full regression evidence, a protected-file-clean diff, and a review-ready branch.

- [ ] **Step 1: Update the systems overview**

Update only the data-ownership statements to record:

```markdown
Stage 5D 已收口 `upgrades.json` 的三个有序分类池和稀有度权重；`DataManager` 是正常运行所有者，`GameData` 保留稳定门面与独立 JSON fallback。升级选择、权重计算、UI、应用和存档消费者保持不变。
```

Remove upgrade category pools and rarity weights from the remaining normal-runtime fallback list. Do not claim that every consumer-owned JSON read or every `GameData` fallback has been removed.

- [ ] **Step 2: Update the engineering guideline status**

Extend the Stage 5 migration status with:

```markdown
Stage 5D 已收口升级分类池与稀有度权重，并保持五个 GameData 公共入口兼容；消费端重复 fallback 继续按证据单独处理。
```

Preserve the owner/facade/fallback rules, deep-copy rule, and Windows Godot execution guidance.

- [ ] **Step 3: Update the stability and boundary report**

Record all of these facts:

- `DataManager` owns the three ordered upgrade category pools and rarity weights;
- five `GameData` methods remain stable manager-first facades with JSON fallback;
- Stage 5D changes no upgrade rule, weight value, random call, UI flow, player application, configuration, or save result;
- remaining debt is limited to separately evidenced consumer-owned fallback or other unclaimed data domains;
- fresh worktrees require one editor scan to populate ignored global-class metadata before headless validation.

- [ ] **Step 4: Run the complete Stage 5D gate**

Run Node/static checks:

```powershell
node tools/validate/check_text_encoding.js
node tools/validate/validate_enemy_configs.js
node tools/validate/validate_modifier_effects.js
npm run verify:data-access-upgrade-catalog-boundary
npm run verify:data-access-status-pool-boundary
npm run verify:data-access-progression-goals-boundary
npm run verify:data-access-challenge-pools-boundary
```

Run Godot checks one at a time outside the managed sandbox:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_upgrade_catalog.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_status_pool.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_progression_goals.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_challenge_pools.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_skill_growth_upgrade_pool.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_upgrade_pool_no_relic_fireball_god_mix.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_upgrade_pool_missing_rarity.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_result_unlock_cache_lifetime.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --quit
```

Inspect startup output and fail the gate if it contains `SCRIPT ERROR` or `ERROR`, even if the process exit code is `0`.

Run final scope checks:

```powershell
git diff --check
git status --short
git diff --stat origin/main
git diff origin/main -- scripts/upgrades/upgrade_pool.gd scripts/upgrades/upgrade_selection_helper.gd scripts/game/save_manager.gd scripts/ui/modals/run_choice_modal_controller.gd scripts/ui/screens/meta_upgrade_view_model_builder.gd scripts/player/player_controller.gd data/upgrades/upgrades.json
```

Expected: every verifier exits `0`, every named test prints `PASS`, startup has no script errors, and the protected-file diff is empty.

- [ ] **Step 5: Request an independent whole-branch review**

Ask a fresh reviewer to compare `origin/main` with the complete Stage 5D branch and working tree, including untracked files. Focus the review on:

- one upgrade-document load while retaining both existing indexes;
- exact source order and deep isolation for all three pools;
- rarity-weight isolation and independent fallback;
- manager-source proof rather than equal-value inference;
- category-restricted permanent fallback;
- restoration of all temporary test state;
- absence of consumer, configuration, selection, UI, player, and save changes;
- documentation and rollback accuracy.

Resolve every verified Critical or Important issue with RED→GREEN evidence and rerun the affected gate plus the complete Stage 5D gate. Record Minor findings without scope expansion unless they invalidate a contract.

- [ ] **Step 6: Inspect the final diff and commit only with authorization**

Run:

```powershell
git diff --check
git status --short
git diff --stat origin/main
```

If the user authorizes one combined implementation commit, stage exactly the approved Stage 5D implementation, verification, plan, and engineering-document files and run:

```powershell
git commit -m "refactor: consolidate upgrade catalog data access"
```

Do not push or create a pull request without separate explicit authorization.

## Performance Success Metric

Not applicable. Stage 5D changes configuration ownership and validation only. It makes no frame-time, allocation, startup-duration, or memory claim, and no performance threshold may be invented for completion.

## Rollback Procedure

If Stage 5D must be reverted before integration:

1. remove the four new owner fields, canonical keys, clear steps, extraction steps, and new accessors from `DataManager`;
2. restore `get_level_up_upgrade_definitions()` to `_get_definition_values(_level_up_upgrade_definitions)`;
3. restore the five `GameData` methods to their Stage 5C bodies;
4. remove the two Stage 5D verifiers and package entries;
5. revert only Stage 5D statements in the three engineering documents;
6. rerun Stage 5A–5C, upgrade-pool, result-unlock, encoding, and headless-startup checks.

If committed, use a normal revert commit after inspecting the exact range. Do not reset, force-push, modify upgrade data, or touch save files. JSON fallback requires no data migration.

## Completion Report Template

```markdown
## 本批次结果
三个升级分类池与稀有度权重的正常运行读取已由 DataManager 所有，五个 GameData 门面和 JSON fallback 保持兼容。

## 修改范围
- DataManager：一次读取升级文档，持有三个有序池、稀有度权重和原有索引。
- GameData：五个现有入口改为 manager-first，并深拷贝 fallback。
- 验证：新增静态边界与运行时 owner/facade/fallback 契约。
- 文档：更新 Stage 5D 状态与剩余数据债务。

## 保持不变
- 升级 ID、分类、顺序、权重、数值、随机选择、UI、应用和存档。
- 五个 GameData 公共入口。
- 所有受保护消费者与 upgrades.json。

## 验证证据
列出实际执行命令、退出码、关键 PASS 输出，以及启动日志中无 SCRIPT ERROR/ERROR 的检查结果。

## 性能对比
不适用。本批次不声明性能提升。

## 遗留风险
只列有代码或测试证据的消费端 fallback 或验证缺口。

## 下一步建议
最多三个选项，并明确推荐一个最小、独立、可回滚的数据域或观测批次。
```
