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

function validateSkill(skill, expectedIds, fireBaseIds, fireFusionIds) {
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
  if (fireFusionIds.has(skill.id)) {
    assert(skill.type === "fusion", `${skill.id} fusion skill id must set type fusion`);
    assert(skill.fusion_school !== null, `${skill.id} fusion skill must set fusion_school`);
    assert(skill.offer_rule.required_min_skill_count, `${skill.id} must set offer_rule.required_min_skill_count`);
  }
  if (fireBaseIds.has(skill.id)) {
    assert(skill.type !== "fusion", `${skill.id} base skill id must not set type fusion`);
  }
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
  const fireBaseIds = new Set(FIRE_BASE_IDS);
  const fireFusionIds = new Set(FIRE_FUSION_IDS);
  const expectedIds = new Set([...FIRE_BASE_IDS, ...FIRE_FUSION_IDS]);
  const actualIds = new Set(skills.map((skill) => skill.id));

  assert(skills.length === 34, `data/skills.json must contain exactly 34 first-version skills, got ${skills.length}`);
  for (const id of expectedIds) {
    assert(actualIds.has(id), `missing skill ${id}`);
  }
  for (const skill of skills) {
    validateSkill(skill, expectedIds, fireBaseIds, fireFusionIds);
  }

  console.log("[verify_fire_skill_system_contract] PASS");
}

main();
