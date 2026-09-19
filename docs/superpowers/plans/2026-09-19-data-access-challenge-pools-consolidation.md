# Stage 5C Data Access Challenge Pools Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `DataManager` the normal-runtime owner of the ordered daily and weekly challenge pools while preserving both `GameData` facades, JSON fallbacks, challenge behavior, and save compatibility.

**Architecture:** `DataManager.load_all()` reads `challenges.json` once, stores its daily and weekly arrays separately, and exposes deep-copy accessors. Each existing `GameData` method queries its matching manager accessor first and otherwise returns a deeply duplicated array from the existing JSON cache. `RunProgressionService`, `SaveManager`, and challenge configuration remain unchanged.

**Tech Stack:** Godot 4.6.3, typed GDScript, Node.js CommonJS verification scripts, JSON configuration, direct Godot headless verification on Windows.

**Spec:** `docs/superpowers/specs/2026-09-19-data-access-challenge-pools-consolidation-design.md`

## Global Constraints

- Do not change challenge IDs, category membership, ordering, character/map requirements, display names, modifiers, scopes, or numeric values.
- Do not modify `scripts/game/run_progression_service.gd`, `scripts/game/save_manager.gd`, or `data/progression/challenges.json`.
- Preserve `GameData.get_daily_challenge_pool() -> Array[Dictionary]` and `GameData.get_weekly_challenge_pool() -> Array[Dictionary]`.
- Preserve JSON fallback independently for each pool when its manager result is unavailable or empty.
- Manager and facade results must deeply isolate nested dictionaries and arrays.
- Do not migrate upgrade pools, rarity weights, or other remaining data domains.
- Do not add a challenge registry, repository, resource type, or generic data-access abstraction.
- Run every Godot command one at a time as a direct executable invocation inside the managed Windows sandbox; do not launch Godot through npm there.
- Do not commit, push, or create a pull request without explicit user authorization.

## Review Focus

- A facade that calls its manager accessor but discards the result must fail both static and runtime source-path checks.
- Mutating nested `modifiers` or `scope` data from manager, facade, or fallback output must not affect a later read.
- An empty daily manager pool must fall back without forcing a valid weekly manager pool onto JSON, and the inverse must also hold.
- Daily and weekly arrays must remain separate and preserve their exact challenge and modifier order.
- The autoload name and temporary manager fields used by tests must be restored before any final assertion or exit.

---

### Task 1: Add the Challenge-Pool Contract and Minimal Ownership Path

**Files:**
- Create: `tools/verify/verify_data_access_challenge_pools_boundary.js`
- Create: `tools/verify/verify_data_access_challenge_pools.gd`
- Modify: `package.json`
- Modify: `scripts/core/data_manager.gd`
- Modify: `scripts/game/game_data.gd`
- Verify unchanged: `scripts/game/run_progression_service.gd`
- Verify unchanged: `scripts/game/save_manager.gd`
- Verify unchanged: `data/progression/challenges.json`

**Interfaces:**
- Consumes: `DataPaths.CHALLENGES_PATH`, `DataManager._load_json_document()`, `DataManager._get_dictionary_array()`, `GameData._get_pool_from_data_manager()`, and the existing `GameData` document cache.
- Produces: `DataManager.get_daily_challenge_definitions() -> Array[Dictionary]`, `DataManager.get_weekly_challenge_definitions() -> Array[Dictionary]`, unchanged challenge-pool facade signatures, `npm run verify:data-access-challenge-pools-boundary`, and `npm run verify:data-access-challenge-pools`.

- [ ] **Step 1: Confirm the clean Stage 5C starting state**

Run:

```powershell
git branch --show-current
git status --short
git log -3 --oneline --decorate
git diff origin/main...HEAD --stat
```

Expected:

- branch is `codex/stage5c-challenge-pools`;
- the only branch-only commit is the approved Stage 5C specification until this plan is committed;
- no production or test file is modified;
- any unexpected user change stops implementation for review and is not overwritten.

- [ ] **Step 2: Record the pre-change regression baseline**

Run Node/static checks:

```powershell
node tools/validate/check_text_encoding.js
node tools/validate/validate_enemy_configs.js
node tools/validate/validate_modifier_effects.js
npm run verify:data-access-status-pool-boundary
npm run verify:data-access-progression-goals-boundary
npm run verify:result-screen-diagnostic-call
```

