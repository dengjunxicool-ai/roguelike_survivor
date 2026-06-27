# Fire Skill System First Version Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the obsolete fire god skill cards with the first version of the new data-driven fire skill system: 14 fire base skills plus 20 bidirectional fire-related fusion skills.

**Architecture:** Keep the existing Godot runtime spine (`SkillManager`, `SkillEventBus`, `SkillActionExecutor`, `StatusEffectManager`, `UpgradePool`) and add a small compatibility layer for the new SkillDefinition schema. Author new skills with `school`, `type`, `offer_rule`, `trigger_rules`, and `effects`, then adapt those rules into the existing event/action execution flow.

**Tech Stack:** Godot 4 GDScript, JSON data in `data/`, Node.js verification scripts in `tools/`, Godot headless smoke scripts in `tools/`.

---

## File Structure

- Modify `data/skills.json`: remove old fire cards and author exactly 34 new fire-scope skill definitions.
- Modify `data/status_effects.json`: add the core new status IDs while preserving unrelated existing statuses required by other systems.
- Modify `scripts/skills/skill_definition.gd`: parse new schema fields.
- Modify `scripts/skills/skill_instance.gd`: expose school/type/fusion metadata for offer and trigger logic.
- Create `scripts/skills/skill_effect_adapter.gd`: convert new `effects` entries into current action dictionaries.
- Create `scripts/skills/skill_trigger_rule_adapter.gd`: convert new `trigger_rules` into current event dictionaries and handle counters/cooldowns.
- Create `scripts/skills/skill_offer_service.gd`: evaluate new `offer_rule` and exclusivity rules.
- Modify `scripts/skills/skill_event_bus.gd`: include adapted trigger rules when executing skill events.
- Modify `scripts/skills/skill_action_executor.gd`: add missing generic action aliases and actions needed by fire/fusion skills.
- Modify `scripts/combat/status_effect_manager.gd`: support new status aliases, max-stack events, expiration events, and status duration consumption.
- Modify `scripts/upgrades/upgrade_pool.gd`: call `SkillOfferService` for skill learn cards.
- Modify or delete obsolete old-fire-card verification scripts that assert the old 60-card fire contract.
- Create `tools/verify_fire_skill_system_contract.js`: static schema, count, and runtime-support contract.
- Create `tools/verify_fire_skill_offer_rules.js`: static offer-rule and exclusivity checks.
- Create `tools/verify_fire_skill_runtime_smoke.gd`: Godot smoke for learning and triggering representative skills.
- Modify `package.json`: add verification commands for the new fire skill system.

## Canonical Skill IDs

Use these exact IDs in `data/skills.json`.

Fire base skills:

- `fire_attack_searing`
- `fire_dash_blazing_run`
- `fire_cast_meteor_rain`
- `fire_cast_lava_rift`
- `fire_cast_scorching_vortex`
- `fire_summon_crimson_dragon`
- `fire_summon_ember_fox_pack`
- `fire_passive_burning_focus`
- `fire_passive_overheated_casting`
- `fire_passive_scorched_ground_affinity`
- `fire_power_combustion_chain`
- `fire_power_ember_attachment`
- `fire_power_ignite_core`
- `fire_core_inferno_cycle`

Fire-related fusion skills:

- `fusion_fire_frost_steam_mist`
- `fusion_fire_frost_shattered_ember`
- `fusion_fire_thunder_plasma_fire_path`
- `fusion_fire_thunder_thunderburn_meteor`
- `fusion_fire_curse_ash_curse_rune`
- `fusion_fire_curse_blackflame_serpents`
- `fusion_fire_holy_holy_flame_absolution`
- `fusion_fire_holy_burning_light_barrier`
- `fusion_fire_chaos_ember_echo`
- `fusion_fire_chaos_molten_split`
- `fusion_frost_fire_crystalized_flame`
- `fusion_frost_fire_frostburn_shards`
- `fusion_thunder_fire_arc_ignition`
- `fusion_thunder_fire_thunderfire_circuit`
- `fusion_curse_fire_ash_soul_pact`
- `fusion_curse_fire_burning_soul_minion`
- `fusion_holy_fire_holy_flame_purification`
- `fusion_holy_fire_solar_hammer`
- `fusion_chaos_fire_riftfire_fork`
- `fusion_chaos_fire_lava_refraction`

## Task 1: Static Contract Tests

**Files:**
- Create: `tools/verify_fire_skill_system_contract.js`
- Modify: `package.json`

- [ ] **Step 1: Write the failing static contract test**

Create `tools/verify_fire_skill_system_contract.js` with this structure:

