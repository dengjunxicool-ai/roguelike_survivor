const fs = require("fs");
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const MARS_PARTICLE_MATERIALS = [
  ["CoreParticles", "resources/effects/mars_spark_missile_core_particles.tres"],
  ["TrailParticles", "resources/effects/mars_spark_missile_trail_particles.tres"],
  ["EmberParticles", "resources/effects/mars_spark_missile_ember_particles.tres"],
  ["SmokeParticles", "resources/effects/mars_spark_missile_smoke_particles.tres"],
];

function readText(relativePath, failures) {
  const fullPath = path.join(root, relativePath);
  if (!fs.existsSync(fullPath)) {
    failures.push(`${relativePath} must exist`);
    return "";
  }
  return readTextFile(fullPath);
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function hasStringLiteral(text, value) {
  return new RegExp(`["']${escapeRegExp(value)}["']`).test(text);
}

function collectFunctionBlocks(text) {
  const signatures = [];
  const signaturePattern = /^func\s+([A-Za-z0-9_]+)\s*\(([^)]*)\)[^\n]*:/gm;
  let match;
  while ((match = signaturePattern.exec(text)) !== null) {
    signatures.push({
      name: match[1],
      params: match[2],
      start: match.index,
      bodyStart: signaturePattern.lastIndex,
    });
  }
  return signatures.map((signature, index) => {
    const end = index + 1 < signatures.length ? signatures[index + 1].start : text.length;
    return {
      name: signature.name,
      params: signature.params,
      text: text.slice(signature.start, end),
      body: text.slice(signature.bodyStart, end),
    };
  });
}

function findFunction(functions, name) {
  return functions.find((fn) => fn.name === name);
}

function hasCallWithArgs(text, callName, args) {
  const pattern = new RegExp(`${escapeRegExp(callName)}\\s*\\(([\\s\\S]*?)\\)`, "g");
  let match;
  while ((match = pattern.exec(text)) !== null) {
    const callText = match[0];
    if (args.every((arg) => callText.includes(arg))) {
      return true;
    }
  }
  return false;
}

function hasTscnAttribute(header, name, value) {
  return new RegExp(`\\b${name}="${escapeRegExp(value)}"`).test(header);
}

function findTscnHeader(text, sectionName, predicate) {
  const headers = text.match(new RegExp(`^\\[${sectionName}[^\\]]*\\]$`, "gm")) || [];
  return headers.find(predicate) || "";
}

function extractTscnResourceId(header) {
  const match = header.match(/\bid="([^"]+)"/);
  return match ? match[1] : "";
}

