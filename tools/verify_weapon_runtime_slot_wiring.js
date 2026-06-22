const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readProjectFile(relativePath) {
  const filePath = path.join(root, relativePath);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing file: ${relativePath}`);
  }
  return fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "");
}

function expectContains(text, needle, label, errors) {
  if (!text.includes(needle)) {
    errors.push(`${label} must contain: ${needle}`);
  }
}

function expectMatches(text, pattern, label, errors) {
  if (!pattern.test(text)) {
    errors.push(`${label} must match: ${pattern}`);
  }
}

function legacyName(parts) {
  return parts.join("_");
}

function main() {
  const errors = [];

  const slot = readProjectFile("scripts/weapons/weapon_runtime_slot.gd");
  const runtime = readProjectFile("scripts/characters/character_runtime.gd");
  const branchSystem = readProjectFile("scripts/weapons/weapon_branch_system.gd");

  expectContains(slot, "class_name WeaponRuntimeSlot", "WeaponRuntimeSlot", errors);
  expectContains(slot, "var weapon_id: StringName", "WeaponRuntimeSlot", errors);
  expectContains(slot, "var base_skill_id: StringName", "WeaponRuntimeSlot", errors);
  expectContains(slot, "var current_skill_id: StringName", "WeaponRuntimeSlot", errors);
  expectContains(slot, "var selected_branch_id: StringName", "WeaponRuntimeSlot", errors);
  expectContains(slot, "var branch_level: int", "WeaponRuntimeSlot", errors);
  expectContains(slot, "func initialize_from_weapon", "WeaponRuntimeSlot", errors);
  expectContains(slot, "func mark_branch_level", "WeaponRuntimeSlot", errors);
  expectContains(slot, "func to_debug_dict", "WeaponRuntimeSlot", errors);
  if (slot.includes("is_evolved") || slot.includes("evolution_id") || slot.includes("mark_evolved")) {
    errors.push("WeaponRuntimeSlot must not keep weapon evolution state.");
  }

  expectContains(runtime, 'preload("res://scripts/weapons/weapon_runtime_slot.gd")', "CharacterRuntime", errors);
  expectContains(runtime, "var main_weapon_slot: RefCounted", "CharacterRuntime", errors);
  expectContains(runtime, "var weapon_slots: Array[RefCounted]", "CharacterRuntime", errors);
  expectContains(runtime, 'main_weapon_slot.call("initialize_from_weapon"', "CharacterRuntime", errors);
  expectContains(runtime, "weapon_slots.append(main_weapon_slot)", "CharacterRuntime", errors);
  expectContains(runtime, "func get_main_weapon_slot", "CharacterRuntime", errors);
  expectContains(runtime, "func get_weapon_slot_debug_state", "CharacterRuntime", errors);
  expectContains(runtime, "func get_selected_weapon_branch_id", "CharacterRuntime", errors);
  expectContains(runtime, "func get_selected_weapon_branch_level", "CharacterRuntime", errors);
  expectContains(runtime, "func mark_weapon_branch_level", "CharacterRuntime", errors);
  if (
    runtime.includes(legacyName(["get", "weapon", "evolution", "id"])) ||
    runtime.includes(legacyName(["is", "equipped", "weapon", "evolved"])) ||
    runtime.includes(legacyName(["mark", "weapon", "evolved"]))
  ) {
    errors.push("CharacterRuntime must not expose weapon evolution accessors.");
  }
  if (runtime.includes("_sync_legacy_weapon_state_from_slot")) {
    errors.push("CharacterRuntime must not keep legacy weapon state mirror sync.");
  }
  if (runtime.includes("var selected_branch_id:") || runtime.includes("var is_weapon_evolved:")) {
    errors.push("CharacterRuntime must not keep legacy selected_branch_id/is_weapon_evolved fields.");
  }
  expectMatches(
    runtime,
    /func get_equipped_weapon_skill_id\(\) -> String:[\s\S]*main_weapon_slot[\s\S]*current_skill_id/,
    "CharacterRuntime.get_equipped_weapon_skill_id",
    errors
  );

  expectContains(branchSystem, 'runtime.call("mark_weapon_branch_level"', "WeaponBranchSystem", errors);

  if (errors.length) {
    for (const error of errors) {
      console.error(`ERROR ${error}`);
    }
    process.exitCode = 1;
    return;
  }

  console.log("Weapon runtime slot wiring verified.");
}

main();