```javascript
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, ""));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const FIRE_BASE_IDS = [
  "fire_attack_searing",
  "fire_dash_blazing_run",
  "fire_cast_meteor_rain",
  "fire_cast_lava_rift",
  "fire_cast_scorching_vortex",
  "fire_summon_crimson_dragon",
  "fire_summon_ember_fox_pack",
  "fire_passive_burning_focus",
  "fire_passive_overheated_casting",
  "fire_passive_scorched_ground_affinity",
  "fire_power_combustion_chain",
  "fire_power_ember_attachment",
  "fire_power_ignite_core",
  "fire_core_inferno_cycle",
];

const FIRE_FUSION_IDS = [
  "fusion_fire_frost_steam_mist",
  "fusion_fire_frost_shattered_ember",
  "fusion_fire_thunder_plasma_fire_path",
  "fusion_fire_thunder_thunderburn_meteor",
  "fusion_fire_curse_ash_curse_rune",
  "fusion_fire_curse_blackflame_serpents",
  "fusion_fire_holy_holy_flame_absolution",
  "fusion_fire_holy_burning_light_barrier",
  "fusion_fire_chaos_ember_echo",
  "fusion_fire_chaos_molten_split",
  "fusion_frost_fire_crystalized_flame",
  "fusion_frost_fire_frostburn_shards",
  "fusion_thunder_fire_arc_ignition",
  "fusion_thunder_fire_thunderfire_circuit",
  "fusion_curse_fire_ash_soul_pact",
  "fusion_curse_fire_burning_soul_minion",
  "fusion_holy_fire_holy_flame_purification",
  "fusion_holy_fire_solar_hammer",
  "fusion_chaos_fire_riftfire_fork",
  "fusion_chaos_fire_lava_refraction",
];

const REQUIRED_SKILL_FIELDS = [
  "id",
  "name",
  "school",
  "fusion_school",
  "type",
  "rarity",
  "max_level",
  "exclusive_group",
  "tags",
  "mechanic_family",
  "offer_rule",
  "trigger_rules",
  "effects",
];

const ALLOWED_TYPES = new Set(["attack", "dash", "cast", "summon", "passive", "power", "core", "fusion"]);
const ALLOWED_SCHOOLS = new Set(["fire", "frost", "thunder", "curse", "holy", "chaos"]);
const ALLOWED_RARITIES = new Set(["normal", "rare", "epic", "legendary"]);
const SUPPORTED_TRIGGERS = new Set([
  "attack_hit",
  "dash_start",
  "dash_end",
  "cast_skill",
  "projectile_hit",
  "area_tick",
  "enemy_death",
  "status_applied",
  "status_tick",
  "status_expired",
  "status_max_stack_reached",
  "shield_gained",
  "shield_broken",
  "summon_attack_hit",
  "always",
]);
const SUPPORTED_EFFECTS = new Set([
  "damage",
  "apply_status",
  "spawn_area",
  "spawn_projectile",
  "spawn_summon",
  "add_modifier",
  "grant_shield",
  "heal",
  "pull",
  "knockback",
  "repeat_skill",
  "transform_area",
  "transfer_status",
  "consume_status_duration",
  "trigger_overload",
  "shatter_frozen",
  "spawn_projectile_burst",
  "repeat_area_path",
  "spawn_area_from_existing_area",
]);
const OBSOLETE_FIRE_IDS = new Set(["mars_spark_missile", "fire_tornado", "soulburn"]);

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function validateSkill(skill, expectedIds) {
  for (const field of REQUIRED_SKILL_FIELDS) {
    assert(Object.prototype.hasOwnProperty.call(skill, field), `${skill.id || "missing id"} missing field ${field}`);
  }
  assert(expectedIds.has(skill.id), `unexpected first-version fire skill id: ${skill.id}`);
  assert(!OBSOLETE_FIRE_IDS.has(skill.id), `obsolete fire card id still present: ${skill.id}`);
  assert(ALLOWED_SCHOOLS.has(skill.school), `${skill.id} invalid school`);
  if (skill.fusion_school !== null) {
    assert(ALLOWED_SCHOOLS.has(skill.fusion_school), `${skill.id} invalid fusion_school`);
  }
  assert(ALLOWED_TYPES.has(skill.type), `${skill.id} invalid type`);
  assert(ALLOWED_RARITIES.has(skill.rarity), `${skill.id} invalid rarity`);
  assert(Number.isInteger(skill.max_level) && skill.max_level >= 1, `${skill.id} invalid max_level`);
  assert(Array.isArray(skill.tags) && skill.tags.length > 0, `${skill.id} must have non-empty tags`);
  assert(typeof skill.offer_rule === "object" && skill.offer_rule !== null && !Array.isArray(skill.offer_rule), `${skill.id} invalid offer_rule`);

  for (const rule of asArray(skill.trigger_rules)) {
    assert(SUPPORTED_TRIGGERS.has(rule.trigger), `${skill.id} unsupported trigger ${rule.trigger}`);
    for (const effect of asArray(rule.effects)) {
      assert(SUPPORTED_EFFECTS.has(effect.type), `${skill.id} unsupported trigger effect ${effect.type}`);
    }
  }
  for (const effect of asArray(skill.effects)) {
    assert(SUPPORTED_EFFECTS.has(effect.type), `${skill.id} unsupported effect ${effect.type}`);
  }

  assert(asArray(skill.trigger_rules).length > 0 || asArray(skill.effects).length > 0, `${skill.id} has no runtime payload`);
}

function main() {
  const document = readJson("data/skills.json");
  const skills = asArray(document.skills);
  const expectedIds = new Set([...FIRE_BASE_IDS, ...FIRE_FUSION_IDS]);
  const actualIds = new Set(skills.map((skill) => skill.id));

  assert(skills.length === 34, `data/skills.json must contain exactly 34 first-version skills, got ${skills.length}`);
  for (const id of expectedIds) {
    assert(actualIds.has(id), `missing skill ${id}`);
  }
  for (const skill of skills) {
    validateSkill(skill, expectedIds);
    if (skill.type === "fusion") {
      assert(skill.fusion_school !== null, `${skill.id} fusion skill must set fusion_school`);
      assert(skill.offer_rule.required_min_skill_count, `${skill.id} must set offer_rule.required_min_skill_count`);
    }
  }

  console.log("[verify_fire_skill_system_contract] PASS");
}

main();
```

- [ ] **Step 2: Add the package script**

In `package.json`, add:

```json
"verify:fire-skill-system-contract": "node tools\\verify_fire_skill_system_contract.js"
```

Keep the existing `verify:obsolete-runtime-removed` script.

- [ ] **Step 3: Run the static contract and verify it fails**

Run: `npm run verify:fire-skill-system-contract`

Expected: FAIL because `data/skills.json` still contains the obsolete fire card set and does not have the new 34-skill contract.

- [ ] **Step 4: Commit the failing contract**

```bash
git add package.json tools/verify_fire_skill_system_contract.js
git commit -m "test: add fire skill system contract"
```

## Task 2: New Skill Data

**Files:**
- Modify: `data/skills.json`
- Test: `tools/verify_fire_skill_system_contract.js`

- [ ] **Step 1: Replace old fire skill cards with the 34 canonical definitions**

Replace `data/skills.json` with a root object containing a single `skills` array. Do not keep old `starting_skills` fireball data in this file for the new skill-system first version unless another current system still requires it during implementation; if it must remain temporarily, update the contract to count only `skills` and document the compatibility section in the same commit.

Every base skill must include:

