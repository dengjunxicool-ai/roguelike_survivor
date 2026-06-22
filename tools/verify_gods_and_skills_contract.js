const fs = require("fs");
const path = require("path");
const { readJsonFile } = require("./json_file");

const ROOT = path.resolve(__dirname, "..");
const GODS_PATH = path.join(ROOT, "data", "gods.json");
const SKILLS_PATH = path.join(ROOT, "data", "skills.json");
const CHARACTERS_PATH = path.join(ROOT, "data", "characters.json");
const RUNTIME_FAMILIES_DOC_PATH = path.join(ROOT, "docs", "skills", "runtime_families.md");
const UNREADABLE_JSON = Symbol("unreadable_json");

const EXPECTED_GODS = [
	{ id: "fire", display_name: "火焰", title: "火之神", implemented: true },
	{ id: "thunder", display_name: "雷霆", title: "雷之神", implemented: false },
	{ id: "frost", display_name: "寒霜", title: "冰之神", implemented: false },
	{ id: "curse", display_name: "诅咒", title: "暗之神", implemented: false },
	{ id: "holy", display_name: "神圣", title: "圣之神", implemented: false },
	{ id: "chaos", display_name: "混沌", title: "混沌之神", implemented: false },
];

const EXPECTED_FIRE_SKILLS_BY_RARITY = {
	common: [
		"火星飞弹",
		"焰舌喷吐",
		"灼热脉冲",
		"火羽刃",
		"熔芯箭",
		"余烬火花",
		"焦灼标记",
		"火纹护甲",
		"热浪推击",
		"火焰鞭影",
		"赤焰连击",
		"火苗复制",
		"燃血刺",
		"灯芯守卫",
		"火花反击",
		"灼心弱点",
		"火种积蓄",
		"烈焰回旋",
		"灰烬回收",
		"赤火护星",
		"熔屑飞溅",
		"焰影步",
		"炽热凝视",
		"火油亲和",
	],
	rare: [
		"双焰施放",
		"炎爆火印",
		"熔炉赐印",
		"黑焰附着",
		"炼狱连弹",
		"日矛点名",
		"融甲灼烧",
		"凤凰羽护",
		"火鸦群袭",
		"熔核回响",
		"炽热回流",
		"怒焰连杀",
		"赤阳护盾",
		"灼魂清算",
		"烈焰偏转",
		"焦热狂热",
		"火刑宣告",
		"燃尽余波",
	],
	epic: [
		"余烬循环",
		"焚心裁决",
		"炎爆序列",
		"灰烬复燃",
		"赤日连祷",
		"黑火债务",
		"凤凰回翔",
		"烈焰狂宴",
		"熔芯过载",
		"日冕爆发",
		"灭火成灰",
		"火种裂变",
	],
	legendary: [
		"终焰王冠",
		"凤凰涅槃",
		"太阳熔炉",
		"黑日降临",
		"万火归一",
		"灭世炎轮",
	],
};

const SOURCE_RARITY_BY_RARITY = {
	common: "普通",
	rare: "稀有",
	epic: "史诗",
	legendary: "传说",
};

const ALLOWED_RUNTIME_FAMILIES = new Set([
	"projectile",
	"cone_area",
	"radial_pulse",
	"orbit",
	"targeted_strike",
	"summon",
	"passive_modifier",
	"stack_mark",
	"kill_trigger",
	"damage_taken_trigger",
	"cooldown_reducer",
	"shield",
	"empower_next_fire",
	"delayed_damage",
	"revive_once",
	"fire_skill_count_scaling",
]);

const EXPECTED_FIRE_NAMES = Object.values(EXPECTED_FIRE_SKILLS_BY_RARITY).flat();
const REQUIRED_FIRE_SKILL_FIELDS = [
	"id",
	"display_name",
	"god_id",
	"rarity",
	"source_rarity",
	"description",
	"vfx_description",
	"build_hint",
	"category",
	"runtime_family",
	"tags",
	"particle",
];

function loadJson(relativePath, absolutePath, errors) {
	if (!fs.existsSync(absolutePath)) {
		errors.push(`Missing file: ${relativePath}`);
		return UNREADABLE_JSON;
	}

	try {
		return readJsonFile(absolutePath);
	} catch (error) {
		errors.push(`Invalid JSON in ${relativePath}: ${error.message}`);
		return UNREADABLE_JSON;
	}
}

function isPlainObject(value) {
	return value !== null && typeof value === "object" && !Array.isArray(value);
}

