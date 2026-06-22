const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function readText(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function getSpawnObjectId(action) {
  const params = action.params || {};
  if (action.type === "spawn_projectile" || action.type === "spawn_projectiles_at_targets") return params.projectile_id || "";
  if (action.type === "spawn_area" || action.type === "create_explosion" || action.type === "spawn_trap") return params.area_id || "";
  if (action.type === "spawn_orbit_object") return params.object_id || params.orbit_object_id || "";
  return "";
}

function main() {
  const weapons = readJson("data/weapons.json").weapons || [];
  const primaryAttacks = readJson("data/primary_attack.json").primary_attacks || [];
  const combatObjects = readJson("data/combat_objects.json").combat_objects || [];
  const attackById = new Map(primaryAttacks.map((attack) => [attack.id, attack]));
  const objectById = new Map(combatObjects.map((object) => [object.id, object]));
  const referencedObjectIds = new Set();

  for (const weapon of weapons) {
    const skillId = weapon.starting_skill_id || weapon.primary_attack_id;
    const attack = attackById.get(skillId);
    assert(attack, `Weapon ${weapon.id} must resolve primary attack ${skillId}`);
    assert(weapon.visual && typeof weapon.visual.rotation === "number", `Weapon ${weapon.id} must declare numeric visual.rotation`);
    for (const event of attack.events || []) {
      for (const action of event.actions || []) {
        const objectId = getSpawnObjectId(action);
        if (objectId !== "") referencedObjectIds.add(objectId);
      }
    }
  }

  const fireStaff = weapons.find((weapon) => weapon.id === "fire_staff");
  assert(fireStaff && fireStaff.visual && typeof fireStaff.visual.rotation === "number", "fire_staff must demonstrate visual.rotation config");

  assert(referencedObjectIds.size >= 12, `Expected current primary attacks to reference at least 12 combat objects, got ${referencedObjectIds.size}`);
  for (const objectId of [...referencedObjectIds].sort()) {
    const object = objectById.get(objectId);
    assert(object, `Referenced combat object must exist: ${objectId}`);
    assert(typeof object.visual_style === "string" && object.visual_style.length > 0, `${objectId} must declare visual_style`);
    assert(["programmatic", "asset"].includes(String(object.visual_mode || "programmatic")), `${objectId} must declare a supported visual_mode when configured`);
    assert(Array.isArray(object.visual_color) && object.visual_color.length >= 4, `${objectId} must declare rgba visual_color`);
    assert(Array.isArray(object.visual_ring_color) && object.visual_ring_color.length >= 4, `${objectId} must declare rgba visual_ring_color`);
    assert(object.visual && typeof object.visual === "object", `${objectId} must keep replaceable visual config`);
  }

  const projectile = readText("scripts/combat/projectile.gd");
  for (const style of [
    "fireball_orb",
    "hail_orb",
    "lightning_orb",
    "arcane_page",
    "throwing_knife",
    "hunter_arrow",
    "poison_bottle",
    "oil_pot",
  ]) {
    assert(projectile.includes(`"${style}"`), `Projectile must support programmatic style ${style}`);
  }
  assert(projectile.includes("func _draw() -> void:"), "Projectile must draw programmatic fallback visuals");

  const combatObjectFactory = readText("scripts/combat/combat_object_factory.gd");
  assert(combatObjectFactory.includes('"visual_style", "visual_color", "visual_ring_color", "visual_mode"'), "CombatObjectFactory must merge top-level visual fallback fields");
  const actionExecutor = readText("scripts/skills/skill_action_executor.gd");
  assert(
    actionExecutor.includes('if area_params.has("visual_style"):') &&
      !actionExecutor.includes('"visual_style": String(area_params.get("visual_style", ""))'),
    "SkillActionExecutor must let area_id definitions provide visual_style unless an action explicitly overrides it"
  );

  const weaponVisual = readText("scripts/weapons/weapon_visual.gd");
  assert(weaponVisual.includes('visual.get("rotation"'), "WeaponVisual must support visual.rotation for weapon sprite rotation");

  const areaEffect = readText("scripts/combat/area_effect.gd");
  for (const style of [
    "fire_burst",
    "frost_patch",
    "trap_circle",
    "holy_field",
    "holy_shield_pulse",
    "hammer_shockwave",
    "poison_cloud",
    "poison_zone",
    "lava_zone",
    "smoke_zone",
    "acid_cone",
  ]) {
    assert(areaEffect.includes(`"${style}"`), `AreaEffect must support programmatic style ${style}`);
  }
  assert(areaEffect.includes("func _uses_programmatic_visual() -> bool:"), "AreaEffect must centralize programmatic visual style checks");

  console.log("Weapon attack visuals verified.");
}

main();