```json
{
  "id": "fire_attack_searing",
  "name": "灼热攻击",
  "school": "fire",
  "fusion_school": null,
  "type": "attack",
  "rarity": "normal",
  "max_level": 5,
  "exclusive_group": "attack_school",
  "tags": ["attack", "fire", "status_burning", "ground_path"],
  "mechanic_family": "attack_status_ground_path",
  "offer_rule": {
    "required_schools": ["fire"],
    "required_skills": [],
    "blocked_by_exclusive_group": ["attack_school"]
  },
  "trigger_rules": [
    {
      "trigger": "attack_hit",
      "counter_key": "fire_attack_searing_hits",
      "threshold": 4,
      "effects": [
        {
          "type": "spawn_area",
          "area_id": "fire_path",
          "radius": 0.8,
          "duration": 2.5,
          "tick_interval": 0.5,
          "effects_on_tick": [
            { "type": "damage", "damage_type": "fire", "source_type": "area", "power_scale": 0.12 },
            { "type": "apply_status", "status": "burning", "stacks": 1 }
          ]
        }
      ]
    }
  ],
  "effects": [
    { "type": "add_modifier", "stat": "attack_damage_multiplier_add", "value": 0.2 }
  ]
}
```

Use the numeric values from the accepted design document for the remaining 33 skills. Author all direct damage as `power_scale`, not fixed damage numbers. Use `rarity: "normal"` for the first data pass unless the design document gives a stronger rarity value; the rarity multiplier system will still support all four rarity names.

- [ ] **Step 2: Run the contract**

Run: `npm run verify:fire-skill-system-contract`

Expected: PASS once the 34 new definitions exist and obsolete old fire IDs are absent.

- [ ] **Step 3: Commit the data replacement**

```bash
git add data/skills.json
git commit -m "data: replace fire cards with first-version skill definitions"
```

## Task 3: Core Status Data and Status Contract

**Files:**
- Modify: `data/status_effects.json`
- Create: `tools/verify_fire_status_contract.js`
- Modify: `package.json`

- [ ] **Step 1: Write the failing status contract**

Create `tools/verify_fire_status_contract.js`:

```javascript
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, ""));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function approx(actual, expected, message) {
  assert(Math.abs(Number(actual) - expected) <= 0.0001, `${message}: expected ${expected}, got ${actual}`);
}

const statuses = readJson("data/status_effects.json").statuses || [];
const byId = new Map(statuses.map((status) => [status.id, status]));
const requiredIds = ["burning", "chilled", "frozen", "conductive", "overload", "cursed", "judgment", "instability"];

for (const id of requiredIds) {
  assert(byId.has(id), `missing status ${id}`);
}

const burning = byId.get("burning");
approx(burning.duration, 4.0, "burning duration");
approx(burning.tick_interval, 0.5, "burning tick interval");
assert(burning.max_stacks === 5, "burning max_stacks");
assert(Array.isArray(burning.on_tick_effects), "burning must use on_tick_effects");
assert(burning.on_tick_effects.some((effect) => effect.type === "damage" && effect.power_scale === 0.18), "burning must tick 0.18P damage");

const chilled = byId.get("chilled");
assert(chilled.max_stacks === 7, "chilled max_stacks");
assert(chilled.convert_to_status === "frozen" || chilled.max_stack_status === "frozen", "chilled must convert to frozen at max stack");

const overload = byId.get("overload");
assert(overload.type === "instant", "overload must be instant");

console.log("[verify_fire_status_contract] PASS");
```

- [ ] **Step 2: Add the package script**

Add:

```json
"verify:fire-status-contract": "node tools\\verify_fire_status_contract.js"
```

- [ ] **Step 3: Run and verify failure**

Run: `npm run verify:fire-status-contract`

Expected: FAIL because `burning`, `chilled`, `conductive`, `cursed`, and `instability` are not yet authored in the new schema.

- [ ] **Step 4: Add the eight core statuses**

Append or merge these status definitions into `data/status_effects.json.statuses`, preserving unrelated statuses:

```json
{
  "id": "burning",
  "display_name": "Burning",
  "type": "dot",
  "duration": 4.0,
  "max_stacks": 5,
  "tick_interval": 0.5,
  "refresh_rule": "refresh_duration",
  "on_tick_effects": [
    { "type": "damage", "damage_type": "fire", "source_type": "status", "power_scale": 0.18 }
  ],
  "damage_type": "status_dot",
  "element": "fire",
  "can_crit": false
}
```

Also add:

- `chilled`: duration 6.0, max 7, `effect.move_slow_per_stack: 0.06`, `max_stack_status: "frozen"`.
- `frozen`: type `hard_control`, max 1, duration 1.2, elite duration 0.5, boss duration 0.15, movement lock effect.
- `conductive`: duration 5.0, max 5, lightning damage taken +0.06 per stack, `max_stack_status: "overload"`.
- `overload`: type `instant`, max 1.
- `cursed`: duration 3.0, max 3, expiration effects with `0.75P * stacks` curse damage.
- `judgment`: duration 6.0, max 5, `max_stack_event: "divine_punishment"`.
- `instability`: duration 6.0, max 4, `max_stack_event: "fission"`.

- [ ] **Step 5: Run the status contract**

Run: `npm run verify:fire-status-contract`

Expected: PASS.

- [ ] **Step 6: Commit status data and test**

```bash
git add data/status_effects.json package.json tools/verify_fire_status_contract.js
git commit -m "data: add core fire skill statuses"
```

## Task 4: Parse New Skill Schema

**Files:**
- Modify: `scripts/skills/skill_definition.gd`
- Modify: `scripts/skills/skill_instance.gd`
- Create: `tools/verify_skill_definition_schema.js`
- Modify: `package.json`

- [ ] **Step 1: Write the schema parser static check**

Create `tools/verify_skill_definition_schema.js`:

