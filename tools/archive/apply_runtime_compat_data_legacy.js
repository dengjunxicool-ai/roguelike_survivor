const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const dataDir = path.join(root, "data");

function readJson(name) {
  return JSON.parse(fs.readFileSync(path.join(dataDir, name), "utf8"));
}

function writeJson(name, value) {
  stripLegacyFields(name, value);
  fs.writeFileSync(path.join(dataDir, name), JSON.stringify(value, null, "\t") + "\n", "utf8");
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

function asOldModifiers(effectList) {
  const map = {
    max_health_multiplier_add: "max_hp_multiplier_add",
    max_health_add: "max_hp_add",
    defense_add: "armor_add",
    pickup_range_multiplier_add: "pickup_radius_multiplier_add",
    pickup_range_add: "pickup_radius_add",
    heal_current: "heal",
    crit_rate_add: "crit_chance_add",
  };
  const modifiers = {};
  for (const effect of effectList || []) {
    const key = map[effect.stat] || effect.stat;
    if (!key) continue;
    modifiers[key] = (modifiers[key] || 0) + Number(effect.value || 0);
  }
  return modifiers;
}

function compatCharacters() {
  const doc = readJson("characters.json");
  for (const character of doc.characters || []) {
    const talent = character.talent || {};
    const trait = character.trait || {};
    character.id = character.id || character.character_id;
    character.display_name = character.display_name || character.name_zh;
    character.description = character.description || character.description_zh;
    character.role = character.role || character.role_zh;
    character.allowed_weapon_ids = character.allowed_weapon_ids || character.allowed_weapons || [];
    character.unlock = character.unlock || character.unlock_condition || { type: "default" };
    character.trait = {
      id: trait.id || talent.talent_id || "",
      display_name: trait.display_name || talent.name_zh || "",
      type: trait.type || talent.type || "",
      params: trait.params || talent.params || {},
    };
    if (character.trait.params.max_stacks === undefined && character.trait.params.max_stack !== undefined) {
      character.trait.params.max_stacks = character.trait.params.max_stack;
    }
    const stats = character.stats || {};
    character.base_stats = character.base_stats || {
      max_hp: stats.hp,
      move_speed: stats.move_speed,
      damage_multiplier: stats.damage_multiplier,
      attack_speed_multiplier: stats.attack_speed_multiplier,
      crit_chance: stats.crit_rate,
      crit_damage: stats.crit_damage,
      armor: stats.defense,
      pickup_radius: stats.pickup_range,
      soul_gain_multiplier: 1.0,
    };
  }
  doc.characters = (doc.characters || []).filter((character) => (character.id || character.character_id) !== "knight");
  writeJson("characters.json", doc);
}

const weaponSkillMap = {
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

function compatWeapons() {
  const doc = readJson("weapons.json");
  for (const weapon of doc.weapons || []) {
    const weaponId = weapon.id || weapon.weapon_id;
    weapon.id = weaponId;
    weapon.display_name = weapon.display_name || weapon.weapon_name_zh;
    weapon.description = weapon.description || weapon.description_zh || weapon.weapon_name_zh;
    weapon.character_id = weapon.character_id || (weapon.allowed_characters || [])[0] || "";
    weapon.starting_skill_id = weapon.starting_skill_id || weaponSkillMap[weaponId] || weapon.primary_attack_id;
    weapon.tags = weapon.tags || weapon.element_tags || [];
    weapon.on_hit_status = weapon.on_hit_status || weapon.base_status_id;
    weapon.weapon_trait = weapon.weapon_trait || {};
    weapon.unlock = weapon.unlock || weapon.unlock_condition || { type: "default" };
    weapon.visual = weapon.visual || {};
    if (!weapon.visual.icon && weapon.cosmetic_slots?.icon) weapon.visual.icon = weapon.cosmetic_slots.icon;
    if (!weapon.visual.texture && weapon.cosmetic_slots?.icon) weapon.visual.texture = weapon.cosmetic_slots.icon;
  }
  doc.weapons = (doc.weapons || []).filter((weapon) => !["spinning_sword_weapon", "guardian_shield", "war_banner"].includes(weapon.id || weapon.weapon_id));
  writeJson("weapons.json", doc);
}

function filterDeletedWeaponSkills() {
  const doc = readJson("primary_attack.json");
  const deletedExact = new Set(["spinning_sword", "greatsword_wall", "blade_storm", "shield_guard", "battle_banner"]);
  const deletedPrefixes = [
    "spinning_sword_weapon_branch_",
    "guardian_shield_branch_",
    "war_banner_branch_",
  ];
  doc.primary_attacks = (doc.primary_attacks || []).filter((skill) => {
    const id = skill.id || "";
    if (deletedExact.has(id)) return false;
    return !deletedPrefixes.some((prefix) => id.startsWith(prefix));
  });
  writeJson("primary_attack.json", doc);
}

const branchNames = {
  burst: ["爆裂", "Burst"],
  rapid: ["急速", "Rapid"],
  lava: ["熔岩", "Lava"],
  soulburn: ["魂燃", "Soulburn"],
  dense: ["密集冰雹", "Dense Hail"],
  lockdown: ["冻结封锁", "Lockdown"],
  shatter: ["碎冰", "Shatter"],
  icicle: ["冰锥", "Icicle"],
  dual_orb: ["双雷球", "Dual Orb"],
  chain: ["连锁", "Chain"],
  lash: ["雷鞭", "Lash"],
  overload_core: ["过载核心", "Overload Core"],
  barrage: ["弹幕", "Barrage"],
  copy: ["复制", "Copy"],
  forbidden: ["禁术", "Forbidden"],
  guardian_page: ["守护书页", "Guardian Page"],
  thousand: ["千刃", "Thousand Blades"],
  execution: ["处决", "Execution"],
  cloudpiercer: ["穿云", "Cloudpiercer"],
  bloodshadow: ["血影", "Bloodshadow"],
  snipe: ["狙击", "Snipe"],
  volley: ["齐射", "Volley"],
  boomerang: ["回返箭", "Boomerang"],
  explosive: ["爆破箭", "Explosive Arrow"],
  blast: ["爆破陷阱", "Blast Trap"],
  toxic_spike: ["毒刺", "Toxic Spike"],
  ice_lock: ["冰锁", "Ice Lock"],
  hunter_mark: ["猎人标记", "Hunter Mark"],
  wall: ["圣墙", "Holy Wall"],
  counter: ["反击", "Counter"],
  purify: ["净化", "Purify"],
  charge: ["盾冲", "Shield Charge"],
  heaven: ["天罚", "Heaven"],
  combo: ["连锤", "Combo"],
  quake: ["震地", "Quake"],
  punish: ["惩戒", "Punish"],
  shelter: ["圣所", "Shelter"],
  judgement: ["审判", "Judgement"],
  purify_field: ["净化圣域", "Purify Field"],
  pulse: ["脉冲", "Pulse"],
  corrosion: ["腐蚀", "Corrosion"],
  toxic_burst: ["毒爆", "Toxic Burst"],
  spread: ["扩散", "Spread"],
  paralyze: ["麻痹", "Paralyze"],
  carpet: ["火毯", "Fire Carpet"],
  detonate: ["引爆", "Detonate"],
  blackfire: ["黑焰", "Blackfire"],
  sticky: ["黏油", "Sticky Oil"],
  pressure: ["高压", "Pressure"],
  fan: ["扇形喷洒", "Fan Spray"],
  melt_armor: ["熔甲", "Melt Armor"],
  acid_burst: ["酸爆", "Acid Burst"],
};

const weaponEvolutionPrefixes = {
  fire_staff: "fire_staff_branch_",
  frost_staff: "frost_staff_branch_",
  lightning_whip: "lightning_whip_branch_",
  spellbook: "spellbook_branch_",
  throwing_knife_belt: "knife_belt_branch_",
  hunter_bow: "hunter_bow_branch_",
  trap_kit: "trap_pack_branch_",
  holy_shield: "holy_shield_weapon_branch_",
  warhammer: "warhammer_branch_",
  cross_relic: "cross_relic_branch_",
  toxic_vial: "toxin_bottle_branch_",
  fire_oil_canister: "fire_oil_canister_branch_",
  acid_sprayer: "acid_sprayer_branch_",
};

function branchKeyFromEvolutionId(evolvedSkillId, prefix) {
  return evolvedSkillId.slice(prefix.length, -"_evolved".length);
}

function compatBranchesAndEvolutions() {
	const skills = readJson("primary_attack.json").primary_attacks || [];
	const weaponsDoc = readJson("weapons.json");
	const skillIds = new Set(skills.map((skill) => skill.id));
	const branches = [];
	const evolutions = [];
	const branchIdsByWeapon = {};

  for (const [weaponId, prefix] of Object.entries(weaponEvolutionPrefixes)) {
    for (const evolvedSkillId of [...skillIds].filter((id) => id.startsWith(prefix) && id.endsWith("_evolved"))) {
      const branchKey = branchKeyFromEvolutionId(evolvedSkillId, prefix);
      const branchId = `${weaponId}_branch_${branchKey}`;
      const [nameZh, nameEn] = branchNames[branchKey] || [branchKey, branchKey];
	      branches.push({
        id: branchId,
        weapon_id: weaponId,
        display_name: nameZh,
        role: "武器倾向",
        description: `${nameZh}方向成长。`,
        rarity: "rare",
        tags: ["weapon", "main_progression"],
        level_path: {
          "2": { display_name: `${nameZh} Lv2`, description: "选择该武器倾向。", rarity: "rare", modifiers: { damage_multiplier_add: 0.08 } },
          "3": { display_name: `${nameZh} Lv3`, description: "强化攻击节奏。", rarity: "rare", modifiers: { attack_speed_multiplier_add: 0.08 } },
          "4": { display_name: `${nameZh} Lv4`, description: "扩大影响范围。", rarity: "epic", modifiers: { skill_area_multiplier_add: 0.1 } },
          "5": { display_name: `${nameZh} Lv5`, description: "解锁终式进化检查。", rarity: "epic", modifiers: { damage_multiplier_add: 0.1 }, enable_evolution_check: true }
        }
	      });
	      if (!branchIdsByWeapon[weaponId]) branchIdsByWeapon[weaponId] = [];
	      branchIdsByWeapon[weaponId].push(branchId);
	      const evolutionId = `${branchId}_evolution`;
      evolutions.push({
        id: evolutionId,
        weapon_id: weaponId,
        branch_id: branchId,
        evolved_skill_id: evolvedSkillId,
        name_zh: `${nameZh}终式`,
        name_en: `${nameEn} Finale`,
        display_name: `${nameZh}终式`,
        description: "武器倾向达到 Lv5 后进化为终式技能。",
        requires: { selected_branch_id: branchId, skill_level: 5, enable_evolution_check: true },
        inherit: { branch_modifiers: true, tags_added: true, events_added: true }
      });
    }
  }

	for (const weapon of weaponsDoc.weapons || []) {
		const weaponId = weapon.id || weapon.weapon_id;
		weapon.branch_ids = branchIdsByWeapon[weaponId] || [];
	}
	writeJson("weapons.json", weaponsDoc);
	writeJson("weapon_branches.json", { branches });
	writeJson("weapon_evolutions.json", { evolutions });
}

function compatEnemies() {
  const doc = readJson("enemies.json");
  for (const monster of doc.monsters || []) {
    monster.id = monster.id || monster.monster_id;
    monster.display_name = monster.display_name || monster.name_zh;
    monster.type = monster.type || monster.rank;
    monster.base_stats = monster.base_stats || {
      max_hp: monster.hp,
      move_speed: monster.move_speed,
      contact_damage: monster.contact_damage,
      armor: monster.defense,
      defense: monster.defense,
      resistances: monster.resistances || {},
      attack_range: monster.behavior_config?.skill_range || 48,
      exp_drop: monster.exp,
      soul_drop: monster.rewards?.souls || 0,
      collision_radius: monster.collision_radius,
    };
    monster.behavior = monster.behavior || Object.assign({ type: monster.behavior_type }, monster.behavior_config || {});
    monster.skills = monster.skills || monster.skill_list || [];
    monster.visual = monster.visual || {};
  }
  writeJson("enemies.json", doc);
}

function compatWaves() {
  const doc = readJson("waves.json");
  for (const wave of doc.waves || []) {
    wave.id = wave.id || wave.wave_id;
    wave.display_name = wave.display_name || wave.name_zh;
    wave.duration_seconds = wave.duration_seconds || Math.max(1, Number(wave.end_time || 0) - Number(wave.start_time || 0));
  }
  writeJson("waves.json", doc);
}

function compatMaps() {
  const doc = readJson("maps.json");
  for (const map of doc.maps || []) {
    map.id = map.id || map.map_id;
    map.display_name = map.display_name || map.name_zh;
    map.description = map.description || map.map_variable?.description_zh || "";
    map.unlock = map.unlock || map.unlock_condition || { type: "default" };
  }
  writeJson("maps.json", doc);
}

function compatUpgrades() {
  const doc = readJson("upgrades.json");
  for (const key of ["curse_choices", "permanent_upgrades", "level_up_upgrades"]) {
    for (const upgrade of doc[key] || []) {
      upgrade.id = upgrade.id || upgrade.upgrade_id;
      upgrade.display_name = upgrade.display_name || upgrade.upgrade_name_zh;
      upgrade.description = upgrade.description || upgrade.ui_description_zh;
      upgrade.enabled = upgrade.enabled ?? true;
      upgrade.base_weight = upgrade.base_weight ?? Number(upgrade.weight_rule?.base || 0);
      upgrade.weight_decay = upgrade.weight_decay ?? Number(upgrade.weight_rule?.decay || 1);
      upgrade.max_level = upgrade.max_level ?? upgrade.max_stack ?? 1;
      upgrade.modifiers = upgrade.modifiers || asOldModifiers(upgrade.effect_list);
      upgrade.level_modifiers = upgrade.level_modifiers || [upgrade.modifiers];
      upgrade.level_descriptions = upgrade.level_descriptions || [upgrade.description || ""];
      if (key === "level_up_upgrades" && (upgrade.tags || []).includes("weapon")) {
        upgrade.skill_modifiers = upgrade.skill_modifiers || upgrade.modifiers;
      }
    }
  }
  writeJson("upgrades.json", doc);
}

function compatStatuses() {
	const doc = readJson("status_effects.json");
	for (const status of doc.statuses || []) {
		status.id = status.id || status.status_id;
		status.display_name = status.display_name || status.name_zh || status.id;
		status.type = status.type || status.status_type;
		status.max_stacks = status.max_stacks ?? status.max_stack ?? 1;
		const effect = status.effect_per_stack || {};
		status.effect = status.effect || {};
		if (status.type === "dot" || effect.damage) {
			status.damage = Number(effect.damage || status.damage || 0);
			status.damage_type = effect.element || status.element || status.id;
			status.effect.dot = true;
		}
		if (effect.move_speed_multiplier_add) {
			status.effect.move_slow_per_stack = Math.abs(Number(effect.move_speed_multiplier_add));
		}
		if (effect.defense_add && Number(effect.defense_add) < 0) {
			status.armor_break_multiplier_add = Math.abs(Number(effect.defense_add)) * 0.03;
		}
		for (const [key, value] of Object.entries(effect)) {
			if (key.endsWith("_vulnerability_add")) {
				const element = key.replace("_vulnerability_add", "");
				status.effect[`${element}_damage_taken_multiplier_add_per_stack`] = Number(value);
			}
			if (key === "crit_rate_taken_add") {
				status.effect.all_damage_taken_multiplier_add_per_stack = Math.max(Number(value) * 0.5, 0);
			}
		}
	}
	writeJson("status_effects.json", doc);
}

function compatRelics() {
  const doc = readJson("relics.json");
  for (const relic of doc.relics || []) {
    relic.id = relic.id || relic.relic_id;
    relic.display_name = relic.display_name || relic.relic_name_zh;
    relic.description = relic.description || relic.ui_description_zh;
    relic.modifiers = relic.modifiers || asOldModifiers(relic.effect_list);
    relic.unlock = relic.unlock || relic.unlock_condition || { type: "default" };
  }
  writeJson("relics.json", doc);
}

compatCharacters();
compatWeapons();
filterDeletedWeaponSkills();
compatBranchesAndEvolutions();
compatEnemies();
compatWaves();
compatMaps();
compatUpgrades();
compatStatuses();
compatRelics();
