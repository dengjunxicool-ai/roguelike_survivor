# Stage 5A Data Access Status Pool Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `DataManager` the normal-runtime owner of the status-definition pool while preserving `GameData` as the stable facade and retaining JSON fallback for compatibility environments.

**Architecture:** Add the one missing read-only pool accessor to the existing `DataManager` index. Keep `GameData.get_status_pool()` unchanged so its already-present manager-first branch begins succeeding, and pin manager/facade/fallback equivalence with focused runtime and static contract tests.

**Tech Stack:** Godot 4.6.3, GDScript, Node.js CommonJS verification scripts, JSON configuration, PowerShell on Windows.

**Spec:** `docs/superpowers/specs/2026-09-19-data-access-status-pool-consolidation-design.md`

## Global Constraints

- Do not change gameplay rules, status behavior, damage formulas, values, UI, visuals, resource paths, JSON schema, or save results.
- Preserve every existing public method, signal, scene node path, configuration ID, and compatibility fallback.
- `DataManager` remains the sole autoload and runtime data owner.
- `GameData` remains the stable consumer facade.
- Direct JSON loading remains available when `DataManager` or the requested accessor is unavailable.
- Do not migrate any existing consumer in Stage 5A.
- Do not add another status-pool source or abstraction.
- Do not claim a performance improvement; this is a boundary consolidation batch.
- Run Godot verification processes sequentially on Windows.
- Preserve all pre-existing untracked `.uid` files and unrelated user changes.
- Do not commit, push, or create a pull request unless the user explicitly authorizes that action.

## Review Focus

- A usable `DataManager` with the new accessor must produce the exact JSON status sequence and values; Task 2 compares the full pool and ordered IDs.
- An unavailable `/root/DataManager` must still use the existing JSON fallback; Task 2 temporarily renames and restores the autoload without removing it from the SceneTree.
- Mutating a returned nested dictionary must not mutate manager-owned data; Task 2 changes the `heat.effect` result and rereads it.
- An unknown status ID must still return `{}`; Task 2 calls the existing singular accessor with a sentinel ID.
- A future edit must not silently replace the manager-first/fallback pair with a third source; Task 1 inspects the exact `get_status_pool()` body.

---

## File Structure

- Create `tools/verify/verify_data_access_status_pool_boundary.js`: static ownership and fallback boundary guard.
- Create `tools/verify/verify_data_access_status_pool.gd`: runtime parity, fallback, ordering, and mutation-isolation verification.
- Modify `scripts/core/data_manager.gd`: add only `get_status_definitions() -> Array[Dictionary]`.
- Modify `package.json`: expose the two focused verification commands.
- Modify `docs/PROJECT_SYSTEMS_OVERVIEW.md`: document owner/facade/fallback terminology and the status-pool migration.
- Modify `docs/PROJECT_ENGINEERING_GUIDELINES.md`: define the rule for adding or migrating configuration domains.
- Modify `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`: record completed Stage 5A scope and remaining fallback domains.

No change to `scripts/game/game_data.gd` is planned. A required production edit there is a stop condition that triggers design review.

### Task 1: Protect the Branch and Add the Static Boundary Contract

**Files:**
- Create: `tools/verify/verify_data_access_status_pool_boundary.js`
- Modify: `package.json`

**Interfaces:**
- Consumes: `DataManager.get_status_definitions() -> Array[Dictionary]` as specified but not yet implemented.
- Produces: `npm run verify:data-access-status-pool-boundary`.

- [ ] **Step 1: Confirm the exact starting state**

Run:

```powershell
git branch --show-current
git status --short
git log -3 --oneline --decorate
```

Expected before any implementation edit:

- `HEAD` is `48f69fb` or a user-approved descendant containing Stage 4.
- The Stage 4 files are present.
- Only the already-known `.uid` files and the approved Stage 5 spec/plan are untracked or modified.
- Any unexpected user change stops execution for review; it is never overwritten or formatted.

- [ ] **Step 2: Create the Stage 5 branch before production work**

Run:

```powershell
git switch -c codex/stage5-data-access-status-pool
```

