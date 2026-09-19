# Skill Learn Option Builder Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract deterministic god-skill learn-card data construction from `UpgradePool` into a pure `SkillLearnOptionBuilder` without changing option output, eligibility, randomness, weighting, guarantees, or external interfaces.

**Architecture:** `UpgradePool` remains the runtime facade and retains definition access, player/service queries, candidate order, maximum-level calculation, rarity RNG, final `UpgradeOption` instantiation, weighting, de-duplication, and guarantees. The new Builder accepts explicit `skill`, `upgrade`, and `rarity` values and returns only an owned plain dictionary matching the existing card data.

**Tech Stack:** Godot 4.6.3, typed GDScript, Node.js CommonJS validation scripts, PowerShell verification on Windows.

**Spec:** `docs/superpowers/specs/2026-09-19-skill-learn-option-builder-design.md`

## Global Constraints

- Do not change gameplay rules, skill behavior, numerical balance, drops, UI, visuals, configuration IDs, JSON schemas, resource paths, save data, signals, node paths, or public methods.
- Keep `_build_god_skill_learn_options(player: Node) -> Array` and `_build_fire_skill_learn_options(player: Node, god_id: StringName = &"fire") -> Array` available with unchanged behavior.
- Keep definition access, eligibility, player/service queries, candidate order, maximum-level calculation, rarity selection, RNG call count/order, final option instantiation, weighting, de-duplication, and guarantees in `UpgradePool` or their existing owners.
- `SkillLearnOptionBuilder` must not access autoloads, nodes, services, RNG, logging, the SceneTree, `UpgradeOption`, or mutable global state.
- Preserve exact option keys, fallback behavior, fixed Chinese copy, payload types, rarity pass-through, and mutable-value ownership defined in the specification.
- Do not generalize other upgrade-card paths or modify debug-card construction in this batch.
- Implement production changes only after the focused test has been observed failing for the expected missing-interface or missing-delegation reason.
- Run Godot tests sequentially on this Windows host.
- Preserve the existing untracked `.uid` files; never stage, modify, delete, or overwrite them.
- Do not push, merge, or create a PR without separate user authorization.

## File Structure

- Create `scripts/upgrades/skill_learn_option_builder.gd`: pure learn-skill option-data construction and private deterministic fallback helpers.
- Modify `scripts/upgrades/upgrade_pool.gd`: preload the Builder and replace only the inline learn-card dictionary with a Builder call; retain orchestration and `_make_option()`.
- Create `tools/verify/verify_skill_learn_option_builder.gd`: direct Builder output, fallback, type, ownership, and non-mutation tests.
- Create `tools/verify/verify_skill_learn_option_builder_boundary.js`: structural ownership and delegation contract.
- Modify `tools/verify/verify_fire_skill_upgrade_pool.js`: move two inline-data marker expectations to the Builder while preserving all existing pool and eligibility assertions.
- Modify `package.json`: expose the two focused Stage 4 verifiers.
- Modify `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`: record the completed Stage 4 boundary and keep weight-policy work deferred.

## Review Focus

- An explicitly null `upgrade.display_name` must fall directly to the skill ID, while an absent key may use `skill.display_name`; Task 1 tests both cases.
- Empty strings are existing valid values and must not be silently repaired into fallback text; Task 1 tests empty display name and empty first level description.
- Returned tags and payload must be independently owned so result mutation cannot alter source dictionaries or a later build result; Task 1 mutates both and rebuilds.
- Texture fallback must inspect the skill only and must not start using an upgrade texture; Task 1 supplies an upgrade-only texture and expects an empty result.
- A missing skill maximum level must use the upgrade maximum, while zero or negative values clamp to one without affecting rarity; Task 1 tests fallback, clamping, and exact rarity pass-through.

---

### Task 1: Add the Pure Skill Learn Option Builder

**Files:**
- Create: `tools/verify/verify_skill_learn_option_builder.gd`
- Create: `scripts/upgrades/skill_learn_option_builder.gd`
- Modify: `package.json`

**Interfaces:**
- Consumes: plain `Dictionary skill`, `Dictionary upgrade`, and already selected `String rarity`.
- Produces: `SkillLearnOptionBuilder.build_option_data(skill: Dictionary, upgrade: Dictionary, rarity: String) -> Dictionary`.

- [ ] **Step 1: Protect the worktree and record the pre-change focused baseline**

Run:

```powershell
git status --short --branch
npm run verify:skill-growth-upgrade-pool
npm run verify:upgrade-pool-no-relic-fireball-god-mix
npm run verify:god-school-learning-rules
npm run verify:skill-card-scaled-values-and-rarity
npm run verify:fire-skill-upgrade-pool
npm run verify:upgrade-pool-missing-rarity
```

Run Godot-backed commands sequentially. Expected: all six existing checks pass. Record the two untracked user `.uid` files and do not stage them.

- [ ] **Step 2: Write the failing direct Builder verifier**

Create `tools/verify/verify_skill_learn_option_builder.gd`:

```gdscript
extends SceneTree


const BuilderScript: Script = preload("res://scripts/upgrades/skill_learn_option_builder.gd")


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_complete_result_and_ownership()
	_verify_display_name_fallbacks()
	_verify_description_fallbacks()
	_verify_texture_and_level_fallbacks()
	_verify_invalid_and_malformed_inputs()
	if not _failed:
		print("[verify_skill_learn_option_builder] PASS")
	quit(1 if _failed else 0)


func _verify_complete_result_and_ownership() -> void:
	var skill: Dictionary = {
		"id": "fire_attack_searing",
		"display_name": "Searing",
		"max_level": 5,
		"background_texture": "res://skill-primary.png",
		"card_background_texture": "res://skill-card.png",
	}
	var upgrade: Dictionary = {
		"id": "learn_skill_fire_attack_searing",
		"display_name": "Learn Searing",
		"description": "fallback description",
		"level_descriptions": ["first description", "second description"],
		"tags": ["fire", {"nested": [1]}],
	}
	var skill_before: Dictionary = skill.duplicate(true)
	var upgrade_before: Dictionary = upgrade.duplicate(true)
	var result: Dictionary = BuilderScript.build_option_data(skill, upgrade, "epic")
	var expected_keys: Array[String] = [
		"affected_origin", "background_texture", "description", "display_name", "does_not_affect",
		"id", "level_text", "payload", "rarity", "recommended_reason", "tags", "type",
	]
	var actual_keys: Array[String] = []
	for key: Variant in result.keys():
		actual_keys.append(str(key))
	actual_keys.sort()
	_expect(actual_keys == expected_keys, "complete result has the exact key set", actual_keys)
	_expect(str(result.get("id", "")) == "level_up_upgrade:learn_skill_fire_attack_searing:epic", "option id is unchanged", result)
	_expect(str(result.get("type", "")) == "level_up_upgrade", "option type is unchanged", result)
	_expect(str(result.get("display_name", "")) == "Learn Searing", "upgrade display name wins", result)
	_expect(str(result.get("description", "")) == "first description", "first level description wins", result)
	_expect(str(result.get("rarity", "")) == "epic", "rarity passes through exactly", result)
	_expect(str(result.get("background_texture", "")) == "res://skill-primary.png", "primary skill texture wins", result)
	_expect(str(result.get("affected_origin", "")) == "神系技能", "affected origin is unchanged", result)
	_expect(str(result.get("does_not_affect", "")) == "不替换角色初始技能。", "does-not-affect text is unchanged", result)
	_expect(str(result.get("recommended_reason", "")) == "从神系技能池学习一个新技能。", "recommendation text is unchanged", result)
	_expect(str(result.get("level_text", "")) == "Lv1 / 5", "level text is unchanged", result)
	var payload: Dictionary = result.get("payload", {}) as Dictionary
	_expect(payload.get("upgrade_id") is StringName and payload.get("upgrade_id") == &"learn_skill_fire_attack_searing", "payload upgrade id is StringName", payload)
	_expect(payload.get("learn_skill_id") is StringName and payload.get("learn_skill_id") == &"fire_attack_searing", "payload skill id is StringName", payload)
	_expect(int(payload.get("level", 0)) == 1 and str(payload.get("target_rarity", "")) == "epic", "payload level and rarity are unchanged", payload)
	var returned_tags: Array = result.get("tags", []) as Array
	var returned_nested_tag: Dictionary = returned_tags[1] as Dictionary
	returned_nested_tag["nested"] = [9]
	payload["level"] = 99
	_expect(skill == skill_before and upgrade == upgrade_before, "building and mutating output do not mutate inputs", [skill, upgrade])
	var rebuilt: Dictionary = BuilderScript.build_option_data(skill, upgrade, "epic")
	_expect(int((rebuilt.get("payload", {}) as Dictionary).get("level", 0)) == 1, "payload is newly owned on every call", rebuilt)
	_expect(((rebuilt.get("tags", []) as Array)[1] as Dictionary).get("nested", []) == [1], "nested tags are newly owned on every call", rebuilt)


func _verify_display_name_fallbacks() -> void:
	var skill: Dictionary = {"id": "skill_a", "display_name": "Skill A"}
	_expect(str(BuilderScript.build_option_data(skill, {"id": "upgrade_a"}, "rare").get("display_name", "")) == "Skill A", "absent upgrade display uses skill display")
	_expect(str(BuilderScript.build_option_data(skill, {"id": "upgrade_a", "display_name": null}, "rare").get("display_name", "")) == "skill_a", "null upgrade display falls directly to skill id")
	_expect(str(BuilderScript.build_option_data(skill, {"id": "upgrade_a", "display_name": ""}, "rare").get("display_name", "missing")) == "", "empty upgrade display remains empty")
	_expect(str(BuilderScript.build_option_data({"id": "skill_a"}, {"id": "upgrade_a"}, "rare").get("display_name", "")) == "skill_a", "missing display fields use skill id")


func _verify_description_fallbacks() -> void:
	var skill: Dictionary = {"id": "skill_a"}
	_expect(str(BuilderScript.build_option_data(skill, {"id": "upgrade_a", "level_descriptions": ["L1"], "description": "fallback"}, "common").get("description", "")) == "L1", "first level description wins")
	_expect(str(BuilderScript.build_option_data(skill, {"id": "upgrade_a", "level_descriptions": [], "description": "fallback"}, "common").get("description", "")) == "fallback", "empty level descriptions use description")
	_expect(str(BuilderScript.build_option_data(skill, {"id": "upgrade_a", "level_descriptions": [""], "description": "fallback"}, "common").get("description", "missing")) == "", "empty first level description remains empty")
	_expect(str(BuilderScript.build_option_data(skill, {"id": "upgrade_a", "level_descriptions": "invalid"}, "common").get("description", "missing")) == "", "malformed descriptions use empty fallback")


func _verify_texture_and_level_fallbacks() -> void:
	var upgrade: Dictionary = {"id": "upgrade_a", "max_level": 4, "background_texture": "res://upgrade.png"}
	var card_fallback: Dictionary = BuilderScript.build_option_data({"id": "skill_a", "card_background_texture": "res://card.png"}, upgrade, "legendary")
	_expect(str(card_fallback.get("background_texture", "")) == "res://card.png", "skill card texture is the secondary texture")
	_expect(str(card_fallback.get("level_text", "")) == "Lv1 / 4", "missing skill max level uses upgrade max level")
	_expect(str(card_fallback.get("rarity", "")) == "legendary", "rarity is not recalculated")
	var no_skill_texture: Dictionary = BuilderScript.build_option_data({"id": "skill_a", "max_level": 0}, upgrade, "")
	_expect(str(no_skill_texture.get("background_texture", "missing")) == "", "upgrade texture is not a fallback")
	_expect(str(no_skill_texture.get("level_text", "")) == "Lv1 / 1", "non-positive skill max level clamps to one")
	_expect(str(no_skill_texture.get("rarity", "missing")) == "", "empty rarity passes through without repair")


func _verify_invalid_and_malformed_inputs() -> void:
	_expect(BuilderScript.build_option_data({}, {"id": "upgrade_a"}, "common").is_empty(), "missing skill id is rejected")
	_expect(BuilderScript.build_option_data({"id": null}, {"id": "upgrade_a"}, "common").is_empty(), "null skill id is rejected")
	_expect(BuilderScript.build_option_data({"id": "skill_a"}, {}, "common").is_empty(), "missing upgrade id is rejected")
	_expect(BuilderScript.build_option_data({"id": "skill_a"}, {"id": ""}, "common").is_empty(), "empty upgrade id is rejected")
	var malformed: Dictionary = BuilderScript.build_option_data({"id": "skill_a"}, {"id": "upgrade_a", "tags": "invalid"}, "common")
	_expect((malformed.get("tags", []) as Array).is_empty(), "malformed tags become an empty array", malformed)


func _expect(condition: bool, label: String, actual: Variant = "") -> void:
	if condition:
		return
	_failed = true
	push_error("[verify_skill_learn_option_builder] FAIL %s actual=%s" % [label, str(actual)])
```

