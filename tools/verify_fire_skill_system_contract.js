const path = require("path");
const { readJsonFile } = require("./lib/json_file");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return readJsonFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function assertClose(actual, expected, message) {
  assert(typeof actual === "number", `${message}: actual value must be a number`);
  assert(Math.abs(actual - expected) <= 0.0001, `${message}: expected ${expected}, got ${actual}`);
}

function rangePx(units) {
  return units * RANGE_UNIT_PX;
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
  "dash_tick",
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
  "player_damage_taken",
  "summon_attack_hit",
  "post_damage_hit",
  "always",
]);
const SUPPORTED_CONDITIONS = new Set([
  "target_has_status",
  "target_has_tag",
  "owner_has_skill",
  "owner_has_relic",
  "skill_has_tag",
  "source_has_tag",
  "damage_element_is",
  "event_status_is",
  "random_chance",
  "target_hp_below",
  "is_critical_hit",
  "enemy_count_in_radius",
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
const RANGE_UNIT_PX = 84.0;
const REQUIRED_FIRE_AREA_VISUAL_IDS = new Set([
  "searing_fire_path",
  "blazing_run_path",
  "meteor_burning_ground",
  "lava_rift",
  "scorching_vortex",
  "ember_fox_burst",
]);
const REQUIRED_METEOR_PROJECTILE_IDS = new Set([
  "meteor_rain_meteor",
  "inferno_cycle_meteor",
]);
const NESTED_EFFECT_ARRAY_FIELDS = new Set([
  "effects",
  "effects_on_tick",
  "effects_on_expire",
  "effects_on_apply",
  "effects_on_remove",
  "effects_on_death",
  "effects_on_status_applied",
  "effects_on_status_tick",
  "effects_on_status_expired",
  "effects_on_status_max_stack_reached",
  "on_hit",
  "on_tick_effects",
  "on_expire",
  "on_apply",
  "on_death",
]);

function isObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function validateEffectArray(effects, skillId, location) {
  assert(Array.isArray(effects), `${skillId} ${location} must be an array`);
  effects.forEach((effect, index) => {
    validateEffect(effect, skillId, `${location}[${index}]`);
  });
}

function validateEffect(effect, skillId, location) {
  assert(isObject(effect), `${skillId} ${location} effect must be an object`);
  assert(SUPPORTED_EFFECTS.has(effect.type), `${skillId} unsupported effect ${effect.type} at ${location}`);
  validateNestedEffectArrays(effect, skillId, location);
}

function validateNestedEffectArrays(value, skillId, location) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => validateNestedEffectArrays(item, skillId, `${location}[${index}]`));
    return;
  }
  if (!isObject(value)) {
    return;
  }
  for (const [key, child] of Object.entries(value)) {
    const childLocation = `${location}.${key}`;
    if (NESTED_EFFECT_ARRAY_FIELDS.has(key)) {
      validateEffectArray(child, skillId, childLocation);
    } else if (key === "conditions") {
      validateConditionArray(child, skillId, childLocation);
    } else if (isObject(child) || Array.isArray(child)) {
      validateNestedEffectArrays(child, skillId, childLocation);
    }
  }
}

function buildExpectedSkillMetadata() {
  assert(FIRE_BASE_IDS.length === 14, `FIRE_BASE_IDS must contain exactly 14 ids, got ${FIRE_BASE_IDS.length}`);
  assert(FIRE_FUSION_IDS.length === 20, `FIRE_FUSION_IDS must contain exactly 20 ids, got ${FIRE_FUSION_IDS.length}`);

  const fireBaseIds = new Set(FIRE_BASE_IDS);
  const fireFusionIds = new Set(FIRE_FUSION_IDS);

  assert(fireBaseIds.size === FIRE_BASE_IDS.length, "FIRE_BASE_IDS must not contain duplicate ids");
  assert(fireFusionIds.size === FIRE_FUSION_IDS.length, "FIRE_FUSION_IDS must not contain duplicate ids");
  for (const id of FIRE_BASE_IDS) {
    assert(!fireFusionIds.has(id), `fire skill id must not be both base and fusion: ${id}`);
  }

  const metadata = new Map();
  for (const id of FIRE_BASE_IDS) {
    metadata.set(id, { school: "fire", fusion_school: null, required_min_skill_count: null });
  }
  for (const id of FIRE_FUSION_IDS) {
    const match = /^fusion_(fire|frost|thunder|curse|holy|chaos)_(fire|frost|thunder|curse|holy|chaos)_/.exec(id);
    assert(match, `fusion skill id must encode school pair: ${id}`);
    const school = match[1];
    const fusionSchool = match[2];
    assert(school !== fusionSchool, `fusion skill id must encode two different schools: ${id}`);
    metadata.set(id, {
      school,
      fusion_school: fusionSchool,
      required_min_skill_count: { [school]: 2, [fusionSchool]: 1 },
    });
  }

  assert(metadata.size === FIRE_BASE_IDS.length + FIRE_FUSION_IDS.length, "expected fire skill metadata must cover every unique id");
  return metadata;
}