Expected: the new branch points at the approved Stage 4 base. If the branch already exists, inspect it rather than forcing or resetting it.

- [ ] **Step 3: Write the failing static boundary verifier**

Create `tools/verify/verify_data_access_status_pool_boundary.js` with:

```javascript
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const dataManager = readTextFile(path.join(root, "scripts", "core", "data_manager.gd"));
const gameData = readTextFile(path.join(root, "scripts", "game", "game_data.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const managerBody = functionBody(dataManager, "get_status_definitions");
const facadeBody = functionBody(gameData, "get_status_pool", "static func ");

assert(managerBody, "DataManager.get_status_definitions must exist.");
assert(
  managerBody.includes("return _get_definition_values(_status_definitions)"),
  "DataManager status pool must use the indexed status store and the existing copy helper.",
);
assert(facadeBody, "GameData.get_status_pool must exist.");
assert(
  facadeBody.includes('_get_pool_from_data_manager("get_status_definitions")'),
  "GameData status pool must query DataManager first.",
);
assert(
  facadeBody.includes('return _get_dictionary_array(STATUS_EFFECTS_PATH, "statuses")'),
  "GameData status pool must retain the JSON compatibility fallback.",
);
for (const forbiddenSource of ["JsonDataLoader", "FileAccess", "JSON.new", "load_dictionary("]) {
  assert(!facadeBody.includes(forbiddenSource), `GameData status pool must not add a third source: ${forbiddenSource}`);
}
assert(
  facadeBody.indexOf('_get_pool_from_data_manager("get_status_definitions")') <
    facadeBody.indexOf('return _get_dictionary_array(STATUS_EFFECTS_PATH, "statuses")'),
  "GameData status pool must keep manager-first ordering.",
);

console.log("[verify_data_access_status_pool_boundary] PASS");
```

- [ ] **Step 4: Add the package command**

Add this entry near the other Stage 5/architecture verification commands in `package.json`:

```json
"verify:data-access-status-pool-boundary": "node tools\\verify\\verify_data_access_status_pool_boundary.js"
```

Keep the JSON valid and do not reorder unrelated scripts.

- [ ] **Step 5: Run the static verifier and observe the intended red result**

Run:

```powershell
npm run verify:data-access-status-pool-boundary
```

Expected: FAIL with `DataManager.get_status_definitions must exist.` This proves the guard detects the missing accessor before production code changes.

- [ ] **Step 6: Review the Task 1 diff without committing**

Run:

```powershell
git diff -- tools/verify/verify_data_access_status_pool_boundary.js package.json
git status --short
```

Expected: only the boundary verifier and one package script entry are new for this task. Do not stage or commit without explicit user authorization.

### Task 2: Add the Runtime Contract and Minimal DataManager Accessor

**Files:**
- Create: `tools/verify/verify_data_access_status_pool.gd`
- Modify: `scripts/core/data_manager.gd`
- Modify: `package.json`

**Interfaces:**
- Consumes: `DataPaths.STATUS_EFFECTS_PATH`, `JsonDataLoader.load_dictionary(path, context)`, existing `GameData.get_status_pool()`, and existing `DataManager.get_status_definition(id)`.
- Produces: `DataManager.get_status_definitions() -> Array[Dictionary]` and `npm run verify:data-access-status-pool`.

- [ ] **Step 1: Write the failing runtime verifier**

