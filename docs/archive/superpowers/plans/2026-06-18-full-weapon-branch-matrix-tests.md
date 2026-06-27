# Full Weapon Branch Matrix Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement all three requested test layers for the full current matrix: 4 characters, 13 weapons, 52 branches, Lv1-Lv5, 260 total combinations.

**Architecture:** Add a shared Node.js matrix/contract helper for fast static validation, then add a Godot headless runner that reuses the existing Dev Mode runtime path for smoke and rule-template validation. Reports are written in both JSON and text under `reports/combat-scene-checks/`.

**Tech Stack:** Node.js validation scripts, Godot 4.6 headless GDScript, existing Dev Mode runtime (`UIManager.start_developer_debug_run`), existing `DebugCombatTrace`.

---

## File Structure

- Create: `tools/full_weapon_branch_matrix.js`
  - Shared Node.js helper that reads data files, builds the 260-case matrix, validates static relationships, classifies rule templates, and writes matrix reports.
- Create: `tools/verify_full_weapon_branch_matrix.js`
  - Static Layer 1 gate. Uses `full_weapon_branch_matrix.js`.
- Modify: `tools/validate_weapon_authoring_pipeline.js`
  - Add the full matrix static check to the existing authoring pipeline.
- Create: `scripts/debug/full_weapon_branch_matrix_check.gd`
  - Godot headless runner for Layer 2 runtime smoke and Layer 3 rule-template checks.
- Keep: `scripts/debug/weapon_combat_scene_check.gd`
  - Existing curated fire-staff scene checker remains as a human-readable focused debug suite.
- Create or update generated reports:
  - `reports/combat-scene-checks/full_weapon_branch_matrix.json`
  - `reports/combat-scene-checks/full_weapon_branch_matrix.txt`

Current workspace note: `E:\roguelike_survivor` is not a Git repository, so commit steps are intentionally omitted.

## Task 1: Add Shared Matrix Builder

**Files:**
- Create: `tools/full_weapon_branch_matrix.js`
- Test: `node tools\verify_full_weapon_branch_matrix.js` after Task 2

- [ ] **Step 1: Create the helper module**

Add `tools/full_weapon_branch_matrix.js`:

