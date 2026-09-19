# Stage 5B Data Access Progression Goals Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `DataManager` the normal-runtime owner of the complete progression-goals document while preserving `GameData` as the stable facade and retaining its JSON compatibility fallback.

**Architecture:** Load the complete progression-goals document into one `DataManager` dictionary because the document has no top-level definition ID and its ordered nested arrays are the public data shape. Change only `GameData.get_progression_goals()` to use the existing manager-first dictionary pattern, then pin source/manager/facade/fallback equivalence and mutation isolation with focused static and runtime verifiers.

**Tech Stack:** Godot 4.6.3, GDScript, Node.js CommonJS verification scripts, JSON configuration, PowerShell on Windows.

**Spec:** `docs/superpowers/specs/2026-09-19-data-access-progression-goals-consolidation-design.md`

## Global Constraints

- Do not change gameplay rules, progression formulas, goal evaluation, values, UI, visuals, resource paths, JSON schema, configuration IDs, or save results.
- Preserve `GameData.get_progression_goals() -> Dictionary` and every existing public method, signal, scene path, and compatibility fallback.
- `DataManager` remains the sole normal-runtime configuration owner; `GameData` remains the stable consumer facade.
- Direct JSON loading remains available when `DataManager` or its progression-goals result is unavailable.
- Do not modify `RunProgressionService` or `SaveManager` production code in Stage 5B.
- Do not consolidate daily challenges, weekly challenges, curse choices, permanent upgrades, level-up upgrades, rarity weights, or consumer-owned fallbacks.
- Do not create a new repository, service, registry, resource type, index format, or generic dictionary-access helper.
- Do not claim a performance improvement; this is an architecture and ownership batch.
- Run Godot verification processes sequentially on Windows.
- Inside the managed Windows sandbox, invoke Godot directly instead of through npm; only validate an npm wrapper outside the sandbox when wrapper behavior is explicitly in scope.
- Preserve unrelated user changes and generated `.uid` files.
- Do not commit, push, or create a pull request unless the user explicitly authorizes that action.

## Review Focus

- An unavailable root `DataManager` must still return the exact source document through the facade; Task 1 renames and restores the autoload while checking the fallback.
- A present manager that yields an empty dictionary must not mask valid fallback data; Task 1's static contract requires the facade's non-empty guard before its fallback return.
- Mutating nested `goals` or `objectives` arrays from either manager or facade output must not contaminate later reads; Task 1 mutates both shapes and rereads source-equivalent data.
- Character, map, goal, and objective sequence order must remain exact; Task 1 compares normalized ordered sequences in addition to full dictionary equality.
- Progression and save consumers must not gain a direct `DataManager` dependency; Task 1's static contract checks both files and Task 2 verifies that they remain unmodified.

---

## File Structure

- Create `tools/verify/verify_data_access_progression_goals_boundary.js`: static owner/facade/fallback and consumer-dependency guard.
- Create `tools/verify/verify_data_access_progression_goals.gd`: runtime source, manager, facade, fallback, ordering, and mutation-isolation verifier.
- Modify `scripts/core/data_manager.gd`: load, own, clear, and deep-copy the complete progression-goals document.
- Modify `scripts/game/game_data.gd`: change only `get_progression_goals()` to manager-first access with the existing JSON fallback.
- Modify `package.json`: expose the two focused Stage 5B verification commands.
- Modify `docs/PROJECT_SYSTEMS_OVERVIEW.md`: record the progression-goals normal-runtime ownership path.
- Modify `docs/PROJECT_ENGINEERING_GUIDELINES.md`: update the Stage 5 migration status without broadening the rule.
- Modify `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`: mark Stage 5B complete and retain the remaining data-domain debt.

No production change to `scripts/game/run_progression_service.gd` or `scripts/game/save_manager.gd` is planned. A required edit to either file is a stop condition that returns to design review.