function validateOfferRuleArrays(skill) {
  const offerRule = skill.offer_rule;
  if (Object.prototype.hasOwnProperty.call(offerRule, "required_schools")) {
    assert(Array.isArray(offerRule.required_schools), `${skill.id} offer_rule.required_schools must be an array`);
    offerRule.required_schools.forEach((school, index) => {
      assert(typeof school === "string", `${skill.id} offer_rule.required_schools[${index}] must be a string`);
      assert(ALLOWED_SCHOOLS.has(school), `${skill.id} offer_rule.required_schools[${index}] invalid school ${school}`);
    });
  }
  if (Object.prototype.hasOwnProperty.call(offerRule, "required_skills")) {
    assert(Array.isArray(offerRule.required_skills), `${skill.id} offer_rule.required_skills must be an array`);
    offerRule.required_skills.forEach((requiredSkill, index) => {
      assert(typeof requiredSkill === "string", `${skill.id} offer_rule.required_skills[${index}] must be a string`);
    });
  }
  if (Object.prototype.hasOwnProperty.call(offerRule, "blocked_by_exclusive_group")) {
    assert(Array.isArray(offerRule.blocked_by_exclusive_group), `${skill.id} offer_rule.blocked_by_exclusive_group must be an array`);
    offerRule.blocked_by_exclusive_group.forEach((group, index) => {
      assert(typeof group === "string", `${skill.id} offer_rule.blocked_by_exclusive_group[${index}] must be a string`);
    });
  }
}

function validateRequiredMinSkillCount(skill, expectedMetadata) {
  const requiredMinSkillCount = skill.offer_rule.required_min_skill_count;
  assert(isObject(requiredMinSkillCount), `${skill.id} offer_rule.required_min_skill_count must be a non-array object`);
  const entries = Object.entries(requiredMinSkillCount);
  assert(entries.length > 0, `${skill.id} offer_rule.required_min_skill_count must not be empty`);
  const expectedCounts = expectedMetadata.required_min_skill_count;
  const expectedSchools = Object.keys(expectedCounts);
  assert(entries.length === expectedSchools.length, `${skill.id} offer_rule.required_min_skill_count must not contain extra schools`);
  for (const [school, count] of entries) {
    assert(ALLOWED_SCHOOLS.has(school), `${skill.id} offer_rule.required_min_skill_count invalid school ${school}`);
    assert(Number.isInteger(count) && count > 0, `${skill.id} offer_rule.required_min_skill_count.${school} must be a positive integer`);
    assert(Object.prototype.hasOwnProperty.call(expectedCounts, school), `${skill.id} offer_rule.required_min_skill_count unexpected school ${school}`);
    assert(expectedCounts[school] === count, `${skill.id} offer_rule.required_min_skill_count.${school} must equal ${expectedCounts[school]}`);
  }
}

function validateConditionArray(conditions, skillId, location) {
  assert(Array.isArray(conditions), `${skillId} ${location} must be an array`);
  conditions.forEach((condition, conditionIndex) => {
    const conditionLocation = `${location}[${conditionIndex}]`;
    assert(isObject(condition), `${skillId} ${conditionLocation} must be a non-array object`);
    assert(Object.prototype.hasOwnProperty.call(condition, "type"), `${skillId} ${conditionLocation} missing type`);
    const conditionType = condition.type;
    assert(SUPPORTED_CONDITIONS.has(conditionType), `${skillId} unsupported condition ${conditionType} at ${conditionLocation}`);
  });
}

function validateTriggerRuleConditions(rule, skillId, ruleIndex) {
  if (!Object.prototype.hasOwnProperty.call(rule, "conditions")) {
    return;
  }
  validateConditionArray(rule.conditions, skillId, `trigger_rules[${ruleIndex}].conditions`);
}

