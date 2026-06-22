const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const dataDir = path.join(root, "data");

function writeJson(name, value) {
  value = normalizeRuntimeFields(name, value);
  fs.writeFileSync(path.join(dataDir, name), JSON.stringify(value, null, "\t") + "\n", "utf8");
}

const startingSkillByWeapon = {
  fire_staff: "fireball",
  frost_staff: "hailstorm",
  lightning_whip: "lightning_orb",
  spellbook: "arcane_pages",
  throwing_knife_belt: "throwing_knife",
  hunter_bow: "piercing_arrow",
  trap_kit: "bear_trap",
  holy_shield: "holy_shield",
  warhammer: "judgement_hammer",
  cross_relic: "holy_field",
  toxic_vial: "poison_bottle",
  fire_oil_canister: "burning_oil_pot",
  acid_sprayer: "acid_spray",
};

function normalizeRuntimeFields(name, value) {
  const doc = JSON.parse(JSON.stringify(value));
  if (name === "characters.json") normalizeCharacters(doc);
  if (name === "weapons.json") normalizeWeapons(doc);
  if (name === "status_effects.json") normalizeStatuses(doc);
  if (name === "enemies.json") normalizeEnemies(doc);
  if (name === "waves.json") normalizeWaves(doc);
  if (name === "upgrades.json") normalizeUpgrades(doc);
  if (name === "relics.json") normalizeRelics(doc);
  if (name === "maps.json") normalizeMaps(doc);
  if (name === "challenges.json") normalizeChallenges(doc);
  stripLegacyFields(name, doc);
  return doc;
}

function stripLegacyFields(name, doc) {
  if (name === "characters.json") {
    for (const character of doc.characters || []) {
      deleteFields(character, ["character_id", "name_zh", "name_en", "role_zh", "role_en", "description_zh", "description_en", "stats", "talent", "allowed_weapons", "unlock_condition"]);
      if (character.trait) deleteFields(character.trait, ["name_zh", "name_en"]);
      if (character.trait?.params?.max_stacks !== undefined) delete character.trait.params.max_stack;
    }
  }
  if (name === "weapons.json") {
    for (const weapon of doc.weapons || []) {
      deleteFields(weapon, ["weapon_id", "weapon_name_zh", "weapon_name_en", "description_zh", "description_en", "allowed_characters", "primary_attack_id", "element_tags", "base_status_id", "cosmetic_slots", "unlock_condition"]);
    }
  }
  if (name === "enemies.json") {
    for (const enemy of doc.monsters || doc.enemies || []) {
      deleteFields(enemy, ["monster_id", "name_zh", "name_en", "monster_family", "rank", "hp", "defense", "exp", "rewards", "spawn_weight", "behavior_type", "behavior_config", "skill_list", "screen_limit", "warning_rule"]);
    }
  }
  if (name === "maps.json") {
    for (const map of doc.maps || []) {
      if (map.map_variable) deleteFields(map.map_variable, ["description_zh", "description_en"]);
      deleteFields(map, ["map_id", "name_zh", "name_en", "unlock_condition"]);
    }
  }
  if (name === "upgrades.json") {
    for (const section of ["curse_choices", "permanent_upgrades", "level_up_upgrades"]) {
      for (const upgrade of doc[section] || []) {
        deleteFields(upgrade, ["upgrade_id", "upgrade_name_zh", "upgrade_name_en", "effect_list", "weight_rule", "max_stack", "ui_description_zh", "ui_description_en"]);
      }
    }
  }
  if (name === "status_effects.json") {
    for (const status of doc.statuses || []) {
      deleteFields(status, ["status_id", "name_zh", "name_en", "status_type", "max_stack", "effect_per_stack", "reaction_trigger_ids", "ui_display_priority"]);
    }
  }
  if (name === "relics.json") {
    for (const relic of doc.relics || []) {
      deleteFields(relic, ["relic_id", "relic_name_zh", "relic_name_en", "effect_list", "ui_description_zh", "ui_description_en", "unlock_condition"]);
    }
  }
  if (name === "waves.json") {
    for (const wave of doc.waves || []) deleteFields(wave, ["wave_id", "name_zh", "name_en"]);
  }
  if (name === "weapon_branches.json") {
    for (const branch of doc.branches || []) deleteFields(branch, ["branch_id", "name_zh", "name_en"]);
  }
  if (name === "weapon_evolutions.json") {
    for (const evolution of doc.evolutions || []) deleteFields(evolution, ["evolution_id", "name_zh", "name_en"]);
  }
  if (name === "challenges.json") {
    for (const challenge of [...(doc.daily_challenges || []), ...(doc.weekly_challenges || [])]) {
      deleteFields(challenge, ["name_zh", "name_en"]);
    }
  }
}

function deleteFields(object, keys) {
  for (const key of keys) delete object[key];
}

function normalizeCharacters(doc) {
  for (const character of doc.characters || []) {
    const stats = character.stats || {};
    const talent = character.talent || {};
    const traitParams = { ...(talent.params || {}) };
    if (traitParams.max_stacks === undefined && traitParams.max_stack !== undefined) traitParams.max_stacks = traitParams.max_stack;
    character.id = character.id || character.character_id;
    character.display_name = character.display_name || character.name_zh;
    character.description = character.description || character.description_zh;
    character.role = character.role || character.role_zh;
    character.allowed_weapon_ids = character.allowed_weapon_ids || character.allowed_weapons || [];
    character.unlock = character.unlock || character.unlock_condition || { type: "default" };
    character.trait = character.trait || {
      id: talent.talent_id || "",
      display_name: talent.name_zh || "",
      type: talent.type || "",
      params: traitParams,
    };
    if (character.trait.params?.max_stacks === undefined && character.trait.params?.max_stack !== undefined) {
      character.trait.params.max_stacks = character.trait.params.max_stack;
    }
    character.base_stats = character.base_stats || {
      max_hp: stats.hp,
      move_speed: stats.move_speed,
      damage_multiplier: stats.damage_multiplier,
      attack_speed_multiplier: stats.attack_speed_multiplier,
      crit_chance: stats.crit_rate,
      crit_damage: stats.crit_damage,
      armor: stats.defense,
      pickup_radius: stats.pickup_range,
      soul_gain_multiplier: 1,
    };
  }
}