function getTscnSectionBody(text, header) {
  const start = text.indexOf(header);
  if (start < 0) {
    return "";
  }
  const bodyStart = start + header.length;
  const rest = text.slice(bodyStart);
  const nextSectionOffset = rest.search(/^\[/m);
  return nextSectionOffset >= 0 ? rest.slice(0, nextSectionOffset) : rest;
}

function expectPanelContract(panel, failures) {
  const functions = collectFunctionBlocks(panel);
  const buildPanel = findFunction(functions, "_build_panel");
  const populateOptions = findFunction(functions, "_populate_options");
  const populateEffects = findFunction(functions, "_populate_effect_options");
  const dispatcher = findFunction(functions, "_trigger_selected_effect");
  const continuousCallback = findFunction(functions, "_start_continuous_effect_fire");
  const singleCallback = findFunction(functions, "_fire_single_effect");
  const marsSpawn = findFunction(functions, "_spawn_mars_spark_missile_effect");

  failures.push(...[
    [panel.includes("MARS_SPARK_MISSILE_EFFECT_SCENE"), "DevDebugPanel must preload the Mars Spark Missile effect scene"],
    [/\bvar\s+_effect_option\s*:\s*OptionButton\b/.test(panel), "DevDebugPanel must keep an _effect_option OptionButton member"],
    [Boolean(buildPanel), "DevDebugPanel must implement _build_panel()"],
    [Boolean(populateOptions), "DevDebugPanel must implement _populate_options()"],
    [Boolean(populateEffects), "DevDebugPanel must implement _populate_effect_options()"],
    [Boolean(dispatcher) && /\bcontinuous\s*:\s*bool\b/.test(dispatcher.params), "_trigger_selected_effect must accept continuous: bool"],
    [Boolean(continuousCallback), "DevDebugPanel must implement _start_continuous_effect_fire()"],
    [Boolean(singleCallback), "DevDebugPanel must implement _fire_single_effect()"],
    [Boolean(marsSpawn), "DevDebugPanel must implement _spawn_mars_spark_missile_effect()"],
  ].filter(([condition]) => !condition).map(([, message]) => message));

  if (buildPanel) {
    if (!hasCallWithArgs(buildPanel.body, "_add_category_button", ['"effects"', '"Effects"'])) {
      failures.push('DevDebugPanel must expose an Effects category button for id "effects"');
    }
    if (!hasCallWithArgs(buildPanel.body, "_add_category_page", ['"effects"', '"Effects"'])) {
      failures.push('DevDebugPanel must register an Effects page for id "effects"');
    }
    if (!buildPanel.body.includes('_add_option_row(effects_page, "Effect")')) {
      failures.push("Effects page must create the _effect_option dropdown on effects_page");
    }
    if (!hasCallWithArgs(buildPanel.body, "_add_button", ['"持续发射"', 'Callable(self, "_start_continuous_effect_fire")'])) {
      failures.push("Effects page must wire 持续发射 to _start_continuous_effect_fire");
    }
    if (!hasCallWithArgs(buildPanel.body, "_add_button", ['"单次发射"', 'Callable(self, "_fire_single_effect")'])) {
      failures.push("Effects page must wire 单次发射 to _fire_single_effect");
    }
  }

  if (populateOptions && !/_populate_effect_options\s*\(\s*\)/.test(populateOptions.body)) {
    failures.push("_populate_options() must call _populate_effect_options()");
  }

  if (populateEffects) {
    if (!hasCallWithArgs(populateEffects.body, "_add_option_item", ["_effect_option", '"Fire Tornado"', '"fire_tornado"'])) {
      failures.push("_populate_effect_options() must add Fire Tornado/fire_tornado to _effect_option");
    }
    if (!hasCallWithArgs(populateEffects.body, "_add_option_item", ["_effect_option", '"火星飞弹"', '"mars_spark_missile"'])) {
      failures.push("_populate_effect_options() must add 火星飞弹/mars_spark_missile to _effect_option");
    }
  }

  if (continuousCallback && !/_trigger_selected_effect\s*\(\s*true\s*\)/.test(continuousCallback.body)) {
    failures.push("_start_continuous_effect_fire() must call _trigger_selected_effect(true)");
  }
  if (singleCallback && !/_trigger_selected_effect\s*\(\s*false\s*\)/.test(singleCallback.body)) {
    failures.push("_fire_single_effect() must call _trigger_selected_effect(false)");
  }

  if (dispatcher) {
    if (!dispatcher.body.includes("_effect_option") || !dispatcher.body.includes("_get_selected_id")) {
      failures.push("_trigger_selected_effect() must read the selected effect id from _effect_option");
    }
    if (!dispatcher.body.includes('&"fire_tornado"') || !dispatcher.body.includes("_spawn_fire_tornado_effect()")) {
      failures.push("_trigger_selected_effect() must dispatch fire_tornado to _spawn_fire_tornado_effect()");
    }
    if (!dispatcher.body.includes('&"mars_spark_missile"') || !/_spawn_mars_spark_missile_effect\s*\(\s*continuous\s*\)/.test(dispatcher.body)) {
      failures.push("_trigger_selected_effect() must dispatch mars_spark_missile to _spawn_mars_spark_missile_effect(continuous)");
    }
  }

  if (marsSpawn) {
    if (!/MARS_SPARK_MISSILE_EFFECT_SCENE\s*\.\s*instantiate\s*\(/.test(marsSpawn.body)) {
      failures.push("_spawn_mars_spark_missile_effect() must instantiate MARS_SPARK_MISSILE_EFFECT_SCENE");
    }
    if (!/configure\s*\([^)]*\bcontinuous\b[^)]*\)/.test(marsSpawn.body) && !/set_continuous\s*\(\s*continuous\s*\)/.test(marsSpawn.body)) {
      failures.push("_spawn_mars_spark_missile_effect() must configure continuous firing mode");
    }
  }
}