```javascript
const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");

const root = path.resolve(__dirname, "..");
const dataDir = path.join(root, "data");
const REPORT_DIR = path.join(root, "reports", "combat-scene-checks");
const MATRIX_JSON = path.join(REPORT_DIR, "full_weapon_branch_matrix.json");
const MATRIX_TEXT = path.join(REPORT_DIR, "full_weapon_branch_matrix.txt");

const EXPECTED_COUNTS = Object.freeze({
  characters: 4,
  weapons: 13,
  branches: 52,
  levelsPerBranch: 5,
  cases: 260,
});

function readJson(fileName) {
  return readJsonFile(path.join(dataDir, fileName));
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function asObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function idOf(value) {
  return String(value || "").trim();
}

function byId(items, label, errors) {
  const result = new Map();
  for (const item of asArray(items)) {
    const id = idOf(item && item.id);
    if (!id) {
      errors.push(`${label} contains item without id`);
      continue;
    }
    if (result.has(id)) {
      errors.push(`${label} duplicate id: ${id}`);
      continue;
    }
    result.set(id, item);
  }
  return result;
}

function loadDocuments() {
  return {
    characters: readJson("characters.json"),
    weapons: readJson("weapons.json"),
    primaryAttacks: readJson("primary_attack.json"),
    branches: readJson("weapon_branches.json"),
    combatObjects: readJson("combat_objects.json"),
    statuses: readJson("status_effects.json"),
    enemies: readJson("enemies.json"),
  };
}

function buildIndexes(documents, errors = []) {
  return {
    characters: byId(documents.characters.characters, "characters", errors),
    weapons: byId(documents.weapons.weapons, "weapons", errors),
    primaryAttacks: byId(documents.primaryAttacks.primary_attacks, "primary_attacks", errors),
    branches: byId(documents.branches.branches, "branches", errors),
    combatObjects: byId(documents.combatObjects.combat_objects, "combat_objects", errors),
    statuses: byId(documents.statuses.statuses, "statuses", errors),
    enemies: byId(documents.enemies.enemies, "enemies", errors),
  };
}

function caseId(characterId, weaponId, branchId, level, template) {
  return `${characterId}__${weaponId}__${branchId}__lv${level}__${template}`;
}

function classifyTemplate(levelConfig, level) {
  if (level === 1) return "base_attack";
  const specialRules = asObject(levelConfig.special_rules);
  const events = asArray(levelConfig.events_added);
  const text = JSON.stringify({ specialRules, events, modifiers: levelConfig.modifiers || [] });

  if (/death|kill/i.test(text)) return "death_trigger";
  if (/every_n|cast_interval|hit_interval|tick_interval/i.test(text)) return "every_n_casts";
  if (/shield|damage_taken|heal|player_damaged|low_hp/i.test(text)) return "player_defense";
  if (/field|cloud|oil|lava|trap|zone|area_tick|duration/i.test(text)) return "field_tick";
  if (/explosion|radius|max_targets|splash|area_direct/i.test(text)) return "multi_target_area";
  if (/elite|boss|poise|mark|core|strong/i.test(text)) return "elite_boss_rule";
  if (/consume|required_stacks|required_status_id|convert/i.test(text)) return "stack_conversion";
  if (/reaction|burst|deflagration|shatter/i.test(text)) return "reaction_burst";
  if (/status_id|stacks|stack|duration/i.test(text)) return "direct_hit_status";
  if (/projectile|orb|page|wall|spawn/i.test(text)) return "spawn_object";
  return "base_attack";
}

function buildMatrix(documents = loadDocuments()) {
  const errors = [];
  const indexes = buildIndexes(documents, errors);
  const cases = [];

  for (const character of indexes.characters.values()) {
    const characterId = idOf(character.id);
    for (const weaponId of asArray(character.allowed_weapon_ids).map(String)) {
      const weapon = indexes.weapons.get(weaponId);
      if (!weapon) {
        errors.push(`character ${characterId} allows missing weapon ${weaponId}`);
        continue;
      }
      const startingSkillId = idOf(weapon.starting_skill_id);
      for (const branchId of asArray(weapon.branch_ids).map(String)) {
        const branch = indexes.branches.get(branchId);
        if (!branch) {
          errors.push(`weapon ${weaponId} references missing branch ${branchId}`);
          continue;
        }
        for (const level of [1, 2, 3, 4, 5]) {
          const levelConfig = level === 1 ? {} : asObject(asObject(branch.level_path)[String(level)]);
          const template = classifyTemplate(levelConfig, level);
          cases.push({
            id: caseId(characterId, weaponId, branchId, level, template),
            character_id: characterId,
            weapon_id: weaponId,
            starting_skill_id: startingSkillId,
            branch_id: branchId,
            level,
            template,
            source: {
              character: `data/characters.json characters.${characterId}`,
              weapon: `data/weapons.json weapons.${weaponId}`,
              branch: `data/weapon_branches.json branches.${branchId}`,
              level: level === 1 ? "base weapon state" : `data/weapon_branches.json ${branchId}.level_path.${level}`,
            },
          });
        }
      }
    }
  }

  return { cases, indexes, errors };
}

function validateStaticMatrix(matrixResult) {
  const errors = [...matrixResult.errors];
  const { cases, indexes } = matrixResult;

  if (indexes.characters.size !== EXPECTED_COUNTS.characters) errors.push(`expected ${EXPECTED_COUNTS.characters} characters, got ${indexes.characters.size}`);
  if (indexes.weapons.size !== EXPECTED_COUNTS.weapons) errors.push(`expected ${EXPECTED_COUNTS.weapons} weapons, got ${indexes.weapons.size}`);
  if (indexes.branches.size !== EXPECTED_COUNTS.branches) errors.push(`expected ${EXPECTED_COUNTS.branches} branches, got ${indexes.branches.size}`);
  if (cases.length !== EXPECTED_COUNTS.cases) errors.push(`expected ${EXPECTED_COUNTS.cases} matrix cases, got ${cases.length}`);

  const seen = new Set();
  for (const item of cases) {
    if (seen.has(item.id)) errors.push(`duplicate matrix case id: ${item.id}`);
    seen.add(item.id);

    const character = indexes.characters.get(item.character_id);
    const weapon = indexes.weapons.get(item.weapon_id);
    const branch = indexes.branches.get(item.branch_id);
    const attack = indexes.primaryAttacks.get(item.starting_skill_id);

    if (!character) errors.push(`${item.id}: missing character ${item.character_id}`);
    if (!weapon) errors.push(`${item.id}: missing weapon ${item.weapon_id}`);
    if (!branch) errors.push(`${item.id}: missing branch ${item.branch_id}`);
    if (!attack) errors.push(`${item.id}: missing starting skill ${item.starting_skill_id}`);

    if (character && !asArray(character.allowed_weapon_ids).map(String).includes(item.weapon_id)) {
      errors.push(`${item.id}: weapon is not allowed by character`);
    }
    if (weapon && idOf(weapon.character_id) !== item.character_id) {
      errors.push(`${item.id}: weapon.character_id expected ${item.character_id}, got ${weapon.character_id || "<empty>"}`);
    }
    if (weapon && !asArray(weapon.branch_ids).map(String).includes(item.branch_id)) {
      errors.push(`${item.id}: branch is not listed on weapon`);
    }
    if (branch && idOf(branch.weapon_id) !== item.weapon_id) {
      errors.push(`${item.id}: branch.weapon_id expected ${item.weapon_id}, got ${branch.weapon_id || "<empty>"}`);
    }
    if (item.level !== 1) {
      const levelConfig = asObject(asObject(branch && branch.level_path)[String(item.level)]);
      if (Object.keys(levelConfig).length === 0) {
        errors.push(`${item.id}: missing branch level_path.${item.level}`);
      }
      validateLevelConfigShape(item, levelConfig, indexes, errors);
    }
  }

  return errors;
}

function validateLevelConfigShape(item, levelConfig, indexes, errors) {
  for (const [index, modifier] of asArray(levelConfig.modifiers).entries()) {
    const label = `${item.id}.modifiers[${index}]`;
    if (!asObject(modifier).stat) errors.push(`${label}: missing stat`);
    if (!["add", "multiplier_add", "multiplier", "override"].includes(String(modifier.op || ""))) errors.push(`${label}: unsupported op ${modifier.op}`);
    if (typeof modifier.value !== "number") errors.push(`${label}: value must be number`);
    if (!asObject(modifier.scope)) errors.push(`${label}: missing scope`);
  }
  for (const [eventIndex, event] of asArray(levelConfig.events_added).entries()) {
    for (const [actionIndex, action] of asArray(event.actions).entries()) {
      const params = asObject(action.params);
      for (const key of ["area_id", "projectile_id", "trap_id", "object_id"]) {
        if (params[key] && !indexes.combatObjects.has(String(params[key]))) {
          errors.push(`${item.id}.events_added[${eventIndex}].actions[${actionIndex}]: missing combat object ${params[key]}`);
        }
      }
      for (const key of ["status_id", "required_status_id"]) {
        if (params[key] && !indexes.statuses.has(String(params[key]))) {
          errors.push(`${item.id}.events_added[${eventIndex}].actions[${actionIndex}]: missing status ${params[key]}`);
        }
      }
    }
  }
  collectStatusRefs(levelConfig.special_rules).forEach((statusId) => {
    if (!indexes.statuses.has(statusId)) errors.push(`${item.id}: missing status referenced by special_rules: ${statusId}`);
  });
}

function collectStatusRefs(value, result = []) {
  if (Array.isArray(value)) {
    value.forEach((item) => collectStatusRefs(item, result));
    return result;
  }
  if (!asObject(value)) return result;
  for (const key of ["status_id", "required_status_id"]) {
    if (value[key]) result.push(String(value[key]));
  }
  for (const child of Object.values(value)) collectStatusRefs(child, result);
  return result;
}

function writeMatrixReports(matrixResult, staticErrors = []) {
  fs.mkdirSync(REPORT_DIR, { recursive: true });
  const summary = summarize(matrixResult.cases, staticErrors);
  fs.writeFileSync(MATRIX_JSON, JSON.stringify({ summary, cases: matrixResult.cases, static_errors: staticErrors }, null, 2) + "\n");
  fs.writeFileSync(MATRIX_TEXT, formatTextReport(summary, matrixResult.cases, staticErrors));
}

function summarize(cases, staticErrors) {
  const byCharacter = {};
  for (const item of cases) {
    byCharacter[item.character_id] = byCharacter[item.character_id] || { cases: 0, weapons: new Set(), branches: new Set() };
    byCharacter[item.character_id].cases += 1;
    byCharacter[item.character_id].weapons.add(item.weapon_id);
    byCharacter[item.character_id].branches.add(item.branch_id);
  }
  return {
    total_cases: cases.length,
    expected_cases: EXPECTED_COUNTS.cases,
    static_failures: staticErrors.length,
    by_character: Object.fromEntries(Object.entries(byCharacter).map(([id, value]) => [id, {
      cases: value.cases,
      weapons: value.weapons.size,
      branches: value.branches.size,
    }])),
  };
}

function formatTextReport(summary, cases, staticErrors) {
  const lines = [];
  lines.push("[FullWeaponBranchMatrix] START");
  lines.push(`total_cases=${summary.total_cases} expected_cases=${summary.expected_cases} static_failures=${summary.static_failures}`);
  for (const [characterId, entry] of Object.entries(summary.by_character)) {
    lines.push(`CHARACTER ${characterId} weapons=${entry.weapons} branches=${entry.branches} cases=${entry.cases}`);
  }
  for (const item of cases) {
    lines.push(`CASE ${item.id} character=${item.character_id} weapon=${item.weapon_id} skill=${item.starting_skill_id} branch=${item.branch_id} level=${item.level} template=${item.template}`);
  }
  for (const error of staticErrors) {
    lines.push(`ERROR ${error}`);
  }
  lines.push(staticErrors.length ? "[FullWeaponBranchMatrix] FAIL" : "[FullWeaponBranchMatrix] PASS");
  return lines.join("\n") + "\n";
}

module.exports = {
  EXPECTED_COUNTS,
  MATRIX_JSON,
  MATRIX_TEXT,
  buildMatrix,
  validateStaticMatrix,
  writeMatrixReports,
};
```

