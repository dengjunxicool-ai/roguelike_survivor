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

  if (isValidTargetBody === "") {
    errors.push("TargetingService public is_valid_target must exist.");
  } else if (!isValidTargetBody.includes("_is_valid_enemy(")) {
    errors.push("TargetingService.is_valid_target must reuse _is_valid_enemy.");
  }

  if (isValidEnemyBody === "") {
    errors.push("TargetingService._is_valid_enemy must exist.");
    return errors;
  }

  for (const requiredToken of ["is_queued_for_deletion", "current_health", "get_runtime_state", "_is_dead"]) {
    if (!isValidEnemyBody.includes(requiredToken)) {
      errors.push(`TargetingService._is_valid_enemy must check ${requiredToken}.`);
    }
  }

  if (!/get_runtime_state[\s\S]*==\s*"dead"/.test(isValidEnemyBody)) {
    errors.push('TargetingService._is_valid_enemy must reject get_runtime_state() == "dead".');
  }

  if (!/current_health[\s\S]*<=\s*0/.test(isValidEnemyBody)) {
    errors.push("TargetingService._is_valid_enemy must reject current_health <= 0.");
  }

  return errors;
}

function validateSkillActionExecutor(text) {
  const errors = [];
  const contextBody = extractGdFunctionBody(text, /^func\s+_context_with_resolved_target\s*\(/m);

  if (contextBody === "") {
    return ["SkillActionExecutor._context_with_resolved_target must exist."];
  }

  if (!contextBody.includes("TargetingServiceScript.is_valid_target(target_2d)")) {
    errors.push("_context_with_resolved_target must validate the Node2D target through TargetingServiceScript.is_valid_target.");
  }

  if (!/if\s+not\s+force_configured_targeting\s+and\s+target\s*!=\s*null\s+and\s+\(target_2d\s*==\s*null\s+or\s+TargetingServiceScript\.is_valid_target\(target_2d\)\):\s*\n\s*return context/.test(contextBody)) {
    errors.push("_context_with_resolved_target must keep live implicit targets without retargeting.");
  }

  if (/not\s+target\.is_queued_for_deletion\s*\(/.test(contextBody)) {
    errors.push("_context_with_resolved_target must not keep the old not target.is_queued_for_deletion() retention logic.");
  }

  if (!contextBody.includes("_resolve_action_target(params, context)")) {
    errors.push("_context_with_resolved_target must resolve a replacement target with _resolve_action_target(params, context).");
  }

  if (!contextBody.includes('resolved_context["target"] = resolved_target')) {
    errors.push('_context_with_resolved_target must write resolved_context["target"].');
  }

  if (!contextBody.includes('resolved_context["enemy"] = resolved_target')) {
    errors.push('_context_with_resolved_target must write resolved_context["enemy"].');
  }

  const staleClearPattern =
    /if\s+resolved_target\s*==\s*null:\s*\n\s*if\s+[^\n]*(?:has_invalid_target_reference|has_invalid_enemy_reference)[^\n]*:\s*[\s\S]*?cleared_context\.erase\("target"\)[\s\S]*?cleared_context\.erase\("enemy"\)[\s\S]*?return cleared_context[\s\S]*?return context/;
  if (!staleClearPattern.test(contextBody)) {
    errors.push("_context_with_resolved_target must clear stale target/enemy when an invalid target has no replacement.");
  }

  return errors;
}

function main() {
  const targetingService = readProjectFile("scripts/skills/targeting_service.gd");
  const skillActionExecutor = readProjectFile("scripts/skills/skill_action_executor.gd");
  const errors = [
    ...validateTargetingService(targetingService),
    ...validateSkillActionExecutor(skillActionExecutor),
  ];

  if (errors.length > 0) {
    console.error("verify_skill_retarget_dead_target: FAIL");
    for (const error of errors) {
      console.error(`- ${error}`);
    }
    process.exit(1);
  }

  console.log("verify_skill_retarget_dead_target: PASS");
}

if (require.main === module) {
  main();
}

module.exports = {
  extractGdFunctionBody,
  validateSkillActionExecutor,
  validateTargetingService,
};