function expectMarsSceneContract(scene, failures) {
  const scriptHeader = findTscnHeader(
    scene,
    "ext_resource",
    (header) =>
      hasTscnAttribute(header, "type", "Script") &&
      hasTscnAttribute(header, "path", "res://scripts/effects/mars_spark_missile_effect.gd")
  );
  if (!scriptHeader) {
    failures.push("Mars Spark Missile scene must declare its script resource");
    return;
  }
  const fireballTextureHeader = findTscnHeader(
    scene,
    "ext_resource",
    (header) =>
      hasTscnAttribute(header, "type", "Texture2D") &&
      hasTscnAttribute(header, "path", "res://assets/effect/fireball/1.png")
  );
  if (!fireballTextureHeader) {
    failures.push("Mars Spark Missile scene must declare fireball texture asset res://assets/effect/fireball/1.png");
  }
  const fireballTextureId = fireballTextureHeader ? extractTscnResourceId(fireballTextureHeader) : "";
  const scriptId = extractTscnResourceId(scriptHeader);
  const rootHeader = findTscnHeader(
    scene,
    "node",
    (header) =>
      hasTscnAttribute(header, "name", "MarsSparkMissileEffect") &&
      hasTscnAttribute(header, "type", "Node2D") &&
      !/\bparent=/.test(header)
  );
  if (!rootHeader) {
    failures.push("Mars Spark Missile scene root must be Node2D named MarsSparkMissileEffect");
  } else {
    const rootBody = getTscnSectionBody(scene, rootHeader);
    if (!new RegExp(`^script\\s*=\\s*ExtResource\\("${escapeRegExp(scriptId)}"\\)`, "m").test(rootBody)) {
      failures.push("Mars Spark Missile scene root must attach MarsSparkMissileEffect script");
    }
  }
  const coreFireballHeader = findTscnHeader(
    scene,
    "node",
    (header) =>
      hasTscnAttribute(header, "name", "CoreFireball") &&
      hasTscnAttribute(header, "type", "Sprite2D") &&
      hasTscnAttribute(header, "parent", ".")
  );
  if (!coreFireballHeader) {
    failures.push("Mars Spark Missile scene must place a CoreFireball Sprite2D at the CoreParticles origin");
  } else {
    const coreFireballBody = getTscnSectionBody(scene, coreFireballHeader);
    if (fireballTextureId && !new RegExp(`^texture\\s*=\\s*ExtResource\\("${escapeRegExp(fireballTextureId)}"\\)`, "m").test(coreFireballBody)) {
      failures.push("CoreFireball Sprite2D must use assets/effect/fireball/1.png");
    }
    if (/^position\s*=\s*Vector2\((?!0(?:\.0+)?, 0(?:\.0+)?\))/m.test(coreFireballBody)) {
      failures.push("CoreFireball Sprite2D must stay at the CoreParticles origin");
    }
  }
  for (const [nodeName, materialPath] of MARS_PARTICLE_MATERIALS) {
    const materialHeader = findTscnHeader(
      scene,
      "ext_resource",
      (header) =>
        (hasTscnAttribute(header, "type", "ParticleProcessMaterial") || hasTscnAttribute(header, "type", "Material")) &&
        hasTscnAttribute(header, "path", `res://${materialPath}`)
    );
    if (!materialHeader) {
      failures.push(`Mars Spark Missile scene must declare editor material resource ${materialPath}`);
      continue;
    }
    const materialId = extractTscnResourceId(materialHeader);
    const nodeHeader = findTscnHeader(scene, "node", (header) => hasTscnAttribute(header, "name", nodeName) && hasTscnAttribute(header, "type", "GPUParticles2D"));
    if (!nodeHeader) {
      failures.push(`Mars Spark Missile scene must include GPUParticles2D ${nodeName}`);
      continue;
    }
    const nodeBody = getTscnSectionBody(scene, nodeHeader);
    if (/^visible\s*=\s*false\s*$/m.test(nodeBody)) {
      failures.push(`Mars Spark Missile ${nodeName} must remain visible in the editor scene`);
    }
    if (nodeName === "CoreParticles" && /^texture\s*=/m.test(nodeBody)) {
      failures.push("CoreParticles must not use the full fireball texture for every particle; CoreFireball Sprite2D owns the fireball image");
    }
    if (!new RegExp(`^process_material\\s*=\\s*ExtResource\\("${escapeRegExp(materialId)}"\\)`, "m").test(nodeBody)) {
      failures.push(`Mars Spark Missile ${nodeName} must use ${materialPath} as process_material`);
    }
  }
  if ((scene.match(/type="GPUParticles2D"/g) || []).length < 3) {
    failures.push("Mars Spark Missile scene must use at least three GPUParticles2D nodes");
  }
  if (scene.includes("CPUParticles2D")) {
    failures.push("Mars Spark Missile scene must not use CPUParticles2D");
  }
}

