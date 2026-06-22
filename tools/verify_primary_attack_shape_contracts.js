const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, ""));
}

function readText(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function attack(id) {
  const found = (readJson("data/primary_attack.json").primary_attacks || []).find((entry) => entry.id === id);
  assert(found, `primary attack ${id} must exist`);
  return found;
}

function combatObject(id) {
  const found = (readJson("data/combat_objects.json").combat_objects || []).find((entry) => entry.id === id);
  assert(found, `combat object ${id} must exist`);
  return found;
}

function eventByTrigger(definition, trigger, sourceId = "") {
  const found = (definition.events || []).find((event) => {
    if (event.trigger !== trigger) return false;
    return sourceId === "" || event.source_id === sourceId;
  });
  assert(found, `${definition.id} must include ${trigger}${sourceId ? ` for ${sourceId}` : ""}`);
  return found;
}

function actionByType(event, type) {
  const found = (event.actions || []).find((action) => action.type === type);
  assert(found, `${event.trigger} must include ${type}`);
  return found;
}

function main() {
  const bearTrap = attack("bear_trap");
  assert(!(bearTrap.components || []).some((entry) => entry.type === "targeting"), "bear_trap must cast without requiring an enemy target");
  const trapAction = actionByType(eventByTrigger(bearTrap, "on_cast"), "spawn_trap");
  assert(trapAction.params.position_mode === "caster", "bear_trap must deploy at the player's feet");
  assert(trapAction.params.radius === 90 && trapAction.params.finish_after_damage === true, "bear_trap must arm a trigger radius and consume on first hit");

  const warhammer = attack("judgement_hammer");
  assert(!(warhammer.components || []).some((entry) => entry.type === "targeting"), "judgement_hammer must not place its impact directly on a target");
  const hammerArea = actionByType(eventByTrigger(warhammer, "on_cast"), "spawn_area");
  assert(hammerArea.params.position_mode === "caster", "judgement_hammer must start from the weapon/player area");
  assert(hammerArea.params.expand_from_radius >= 0 && hammerArea.params.expand_to_radius === 90, "judgement_hammer must expand damage out to its impact radius");
  assert(hammerArea.params.damage_once_per_body === true, "judgement_hammer expansion must not multi-hit the same enemy during one swing");

  const oilPot = attack("burning_oil_pot");
  const oilCast = actionByType(eventByTrigger(oilPot, "on_cast"), "spawn_projectile");
  assert(oilCast.params.projectile_id === "fire_oil_pot_projectile", "burning_oil_pot must throw an oil pot projectile");
  assert(oilCast.params.trajectory_mode === "linear", "burning_oil_pot projectile must use a straight throw");
  const oilHit = actionByType(eventByTrigger(oilPot, "on_projectile_hit", "fire_oil_pot_projectile"), "spawn_area");
  assert(oilHit.params.area_id === "fire_oil_area", "fire_oil_pot_projectile hit must create the fire oil area");
  assert(combatObject("fire_oil_pot_projectile").visual_style === "oil_pot", "fire_oil_pot_projectile must have an oil-pot visual style");

  const acidSpray = attack("acid_spray");
  const acidArea = actionByType(eventByTrigger(acidSpray, "on_cast"), "spawn_area");
  assert(acidArea.params.area_id === "acid_spray_cone_area", "acid_spray must cast the acid cone area");
  assert(acidArea.params.position_mode === "caster", "acid_spray cone must originate from the weapon/player position");
  assert(acidArea.params.cone_width_degrees === 70 && acidArea.params.radius === 320, "acid_spray cone must preserve its base shape");

  const executor = readText("scripts/skills/skill_action_executor.gd");
  assert(executor.includes("position_mode"), "SkillActionExecutor must resolve configured area position modes");
  assert(executor.includes("curve_target_position"), "SkillActionExecutor must pass curved projectile target positions");

  const areaEffect = readText("scripts/combat/area_effect.gd");
  assert(areaEffect.includes("func _update_expanding_radius"), "AreaEffect must support expanding damage areas");
  assert(areaEffect.includes("damage_once_per_body"), "AreaEffect must support one hit per body for expanding swings");

  const projectile = readText("scripts/combat/projectile.gd");
  assert(projectile.includes('"oil_pot"'), "Projectile must draw the oil pot fallback visual");

  console.log("Primary attack shape contracts verified.");
}

main();
