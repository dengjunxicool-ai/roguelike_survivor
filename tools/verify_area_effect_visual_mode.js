const path = require("path");
const { readTextFile } = require("./lib/json_file");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function readJson(relativePath) {
  return JSON.parse(read(relativePath));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const factory = read("scripts/combat/combat_object_factory.gd");
assert(factory.includes('"visual_style", "visual_color", "visual_ring_color", "visual_mode"'), "CombatObjectFactory must merge visual_mode from combat object definitions");

const areaEffect = read("scripts/combat/area_effect.gd");
assert(areaEffect.includes("var _visual_mode: String"), "AreaEffect must store visual_mode");
assert(areaEffect.includes('_visual_mode = String(params.get("visual_mode"'), "AreaEffect.setup must read visual_mode from params");
assert(areaEffect.includes('if _visual_mode == "asset":') && areaEffect.includes("return false"), "AreaEffect must let asset mode use configured visual resources instead of programmatic drawing");

const combatObjects = readJson("data/combat_objects.json").combat_objects || [];
const genericExplosion = combatObjects.find((object) => object.id === "generic_explosion_area");
assert(genericExplosion, "generic_explosion_area must exist");
assert(genericExplosion.visual_mode === "programmatic", "generic_explosion_area must declare programmatic fallback mode explicitly");
assert(genericExplosion.visual && typeof genericExplosion.visual === "object", "generic_explosion_area must keep replaceable visual asset config");

console.log("Area effect visual mode verified.");