### Task 1: Add the Progression-Goals Contract and Minimal Ownership Path

**Files:**
- Create: `tools/verify/verify_data_access_progression_goals_boundary.js`
- Create: `tools/verify/verify_data_access_progression_goals.gd`
- Modify: `package.json`
- Modify: `scripts/core/data_manager.gd`
- Modify: `scripts/game/game_data.gd`
- Verify unchanged: `scripts/game/run_progression_service.gd`
- Verify unchanged: `scripts/game/save_manager.gd`

**Interfaces:**
- Consumes: `DataPaths.PROGRESSION_GOALS_PATH`, `JsonDataLoader.load_dictionary(path, context)`, `GameData._get_data_manager()`, and the existing `GameData` document cache.
- Produces: `DataManager.get_progression_goals() -> Dictionary`, unchanged `GameData.get_progression_goals() -> Dictionary`, `npm run verify:data-access-progression-goals-boundary`, and `npm run verify:data-access-progression-goals`.

- [ ] **Step 1: Confirm the clean Stage 5B starting state**

Run:

```powershell
git branch --show-current
git status --short
git log -3 --oneline --decorate
git diff origin/main...HEAD --stat
```

Expected:

- branch is `codex/stage5b-progression-goals`;
- the only branch-only commit is the approved Stage 5B specification until this plan is committed;
- no production or test file is modified;
- any unexpected user change stops implementation for review and is not overwritten.

- [ ] **Step 2: Record the baseline before adding the Stage 5B tests**

Run:

```powershell
node tools/validate/check_text_encoding.js
node tools/validate/validate_enemy_configs.js
node tools/validate/validate_modifier_effects.js
npm run verify:data-access-status-pool-boundary
npm run verify:result-screen-diagnostic-call
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_status_pool.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_result_unlock_cache_lifetime.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --quit
```

Expected:

- all commands exit `0`;
- the status-pool verifier prints `[verify_data_access_status_pool] PASS`;
- any pre-existing warning is recorded before Stage 5B code changes;
- a failure is classified before proceeding rather than absorbed into the new scope.

- [ ] **Step 3: Create the failing static boundary verifier**

Create `tools/verify/verify_data_access_progression_goals_boundary.js` with:

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
const managerBody = functionBody(dataManager, "get_progression_goals");
const facadeBody = functionBody(gameData, "get_progression_goals", "static func ");

assert(
  dataManager.includes("const PROGRESSION_GOALS_PATH: String = DataPathsScript.PROGRESSION_GOALS_PATH"),
  "DataManager must register the canonical progression-goals path.",
);
assert(dataManager.includes("var _progression_goals: Dictionary = {}"), "DataManager must own one progression-goals document.");
assert(loadAllBody.includes("_progression_goals.clear()"), "DataManager reload must clear progression goals first.");
assert(
  loadAllBody.includes("_progression_goals = _load_json_document(PROGRESSION_GOALS_PATH)"),
  "DataManager must load the complete progression-goals document.",
);
assert(managerBody, "DataManager.get_progression_goals must exist.");
assert(
  managerBody.includes("return _progression_goals.duplicate(true)"),
  "DataManager must return a deeply isolated progression-goals document.",
);
assert(facadeBody, "GameData.get_progression_goals must exist.");
for (const marker of [
  "_get_data_manager()",
  'has_method("get_progression_goals")',
  'call("get_progression_goals")',
  "not goals_data.is_empty()",
  "return _load_document(PROGRESSION_GOALS_PATH).duplicate(true)",
]) {
  assert(facadeBody.includes(marker), `GameData progression-goals facade is missing: ${marker}`);
}
assert(
  facadeBody.indexOf('call("get_progression_goals")') <
    facadeBody.indexOf("return _load_document(PROGRESSION_GOALS_PATH).duplicate(true)"),
  "GameData progression goals must keep manager-first ordering.",
);
for (const forbiddenSource of ["JsonDataLoader", "FileAccess", "JSON.new", "load_dictionary("]) {
  assert(!facadeBody.includes(forbiddenSource), `GameData progression goals must not add a third source: ${forbiddenSource}`);
}
assert(
  progression.includes("GameData.get_progression_goals()"),
  "RunProgressionService must continue through the GameData facade.",
);
assert(!progression.includes("DataManager"), "RunProgressionService must not depend directly on DataManager.");
assert(!saveManager.includes("DataManager"), "SaveManager must not depend directly on DataManager.");