function requiredArray(document, key, relativePath, errors) {
	if (Array.isArray(document[key])) return document[key];

	errors.push(`${relativePath} must contain a top-level "${key}" array`);
	return [];
}

function isPresent(value) {
	if (value === undefined || value === null) return false;
	if (typeof value === "string" && value.trim() === "") return false;
	return true;
}

function isNonEmptyString(value) {
	return typeof value === "string" && value.trim() !== "";
}

function countBy(items, key) {
	return items.reduce((counts, item) => {
		const value = item && item[key];
		counts[value] = (counts[value] || 0) + 1;
		return counts;
	}, {});
}

function validateGods(godsDocument, errors) {
	if (godsDocument === UNREADABLE_JSON) return;

	if (!isPlainObject(godsDocument)) {
		errors.push('data/gods.json root must be an object with a top-level "gods" array');
		return;
	}

	const gods = requiredArray(godsDocument, "gods", "data/gods.json", errors);
	const godIds = gods.map((god) => god && god.id).filter(Boolean);
	const duplicateIds = godIds.filter((id, index) => godIds.indexOf(id) !== index);
	const uniqueDuplicateIds = [...new Set(duplicateIds)];

	if (gods.length !== EXPECTED_GODS.length) {
		errors.push(`data/gods.json must contain ${EXPECTED_GODS.length} gods, got ${gods.length}`);
	}
	if (uniqueDuplicateIds.length > 0) {
		errors.push(`data/gods.json god ids must be unique; duplicates: ${uniqueDuplicateIds.join(", ")}`);
	}

	for (const expectedGod of EXPECTED_GODS) {
		const god = gods.find((candidate) => candidate && candidate.id === expectedGod.id);
		if (!god) {
			errors.push(`data/gods.json is missing god id: ${expectedGod.id}`);
			continue;
		}

		for (const field of ["id", "display_name", "title", "description", "tags", "color", "implemented"]) {
			if (!isPresent(god[field])) {
				errors.push(`data/gods.json god ${expectedGod.id} is missing required field: ${field}`);
			}
		}
		if (god.display_name !== expectedGod.display_name) {
			errors.push(`data/gods.json god ${expectedGod.id} display_name must be ${expectedGod.display_name}`);
		}
		if (god.title !== expectedGod.title) {
			errors.push(`data/gods.json god ${expectedGod.id} title must be ${expectedGod.title}`);
		}
		if (god.implemented !== expectedGod.implemented) {
			errors.push(`data/gods.json god ${expectedGod.id} implemented must be ${expectedGod.implemented}`);
		}
		if (!Array.isArray(god.tags) || god.tags.length === 0) {
			errors.push(`data/gods.json god ${expectedGod.id} tags must be a non-empty array`);
		}
		if (!isPlainObject(god.color)) {
			errors.push(`data/gods.json god ${expectedGod.id} color must be an object`);
		}
	}
}

function validateStartingSkills(startingSkills, skills, errors) {
	if (!Array.isArray(startingSkills)) {
		errors.push("data/skills.json must contain a top-level starting_skills array");
		return;
	}

	if (startingSkills.length !== 1) {
		errors.push(`data/skills.json starting_skills must contain exactly one entry, got ${startingSkills.length}`);
	}

	const fireballStartingSkills = startingSkills.filter((skill) => {
		return isPlainObject(skill) && skill.id === "fireball";
	});
	if (fireballStartingSkills.length === 0) {
		errors.push('data/skills.json starting_skills must include an object with id: "fireball"');
	} else if (fireballStartingSkills.length > 1) {
		errors.push(`data/skills.json starting_skills must contain exactly one fireball entry, got ${fireballStartingSkills.length}`);
	}

	startingSkills.forEach((skill, index) => {
		if (!isPlainObject(skill)) {
			errors.push(`data/skills.json starting_skills[${index}] must be an object with offer_in_upgrade_pool: false`);
			return;
		}
		if ("weapon_id" in skill) {
			errors.push(`data/skills.json starting_skills[${index}] (${skill.id || "missing id"}) must not depend on weapon_id`);
		}
		if (skill.offer_in_upgrade_pool !== false) {
			errors.push(`data/skills.json starting_skills[${index}] (${skill.id || "missing id"}) must set offer_in_upgrade_pool: false`);
		}
	});

	if (fireballStartingSkills.length === 1) {
		const fireballStartingSkill = fireballStartingSkills[0];
		if (fireballStartingSkill.category !== "active") {
			errors.push('data/skills.json starting_skills fireball must set category: "active"');
		}
		if (fireballStartingSkill.is_starting_skill !== true) {
			errors.push("data/skills.json starting_skills fireball must set is_starting_skill: true");
		}
		if (fireballStartingSkill.offer_in_upgrade_pool !== false) {
			errors.push("data/skills.json starting_skills fireball must set offer_in_upgrade_pool: false");
		}
	}

	const fireballSkillEntries = skills.filter((skill) => skill && skill.id === "fireball");
	if (fireballSkillEntries.length > 0) {
		errors.push('data/skills.json skills must not contain "fireball"; it belongs only in starting_skills');
	}
}

