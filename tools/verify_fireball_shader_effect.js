const fs = require("fs");
const path = require("path");
const { readJsonFile, readTextFile } = require("./lib/json_file");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertFile(relativePath) {
  assert(fs.existsSync(path.join(root, relativePath)), `Missing ${relativePath}`);
}

assertFile("assets/effect/fireball/core.png");
assertFile("resources/effects/fireball_flying_shader.gdshader");
assertFile("resources/effects/fireball_flying_material.tres");

const shader = read("resources/effects/fireball_flying_shader.gdshader");
for (const uniformName of [
  "glow_strength",
  "distort_strength",
  "distort_speed",
  "trail_intensity",
  "edge_softness",
  "color_hot",
  "color_rim",
]) {
  assert(shader.includes(`uniform`) && shader.includes(uniformName), `Shader must expose ${uniformName}`);
}
assert(shader.includes("shader_type canvas_item"), "Shader must be a canvas_item shader");
assert(shader.includes("TIME * distort_speed"), "Shader must animate UV distortion with TIME");
assert(shader.includes("smoothstep(0.0, 1.0, uv.x)") || shader.includes("smoothstep(0.0,1.0,uv.x)"), "Shader must stretch glow/trail along forward UV");
const fragmentBody = shader.slice(shader.indexOf("void fragment()"));
assert(!/\breturn\s*;/.test(fragmentBody), "Canvas item fragment shader must not use return; Godot rejects return in fragment().");
assert(!/\bvec[234]\s+source_color\b/.test(fragmentBody), "Canvas item fragment shader must not use source_color as a local variable name; Godot treats source_color as a shader hint keyword.");

const material = read("resources/effects/fireball_flying_material.tres");
assert(material.includes("fireball_flying_shader.gdshader"), "ShaderMaterial must use fireball_flying_shader.gdshader");
assert(shader.includes("tex.rgb"), "Shader must preserve the source fireball texture colors instead of recoloring from red only");
assert(shader.includes("source_luma"), "Shader must derive glow from source luminance for bright yellow-white cores");
assert(material.includes("shader_parameter/glow_strength = 2.6"), "Material must set glow_strength = 2.6 for a brighter natural fireball");
assert(material.includes("shader_parameter/distort_strength = 0.03"), "Material must set distort_strength = 0.03");
assert(material.includes("shader_parameter/distort_speed = 2.0"), "Material must set distort_speed = 2.0");
assert(material.includes("shader_parameter/trail_intensity = 0.85"), "Material must set trail_intensity = 0.85");
assert(material.includes("shader_parameter/edge_softness = 0.12"), "Material must set edge_softness = 0.12");
assert(material.includes("shader_parameter/color_hot = Color(1, 0.92, 0.35, 1)"), "Material must use a brighter yellow-white hot color");
assert(material.includes("shader_parameter/color_rim = Color(1, 0.48, 0.08, 1)"), "Material must use a warmer orange rim color");

const combatObjects = readJsonFile(path.join(root, "data", "combat_objects.json")).combat_objects || [];
const fireball = combatObjects.find((object) => object.id === "fireball_projectile");
assert(fireball, "fireball_projectile must exist");
assert(fireball.visual?.texture === "res://assets/effect/fireball/core.png", "fireball_projectile must use core.png texture");
assert(fireball.visual?.material === "res://resources/effects/fireball_flying_material.tres", "fireball_projectile must use fireball_flying_material.tres");
assert(!fireball.visual?.sprite_frames, "fireball_projectile shader effect must use the static texture path, not sprite_frames");
assert(fireball.visual?.rotation_degrees === -42, "fireball_projectile visual must counter-rotate the angled source art so it follows the projectile direction horizontally");

const visualApplier = read("scripts/visual/visual_config_applier.gd");
assert(visualApplier.includes('"material"'), "VisualConfigApplier must read visual.material");
assert(visualApplier.includes("load(material_path)"), "VisualConfigApplier must load configured material paths");
assert(visualApplier.includes("item.material"), "VisualConfigApplier must assign the material to the CanvasItem");

console.log("Fireball shader effect verified.");