console.log("[verify_data_access_progression_goals_boundary] PASS");
```

- [ ] **Step 4: Register both focused verification commands**

Add these entries near the Stage 5A verification entries in `package.json`:

```json
"verify:data-access-progression-goals": "D:\\Godot\\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_progression_goals.gd",
"verify:data-access-progression-goals-boundary": "node tools\\verify\\verify_data_access_progression_goals_boundary.js"
```

Do not reorder or reformat unrelated scripts.

- [ ] **Step 5: Run the static verifier and observe the intended red state**

Run:

```powershell
npm run verify:data-access-progression-goals-boundary
```

Expected: FAIL on the first missing `DataManager` progression-goals ownership marker. A syntax error or missing-file error is not the intended red state and must be fixed before proceeding.

- [ ] **Step 6: Create the failing runtime verifier**

Create `tools/verify/verify_data_access_progression_goals.gd` with:

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

	_expect(data_manager.has_method("get_progression_goals"), "DataManager exposes get_progression_goals")
	if not data_manager.has_method("get_progression_goals"):
		_finish()
		return

	var source: Dictionary = JsonDataLoaderScript.load_dictionary(
		DataPathsScript.PROGRESSION_GOALS_PATH,
		"verify_data_access_progression_goals"
	)
	var manager_result: Dictionary = _call_dictionary(data_manager, "get_progression_goals")
	var facade_result: Dictionary = GameDataScript.get_progression_goals()

	_expect(not source.is_empty(), "source progression-goals document is non-empty")
	_expect(manager_result == source, "DataManager values match the source document")
	_expect(facade_result == manager_result, "GameData normal path matches DataManager")
	_expect(
		_character_sequences(manager_result) == _character_sequences(source),
		"character and goal order matches the source",
		_character_sequences(manager_result)
	)
	_expect(
		_map_sequences(manager_result) == _map_sequences(source),
		"map and objective order matches the source",
		_map_sequences(manager_result)
	)

	_verify_manager_result_isolation(data_manager, source)
	_verify_facade_result_isolation(data_manager, source)

	var original_manager_name: StringName = data_manager.name
	data_manager.name = &"Stage5BUnavailableDataManager"
	GameDataScript._document_cache.clear()
	var fallback_result: Dictionary = GameDataScript.get_progression_goals()
	data_manager.name = original_manager_name
	GameDataScript._document_cache.clear()

	_expect(fallback_result == source, "fallback values match the source document")
	_expect(
		_character_sequences(fallback_result) == _character_sequences(source),
		"fallback preserves character and goal order"
	)
	_expect(
		_map_sequences(fallback_result) == _map_sequences(source),
		"fallback preserves map and objective order"
	)
	_expect(GameDataScript.get_progression_goals() == manager_result, "restored facade returns manager-backed values")

	_finish()


func _verify_manager_result_isolation(data_manager: Node, source: Dictionary) -> void:
	var first: Dictionary = _call_dictionary(data_manager, "get_progression_goals")
	var characters: Array = first.get("character_specializations", []) as Array
	_expect(not characters.is_empty(), "manager character goals exist for mutation isolation")
	if not characters.is_empty():
		var first_character: Dictionary = characters[0] as Dictionary
		var goals: Array = first_character.get("goals", []) as Array
		goals.append("__stage5b_probe_goal__")
		first_character["__stage5b_probe"] = true
	_expect(_call_dictionary(data_manager, "get_progression_goals") == source, "DataManager returns deeply isolated progression goals")


func _verify_facade_result_isolation(data_manager: Node, source: Dictionary) -> void:
	var first: Dictionary = GameDataScript.get_progression_goals()
	var maps: Array = first.get("map_challenges", []) as Array
	_expect(not maps.is_empty(), "facade map objectives exist for mutation isolation")
	if not maps.is_empty():
		var first_map: Dictionary = maps[0] as Dictionary
		var objectives: Array = first_map.get("objectives", []) as Array
		objectives.append("__stage5b_probe_objective__")
		first_map["__stage5b_probe"] = true
	_expect(GameDataScript.get_progression_goals() == source, "GameData returns deeply isolated progression goals")
	_expect(_call_dictionary(data_manager, "get_progression_goals") == source, "facade mutation does not affect DataManager")


func _call_dictionary(data_manager: Node, method_name: String) -> Dictionary:
	var value: Variant = data_manager.call(method_name)
	return value as Dictionary if value is Dictionary else {}


func _character_sequences(document: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_variant: Variant in document.get("character_specializations", []):
		if entry_variant is Dictionary:
			var entry: Dictionary = entry_variant
			result.append({
				"character_id": String(entry.get("character_id", "")),
				"goals": (entry.get("goals", []) as Array).duplicate(true),
			})
	return result


func _map_sequences(document: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_variant: Variant in document.get("map_challenges", []):
		if entry_variant is Dictionary:
			var entry: Dictionary = entry_variant
			result.append({
				"map_id": String(entry.get("map_id", "")),
				"objectives": (entry.get("objectives", []) as Array).duplicate(true),
			})
	return result


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_data_access_progression_goals] FAIL %s actual=%s" % [label, str(actual)])


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_progression_goals] PASS")
	quit(1 if _failed else 0)
```