function validateRequiredFireSkillField(skill, index, field, errors) {
	const skillLabel = skill.id || skill.display_name || `#${index}`;

	if (field === "tags") {
		if (!Array.isArray(skill.tags) || skill.tags.length === 0) {
			errors.push(`data/skills.json fire skill ${skillLabel} must set tags to a non-empty array`);
		}
		return;
	}

	if (field === "particle") {
		if (!isPlainObject(skill.particle)) {
			errors.push(`data/skills.json fire skill ${skillLabel} must set particle to an object`);
			return;
		}
		if (!isNonEmptyString(skill.particle.profile)) {
			errors.push(`data/skills.json fire skill ${skillLabel} must set particle.profile to a non-empty string`);
		}
		return;
	}

	if (!isPresent(skill[field])) {
		errors.push(`data/skills.json fire skill ${skillLabel} is missing required field: ${field}`);
	}
}

function hasRuntimePayload(skill) {
	return (
		(Array.isArray(skill.events) && skill.events.some((event) => Array.isArray(event.actions) && event.actions.length > 0)) ||
		(Array.isArray(skill.skill_modifiers) && skill.skill_modifiers.length > 0) ||
		isPlainObject(skill.runtime_rules)
	);
}

function validateFireSkills(skills, errors, documentedRuntimeFamilies) {
	const fireLearnableSkills = skills.filter((skill) => {
		return skill && skill.god_id === "fire" && skill.id !== "fireball" && skill.offer_in_upgrade_pool !== false;
	});

	if (fireLearnableSkills.length !== EXPECTED_FIRE_NAMES.length) {
		errors.push(`data/skills.json skills must contain ${EXPECTED_FIRE_NAMES.length} learnable fire skills, got ${fireLearnableSkills.length}`);
	}

	const fireNames = new Set(fireLearnableSkills.map((skill) => skill.display_name));
	const missingFireNames = EXPECTED_FIRE_NAMES.filter((name) => !fireNames.has(name));
	if (missingFireNames.length > 0) {
		errors.push(`data/skills.json is missing fire skill display_name values: ${missingFireNames.join("、")}`);
	}

	const rarityCounts = countBy(fireLearnableSkills, "rarity");
	for (const [rarity, names] of Object.entries(EXPECTED_FIRE_SKILLS_BY_RARITY)) {
		const actualCount = rarityCounts[rarity] || 0;
		if (actualCount !== names.length) {
			errors.push(`data/skills.json fire rarity count for ${rarity} must be ${names.length}, got ${actualCount}`);
		}
		for (const expectedName of names) {
			const skill = fireLearnableSkills.find((candidate) => candidate.display_name === expectedName);
			if (!skill) continue;
			if (skill.rarity !== rarity) {
				errors.push(`data/skills.json fire skill ${expectedName} rarity must be ${rarity}`);
			}
			if (skill.source_rarity !== SOURCE_RARITY_BY_RARITY[rarity]) {
				errors.push(`data/skills.json fire skill ${expectedName} source_rarity must be ${SOURCE_RARITY_BY_RARITY[rarity]}`);
			}
		}
	}

	const knownRarities = new Set(Object.keys(EXPECTED_FIRE_SKILLS_BY_RARITY));
	const unexpectedRarities = Object.keys(rarityCounts).filter((rarity) => !knownRarities.has(rarity));
	if (unexpectedRarities.length > 0) {
		errors.push(`data/skills.json fire skills have unexpected rarity values: ${unexpectedRarities.join(", ")}`);
	}

	fireLearnableSkills.forEach((skill, index) => {
		for (const field of REQUIRED_FIRE_SKILL_FIELDS) {
			validateRequiredFireSkillField(skill, index, field, errors);
		}
		if (skill.god_id !== "fire") {
			errors.push(`data/skills.json fire skill ${skill.id || index} must set god_id: "fire"`);
		}
		if (!ALLOWED_RUNTIME_FAMILIES.has(skill.runtime_family) && !documentedRuntimeFamilies.has(skill.runtime_family)) {
			errors.push(
				`data/skills.json fire skill ${skill.id || index} has undocumented runtime_family: ${skill.runtime_family}`
			);
		}
		if (!hasRuntimePayload(skill)) {
			errors.push(`data/skills.json fire skill ${skill.id || index} must provide events/actions, skill_modifiers, or runtime_rules`);
		}
	});
}