function normalizeWeapons(doc) {
  for (const weapon of doc.weapons || []) {
    weapon.id = weapon.id || weapon.weapon_id;
    weapon.display_name = weapon.display_name || weapon.weapon_name_zh;
    weapon.description = weapon.description || weapon.description_zh || weapon.weapon_name_zh;
    weapon.character_id = weapon.character_id || (weapon.allowed_characters || [])[0] || "";
    weapon.starting_skill_id = weapon.starting_skill_id || startingSkillByWeapon[weapon.weapon_id] || weapon.primary_attack_id || "";
    weapon.tags = weapon.tags || weapon.element_tags || [];
    weapon.on_hit_status = weapon.on_hit_status || weapon.base_status_id || "";
    weapon.unlock = weapon.unlock || weapon.unlock_condition || { type: "default" };
    weapon.visual = weapon.visual || {};
    if (!weapon.visual.icon && weapon.cosmetic_slots?.icon) weapon.visual.icon = weapon.cosmetic_slots.icon;
    if (!weapon.visual.texture && weapon.cosmetic_slots?.icon) weapon.visual.texture = weapon.cosmetic_slots.icon;
  }
}

function normalizeStatuses(doc) {
  for (const status of doc.statuses || []) {
    const effect = status.effect_per_stack || {};
    status.id = status.id || status.status_id;
    status.display_name = status.display_name || status.name_zh || status.status_id;
    status.type = status.type || status.status_type;
    status.max_stacks = status.max_stacks ?? status.max_stack ?? 1;
    status.effect = status.effect || {};
    if (status.type === "dot" || effect.damage) {
      status.damage = Number(effect.damage || status.damage || 0);
      status.damage_type = effect.element || status.element || status.id;
      status.effect.dot = true;
    }
    if (effect.move_speed_multiplier_add) status.effect.move_slow_per_stack = Math.abs(Number(effect.move_speed_multiplier_add));
    if (effect.defense_add && Number(effect.defense_add) < 0) status.armor_break_multiplier_add = Math.abs(Number(effect.defense_add)) * 0.03;
    for (const [key, rawValue] of Object.entries(effect)) {
      const numberValue = Number(rawValue);
      if (key.endsWith("_vulnerability_add")) {
        status.effect[`${key.replace("_vulnerability_add", "")}_damage_taken_multiplier_add_per_stack`] = numberValue;
      } else if (key === "crit_rate_taken_add") {
        status.effect.all_damage_taken_multiplier_add_per_stack = Math.max(numberValue * 0.5, 0);
      }
    }
  }
}

function normalizeEnemies(doc) {
  for (const enemy of doc.monsters || doc.enemies || []) {
    enemy.id = enemy.id || enemy.monster_id;
    enemy.display_name = enemy.display_name || enemy.name_zh;
    enemy.type = enemy.type || enemy.rank;
    enemy.base_stats = enemy.base_stats || {
      max_hp: enemy.hp,
      move_speed: enemy.move_speed,
      contact_damage: enemy.contact_damage,
      armor: enemy.defense,
      resistances: enemy.resistances || {},
      attack_range: enemy.behavior_config?.skill_range || 48,
      exp_drop: enemy.exp,
      soul_drop: enemy.rewards?.souls || 0,
      collision_radius: enemy.collision_radius,
    };
    enemy.behavior = enemy.behavior || Object.assign({ type: enemy.behavior_type }, enemy.behavior_config || {});
    enemy.skills = enemy.skills || enemy.skill_list || [];
    enemy.visual = enemy.visual || {};
  }
}

function normalizeWaves(doc) {
  for (const wave of doc.waves || []) {
    wave.id = wave.id || wave.wave_id;
    wave.display_name = wave.display_name || wave.name_zh;
    wave.duration_seconds = wave.duration_seconds || Math.max(1, Number(wave.end_time || 0) - Number(wave.start_time || 0));
  }
}

function normalizeUpgrades(doc) {
  for (const key of ["curse_choices", "permanent_upgrades", "level_up_upgrades"]) {
    for (const upgrade of doc[key] || []) {
      upgrade.id = upgrade.id || upgrade.upgrade_id;
      upgrade.display_name = upgrade.display_name || upgrade.upgrade_name_zh;
      upgrade.description = upgrade.description || upgrade.ui_description_zh;
      upgrade.enabled = upgrade.enabled ?? true;
      upgrade.base_weight = upgrade.base_weight ?? Number(upgrade.weight_rule?.base || 0);
      upgrade.weight_decay = upgrade.weight_decay ?? Number(upgrade.weight_rule?.decay || 1);
      upgrade.max_level = upgrade.max_level ?? upgrade.max_stack ?? 1;
      upgrade.modifiers = upgrade.modifiers || modifiersFromEffectList(upgrade.effect_list);
      upgrade.level_modifiers = upgrade.level_modifiers || [upgrade.modifiers];
      upgrade.level_descriptions = upgrade.level_descriptions || [upgrade.description || ""];
      if (key === "level_up_upgrades" && (upgrade.tags || []).includes("weapon")) {
        upgrade.skill_modifiers = upgrade.skill_modifiers || upgrade.modifiers;
      }
    }
  }
}

function normalizeRelics(doc) {
  for (const relic of doc.relics || []) {
    relic.id = relic.id || relic.relic_id;
    relic.display_name = relic.display_name || relic.relic_name_zh;
    relic.description = relic.description || relic.ui_description_zh;
    relic.modifiers = relic.modifiers || modifiersFromEffectList(relic.effect_list);
    relic.unlock = relic.unlock || relic.unlock_condition || { type: "default" };
  }
}

function normalizeMaps(doc) {
  for (const map of doc.maps || []) {
    map.id = map.id || map.map_id;
    map.display_name = map.display_name || map.name_zh;
    map.description = map.description || map.map_variable?.description_zh || "";
    map.unlock = map.unlock || map.unlock_condition || { type: "default" };
  }
}

function normalizeChallenges(doc) {
  for (const challenge of [...(doc.daily_challenges || []), ...(doc.weekly_challenges || [])]) {
    challenge.display_name = challenge.display_name || challenge.name_zh || challenge.challenge_id;
  }
}

function modifiersFromEffectList(effectList) {
  const fieldMap = {
    max_health_multiplier_add: "max_hp_multiplier_add",
    max_health_add: "max_hp_add",
    defense_add: "armor_add",
    pickup_range_multiplier_add: "pickup_radius_multiplier_add",
    pickup_range_add: "pickup_radius_add",
    heal_current: "heal",
    crit_rate_add: "crit_chance_add",
  };
  const result = {};
  for (const effect of effectList || []) {
    const key = fieldMap[effect.stat] || effect.stat;
    if (!key) continue;
    result[key] = (result[key] || 0) + Number(effect.value || 0);
  }
  return result;
}