- [ ] **Step 7: Run the runtime verifier and observe the intended red state**

Run Godot directly inside the managed sandbox:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_progression_goals.gd
```

Expected: exit `1` with `DataManager exposes get_progression_goals` failure. A parser error, native crash, or failure before that assertion is not the intended red state.

- [ ] **Step 8: Add the minimal `DataManager` ownership path**

Modify `scripts/core/data_manager.gd` in the existing constant, field, clear, load, and accessor groups:

```gdscript
const PROGRESSION_GOALS_PATH: String = DataPathsScript.PROGRESSION_GOALS_PATH
```

```gdscript
var _progression_goals: Dictionary = {}
```

Inside `load_all()` with the other clear operations:

```gdscript
_progression_goals.clear()
```

Inside `load_all()` after the other document loads:

```gdscript
_progression_goals = _load_json_document(PROGRESSION_GOALS_PATH)
```

Add the public read-only accessor near `get_wave_config()`:

```gdscript
func get_progression_goals() -> Dictionary:
	return _progression_goals.duplicate(true)
```

Do not index the nested arrays and do not change existing accessors.

- [ ] **Step 9: Make the `GameData` facade manager-first**

Replace only the body of `GameData.get_progression_goals()` in `scripts/game/game_data.gd`:

```gdscript
static func get_progression_goals() -> Dictionary:
	var data_manager: Node = _get_data_manager()
	if data_manager != null and data_manager.has_method("get_progression_goals"):
		var data: Variant = data_manager.call("get_progression_goals")
		if data is Dictionary:
			var goals_data: Dictionary = data
			if not goals_data.is_empty():
				return goals_data
	return _load_document(PROGRESSION_GOALS_PATH).duplicate(true)