Create `tools/verify/verify_data_access_status_pool.gd` with:

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

	_expect(data_manager.has_method("get_status_definitions"), "DataManager exposes get_status_definitions")
	if not data_manager.has_method("get_status_definitions"):
		_finish()
		return

	var source_document: Dictionary = JsonDataLoaderScript.load_dictionary(
		DataPathsScript.STATUS_EFFECTS_PATH,
		"verify_data_access_status_pool"
	)
	var source_pool: Array[Dictionary] = _to_dictionary_array(source_document.get("statuses", []))
	var manager_pool: Array[Dictionary] = _call_pool(data_manager, "get_status_definitions")
	var facade_pool: Array[Dictionary] = GameDataScript.get_status_pool()

	_expect(not source_pool.is_empty(), "source status pool is non-empty")
	_expect(_ids(manager_pool) == _ids(source_pool), "DataManager preserves source status order", _ids(manager_pool))
	_expect(manager_pool == source_pool, "DataManager status values match the source document")
	_expect(facade_pool == manager_pool, "GameData normal path matches DataManager")
	_expect(
		(data_manager.call("get_status_definition", &"__stage5_missing_status__") as Dictionary).is_empty(),
		"unknown status id remains empty"
	)

	_verify_manager_result_isolation(data_manager)
	_verify_facade_result_isolation()

	var original_manager_name: StringName = data_manager.name
	data_manager.name = &"Stage5UnavailableDataManager"
	GameDataScript._document_cache.clear()
	var fallback_pool: Array[Dictionary] = GameDataScript.get_status_pool()
	data_manager.name = original_manager_name
	GameDataScript._document_cache.clear()

	_expect(_ids(fallback_pool) == _ids(source_pool), "fallback preserves source status order", _ids(fallback_pool))
	_expect(fallback_pool == source_pool, "fallback values match the source document")
	var restored_pool: Array[Dictionary] = GameDataScript.get_status_pool()
	_expect(restored_pool == manager_pool, "restored facade returns manager-backed values")

	_finish()


func _verify_manager_result_isolation(data_manager: Node) -> void:
	var first_pool: Array[Dictionary] = _call_pool(data_manager, "get_status_definitions")
	var heat: Dictionary = _find_by_id(first_pool, &"heat")
	_expect(not heat.is_empty(), "heat status exists for mutation isolation")
	if heat.is_empty():
		return
	var effect: Dictionary = heat.get("effect", {}) as Dictionary
	effect["__stage5_probe"] = true
	var fresh_heat: Dictionary = _find_by_id(_call_pool(data_manager, "get_status_definitions"), &"heat")
	var fresh_effect: Dictionary = fresh_heat.get("effect", {}) as Dictionary
	_expect(not fresh_effect.has("__stage5_probe"), "DataManager returns deeply isolated status definitions")


func _verify_facade_result_isolation() -> void:
	var first_pool: Array[Dictionary] = GameDataScript.get_status_pool()
	var heat: Dictionary = _find_by_id(first_pool, &"heat")
	_expect(not heat.is_empty(), "facade exposes heat for mutation isolation")
	if heat.is_empty():
		return
	var effect: Dictionary = heat.get("effect", {}) as Dictionary
	effect["__stage5_probe"] = true
	var fresh_heat: Dictionary = _find_by_id(GameDataScript.get_status_pool(), &"heat")
	var fresh_effect: Dictionary = fresh_heat.get("effect", {}) as Dictionary
	_expect(not fresh_effect.has("__stage5_probe"), "GameData manager path returns deeply isolated definitions")


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


func _ids(items: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for item: Dictionary in items:
		result.append(StringName(String(item.get("id", ""))))
	return result


func _find_by_id(items: Array[Dictionary], target_id: StringName) -> Dictionary:
	for item: Dictionary in items:
		if StringName(String(item.get("id", ""))) == target_id:
			return item
	return {}


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_data_access_status_pool] FAIL %s actual=%s" % [label, str(actual)])


func _finish() -> void:
	if not _failed:
		print("[verify_data_access_status_pool] PASS")
	quit(1 if _failed else 0)
```

- [ ] **Step 2: Add the runtime package command**

Add:

```json
"verify:data-access-status-pool": "D:\\Godot\\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_data_access_status_pool.gd"
```

- [ ] **Step 3: Run the runtime verifier and observe the intended red result**

Run:

```powershell
npm run verify:data-access-status-pool
```

Expected: FAIL with `DataManager exposes get_status_definitions`. A parser or fixture failure is not the intended red result and must be fixed before production code changes.

- [ ] **Step 4: Add the minimal accessor**

In `scripts/core/data_manager.gd`, place the pool accessor beside the other pool accessors:

```gdscript
func get_status_definitions() -> Array[Dictionary]:
	return _get_definition_values(_status_definitions)