function validateSkill(skill, expectedIds, fireBaseIds, fireFusionIds, expectedMetadataById) {
  for (const field of REQUIRED_SKILL_FIELDS) {
    assert(Object.prototype.hasOwnProperty.call(skill, field), `${skill.id || "missing id"} missing field ${field}`);
  }
  assert(!OBSOLETE_FIRE_IDS.has(skill.id), `obsolete fire card id still present: ${skill.id}`);
  assert(expectedIds.has(skill.id), `unexpected first-version fire skill id: ${skill.id}`);
  assert(Array.isArray(skill.trigger_rules), `${skill.id} trigger_rules must be an array`);
  assert(Array.isArray(skill.effects), `${skill.id} effects must be an array`);
  assert(ALLOWED_SCHOOLS.has(skill.school), `${skill.id} invalid school`);
  if (skill.fusion_school !== null) {
    assert(ALLOWED_SCHOOLS.has(skill.fusion_school), `${skill.id} invalid fusion_school`);
  }
  assert(ALLOWED_TYPES.has(skill.type), `${skill.id} invalid type`);
  assert(ALLOWED_RARITIES.has(skill.rarity), `${skill.id} invalid rarity`);
  assert(Number.isInteger(skill.max_level) && skill.max_level >= 1, `${skill.id} invalid max_level`);
  assert(Array.isArray(skill.tags) && skill.tags.length > 0, `${skill.id} must have non-empty tags`);
  assert(isObject(skill.offer_rule), `${skill.id} invalid offer_rule`);
  validateOfferRuleArrays(skill);
  const expectedMetadata = expectedMetadataById.get(skill.id);
  assert(skill.school === expectedMetadata.school, `${skill.id} must set school ${expectedMetadata.school}`);
  assert(skill.fusion_school === expectedMetadata.fusion_school, `${skill.id} must set fusion_school ${expectedMetadata.fusion_school}`);
  if (fireFusionIds.has(skill.id)) {
    assert(skill.type === "fusion", `${skill.id} fusion skill id must set type fusion`);
    assert(skill.fusion_school !== null, `${skill.id} fusion skill must set fusion_school`);
    validateRequiredMinSkillCount(skill, expectedMetadata);
  }
  if (fireBaseIds.has(skill.id)) {
    assert(skill.type !== "fusion", `${skill.id} base skill id must not set type fusion`);
    assert(skill.fusion_school === null, `${skill.id} base skill id must set fusion_school null`);
  }

  skill.trigger_rules.forEach((rule, index) => {
    assert(isObject(rule), `${skill.id} trigger_rules[${index}] must be an object`);
    assert(SUPPORTED_TRIGGERS.has(rule.trigger), `${skill.id} unsupported trigger ${rule.trigger}`);
    validateTriggerRuleConditions(rule, skill.id, index);
    validateEffectArray(rule.effects, skill.id, `trigger_rules[${index}].effects`);
  });
  validateEffectArray(skill.effects, skill.id, "effects");

  assert(skill.trigger_rules.length > 0 || skill.effects.length > 0, `${skill.id} has no runtime payload`);
}

function findSkill(skills, id) {
  return skills.find((skill) => skill.id === id);
}

function firstEffect(skill) {
  assert(skill.trigger_rules.length > 0, `${skill.id} must have trigger rules`);
  assert(skill.trigger_rules[0].effects.length > 0, `${skill.id} first trigger rule must have effects`);
  return skill.trigger_rules[0].effects[0];
}

function validateMeteorRainSkill(skills) {
  const skill = findSkill(skills, "fire_cast_meteor_rain");
  assert(isObject(skill), "fire_cast_meteor_rain must exist");
  const effect = firstEffect(skill);
  assert(effect.type === "spawn_projectile_burst", "fire_cast_meteor_rain must spawn a projectile burst");
  assert(effect.projectile_id === "meteor_rain_meteor", "fire_cast_meteor_rain must spawn meteor_rain_meteor");
  assert(effect.trajectory_mode === "linear", "fire_cast_meteor_rain meteors must fall in a straight line");
  assert(!Object.prototype.hasOwnProperty.call(effect, "curve_height"), "fire_cast_meteor_rain meteors must not use curve_height");
  assert(Array.isArray(effect.visual_start_offset), "fire_cast_meteor_rain must set a visual_start_offset");
  assert(effect.visual_start_offset[0] === -360.0 && effect.visual_start_offset[1] === -360.0, "fire_cast_meteor_rain must use a 45-degree fall offset");
  assert(effect.collision_radius === 18.0, "fire_cast_meteor_rain projectile collision radius must remain focused");
  assert(!Object.prototype.hasOwnProperty.call(effect, "radius"), "fire_cast_meteor_rain projectile collision must not be stored as skill range radius");
  const damageEffect = effect.on_hit.find((child) => child.type === "damage");
  assert(isObject(damageEffect), "fire_cast_meteor_rain must deal impact damage on hit");
  assertClose(damageEffect.radius, rangePx(1.6), "fire_cast_meteor_rain impact damage radius must be 1.6R");
  const areaEffect = effect.on_hit.find((child) => child.type === "spawn_area" && child.area_id === "meteor_burning_ground");
  assert(isObject(areaEffect), "fire_cast_meteor_rain must spawn meteor_burning_ground on hit");
  assertClose(areaEffect.radius, rangePx(1.6), "fire_cast_meteor_rain crater area radius must be 1.6R");
}