const characters = [
  {
    character_id: "mage",
    name_zh: "法师",
    name_en: "Mage",
    role_zh: "高爆发元素施法者",
    role_en: "High burst elemental caster",
    description_zh: "以主武器伤害和元素状态推进节奏，但过载后更脆弱。",
    description_en: "Pushes tempo with main-weapon damage and elemental status, becoming fragile while overloaded.",
    stats: { hp: 75, move_speed: 98, damage_multiplier: 1.08, attack_speed_multiplier: 1.0526, crit_rate: 0.06, crit_damage: 1.5, defense: 0, pickup_range: 85 },
    talent: {
      talent_id: "arcane_overload",
      name_zh: "奥术过载",
      name_en: "Arcane Overload",
      type: "weapon_cast_stack",
      params: {
        casts_per_stack: 3,
        max_stack: 6,
        modifiers_per_stack: { equipped_weapon_damage_add: 0.04, attack_speed_multiplier_add: 0.0204, move_speed_multiplier_add: -0.015, damage_taken_multiplier_add: 0.02 },
        full_stack_modifiers: { equipped_weapon_damage_add: 0.08, damage_taken_multiplier_add: 0.08, pickup_range_multiplier_add: -0.2 },
        on_damaged: { lose_stack_percent: 0.5, clear_below_stack: 2 }
      }
    },
    allowed_weapons: ["fire_staff", "frost_staff", "lightning_whip", "spellbook"],
    unlock_condition: { type: "default" },
    visual: { sprite_frames: "res://assets/hero/mage_spriteframes.tres", texture: "res://assets/hero/mege.png" }
  },
  {
    character_id: "ranger",
    name_zh: "游侠",
    name_en: "Ranger",
    role_zh: "高速暴击与陷阱猎手",
    role_en: "Fast critical hunter and trapper",
    description_zh: "保持移动能进入猎手节奏，停顿、受击或硬控会中断节奏。",
    description_en: "Sustained movement enters Hunter's Rhythm; stopping, damage, or hard control breaks it.",
    stats: { hp: 85, move_speed: 118, damage_multiplier: 0.95, attack_speed_multiplier: 1.12, crit_rate: 0.12, crit_damage: 1.6, defense: 0, pickup_range: 80 },
    talent: {
      talent_id: "hunters_rhythm",
      name_zh: "猎手节奏",
      name_en: "Hunter's Rhythm",
      type: "moving_bonus",
      params: {
        moving_seconds_required: 2.5,
        stop_break_seconds: 0.4,
        active_modifiers: { crit_rate_add: 0.12, projectile_speed_multiplier_add: 0.15, trap_interval_multiplier_add: -0.1 },
        penalty_duration: 3.0,
        penalty_modifiers: { crit_rate_add: -0.08, trap_interval_multiplier_add: 0.08 }
      }
    },
    allowed_weapons: ["throwing_knife_belt", "hunter_bow", "trap_kit"],
    unlock_condition: { type: "default" },
    visual: { texture: "res://assets/hero/2.png" }
  },
  {
    character_id: "paladin",
    name_zh: "圣骑士",
    name_en: "Paladin",
    role_zh: "护盾与神圣防线",
    role_en: "Shielded holy frontline",
    description_zh: "更稳定地承受伤害，并在护盾存在时强化神圣伤害。",
    description_en: "Withstands damage more steadily and empowers holy damage while shielded.",
    stats: { hp: 135, move_speed: 90, damage_multiplier: 0.92, attack_speed_multiplier: 0.9048, crit_rate: 0.04, crit_damage: 1.5, defense: 6, pickup_range: 78 },
    talent: {
      talent_id: "holy_burden",
      name_zh: "神圣重负",
      name_en: "Holy Burden",
      type: "passive_with_periodic_shield",
      params: {
        shield_amount: 20,
        shield_interval: 18,
        shield_duration: 18,
        base_modifiers: { damage_taken_multiplier_add: -0.1, move_speed_multiplier_add: -0.08, attack_speed_multiplier_add: -0.0411, holy_damage_multiplier_add: 0.05 }
      }
    },
    allowed_weapons: ["holy_shield", "warhammer", "cross_relic"],
    unlock_condition: { type: "default" },
    visual: { texture: "res://assets/hero/3.png" }
  },
  {
    character_id: "alchemist",
    name_zh: "炼金术士",
    name_en: "Alchemist",
    role_zh: "异常状态与反应专家",
    role_en: "Status and reaction specialist",
    description_zh: "直接主攻击较弱，但持续伤害与状态反应更强。",
    description_en: "Weaker direct main attacks, stronger damage over time and reactions.",
    stats: { hp: 95, move_speed: 100, damage_multiplier: 0.9, attack_speed_multiplier: 1.0, crit_rate: 0.05, crit_damage: 1.5, defense: 2, pickup_range: 90 },
    talent: {
      talent_id: "unstable_potion",
      name_zh: "不稳定试剂",
      name_en: "Unstable Potion",
      type: "status_kill_random_area",
      params: {
        kill_chance: 0.15,
        same_source_cooldown: 0.5,
        max_zones: 4,
        boss_minion_chance_multiplier: 0.5,
        area_damage: 6,
        area_duration: 2.5,
        area_tick_interval: 0.5,
        area_radius: 56,
        base_modifiers: { dot_damage_multiplier_add: 0.25, reaction_damage_multiplier_add: 0.1, direct_damage_multiplier_add: -0.1 }
      }
    },
    allowed_weapons: ["toxic_vial", "fire_oil_canister", "acid_sprayer"],
    unlock_condition: { type: "default" },
    visual: { texture: "res://assets/hero/4.png" }
  }
];