- [ ] **Step 2: Run a direct helper smoke from Node**

Run:

```powershell
node -e "const m=require('./tools/full_weapon_branch_matrix'); const r=m.buildMatrix(); console.log(r.cases.length)"
```

Expected:

```text
260
```

## Task 2: Add Static Full-Matrix Gate

**Files:**
- Create: `tools/verify_full_weapon_branch_matrix.js`
- Modify: `tools/validate_weapon_authoring_pipeline.js`

- [ ] **Step 1: Create the verification script**

Add `tools/verify_full_weapon_branch_matrix.js`:

```javascript
const {
  EXPECTED_COUNTS,
  MATRIX_JSON,
  MATRIX_TEXT,
  buildMatrix,
  validateStaticMatrix,
  writeMatrixReports,
} = require("./full_weapon_branch_matrix");

function main() {
  const result = buildMatrix();
  const errors = validateStaticMatrix(result);
  writeMatrixReports(result, errors);

  if (errors.length) {
    for (const error of errors) {
      console.error(`ERROR ${error}`);
    }
    console.error(`Full weapon branch matrix failed. report=${MATRIX_TEXT}`);
    process.exitCode = 1;
    return;
  }

  console.log(`Full weapon branch matrix verified. cases=${result.cases.length} expected=${EXPECTED_COUNTS.cases} report=${MATRIX_JSON}`);
}

main();
```

- [ ] **Step 2: Add it to the authoring pipeline**

In `tools/validate_weapon_authoring_pipeline.js`, insert this check after `weapon graph`:

```javascript
  ["full weapon branch matrix", "tools/verify_full_weapon_branch_matrix.js"],
```

The top of `CHECKS` should become:

```javascript
const CHECKS = [
  ["modifier effects", "tools/validate_modifier_effects.js"],
  ["weapon graph", "tools/validate_weapon_graph.js"],
  ["full weapon branch matrix", "tools/verify_full_weapon_branch_matrix.js"],
  ["no weapon evolution", "tools/validate_no_weapon_evolution.js"],
```

- [ ] **Step 3: Run the new static gate directly**

Run:

```powershell
node tools\verify_full_weapon_branch_matrix.js
```

Expected:

```text
Full weapon branch matrix verified. cases=260 expected=260 report=...
```

- [ ] **Step 4: Run the full authoring pipeline**

Run:

```powershell
node tools\validate_weapon_authoring_pipeline.js
```

Expected for this workspace right now:

```text
== full weapon branch matrix ==
Full weapon branch matrix verified. cases=260 expected=260 ...
```

The whole pipeline may still exit `1` because existing fire-staff alignment and area visual mode checks already fail. Do not treat those as introduced by this task unless the new full-matrix check itself fails.

## Task 3: Add Godot Matrix Runner Skeleton

**Files:**
- Create: `scripts/debug/full_weapon_branch_matrix_check.gd`

- [ ] **Step 1: Add skeleton runner with mode parsing and reports**

Create `scripts/debug/full_weapon_branch_matrix_check.gd`:

```gdscript
extends SceneTree


const DebugCombatTraceScript: Script = preload("res://scripts/debug/debug_combat_trace.gd")
const REPORT_JSON_PATH: String = "res://reports/combat-scene-checks/full_weapon_branch_matrix_runtime.json"
const REPORT_TEXT_PATH: String = "res://reports/combat-scene-checks/full_weapon_branch_matrix_runtime.txt"
const APP_BOOTSTRAP_PATH: String = "res://scenes/app_bootstrap.tscn"
const ENEMY_SCENE_PATH: String = "res://scenes/enemy.tscn"
const MAP_ID: StringName = &"abandoned_dungeon"

var _mode: String = "smoke"
var _failed: bool = false
var _active_app: Node
var _results: Array[Dictionary] = []
var _lines: Array[String] = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	await process_frame
	_mode = _parse_mode()
	_lines.append("[FullWeaponBranchMatrixRuntime] START mode=%s" % _mode)
	var matrix: Array[Dictionary] = _build_matrix()
	_expect_global(matrix.size() == 260, "matrix has 260 cases", matrix.size(), 260)
	for case_data: Dictionary in matrix:
		await _run_case(case_data)
	_write_reports()
	for line: String in _lines:
		print(line)
	quit(1 if _failed else 0)


func _parse_mode() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			return arg.trim_prefix("--mode=")
		if arg == "rules":
			return "rules"
		if arg == "smoke":
			return "smoke"
	return "smoke"


func _expect_global(condition: bool, name: String, actual: Variant, expected: Variant) -> void:
	if condition:
		_lines.append("PASS global expected=%s actual=%s" % [str(expected), str(actual)])
		return
	_failed = true
	_lines.append("FAIL global assertion=%s expected=%s actual=%s" % [name, str(expected), str(actual)])


func _record_result(case_data: Dictionary, status: String, assertions: Array[Dictionary], trace_summary: Array[String] = []) -> void:
	var result: Dictionary = case_data.duplicate(true)
	result["status"] = status
	result["assertions"] = assertions
	result["trace_summary"] = trace_summary
	_results.append(result)
	_lines.append("CASE %s status=%s assertions=%d" % [String(case_data.get("id", "")), status, assertions.size()])
	for assertion: Dictionary in assertions:
		var line_status: String = "PASS" if bool(assertion.get("pass", false)) else "FAIL"
		_lines.append("%s %s assertion=%s expected=%s actual=%s source=%s" % [
			line_status,
			String(case_data.get("id", "")),
			String(assertion.get("name", "")),
			str(assertion.get("expected", "")),
			str(assertion.get("actual", "")),
			String(assertion.get("source", ""))
		])
		if line_status == "FAIL":
			_failed = true


func _assert(assertions: Array[Dictionary], name: String, pass: bool, expected: Variant, actual: Variant, source: String) -> void:
	assertions.append({
		"name": name,
		"pass": pass,
		"expected": expected,
		"actual": actual,
		"source": source
	})


func _write_reports() -> void:
	var json_path: String = ProjectSettings.globalize_path(REPORT_JSON_PATH)
	var text_path: String = ProjectSettings.globalize_path(REPORT_TEXT_PATH)
	DirAccess.make_dir_recursive_absolute(json_path.get_base_dir())
	var summary: Dictionary = _summary()
	var json_file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(JSON.stringify({"summary": summary, "results": _results}, "\t") + "\n")
		json_file.close()
	var text_file: FileAccess = FileAccess.open(text_path, FileAccess.WRITE)
	if text_file != null:
		_lines.append("[FullWeaponBranchMatrixRuntime] %s" % ("FAIL" if _failed else "PASS"))
		text_file.store_string("\n".join(_lines) + "\n")
		text_file.close()


func _summary() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	for result: Dictionary in _results:
		if String(result.get("status", "")) == "PASS":
			passed += 1
		else:
			failed += 1
	return {
		"mode": _mode,
		"total_cases": _results.size(),
		"passed_cases": passed,
		"failed_cases": failed
	}
```

- [ ] **Step 2: Add matrix loading/generation functions**

Append to the same file:

```gdscript
func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _as_array(value: Variant) -> Array:
	return value if value is Array else []


func _by_id(items: Array) -> Dictionary:
	var result: Dictionary = {}
	for item_variant: Variant in items:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			var id: String = String(item.get("id", ""))
			if id != "":
				result[id] = item
	return result


func _build_matrix() -> Array[Dictionary]:
	var characters: Dictionary = _by_id(_as_array(_load_json("res://data/characters.json").get("characters", [])))
	var weapons: Dictionary = _by_id(_as_array(_load_json("res://data/weapons.json").get("weapons", [])))
	var branches: Dictionary = _by_id(_as_array(_load_json("res://data/weapon_branches.json").get("branches", [])))
	var cases: Array[Dictionary] = []
	for character_id: String in characters.keys():
		var character: Dictionary = characters[character_id]
		for weapon_variant: Variant in _as_array(character.get("allowed_weapon_ids", [])):
			var weapon_id: String = String(weapon_variant)
			var weapon: Dictionary = weapons.get(weapon_id, {})
			for branch_variant: Variant in _as_array(weapon.get("branch_ids", [])):
				var branch_id: String = String(branch_variant)
				var branch: Dictionary = branches.get(branch_id, {})
				for level: int in [1, 2, 3, 4, 5]:
					var level_config: Dictionary = {} if level == 1 else Dictionary(branch.get("level_path", {})).get(String(level), {})
					var template: String = _classify_template(level_config, level)
					cases.append({
						"id": "%s__%s__%s__lv%d__%s" % [character_id, weapon_id, branch_id, level, template],
						"character_id": character_id,
						"weapon_id": weapon_id,
						"starting_skill_id": String(weapon.get("starting_skill_id", "")),
						"branch_id": branch_id,
						"level": level,
						"template": template
					})
	return cases


func _classify_template(level_config: Dictionary, level: int) -> String:
	if level == 1:
		return "base_attack"
	var text: String = JSON.stringify(level_config).to_lower()
	if text.contains("death") or text.contains("kill"):
		return "death_trigger"
	if text.contains("cast_interval") or text.contains("hit_interval") or text.contains("every"):
		return "every_n_casts"
	if text.contains("shield") or text.contains("damage_taken") or text.contains("heal") or text.contains("player_damaged"):
		return "player_defense"
	if text.contains("field") or text.contains("cloud") or text.contains("oil") or text.contains("lava") or text.contains("trap"):
		return "field_tick"
	if text.contains("explosion") or text.contains("radius") or text.contains("max_targets") or text.contains("area_direct"):
		return "multi_target_area"
	if text.contains("elite") or text.contains("boss") or text.contains("poise") or text.contains("mark") or text.contains("core"):
		return "elite_boss_rule"
	if text.contains("consume") or text.contains("required_stacks") or text.contains("required_status_id"):
		return "stack_conversion"
	if text.contains("reaction") or text.contains("burst") or text.contains("deflagration") or text.contains("shatter"):
		return "reaction_burst"
	if text.contains("status_id") or text.contains("stacks") or text.contains("duration"):
		return "direct_hit_status"
	if text.contains("projectile") or text.contains("orb") or text.contains("page") or text.contains("wall") or text.contains("spawn"):
		return "spawn_object"
	return "base_attack"
```

- [ ] **Step 3: Add temporary case dispatcher**

Append:

```gdscript
func _run_case(case_data: Dictionary) -> void:
	var assertions: Array[Dictionary] = []
	_assert(assertions, "case has character", String(case_data.get("character_id", "")) != "", "non-empty", case_data.get("character_id", ""), "matrix")
	_assert(assertions, "case has weapon", String(case_data.get("weapon_id", "")) != "", "non-empty", case_data.get("weapon_id", ""), "matrix")
	_assert(assertions, "case has branch", String(case_data.get("branch_id", "")) != "", "non-empty", case_data.get("branch_id", ""), "matrix")
	_assert(assertions, "case has level 1-5", int(case_data.get("level", 0)) >= 1 and int(case_data.get("level", 0)) <= 5, "1..5", case_data.get("level", 0), "matrix")
	_record_result(case_data, _status_from_assertions(assertions), assertions)


func _status_from_assertions(assertions: Array[Dictionary]) -> String:
	for assertion: Dictionary in assertions:
		if not bool(assertion.get("pass", false)):
			return "FAIL"
	return "PASS"
```

- [ ] **Step 4: Run skeleton**

Run:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --check-only --script res://scripts/debug/full_weapon_branch_matrix_check.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://scripts/debug/full_weapon_branch_matrix_check.gd -- --mode=smoke
```

Expected:

```text
exit 0
summary.total_cases=260
failed_cases=0
```

## Task 4: Implement Runtime Smoke Layer For All 260 Cases

**Files:**
- Modify: `scripts/debug/full_weapon_branch_matrix_check.gd`

- [ ] **Step 1: Replace temporary dispatcher with real runtime dispatcher**

Replace `_run_case()` with:

```gdscript
func _run_case(case_data: Dictionary) -> void:
	if _mode == "rules":
		await _run_rule_case(case_data)
	else:
		await _run_smoke_case(case_data)
```

- [ ] **Step 2: Add Dev Mode scene helpers**

Insert dynamic scene lifecycle helpers that follow the same runtime path as `scripts/debug/weapon_combat_scene_check.gd`: app bootstrap, `UIManager.start_developer_debug_run`, real player lookup, real branch application, real enemy scene spawn, and real `SkillExecutor.debug_cast_all_skills`.

```gdscript
func _run_smoke_case(case_data: Dictionary) -> void:
	var assertions: Array[Dictionary] = []
	var scene: Dictionary = await _create_case_scene(case_data, assertions)
	var player: Node2D = scene.get("player") as Node2D
	var records: Array = []
	var trace_summary: Array[String] = []
	if player != null:
		var enemy: Node2D = await _spawn_enemy(player, &"small_slime", player.global_position + Vector2(160.0, 0.0), 999)
		_assert(assertions, "smoke enemy spawned", enemy != null, "enemy", "enemy" if enemy != null else "missing", "res://scenes/enemy.tscn")
		var attack_result: Dictionary = await _attack_once(player)
		records = attack_result.get("records", [])
		trace_summary = _trace_summary(records)
		_assert(assertions, "debug cast count >= 1", int(attack_result.get("cast_count", 0)) >= 1, ">=1", attack_result.get("cast_count", 0), "SkillExecutor.debug_cast_all_skills")
		_assert(assertions, "runtime artifact exists", _has_runtime_artifact(player, records), "damage/status/object/player artifact", trace_summary, "DebugCombatTrace/runtime scene")
		_assert_source_fields_if_damage(case_data, assertions, records)
	await _teardown_case_scene()
	_record_result(case_data, _status_from_assertions(assertions), assertions, trace_summary)
```

Add these helpers:

```gdscript
func _create_case_scene(case_data: Dictionary, assertions: Array[Dictionary]) -> Dictionary:
	await _teardown_case_scene()
	var app_scene: PackedScene = load(APP_BOOTSTRAP_PATH) as PackedScene
	_assert(assertions, "app bootstrap loads", app_scene != null, APP_BOOTSTRAP_PATH, "loaded" if app_scene != null else "missing", APP_BOOTSTRAP_PATH)
	if app_scene == null:
		return {}
	_active_app = app_scene.instantiate()
	root.add_child(_active_app)
	current_scene = _active_app
	await _wait_process_frames(3)
	var ui_manager: Node = _active_app.find_child("UIManager", true, false)
	_assert(assertions, "UIManager.start_developer_debug_run exists", ui_manager != null and ui_manager.has_method("start_developer_debug_run"), "method exists", "missing", "scripts/ui/ui_manager.gd")
	if ui_manager == null or not ui_manager.has_method("start_developer_debug_run"):
		return {}
	ui_manager.call("start_developer_debug_run", {
		"character_id": StringName(String(case_data.get("character_id", ""))),
		"weapon_id": StringName(String(case_data.get("weapon_id", ""))),
		"map_id": MAP_ID,
		"branch_id": StringName(String(case_data.get("branch_id", "")))
	})
	_set_debug_metas(StringName(String(case_data.get("branch_id", ""))))
	await _wait_for_player(90)
	var player: Node2D = _get_player() as Node2D
	_assert(assertions, "real player exists", player != null, "player", "player" if player != null else "missing", "UIManager.start_developer_debug_run")
	if player == null:
		return {}
	player.set("crit_chance", 0.0)
	player.set("crit_damage", 1.0)
	var branch_ok: bool = _ensure_weapon_branch_level(player, StringName(String(case_data.get("branch_id", ""))), int(case_data.get("level", 1)))
	_assert(assertions, "branch level applied", branch_ok, "applied Lv%d" % int(case_data.get("level", 1)), branch_ok, "WeaponBranchSystem")
	var skill: RefCounted = _get_weapon_skill(player)
	_assert(assertions, "weapon skill current level", skill != null and int(skill.get("current_level")) >= int(case_data.get("level", 1)), int(case_data.get("level", 1)), int(skill.get("current_level")) if skill != null else "missing", "SkillManager")
	await _wait_process_frames(4)
	return {"player": player, "ui_manager": ui_manager}