```

Do not modify `GameDataAccess`, the document cache, or any other `GameData` method.

- [ ] **Step 10: Run the focused tests and verify the green state**

Run:

```powershell
npm run verify:data-access-progression-goals-boundary
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_progression_goals.gd
npm run verify:data-access-status-pool-boundary
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_status_pool.gd
```

Expected:

- both static verifiers print `PASS`;
- both runtime verifiers print `PASS` and exit `0`;
- the Stage 5A contract remains green.

- [ ] **Step 11: Inspect the Task 1 diff and commit only with authorization**

Run:

```powershell
git diff --check
git diff -- scripts/core/data_manager.gd scripts/game/game_data.gd package.json tools/verify/verify_data_access_progression_goals_boundary.js tools/verify/verify_data_access_progression_goals.gd
git status --short
```

Confirm:

- no progression rule, save, JSON, challenge, rarity, or unrelated formatting change is present;
- `RunProgressionService` and `SaveManager` are unchanged;
- only the two tests, two package entries, one manager document path, and one facade method changed.

If the user has authorized commits, run:

```powershell
git add package.json scripts/core/data_manager.gd scripts/game/game_data.gd tools/verify/verify_data_access_progression_goals_boundary.js tools/verify/verify_data_access_progression_goals.gd
git commit -m "refactor: consolidate progression goals data access"
```

Expected: one focused Task 1 commit. Without explicit authorization, leave the verified files uncommitted.

### Task 2: Update Engineering Records and Run the Full Stage 5B Gate

**Files:**
- Modify: `docs/PROJECT_SYSTEMS_OVERVIEW.md`
- Modify: `docs/PROJECT_ENGINEERING_GUIDELINES.md`
- Modify: `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`
- Verify only: all Stage 5B production, test, plan, and spec files

**Interfaces:**
- Consumes: the verified `DataManager.get_progression_goals()` and manager-first `GameData.get_progression_goals()` contract from Task 1.
- Produces: accurate project documentation, complete verification evidence, and a review-ready Stage 5B branch.

- [ ] **Step 1: Update the systems overview**

In `docs/PROJECT_SYSTEMS_OVERVIEW.md`, update the data-configuration description to state:

```markdown
`DataManager` 是运行时配置所有者，负责启动加载、索引或持有完整配置文档，并通过深拷贝 accessor 输出；`GameData` 是稳定消费门面。Stage 5A 已收口状态池，Stage 5B 已收口进度目标文档；无可用 autoload 或有效结果时仍保留 JSON fallback。每日/每周挑战与升级配置剩余入口继续按独立批次处理。
```

Keep the existing diagram and table structure. Do not state that all `GameData` fallbacks are consolidated.

- [ ] **Step 2: Update the engineering guideline status line**

In `docs/PROJECT_ENGINEERING_GUIDELINES.md`, update only the Stage 5 migration-status wording so it records:

```markdown
DataManager/GameData 读取路径收口：Stage 5A 已收口状态池，Stage 5B 已收口进度目标文档；其余数据域继续按契约测试逐项迁移。
```

Preserve the existing owner/facade/fallback rules and Windows managed-sandbox guidance.

- [ ] **Step 3: Update the stability and boundary report**

In `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`:

- state that `DataManager.get_progression_goals()` owns the normal-runtime progression document;
- state that `GameData.get_progression_goals()` remains the facade and JSON fallback;
- remove progression goals from the remaining fallback-domain list;
- retain daily challenges, weekly challenges, upgrade category pools, rarity weights, and verified consumer-owned fallbacks as remaining debt;
- state that Stage 5B changes no progression rule or save behavior.

- [ ] **Step 4: Run the complete Stage 5B verification gate**

Run Node/static checks:

```powershell
node tools/validate/check_text_encoding.js
node tools/validate/validate_enemy_configs.js
node tools/validate/validate_modifier_effects.js
npm run verify:data-access-progression-goals-boundary
npm run verify:data-access-status-pool-boundary
npm run verify:result-screen-diagnostic-call
```

Run Godot checks sequentially and directly:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_progression_goals.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_status_pool.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_result_unlock_cache_lifetime.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --quit
```