- [ ] **Step 3: Add the package command and run the verifier to observe RED**

Add this entry to `package.json` scripts:

```json
"verify:skill-learn-option-builder": "D:\\Godot\\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_skill_learn_option_builder.gd"
```

Run:

```powershell
npm run verify:skill-learn-option-builder
```

Expected: non-zero exit caused by the missing `scripts/upgrades/skill_learn_option_builder.gd`, not by an unrelated engine or environment failure.

- [ ] **Step 4: Implement the minimal pure Builder**

Create `scripts/upgrades/skill_learn_option_builder.gd`:

```gdscript
extends RefCounted
class_name SkillLearnOptionBuilder


static func build_option_data(skill: Dictionary, upgrade: Dictionary, rarity: String) -> Dictionary:
	var skill_id: StringName = StringName(_string_or(skill.get("id", ""), ""))
	var upgrade_id: StringName = StringName(_string_or(upgrade.get("id", ""), ""))
	if skill_id == &"" or upgrade_id == &"":
		return {}
	var max_level: int = maxi(int(skill.get("max_level", upgrade.get("max_level", 1))), 1)
	return {
		"id": "level_up_upgrade:%s:%s" % [_string_or(upgrade_id, ""), rarity],
		"type": "level_up_upgrade",
		"display_name": _string_or(upgrade.get("display_name", skill.get("display_name", skill_id)), _string_or(skill_id, "")),
		"description": _get_description(upgrade),
		"rarity": rarity,
		"background_texture": _get_background_texture(skill),
		"tags": _get_array(upgrade.get("tags", [])).duplicate(true),
		"affected_origin": "神系技能",
		"does_not_affect": "不替换角色初始技能。",
		"recommended_reason": "从神系技能池学习一个新技能。",
		"level_text": "Lv1 / %d" % max_level,
		"payload": {
			"upgrade_id": upgrade_id,
			"learn_skill_id": skill_id,
			"level": 1,
			"target_rarity": rarity,
		},
	}


static func _get_description(upgrade: Dictionary) -> String:
	var descriptions: Array = _get_array(upgrade.get("level_descriptions", []))
	if not descriptions.is_empty():
		return _string_or(descriptions[0], "")
	return _string_or(upgrade.get("description", ""), "")


static func _get_background_texture(skill: Dictionary) -> String:
	for key: String in ["background_texture", "card_background_texture"]:
		var value: String = _string_or(skill.get(key, ""), "")
		if value != "":
			return value
	return ""


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _string_or(value: Variant, default_value: String = "") -> String:
	return default_value if value == null else str(value)
```