```javascript
const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const definition = read("scripts/skills/skill_definition.gd");
const instance = read("scripts/skills/skill_instance.gd");

for (const field of ["school", "fusion_school", "skill_type", "rarity", "exclusive_group", "mechanic_family", "offer_rule", "trigger_rules", "effects"]) {
  assert(definition.includes(`var ${field}`), `SkillDefinition must expose ${field}`);
}
assert(definition.includes('data.get("name"'), "SkillDefinition must read name");
assert(definition.includes('data.get("school"'), "SkillDefinition must read school");
assert(definition.includes('data.get("trigger_rules"'), "SkillDefinition must read trigger_rules");
assert(definition.includes('data.get("effects"'), "SkillDefinition must read effects");

for (const field of ["school", "fusion_school", "skill_type", "exclusive_group"]) {
  assert(instance.includes(`var ${field}`), `SkillInstance must expose ${field}`);
}

console.log("[verify_skill_definition_schema] PASS");
```

- [ ] **Step 2: Add package script and run failure**

Add:

```json
"verify:skill-definition-schema": "node tools\\verify_skill_definition_schema.js"
```

Run: `npm run verify:skill-definition-schema`

Expected: FAIL because new fields are not yet parsed.

- [ ] **Step 3: Extend `SkillDefinition`**

Add these properties to `scripts/skills/skill_definition.gd`:

```gdscript
var name: String = ""
var school: StringName = &""
var fusion_school: Variant = null
var skill_type: String = ""
var rarity: String = "normal"
var exclusive_group: String = ""
var mechanic_family: String = ""
var offer_rule: Dictionary = {}
var trigger_rules: Array[Dictionary] = []
var effects: Array[Dictionary] = []
```

In `_init(data)`, assign:

```gdscript
name = String(data.get("name", data.get("display_name", "")))
display_name = String(data.get("display_name", name))
school = StringName(String(data.get("school", data.get("god_id", ""))))
var fusion_value: Variant = data.get("fusion_school", null)
fusion_school = null if fusion_value == null else StringName(String(fusion_value))
skill_type = String(data.get("type", _category_to_skill_type(String(data.get("category", "")))))
rarity = String(data.get("rarity", "normal"))
exclusive_group = String(data.get("exclusive_group", ""))
mechanic_family = String(data.get("mechanic_family", ""))
offer_rule = _parse_dictionary(data.get("offer_rule", {}))
trigger_rules = _parse_dictionary_array(data.get("trigger_rules", []))
effects = _parse_dictionary_array(data.get("effects", []))
```

Add:

```gdscript
func _category_to_skill_type(value: String) -> String:
	match value:
		"active":
			return "cast"
		"passive":
			return "passive"
		_:
			return value
```

- [ ] **Step 4: Extend `SkillInstance`**

Add:

```gdscript
var school: StringName = &""
var fusion_school: Variant = null
var skill_type: String = ""
var exclusive_group: String = ""
```

In `_init(skill_definition)`, after `skill_id = definition.id`, assign:

```gdscript
school = StringName(String(definition.get("school")))
fusion_school = definition.get("fusion_school")
skill_type = String(definition.get("skill_type"))
exclusive_group = String(definition.get("exclusive_group"))
```

- [ ] **Step 5: Run schema and data contracts**

Run:

```bash
npm run verify:skill-definition-schema
npm run verify:fire-skill-system-contract
```

Expected: both PASS.

- [ ] **Step 6: Commit schema parsing**

```bash
git add package.json scripts/skills/skill_definition.gd scripts/skills/skill_instance.gd tools/verify_skill_definition_schema.js
git commit -m "feat: parse new skill definition schema"
```

## Task 5: Effect and Trigger Adapters

**Files:**
- Create: `scripts/skills/skill_effect_adapter.gd`
- Create: `scripts/skills/skill_trigger_rule_adapter.gd`
- Modify: `scripts/skills/skill_event_bus.gd`
- Create: `tools/verify_skill_rule_adapters.js`
- Modify: `package.json`

- [ ] **Step 1: Write static adapter check**

Create `tools/verify_skill_rule_adapters.js`:

```javascript
const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const effectAdapter = read("scripts/skills/skill_effect_adapter.gd");
const triggerAdapter = read("scripts/skills/skill_trigger_rule_adapter.gd");
const eventBus = read("scripts/skills/skill_event_bus.gd");

for (const effectType of ["damage", "apply_status", "spawn_area", "spawn_projectile", "spawn_summon", "grant_shield", "pull", "transfer_status"]) {
  assert(effectAdapter.includes(`"${effectType}"`), `SkillEffectAdapter must map ${effectType}`);
}

for (const trigger of ["attack_hit", "enemy_death", "status_max_stack_reached", "projectile_hit", "area_tick"]) {
  assert(triggerAdapter.includes(`"${trigger}"`), `SkillTriggerRuleAdapter must normalize ${trigger}`);
}

assert(triggerAdapter.includes("counter_key"), "SkillTriggerRuleAdapter must support counters");
assert(triggerAdapter.includes("cooldown"), "SkillTriggerRuleAdapter must support cooldown");
assert(eventBus.includes("SkillTriggerRuleAdapterScript"), "SkillEventBus must use SkillTriggerRuleAdapter");

console.log("[verify_skill_rule_adapters] PASS");
```

- [ ] **Step 2: Add package script and run failure**

Add:

```json
"verify:skill-rule-adapters": "node tools\\verify_skill_rule_adapters.js"
```

Run: `npm run verify:skill-rule-adapters`

Expected: FAIL because adapter files do not exist.

- [ ] **Step 3: Create `SkillEffectAdapter`**

Create `scripts/skills/skill_effect_adapter.gd`:

```gdscript
extends RefCounted
class_name SkillEffectAdapter


static func to_actions(effects: Array) -> Array:
	var actions: Array = []
	for effect_variant: Variant in effects:
		if effect_variant is Dictionary:
			var action: Dictionary = to_action(effect_variant as Dictionary)
			if not action.is_empty():
				actions.append(action)
	return actions


static func to_action(effect: Dictionary) -> Dictionary:
	var effect_type: String = String(effect.get("type", ""))
	var params: Dictionary = effect.duplicate(true)
	params.erase("type")
	match effect_type:
		"damage":
			return {"type": "deal_damage", "params": _normalize_damage_params(params)}
		"apply_status":
			return {"type": "apply_status", "params": _normalize_status_params(params)}
		"spawn_area":
			return {"type": "spawn_area", "params": _normalize_area_params(params)}
		"spawn_projectile":
			return {"type": "spawn_projectile", "params": _normalize_projectile_params(params)}
		"spawn_summon":
			return {"type": "spawn_summon", "params": params}
		"add_modifier":
			return {"type": "add_temporary_modifier", "params": params}
		"grant_shield":
			return {"type": "grant_shield", "params": params}
		"heal":
			return {"type": "heal_owner", "params": params}
		"pull":
			return {"type": "pull", "params": params}
		"knockback":
			return {"type": "knockback", "params": params}
		"repeat_skill":
			return {"type": "repeat_skill", "params": params}
		"transform_area":
			return {"type": "transform_area", "params": params}
		"transfer_status":
			return {"type": "transfer_status", "params": params}
		"consume_status_duration":
			return {"type": "consume_status_duration", "params": params}
		"trigger_overload":
			return {"type": "trigger_overload", "params": params}
		"shatter_frozen":
			return {"type": "shatter_frozen", "params": params}
		"spawn_projectile_burst":
			return {"type": "spawn_projectile_burst", "params": params}
		"repeat_area_path":
			return {"type": "repeat_area_path", "params": params}
		"spawn_area_from_existing_area":
			return {"type": "spawn_area_from_existing_area", "params": params}
		_:
			push_warning("[SkillEffectAdapter] Unsupported effect type: %s" % effect_type)
			return {}


static func _normalize_damage_params(params: Dictionary) -> Dictionary:
	if params.has("power_scale") and not params.has("amount"):
		params["amount"] = {"stat": "power", "scale": float(params.get("power_scale", 0.0))}
	if params.has("source_type") and not params.has("damage_origin"):
		params["damage_origin"] = String(params.get("source_type"))
	return params


static func _normalize_status_params(params: Dictionary) -> Dictionary:
	if params.has("status") and not params.has("status_id"):
		params["status_id"] = params["status"]
	if params.has("stacks") and not params.has("stack"):
		params["stack"] = params["stacks"]
	return params


static func _normalize_area_params(params: Dictionary) -> Dictionary:
	if params.has("effects_on_tick"):
		params["actions_on_tick"] = to_actions(params.get("effects_on_tick", []))
	return params


static func _normalize_projectile_params(params: Dictionary) -> Dictionary:
	if params.has("on_hit"):
		params["actions_on_hit"] = to_actions(params.get("on_hit", []))
	if params.has("damage") and params.get("damage") is Dictionary:
		var damage: Dictionary = params.get("damage")
		if damage.has("power_scale"):
			params["damage"] = {"stat": "power", "scale": float(damage.get("power_scale", 0.0))}
		for key_variant: Variant in damage.keys():
			var key: String = String(key_variant)
			if not params.has(key):
				params[key] = damage[key_variant]
	return params
```

- [ ] **Step 4: Create `SkillTriggerRuleAdapter`**

Create `scripts/skills/skill_trigger_rule_adapter.gd`:

```gdscript
extends RefCounted
class_name SkillTriggerRuleAdapter


const SkillEffectAdapterScript: Script = preload("res://scripts/skills/skill_effect_adapter.gd")

const TRIGGER_ALIASES: Dictionary = {
	"attack_hit": &"attack_hit",
	"dash_start": &"dash_start",
	"dash_end": &"dash_end",
	"cast_skill": &"on_cast",
	"projectile_hit": &"on_projectile_hit",
	"area_tick": &"area_tick",
	"enemy_death": &"enemy_death",
	"status_applied": &"status_applied",
	"status_tick": &"status_tick",
	"status_expired": &"status_expired",
	"status_max_stack_reached": &"status_max_stack_reached",
	"shield_gained": &"shield_gained",
	"shield_broken": &"shield_broken",
	"summon_attack_hit": &"summon_attack_hit",
	"always": &"always",
}


static func to_events(skill_instance: RefCounted, definition: RefCounted) -> Array:
	var events: Array = []
	if definition == null:
		return events
	var rules_variant: Variant = definition.get("trigger_rules")
	if not (rules_variant is Array):
		return events
	for rule_variant: Variant in rules_variant:
		if rule_variant is Dictionary:
			var event: Dictionary = to_event(rule_variant as Dictionary, skill_instance)
			if not event.is_empty():
				events.append(event)
	return events


static func to_event(rule: Dictionary, _skill_instance: RefCounted = null) -> Dictionary:
	var trigger_name: String = String(rule.get("trigger", ""))
	var event_name: StringName = TRIGGER_ALIASES.get(trigger_name, StringName(trigger_name))
	if event_name == &"":
		return {}
	var event: Dictionary = {
		"trigger": event_name,
		"conditions": rule.get("conditions", []),
		"actions": SkillEffectAdapterScript.to_actions(rule.get("effects", []))
	}
	for optional_key: String in ["source_id", "counter_key", "threshold", "cooldown", "max_triggers_per_second"]:
		if rule.has(optional_key):
			event[optional_key] = rule[optional_key]
	return event


static func can_execute_rule_event(event: Dictionary, context: Dictionary, skill_instance: RefCounted) -> bool:
	if not _passes_counter(event, skill_instance):
		return false
	if not _passes_cooldown(event, context, skill_instance):
		return false
	return true


static func _passes_counter(event: Dictionary, skill_instance: RefCounted) -> bool:
	var counter_key: String = String(event.get("counter_key", ""))
	if counter_key == "" or skill_instance == null:
		return true
	var threshold: int = maxi(int(event.get("threshold", 1)), 1)
	var current: int = int(skill_instance.get_meta(counter_key, 0)) + 1
	if current >= threshold:
		skill_instance.set_meta(counter_key, 0)
		return true
	skill_instance.set_meta(counter_key, current)
	return false


static func _passes_cooldown(event: Dictionary, context: Dictionary, skill_instance: RefCounted) -> bool:
	if not event.has("cooldown") or skill_instance == null:
		return true
	var cooldown: float = maxf(float(event.get("cooldown", 0.0)), 0.0)
	if cooldown <= 0.0:
		return true
	var key: String = "trigger_cd:%s:%s" % [String(event.get("trigger", "")), String(event.get("source_id", ""))]
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var ready_at: float = float(skill_instance.get_meta(key, 0.0))
	if now < ready_at:
		return false
	skill_instance.set_meta(key, now + cooldown)
	context["last_trigger_cooldown_key"] = key
	return true
```

