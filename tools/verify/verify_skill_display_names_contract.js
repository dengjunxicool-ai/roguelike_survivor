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
    if (!skill || typeof skill !== "object" || Array.isArray(skill)) {
      continue;
    }
    const skillId = String(skill.id || "<missing id>");
    assert(!Object.hasOwn(skill, "name"), `${sectionName}.${skillId} must not retain name alias`);
    assert(skill.display_name !== undefined, `${sectionName}.${skillId} must define display_name`);
    assert(
      typeof skill.display_name === "string" && skill.display_name.trim() !== "",
      `${sectionName}.${skillId} display_name must be nonempty`
    );
  }
}

verifySection("starting_skills");
verifySection("skills");

console.log("[verify_skill_display_names_contract] PASS");