function requireEffect(skill, ruleIndex, effectIndex) {
  assert(isObject(skill), "required skill must exist");
  assert(Array.isArray(skill.trigger_rules), `${skill.id} trigger_rules must be an array`);
  const rule = skill.trigger_rules[ruleIndex];
  assert(isObject(rule), `${skill.id} trigger_rules[${ruleIndex}] must exist`);
  assert(Array.isArray(rule.effects), `${skill.id} trigger_rules[${ruleIndex}].effects must be an array`);
  const effect = rule.effects[effectIndex];
  assert(isObject(effect), `${skill.id} trigger_rules[${ruleIndex}].effects[${effectIndex}] must exist`);
  return effect;
}

function validateBaseFireRangePixels(skills) {
  const byId = new Map(skills.map((skill) => [skill.id, skill]));

  assertClose(requireEffect(byId.get("fire_attack_searing"), 1, 0).radius, rangePx(0.8), "fire_attack_searing fire path radius must be 0.8R");
  assertClose(requireEffect(byId.get("fire_dash_blazing_run"), 0, 0).radius, rangePx(0.75), "fire_dash_blazing_run dash_start path radius must be 0.75R");
  assertClose(requireEffect(byId.get("fire_dash_blazing_run"), 1, 0).radius, rangePx(0.75), "fire_dash_blazing_run dash_tick path radius must be 0.75R");

  const lavaRift = requireEffect(byId.get("fire_cast_lava_rift"), 0, 0);
  assertClose(lavaRift.length, rangePx(6.0), "fire_cast_lava_rift length must be 6R");
  assertClose(lavaRift.width, rangePx(0.8), "fire_cast_lava_rift width must be 0.8R");

  const vortex = requireEffect(byId.get("fire_cast_scorching_vortex"), 0, 0);
  assertClose(vortex.radius, rangePx(2.2), "fire_cast_scorching_vortex radius must be 2.2R");
  const vortexPull = vortex.effects_on_tick.find((child) => child.type === "pull");
  assert(!isObject(vortexPull), "fire_cast_scorching_vortex must not pull enemies back toward the player");

  assertClose(requireEffect(byId.get("fire_summon_crimson_dragon"), 1, 0).length, rangePx(4.0), "fire_summon_crimson_dragon breath length must be 4R");
  assertClose(requireEffect(byId.get("fire_summon_ember_fox_pack"), 1, 1).radius, rangePx(1.2), "fire_summon_ember_fox_pack burst radius must be 1.2R");
  assertClose(requireEffect(byId.get("fire_power_combustion_chain"), 0, 0).radius, rangePx(2.2), "fire_power_combustion_chain radius must be 2.2R");
  assertClose(requireEffect(byId.get("fire_power_ignite_core"), 0, 1).radius, rangePx(1.2), "fire_power_ignite_core projectile hit radius must be 1.2R");
  assertClose(requireEffect(byId.get("fire_power_ignite_core"), 1, 1).radius, rangePx(1.2), "fire_power_ignite_core area tick radius must be 1.2R");
  assertClose(requireEffect(byId.get("fire_core_inferno_cycle"), 0, 0).radius, rangePx(1.4), "fire_core_inferno_cycle burst radius must be 1.4R");
}

function validateNoRawRangeUnits(value, location) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => validateNoRawRangeUnits(item, `${location}[${index}]`));
    return;
  }
  if (!isObject(value)) {
    return;
  }
  for (const [key, child] of Object.entries(value)) {
    const childLocation = `${location}.${key}`;
    if ((key === "radius" || key === "length" || key === "width") && typeof child === "number") {
      assert(child > 10.0, `${childLocation} appears to still be stored in raw R units: ${child}`);
    }
    validateNoRawRangeUnits(child, childLocation);
  }
}