const weapons = [
  ["fire_staff", "火焰法杖", "Fire Staff", ["mage"], "fireball", ["fire", "projectile"], ["direct_magical"], "heat", "nearest_enemy", ["weapon", "damage", "area", "status"], "res://assets/weapon/fire_staff.png"],
  ["frost_staff", "寒霜法杖", "Frost Staff", ["mage"], "hailstorm", ["ice", "area"], ["area_direct"], "chill", "nearest_enemy", ["weapon", "area", "control", "status"], "res://assets/weapon/frost_staff.png"],
  ["lightning_whip", "雷电长鞭", "Lightning Whip", ["mage"], "lightning_orb", ["lightning", "chain"], ["direct_magical"], "charge", "nearest_enemy", ["weapon", "chain", "speed", "status"], "res://assets/weapon/lightning_whip.png"],
  ["spellbook", "奥术法典", "Spellbook", ["mage"], "arcane_page", ["arcane", "projectile"], ["direct_magical"], "arcane_mark", "nearest_enemy", ["weapon", "projectile", "rare", "status"], "res://assets/weapon/spellbook.png"],
  ["throwing_knife_belt", "飞刀腰带", "Throwing Knife Belt", ["ranger"], "throwing_knife", ["physical", "projectile"], ["direct_physical"], "wound", "nearest_enemy", ["weapon", "projectile", "crit", "status"], "res://assets/weapon/knife_belt.png"],
  ["hunter_bow", "猎人长弓", "Hunter's Bow", ["ranger"], "piercing_arrow", ["physical", "projectile"], ["direct_physical"], "hunter_mark", "highest_hp_enemy", ["weapon", "projectile", "pierce", "crit"], "res://assets/weapon/hunter_bow.png"],
  ["trap_kit", "陷阱包", "Trap Kit", ["ranger"], "bear_trap", ["physical", "trap"], ["area_direct"], "snare_mark", "near_player", ["weapon", "trap", "control", "area"], "res://assets/weapon/trap_pack.png"],
  ["holy_shield", "圣盾", "Holy Shield", ["paladin"], "holy_shield_guard", ["holy", "shield"], ["area_direct"], "holy_mark", "self", ["weapon", "shield", "holy", "survival"], "res://assets/weapon/holy_shield_weapon.png"],
  ["warhammer", "审判战锤", "Warhammer", ["paladin"], "judgement_hammer", ["physical", "holy", "area"], ["area_direct"], "judgment", "nearest_enemy", ["weapon", "area", "holy", "damage"], "res://assets/weapon/warhammer.png"],
  ["cross_relic", "十字圣物", "Cross Relic", ["paladin"], "holy_field", ["holy", "field"], ["area_direct"], "radiance", "near_player", ["weapon", "field", "holy", "survival"], "res://assets/weapon/cross_relic.png"],
  ["toxic_vial", "毒素瓶", "Toxic Vial", ["alchemist"], "toxic_vial_pool", ["poison", "field"], ["status_dot"], "residue", "nearest_enemy", ["weapon", "dot", "poison", "area"], "res://assets/weapon/toxin_bottle.png"],
  ["fire_oil_canister", "燃油罐", "Fire Oil Canister", ["alchemist"], "fire_oil_pool", ["fire", "field"], ["status_dot"], "oil", "nearest_enemy", ["weapon", "dot", "fire", "area"], "res://assets/weapon/fire_oil_canister.png"],
  ["acid_sprayer", "酸液喷射器", "Acid Sprayer", ["alchemist"], "acid_spray", ["acid", "cone"], ["status_dot"], "corrosion", "nearest_enemy", ["weapon", "dot", "acid", "area"], "res://assets/weapon/acid_sprayer.png"]
].map(([weapon_id, name_zh, name_en, allowed_characters, primary_attack_id, element_tags, damage_origin_list, base_status_id, targeting_rule_id, upgrade_tag_pool, icon]) => ({
  weapon_id,
  weapon_name_zh: name_zh,
  weapon_name_en: name_en,
  allowed_characters,
  primary_attack_id,
  element_tags,
  damage_origin_list,
  base_status_id,
  branch_ids: [],
  targeting_rule_id,
  upgrade_tag_pool,
  unlock_condition: { type: "default" },
  cosmetic_slots: { icon }
}));

const statuses = [
  ["heat", "base", 5, 4, 0, { fire_vulnerability_add: 0.03 }, "refresh_duration", "none", ["ignite"], 40],
  ["chill", "base", 5, 3, 0, { move_speed_multiplier_add: -0.06 }, "refresh_duration", "slow_poise", ["freeze"], 45],
  ["charge", "base", 4, 4, 0, { lightning_vulnerability_add: 0.04 }, "refresh_duration", "none", ["shock"], 42],
  ["arcane_mark", "base", 5, 5, 0, { arcane_vulnerability_add: 0.03 }, "refresh_duration", "none", ["detonate_mark"], 38],
  ["wound", "base", 5, 5, 0, { bleed_damage_add: 1 }, "refresh_duration", "none", ["bleed"], 36],
  ["judgment", "base", 3, 6, 0, { holy_vulnerability_add: 0.05 }, "refresh_duration", "none", ["smite"], 50],
  ["residue", "base", 5, 4, 0, { poison_vulnerability_add: 0.04 }, "refresh_duration", "none", ["poison"], 44],
  ["oil", "base", 5, 4, 0, { fire_vulnerability_add: 0.04 }, "refresh_duration", "none", ["burn"], 44],
  ["corrosion", "base", 5, 4, 0, { defense_add: -1 }, "refresh_duration", "armor_break_resist", ["acid_burst"], 44],
  ["hunter_mark", "mark", 1, 5, 0, { crit_rate_taken_add: 0.08 }, "replace", "none", [], 35],
  ["snare_mark", "mark", 1, 2, 0, { move_speed_multiplier_add: -0.45 }, "replace", "slow_poise", [], 35],
  ["holy_mark", "mark", 1, 4, 0, { holy_vulnerability_add: 0.05 }, "replace", "none", [], 35],
  ["burn", "dot", 1, 3, 0.5, { damage: 5, element: "fire" }, "refresh_duration", "dot_resist", [], 60],
  ["poison", "dot", 1, 4, 0.5, { damage: 4, element: "poison" }, "refresh_duration", "dot_resist", [], 60],
  ["bleed", "dot", 1, 4, 0.5, { damage: 4, element: "physical" }, "refresh_duration", "dot_resist", [], 60],
  ["blackfire", "dot", 1, 3, 0.5, { damage: 6, element: "fire" }, "refresh_duration", "dot_resist", [], 62],
  ["shock", "reaction", 1, 0.8, 0, { trigger_damage: 10 }, "replace", "reaction_resist", [], 65],
  ["slow", "control", 1, 2, 0, { move_speed_multiplier_add: -0.35 }, "strongest_only", "poise", [], 70],
  ["root", "control", 1, 1.2, 0, { move_speed_multiplier_add: -1.0 }, "strongest_only", "poise", [], 72],
  ["freeze", "hard_control", 1, 0.8, 0, { move_speed_multiplier_add: -1.0 }, "strongest_only", "poise", [], 80],
  ["stun", "hard_control", 1, 0.7, 0, { move_speed_multiplier_add: -1.0 }, "strongest_only", "poise", [], 80],
  ["paralyze", "hard_control", 1, 0.7, 0, { move_speed_multiplier_add: -1.0 }, "strongest_only", "poise", [], 80],
  ["weaken", "debuff", 1, 3, 0, { damage_multiplier_add: -0.15 }, "refresh_duration", "none", [], 55],
  ["radiance", "field", 1, 0.5, 0.5, { heal: 1, damage: 6, element: "holy" }, "field_tick", "none", [], 58]
].map(([status_id, status_type, max_stack, duration, tick_interval, effect_per_stack, refresh_rule, boss_conversion_rule, reaction_trigger_ids, ui_display_priority]) => ({
  status_id,
  name_zh: status_id,
  name_en: status_id,
  status_type,
  max_stack,
  duration,
  tick_interval,
  effect_per_stack,
  refresh_rule,
  boss_conversion_rule,
  reaction_trigger_ids,
  ui_display_priority
}));