- [ ] **Step 5: Wire adapters into `SkillEventBus`**

Preload:

```gdscript
const SkillTriggerRuleAdapterScript: Script = preload("res://scripts/skills/skill_trigger_rule_adapter.gd")
```

In `_execute_skill_events`, after existing event matching and condition checks, add a guard:

```gdscript
if not SkillTriggerRuleAdapterScript.can_execute_rule_event(event, context, skill_instance):
	continue
```

In `_get_skill_events`, append adapted trigger rules:

```gdscript
events.append_array(SkillTriggerRuleAdapterScript.to_events(skill_instance, definition))
```

- [ ] **Step 6: Run checks**

Run:

```bash
npm run verify:skill-rule-adapters
npm run verify:fire-skill-system-contract
```

Expected: both PASS.

- [ ] **Step 7: Commit adapters**

```bash
git add package.json scripts/skills/skill_effect_adapter.gd scripts/skills/skill_trigger_rule_adapter.gd scripts/skills/skill_event_bus.gd tools/verify_skill_rule_adapters.js
git commit -m "feat: adapt skill triggers and effects"
```

## Task 6: New Offer Service

**Files:**
- Create: `scripts/skills/skill_offer_service.gd`
- Modify: `scripts/upgrades/upgrade_pool.gd`
- Create: `tools/verify_fire_skill_offer_rules.js`
- Modify: `package.json`

- [ ] **Step 1: Write the offer service static check**

Create `tools/verify_fire_skill_offer_rules.js`:

```javascript
const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const service = read("scripts/skills/skill_offer_service.gd");
const pool = read("scripts/upgrades/upgrade_pool.gd");

for (const token of ["required_schools", "required_min_skill_count", "blocked_by_exclusive_group", "exclusive_group", "fusion", "attack_school", "dash_school", "core_school"]) {
  assert(service.includes(token), `SkillOfferService must handle ${token}`);
}
assert(pool.includes("SkillOfferServiceScript"), "UpgradePool must preload SkillOfferService");
assert(pool.includes("_skill_offer_service"), "UpgradePool must own SkillOfferService");
assert(pool.includes("is_skill_available"), "UpgradePool must ask SkillOfferService before offering learn cards");

console.log("[verify_fire_skill_offer_rules] PASS");
```

- [ ] **Step 2: Add script and run failure**

Add:

```json
"verify:fire-skill-offer-rules": "node tools\\verify_fire_skill_offer_rules.js"
```

Run: `npm run verify:fire-skill-offer-rules`

Expected: FAIL because service is missing.

- [ ] **Step 3: Create `SkillOfferService`**

Create `scripts/skills/skill_offer_service.gd` with public methods:

```gdscript
extends RefCounted
class_name SkillOfferService


func is_skill_available(player: Node, skill: Dictionary) -> bool:
	var skill_id: StringName = StringName(String(skill.get("id", "")))
	if skill_id == &"":
		return false
	var skill_manager: Node = _get_skill_manager(player)
	if skill_manager == null:
		return false
	if _has_learned(skill_manager, skill_id):
		return false
	if _is_blocked_by_exclusive_group(skill_manager, skill):
		return false
	if String(skill.get("type", "")) == "fusion" and _has_any_fusion(skill_manager):
		return false
	return _offer_rule_met(skill_manager, _get_dictionary(skill.get("offer_rule", {})))


func _offer_rule_met(skill_manager: Node, offer_rule: Dictionary) -> bool:
	for school_variant: Variant in _get_array(offer_rule.get("required_schools", [])):
		if _count_school(skill_manager, StringName(String(school_variant))) <= 0:
			return false
	for skill_variant: Variant in _get_array(offer_rule.get("required_skills", [])):
		if not _has_learned(skill_manager, StringName(String(skill_variant))):
			return false
	var min_counts: Dictionary = _get_dictionary(offer_rule.get("required_min_skill_count", {}))
	for school_variant: Variant in min_counts.keys():
		if _count_school(skill_manager, StringName(String(school_variant))) < int(min_counts[school_variant]):
			return false
	return true


func _is_blocked_by_exclusive_group(skill_manager: Node, skill: Dictionary) -> bool:
	var blocked_groups: Array = _get_array(_get_dictionary(skill.get("offer_rule", {})).get("blocked_by_exclusive_group", []))
	var own_group: String = String(skill.get("exclusive_group", ""))
	if own_group != "":
		blocked_groups.append(own_group)
	for group_variant: Variant in blocked_groups:
		if _has_exclusive_group(skill_manager, String(group_variant)):
			return true
	return false


func _has_exclusive_group(skill_manager: Node, group: String) -> bool:
	if group == "":
		return false
	for skill_instance: RefCounted in _get_all_skills(skill_manager):
		if skill_instance != null and String(skill_instance.get("exclusive_group")) == group:
			return true
	return false


func _has_any_fusion(skill_manager: Node) -> bool:
	for skill_instance: RefCounted in _get_all_skills(skill_manager):
		if skill_instance != null and String(skill_instance.get("skill_type")) == "fusion":
			return true
	return false


func _count_school(skill_manager: Node, school: StringName) -> int:
	if school == &"":
		return 0
	var count: int = 0
	for skill_instance: RefCounted in _get_all_skills(skill_manager):
		if skill_instance == null:
			continue
		if StringName(String(skill_instance.get("school"))) == school or StringName(String(skill_instance.get("fusion_school"))) == school:
			count += 1
	return count


func _has_learned(skill_manager: Node, skill_id: StringName) -> bool:
	if skill_manager.has_method("has_skill") and bool(skill_manager.call("has_skill", skill_id)):
		return true
	if skill_manager.has_method("has_learned_skill") and bool(skill_manager.call("has_learned_skill", skill_id)):
		return true
	return false


func _get_all_skills(skill_manager: Node) -> Array:
	if skill_manager != null and skill_manager.has_method("get_all_skills"):
		var value: Variant = skill_manager.call("get_all_skills")
		if value is Array:
			return value
	return []


func _get_skill_manager(player: Node) -> Node:
	if player == null:
		return null
	var manager: Node = player.get_node_or_null("SkillManager")
	if manager != null:
		return manager
	if player.has_method("get_skill_manager"):
		var value: Variant = player.call("get_skill_manager")
		if value is Node:
			return value
	return null


func _get_array(value: Variant) -> Array:
	return value if value is Array else []


func _get_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
```