Run these Godot commands separately:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_status_pool.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_progression_goals.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_result_unlock_cache_lifetime.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --quit
```

Expected: every command exits `0`; both prior Stage 5 runtime verifiers print `PASS`; record any pre-existing warning before adding Stage 5C code.

- [ ] **Step 3: Create the failing static boundary verifier**

Create `tools/verify/verify_data_access_challenge_pools_boundary.js`:

```javascript
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const dataManager = readTextFile(path.join(root, "scripts", "core", "data_manager.gd"));
const gameData = readTextFile(path.join(root, "scripts", "game", "game_data.gd"));
const progression = readTextFile(path.join(root, "scripts", "game", "run_progression_service.gd"));
const saveManager = readTextFile(path.join(root, "scripts", "game", "save_manager.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const loadAllBody = functionBody(dataManager, "load_all");
const dailyManagerBody = functionBody(dataManager, "get_daily_challenge_definitions");
const weeklyManagerBody = functionBody(dataManager, "get_weekly_challenge_definitions");
const dailyFacadeBody = functionBody(gameData, "get_daily_challenge_pool", "static func ");
const weeklyFacadeBody = functionBody(gameData, "get_weekly_challenge_pool", "static func ");

assert(
  dataManager.includes("const CHALLENGES_PATH: String = DataPathsScript.CHALLENGES_PATH"),
  "DataManager must register the canonical challenge path.",
);
assert(dataManager.includes('const DAILY_CHALLENGES_KEY: String = "daily_challenges"'), "Daily key must stay canonical.");
assert(dataManager.includes('const WEEKLY_CHALLENGES_KEY: String = "weekly_challenges"'), "Weekly key must stay canonical.");
assert(dataManager.includes("var _daily_challenge_definitions: Array[Dictionary] = []"), "DataManager must own the daily pool.");
assert(dataManager.includes("var _weekly_challenge_definitions: Array[Dictionary] = []"), "DataManager must own the weekly pool.");
assert(loadAllBody.includes("_daily_challenge_definitions.clear()"), "Reload must clear the daily pool.");
assert(loadAllBody.includes("_weekly_challenge_definitions.clear()"), "Reload must clear the weekly pool.");
const challengeLoads = loadAllBody.match(/_load_json_document\(CHALLENGES_PATH\)/g) || [];
assert(challengeLoads.length === 1, "DataManager must load the challenge document exactly once.");
assert(
  loadAllBody.includes("_daily_challenge_definitions = _get_dictionary_array(challenges_document, DAILY_CHALLENGES_KEY, CHALLENGES_PATH)"),
  "DataManager must extract the ordered daily pool.",
);
assert(
  loadAllBody.includes("_weekly_challenge_definitions = _get_dictionary_array(challenges_document, WEEKLY_CHALLENGES_KEY, CHALLENGES_PATH)"),
  "DataManager must extract the ordered weekly pool.",
);
assert(
  dailyManagerBody.includes("return _daily_challenge_definitions.duplicate(true)"),
  "Daily manager accessor must deeply isolate its pool.",
);
assert(
  weeklyManagerBody.includes("return _weekly_challenge_definitions.duplicate(true)"),
  "Weekly manager accessor must deeply isolate its pool.",
);

function verifyFacade(body, managerMethod, key, label) {
  assert(body, `GameData ${label} facade must exist.`);
  for (const marker of [
    `_get_pool_from_data_manager("${managerMethod}")`,
    "if not data.is_empty()",
    "return data",
    `return _get_dictionary_array(CHALLENGES_PATH, "${key}").duplicate(true)`,
  ]) {
    assert(body.includes(marker), `GameData ${label} facade is missing: ${marker}`);
  }
  assert(
    body.indexOf(`_get_pool_from_data_manager("${managerMethod}")`) <
      body.indexOf(`return _get_dictionary_array(CHALLENGES_PATH, "${key}").duplicate(true)`),
    `GameData ${label} facade must keep manager-first ordering.`,
  );
  for (const forbiddenSource of ["JsonDataLoader", "FileAccess", "JSON.new", "load_dictionary("]) {
    assert(!body.includes(forbiddenSource), `GameData ${label} facade must not add a third source: ${forbiddenSource}`);
  }
}

verifyFacade(dailyFacadeBody, "get_daily_challenge_definitions", "daily_challenges", "daily challenge");
verifyFacade(weeklyFacadeBody, "get_weekly_challenge_definitions", "weekly_challenges", "weekly challenge");
assert(progression.includes("GameData.get_daily_challenge_pool()"), "Progression must keep the daily GameData facade.");
assert(progression.includes("GameData.get_weekly_challenge_pool()"), "Progression must keep the weekly GameData facade.");
assert(!progression.includes("DataManager"), "RunProgressionService must not depend directly on DataManager.");
assert(!saveManager.includes("DataManager"), "SaveManager must not depend directly on DataManager.");

console.log("[verify_data_access_challenge_pools_boundary] PASS");
```

- [ ] **Step 4: Register the focused commands**

Add near the other Stage 5 scripts in `package.json`:

```json
"verify:data-access-challenge-pools": "D:\\Godot\\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_challenge_pools.gd",
"verify:data-access-challenge-pools-boundary": "node tools\\verify\\verify_data_access_challenge_pools_boundary.js"
```

Do not reorder or reformat unrelated scripts.

- [ ] **Step 5: Run the static verifier and observe RED**

Run:

```powershell
npm run verify:data-access-challenge-pools-boundary
```

Expected: FAIL on the missing canonical challenge path in `DataManager`. A syntax or missing-file error is not the intended failure.

- [ ] **Step 6: Create the failing runtime verifier**

Create `tools/verify/verify_data_access_challenge_pools.gd`:

```gdscript
extends SceneTree


const DataPathsScript := preload("res://scripts/core/data_paths.gd")
const JsonDataLoaderScript := preload("res://scripts/core/json_data_loader.gd")
const GameDataScript := preload("res://scripts/game/game_data.gd")


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var data_manager: Node = root.get_node_or_null("DataManager")
	_expect(data_manager != null, "DataManager autoload exists")
	if data_manager == null:
		_finish()
		return

	for method_name: String in ["get_daily_challenge_definitions", "get_weekly_challenge_definitions"]:
		_expect(data_manager.has_method(method_name), "DataManager exposes %s" % method_name)
	if not data_manager.has_method("get_daily_challenge_definitions") or not data_manager.has_method("get_weekly_challenge_definitions"):
		_finish()
		return

	var source_document: Dictionary = JsonDataLoaderScript.load_dictionary(
		DataPathsScript.CHALLENGES_PATH,
		"verify_data_access_challenge_pools"
	)
	var source_daily: Array[Dictionary] = _to_dictionary_array(source_document.get("daily_challenges", []))
	var source_weekly: Array[Dictionary] = _to_dictionary_array(source_document.get("weekly_challenges", []))
	var manager_daily: Array[Dictionary] = _call_pool(data_manager, "get_daily_challenge_definitions")
	var manager_weekly: Array[Dictionary] = _call_pool(data_manager, "get_weekly_challenge_definitions")

	GameDataScript._document_cache.clear()
	var facade_daily: Array[Dictionary] = GameDataScript.get_daily_challenge_pool()
	var facade_weekly: Array[Dictionary] = GameDataScript.get_weekly_challenge_pool()

	_expect(not source_daily.is_empty(), "source daily pool is non-empty")
	_expect(not source_weekly.is_empty(), "source weekly pool is non-empty")
	_expect(manager_daily == source_daily, "DataManager daily values match source")
	_expect(manager_weekly == source_weekly, "DataManager weekly values match source")
	_expect(_signatures(manager_daily) == _signatures(source_daily), "daily order and modifiers match source", _signatures(manager_daily))
	_expect(_signatures(manager_weekly) == _signatures(source_weekly), "weekly order and modifiers match source", _signatures(manager_weekly))
	_expect(facade_daily == manager_daily, "daily facade matches DataManager")
	_expect(facade_weekly == manager_weekly, "weekly facade matches DataManager")
	_expect(
		not GameDataScript._document_cache.has(DataPathsScript.CHALLENGES_PATH),
		"normal challenge facades do not enter the JSON cache"
	)

	_verify_manager_isolation(data_manager, source_daily, source_weekly)
	_verify_facade_isolation(data_manager, source_daily, source_weekly)
	_verify_independent_empty_pool_fallback(data_manager, manager_daily, manager_weekly, source_daily, source_weekly)
	_verify_full_fallback(data_manager, manager_daily, manager_weekly, source_daily, source_weekly)

	_finish()


func _verify_manager_isolation(data_manager: Node, source_daily: Array[Dictionary], source_weekly: Array[Dictionary]) -> void:
	var daily_probe: Array[Dictionary] = _call_pool(data_manager, "get_daily_challenge_definitions")
	var weekly_probe: Array[Dictionary] = _call_pool(data_manager, "get_weekly_challenge_definitions")
	_expect(_mutate_first_scope(daily_probe, "__stage5c_daily_manager__"), "daily manager pool has nested scope")
	_expect(_mutate_first_scope(weekly_probe, "__stage5c_weekly_manager__"), "weekly manager pool has nested scope")
	_expect(_call_pool(data_manager, "get_daily_challenge_definitions") == source_daily, "daily manager output is deeply isolated")
	_expect(_call_pool(data_manager, "get_weekly_challenge_definitions") == source_weekly, "weekly manager output is deeply isolated")


func _verify_facade_isolation(data_manager: Node, source_daily: Array[Dictionary], source_weekly: Array[Dictionary]) -> void:
	var daily_probe: Array[Dictionary] = GameDataScript.get_daily_challenge_pool()
	var weekly_probe: Array[Dictionary] = GameDataScript.get_weekly_challenge_pool()
	_expect(_mutate_first_scope(daily_probe, "__stage5c_daily_facade__"), "daily facade pool has nested scope")
	_expect(_mutate_first_scope(weekly_probe, "__stage5c_weekly_facade__"), "weekly facade pool has nested scope")
	_expect(GameDataScript.get_daily_challenge_pool() == source_daily, "daily facade output is deeply isolated")
	_expect(GameDataScript.get_weekly_challenge_pool() == source_weekly, "weekly facade output is deeply isolated")
	_expect(_call_pool(data_manager, "get_daily_challenge_definitions") == source_daily, "daily facade mutation does not affect DataManager")
	_expect(_call_pool(data_manager, "get_weekly_challenge_definitions") == source_weekly, "weekly facade mutation does not affect DataManager")


func _verify_independent_empty_pool_fallback(
	data_manager: Node,
	manager_daily: Array[Dictionary],
	manager_weekly: Array[Dictionary],
	source_daily: Array[Dictionary],
	source_weekly: Array[Dictionary]
) -> void:
	var empty_pool: Array[Dictionary] = []
	data_manager.set("_daily_challenge_definitions", empty_pool)
	GameDataScript._document_cache.clear()
	var daily_fallback: Array[Dictionary] = GameDataScript.get_daily_challenge_pool()
	var daily_used_fallback: bool = GameDataScript._document_cache.has(DataPathsScript.CHALLENGES_PATH)
	GameDataScript._document_cache.clear()
	var weekly_still_manager: Array[Dictionary] = GameDataScript.get_weekly_challenge_pool()
	var weekly_avoided_fallback: bool = not GameDataScript._document_cache.has(DataPathsScript.CHALLENGES_PATH)
	data_manager.set("_daily_challenge_definitions", manager_daily.duplicate(true))

	data_manager.set("_weekly_challenge_definitions", empty_pool)
	GameDataScript._document_cache.clear()
	var weekly_fallback: Array[Dictionary] = GameDataScript.get_weekly_challenge_pool()
	var weekly_used_fallback: bool = GameDataScript._document_cache.has(DataPathsScript.CHALLENGES_PATH)
	GameDataScript._document_cache.clear()
	var daily_still_manager: Array[Dictionary] = GameDataScript.get_daily_challenge_pool()
	var daily_avoided_fallback: bool = not GameDataScript._document_cache.has(DataPathsScript.CHALLENGES_PATH)
	data_manager.set("_weekly_challenge_definitions", manager_weekly.duplicate(true))
	GameDataScript._document_cache.clear()

	_expect(daily_fallback == source_daily and daily_used_fallback, "empty daily manager pool falls back independently")
	_expect(weekly_still_manager == source_weekly and weekly_avoided_fallback, "valid weekly manager pool remains manager-backed")
	_expect(weekly_fallback == source_weekly and weekly_used_fallback, "empty weekly manager pool falls back independently")
	_expect(daily_still_manager == source_daily and daily_avoided_fallback, "valid daily manager pool remains manager-backed")


func _verify_full_fallback(
	data_manager: Node,
	manager_daily: Array[Dictionary],
	manager_weekly: Array[Dictionary],
	source_daily: Array[Dictionary],
	source_weekly: Array[Dictionary]
) -> void:
	var original_manager_name: StringName = data_manager.name
	data_manager.name = &"Stage5CUnavailableDataManager"
	GameDataScript._document_cache.clear()
	var fallback_daily: Array[Dictionary] = GameDataScript.get_daily_challenge_pool()
	var fallback_weekly: Array[Dictionary] = GameDataScript.get_weekly_challenge_pool()
	var fallback_loaded_document: bool = GameDataScript._document_cache.has(DataPathsScript.CHALLENGES_PATH)
	var daily_mutated: bool = _mutate_first_scope(fallback_daily, "__stage5c_daily_fallback__")
	var weekly_mutated: bool = _mutate_first_scope(fallback_weekly, "__stage5c_weekly_fallback__")
	var fresh_fallback_daily: Array[Dictionary] = GameDataScript.get_daily_challenge_pool()
	var fresh_fallback_weekly: Array[Dictionary] = GameDataScript.get_weekly_challenge_pool()
	data_manager.name = original_manager_name
	GameDataScript._document_cache.clear()

	_expect(fallback_loaded_document, "fallback enters the challenge JSON cache")
	_expect(daily_mutated and weekly_mutated, "fallback pools expose nested scope probes")
	_expect(fresh_fallback_daily == source_daily, "daily fallback output is deeply isolated")
	_expect(fresh_fallback_weekly == source_weekly, "weekly fallback output is deeply isolated")
	_expect(GameDataScript.get_daily_challenge_pool() == manager_daily, "restored daily facade is manager-backed")
	_expect(GameDataScript.get_weekly_challenge_pool() == manager_weekly, "restored weekly facade is manager-backed")


func _mutate_first_scope(pool: Array[Dictionary], marker: String) -> bool:
	if pool.is_empty():
		return false
	var modifiers: Array = pool[0].get("modifiers", []) as Array
	if modifiers.is_empty() or not (modifiers[0] is Dictionary):
		return false
	var modifier: Dictionary = modifiers[0]
	var scope: Dictionary = modifier.get("scope", {}) as Dictionary
	scope[marker] = true
	return true


func _call_pool(data_manager: Node, method_name: String) -> Array[Dictionary]:
	return _to_dictionary_array(data_manager.call(method_name))


func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item_variant: Variant in value:
		if item_variant is Dictionary:
			result.append(item_variant as Dictionary)
	return result


func _signatures(pool: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for challenge: Dictionary in pool:
		result.append({
			"challenge_id": String(challenge.get("challenge_id", "")),
			"modifiers": (challenge.get("modifiers", []) as Array).duplicate(true),
		})
	return result


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_data_access_challenge_pools] FAIL %s actual=%s" % [label, str(actual)])


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_challenge_pools] PASS")
	quit(1 if _failed else 0)
```

- [ ] **Step 7: Run the runtime verifier and observe RED**

Run directly:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_challenge_pools.gd
```

Expected: exit `1` with `DataManager exposes get_daily_challenge_definitions` and/or `get_weekly_challenge_definitions`. Parser errors or native crashes are not the intended RED state.

- [ ] **Step 8: Add the minimal `DataManager` ownership path**

Modify `scripts/core/data_manager.gd` in the existing constant, field, clear, load, and accessor groups:

```gdscript
const CHALLENGES_PATH: String = DataPathsScript.CHALLENGES_PATH
```

```gdscript
const DAILY_CHALLENGES_KEY: String = "daily_challenges"
const WEEKLY_CHALLENGES_KEY: String = "weekly_challenges"
```

```gdscript
var _daily_challenge_definitions: Array[Dictionary] = []
var _weekly_challenge_definitions: Array[Dictionary] = []
```

Inside `load_all()` with the other clear operations:

```gdscript
_daily_challenge_definitions.clear()
_weekly_challenge_definitions.clear()
```

Inside `load_all()` after the existing complete-document loads:

```gdscript
var challenges_document: Dictionary = _load_json_document(CHALLENGES_PATH)
_daily_challenge_definitions = _get_dictionary_array(challenges_document, DAILY_CHALLENGES_KEY, CHALLENGES_PATH)
_weekly_challenge_definitions = _get_dictionary_array(challenges_document, WEEKLY_CHALLENGES_KEY, CHALLENGES_PATH)
```

Add near the other pool accessors:

```gdscript
func get_daily_challenge_definitions() -> Array[Dictionary]:
	return _daily_challenge_definitions.duplicate(true)


func get_weekly_challenge_definitions() -> Array[Dictionary]:
	return _weekly_challenge_definitions.duplicate(true)
```

Do not index, merge, filter, or reorder either pool.

- [ ] **Step 9: Make both `GameData` facades manager-first**

Replace only the two existing method bodies in `scripts/game/game_data.gd`:

```gdscript
static func get_daily_challenge_pool() -> Array[Dictionary]:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_daily_challenge_definitions")
	if not data.is_empty():
		return data
	return _get_dictionary_array(CHALLENGES_PATH, "daily_challenges").duplicate(true)


static func get_weekly_challenge_pool() -> Array[Dictionary]:
	var data: Array[Dictionary] = _get_pool_from_data_manager("get_weekly_challenge_definitions")
	if not data.is_empty():
		return data
	return _get_dictionary_array(CHALLENGES_PATH, "weekly_challenges").duplicate(true)
```

Do not modify `GameDataAccess`, the document cache, or any other facade.

- [ ] **Step 10: Run focused GREEN verification**

Run:

```powershell
npm run verify:data-access-challenge-pools-boundary
```

Then run each Godot command separately:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_challenge_pools.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_status_pool.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_progression_goals.gd
```

Expected: the new static and runtime verifiers print `PASS`; Stage 5A and Stage 5B runtime contracts remain green.

- [ ] **Step 11: Inspect Task 1 scope and commit only with authorization**

Run:

```powershell
git diff --check
git diff -- package.json scripts/core/data_manager.gd scripts/game/game_data.gd tools/verify/verify_data_access_challenge_pools_boundary.js tools/verify/verify_data_access_challenge_pools.gd
git diff -- scripts/game/run_progression_service.gd scripts/game/save_manager.gd data/progression/challenges.json
git status --short
```

Expected: the protected-file diff is empty; no progression, save, challenge data, upgrade, UI, or unrelated formatting change is present.

If the user has explicitly authorized commits, stage only the five Task 1 files and run:

```powershell
git commit -m "refactor: consolidate challenge pool data access"
```

Without explicit authorization, leave the verified files uncommitted.

### Task 2: Update Engineering Records and Run the Full Stage 5C Gate

**Files:**
- Modify: `docs/PROJECT_SYSTEMS_OVERVIEW.md`
- Modify: `docs/PROJECT_ENGINEERING_GUIDELINES.md`
- Modify: `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`
- Verify only: all Stage 5C production, test, plan, and specification files

**Interfaces:**
- Consumes: both verified manager accessors and both manager-first `GameData` challenge facades from Task 1.
- Produces: accurate Stage 5C engineering records, complete verification evidence, and a review-ready branch.

- [ ] **Step 1: Update the systems overview**

Update the data-configuration description to state:

```markdown
`DataManager` 是运行时配置所有者，负责启动加载、索引或持有有序配置池，并通过深拷贝 accessor 输出；`GameData` 是稳定消费门面。Stage 5A 已收口状态池，Stage 5B 已收口进度目标文档，Stage 5C 已收口每日/每周挑战池；无可用 autoload 或有效结果时仍保留 JSON fallback。升级分类池、稀有度权重和已验证的消费端 fallback 继续按独立批次处理。
```

Keep existing diagrams and tables. Do not claim that every `GameData` fallback is consolidated.

- [ ] **Step 2: Update the engineering guideline status**

Update only the Stage 5 migration-status wording to:

```markdown
DataManager/GameData 读取路径收口：Stage 5A 已收口状态池，Stage 5B 已收口进度目标文档，Stage 5C 已收口每日/每周挑战池；其余数据域继续按契约测试逐项迁移。
```

Preserve the owner/facade/fallback rules and managed-Windows-sandbox guidance.

- [ ] **Step 3: Update the stability and boundary report**

Record all of the following facts:

- `DataManager` owns the normal-runtime daily and weekly challenge pools;
- the two `GameData` methods remain stable facades and JSON fallbacks;
- challenge pools are removed from the remaining fallback-domain list;
- upgrade category pools, rarity weights, and verified consumer-owned fallbacks remain debt;
- Stage 5C changes no challenge rule, completion behavior, configuration value, or save result.

- [ ] **Step 4: Run the complete Stage 5C verification gate**

Run Node/static checks:

```powershell
node tools/validate/check_text_encoding.js
node tools/validate/validate_enemy_configs.js
node tools/validate/validate_modifier_effects.js
npm run verify:data-access-challenge-pools-boundary
npm run verify:data-access-status-pool-boundary
npm run verify:data-access-progression-goals-boundary
npm run verify:result-screen-diagnostic-call
```

Run Godot checks one at a time:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_challenge_pools.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_status_pool.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_progression_goals.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_result_unlock_cache_lifetime.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --quit
```

Run final scope checks:

```powershell
git diff --check
git status --short
git diff --stat origin/main
git diff origin/main -- scripts/game/run_progression_service.gd scripts/game/save_manager.gd data/progression/challenges.json data/upgrades/upgrades.json
```

Expected:

- every command exits `0`;
- all three Stage 5 runtime verifiers print `PASS`;
- result-unlock verification and headless startup complete without a new Stage 5C warning;
- the protected-file diff is empty;
- only demonstrably pre-existing or environmental failures may remain, and each must be reported.

- [ ] **Step 5: Request an independent whole-branch review**

Ask a fresh reviewer to compare `origin/main` with the complete Stage 5C working tree, including untracked files, and focus on:

- one-load/two-pool ownership and exact source equivalence;
- daily/weekly independence when either manager pool is empty;
- nested modifier and scope isolation on manager, facade, and fallback paths;
- proof that normal paths avoid and fallback paths use the JSON cache;
- guaranteed restoration of the autoload name and temporarily changed manager fields;
- absence of progression, save, challenge-data, and upgrade behavior changes;
- documentation accuracy and rollback completeness.

Resolve every verified Critical or Important issue in one fix pass, using RED→GREEN for each test change, then rerun the affected test and the complete gate. Record Minor findings without expanding scope unless they invalidate a stated contract.

- [ ] **Step 6: Inspect the final diff and commit documentation only with authorization**

Run:

```powershell
git diff --check
git status --short
git diff --stat
```

If Task 1 was committed separately and the user authorizes a documentation commit:

```powershell
git add docs/PROJECT_SYSTEMS_OVERVIEW.md docs/PROJECT_ENGINEERING_GUIDELINES.md docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md
git commit -m "docs: record stage 5c challenge pool ownership"
```

If the user authorizes one combined implementation commit, stage exactly all approved Stage 5C files and use:

```powershell
git commit -m "refactor: consolidate challenge pool data access"
```

Do not push or create a pull request without separate explicit authorization.

## Performance Success Metric

Not applicable. Stage 5C changes configuration ownership and validation only. It does not claim lower frame time, allocation count, startup duration, or memory use; no performance threshold may be invented for completion.

## Rollback Procedure

If Stage 5C must be reverted before integration:

1. remove the challenge path, two key constants, two fields, clear steps, one document load, extraction steps, and two accessors from `scripts/core/data_manager.gd`;
2. restore both `GameData` challenge methods to their original direct `_get_dictionary_array()` bodies;
3. remove both Stage 5C verifier files and their package entries;
4. revert only the Stage 5C statements in the three engineering documents;
5. rerun Stage 5A, Stage 5B, result-unlock, encoding, and headless-startup verification.

If Stage 5C was committed, use a normal revert commit after inspecting the exact range. Do not reset, force-push, delete challenge data, or alter save files. The preserved `GameData` JSON path requires no data migration.

## Completion Report Template

Use this exact structure after the gate passes:

```markdown
## 本批次结果
每日与每周挑战池的正常运行读取已由 DataManager 所有，两个 GameData 门面和 JSON fallback 保持兼容。

## 修改范围
- DataManager：单次加载挑战文档，分别持有并深拷贝输出两个有序池。
- GameData：两个现有挑战池方法改为 manager-first，并深拷贝 fallback。
- 验证：新增静态边界和运行时双池四路径验证。
- 文档：更新 Stage 5C 状态与剩余数据域。

## 保持不变
- 挑战 ID、类别、顺序、规则、modifier、完成逻辑和存档结果。
- 两个 GameData 公共方法。
- RunProgressionService、SaveManager 和 challenges.json。

## 验证证据
列出实际执行的每条命令、退出码和关键 PASS 输出。

## 性能对比
不适用。本批次不声明性能提升。

## 遗留风险
只列具有代码或测试证据的剩余升级数据域和验证缺口。

## 下一步建议
最多给出三个选项，默认推荐在升级分类池与稀有度权重中选择一个低风险独立批次。
```
