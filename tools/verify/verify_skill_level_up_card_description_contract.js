const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "../..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
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

const upgradePool = read("scripts/upgrades/upgrade_pool.gd");
const upgradeOption = read("scripts/upgrades/upgrade_option.gd");
const choiceModal = read("scripts/ui/modals/run_choice_modal_controller.gd");

const levelUpBuilder = bodyOf(upgradePool, "_build_skill_level_up_options");
const skillLevelUpDescription = bodyOf(upgradePool, "_build_skill_level_up_description");
const optionInit = bodyOf(upgradeOption, "_init");
const optionDictionary = bodyOf(upgradeOption, "to_dictionary");
const bindChoiceCard = bodyOf(choiceModal, "_bind_choice_card");

assert(levelUpBuilder, "UpgradePool must define _build_skill_level_up_options");
assert(!levelUpBuilder.includes("_get_skill_level_description"), "owned skill level-up cards must not read per-level descriptions");
assert(!levelUpBuilder.includes("level_descriptions"), "owned skill level-up cards must ignore level_descriptions");
assert(levelUpBuilder.includes('_get_definition_string(definition, "display_name", skill_name)'), "owned skill level-up cards must use skill display_name in generated text");
assert(levelUpBuilder.includes('"description": _build_skill_level_up_description(skill_name, next_level)'), "owned skill level-up description must be generated from display_name and next level");
assert(!skillLevelUpDescription.includes("?"), "owned skill level-up description must not include a visible ? icon");
assert(!levelUpBuilder.includes("tooltip_description"), "owned skill level-up cards must not export hover tooltip data");

assert(!upgradeOption.includes("tooltip_description"), "UpgradeOption must not carry description hover tooltip data");
assert(!optionInit.includes("tooltip_description"), "UpgradeOption must not read tooltip_description from source data");
assert(!optionDictionary.includes("tooltip_description"), "UpgradeOption must not export tooltip_description to UI dictionaries");

assert(!choiceModal.includes("SkillCardDescriptionHelpIcon"), "choice cards must not create a ? icon after display_name");
assert(!choiceModal.includes("SkillCardDisplayNameHoverArea"), "choice cards must not create display-name hover interaction");
assert(!choiceModal.includes("SkillCardDescriptionHelpPoll"), "choice cards must not poll hover state for a description icon");
assert(!choiceModal.includes("_configure_choice_card_description_hover"), "choice cards must not bind custom description hover behavior");
assert(!choiceModal.includes("_get_option_tooltip_text"), "choice cards must not read custom tooltip_description data");
assert(!choiceModal.includes("description_hover"), "choice cards must not store description hover metadata");
assert(bindChoiceCard.includes("description.text = _get_option_description_text(option)"), "pooled choice cards must bind the plain option description label");

console.log("[verify_skill_level_up_card_description_contract] PASS");
