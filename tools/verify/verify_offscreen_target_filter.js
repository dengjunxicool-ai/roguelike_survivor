const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function readProjectFile(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function extractGdFunctionBody(text, signaturePattern) {
  const match = signaturePattern.exec(text);
  if (!match) return "";

  const bodyStart = text.indexOf("\n", match.index);
  if (bodyStart < 0) return "";

  const rest = text.slice(bodyStart + 1);
  const nextFunction = rest.search(/^(?:static\s+)?func\s+/m);
  return nextFunction >= 0 ? rest.slice(0, nextFunction) : rest;
}

function validateTargetingService(text) {
  const errors = [];
  const isValidTargetBody = extractGdFunctionBody(text, /^static\s+func\s+is_valid_target\s*\(/m);
  const isValidEnemyBody = extractGdFunctionBody(text, /^static\s+func\s+_is_valid_enemy\s*\(/m);
  const cameraVisibilityBody = extractGdFunctionBody(text, /^static\s+func\s+_is_enemy_inside_active_camera_view\s*\(/m);

  if (isValidTargetBody === "") {
    errors.push("TargetingService.is_valid_target must exist.");
  } else if (!isValidTargetBody.includes("_is_valid_enemy(")) {
    errors.push("TargetingService.is_valid_target must reuse _is_valid_enemy.");
  }

  if (isValidEnemyBody === "") {
    errors.push("TargetingService._is_valid_enemy must exist.");
  } else {
    for (const token of ["is_queued_for_deletion", "current_health", "get_runtime_state", "_is_dead"]) {
      if (!isValidEnemyBody.includes(token)) {
        errors.push(`TargetingService._is_valid_enemy must keep ${token} validity check.`);
      }
    }
    if (!isValidEnemyBody.includes("_is_enemy_inside_active_camera_view(enemy)")) {
      errors.push("TargetingService._is_valid_enemy must reject enemies outside the active camera view.");
    }
  }

  if (cameraVisibilityBody === "") {
    errors.push("TargetingService._is_enemy_inside_active_camera_view must exist.");
  } else {
    for (const token of [
      "Engine.get_main_loop",
      "tree.root",
      "get_camera_2d",
      "get_visible_rect",
      "camera.zoom.abs",
      "get_screen_center_position",
      "enemy.global_position",
      "Rect2",
      "has_point",
    ]) {
      if (!cameraVisibilityBody.includes(token)) {
        errors.push(`TargetingService camera visibility helper must use ${token}.`);
      }
    }
    if (!/camera\s*==\s*null[\s\S]*return true/.test(cameraVisibilityBody)) {
      errors.push("TargetingService camera visibility helper must allow targets when no active camera exists.");
    }
  }

  return errors;
}

function validateProjectile(text) {
  const errors = [];
  const nearestBody = extractGdFunctionBody(text, /^func\s+_find_nearest_homing_target\s*\(/m);
  const sweptBody = extractGdFunctionBody(text, /^func\s+_resolve_swept_homing_hit\s*\(/m);
  const validBody = extractGdFunctionBody(text, /^func\s+_is_valid_homing_target\s*\(/m);

  if (!text.includes('preload("res://scripts/skills/targeting_service.gd")')) {
    errors.push("Projectile must preload TargetingService.");
  }

  if (nearestBody === "") {
    errors.push("Projectile._find_nearest_homing_target must exist.");
  } else if (!nearestBody.includes("_is_valid_homing_target(target)")) {
    errors.push("Projectile._find_nearest_homing_target must reuse _is_valid_homing_target.");
  }

  if (sweptBody === "") {
    errors.push("Projectile._resolve_swept_homing_hit must exist.");
  } else if (!sweptBody.includes("_is_valid_homing_target(target)")) {
    errors.push("Projectile._resolve_swept_homing_hit must reuse _is_valid_homing_target.");
  }

  if (validBody === "") {
    errors.push("Projectile._is_valid_homing_target must exist.");
  } else if (!validBody.includes("TargetingServiceScript.is_valid_target(target)")) {
    errors.push("Projectile._is_valid_homing_target must use TargetingServiceScript.is_valid_target(target).");
  }

  return errors;
}

function main() {
  const targetingService = readProjectFile("scripts/skills/targeting_service.gd");
  const projectile = readProjectFile("scripts/combat/projectile.gd");
  const errors = [
    ...validateTargetingService(targetingService),
    ...validateProjectile(projectile),
  ];

  if (errors.length > 0) {
    console.error("verify_offscreen_target_filter: FAIL");
    for (const error of errors) {
      console.error(`- ${error}`);
    }
    process.exit(1);
  }

  console.log("verify_offscreen_target_filter: PASS");
}

if (require.main === module) {
  main();
}