const dungeonHeartPhases = [
  {
    hp_percent_min: 0.7,
    hp_percent_max: 1.01,
    max_concurrent_skills: 1,
    skills: [
      { skill_id: "red_circle", type: "delayed_area_blast", radius: 78, damage: 22, delay: 0.9, cooldown: 5.0 },
      { skill_id: "ring_bullets", type: "ring_projectiles", projectile_count: 12, speed: 230, damage: 12, safe_gap_count: 2, cooldown: 7.0 },
    ],
  },
  {
    hp_percent_min: 0.35,
    hp_percent_max: 0.7,
    max_concurrent_skills: 2,
    skills: [
      { skill_id: "red_circle", type: "delayed_area_blast", radius: 86, damage: 24, delay: 0.85, cooldown: 4.4 },
      { skill_id: "corrupted_cores", type: "corrupted_cores", count: 2, hp: 120, cooldown: 18.0 },
      { skill_id: "corruption_gaze", type: "corruption_gaze", radius: 52, damage: 7, delay: 1.2, duration: 2.5, tick_interval: 0.5, cooldown: 10.0 },
    ],
  },
  {
    hp_percent_min: 0.0,
    hp_percent_max: 0.35,
    max_concurrent_skills: 2,
    skills: [
      { skill_id: "red_circle", type: "delayed_area_blast", radius: 94, damage: 28, delay: 0.8, cooldown: 3.8 },
      { skill_id: "ring_bullets", type: "ring_projectiles", projectile_count: 20, speed: 290, damage: 16, safe_gap_count: 3, cooldown: 6.0 },
      { skill_id: "shockwave", type: "shockwave", radius: 360, damage: 28, warning_time: 0.8, cooldown: 7.0 },
      { skill_id: "corruption_gaze", type: "corruption_gaze", radius: 52, damage: 7, delay: 1.2, duration: 2.5, tick_interval: 0.5, cooldown: 9.0 },
    ],
  },
];

const monsters = [
  ["small_slime", "小史莱姆", "Small Slime", "slime", "normal", 18, 0, 45, 6, 0.8, 18, 3, 32, "chase_player", [], 120],
  ["skeleton", "骷髅兵", "Skeleton", "undead", "normal", 30, 1, 52, 9, 0.9, 20, 5, 28, "chase_player", [], 120],
  ["bat", "蝙蝠", "Bat", "beast", "normal", 22, 0, 82, 7, 0.7, 14, 4, 24, "chase_player", [], 120],
  ["archer_skeleton", "弓箭骷髅", "Archer Skeleton", "undead", "normal", 38, 1, 42, 8, 1.1, 18, 7, 18, "keep_distance_and_shoot", [{ skill_id: "arrow_shot", cooldown: 2.2 }], 80],
  ["toxic_bug", "毒虫", "Toxic Bug", "insect", "normal", 36, 0, 58, 7, 0.8, 16, 5, 22, "chase_player", [{ skill_id: "poison_contact" }], 90],
  ["bomber", "炸弹怪", "Bomber", "construct", "normal", 45, 0, 54, 18, 1.0, 20, 6, 14, "explode_near_player", [{ skill_id: "self_explode" }], 45],
  ["armored_skeleton", "重甲骷髅", "Armored Skeleton", "undead", "normal", 70, 5, 38, 14, 1.0, 24, 9, 15, "chase_player", [], 70],
  ["skeleton_priest", "骷髅祭司", "Skeleton Priest", "undead", "normal", 55, 2, 40, 10, 1.1, 20, 10, 12, "summon_and_chase", [{ skill_id: "minor_summon" }], 35],
  ["war_drum_goblin", "战鼓哥布林", "War Drum Goblin", "goblin", "normal", 65, 2, 46, 10, 1.0, 20, 10, 10, "chase_and_cast_pool", [{ skill_id: "war_drum" }], 35],
  ["gem_slime", "宝石史莱姆", "Gem Slime", "slime", "normal", 80, 1, 55, 8, 0.8, 18, 24, 4, "chase_player", [], 20],
  ["shadow_hunter", "暗影猎手", "Shadow Hunter", "shadow", "normal", 95, 3, 78, 16, 0.8, 18, 12, 7, "dash_attack", [{ skill_id: "shadow_dash" }], 35],
  ["giant_slime", "巨型史莱姆", "Giant Slime", "slime", "elite", 560, 5, 42, 16, 1.1, 34, 90, 0, "chase_player", [], 1, 20],
  ["skeleton_captain", "骷髅队长", "Skeleton Captain", "undead", "elite", 1150, 9, 52, 22, 1.0, 28, 150, 0, "dash_attack", [{ skill_id: "captain_charge" }], 1, 35],
  ["toxic_matriarch", "毒虫女王", "Toxic Matriarch", "insect", "elite", 1050, 9, 48, 22, 1.0, 30, 140, 0, "chase_and_cast_pool", [{ skill_id: "toxic_pool" }], 1, 35],
  ["lava_golem", "熔岩魔像", "Lava Golem", "construct", "elite", 1400, 12, 36, 28, 1.1, 36, 170, 0, "chase_and_cast_pool", [{ skill_id: "lava_pool" }], 1, 45],
  ["dungeon_heart", "地牢之心", "Dungeon Heart", "boss", "boss", 5000, 10, 24, 30, 1.0, 62, 0, 0, "boss_dungeon_heart", [{ skill_id: "red_circle" }, { skill_id: "ring_bullets" }, { skill_id: "summon_minions" }, { skill_id: "shockwave" }, { skill_id: "corruption_gaze" }, { skill_id: "corrupted_cores" }], 1, 200]
].map(([monster_id, name_zh, name_en, monster_family, rank, hp, defense, move_speed, contact_damage, contact_interval, collision_radius, exp, spawn_weight, behavior_type, skill_list, screen_limit, souls = 0]) => ({
  monster_id,
  name_zh,
  name_en,
  monster_family,
  rank,
  hp,
  defense,
  move_speed,
  contact_damage,
  contact_interval,
  collision_radius,
  exp,
  rewards: { souls },
  spawn_weight,
  behavior_type,
  skill_list,
  screen_limit,
  warning_rule: rank === "boss" ? { pre_warning_seconds: 2.0, concurrent_skill_limit: 2 } : {},
  resistances: rank === "boss" ? { armor: 0.08, magic: 0.08, poison: 0.18, acid: 0.1, holy: 0.0 } : {},
  behavior_config: rank === "boss" ? { rage_after_seconds: 300, skill_range: 760, phases: dungeonHeartPhases } : {}
}));

