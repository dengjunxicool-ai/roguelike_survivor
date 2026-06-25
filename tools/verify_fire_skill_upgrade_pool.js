const fs = require("fs");
const path = require("path");
const { readJsonFile, stripBom } = require("./json_file");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return stripBom(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function bodyOf(source, functionName) {
  const marker = `func ${functionName}`;
  const start = source.indexOf(marker);
  if (start < 0) return "";
  const next = source.indexOf("\nfunc ", start + marker.length);
  return source.slice(start, next < 0 ? source.length : next);
}

const skillsDocument = readJsonFile(path.join(root, "data", "skills.json"));
const upgradePool = read("scripts/upgrades/upgrade_pool.gd");
const playerController = read("scripts/player/player_controller.gd");
const skillManager = read("scripts/skills/skill_manager.gd");
const skillEventBus = read("scripts/skills/skill_event_bus.gd");
const gameData = read("scripts/game/game_data.gd");
const playerAbsorbStage = read("scripts/combat/application_stages/player_absorb_application_stage.gd");
const fireSkillRuntimePath = path.join(root, "scripts", "skills", "fire_skill_runtime.gd");
const addSkillBody = bodyOf(skillManager, "add_skill");

const fireSkills = (skillsDocument.skills || []).filter(
  (skill) => skill && skill.god_id === "fire" && skill.offer_in_upgrade_pool === true
);

assert(fireSkills.length === 60, `expected 60 fire learnable skill-card sources, got ${fireSkills.length}`);
for (const skill of fireSkills) {
  assert(typeof skill.id === "string" && skill.id.trim() !== "", "fire skill source must have an id");
  assert(["active", "passive"].includes(skill.category), `${skill.id} must be an active or passive learnable skill`);
}

const growthBody = bodyOf(upgradePool, "_select_growth_stage_options");
const formalBuilderBody = bodyOf(upgradePool, "_build_god_skill_learn_options");
const debugBuilderBody = bodyOf(upgradePool, "generate_debug_fire_skill_options");

assert(formalBuilderBody, "UpgradePool must define a non-debug god learn option builder");
assert(growthBody.includes("_build_god_skill_learn_options(player)"), "generate_options growth stage must include god learn skill cards");
assert(!formalBuilderBody.includes("debug_learn_"), "formal god learn options must not use debug learn ids");
assert(!formalBuilderBody.includes("_make_debug_learn_skill_upgrade"), "formal god learn options must not depend on debug-only synthesis");
assert(debugBuilderBody && debugBuilderBody.includes("generate_debug_fire_skill_options"), "debug fire skill options should remain separate");
assert(formalBuilderBody.includes("_get_debug_god_skill_definitions(god_id)"), "formal god learn options must read data/skills.json dynamically");
assert(!formalBuilderBody.includes("mars_spark_missile_projectile"), "formal god learn options must not hardcode a single skill implementation");
assert(formalBuilderBody.includes('"id": "level_up_upgrade:%s"'), "god learn cards must use level_up_upgrade option ids");
assert(formalBuilderBody.includes('"type": "level_up_upgrade"'), "god learn cards must use level_up_upgrade option type");
assert(formalBuilderBody.includes('"upgrade_id"'), "god learn card payload must carry upgrade_id");
assert(formalBuilderBody.includes('"learn_skill_id"'), "god learn card payload must carry learn_skill_id");
assert(formalBuilderBody.includes("_get_option_background_texture(skill)"), "god learn cards should inherit skill card art/background data");
assert(
  /_get_option_weight\s*\(\s*option_variant\s+as\s+RefCounted\s*\)/.test(upgradePool),
  "UpgradePool weighted selection must continue using _get_option_weight"
);
assert(
  /rarity_weights\.get\(String\(option\.get\("rarity"\)\),\s*1\.0\)/.test(upgradePool),
  "_get_option_weight must still fall back to rarity_weights"
);

assert(gameData.includes('const GOD_SKILL_LEARN_UPGRADE_PREFIX: String = "learn_god_skill_"'), "GameData must define synthetic god learn upgrade prefix");
assert(gameData.includes("_make_god_skill_learn_upgrade"), "GameData.get_upgrade must synthesize god learn-skill upgrades");
const getUpgradeBody = bodyOf(gameData, "get_upgrade");
assert(getUpgradeBody.includes("upgrade_id_text.begins_with(GOD_SKILL_LEARN_UPGRADE_PREFIX)"), "GameData.get_upgrade must parse synthetic god learn ids");
assert(getUpgradeBody.includes("return _make_god_skill_learn_upgrade"), "GameData.get_upgrade must return synthetic learn-skill upgrade data");

assert(playerController.includes('const LEVEL_UP_UPGRADE_PREFIX: String = "level_up_upgrade:"'), "PlayerController must parse level_up_upgrade option ids");
assert(playerController.includes("func _apply_level_up_upgrade(upgrade_id: StringName) -> bool:"), "PlayerController must apply level-up upgrades");
assert(playerController.includes("var upgrade: Dictionary = GameData.get_upgrade(upgrade_id)"), "_apply_level_up_upgrade must load upgrades through GameData.get_upgrade");
assert(playerController.includes('if upgrade.has("learn_skill_id")'), "_apply_level_up_upgrade must handle learn_skill_id cards");
assert(playerController.includes("_learn_active_skill(learned_skill_id)"), "_apply_level_up_upgrade must route learn cards to _learn_active_skill");
assert(playerController.includes('skill_manager.call("add_skill", skill_id)'), "_learn_active_skill must call SkillManager.add_skill");

assert(skillManager.includes("var max_active_skills: int = 999"), "SkillManager default active skill cap must be raised for fire learn cards");
assert(skillManager.includes('category != "active" and category != "passive"'), "SkillManager.add_skill must allow active and passive skill definitions");
assert(skillManager.includes("if not _can_current_character_learn(definition_data):"), "SkillManager.add_skill must run character/pool learnability checks");
assert(skillManager.includes("category == \"active\" and is_active_skill_full()"), "SkillManager.add_skill must apply active cap only to active skills");
assert(skillManager.includes("_is_pool_learnable_skill(skill_data)"), "SkillManager must allow upgrade-pool learnable skill definitions");
assert(skillManager.includes("var passive_skills: Dictionary = {}"), "SkillManager must store passive skills separately from active skills");
assert(skillManager.includes("passive_skills[id] = skill_instance"), "SkillManager.add_skill must place passive skills in passive_skills");
assert(skillManager.includes("_apply_passive_skill_payload(definition)"), "SkillManager.add_skill must apply passive payloads");
assert(skillManager.includes('definition.get("skill_modifiers")'), "SkillManager passive payloads must apply skill_modifiers");
assert(addSkillBody.includes('if category == "passive":'), "SkillManager.add_skill must branch passive skills explicitly");
assert(/if\s+category\s*==\s*"passive":[\s\S]*?passive_skills\[id\]\s*=\s*skill_instance[\s\S]*?else:[\s\S]*?active_skills\[id\]\s*=\s*skill_instance/.test(addSkillBody), "SkillManager must store passive and active skills in separate dictionaries");
const skillDefinition = read("scripts/skills/skill_definition.gd");
const skillInstance = read("scripts/skills/skill_instance.gd");
const skillExecutor = read("scripts/skills/skill_executor.gd");
assert(skillDefinition.includes("var skill_modifiers: Array[Dictionary] = []"), "SkillDefinition must parse skill_modifiers");
assert(skillDefinition.includes("var runtime_rules: Dictionary = {}"), "SkillDefinition must parse runtime_rules");
assert(skillInstance.includes('"fire_runtime_rules"'), "SkillInstance must expose runtime_rules through runtime_special_rules");
assert(skillExecutor.includes("get_active_skills"), "SkillExecutor must tick active skills, not passive skills");
const availabilityBody = bodyOf(upgradePool, "_is_learn_skill_upgrade_available");
assert(!availabilityBody.includes("is_active_skill_full"), "UpgradePool must not block fire learn cards when active skills are full");

assert(fs.existsSync(fireSkillRuntimePath), "FireSkillRuntime adapter must exist");
const fireSkillRuntime = read("scripts/skills/fire_skill_runtime.gd");
assert(skillEventBus.includes('preload("res://scripts/skills/fire_skill_runtime.gd")'), "SkillEventBus must preload FireSkillRuntime");
assert(skillEventBus.includes("get_all_skills"), "SkillEventBus must inspect all learned skills for passive runtime rules");
assert(skillEventBus.includes("execute_passive_event"), "SkillEventBus must dispatch passive events through FireSkillRuntime");
assert(playerController.includes('preload("res://scripts/skills/fire_skill_runtime.gd")'), "PlayerController must preload FireSkillRuntime");
assert(playerController.includes("&\"on_player_damaged\""), "PlayerController damage path must emit on_player_damaged runtime rules");
assert(playerController.includes("execute_passive_event"), "PlayerController must dispatch player damaged passive runtime rules");

for (const eventName of ["on_cast", "on_projectile_hit", "on_enemy_killed", "on_player_damaged"]) {
  assert(fireSkillRuntime.includes(`"${eventName}"`) || fireSkillRuntime.includes(`&"${eventName}"`), `FireSkillRuntime must support ${eventName}`);
}
assert(fireSkillRuntime.includes("SkillActionExecutorScript"), "FireSkillRuntime must reuse SkillActionExecutor for action payloads");
assert(fireSkillRuntime.includes("execute_actions"), "FireSkillRuntime must execute configured runtime rule actions");
assert(fireSkillRuntime.includes("reduce_cooldowns"), "FireSkillRuntime must map cooldown runtime rules to real cooldown reduction");
assert(fireSkillRuntime.includes("fire_passive_shield"), "FireSkillRuntime must map shield runtime rules to player meta shield");
assert(fireSkillRuntime.includes("runtime_modifiers"), "FireSkillRuntime must map bonus/empower runtime rules to real skill runtime modifiers");
assert(playerAbsorbStage.includes("fire_passive_shield"), "Player damage pipeline must consume fire passive shield points");
assert(playerAbsorbStage.includes("fire_passive_shield_expires_at"), "Player damage pipeline must respect fire passive shield expiration");
assert(playerAbsorbStage.includes("absorbed_amount = maxi(absorbed_amount - fire_absorbed, 0)"), "Fire passive shield must reduce incoming player damage");

const supportedRuntimeRulesMatch = fireSkillRuntime.match(/const SUPPORTED_RULE_NAMES:[\s\S]*?=\s*\[([\s\S]*?)\]/);
assert(supportedRuntimeRulesMatch, "FireSkillRuntime must declare SUPPORTED_RULE_NAMES");
const supportedRuntimeRules = new Set(
  [...supportedRuntimeRulesMatch[1].matchAll(/"([^"]+)"/g)].map((match) => match[1])
);
const firePassiveRuntimeRules = fireSkills
  .filter((skill) => skill.category === "passive" && skill.runtime_rules && typeof skill.runtime_rules === "object")
  .map((skill) => ({ id: skill.id, rule: String(skill.runtime_rules.rule || "").trim() }))
  .filter((entry) => entry.rule !== "");
for (const entry of firePassiveRuntimeRules) {
  assert(
    supportedRuntimeRules.has(entry.rule),
    `FireSkillRuntime must support or explicitly map fire passive runtime rule ${entry.rule} from ${entry.id}`
  );
}

console.log("[verify_fire_skill_upgrade_pool] PASS");
