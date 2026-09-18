const path = require("path");
const { readJsonFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const skillsDocument = readJsonFile(path.join(root, "data", "skills", "skills.json"));

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function verifySection(sectionName) {
  const entries = Array.isArray(skillsDocument[sectionName]) ? skillsDocument[sectionName] : [];
  for (const skill of entries) {
    if (!skill || typeof skill !== "object" || Array.isArray(skill) || skill.name === undefined) {
      continue;
    }
    const skillId = String(skill.id || "<missing id>");
    assert(skill.display_name !== undefined, `${sectionName}.${skillId} must define display_name`);
    assert(
      skill.display_name === skill.name,
      `${sectionName}.${skillId} display_name must exactly match name`
    );
  }
}

verifySection("starting_skills");
verifySection("skills");

console.log("[verify_skill_display_names_contract] PASS");
