const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function byId(items) {
  const result = new Map();
  for (const item of asArray(items)) {
    result.set(String(item.id || ""), item);
  }
  return result;
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function smokeLoadout(character, weapon, skills) {
  const characterId = String(character.id || "");
  const weaponId = String(weapon.id || "");
  const allowedWeapons = asArray(character.allowed_weapon_ids).map(String);

  assert(allowedWeapons.includes(weaponId), `${characterId} cannot equip ${weaponId}`);
  assert(weapon.starting_skill_id, `${weaponId} has no starting_skill_id`);
  const skill = skills.get(String(weapon.starting_skill_id || ""));
  assert(skill, `${weaponId} starting skill is missing: ${weapon.starting_skill_id}`);
  assert(String(skill.category || "") === "active", `${weaponId} starting skill must be active: ${weapon.starting_skill_id}`);

  const baseStats = character.base_stats || {};
  for (const stat of ["max_hp", "move_speed", "damage_multiplier", "attack_speed_multiplier", "crit_chance", "crit_damage", "armor", "pickup_radius", "soul_gain_multiplier"]) {
    assert(Number.isFinite(Number(baseStats[stat])), `${characterId} base_stats.${stat} must be numeric`);
  }

  assert(character.trait && character.trait.type, `${characterId} has no trait.type`);
  assert(character.trait.params && typeof character.trait.params === "object", `${characterId} has no trait.params`);

  return {
    character_id: characterId,
    weapon_id: weaponId,
    starting_skill_id: String(weapon.starting_skill_id),
    trait_type: String(character.trait.type),
  };
}

function main() {
  const characters = byId(readJson("data/characters.json").characters);
  const weapons = byId(readJson("data/weapons.json").weapons);
  const skills = byId(readJson("data/primary_attack.json").primary_attacks);

  const rows = [];
  for (const character of characters.values()) {
    for (const weaponId of asArray(character.allowed_weapon_ids).map(String)) {
      const weapon = weapons.get(weaponId);
      assert(weapon, `${character.id} references missing weapon: ${weaponId}`);
      rows.push(smokeLoadout(character, weapon, skills));
    }
  }

  for (const row of rows) {
    console.log(`${row.character_id} + ${row.weapon_id} -> ${row.starting_skill_id} (${row.trait_type})`);
  }
  console.log(`Character system smoke checks passed. loadouts=${rows.length}`);
}

main();