```

Do not change `load_all()`, the private index, `GameData`, or any consumer.

- [ ] **Step 5: Run both focused tests and verify green**

Run sequentially:

```powershell
npm run verify:data-access-status-pool-boundary
npm run verify:data-access-status-pool
```

Expected:

```text
[verify_data_access_status_pool_boundary] PASS
[verify_data_access_status_pool] PASS
```

- [ ] **Step 6: Verify the production diff is exactly one accessor**

Run:

```powershell
git diff -- scripts/core/data_manager.gd scripts/game/game_data.gd
```

Expected: one new three-line method in `data_manager.gd`; no diff in `game_data.gd`.

- [ ] **Step 7: Record the implementation checkpoint without committing**

Run:

```powershell
git status --short
```

Expected: the two verifiers, two package entries, one accessor, and approved documentation are the only Stage 5 changes. Do not stage or commit without explicit user authorization.

### Task 3: Update the Boundary Documentation

**Files:**
- Modify: `docs/PROJECT_SYSTEMS_OVERVIEW.md`
- Modify: `docs/PROJECT_ENGINEERING_GUIDELINES.md`
- Modify: `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`

**Interfaces:**
- Consumes: the verified `DataManager.get_status_definitions()` contract from Task 2.
- Produces: accurate project guidance for future configuration-domain migrations.

- [ ] **Step 1: Update the systems overview terminology**

In the configuration-loading section of `docs/PROJECT_SYSTEMS_OVERVIEW.md`, replace claims that imply two equal sources or that most code directly reads `DataManager` with text equivalent to:

```markdown
`DataManager` 是运行时配置所有者，负责启动加载、索引和隔离副本输出；`GameData` 是现有消费端的稳定读取门面。正常运行中，已收口的数据域由 `GameData` 委托给 `DataManager`；无 autoload 或缺少 accessor 的隔离/headless 环境仍保留 JSON fallback。Stage 5A 已收口状态池，其他 fallback 数据域仍需逐项迁移和验证。
```

Keep the existing flow diagram but label `GameData` as the consumer facade and direct JSON reading as a compatibility fallback.

- [ ] **Step 2: Add the engineering rule for future domains**

In `docs/PROJECT_ENGINEERING_GUIDELINES.md`, update the configuration rules to require this order:

```markdown
1. 新配置路径先登记到 `DataPaths`。
2. 正常运行数据由 `DataManager` 加载、索引并通过深拷贝 accessor 输出。
3. `GameData` 作为稳定门面优先委托给 `DataManager`；兼容 fallback 在迁移证据充分前保留。
4. 每个数据域必须验证 manager、facade 与 fallback 的 ID、顺序、字段和值一致。
5. 数值或 schema 变化不得混入读取路径重构。
```

Do not claim that all current domains already satisfy the rule.

- [ ] **Step 3: Record Stage 5A and remaining debt**

In `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`:

- mark the status pool as manager-owned through `get_status_definitions()`;
- retain the general `DataManager`/`GameData` debt entry;
- state that progression goals, challenges, upgrade category pools, rarity weights, and duplicated consumer fallbacks remain candidates for later batches;
- keep Stage 6 and Stage 7 ordering unchanged.

- [ ] **Step 4: Run the encoding guard**

Run:

```powershell
node tools/validate/check_text_encoding.js
```

Expected: PASS with no newly reported invalid encoding.

- [ ] **Step 5: Review documentation truthfulness and diff scope**

Run:

```powershell
git diff --check
git diff -- docs/PROJECT_SYSTEMS_OVERVIEW.md docs/PROJECT_ENGINEERING_GUIDELINES.md docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md
```

Expected: no whitespace errors and no statement that Stage 5 is fully complete.

### Task 4: Run the Stage 5A Verification Gate and Prepare Handoff

**Files:**
- Verify only: all Stage 5A files and affected status/config systems.

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces: evidence required to call Stage 5A complete or a precise failure report.

- [ ] **Step 1: Run static and configuration validation sequentially**

Run each command separately and record its exit code:

```powershell
node tools/validate/check_text_encoding.js
node tools/validate/validate_enemy_configs.js
node tools/validate/validate_modifier_effects.js
npm run verify:data-access-status-pool-boundary
npm run verify:fire-status-contract
npm run verify:burn-status-table
npm run verify:gods-and-skills-contract
```

Expected: every command exits `0` and reports PASS where applicable.

- [ ] **Step 2: Run Godot runtime verification sequentially**

Run each command only after the prior Godot process exits:

```powershell
npm run verify:data-access-status-pool
npm run verify:burn-status-runtime
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --quit
```

Expected:

- the new status-pool runtime verifier prints PASS;
- the burn runtime verifier prints PASS;
- headless startup exits `0` without a new script error or warning attributable to Stage 5A.

- [ ] **Step 3: Classify any failure before editing**

For every failure, record:

```text
Command:
Exit code:
Key output:
Classification: pre-existing / environment / Stage 5A regression
Evidence:
```

Stop scope expansion. Do not delete assertions, loosen comparisons, skip fallback coverage, or change status data to make a test pass.

- [ ] **Step 4: Inspect the final diff and protected files**

Run:

```powershell
git diff --check
git status --short
git diff --stat
git diff -- scripts/core/data_manager.gd scripts/game/game_data.gd package.json tools/verify/verify_data_access_status_pool.gd tools/verify/verify_data_access_status_pool_boundary.js docs/PROJECT_SYSTEMS_OVERVIEW.md docs/PROJECT_ENGINEERING_GUIDELINES.md docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md
```

Expected:

- production code changes only add `DataManager.get_status_definitions()`;
- `scripts/game/game_data.gd` remains unchanged;
- no JSON, scene, resource, UI, gameplay, save, or unrelated file changes;
- the seven pre-existing untracked `.uid` files remain untouched and unstaged.

- [ ] **Step 5: Request independent review before completion**

Use the review workflow required by the selected execution method. The reviewer checks:

- exact spec coverage;
- correct manager/facade/fallback behavior;
- autoload restoration in the runtime verifier;
- copy and ordering guarantees;
- absence of unrelated changes.

Resolve only verified Critical or Important findings inside Stage 5A scope, then rerun the affected tests and the complete gate.

- [ ] **Step 6: Report completion without publishing changes**

Use the project completion format:

```markdown
## 本批次结果
一句话说明状态池正常运行读取已由 DataManager 所有，并保留兼容 fallback。

