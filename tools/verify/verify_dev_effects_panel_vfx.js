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

function expectPanelContract(panel, effectsPage, failures) {
  const functions = collectFunctionBlocks(panel);
  const pageFunctions = collectFunctionBlocks(effectsPage);
  const buildPanel = findFunction(functions, "_build_panel");
  const categoryNavigation = findFunction(functions, "_add_category_navigation");
  const buildEffectsPage = findFunction(functions, "_build_effects_page");
  const populateOptions = findFunction(functions, "_populate_options");

  failures.push(...[
    [/\bvar\s+_effect_option\s*:\s*OptionButton\b/.test(panel), "DevDebugPanel must keep an _effect_option OptionButton compatibility alias"],
    [/\bvar\s+_effects_page\s*:\s*VBoxContainer\b/.test(panel), "DevDebugPanel must keep the mounted Effects page"],
    [Boolean(buildPanel), "DevDebugPanel must implement _build_panel()"],
    [Boolean(populateOptions), "DevDebugPanel must implement _populate_options()"],
    [Boolean(buildEffectsPage), "DevDebugPanel must implement _build_effects_page()"],
    [effectsPage.includes("MARS_SPARK_MISSILE_EFFECT_SCENE"), "DevDebugEffectsPage must preload the Mars Spark Missile effect scene"],
  ].filter(([condition]) => !condition).map(([, message]) => message));

  if (buildPanel) {
    const categoryNavigationBody = categoryNavigation ? categoryNavigation.body : buildPanel.body;
    if (!hasCallWithArgs(categoryNavigationBody, "_add_category_button", ['"effects"', '"Effects"'])) {
      failures.push('DevDebugPanel must expose an Effects category button for id "effects"');
    }
  }
  if (buildEffectsPage) {
    if (!hasCallWithArgs(buildEffectsPage.body, "_add_category_page", ['"effects"', '"Effects"'])) {
      failures.push('DevDebugPanel must register an Effects page for id "effects"');
    }
    for (const required of [
      "DevDebugEffectsPageScript.new()",
      'Callable(self, "_get_player")',
      'Callable(self, "_get_nearest_enemy")',
      'call("get_effect_option")',
    ]) {
      if (!buildEffectsPage.body.includes(required)) {
        failures.push(`DevDebugPanel _build_effects_page() must include ${required}`);
      }
    }
  }
  if (populateOptions && !/_populate_effect_options\s*\(\s*\)/.test(populateOptions.body)) {
    failures.push("_populate_options() must call _populate_effect_options()");
  }

  const delegates = [
    ["_populate_effect_options", "populate_options"],
    ["_start_continuous_effect_fire", "start_continuous_effect"],
    ["_fire_single_effect", "fire_single_effect"],
    ["_trigger_selected_effect", "trigger_selected_effect"],
    ["_spawn_mars_spark_missile_effect", "spawn_mars_spark_missile_effect"],
  ];
  for (const [panelMethod, pageMethod] of delegates) {
    const fn = findFunction(functions, panelMethod);
    if (!fn || !fn.body.includes(`_effects_page.call("${pageMethod}"`)) {
      failures.push(`DevDebugPanel ${panelMethod}() must delegate to ${pageMethod}()`);
    }
  }

  const pageBuild = findFunction(pageFunctions, "build");
  const pagePopulate = findFunction(pageFunctions, "populate_options");
  const pageDispatch = findFunction(pageFunctions, "trigger_selected_effect");
  const pageMarsSpawn = findFunction(pageFunctions, "spawn_mars_spark_missile_effect");
  if (!pageBuild || !pageBuild.body.includes('"持续发射"') || !pageBuild.body.includes('Callable(self, "start_continuous_effect")')) {
    failures.push("DevDebugEffectsPage must wire 持续发射 to start_continuous_effect");
  }
  if (!pageBuild || !pageBuild.body.includes('"单次发射"') || !pageBuild.body.includes('Callable(self, "fire_single_effect")')) {
    failures.push("DevDebugEffectsPage must wire 单次发射 to fire_single_effect");
  }
  if (!pagePopulate || !hasCallWithArgs(pagePopulate.body, "_add_option_item", ['"Fire Tornado"', '"fire_tornado"'])) {
    failures.push("DevDebugEffectsPage must expose Fire Tornado/fire_tornado");
  }
  if (!pagePopulate || !hasCallWithArgs(pagePopulate.body, "_add_option_item", ['"火星飞弹"', '"mars_spark_missile"'])) {
    failures.push("DevDebugEffectsPage must expose 火星飞弹/mars_spark_missile");
  }
  if (!pageDispatch || !pageDispatch.body.includes('&"fire_tornado"') || !pageDispatch.body.includes("spawn_fire_tornado_effect()")) {
    failures.push("DevDebugEffectsPage must dispatch the selected Fire Tornado effect");
  }
  if (!pageDispatch || !pageDispatch.body.includes('&"mars_spark_missile"') || !pageDispatch.body.includes("spawn_mars_spark_missile_effect(continuous)")) {
    failures.push("DevDebugEffectsPage must dispatch the selected Mars effect");
  }
  if (!pageMarsSpawn || !/MARS_SPARK_MISSILE_EFFECT_SCENE\s*\.\s*instantiate\s*\(/.test(pageMarsSpawn.body)) {
    failures.push("DevDebugEffectsPage must instantiate MARS_SPARK_MISSILE_EFFECT_SCENE");
  }
  if (!pageMarsSpawn || !/set_continuous\s*\(\s*continuous\s*\)/.test(pageMarsSpawn.body)) {
    failures.push("DevDebugEffectsPage must configure continuous firing mode");
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
  if (!script.includes("CombatTargetRegistryScript.get_or_create(self)") || !script.includes('get_targets_in_radius", global_position, seek_range, target_group')) {
    failures.push("Mars Spark Missile script must query CombatTargetRegistry with its configurable target_group when homing");
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
  const effectsPage = readText("scripts/debug/pages/dev_debug_effects_page.gd", failures);
  const scene = readText("scenes/effects/mars_spark_missile_effect.tscn", failures);
  const script = readText("scripts/effects/mars_spark_missile_effect.gd", failures);
  const materials = MARS_PARTICLE_MATERIALS.map(([, materialPath]) => [
    materialPath,
    readText(materialPath, failures),
  ]);

  if (panel && effectsPage) {
    expectPanelContract(panel, effectsPage, failures);
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