- [ ] **Step 4: Wire into `UpgradePool`**

Preload and instantiate:

```gdscript
const SkillOfferServiceScript: Script = preload("res://scripts/skills/skill_offer_service.gd")
var _skill_offer_service: RefCounted = SkillOfferServiceScript.new()
```

In `_build_god_skill_learn_options`, replace fire-only filtering with all skills from `GameData.get_skill_pool()` where `offer_in_upgrade_pool` is true or where the new schema has an `offer_rule`. Call:

```gdscript
if not bool(_skill_offer_service.call("is_skill_available", player, skill)):
	continue
```

- [ ] **Step 5: Run checks**

Run:

```bash
npm run verify:fire-skill-offer-rules
npm run verify:fire-skill-system-contract
```

Expected: both PASS.

- [ ] **Step 6: Commit offer service**

```bash
git add package.json scripts/skills/skill_offer_service.gd scripts/upgrades/upgrade_pool.gd tools/verify_fire_skill_offer_rules.js
git commit -m "feat: add skill offer service"
```

## Task 7: Action Executor Gaps

**Files:**
- Modify: `scripts/skills/skill_action_executor.gd`
- Create: `tools/verify_fire_effect_action_support.js`
- Modify: `package.json`

- [ ] **Step 1: Write static action support check**

Create `tools/verify_fire_effect_action_support.js`:

```javascript
const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const executor = read("scripts/skills/skill_action_executor.gd");
for (const action of ["grant_shield", "pull", "repeat_skill", "transform_area", "transfer_status", "consume_status_duration", "trigger_overload", "shatter_frozen", "spawn_projectile_burst", "repeat_area_path", "spawn_area_from_existing_area"]) {
  assert(executor.includes(`"${action}"`), `SkillActionExecutor must support ${action}`);
}
assert(executor.includes("power_scale") || executor.includes('"scale"'), "SkillActionExecutor must resolve scaled power damage");

console.log("[verify_fire_effect_action_support] PASS");
```

- [ ] **Step 2: Add script and run failure**

Add:

```json
"verify:fire-effect-actions": "node tools\\verify_fire_effect_action_support.js"
```

Run: `npm run verify:fire-effect-actions`

Expected: FAIL until the missing action names exist.

- [ ] **Step 3: Add match arms**

In `execute_action`, add:

```gdscript
"grant_shield":
	return _grant_shield(params, context)
"pull":
	return _pull(params, context)
"repeat_skill":
	return _repeat_skill(params, context)
"transform_area":
	return _transform_area(params, context)
"transfer_status":
	return _transfer_status(params, context)
"consume_status_duration":
	return _consume_status_duration(params, context)
"trigger_overload":
	return _trigger_overload(params, context)
"shatter_frozen":
	return _shatter_frozen(params, context)
"spawn_projectile_burst":
	return _spawn_projectile_burst(params, context)
"repeat_area_path":
	return _repeat_area_path(params, context)
"spawn_area_from_existing_area":
	return _spawn_area_from_existing_area(params, context)
```

Implement each as a generic method. If an action requires scene-specific data that does not exist yet, it must return `false` after logging a warning rather than throwing. `grant_shield`, `consume_status_duration`, and `transfer_status` should call existing target/player/status methods when present. `spawn_projectile_burst` should reuse `_spawn_projectile` in a loop with spread/count params.

- [ ] **Step 4: Support scaled power values**

In `_deal_damage` and spawn helpers, when `amount` or `damage` is a Dictionary shaped like `{"stat": "power", "scale": 0.9}`, resolve it as:

```gdscript
func _resolve_scaled_amount(value: Variant, context: Dictionary, stat_name: String = "damage") -> float:
	if value is Dictionary:
		var data: Dictionary = value
		if String(data.get("stat", "")) == "power":
			return float(ModifierResolverScript.resolve_value(context, stat_name, ModifierResolverScript.get_stat(context, "power", _get_caster_attack_power(context)))) * float(data.get("scale", 1.0))
	return float(ModifierResolverScript.resolve_value(context, stat_name, value))
```

Add `_get_caster_attack_power(context)` to read `attack_power`, `damage`, or `base_damage` from caster, falling back to `1.0`.

- [ ] **Step 5: Run checks**

Run:

```bash
npm run verify:fire-effect-actions
npm run verify:skill-rule-adapters
```

Expected: both PASS.

- [ ] **Step 6: Commit action support**

```bash
git add package.json scripts/skills/skill_action_executor.gd tools/verify_fire_effect_action_support.js
git commit -m "feat: support fire skill effect actions"
```

## Task 8: Status Runtime Events

**Files:**
- Modify: `scripts/combat/status_effect_manager.gd`
- Create: `tools/verify_fire_status_runtime_support.js`
- Modify: `package.json`

- [ ] **Step 1: Write static status runtime check**

Create `tools/verify_fire_status_runtime_support.js`:

```javascript
const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const manager = read("scripts/combat/status_effect_manager.gd");
for (const token of ["status_applied", "status_tick", "status_expired", "status_max_stack_reached", "consume_status_duration", "on_tick_effects", "max_stack_status"]) {
  assert(manager.includes(token), `StatusEffectManager must support ${token}`);
}

console.log("[verify_fire_status_runtime_support] PASS");
```

