const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(relativePath) {
  const text = read(relativePath).replace(/^\uFEFF/, "");
  return JSON.parse(text);
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function extractGdFunctionBody(text, functionName) {
  const declarationPattern = new RegExp(`(^|\\n)func\\s+${functionName}\\b[^\\n]*`);
  const match = declarationPattern.exec(text);
  assert(match != null, `DevDebugPanel must declare ${functionName}`);
  const start = match.index + match[1].length;
  const nextFunctionPattern = /\nfunc\s+/g;
  nextFunctionPattern.lastIndex = start + match[0].length - match[1].length;
  const nextMatch = nextFunctionPattern.exec(text);
  const end = nextMatch == null ? text.length : nextMatch.index;
  return text.slice(start, end);
}

const panel = read("scripts/debug/dev_debug_panel.gd");
const godsData = readJson("data/gods.json");
const skillsData = readJson("data/skills.json");

assert(panel.includes("func _string_or(value: Variant"), "DevDebugPanel must use a safe Variant-to-String helper");
assert(!panel.includes("String(god_id)"), "DevDebugPanel must not call the removed String constructor on god_id");
assert(!panel.includes('StringName(String(skill.get("god_id"'), "DevDebugPanel god filter must not wrap skill god_id with String(...)");
assert(!panel.includes('StringName(String(skill.get("school"'), "DevDebugPanel god filter must not wrap skill school with String(...)");
assert(!panel.includes('StringName(String(skill.get("fusion_school"'), "DevDebugPanel god filter must not wrap skill fusion_school with String(...)");

const gods = Array.isArray(godsData.gods) ? godsData.gods : [];
assert(gods.length === 6, "data/gods.json must define exactly 6 gods");
for (const god of gods) {
  assert(typeof god.id === "string" && god.id.trim() !== "", "each god must have a non-empty id");
}

const standaloneFireSkillsCategoryPattern = /_add_category_button\s*\([^)]*"fire_skills"[^)]*"Fire Skills"[^)]*\)/;
assert(!standaloneFireSkillsCategoryPattern.test(panel), "DevDebugPanel must not expose Fire Skills as a standalone category");
const skillCardsCategoryPattern = /_add_category_button\s*\([^)]*"skill_cards"[^)]*"Skill Cards"[^)]*\)/;
assert(skillCardsCategoryPattern.test(panel), "DevDebugPanel must expose Skill Cards category");
assert(!panel.includes('"Runtime Skill Cards"'), "Skill Cards page must not use old Runtime Skill Cards title");
assert(!panel.includes('"Refresh Cards"'), "Skill Cards page must not expose old Refresh Cards button");
assert(!panel.includes('"Clear Skill Cards"'), "Skill Cards page must not expose old Clear Skill Cards button");
assert(!panel.includes('"Clear Chart"'), "Skill Cards page must not expose old Clear Chart button");
assert(!panel.includes('"Spawn Target"'), "Skill Cards page must not expose Spawn Target button");
assert(!panel.includes('"Run Selected"'), "Skill Cards page must not expose Run Selected button");
assert(!panel.includes('"Refresh Gods"'), "Skill Cards page must not expose Refresh Gods button");
assert(!panel.includes("RuntimeUpgradeCards"), "DevDebugPanel must not keep old runtime upgrade card UI nodes");
assert(!panel.includes("RuntimeUpgradeComparisonChart"), "DevDebugPanel must not keep old runtime upgrade comparison chart");
assert(!/(^|\n)func\s+_run_selected_god_skill_chain\s*\(/.test(panel), "DevDebugPanel must not keep Run Selected button handler");
assert(/GodSkillCardsScroll[\s\S]*custom_minimum_size\s*=\s*Vector2\s*\(\s*440\s*,\s*(5[2-9]\d|[6-9]\d\d|\d{4,})\s*\)/.test(panel), "GodSkillCardsScroll must use the larger card display area");

const declarationMarkers = [
  [/(^|\n)func\s+_populate_god_skill_buttons\s*\(/, "func _populate_god_skill_buttons("],
  [/(^|\n)func\s+_refresh_god_skill_cards\s*\(/, "func _refresh_god_skill_cards("],
  [/(^|\n)func\s+_format_god_skill_card_text\s*\(/, "func _format_god_skill_card_text("],
  [/(^|\n)func\s+debug_run_god_skill_chain\s*\(/, "func debug_run_god_skill_chain("],
  [/(^|\n)func\s+_select_god_skill_cards\s*\(/, "func _select_god_skill_cards("],
  [/(^|\n)func\s+_run_god_skill_card\s*\(/, "func _run_god_skill_card("],
  [/(^|\n)func\s+_get_god_definitions\s*\(/, "func _get_god_definitions("],
  [/(^|\n)func\s+_get_god_skill_definitions\s*\(\s*god_id/, "func _get_god_skill_definitions(god_id"],
];

for (const [pattern, label] of declarationMarkers) {
  assert(pattern.test(panel), `DevDebugPanel must declare ${label}`);
}

const godDrivenBehaviorMarkers = [
  /(?:var\s+)?_selected_god_id\b/,
  /\.name\s*=\s*"GodSkillButtons"/,
  /\.name\s*=\s*"GodSkillCardsScroll"/,
  /skill\.get\("god_id"/,
  /"No skill cards for this god yet\."/,
  /"vfx_description"/,
  /"effect_description"/,
];

for (const pattern of godDrivenBehaviorMarkers) {
  assert(pattern.test(panel), `DevDebugPanel god skill cards must match ${pattern}`);
}

const godSkillCardRunBody = extractGdFunctionBody(panel, "_run_god_skill_card");
assert(!godSkillCardRunBody.includes("_spawn_fire_skill_debug_target"), "Selecting a god skill card must not spawn a target");
assert(!godSkillCardRunBody.includes("_prepare_fire_skill_debug_target"), "Selecting a god skill card must not prepare a spawned target");

const skills = Array.isArray(skillsData.skills) ? skillsData.skills : [];
const fireSkills = skills.filter(
  (skill) => skill.school === "fire" || skill.fusion_school === "fire" || (skill.tags || []).includes("fire")
);
assert(fireSkills.length === 34, "data/skills.json must define 34 first-version fire-related skills");
assert(
  fireSkills.some((skill) => skill.id === "fire_attack_searing"),
  "fire skill cards must include fire_attack_searing"
);
assert(
  !fireSkills.some((skill) => skill.id === "mars_spark_missile"),
  "old mars_spark_missile fire card must be removed"
);
const searing = fireSkills.find((skill) => skill.id === "fire_attack_searing");
assert(searing.type === "attack", "fire_attack_searing must be an attack skill");
assert(searing.exclusive_group === "attack_school", "fire_attack_searing must claim attack_school");
assert(
  (searing.trigger_rules || []).some((rule) => rule.trigger === "attack_hit"),
  "fire_attack_searing must react to attack_hit"
);
assert(
  (searing.effects || []).some((effect) => effect.type === "add_modifier"),
  "fire_attack_searing must carry its attack modifier effect"
);
assert(
  fireSkills.some((skill) => skill.id === "fusion_fire_frost_steam_mist" && skill.type === "fusion"),
  "fire skill cards must include fire-related fusion skills"
);

console.log("[verify_devtools_god_skill_cards_static] PASS");