function expectMarsScriptContract(script, failures) {
  if (!script.includes("class_name MarsSparkMissileEffect")) {
    failures.push("Mars Spark Missile script must declare class_name MarsSparkMissileEffect");
  }
  for (const methodName of ["configure", "set_continuous", "_spawn_missile"]) {
    if (!script.includes(`func ${methodName}(`)) {
      failures.push(`Mars Spark Missile script must implement ${methodName}()`);
    }
  }
  if (!script.includes("GPUParticles2D")) {
    failures.push("Mars Spark Missile script must use GPUParticles2D");
  }
  if (!/@export var homing_enabled: bool = true/.test(script)) {
    failures.push("Mars Spark Missile script must expose homing_enabled for dev tuning");
  }
  if (!/@export var target_group: StringName = &"enemies"/.test(script)) {
    failures.push("Mars Spark Missile script must expose target_group for enemy homing");
  }
  if (!script.includes("get_nodes_in_group(target_group)")) {
    failures.push("Mars Spark Missile script must search its configurable target_group when homing");
  }
  if (script.includes("ParticleProcessMaterial.new()") || /process_material\s*=/.test(script)) {
    failures.push("Mars Spark Missile script must not create or assign particle materials; edit them in .tres resources");
  }
  if (script.includes("CPUParticles2D")) {
    failures.push("Mars Spark Missile script must not use CPUParticles2D");
  }
  if (!script.includes("queue_free()")) {
    failures.push("Mars Spark Missile script must clean itself up with queue_free()");
  }
}

function expectMarsMaterialContract(materialPath, material, failures) {
  if (!material.includes('[gd_resource type="ParticleProcessMaterial"')) {
    failures.push(`${materialPath} must be a ParticleProcessMaterial resource`);
  }
  for (const propertyName of [
    "emission_shape",
    "emission_sphere_radius",
    "direction",
    "spread",
    "gravity",
    "initial_velocity_min",
    "initial_velocity_max",
    "scale_max",
  ]) {
    if (!new RegExp(`^${propertyName}\\s*=`, "m").test(material)) {
      failures.push(`${materialPath} must expose ${propertyName} for editor tuning`);
    }
  }
  if (!/^color\s*=/m.test(material) && !/^color_ramp\s*=/m.test(material)) {
    failures.push(`${materialPath} must expose color or color_ramp for editor tuning`);
  }
  if (materialPath.endsWith("mars_spark_missile_trail_particles.tres")) {
    const scaleMax = readNumericResourceProperty(material, "scale_max");
    const velocityMax = readNumericResourceProperty(material, "initial_velocity_max");
    const dampingMax = readNumericResourceProperty(material, "damping_max");
    if (!Number.isFinite(scaleMax) || scaleMax < 0.9) {
      failures.push(`${materialPath} trail scale_max must stay large enough for the default particle to remain visible`);
    }
    if (!Number.isFinite(velocityMax) || velocityMax < 110.0) {
      failures.push(`${materialPath} trail initial_velocity_max must be high enough to draw a readable tail`);
    }
    if (!Number.isFinite(dampingMax) || dampingMax > 48.0) {
      failures.push(`${materialPath} trail damping_max must not collapse the tail range`);
    }
  }
}

function readNumericResourceProperty(text, propertyName) {
  const match = text.match(new RegExp(`^${propertyName}\\s*=\\s*([-+0-9.]+)`, "m"));
  return match ? Number(match[1]) : NaN;
}

function main() {
  const failures = [];
  const panel = readText("scripts/debug/dev_debug_panel.gd", failures);
  const scene = readText("scenes/effects/mars_spark_missile_effect.tscn", failures);
  const script = readText("scripts/effects/mars_spark_missile_effect.gd", failures);
  const materials = MARS_PARTICLE_MATERIALS.map(([, materialPath]) => [
    materialPath,
    readText(materialPath, failures),
  ]);

  if (panel) {
    expectPanelContract(panel, failures);
  }
  if (scene) {
    expectMarsSceneContract(scene, failures);
  }
  if (script) {
    expectMarsScriptContract(script, failures);
  }
  for (const [materialPath, material] of materials) {
    if (material) {
      expectMarsMaterialContract(materialPath, material, failures);
    }
  }

  if (failures.length > 0) {
    console.error("Dev effects panel VFX verification failed:");
    for (const failure of failures) {
      console.error(`- ${failure}`);
    }
    process.exit(1);
  }
  console.log("Dev effects panel VFX verified.");
}

main();