const waves = {
  run: {
    duration_seconds: 300,
    boss_spawn_time: 240,
    starting_level: 1,
    experience_table: [14, 24, 36, 52, 72, 96, 124, 156, 192, 232, 276, 324, 376, 432, 492],
    experience_formula: { type: "table", values: [14, 24, 36, 52, 72, 96, 124, 156, 192, 232, 276, 324, 376, 432, 492] }
  },
  spawn_rules: {
    first_level_up_choice: { option_count: 3, minimum_weapon_tendency_options: 2 },
    upgrade_phase_weights: [
      { phase_id: "before_main_lv3", condition: { main_level_max: 2 }, weights: { main_progression: 45, adaptive: 30, survival: 20, boss: 0, rare: 5 } },
      { phase_id: "main_lv3_to_lv5", condition: { main_level_min: 3, main_level_max: 5 }, weights: { main_progression: 35, adaptive: 35, survival: 20, boss: 5, rare: 5 } },
      { phase_id: "after_lv5", condition: { main_level_min: 6 }, weights: { main_progression: 0, adaptive: 35, survival: 20, boss: 25, rare: 5 } },
      { phase_id: "after_220s", condition: { elapsed_time_min: 220 }, weights: { main_progression: 0, adaptive: 25, survival: 20, boss: 45, rare: 10 } }
    ],
    low_hp_rule: { threshold_percent: 0.35, guarantee_tags: ["survival", "heal"] },
    weapon_tag_rule: { minimum_matching_choice_count: 1 },
    main_progression_pity: { missing_choices_before_guarantee: 2 }
  },
  waves: [
    { wave_id: "wave_1", name_zh: "史莱姆苏醒", name_en: "Slime Awakening", start_time: 0, end_time: 25, max_alive: 35, spawn_interval: 1.1, enemy_multipliers: { hp: 1, defense_add: 0, damage: 0.9, speed: 1, exp: 1.25 }, groups: [{ enemy_ids: ["small_slime"], weight: 100 }] },
    { wave_id: "wave_2", name_zh: "骷髅靠近", name_en: "Skeleton Approach", start_time: 25, end_time: 55, max_alive: 50, spawn_interval: 0.95, enemy_multipliers: { hp: 1.15, defense_add: 0, damage: 1, speed: 1, exp: 1.15 }, groups: [{ enemy_ids: ["small_slime", "skeleton"], weight: 100 }] },
    { wave_id: "wave_3", name_zh: "蝙蝠群", name_en: "Bat Swarm", start_time: 55, end_time: 85, max_alive: 70, spawn_interval: 0.8, enemy_multipliers: { hp: 1.3, defense_add: 1, damage: 1.12, speed: 1.05, exp: 1.05 }, groups: [{ enemy_ids: ["bat", "skeleton"], weight: 100 }] },
    { wave_id: "wave_4", name_zh: "第一精英", name_en: "First Elite", start_time: 85, end_time: 115, max_alive: 80, spawn_interval: 0.75, enemy_multipliers: { hp: 1.55, defense_add: 1, damage: 1.28, speed: 1, exp: 1 }, groups: [{ enemy_ids: ["archer_skeleton", "armored_skeleton"], weight: 100 }], events: [{ time: 90, type: "spawn_elite", enemy_id: "giant_slime" }] },
    { wave_id: "wave_5", name_zh: "远程压制", name_en: "Ranged Pressure", start_time: 115, end_time: 150, max_alive: 100, spawn_interval: 0.65, enemy_multipliers: { hp: 1.85, defense_add: 2, damage: 1.45, speed: 1.05, exp: 1 }, groups: [{ enemy_ids: ["archer_skeleton", "toxic_bug", "bomber"], weight: 100 }] },
    { wave_id: "wave_6", name_zh: "第二精英", name_en: "Second Elite", start_time: 150, end_time: 185, max_alive: 120, spawn_interval: 0.55, enemy_multipliers: { hp: 2.2, defense_add: 2, damage: 1.65, speed: 1.06, exp: 1.05 }, groups: [{ enemy_ids: ["toxic_bug", "bomber", "skeleton_priest"], weight: 100 }] },
    { wave_id: "wave_7", name_zh: "怪潮压境", name_en: "Crushing Horde", start_time: 185, end_time: 220, max_alive: 135, spawn_interval: 0.52, enemy_multipliers: { hp: 2.5, defense_add: 3, damage: 1.82, speed: 1.08, exp: 1.1 }, groups: [{ enemy_ids: ["armored_skeleton", "war_drum_goblin", "shadow_hunter"], weight: 100 }], events: [{ time: 190, type: "spawn_elite", enemy_id: "skeleton_captain" }] },
    { wave_id: "wave_8", name_zh: "最终怪潮", name_en: "Final Horde", start_time: 220, end_time: 240, max_alive: 160, spawn_interval: 0.38, enemy_multipliers: { hp: 2.75, defense_add: 3, damage: 2, speed: 1.1, exp: 1.3 }, groups: [{ enemy_ids: ["shadow_hunter", "skeleton_priest", "war_drum_goblin", "gem_slime"], weight: 100 }] }
  ],
  boss_event: {
    boss_id: "dungeon_heart",
    spawn_time: 240,
    souls_reward: 200,
    gold_reward: 120,
    fairness: { warning_required: true, max_concurrent_major_mechanics: 2, overlap_damage_protection_seconds: 0.3 },
    minion_spawn: {
      enabled: true,
      max_alive: 35,
      spawn_interval: 3,
      enemy_multipliers: { hp: 2.1, defense_add: 2, damage: 1.65, speed: 1.05, exp: 0.5 },
      groups: [{ enemy_ids: ["small_slime", "skeleton", "toxic_bug"], weight: 100 }]
    }
  },
  rewards: { base_gold: 0, boss_gold: 120, boss_souls: 200 }
};

function upgrade(id, nameZh, nameEn, rarity, tags, effects, weight = 50, maxStack = 3, desc = "") {
  return {
    upgrade_id: id,
    upgrade_name_zh: nameZh,
    upgrade_name_en: nameEn,
    rarity,
    tags,
    required_weapon_tags: tags.includes("weapon") ? ["weapon"] : [],
    required_branch_id: "",
    required_player_state: {},
    effect_list: effects,
    exclude_tags: [],
    weight_rule: { base: weight, decay: 0.85 },
    max_stack: maxStack,
    ui_description_zh: desc || nameZh,
    ui_description_en: desc || nameEn
  };
}