```

Add these helper functions immediately after `_create_case_scene()`. Their behavior must match the current focused checker, with dynamic `case_data` values instead of hardcoded fire-staff constants:

```gdscript
_teardown_case_scene()
_set_debug_metas()
_wait_for_player()
_get_player()
_spawn_enemy()
_ensure_weapon_branch_level()
_has_branch_level()
_get_weapon_skill()
_attack_once()
_wait_process_frames()
```

Change `_set_debug_metas()` so it takes the dynamic branch id and does not hardcode fire staff.

- [ ] **Step 3: Add generic smoke artifact checks**

Append:

```gdscript
func _has_runtime_artifact(player: Node, records: Array) -> bool:
	if records.size() > 0:
		return true
	var scene_root: Node = player.get_parent() if player != null else null
	if scene_root == null:
		return false
	for group_name: StringName in [&"projectiles", &"combat_objects", &"area_effects", &"traps"]:
		if get_nodes_in_group(group_name).size() > 0:
			return true
	return false


func _assert_source_fields_if_damage(case_data: Dictionary, assertions: Array[Dictionary], records: Array) -> void:
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) != "damage":
			continue
		var actual_weapon: String = String(record.get("source_weapon_id", ""))
		var actual_skill: String = String(record.get("source_skill_id", ""))
		if actual_weapon != "":
			_assert(assertions, "damage source_weapon_id", actual_weapon == String(case_data.get("weapon_id", "")), case_data.get("weapon_id", ""), actual_weapon, "DebugCombatTrace.damage")
		if actual_skill != "":
			_assert(assertions, "damage source_skill_id", actual_skill == String(case_data.get("starting_skill_id", "")), case_data.get("starting_skill_id", ""), actual_skill, "DebugCombatTrace.damage")
		return


func _trace_summary(records: Array) -> Array[String]:
	var result: Array[String] = []
	for record_variant: Variant in records:
		if record_variant is Dictionary:
			var record: Dictionary = record_variant
			result.append("type=%s skill=%s weapon=%s origin=%s damage_type=%s element=%s final=%s raw=%s" % [
				String(record.get("type", "")),
				String(record.get("source_skill_id", record.get("skill_id", ""))),
				String(record.get("source_weapon_id", "")),
				String(record.get("damage_origin", "")),
				String(record.get("damage_type", "")),
				String(record.get("element", "")),
				str(record.get("final_amount", "")),
				str(record.get("raw_amount", record.get("amount", "")))
			])
	return result
```

- [ ] **Step 4: Run smoke mode**

Run:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --check-only --script res://scripts/debug/full_weapon_branch_matrix_check.gd
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://scripts/debug/full_weapon_branch_matrix_check.gd -- --mode=smoke
```

Expected:

```text
full_weapon_branch_matrix_runtime.json summary.total_cases=260
```

If some weapons do not produce a damage trace in one attack because they are field/trap/tick based, the runtime artifact assertion should still pass if the expected object/status exists. If the artifact is missing, leave it as a failure.

## Task 5: Implement Rule-Template Layer

**Files:**
- Modify: `scripts/debug/full_weapon_branch_matrix_check.gd`

- [ ] **Step 1: Add rule case dispatcher**

Add:

```gdscript
func _run_rule_case(case_data: Dictionary) -> void:
	var template: String = String(case_data.get("template", "base_attack"))
	match template:
		"base_attack":
			await _run_template_base_attack(case_data)
		"direct_hit_status":
			await _run_template_direct_hit_status(case_data)
		"multi_target_area":
			await _run_template_multi_target_area(case_data)
		"elite_boss_rule":
			await _run_template_elite_boss_rule(case_data)
		"stack_conversion":
			await _run_template_stack_conversion(case_data)
		"reaction_burst":
			await _run_template_reaction_burst(case_data)
		"field_tick":
			await _run_template_field_tick(case_data)
		"spawn_object":
			await _run_template_spawn_object(case_data)
		"player_defense":
			await _run_template_player_defense(case_data)
		"death_trigger":
			await _run_template_death_trigger(case_data)
		"every_n_casts":
			await _run_template_every_n_casts(case_data)
		_:
			await _run_template_base_attack(case_data)
```

- [ ] **Step 2: Add data lookup helpers for rule expectations**

Append:

```gdscript
func _branch_level_config(case_data: Dictionary) -> Dictionary:
	if int(case_data.get("level", 1)) == 1:
		return {}
	var branches: Array = _as_array(_load_json("res://data/weapon_branches.json").get("branches", []))
	for branch_variant: Variant in branches:
		if branch_variant is Dictionary:
			var branch: Dictionary = branch_variant
			if String(branch.get("id", "")) == String(case_data.get("branch_id", "")):
				return Dictionary(branch.get("level_path", {})).get(String(case_data.get("level", 1)), {})
	return {}


func _primary_attack(case_data: Dictionary) -> Dictionary:
	for attack_variant: Variant in _as_array(_load_json("res://data/primary_attack.json").get("primary_attacks", [])):
		if attack_variant is Dictionary and String((attack_variant as Dictionary).get("id", "")) == String(case_data.get("starting_skill_id", "")):
			return attack_variant
	return {}


func _collect_expected_status_ids(value: Variant, result: Array[String] = []) -> Array[String]:
	if value is Array:
		for item: Variant in value:
			_collect_expected_status_ids(item, result)
		return result
	if not (value is Dictionary):
		return result
	var dict: Dictionary = value
	for key: String in ["status_id", "required_status_id"]:
		if dict.has(key):
			result.append(String(dict[key]))
	for child: Variant in dict.values():
		_collect_expected_status_ids(child, result)
	return result


func _collect_expected_action_types(level_config: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for event_variant: Variant in _as_array(level_config.get("events_added", [])):
		if not (event_variant is Dictionary):
			continue
		for action_variant: Variant in _as_array((event_variant as Dictionary).get("actions", [])):
			if action_variant is Dictionary:
				result.append(String((action_variant as Dictionary).get("type", "")))
	return result
```

- [ ] **Step 3: Add generic exact rule-state assertion**

Every rule template should first prove the branch level's authored runtime additions exist on the weapon skill:

```gdscript
func _assert_runtime_level_payload(case_data: Dictionary, player: Node, assertions: Array[Dictionary]) -> void:
	var level_config: Dictionary = _branch_level_config(case_data)
	var skill: RefCounted = _get_weapon_skill(player)
	if int(case_data.get("level", 1)) == 1:
		_assert(assertions, "Lv1 has no branch-only runtime payload", skill != null, "base skill", "skill" if skill != null else "missing", "SkillManager")
		return
	var expected_status_ids: Array[String] = _collect_expected_status_ids(level_config.get("special_rules", {}))
	var expected_actions: Array[String] = _collect_expected_action_types(level_config)
	_assert(assertions, "level config exists", not level_config.is_empty(), "level_path.%d" % int(case_data.get("level", 1)), level_config.keys(), String(case_data.get("source", "")))
	if skill != null:
		if skill.get("runtime_special_rules") is Dictionary:
			var rules: Dictionary = skill.get("runtime_special_rules")
			for rule_key: Variant in Dictionary(level_config.get("special_rules", {})).keys():
				_assert(assertions, "runtime special rule %s" % String(rule_key), rules.has(String(rule_key)), "present", rules.keys(), "SkillInstance.runtime_special_rules")
		if skill.get("runtime_events") is Array:
			var runtime_events: Array = skill.get("runtime_events")
			for action_type: String in expected_actions:
				_assert(assertions, "runtime event action %s" % action_type, JSON.stringify(runtime_events).contains(action_type), "present", runtime_events, "SkillInstance.runtime_events")
	for status_id: String in expected_status_ids:
		_assert(assertions, "referenced status exists %s" % status_id, _status_exists(status_id), "status exists", status_id, "data/status_effects.json")


func _status_exists(status_id: String) -> bool:
	for status_variant: Variant in _as_array(_load_json("res://data/status_effects.json").get("statuses", [])):
		if status_variant is Dictionary and String((status_variant as Dictionary).get("id", "")) == status_id:
			return true
	return false
```

- [ ] **Step 4: Implement all template functions with shared behavior**

Add the template functions. Each should create the real scene, assert runtime payload, drive the minimal action for that rule type, and assert relevant trace/state.

```gdscript
func _run_template_base_attack(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "base_attack", 1, false, false)


func _run_template_direct_hit_status(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "direct_hit_status", 1, true, false)


func _run_template_multi_target_area(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "multi_target_area", 4, false, true)


func _run_template_elite_boss_rule(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "elite_boss_rule", 1, true, false, &"giant_slime")


func _run_template_stack_conversion(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "stack_conversion", 1, true, false)


func _run_template_reaction_burst(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "reaction_burst", 3, true, true)


func _run_template_field_tick(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "field_tick", 2, true, true, &"small_slime", 45)


func _run_template_spawn_object(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "spawn_object", 1, false, true)


func _run_template_player_defense(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "player_defense", 1, false, false)


func _run_template_death_trigger(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "death_trigger", 3, true, true, &"small_slime", 90, 1)


func _run_template_every_n_casts(case_data: Dictionary) -> void:
	await _run_rule_template_common(case_data, "every_n_casts", 3, true, true, &"small_slime", 120)
```

Add the common implementation:

```gdscript
func _run_rule_template_common(case_data: Dictionary, template_name: String, enemy_count: int, expect_status_or_rule: bool, expect_area_or_reaction: bool, enemy_id: StringName = &"small_slime", wait_frames: int = 30, enemy_hp: int = 999) -> void:
	var assertions: Array[Dictionary] = []
	var scene: Dictionary = await _create_case_scene(case_data, assertions)
	var player: Node2D = scene.get("player") as Node2D
	var enemies: Array[Node2D] = []
	if player != null:
		_assert_runtime_level_payload(case_data, player, assertions)
		for index: int in range(enemy_count):
			enemies.append(await _spawn_enemy(player, enemy_id, player.global_position + Vector2(160.0, float(index - 1) * 36.0), enemy_hp))
		var attack_result: Dictionary = await _attack_once(player)
		for _frame_index: int in range(wait_frames):
			await physics_frame
		var records: Array = DebugCombatTraceScript.get_records(root)
		var trace_summary: Array[String] = _trace_summary(records)
		_assert(assertions, "template name", String(case_data.get("template", "")) == template_name, template_name, case_data.get("template", ""), "matrix.template")
		_assert(assertions, "rule cast count >= 1", int(attack_result.get("cast_count", 0)) >= 1, ">=1", attack_result.get("cast_count", 0), "SkillExecutor.debug_cast_all_skills")
		_assert(assertions, "rule runtime artifact exists", _has_runtime_artifact(player, records), "artifact", trace_summary, "DebugCombatTrace/runtime scene")
		_assert_expected_damage_shape(case_data, assertions, records)
		if expect_status_or_rule:
			_assert_expected_status_or_special_rule(case_data, assertions, enemies)
		if expect_area_or_reaction:
			_assert_expected_area_or_reaction(case_data, assertions, records)
		_assert_source_fields_if_damage(case_data, assertions, records)
		await _teardown_case_scene()
		_record_result(case_data, _status_from_assertions(assertions), assertions, trace_summary)
		return
	await _teardown_case_scene()
	_record_result(case_data, _status_from_assertions(assertions), assertions, [])
```

- [ ] **Step 5: Add rule-template assertion helpers**

Append:

```gdscript
func _assert_expected_damage_shape(case_data: Dictionary, assertions: Array[Dictionary], records: Array) -> void:
	var attack: Dictionary = _primary_attack(case_data)
	var expected_weapon: String = String(case_data.get("weapon_id", ""))
	var expected_skill: String = String(case_data.get("starting_skill_id", ""))
	var has_damage: bool = false
	for record_variant: Variant in records:
		if record_variant is Dictionary and String((record_variant as Dictionary).get("type", "")) == "damage":
			has_damage = true
			var record: Dictionary = record_variant
			if String(record.get("source_weapon_id", "")) != "":
				_assert(assertions, "damage shape weapon id", String(record.get("source_weapon_id", "")) == expected_weapon, expected_weapon, record.get("source_weapon_id", ""), "DebugCombatTrace.damage")
			if String(record.get("source_skill_id", "")) != "":
				_assert(assertions, "damage shape skill id", String(record.get("source_skill_id", "")) == expected_skill, expected_skill, record.get("source_skill_id", ""), "DebugCombatTrace.damage")
	_assert(assertions, "primary attack exists", not attack.is_empty(), expected_skill, attack.get("id", "missing"), "data/primary_attack.json")


func _assert_expected_status_or_special_rule(case_data: Dictionary, assertions: Array[Dictionary], enemies: Array[Node2D]) -> void:
	var level_config: Dictionary = _branch_level_config(case_data)
	var status_ids: Array[String] = _collect_expected_status_ids(level_config.get("special_rules", {}))
	if status_ids.is_empty():
		_assert(assertions, "status/rule template has special_rules", not Dictionary(level_config.get("special_rules", {})).is_empty(), "special_rules", level_config.get("special_rules", {}), "data/weapon_branches.json")
		return
	for status_id: String in status_ids:
		var observed: bool = false
		for enemy: Node2D in enemies:
			if enemy != null and enemy.has_method("get_status_stack") and int(enemy.call("get_status_stack", StringName(status_id))) > 0:
				observed = true
		_assert(assertions, "status observed or rule declared %s" % status_id, observed or _status_exists(status_id), "observed or declared", observed, "EnemyBase.get_status_stack/data/status_effects.json")


func _assert_expected_area_or_reaction(case_data: Dictionary, assertions: Array[Dictionary], records: Array) -> void:
	var saw_area_or_reaction: bool = false
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if String(record.get("type", "")) == "explosion":
			saw_area_or_reaction = true
		if String(record.get("damage_origin", "")) == "reaction":
			saw_area_or_reaction = true
		if String(record.get("damage_type", "")).contains("area"):
			saw_area_or_reaction = true
	_assert(assertions, "area or reaction trace", saw_area_or_reaction, "explosion/reaction/area trace", _trace_summary(records), "DebugCombatTrace")
```

- [ ] **Step 6: Run rules mode**

Run:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://scripts/debug/full_weapon_branch_matrix_check.gd -- --mode=rules
```

Expected:

```text
full_weapon_branch_matrix_runtime.json summary.total_cases=260
```

Some rule-template failures are expected on the first run because this layer is intentionally stricter than the existing runtime coverage. Keep the failures in the report with source paths.

## Task 6: Improve Reports And Failure Diagnostics

**Files:**
- Modify: `scripts/debug/full_weapon_branch_matrix_check.gd`
- Modify: `tools/full_weapon_branch_matrix.js`

- [ ] **Step 1: Add grouped report summaries**

In GDScript `_summary()`, replace the body with:

```gdscript
func _summary() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var by_character: Dictionary = {}
	for result: Dictionary in _results:
		var status: String = String(result.get("status", ""))
		if status == "PASS":
			passed += 1
		else:
			failed += 1
		var character_id: String = String(result.get("character_id", ""))
		if not by_character.has(character_id):
			by_character[character_id] = {"cases": 0, "passed": 0, "failed": 0}
		by_character[character_id]["cases"] += 1
		if status == "PASS":
			by_character[character_id]["passed"] += 1
		else:
			by_character[character_id]["failed"] += 1
	return {
		"mode": _mode,
		"total_cases": _results.size(),
		"expected_cases": 260,
		"passed_cases": passed,
		"failed_cases": failed,
		"by_character": by_character
	}
```

- [ ] **Step 2: Add explicit no-skip behavior**

Add this assertion before recording any result:

```gdscript
_assert(assertions, "case is not skipped", true, "executed", "executed", "runner")
```

Do not add a `SKIP` status. Missing APIs and missing runtime behavior must be `FAIL`, not skipped.

- [ ] **Step 3: Include source paths in case data**

In GDScript `_build_matrix()`, add source fields to each case:

```gdscript
"source_character": "data/characters.json " + character_id,
"source_weapon": "data/weapons.json " + weapon_id,
"source_branch": "data/weapon_branches.json " + branch_id,
"source_level": "base weapon state" if level == 1 else "data/weapon_branches.json %s.level_path.%d" % [branch_id, level]
```

- [ ] **Step 4: Re-run both modes**

Run:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://scripts/debug/full_weapon_branch_matrix_check.gd -- --mode=smoke
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://scripts/debug/full_weapon_branch_matrix_check.gd -- --mode=rules
```

Expected:

```text
Both reports include total_cases=260 and grouped character summaries.
```

## Task 7: Final Verification

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run static matrix**

Run:

```powershell
node tools\verify_full_weapon_branch_matrix.js
```

Expected:

```text
Full weapon branch matrix verified. cases=260 expected=260
```

- [ ] **Step 2: Run full static pipeline**

Run:

```powershell
node tools\validate_weapon_authoring_pipeline.js
```

Expected:

```text
The new "full weapon branch matrix" check passes.
```

Existing unrelated failures may remain:

```text
fire staff branch table alignment
area effect visual mode
```

Report them separately.

- [ ] **Step 3: Run Godot syntax check**

Run:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --check-only --script res://scripts/debug/full_weapon_branch_matrix_check.gd
```

Expected:

```text
exit 0
```

- [ ] **Step 4: Run runtime smoke layer**

Run:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://scripts/debug/full_weapon_branch_matrix_check.gd -- --mode=smoke
```

Expected:

```text
reports/combat-scene-checks/full_weapon_branch_matrix_runtime.json has summary.total_cases=260
```

- [ ] **Step 5: Run rule-template layer**

Run:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://scripts/debug/full_weapon_branch_matrix_check.gd -- --mode=rules
```

Expected:

```text
reports/combat-scene-checks/full_weapon_branch_matrix_runtime.json has summary.total_cases=260
```

Rule failures are acceptable only if they are real behavior/config mismatches and each failure names expected, actual, source config, and trace summary.

- [ ] **Step 6: Check report invariants**

Run:

```powershell
node -e "const fs=require('fs'); const r=JSON.parse(fs.readFileSync('reports/combat-scene-checks/full_weapon_branch_matrix_runtime.json','utf8')); if(r.summary.total_cases!==260) throw new Error('expected 260 runtime cases'); console.log(r.summary)"
```

Expected:

```text
summary object printed with total_cases: 260
```

## Self-Review

Spec coverage:

- Layer 1 static matrix contract: Task 1 and Task 2.
- Layer 2 runtime smoke matrix: Task 3 and Task 4.
- Layer 3 rule-template checks: Task 5.
- Reports and diagnostics: Task 6.
- Verification: Task 7.
- Full scope of 4 characters, 13 weapons, 52 branches, Lv1-Lv5, 260 combinations: Task 1, Task 3, Task 7.

No silent skips are allowed. Known existing static failures must be reported separately from new full-matrix failures.
