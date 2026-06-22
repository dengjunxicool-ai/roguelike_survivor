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

const panel = read("scripts/debug/dev_debug_panel.gd");
const godsData = readJson("data/gods.json");
const skillsData = readJson("data/skills.json");

const gods = Array.isArray(godsData.gods) ? godsData.gods : [];
assert(gods.length === 6, "data/gods.json must define exactly 6 gods");
for (const god of gods) {
  assert(typeof god.id === "string" && god.id.trim() !== "", "each god must have a non-empty id");
}

assert(
  !panel.includes('_add_category_button(category_grid, "fire_skills", "Fire Skills")'),
  "DevDebugPanel must not expose Fire Skills as a standalone category"
);
assert(
  panel.includes('_add_category_button(category_grid, "skill_cards", "Skill Cards")'),
  "DevDebugPanel must expose Skill Cards category"
);

const implementationMarkers = [
  "GodSkillButtons",
  "GodSkillCardsScroll",
  "func _populate_god_skill_buttons()",
  "func _refresh_god_skill_cards()",
  "func _format_god_skill_card_text",
  "vfx_description",
  "effect_description",
  "debug_run_god_skill_chain",
];

for (const marker of implementationMarkers) {
  assert(panel.includes(marker), `DevDebugPanel must include ${marker}`);
}

const skills = Array.isArray(skillsData.skills) ? skillsData.skills : [];
const fireSkills = skills.filter(
  (skill) => skill.god_id === "fire" && skill.offer_in_upgrade_pool === true
);
assert(fireSkills.length === 60, "data/skills.json must define 60 fire upgrade skills");
assert(
  fireSkills.some((skill) => skill.id === "mars_spark_missile"),
  "fire upgrade skills must include mars_spark_missile"
);

console.log("[verify_devtools_god_skill_cards_static] PASS");