const upgrades = {
  rarity_weights: { common: 60, rare: 28, epic: 10, legendary: 2 },
  curse_choices: [
    upgrade("curse_greedy_horde", "贪婪怪潮", "Greedy Horde", "rare", ["threat"], [{ stat: "enemy_spawn_count_multiplier_add", op: "add", value: 0.2 }, { stat: "coin_gain_multiplier_add", op: "add", value: 0.25 }], 20, 1),
    upgrade("curse_boss_bounty", "Boss 悬赏", "Boss Bounty", "epic", ["boss", "threat"], [{ stat: "boss_hp_multiplier_add", op: "add", value: 0.2 }, { stat: "soul_gain_multiplier_add", op: "add", value: 0.25 }], 12, 1)
  ],
  permanent_upgrades: [
    upgrade("meta_health", "生命强化", "Health", "common", ["meta", "survival"], [{ stat: "max_health_multiplier_add", op: "add", value: 0.02 }], 100, 20),
    upgrade("meta_attack", "攻击强化", "Attack", "common", ["meta", "weapon"], [{ stat: "damage_multiplier_add", op: "add", value: 0.015 }], 100, 15),
    upgrade("meta_pickup", "拾取强化", "Pickup", "common", ["meta", "economy"], [{ stat: "pickup_range_multiplier_add", op: "add", value: 0.04 }], 90, 40),
    upgrade("meta_luck", "幸运强化", "Luck", "rare", ["meta", "rare"], [{ stat: "luck_add", op: "add", value: 0.01 }], 50, 10),
    upgrade("meta_combat_intuition", "战斗直觉", "Combat Intuition", "rare", ["meta", "boss"], [{ stat: "pre_boss_blessing_options_add", op: "add", value: 1 }], 30, 1),
    upgrade("meta_stable_growth", "稳定成长", "Stable Growth", "rare", ["meta", "weapon"], [{ stat: "main_progression_weight_add", op: "add", value: 0.1 }], 30, 10)
  ],
  level_up_upgrades: [
    upgrade("weapon_damage_focus", "武器伤害", "Weapon Damage", "common", ["weapon", "adaptive", "damage"], [{ stat: "damage_multiplier_add", op: "add", value: 0.08 }], 100, 5, "主武器伤害提高。"),
    upgrade("weapon_attack_speed", "武器节奏", "Weapon Tempo", "common", ["weapon", "adaptive", "speed"], [{ stat: "attack_speed_multiplier_add", op: "add", value: 0.08 }], 90, 5, "主武器攻击频率提高。"),
    upgrade("weapon_area", "范围扩张", "Area Expansion", "common", ["weapon", "adaptive", "area"], [{ stat: "skill_area_multiplier_add", op: "add", value: 0.12 }], 70, 5, "主武器影响范围提高。"),
    upgrade("weapon_status", "状态增幅", "Status Amplifier", "rare", ["weapon", "adaptive", "status"], [{ stat: "status_duration_multiplier_add", op: "add", value: 0.15 }], 55, 4, "基础状态持续时间提高。"),
    upgrade("survival_health", "生命强化", "Health Up", "common", ["survival"], [{ stat: "max_health_add", op: "add", value: 18 }], 85, 5, "最大生命提高。"),
    upgrade("survival_defense", "防御强化", "Defense Up", "common", ["survival"], [{ stat: "defense_add", op: "add", value: 2 }], 70, 5, "防御提高。"),
    upgrade("survival_pickup", "拾取强化", "Pickup Up", "common", ["survival", "economy"], [{ stat: "pickup_range_add", op: "add", value: 18 }], 65, 5, "拾取范围提高。"),
    upgrade("survival_heal", "应急治疗", "Emergency Heal", "rare", ["survival", "heal"], [{ stat: "heal_current", op: "add", value: 30 }], 35, 3, "立即恢复生命。"),
    upgrade("boss_damage", "Boss 压制", "Boss Pressure", "rare", ["boss", "weapon"], [{ stat: "boss_damage_multiplier_add", op: "add", value: 0.12 }], 45, 3, "对 Boss 伤害提高。"),
    upgrade("rare_crit", "精准打击", "Precision Strike", "rare", ["rare", "weapon", "crit"], [{ stat: "crit_rate_add", op: "add", value: 0.08 }], 40, 4, "暴击率提高。")
  ]
};

const relics = {
  relics: [
    { relic_id: "ember_badge", relic_name_zh: "余烬徽章", relic_name_en: "Ember Badge", rarity: "rare", tags: ["fire", "reaction"], trigger_condition: { event: "apply_status", status_id: "heat" }, effect_list: [{ stat: "fire_damage_multiplier_add", op: "add", value: 0.12 }], cooldown: 0, limit_rule: {}, negative_modifier: {}, unlock_condition: { type: "default" }, ui_description_zh: "热量相关伤害提高。", ui_description_en: "Improves heat-related damage." },
    { relic_id: "icecrack_ring", relic_name_zh: "冰裂指环", relic_name_en: "Icecrack Ring", rarity: "rare", tags: ["ice", "control"], trigger_condition: { event: "hit_chilled_enemy" }, effect_list: [{ stat: "crit_rate_add", op: "add", value: 0.06 }], cooldown: 0, limit_rule: {}, negative_modifier: {}, unlock_condition: { type: "default" }, ui_description_zh: "攻击寒冷目标时更容易暴击。", ui_description_en: "Improves crits against chilled targets." },
    { relic_id: "thunder_conductor", relic_name_zh: "雷导体", relic_name_en: "Thunder Conductor", rarity: "epic", tags: ["lightning", "chain"], trigger_condition: { event: "shock_triggered" }, effect_list: [{ stat: "projectile_speed_multiplier_add", op: "add", value: 0.15 }], cooldown: 3, limit_rule: {}, negative_modifier: {}, unlock_condition: { type: "default" }, ui_description_zh: "触发电击后短暂强化投射速度。", ui_description_en: "Boosts projectile speed after shock triggers." },
    { relic_id: "hunter_bone_whistle", relic_name_zh: "猎骨哨", relic_name_en: "Hunter Bone Whistle", rarity: "rare", tags: ["physical", "trap"], trigger_condition: { event: "elite_reward" }, effect_list: [{ stat: "trap_interval_multiplier_add", op: "add", value: -0.12 }], cooldown: 0, limit_rule: {}, negative_modifier: {}, unlock_condition: { type: "default" }, ui_description_zh: "陷阱部署间隔降低。", ui_description_en: "Reduces trap deployment interval." },
    { relic_id: "shieldbreaker_covenant", relic_name_zh: "破盾契约", relic_name_en: "Shieldbreaker Covenant", rarity: "epic", tags: ["boss", "damage"], trigger_condition: { event: "boss_phase_start" }, effect_list: [{ stat: "boss_damage_multiplier_add", op: "add", value: 0.18 }], cooldown: 0, limit_rule: {}, negative_modifier: { stat: "damage_taken_multiplier_add", value: 0.08 }, unlock_condition: { type: "default" }, ui_description_zh: "Boss 战更强，但承伤提高。", ui_description_en: "Stronger in boss fights, but you take more damage." },
    { relic_id: "toxic_fog_remnant_flask", relic_name_zh: "瘴雾残瓶", relic_name_en: "Toxic Fog Remnant Flask", rarity: "rare", tags: ["poison", "map"], trigger_condition: { event: "map_event", map_variable: "toxic_fog" }, effect_list: [{ stat: "poison_damage_multiplier_add", op: "add", value: 0.15 }], cooldown: 0, limit_rule: {}, negative_modifier: {}, unlock_condition: { type: "default" }, ui_description_zh: "毒相关伤害提高。", ui_description_en: "Improves poison damage." },
    { relic_id: "corrosion_nameplate", relic_name_zh: "腐蚀名牌", relic_name_en: "Corrosion Nameplate", rarity: "rare", tags: ["acid"], trigger_condition: { event: "apply_status", status_id: "corrosion" }, effect_list: [{ stat: "acid_damage_multiplier_add", op: "add", value: 0.12 }], cooldown: 0, limit_rule: {}, negative_modifier: {}, unlock_condition: { type: "default" }, ui_description_zh: "腐蚀相关伤害提高。", ui_description_en: "Improves corrosion damage." }
  ]
};