- [ ] **Step 5: Run the direct test and parse checks to verify GREEN**

Run sequentially:

```powershell
npm run verify:skill-learn-option-builder
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/upgrades/skill_learn_option_builder.gd
node tools/validate/check_text_encoding.js
git diff --check
```

Expected: the verifier prints `[verify_skill_learn_option_builder] PASS`; Builder parse, encoding, and diff checks exit `0`.

- [ ] **Step 6: Review and commit Task 1 only after implementation authorization**

Confirm the diff contains no autoload, service, RNG, node, logging, `UpgradeOption`, or unrelated edits. Then, only if the user authorized implementation commits:

```powershell
git add package.json scripts/upgrades/skill_learn_option_builder.gd tools/verify/verify_skill_learn_option_builder.gd
git commit -m "test: define skill learn option builder contract"
```

### Task 2: Delegate UpgradePool Construction Without Moving Runtime Decisions

**Files:**
- Create: `tools/verify/verify_skill_learn_option_builder_boundary.js`
- Modify: `scripts/upgrades/upgrade_pool.gd:1-13,175-217`
- Modify: `tools/verify/verify_fire_skill_upgrade_pool.js`
- Modify: `package.json`

**Interfaces:**
- Consumes: `SkillLearnOptionBuilder.build_option_data(skill: Dictionary, upgrade: Dictionary, rarity: String) -> Dictionary` from Task 1.
- Produces: unchanged `_build_god_skill_learn_options(player: Node) -> Array` with pure data construction delegated and `_make_option(option_data)` retained.

- [ ] **Step 1: Write the failing structural boundary contract**

Create `tools/verify/verify_skill_learn_option_builder_boundary.js`:

```javascript
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const pool = readTextFile(path.join(root, "scripts", "upgrades", "upgrade_pool.gd"));
const builder = readTextFile(path.join(root, "scripts", "upgrades", "skill_learn_option_builder.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name, prefix = "func ") {
  const start = source.indexOf(`${prefix}${name}(`);
  if (start < 0) return "";
  const next = source.indexOf(`\n${prefix}`, start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

const body = functionBody(pool, "_build_god_skill_learn_options");
const builderBody = functionBody(builder, "build_option_data", "static func ");

assert(builderBody, "SkillLearnOptionBuilder.build_option_data must exist.");
assert(
  pool.includes('const SkillLearnOptionBuilderScript: Script = preload("res://scripts/upgrades/skill_learn_option_builder.gd")'),
  "UpgradePool must preload SkillLearnOptionBuilder.",
);
assert(body, "UpgradePool must keep _build_god_skill_learn_options.");
for (const marker of [
  "_is_learn_skill_upgrade_available(player, skill_id)",
  '_skill_offer_service.call("is_skill_available", player, skill)',
  "_make_god_skill_learn_upgrade(skill, _get_skill_god_id(skill))",
  "SkillGrowthScalingScript.pick_rarity_for_max_level(max_level, _rng)",
]) {
  assert(body.includes(marker), `_build_god_skill_learn_options must retain runtime decision: ${marker}`);
}
assert(body.includes("SkillLearnOptionBuilderScript.build_option_data(skill, upgrade, rarity)"), "UpgradePool must delegate learn-card data construction.");
assert(body.includes("option_data.is_empty()"), "UpgradePool must skip an invalid empty Builder result.");
assert(body.includes("_make_option(option_data)"), "UpgradePool must retain final UpgradeOption construction.");

const eligibilityIndex = body.indexOf("_is_learn_skill_upgrade_available(player, skill_id)");
const serviceIndex = body.indexOf('_skill_offer_service.call("is_skill_available", player, skill)');
const rarityIndex = body.indexOf("SkillGrowthScalingScript.pick_rarity_for_max_level(max_level, _rng)");
const builderIndex = body.indexOf("SkillLearnOptionBuilderScript.build_option_data(skill, upgrade, rarity)");
assert(eligibilityIndex < serviceIndex && serviceIndex < rarityIndex && rarityIndex < builderIndex, "Eligibility and rarity selection must remain ordered before Builder delegation.");

for (const movedMarker of ['"affected_origin": "神系技能"', '"learn_skill_id": skill_id', '"level_text": "Lv1 / %d"']) {
  assert(!body.includes(movedMarker), `UpgradePool must not retain moved data marker: ${movedMarker}`);
  assert(builderBody.includes(movedMarker), `Builder must own moved data marker: ${movedMarker}`);
}

for (const retainedMethod of [
  "_build_fire_skill_learn_options",
  "_fill_from_weighted_pool",
  "_enforce_guaranteed_options",
  "_enforce_god_skill_learn_option",
  "_enforce_ordinary_active_learn_option",
  "_make_debug_god_skill_option",
  "_make_option",
]) {
  assert(functionBody(pool, retainedMethod), `UpgradePool must retain ${retainedMethod}.`);
}

for (const forbiddenDependency of ["GameData", "SkillOfferService", "UpgradeOfferPolicy", "SkillGrowthScaling", "UpgradeSelectionHelper", "UpgradeOption", "get_tree(", "print(", "push_error("]) {
  assert(!builder.includes(forbiddenDependency), `Builder must not depend on ${forbiddenDependency}.`);
}

console.log("[verify_skill_learn_option_builder_boundary] PASS");
```

- [ ] **Step 2: Add the boundary command and observe RED**

Add this entry to `package.json` scripts:

```json
"verify:skill-learn-option-builder-boundary": "node tools\\verify\\verify_skill_learn_option_builder_boundary.js"
```

Run:

```powershell
node --check tools/verify/verify_skill_learn_option_builder_boundary.js
npm run verify:skill-learn-option-builder-boundary
```

Expected: syntax check passes; the contract fails because `UpgradePool` has not yet preloaded or delegated to the Builder.

- [ ] **Step 3: Replace only the inline option dictionary with delegation**

Add alongside the existing upgrade preloads:

```gdscript
const SkillLearnOptionBuilderScript: Script = preload("res://scripts/upgrades/skill_learn_option_builder.gd")
```

In `_build_god_skill_learn_options()`, leave all code through rarity selection unchanged and replace only `options.append(_make_option({...}))` with:

```gdscript
		var option_data: Dictionary = SkillLearnOptionBuilderScript.build_option_data(skill, upgrade, rarity)
		if option_data.is_empty():
			continue
		options.append(_make_option(option_data))
```

Do not move or rewrite the eligibility checks, synthetic upgrade call, upgrade-ID guard, maximum-level calculation, rarity call, loop order, return, or neighboring methods.

- [ ] **Step 4: Update the existing fire upgrade-pool contract without weakening it**

In `tools/verify/verify_fire_skill_upgrade_pool.js`, read the Builder:

```javascript
const skillLearnOptionBuilder = read("scripts/upgrades/skill_learn_option_builder.gd");
```

Replace only these old inline-construction assertions:

```javascript
assert(formalBuilderBody.includes('"id": "level_up_upgrade:%s:%s"'), "learn cards must use level_up_upgrade option ids with rarity suffix");
assert(formalBuilderBody.includes('"learn_skill_id"'), "learn card payload must carry learn_skill_id");
```

with delegation-aware assertions:

```javascript
assert(formalBuilderBody.includes("SkillLearnOptionBuilderScript.build_option_data"), "learn options must delegate card data to SkillLearnOptionBuilder");
assert(skillLearnOptionBuilder.includes('"id": "level_up_upgrade:%s:%s"'), "learn cards must use level_up_upgrade option ids with rarity suffix");
assert(skillLearnOptionBuilder.includes('"learn_skill_id"'), "learn card payload must carry learn_skill_id");
```

Keep every other existing assertion unchanged, including unified pool access, `offer_rule`, `is_skill_available`, old-skill exclusion, fire compatibility, and `SkillOfferService` rule tokens.

- [ ] **Step 5: Run the focused boundary and behavior checks to verify GREEN**

Run in this order:

```powershell
npm run verify:skill-learn-option-builder-boundary
npm run verify:skill-learn-option-builder
npm run verify:fire-skill-upgrade-pool
npm run verify:skill-growth-upgrade-pool
npm run verify:upgrade-pool-no-relic-fireball-god-mix
npm run verify:god-school-learning-rules
npm run verify:skill-card-scaled-values-and-rarity
npm run verify:upgrade-pool-missing-rarity
```

Run Godot-backed commands sequentially. Expected: `8/8 PASS`; no new warnings or engine errors.

- [ ] **Step 6: Parse the changed production facade and inspect its diff**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/upgrades/upgrade_pool.gd
git diff --check
git diff -- scripts/upgrades/upgrade_pool.gd tools/verify/verify_fire_skill_upgrade_pool.js
```

Expected: parse and diff checks pass; the pool diff contains one preload, one Builder call, one empty-result guard, and `_make_option(option_data)`, with no other orchestration changes.

- [ ] **Step 7: Review and commit Task 2 only after implementation authorization**

Confirm randomness and ownership boundaries using the structural contract. Then, only if the user authorized implementation commits:

```powershell
git add package.json scripts/upgrades/upgrade_pool.gd tools/verify/verify_fire_skill_upgrade_pool.js tools/verify/verify_skill_learn_option_builder_boundary.js
git commit -m "refactor: extract skill learn option data"
```

### Task 3: Run Full Regression and Record the Boundary

**Files:**
- Modify: `docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md`
- Verify: all Stage 4 production and verification files from Tasks 1-2.

**Interfaces:**
- Consumes: the pure Builder interface and unchanged `UpgradePool` facade from Tasks 1-2.
- Produces: complete evidence that Stage 4 preserves the established baselines and a report that records the new boundary without claiming performance improvement.

- [ ] **Step 1: Update the stability report with measured scope only**

In the upgrade-system row and safe-change/roadmap sections, record these facts:

```markdown
- Stage 4 moved deterministic learn-skill option-data construction into `SkillLearnOptionBuilder`.
- `UpgradePool` still owns definitions, eligibility, RNG/rarity, `UpgradeOption` construction, weighting, de-duplication, and guarantees.
- Weight-policy extraction and broader upgrade-card consolidation remain deferred and require separate design and verification.
- This was an architecture batch; performance comparison is not applicable and no performance improvement is claimed.
```

Do not rewrite unrelated roadmap items or change the risk rating without new evidence.

- [ ] **Step 2: Run Stage 4 and Stage 3 focused verification**

Run:

```powershell
node --check tools/verify/verify_skill_learn_option_builder_boundary.js
node tools/validate/check_text_encoding.js
npm run verify:skill-learn-option-builder-boundary
npm run verify:skill-learn-option-builder
npm run verify:skill-action-builder-boundary
npm run verify:skill-action-builder-pure-data
```

Expected: Node syntax and encoding exit `0`; all four focused verifiers print `PASS`.

- [ ] **Step 3: Run the complete focused UpgradePool regression**

Run Godot-backed commands sequentially:

```powershell
npm run verify:skill-growth-upgrade-pool
npm run verify:upgrade-pool-no-relic-fireball-god-mix
npm run verify:god-school-learning-rules
npm run verify:skill-card-scaled-values-and-rarity
npm run verify:fire-skill-upgrade-pool
npm run verify:upgrade-pool-missing-rarity
```

Then run the active-skill guarantee script directly because it has no package entry:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_upgrade_pool_active_skill_guarantee.gd
```

Expected: `7/7 PASS` with no new warnings or engine errors.

- [ ] **Step 4: Run the Stage 1 static baseline**

Run these nine read-only Node validators; they may run in parallel:

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

- [ ] **Step 5: Run the complete 11-test Godot baseline sequentially**

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

- [ ] **Step 6: Run final parse, startup, encoding, and scope checks**

Run sequentially:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/upgrades/skill_learn_option_builder.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/upgrades/upgrade_pool.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --quit
node tools/validate/check_text_encoding.js
git diff --check
git status --short
git diff --stat origin/codex/stage3-skill-action-builders
git diff --name-only origin/codex/stage3-skill-action-builders
```

Expected:

- both production scripts parse;
- project startup exits `0` without new errors;
- all text files remain valid UTF-8;
- `git diff --check` prints nothing;
- changed files are limited to the Stage 4 spec, plan, Builder, pool delegate, two focused verifiers, the deliberate fire-contract update, package scripts, and stability report;
- the two user-owned `.uid` files remain untracked and unchanged.

- [ ] **Step 7: Perform the final whole-branch review**

Review the branch against the specification and these failure classes:

1. candidate order, eligibility, maximum-level, or RNG calls moved or changed;
2. fallback behavior differs for missing, null, or empty display/description fields;
3. source dictionaries or nested tags can be mutated through returned data;
4. weighting, guarantees, debug cards, final option construction, or facade methods moved or removed;
5. unrelated gameplay, configuration, resources, UI, formatting, or user-owned files entered the diff.

Critical or Important findings require one TDD fix pass followed by the complete suite. Minor findings are recorded and deferred rather than expanding this batch.

- [ ] **Step 8: Commit final documentation only after implementation authorization**

If Tasks 1-2 already have authorized commits, commit only the final report and plan:

```powershell
git add docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md docs/superpowers/plans/2026-09-19-skill-learn-option-builder-extraction.md
git commit -m "docs: record stage 4 skill learn builder boundary"
```

If the user instead authorizes one consolidated implementation commit, stage only the approved Stage 4 files explicitly:

```powershell
git add docs/PROJECT_STABILITY_AND_BOUNDARY_REPORT.md docs/superpowers/plans/2026-09-19-skill-learn-option-builder-extraction.md package.json scripts/upgrades/skill_learn_option_builder.gd scripts/upgrades/upgrade_pool.gd tools/verify/verify_skill_learn_option_builder.gd tools/verify/verify_skill_learn_option_builder_boundary.js tools/verify/verify_fire_skill_upgrade_pool.js
git commit -m "refactor: extract skill learn option data"
```

Do not stage either untracked `.uid` file. Do not push or create a PR without separate user authorization.

## Rollback

- Revert the Stage 4 implementation commit or ordered Task 1-2 commits.
- Restore the inline dictionary in `_build_god_skill_learn_options()` and remove the Builder preload, focused tests, and package commands.
- Keep the facade names, loop, and `_make_option()` path unchanged, so no call-site migration or data conversion is required.
- Re-run the six pre-change focused checks, Stage 1 static baseline, and 11 sequential Godot baseline tests after rollback.

## Performance Success Metric

Not applicable. This batch changes responsibility ownership only. It must not claim reduced allocations, faster frame time, or any other performance gain without a separate controlled benchmark.