function validateUniqueSkillIds(skills, errors) {
	const skillIds = skills.map((skill) => skill && skill.id).filter(Boolean);
	const duplicateIds = skillIds.filter((id, index) => skillIds.indexOf(id) !== index);
	const uniqueDuplicateIds = [...new Set(duplicateIds)];
	if (uniqueDuplicateIds.length > 0) {
		errors.push(`data/skills.json skills ids must be unique; duplicates: ${uniqueDuplicateIds.join(", ")}`);
	}
}

function validateSkills(skillsDocument, errors, documentedRuntimeFamilies) {
	if (skillsDocument === UNREADABLE_JSON) return;

	if (!isPlainObject(skillsDocument)) {
		errors.push('data/skills.json root must be an object with top-level "skills" and "starting_skills" arrays');
		return;
	}

	const skills = requiredArray(skillsDocument, "skills", "data/skills.json", errors);
	validateUniqueSkillIds(skills, errors);
	validateStartingSkills(skillsDocument.starting_skills, skills, errors);
	validateFireSkills(skills, errors, documentedRuntimeFamilies);
}

function validateCharacters(charactersDocument, errors) {
	if (charactersDocument === UNREADABLE_JSON) return;
	if (!isPlainObject(charactersDocument)) {
		errors.push('data/characters.json root must be an object with a top-level "characters" array');
		return;
	}

	const characters = requiredArray(charactersDocument, "characters", "data/characters.json", errors);
	for (const character of characters) {
		if (!isPlainObject(character)) continue;
		if (character.starting_skill_id !== "fireball") {
			errors.push(`data/characters.json character ${character.id || "missing id"} must set starting_skill_id: "fireball"`);
		}
	}
}

function validateRuntimeFamiliesDoc(skillsDocument, errors) {
	if (skillsDocument === UNREADABLE_JSON) return;
	if (!fs.existsSync(RUNTIME_FAMILIES_DOC_PATH)) {
		errors.push("Missing file: docs/skills/runtime_families.md");
		return;
	}

	const docText = fs.readFileSync(RUNTIME_FAMILIES_DOC_PATH, "utf8");
	const skills = Array.isArray(skillsDocument.skills) ? skillsDocument.skills : [];
	const usedFamilies = [...new Set(skills.map((skill) => skill && skill.runtime_family).filter(Boolean))].sort();
	for (const runtimeFamily of usedFamilies) {
		if (!docText.includes(`\`${runtimeFamily}\``)) {
			errors.push(`docs/skills/runtime_families.md must document runtime family: ${runtimeFamily}`);
		}
	}
}

function readDocumentedRuntimeFamilies() {
	if (!fs.existsSync(RUNTIME_FAMILIES_DOC_PATH)) {
		return new Set();
	}

	const docText = fs.readFileSync(RUNTIME_FAMILIES_DOC_PATH, "utf8");
	return new Set([...docText.matchAll(/`([a-z0-9_]+)`/g)].map((match) => match[1]));
}

function main() {
	const errors = [];
	const godsDocument = loadJson("data/gods.json", GODS_PATH, errors);
	const skillsDocument = loadJson("data/skills.json", SKILLS_PATH, errors);
	const charactersDocument = loadJson("data/characters.json", CHARACTERS_PATH, errors);
	const documentedRuntimeFamilies = readDocumentedRuntimeFamilies();

	validateGods(godsDocument, errors);
	validateSkills(skillsDocument, errors, documentedRuntimeFamilies);
	validateCharacters(charactersDocument, errors);
	validateRuntimeFamiliesDoc(skillsDocument, errors);

	if (errors.length > 0) {
		console.error("[verify_gods_and_skills_contract] FAIL");
		for (const error of errors) {
			console.error(`- ${error}`);
		}
		process.exit(1);
	}

	console.log("[verify_gods_and_skills_contract] PASS");
}

main();
