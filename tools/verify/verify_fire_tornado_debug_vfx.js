const fs = require("fs");
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function readText(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function hasTscnAttribute(header, name, value) {
  return new RegExp(`\\b${name}="${escapeRegExp(value)}"`).test(header);
}

function findTscnHeader(text, sectionName, predicate) {
  const headers = text.match(new RegExp(`^\\[${sectionName}[^\\]]*\\]$`, "gm")) || [];
  return headers.find(predicate) || "";
}

function getTscnSectionBody(text, header) {
  const start = text.indexOf(header);
  assert(start >= 0, `section ${header} must exist`);

  const bodyStart = start + header.length;
  const rest = text.slice(bodyStart);
  const nextSectionOffset = rest.search(/^\[/m);
  return nextSectionOffset >= 0 ? rest.slice(0, nextSectionOffset) : rest;
}

function extractTscnResourceId(header) {
  const match = header.match(/\bid="([^"]+)"/);
  return match ? match[1] : "";
}

function extractGdFunctionBody(text, signature) {
  const signatureIndex = text.indexOf(signature);
  assert(signatureIndex >= 0, `${signature} must exist`);

  const bodyStart = text.indexOf("\n", signatureIndex);
  if (bodyStart < 0) {
    return "";
  }

  const rest = text.slice(bodyStart + 1);
  const nextTopLevelFunctionOffset = rest.search(/^func\s+/m);
  return nextTopLevelFunctionOffset >= 0 ? rest.slice(0, nextTopLevelFunctionOffset) : rest;
}

function main() {
  const scenePath = path.join(root, "scenes/effects/fire_tornado_effect.tscn");
  const scriptPath = path.join(root, "scripts/effects/fire_tornado_effect.gd");
  const debugPanelPath = path.join(root, "scripts/debug/dev_debug_panel.gd");
  assert(fs.existsSync(scenePath), "fire tornado effect scene must exist");
  assert(fs.existsSync(scriptPath), "fire tornado effect script must exist");

  const scene = readText("scenes/effects/fire_tornado_effect.tscn");
  const scriptResourceHeader = findTscnHeader(
    scene,
    "ext_resource",
    (header) =>
      hasTscnAttribute(header, "type", "Script") &&
      hasTscnAttribute(header, "path", "res://scripts/effects/fire_tornado_effect.gd")
  );
  assert(scriptResourceHeader, "scene must declare FireTornadoEffect script resource");
  const scriptResourceId = extractTscnResourceId(scriptResourceHeader);
  assert(scriptResourceId, "FireTornadoEffect script resource must have an id");

  const rootNodeHeader = findTscnHeader(
    scene,
    "node",
    (header) =>
      hasTscnAttribute(header, "name", "FireTornadoEffect") &&
      hasTscnAttribute(header, "type", "Node2D") &&
      !/\bparent=/.test(header)
  );
  assert(rootNodeHeader, "scene root must be a Node2D named FireTornadoEffect");
  const rootNodeBody = getTscnSectionBody(scene, rootNodeHeader);
  assert(
    new RegExp(`^script\\s*=\\s*ExtResource\\("${escapeRegExp(scriptResourceId)}"\\)`, "m").test(rootNodeBody),
    "scene root must attach FireTornadoEffect script"
  );

  for (const nodeName of ["HeatCore", "BaseFireRing", "SpiralEmitterA", "SpiralEmitterB", "EmberSpray", "SmokeWisps", "OuterEmbers"]) {
    assert(scene.includes(`name="${nodeName}"`), `scene must include ${nodeName}`);
  }
  assert((scene.match(/type="GPUParticles2D"/g) || []).length >= 6, "scene must use at least six GPUParticles2D nodes");
  assert(!scene.includes("CPUParticles2D"), "scene must not use CPUParticles2D nodes");
  assert(!scene.includes("visibility_rect"), "GPUParticles2D scene nodes must not serialize unsupported visibility_rect");

  const script = readText("scripts/effects/fire_tornado_effect.gd");
  assert(script.includes("class_name FireTornadoEffect"), "script must declare FireTornadoEffect");
  assert(script.includes("@export_range(0.1, 30.0"), "script must expose a bounded lifetime export");
  assert(script.includes("func _process(delta: float) -> void:"), "script must animate and expire in _process");
  assert(script.includes("queue_free()"), "script must auto-clean with queue_free");
  assert(script.includes("_configure_particles("), "script must configure particle emitters");
  assert(script.includes("_update_spiral_emitters("), "script must animate spiral emitter positions");
  for (const methodName of [
    "_get_growth_alpha",
    "_get_dissolve_alpha",
    "_get_gif_loop_alpha",
    "_draw_gif_base_ember_ring",
    "_draw_smooth_fire_column",
    "_draw_dissolve_ash_cloud",
    "_draw_tornado_body",
    "_draw_spiral_fire_ribbons",
    "_draw_base_eruption",
    "_draw_smoke_wisps",
    "_draw_ember_streaks",
  ]) {
    assert(script.includes(`func ${methodName}(`), `FireTornadoEffect must implement ${methodName}`);
  }
  assert(script.includes("smoothstep(0.0, 0.22"), "FireTornadoEffect must ease in from a dark ember base like the GIF");
  assert(script.includes("smoothstep(0.72, 1.0"), "FireTornadoEffect must dissolve into embers and smoke like the GIF");
  assert(script.includes("Color(0.015, 0.010, 0.006"), "FireTornadoEffect must add a near-black smoke veil for the GIF-style dark field");
  assert(script.includes("Color(1.0, 0.18, 0.025"), "FireTornadoEffect must retune fire toward darker red-orange ribbons");
  assert(!script.includes("GroundShadowScript"), "FireTornadoEffect must not add an oblique ground shadow in top-down mode");
  assert(!script.includes("oblique_ground_flatten"), "FireTornadoEffect must not expose oblique ground flattening in top-down mode");
  assert(!script.includes("oblique_column_scale"), "FireTornadoEffect must not compress the tornado column for an oblique view");
  assert(!script.includes("_project_ground"), "FireTornadoEffect must not project points onto an oblique ground");
  assert(!script.includes("_project_column"), "FireTornadoEffect must not project the tornado column for an oblique view");
  assert(script.includes("GPUParticles2D"), "FireTornadoEffect must configure GPUParticles2D emitters");
  assert(!script.includes("CPUParticles2D"), "FireTornadoEffect must not reference CPUParticles2D");
  assert(!script.includes(".visibility_rect"), "FireTornadoEffect must not assign unsupported GPUParticles2D.visibility_rect");

  assert(fs.existsSync(debugPanelPath), "debug panel script must exist");
  const debugPanel = readText("scripts/debug/dev_debug_panel.gd");
  assert(debugPanel.includes("FIRE_TORNADO_EFFECT_SCENE"), "debug panel must preload the fire tornado scene");
  assert(debugPanel.includes('"Fire Tornado"'), "debug panel must expose a Fire Tornado button");
  assert(debugPanel.includes("func _spawn_fire_tornado_effect() -> void:"), "debug panel must implement fire tornado spawning");
  const resolveSpawnSignature = "func _resolve_fire_tornado_spawn_position(player: Node2D) -> Vector2:";
  const resolveSpawnBody = extractGdFunctionBody(debugPanel, resolveSpawnSignature);
  assert(resolveSpawnBody.includes("_get_nearest_enemy()"), "spawn position must use nearest enemy direction when available");

  console.log("Fire tornado debug VFX verified.");
}

main();