function main() {
	const expectedMetadataById = buildExpectedSkillMetadata();

	const document = readJson("data/skills.json");
	const combatObjectsDocument = readJson("data/combat_objects.json");
	const charactersDocument = readJson("data/characters.json");
	assert(Array.isArray(document.starting_skills), "data/skills.json starting_skills must be an array");
	assert(document.starting_skills.length === 1, `data/skills.json must contain exactly one starting skill, got ${document.starting_skills.length}`);
	const fireball = document.starting_skills[0];
	assert(isObject(fireball), "data/skills.json starting_skills[0] must be an object");
	assert(fireball.id === "fireball", "data/skills.json starting skill must be fireball");
	assert(fireball.is_starting_skill === true, "fireball must be marked as a starting skill");
	assert(fireball.offer_in_upgrade_pool === false, "fireball must not appear in the upgrade offer pool");

	assert(Array.isArray(document.skills), "data/skills.json skills must be an array");
	const skills = document.skills;
	skills.forEach((skill, index) => {
		assert(isObject(skill), `data/skills.json skills[${index}] must be a non-array object`);
	});
  const fireBaseIds = new Set(FIRE_BASE_IDS);
  const fireFusionIds = new Set(FIRE_FUSION_IDS);
  const expectedIds = new Set(expectedMetadataById.keys());
  const fireSkills = skills.filter((skill) => expectedIds.has(skill.id));
  const actualIds = new Set(fireSkills.map((skill) => skill.id));

	assert(fireSkills.length === 34, `data/skills.json must contain exactly 34 first-version fire skills, got ${fireSkills.length}`);
	assert(!actualIds.has("fireball"), "fireball belongs in starting_skills, not the first-version fire skill pool");
	for (const id of expectedIds) {
		assert(actualIds.has(id), `missing skill ${id}`);
	}
	for (const skill of fireSkills) {
		validateSkill(skill, expectedIds, fireBaseIds, fireFusionIds, expectedMetadataById);
	}
	validateMeteorRainSkill(fireSkills);
	validateBaseFireRangePixels(fireSkills);
	validateNoRawRangeUnits(fireSkills, "data/skills.json.skills");

	const combatObjects = Array.isArray(combatObjectsDocument.combat_objects) ? combatObjectsDocument.combat_objects : [];
	const combatObjectById = new Map(combatObjects.map((object) => [object.id, object]));
	for (const areaId of REQUIRED_FIRE_AREA_VISUAL_IDS) {
		const object = combatObjectById.get(areaId);
		assert(isObject(object), `fire area ${areaId} must have a combat object definition`);
		assert(object.type === "area", `fire area ${areaId} must be an area combat object`);
		assert(object.visual_mode === "programmatic", `fire area ${areaId} must use programmatic visuals`);
		assert(typeof object.visual_style === "string" && object.visual_style !== "", `fire area ${areaId} must set visual_style`);
	}
	const meteorGround = combatObjectById.get("meteor_burning_ground");
	assert(meteorGround.visual_style === "meteor_crater", "meteor_burning_ground must draw a meteor crater impact visual");
	for (const projectileId of REQUIRED_METEOR_PROJECTILE_IDS) {
		const object = combatObjectById.get(projectileId);
		assert(isObject(object), `meteor projectile ${projectileId} must have a combat object definition`);
		assert(object.type === "projectile", `meteor projectile ${projectileId} must be a projectile combat object`);
		assert(object.visual_mode === "programmatic", `meteor projectile ${projectileId} must use programmatic visuals`);
		assert(object.visual_style === "meteor", `meteor projectile ${projectileId} must draw the meteor visual style`);
	}

	const allSkillIds = new Set([...document.starting_skills, ...skills].map((skill) => skill.id));
	assert(Array.isArray(charactersDocument.characters), "data/characters.json characters must be an array");
	for (const character of charactersDocument.characters) {
		assert(isObject(character), "data/characters.json characters entries must be objects");
		const startingSkillId = character.starting_skill_id;
		assert(typeof startingSkillId === "string" && startingSkillId !== "", `${character.id || "missing character"} must set starting_skill_id`);
		assert(allSkillIds.has(startingSkillId), `${character.id || "missing character"} references missing starting_skill_id ${startingSkillId}`);
	}

	console.log("[verify_fire_skill_system_contract] PASS");
}

main();