- [ ] **Step 2: Add package script and run failure**

Add:

```json
"verify:fire-status-runtime": "node tools\\verify_fire_status_runtime_support.js"
```

Run: `npm run verify:fire-status-runtime`

Expected: FAIL until event tokens and helpers exist.

- [ ] **Step 3: Add status events**

After status application, tick, expiration, and max-stack detection, emit through the player's `SkillEventBus` if available. Use event names:

```gdscript
&"status_applied"
&"status_tick"
&"status_expired"
&"status_max_stack_reached"
```

Event context must include:

```gdscript
{
	"target": get_parent(),
	"status_id": status_id,
	"status": status.duplicate(true),
	"position": (get_parent() as Node2D).global_position if get_parent() is Node2D else Vector2.ZERO
}
```

- [ ] **Step 4: Add max-stack conversion and duration consumption**

Add `consume_status_duration(status_id, seconds)` to reduce duration and erase status if duration reaches zero.

When a status reaches max stacks and its definition has `max_stack_status`, call `apply_status(max_stack_status, {})` and emit `status_max_stack_reached`.

- [ ] **Step 5: Run checks**

Run:

```bash
npm run verify:fire-status-runtime
npm run verify:fire-status-contract
```

Expected: both PASS.

- [ ] **Step 6: Commit status runtime support**

```bash
git add package.json scripts/combat/status_effect_manager.gd tools/verify_fire_status_runtime_support.js
git commit -m "feat: emit skill status events"
```

## Task 9: Obsolete Fire Card Cleanup

**Files:**
- Modify or delete obsolete tools that assert the old fire card contract:
  - `tools/verify_devtools_god_skill_cards_static.js`
  - `tools/verify_fire_skill_dev_tools_entry_static.js`
  - `tools/verify_fire_skill_upgrade_pool.js`
  - `tools/verify_mars_spark_missile_skill_card.js`
  - `tools/verify_skill_runtime_no_dead_cards.js`
- Modify: `scripts/debug/dev_debug_panel.gd` only if it still hardcodes old fire card IDs or old "60 fire skills" labels.

- [ ] **Step 1: Search old fire-card assumptions**

Run:

```bash
rg -n "mars_spark_missile|60 fire|fire upgrade skills|Runtime Skill Cards|GodSkillCard_mars|fire_tornado|soulburn" tools scripts data docs
```

Expected: list of obsolete assertions and any genuine runtime references.

- [ ] **Step 2: Remove or rewrite obsolete checks**

Delete checks whose only purpose is preserving old 60-card fire data. Rewrite any dev-panel checks to assert generic new fire skill behavior, using `fire_attack_searing` as the smoke ID instead of `mars_spark_missile`.

- [ ] **Step 3: Run repository verification scripts that still apply**

Run:

```bash
npm run verify:obsolete-runtime-removed
npm run verify:fire-skill-system-contract
npm run verify:fire-skill-offer-rules
```

Expected: PASS.

- [ ] **Step 4: Commit cleanup**

```bash
git add tools scripts/debug/dev_debug_panel.gd package.json
git commit -m "chore: remove obsolete fire skill card checks"
```

## Task 10: Runtime Smoke Test

**Files:**
- Create: `tools/verify_fire_skill_runtime_smoke.gd`
- Modify: `package.json`

- [ ] **Step 1: Create Godot smoke script**

Create `tools/verify_fire_skill_runtime_smoke.gd`. It should:

- instantiate a lightweight player node
- attach `SkillManager`, `SkillEventBus`, and `StatusEffectManager`
- learn all 34 skills by ID
- assert every skill is learned or levelable through the manager
- trigger representative events: attack hit, dash start, cast, enemy death, status max stack, shield gained, projectile hit, area tick
- apply `burning` and verify stack/tick snapshot behavior
- print `[verify_fire_skill_runtime_smoke] PASS`

Use existing smoke scripts in `tools/verify_fire_skill_card_selection_runtime.gd` and `tools/verify_burn_status_runtime_scene.gd` as local patterns for creating nodes and ending the script with a nonzero exit on failure.

- [ ] **Step 2: Add package script**

Add:

```json
"verify:fire-skill-runtime-smoke": ".\\roguelike_survivor.console.exe --headless --path . --script res://tools/verify_fire_skill_runtime_smoke.gd"
```

- [ ] **Step 3: Run smoke and fix failures task-locally**

Run:

```bash
npm run verify:fire-skill-runtime-smoke
```

Expected: PASS with `[verify_fire_skill_runtime_smoke] PASS`.

- [ ] **Step 4: Commit smoke**

```bash
git add package.json tools/verify_fire_skill_runtime_smoke.gd
git commit -m "test: add fire skill runtime smoke"
```

## Task 11: Final Verification

**Files:**
- No new files expected.

- [ ] **Step 1: Run all new verification commands**

Run:

```bash
npm run verify:fire-skill-system-contract
npm run verify:fire-status-contract
npm run verify:skill-definition-schema
npm run verify:skill-rule-adapters
npm run verify:fire-skill-offer-rules
npm run verify:fire-effect-actions
npm run verify:fire-status-runtime
npm run verify:fire-skill-runtime-smoke
```

Expected: all PASS.

- [ ] **Step 2: Check git status**

Run:

```bash
git status --short
```

Expected: only files intentionally changed by this plan are modified or staged. Existing unrelated workspace changes may remain, but they must not be included in commits for this plan.

- [ ] **Step 3: Review first-version acceptance criteria**

Confirm:

- Old fire god skill card data is removed.
- `data/skills.json` has exactly 34 authored fire-scope skill definitions.
- New skill schema is parsed.
- Offer rules handle fire base skills, exclusivity, and fire-related fusion unlocks.
- Core statuses required by fire and fire-related fusions exist.
- Representative combat smoke passes.
- Static validation confirms supported triggers, conditions, effects, and payload.

- [ ] **Step 4: Commit final fixes if any**

If final verification required fixes:

```bash
git add data scripts tools package.json
git commit -m "fix: complete fire skill system verification"
```

If final verification required no fixes, do not create an empty commit.