Run final diff checks:

```powershell
git diff --check
git status --short
git diff --stat origin/main...HEAD
git diff origin/main...HEAD -- scripts/game/run_progression_service.gd scripts/game/save_manager.gd data/progression/progression_goals.json data/progression/challenges.json data/upgrades/upgrades.json
```

Expected:

- every command exits `0`;
- both Stage 5 runtime verifiers print `PASS`;
- the result-unlock verifier and headless startup complete without a new Stage 5B warning;
- the final scoped diff command is empty, proving progression rules, save behavior, and configuration documents are unchanged;
- the only documented remaining failures are demonstrably pre-existing or environmental.

- [ ] **Step 5: Request an independent whole-branch review**

Ask the reviewer to compare `origin/main` with the Stage 5B head and focus on:

- exact source/manager/facade/fallback equivalence;
- nested dictionary and array ownership;
- guaranteed autoload restoration in the fallback probe;
- absence of progression, save, challenge, and upgrade behavior changes;
- documentation accuracy and rollback completeness.

Resolve every verified Critical or Important issue inside Stage 5B scope, then rerun the affected test and the complete gate. Record Minor issues without expanding the batch unless they invalidate a stated contract.

- [ ] **Step 6: Inspect the final diff and commit documentation only with authorization**

Run:

```powershell
git diff --check
git status --short
git diff --stat
```

If the user has authorized commits and Task 1 was committed separately, run:

```powershell
git add docs/PROJECT_SYSTEMS_OVERVIEW.md docs/PROJECT_ENGINEERING_GUIDELINES.md docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md
git commit -m "docs: record stage 5b progression goals ownership"
```

If the user instead authorizes one final combined commit, stage exactly all approved Stage 5B files and use:

```powershell
git commit -m "refactor: consolidate progression goals data access"
```

Do not push or create a pull request without separate explicit authorization.

## Performance Success Metric

Not applicable. Stage 5B changes configuration ownership and validation only. It does not claim lower frame time, allocation count, startup duration, or memory use; no performance threshold may be invented for completion.

## Rollback Procedure

If Stage 5B must be reverted before integration:

1. remove `PROGRESSION_GOALS_PATH`, `_progression_goals`, its clear/load steps, and `DataManager.get_progression_goals()` from `scripts/core/data_manager.gd`;
2. restore `GameData.get_progression_goals()` to `return _load_document(PROGRESSION_GOALS_PATH).duplicate(true)`;
3. remove the two Stage 5B verifier files and their two `package.json` entries;
4. revert only the Stage 5B statements in the three engineering documents;
5. rerun the Stage 5A status-pool verifier, result-unlock verifier, encoding check, and headless startup.

If Stage 5B was committed, use a normal revert commit after inspecting the exact commit range. Do not reset, force-push, delete configuration data, or alter save files. The preserved `GameData` JSON path requires no data migration.

## Completion Report Template

Use this exact structure after the gate passes:

```markdown
## 本批次结果
进度目标配置的正常运行读取已由 DataManager 所有，GameData 门面和 JSON fallback 保持兼容。

## 修改范围
- DataManager：持有并深拷贝输出完整进度目标文档。
- GameData：get_progression_goals 改为 manager-first。
- 验证：新增静态边界和运行时四路径一致性验证。
- 文档：更新 Stage 5B 状态与剩余数据域。

## 保持不变
- 目标 ID、顺序、判定规则、结算逻辑和存档结果。
- GameData 公共方法与 fallback。
- 每日/每周挑战和升级数据入口。

## 验证证据
列出本计划实际执行的每条命令、退出码和关键 PASS 输出。

## 性能对比
不适用。本批次不声明性能提升。

## 遗留风险
只列具有代码或测试证据的剩余数据域和验证缺口。

## 下一步建议
最多三个选项，默认推荐从每日/每周挑战池和升级剩余入口中选择一个低风险独立批次。
```