## 修改范围
逐文件列出 accessor、测试、命令和文档职责。

## 保持不变
列出状态玩法、数值、接口、顺序、schema、资源、UI 和存档不变量。

## 验证证据
列出实际命令、退出码和 PASS 输出。

## 性能对比
不适用；本批次不作性能声明。

## 遗留风险
只列仍由 GameData 正常 fallback 或消费端重复 fallback 的已证实数据域。

## 下一步建议
最多三个选项，默认推荐先选择一个低风险数据域设计 Stage 5B。
```

Do not commit, push, or create a pull request until the user explicitly authorizes it.

## Suggested Commit Checkpoints After Explicit Authorization

If the user later authorizes commits, use these scoped checkpoints after all corresponding tests are green:

```powershell
git add docs/superpowers/specs/2026-09-19-data-access-status-pool-consolidation-design.md docs/superpowers/plans/2026-09-19-data-access-status-pool-consolidation.md tools/verify/verify_data_access_status_pool_boundary.js tools/verify/verify_data_access_status_pool.gd scripts/core/data_manager.gd package.json
git commit -m "refactor: consolidate status pool data access"
```

Then, after confirming the documentation diff is accurate:

```powershell
git add docs/PROJECT_SYSTEMS_OVERVIEW.md docs/PROJECT_ENGINEERING_GUIDELINES.md docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md
git commit -m "docs: record stage 5 data access boundary"
```

Before either commit, inspect `git diff --cached --name-only` and confirm no `.uid` or unrelated file is staged.