const maps = {
  maps: [
    { map_id: "abandoned_dungeon", name_zh: "废弃地牢", name_en: "Abandoned Dungeon", map_variable: { type: "open", description_zh: "无强机制，标准开阔地图。", description_en: "No strong mechanic, standard open map." }, difficulty: 1, boss_id: "dungeon_heart", elite_preview_ids: ["giant_slime", "skeleton_captain"], unlock_condition: { type: "default" }, visual: { background: "res://assets/ui/maps/abandoned_dungeon.png" } },
    { map_id: "toxic_fog_graveyard", name_zh: "瘴毒墓园", name_en: "Toxic Fog Graveyard", map_variable: { type: "toxic_fog", description_zh: "随机瘴毒雾区，毒系敌人更多。", description_en: "Random toxic fog zones and more poison enemies." }, difficulty: 2, boss_id: "dungeon_heart", elite_preview_ids: ["toxic_matriarch"], unlock_condition: { type: "clear_map", map_id: "abandoned_dungeon" }, visual: { background: "res://assets/ui/maps/poison_graveyard.png" } },
    { map_id: "lava_temple", name_zh: "熔火神殿", name_en: "Lava Temple", map_variable: { type: "lava_fissure", description_zh: "周期性熔岩裂隙。", description_en: "Periodic lava fissures." }, difficulty: 3, boss_id: "dungeon_heart", elite_preview_ids: ["lava_golem"], unlock_condition: { type: "clear_map", map_id: "toxic_fog_graveyard" }, visual: { background: "res://assets/ui/maps/lava_temple.png" } },
    { map_id: "abyss_corridor", name_zh: "深渊回廊", name_en: "Abyss Corridor", map_variable: { type: "narrow_corridor", description_zh: "狭窄回廊，包围压力更强。", description_en: "Narrow corridors and stronger encirclement pressure." }, difficulty: 4, boss_id: "dungeon_heart", elite_preview_ids: ["shadow_hunter"], unlock_condition: { type: "clear_map", map_id: "lava_temple" }, visual: { background: "res://assets/ui/maps/abyss_corridor.png" } }
  ]
};

const progression = {
  weapon_mastery: {
    level_rewards: [
      { level: 1, reward_zh: "图鉴条目", reward_en: "Codex entry" },
      { level: 2, reward_zh: "武器皮肤", reward_en: "Weapon skin" },
      { level: 3, reward_zh: "最佳分支记录", reward_en: "Best branch record" },
      { level: 4, reward_zh: "专属遗物加入池", reward_en: "Exclusive relic added" },
      { level: 5, reward_zh: "特殊特效", reward_en: "Special VFX" },
      { level: 6, reward_zh: "挑战关卡", reward_en: "Challenge stage" },
      { level: 7, reward_zh: "金色称号", reward_en: "Golden title" }
    ]
  },
  character_specializations: [
    { character_id: "mage", goals: ["overload_full_stack_kills", "element_reaction_mastery"] },
    { character_id: "ranger", goals: ["rhythm_uptime", "trap_and_crit_mastery"] },
    { character_id: "paladin", goals: ["shield_survival", "holy_damage_mastery"] },
    { character_id: "alchemist", goals: ["status_kill_chains", "reaction_zone_mastery"] }
  ],
  map_challenges: [
    { map_id: "abandoned_dungeon", objectives: ["clear_once", "clear_without_death", "defeat_boss_before_285s"] },
    { map_id: "toxic_fog_graveyard", objectives: ["clear_once", "avoid_toxic_fog_overdamage", "defeat_toxic_matriarch"] },
    { map_id: "lava_temple", objectives: ["clear_once", "survive_lava_fissures", "defeat_lava_golem"] },
    { map_id: "abyss_corridor", objectives: ["clear_once", "survive_encirclement", "defeat_shadow_hunter"] }
  ]
};

const challenges = {
  daily_challenges: [
    { challenge_id: "daily_fixed_fire_mage", name_zh: "每日示例：火焰法师", name_en: "Daily Sample: Fire Mage", character_id: "mage", weapon_id: "fire_staff", map_id: "abandoned_dungeon", modifiers: [{ stat: "enemy_spawn_count_multiplier_add", value: 0.15 }] }
  ],
  weekly_challenges: [
    { challenge_id: "weekly_fixed_pure_survival", name_zh: "每周示例：纯生存", name_en: "Weekly Sample: Pure Survival", character_id: "paladin", weapon_id: "holy_shield", map_id: "abyss_corridor", modifiers: [{ stat: "damage_taken_multiplier_add", value: 0.12 }, { stat: "soul_gain_multiplier_add", value: 0.2 }] }
  ]
};

writeJson("characters.json", { characters });
writeJson("weapons.json", { weapons });
writeJson("status_effects.json", { statuses });
writeJson("enemies.json", { monsters });
writeJson("waves.json", waves);
writeJson("upgrades.json", upgrades);
writeJson("relics.json", relics);
writeJson("maps.json", maps);
writeJson("progression_goals.json", progression);
writeJson("challenges.json", challenges);
writeJson("weapon_branches.json", { branches: [] });
writeJson("weapon_evolutions.json", { evolutions: [] });
