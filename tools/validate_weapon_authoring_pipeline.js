const { spawnSync } = require("child_process");
const path = require("path");

const root = path.resolve(__dirname, "..");

const CHECKS = [
  ["modifier effects", "tools/validate_modifier_effects.js"],
  ["weapon graph", "tools/validate_weapon_graph.js"],
  ["full weapon branch matrix", "tools/verify_full_weapon_branch_matrix.js"],
  ["combat test tooling", "tools/verify_combat_test_tooling.js"],
  ["no weapon evolution", "tools/validate_no_weapon_evolution.js"],
  ["primary attack single source", "tools/verify_primary_attack_single_source.js"],
  ["branch design alignment", "tools/validate_branch_design_alignment.js"],
  ["fire staff branch table", "tools/verify_fire_staff_branch_table.js"],
  ["soulburn Lv3 rule", "tools/verify_soulburn_lv3_rule.js"],
  ["soulburn Lv4 rule", "tools/verify_soulburn_lv4_rule.js"],
  ["soulburn Lv5 rule", "tools/verify_soulburn_lv5_rule.js"],
  ["lava Lv3 player lava rule", "tools/verify_lava_lv3_player_lava_rule.js"],
  ["lava Lv4 slow rule", "tools/verify_lava_lv4_slow_rule.js"],
  ["fireball impact target explosion half damage", "tools/verify_fireball_impact_target_explosion_half_damage.js"],
  ["burn status table", "tools/verify_burn_status_table.js"],
  ["fireball explosion multi-hit burn", "tools/verify_fireball_explosion_multi_hit_burn.js"],
  ["burst fireball death explosion debug trace", "tools/verify_burst_fireball_death_explosion_debug_trace.js"],
  ["frost staff branch table", "tools/verify_frost_staff_branch_table.js"],
  ["lightning whip branch table", "tools/verify_lightning_whip_branch_table.js"],
  ["spellbook branch table", "tools/verify_spellbook_branch_table.js"],
  ["throwing knife belt branch table", "tools/verify_throwing_knife_belt_branch_table.js"],
  ["hunter bow branch table", "tools/verify_hunter_bow_branch_table.js"],
  ["trap kit branch table", "tools/verify_trap_kit_branch_table.js"],
  ["holy shield branch table", "tools/verify_holy_shield_branch_table.js"],
  ["warhammer branch table", "tools/verify_warhammer_branch_table.js"],
  ["cross relic branch table", "tools/verify_cross_relic_branch_table.js"],
  ["toxic vial branch table", "tools/verify_toxic_vial_branch_table.js"],
  ["fire oil canister branch table", "tools/verify_fire_oil_canister_branch_table.js"],
  ["acid sprayer branch table", "tools/verify_acid_sprayer_branch_table.js"],
  ["primary attack assumptions", "tools/verify_primary_attack_config.js"],
  ["primary attack shape contracts", "tools/verify_primary_attack_shape_contracts.js"],
  ["area max target wiring", "tools/verify_area_effect_max_targets.js"],
  ["area effect visual mode", "tools/verify_area_effect_visual_mode.js"],
  ["combat structure refactor", "tools/verify_combat_structure_refactor.js"],
  ["character configs", "tools/validate_character_configs.js"],
  ["weapon authoring templates", "tools/verify_weapon_authoring_templates.js"],
  ["weapon runtime slot wiring", "tools/verify_weapon_runtime_slot_wiring.js"],
  ["weapon runtime state access", "tools/verify_weapon_runtime_state_access.js"],
  ["debug attack damage cards", "tools/verify_debug_attack_damage_cards.js"],
  ["unified damage trace context", "tools/verify_unified_damage_trace_context.js"],
  ["debug mage branch display", "tools/verify_debug_mage_branch_display.js"],
  ["debug ranger branch display", "tools/verify_debug_ranger_branch_display.js"],
  ["debug paladin branch display", "tools/verify_debug_paladin_branch_display.js"],
  ["debug alchemist branch display", "tools/verify_debug_alchemist_branch_display.js"],
  ["weapon attack visuals", "tools/verify_weapon_attack_visuals.js"],
  ["fireball shader effect", "tools/verify_fireball_shader_effect.js"],
  ["fire tornado debug VFX", "tools/verify_fire_tornado_debug_vfx.js"],
  ["dev effects panel VFX", "tools/verify_dev_effects_panel_vfx.js"],
  ["mars spark missile skill card", "tools/verify_mars_spark_missile_skill_card.js"],
  ["lightning chain and debug attack once", "tools/verify_lightning_chain_and_debug_attack_once.js"],
  ["frost hail and lightning chain visuals", "tools/verify_frost_hail_and_lightning_chain_visuals.js"],
  ["text encoding", "tools/check_text_encoding.js"],
];

function runCheck(label, scriptPath) {
  console.log(`\n== ${label} ==`);
  const result = spawnSync(process.execPath, [scriptPath], {
    cwd: root,
    encoding: "utf8",
  });
  process.stdout.write(result.stdout || "");
  process.stderr.write(result.stderr || "");
  return result.status === 0;
}

function main() {
  let failed = false;
  for (const [label, scriptPath] of CHECKS) {
    if (!runCheck(label, scriptPath)) {
      failed = true;
    }
  }

  if (failed) {
    console.error("\nWeapon authoring pipeline failed.");
    process.exitCode = 1;
    return;
  }

  console.log("\nWeapon authoring pipeline passed.");
}

main();
