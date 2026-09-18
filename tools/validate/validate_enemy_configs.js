const path = require("path");
const { readJsonFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const enemiesPath = path.join(root, "data", "enemies", "enemies.json");
const enemySkillsPath = path.join(root, "data", "enemies", "enemy_skills.json");
const wavesPath = path.join(root, "data", "waves", "waves.json");

const VALID_ENEMY_TYPES = new Set(["normal", "elite", "boss"]);
const VALID_BEHAVIOR_TYPES = new Set([
  "chase_player",
  "keep_distance_and_shoot",
  "explode_near_player",
  "summon_and_chase",
  "chase_and_cast_pool",
  "dash_attack",
  "boss_dungeon_heart",
]);
const VALID_DEATH_EFFECT_TYPES = new Set(["", "poison_pool", "spawn_enemies"]);
const VALID_WAVE_EVENT_TYPES = new Set(["spawn_elite", "final_blessing"]);
const VALID_REWARD_EVENT_TYPES = new Set(["force_level_up"]);
const VALID_ENEMY_SKILL_RUNTIMES = new Set(["active", "boss_phase"]);
const VALID_ENEMY_ACTION_TYPES = new Set([
  "projectile",
  "damage_area",
  "summon",
  "dash",
  "self_explode",
  "ring_projectiles",
  "delayed_area_blast",
  "shockwave",
  "corruption_gaze",
  "corrupted_cores",
  "contact_status",
]);
const REQUIRED_ACTIONS_BY_BEHAVIOR = {
  keep_distance_and_shoot: ["projectile"],
  explode_near_player: ["self_explode"],
  summon_and_chase: ["summon"],
  chase_and_cast_pool: ["damage_area"],
};
const VALID_MULTIPLIER_KEYS = new Set(["hp", "damage", "speed", "move_speed", "exp", "defense_add"]);
const VALID_DEATH_POLICY_CAUSES = new Set(["default", "damage", "self_explosion"]);
const VALID_DEATH_POLICY_KEYS = new Set([
  "play_death_visual",
  "record_boss_core",
  "award_soul",
  "notify_kill_events",
  "emit_died_signal",
  "run_death_effect",
  "drop_experience",
]);
const ENEMY_ACTION_PARAM_SCHEMAS = {
  projectile: {
    required: ["element", "damage_type"],
    string: ["element", "damage_type"],
    number: ["damage", "speed", "pierce", "radius", "lifetime", "spawn_offset", "projectile_speed", "projectile_pierce", "projectile_radius", "projectile_lifetime", "projectile_spawn_offset"],
    object: ["visual", "projectile_visual"],
    array: ["visual_color", "projectile_color"],
  },
  damage_area: {
    required: ["duration", "tick_interval", "radius", "element", "damage_type"],
    string: ["element", "damage_type"],
    number: ["damage", "duration", "tick_interval", "radius", "area_radius"],
    array: ["visual_color"],
  },
  summon: {
    required: ["enemy_id", "count", "radius"],
    string: ["enemy_id"],
    number: ["count", "radius", "spawn_radius"],
  },
  contact_status: {
    required: ["status_id", "duration", "damage", "tick_interval", "stack"],
    string: ["status_id"],
    number: ["duration", "damage", "tick_interval", "stack", "max_stacks"],
    object: ["status_params"],
  },
  self_explode: {},
  dash: {},
  ring_projectiles: {
    required: ["element", "damage_type"],
    string: ["element", "damage_type"],
    number: ["damage", "projectile_count", "count", "speed", "radius", "projectile_radius", "pierce", "safe_gap_count", "safe_gap_start"],
    array: ["visual_color"],
  },
  delayed_area_blast: {
    required: ["element", "damage_type"],
    string: ["element", "damage_type"],
    number: ["damage", "radius", "delay", "duration", "tick_interval"],
    array: ["visual_color"],
  },
  shockwave: {
    required: ["element", "damage_type"],
    string: ["element", "damage_type"],
    number: ["damage", "radius", "warning_time", "duration", "tick_interval"],
    array: ["visual_color"],
  },
  corruption_gaze: {
    required: ["element", "damage_type"],
    string: ["element", "damage_type"],
    number: ["damage", "radius", "delay", "duration", "tick_interval"],
    array: ["visual_color"],
  },
  corrupted_cores: {
    required: ["count", "hp"],
    number: ["count", "hp"],
  },
};

const REQUIRED_BASE_STATS = [
  "max_hp",
  "move_speed",
  "contact_damage",
  "attack_range",
  "exp_drop",
  "soul_drop",
  "collision_radius",
];

const errors = [];
const warnings = [];

function location(parts) {
  return parts.filter(Boolean).join(".");
}

function error(where, message) {
  errors.push(`${where}: ${message}`);
}

function warn(where, message) {
  warnings.push(`${where}: ${message}`);
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function getArray(value) {
  return Array.isArray(value) ? value : [];
}

function checkNumber(where, object, key, required = false) {
  if (!Object.prototype.hasOwnProperty.call(object, key)) {
    if (required) {
      error(where, `missing required number '${key}'`);
    }
    return;
  }
  if (typeof object[key] !== "number") {
    error(where, `'${key}' must be a number`);
  }
}

function checkBoolean(where, object, key, required = false) {
  if (!Object.prototype.hasOwnProperty.call(object, key)) {
    if (required) {
      error(where, `missing required boolean '${key}'`);
    }
    return;
  }
  if (typeof object[key] !== "boolean") {
    error(where, `'${key}' must be a boolean`);
  }
}

function checkString(where, object, key, required = false) {
  if (!Object.prototype.hasOwnProperty.call(object, key)) {
    if (required) {
      error(where, `missing required string '${key}'`);
    }
    return;
  }
  if (typeof object[key] !== "string" || object[key] === "") {
    error(where, `'${key}' must be a non-empty string`);
  }
}

function checkArray(where, object, key, required = false) {
  if (!Object.prototype.hasOwnProperty.call(object, key)) {
    if (required) {
      error(where, `missing required array '${key}'`);
    }
    return;
  }
  if (!Array.isArray(object[key])) {
    error(where, `'${key}' must be an array`);
  }
}

function checkEnemyDefinitions(enemies, enemySkillById) {
  if (!Array.isArray(enemies)) {
    error("enemies.monsters", "must be an array");
    return new Map();
  }

  const enemyById = new Map();
  for (let index = 0; index < enemies.length; index += 1) {
    const enemy = enemies[index];
    const where = `enemies.monsters[${index}]`;
    if (!isObject(enemy)) {
      error(where, "must be an object");
      continue;
    }

    const id = String(enemy.id || "");
    const enemyWhere = id ? `enemy:${id}` : where;
    if (!id) {
      error(where, "missing non-empty id");
    } else if (enemyById.has(id)) {
      error(enemyWhere, "duplicate enemy id");
    } else {
      enemyById.set(id, enemy);
    }

    const type = String(enemy.type || "");
    if (!VALID_ENEMY_TYPES.has(type)) {
      error(enemyWhere, `invalid type '${type}', expected one of ${[...VALID_ENEMY_TYPES].join(", ")}`);
    }

    const baseStats = enemy.base_stats;
    if (!isObject(baseStats)) {
      error(enemyWhere, "base_stats must be an object");
    } else {
      for (const key of REQUIRED_BASE_STATS) {
        checkNumber(`${enemyWhere}.base_stats`, baseStats, key, true);
      }
      if (isObject(baseStats.resistances) === false && Object.prototype.hasOwnProperty.call(baseStats, "resistances")) {
        error(`${enemyWhere}.base_stats`, "resistances must be an object when present");
      }
      if (
        Object.prototype.hasOwnProperty.call(baseStats, "contact_interval") &&
        Object.prototype.hasOwnProperty.call(baseStats, "damage_interval") &&
        Number(baseStats.contact_interval) !== Number(baseStats.damage_interval)
      ) {
        warn(`${enemyWhere}.base_stats`, "contact_interval and damage_interval differ; runtime uses contact_interval first");
      }
    }

    if (
      Object.prototype.hasOwnProperty.call(enemy, "contact_interval") &&
      Object.prototype.hasOwnProperty.call(enemy, "damage_interval") &&
      Number(enemy.contact_interval) !== Number(enemy.damage_interval)
    ) {
      warn(enemyWhere, "top-level contact_interval and damage_interval differ; runtime uses contact_interval first");
    }

    const behavior = isObject(enemy.behavior) ? enemy.behavior : null;
    let behaviorType = "";
    if (!behavior) {
      error(`${enemyWhere}.behavior`, "must be an object with required type");
    } else {
      checkString(`${enemyWhere}.behavior`, behavior, "type", true);
      behaviorType = String(behavior.type || "");
    }
    if (behaviorType !== "" && !VALID_BEHAVIOR_TYPES.has(behaviorType)) {
      error(`${enemyWhere}.behavior`, `unknown behavior.type '${behaviorType}'`);
    }
    if (behavior && behaviorType === "boss_dungeon_heart") {
      checkBossBehaviorConfig(`${enemyWhere}.behavior`, behavior, enemySkillById);
    }

    const deathEffect = enemy.death_effect;
    if (deathEffect !== undefined) {
      if (!isObject(deathEffect)) {
        error(`${enemyWhere}.death_effect`, "must be an object when present");
      } else {
        const effectType = String(deathEffect.type || "");
        if (!VALID_DEATH_EFFECT_TYPES.has(effectType)) {
          error(`${enemyWhere}.death_effect`, `unknown death_effect.type '${effectType}'`);
        }
      }
    }

    if (enemy.skills !== undefined && !Array.isArray(enemy.skills)) {
      error(`${enemyWhere}.skills`, "must be an array when present");
    } else if (Array.isArray(enemy.skills)) {
      checkEnemySkillRefs(`${enemyWhere}.skills`, enemy.skills, enemySkillById);
      if (behaviorType === "boss_dungeon_heart") {
        checkBossSkillRefs(`${enemyWhere}.skills`, enemy.skills, enemySkillById);
      }
    }
    checkRequiredBehaviorActions(`${enemyWhere}.skills`, behaviorType, Array.isArray(enemy.skills) ? enemy.skills : [], enemySkillById);

    checkDeathPolicy(`${enemyWhere}.death_policy`, enemy.death_policy);
  }

  return enemyById;
}

function checkRequiredBehaviorActions(where, behaviorType, skills, enemySkillById) {
  const requiredActions = REQUIRED_ACTIONS_BY_BEHAVIOR[behaviorType] || [];
  for (const actionType of requiredActions) {
    if (!enemySkillsContainAction(skills, actionType, enemySkillById)) {
      error(where, `behavior '${behaviorType}' requires an enemy skill action '${actionType}'`);
    }
  }
}

function enemySkillsContainAction(skills, actionType, enemySkillById) {
  for (const skillRef of skills) {
    if (!isObject(skillRef)) {
      continue;
    }
    const skillId = String(skillRef.skill_id || skillRef.id || "");
    const definition = enemySkillById.get(skillId);
    if (!definition || !Array.isArray(definition.actions)) {
      continue;
    }
    for (const action of definition.actions) {
      if (isObject(action) && String(action.type || "") === actionType) {
        return true;
      }
    }
  }
  return false;
}

function checkBossSkillRefs(where, skills, enemySkillById) {
  for (let index = 0; index < skills.length; index += 1) {
    const skillRef = skills[index];
    if (!isObject(skillRef)) {
      continue;
    }
    const skillId = String(skillRef.skill_id || skillRef.id || "");
    if (!enemySkillById.has(skillId)) {
      continue;
    }
    const skill = enemySkillById.get(skillId);
    if (String(skill.runtime || "active") !== "boss_phase") {
      error(`${where}[${index}]`, `boss_dungeon_heart skill '${skillId}' must use runtime='boss_phase'`);
    }
  }
}

function checkBossBehaviorConfig(where, behavior, enemySkillById) {
  if (Object.prototype.hasOwnProperty.call(behavior, "phase_thresholds")) {
    error(where, "phase_thresholds is no longer supported; configure explicit phases");
  }
  if (!Array.isArray(behavior.phases) || behavior.phases.length === 0) {
    error(where, "boss_dungeon_heart requires non-empty phases");
    return;
  }
  for (let phaseIndex = 0; phaseIndex < behavior.phases.length; phaseIndex += 1) {
    const phase = behavior.phases[phaseIndex];
    const phaseWhere = `${where}.phases[${phaseIndex}]`;
    if (!isObject(phase)) {
      error(phaseWhere, "must be an object");
      continue;
    }
    checkNumber(phaseWhere, phase, "hp_percent_min", true);
    checkNumber(phaseWhere, phase, "hp_percent_max", true);
    checkNumber(phaseWhere, phase, "max_concurrent_skills", true);
    if (!Array.isArray(phase.skills) || phase.skills.length === 0) {
      error(`${phaseWhere}.skills`, "must be a non-empty array");
      continue;
    }
    for (let skillIndex = 0; skillIndex < phase.skills.length; skillIndex += 1) {
      const skill = phase.skills[skillIndex];
      const skillWhere = `${phaseWhere}.skills[${skillIndex}]`;
      if (!isObject(skill)) {
        error(skillWhere, "must be an object");
        continue;
      }
      checkString(skillWhere, skill, "skill_id", true);
      checkNumber(skillWhere, skill, "cooldown", true);
      const skillId = String(skill.skill_id || "");
      if (!enemySkillById.has(skillId)) {
        error(`${skillWhere}.skill_id`, `references missing enemy skill '${skillId}'`);
        continue;
      }
      const definition = enemySkillById.get(skillId);
      if (String(definition.runtime || "active") !== "boss_phase") {
        error(`${skillWhere}.skill_id`, `references '${skillId}' but it is not runtime='boss_phase'`);
      }
      if (skill.type !== undefined && !VALID_ENEMY_ACTION_TYPES.has(String(skill.type))) {
        error(`${skillWhere}.type`, `unknown boss phase action type '${skill.type}'`);
      }
    }
  }
}

function checkEnemySkillDefinitions(document) {
  const skills = getArray(document.enemy_skills);
  if (!Array.isArray(document.enemy_skills)) {
    error("enemy_skills.enemy_skills", "must be an array");
  }

  const skillById = new Map();
  for (let index = 0; index < skills.length; index += 1) {
    const skill = skills[index];
    const where = `enemy_skills[${index}]`;
    if (!isObject(skill)) {
      error(where, "must be an object");
      continue;
    }

    const id = String(skill.id || "");
    const skillWhere = id ? `enemy_skill:${id}` : where;
    if (!id) {
      error(where, "missing non-empty id");
    } else if (skillById.has(id)) {
      error(skillWhere, "duplicate enemy skill id");
    } else {
      skillById.set(id, skill);
    }

    const runtime = String(skill.runtime || "active");
    if (!VALID_ENEMY_SKILL_RUNTIMES.has(runtime)) {
      error(skillWhere, `invalid runtime '${runtime}', expected one of ${[...VALID_ENEMY_SKILL_RUNTIMES].join(", ")}`);
    }
    if (skill.cooldown !== undefined && typeof skill.cooldown !== "number") {
      error(`${skillWhere}.cooldown`, "must be a number when present");
    }
    checkEnemyActions(`${skillWhere}.actions`, skill.actions);
    if (!Array.isArray(skill.actions) || skill.actions.length === 0) {
      error(`${skillWhere}.actions`, "must define at least one executable action");
    }
  }

  return skillById;
}

function checkEnemyActions(where, actionsValue) {
  if (actionsValue === undefined) {
    return;
  }
  if (!Array.isArray(actionsValue)) {
    error(where, "must be an array when present");
    return;
  }
  for (let index = 0; index < actionsValue.length; index += 1) {
    const action = actionsValue[index];
    const actionWhere = `${where}[${index}]`;
    if (!isObject(action)) {
      error(actionWhere, "must be an object");
      continue;
    }
    const type = String(action.type || "");
    if (!VALID_ENEMY_ACTION_TYPES.has(type)) {
      error(actionWhere, `unknown enemy action type '${type}'`);
    }
    if (action.params !== undefined && !isObject(action.params)) {
      error(`${actionWhere}.params`, "must be an object when present");
      continue;
    }
    checkEnemyActionParams(actionWhere, type, isObject(action.params) ? action.params : {});
  }
}

function checkEnemyActionParams(where, type, params) {
  const schema = ENEMY_ACTION_PARAM_SCHEMAS[type] || {};
  for (const key of schema.required || []) {
    if (!Object.prototype.hasOwnProperty.call(params, key)) {
      error(`${where}.params`, `missing required '${key}' for action '${type}'`);
    }
  }
  for (const key of schema.string || []) {
    if (Object.prototype.hasOwnProperty.call(params, key) && (typeof params[key] !== "string" || params[key] === "")) {
      error(`${where}.params.${key}`, "must be a non-empty string");
    }
  }
  for (const key of schema.number || []) {
    if (Object.prototype.hasOwnProperty.call(params, key) && typeof params[key] !== "number") {
      error(`${where}.params.${key}`, "must be a number");
    }
  }
  for (const key of schema.object || []) {
    if (Object.prototype.hasOwnProperty.call(params, key) && !isObject(params[key])) {
      error(`${where}.params.${key}`, "must be an object");
    }
  }
  for (const key of schema.array || []) {
    if (Object.prototype.hasOwnProperty.call(params, key) && !Array.isArray(params[key])) {
      error(`${where}.params.${key}`, "must be an array");
    }
  }
}

function checkEnemySkillRefs(where, skills, enemySkillById) {
  for (let index = 0; index < skills.length; index += 1) {
    const skillRef = skills[index];
    const skillWhere = `${where}[${index}]`;
    if (!isObject(skillRef)) {
      error(skillWhere, "must be an object");
      continue;
    }
    const skillId = String(skillRef.skill_id || skillRef.id || "");
    if (!skillId) {
      error(skillWhere, "missing skill_id");
      continue;
    }
    if (!enemySkillById.has(skillId)) {
      error(skillWhere, `references missing enemy skill '${skillId}'`);
    }
    if (skillRef.cooldown !== undefined && typeof skillRef.cooldown !== "number") {
      error(`${skillWhere}.cooldown`, "must be a number when present");
    }
  }
}

function checkDeathPolicy(where, deathPolicy) {
  if (deathPolicy === undefined) {
    return;
  }
  if (!isObject(deathPolicy)) {
    error(where, "must be an object when present");
    return;
  }
  for (const [cause, policy] of Object.entries(deathPolicy)) {
    const policyWhere = `${where}.${cause}`;
    if (!VALID_DEATH_POLICY_CAUSES.has(cause)) {
      warn(policyWhere, `unknown death policy cause '${cause}'`);
    }
    if (!isObject(policy)) {
      error(policyWhere, "must be an object");
      continue;
    }
    for (const [key, value] of Object.entries(policy)) {
      if (!VALID_DEATH_POLICY_KEYS.has(key)) {
        warn(policyWhere, `unknown death policy key '${key}'`);
      }
      if (typeof value !== "boolean") {
        error(`${policyWhere}.${key}`, "must be a boolean");
      }
    }
  }
}

function checkWaveDefinitions(waveConfig, enemyById) {
  checkSpawnRules(waveConfig.spawn_rules);
  const waves = getArray(waveConfig.waves);
  if (!Array.isArray(waveConfig.waves)) {
    error("waves.waves", "must be an array");
  }

  for (let index = 0; index < waves.length; index += 1) {
    const wave = waves[index];
    const waveId = String(wave.id || `index_${index}`);
    const where = `wave:${waveId}`;
    if (!isObject(wave)) {
      error(`waves.waves[${index}]`, "must be an object");
      continue;
    }

    if (waveId === "boss_minions") {
      error(where, "must not remain as a normal wave; migrate to boss_event.minion_spawn");
    }

    checkNumber(where, wave, "spawn_interval");
    checkNumber(where, wave, "max_alive");
    checkNumber(where, wave, "duration_seconds");

    checkMultipliers(`${where}.enemy_multipliers`, wave.enemy_multipliers);
    checkGroups(`${where}.groups`, wave.groups, enemyById);
    checkEvents(`${where}.events`, wave.events, enemyById);
  }

  const bossEvent = waveConfig.boss_event;
  if (!isObject(bossEvent)) {
    error("waves.boss_event", "must be an object");
    return;
  }

  const bossId = String(bossEvent.boss_id || bossEvent.enemy_id || "");
  if (!bossId) {
    error("waves.boss_event", "missing boss_id");
  } else if (!enemyById.has(bossId)) {
    error("waves.boss_event", `boss_id '${bossId}' does not exist`);
  } else if (String(enemyById.get(bossId).type || "") !== "boss") {
    error("waves.boss_event", `boss_id '${bossId}' must reference type=boss`);
  }
  checkNumber("waves.boss_event", bossEvent, "spawn_time");
  checkNumber("waves.boss_event", bossEvent, "souls_reward");
  checkNumber("waves.boss_event", bossEvent, "gold_reward");
  checkBoolean("waves.boss_event", bossEvent, "clear_normal_enemies_on_spawn");
  checkBossFairness("waves.boss_event.fairness", bossEvent.fairness);
  checkMultipliers("waves.boss_event.boss_multipliers", bossEvent.boss_multipliers);

  if (bossEvent.minion_spawn !== undefined) {
    if (!isObject(bossEvent.minion_spawn)) {
      error("waves.boss_event.minion_spawn", "must be an object when present");
    } else {
      checkBoolean("waves.boss_event.minion_spawn", bossEvent.minion_spawn, "enabled", true);
      checkNumber("waves.boss_event.minion_spawn", bossEvent.minion_spawn, "spawn_interval", bossEvent.minion_spawn.enabled === true);
      checkNumber("waves.boss_event.minion_spawn", bossEvent.minion_spawn, "max_alive", bossEvent.minion_spawn.enabled === true);
      if (bossEvent.minion_spawn.enabled === true) {
        if (Number(bossEvent.minion_spawn.max_alive) <= 0) {
          error("waves.boss_event.minion_spawn.max_alive", "must be greater than 0 when enabled");
        }
        if (Number(bossEvent.minion_spawn.spawn_interval) <= 0) {
          error("waves.boss_event.minion_spawn.spawn_interval", "must be greater than 0 when enabled");
        }
      checkGroups("waves.boss_event.minion_spawn.groups", bossEvent.minion_spawn.groups, enemyById);
      checkMultipliers("waves.boss_event.minion_spawn.enemy_multipliers", bossEvent.minion_spawn.enemy_multipliers);
      }
    }
  }
  checkRewards("waves.rewards", waveConfig.rewards);
}

function checkSpawnRules(spawnRules) {
  const where = "waves.spawn_rules";
  if (!isObject(spawnRules)) {
    error(where, "must be an object");
    return;
  }
  for (const key of [
    "spawn_batch_interval_seconds",
    "max_spawn_batch_size",
    "spawn_warning_duration_seconds",
    "visible_spawn_margin",
    "spawn_player_safe_radius",
  ]) {
    checkNumber(where, spawnRules, key, true);
  }
  if (Number(spawnRules.spawn_batch_interval_seconds) < 15) {
    error(`${where}.spawn_batch_interval_seconds`, "must be at least 15 seconds");
  }
  const maxBatchSize = Number(spawnRules.max_spawn_batch_size);
  if (!Number.isInteger(maxBatchSize) || maxBatchSize < 1 || maxBatchSize > 15) {
    error(`${where}.max_spawn_batch_size`, "must be an integer from 1 to 15");
  }
  if (Number(spawnRules.spawn_warning_duration_seconds) <= 0) {
    error(`${where}.spawn_warning_duration_seconds`, "must be greater than 0");
  }
  if (Number(spawnRules.visible_spawn_margin) < 0) {
    error(`${where}.visible_spawn_margin`, "must not be negative");
  }
  if (Number(spawnRules.spawn_player_safe_radius) < 0) {
    error(`${where}.spawn_player_safe_radius`, "must not be negative");
  }
}

function checkBossFairness(where, fairness) {
  if (fairness === undefined) {
    return;
  }
  if (!isObject(fairness)) {
    error(where, "must be an object when present");
    return;
  }
  checkBoolean(where, fairness, "warning_required");
  checkNumber(where, fairness, "max_concurrent_major_mechanics");
  checkNumber(where, fairness, "overlap_damage_protection_seconds");
}

function checkRewards(where, rewards) {
  if (rewards === undefined) {
    return;
  }
  if (!isObject(rewards)) {
    error(where, "must be an object when present");
    return;
  }
  checkNumber(where, rewards, "base_gold");
  checkNumber(where, rewards, "boss_gold");
  checkNumber(where, rewards, "boss_souls");
  if (rewards.wave_clear_rewards !== undefined) {
    if (!Array.isArray(rewards.wave_clear_rewards)) {
      error(`${where}.wave_clear_rewards`, "must be an array when present");
      return;
    }
    for (let index = 0; index < rewards.wave_clear_rewards.length; index += 1) {
      const event = rewards.wave_clear_rewards[index];
      const eventWhere = `${where}.wave_clear_rewards[${index}]`;
      if (!isObject(event)) {
        error(eventWhere, "must be an object");
        continue;
      }
      const type = String(event.type || "");
      if (!VALID_REWARD_EVENT_TYPES.has(type)) {
        error(eventWhere, `unknown reward event type '${type}'`);
      }
      checkNumber(eventWhere, event, "time", true);
      checkString(eventWhere, event, "announcement");
    }
  }
}

function checkEnemySkillActionReferences(enemySkillById, enemyById) {
  for (const [skillId, skill] of enemySkillById.entries()) {
    const actions = getArray(skill.actions);
    for (let index = 0; index < actions.length; index += 1) {
      const action = actions[index];
      if (!isObject(action)) {
        continue;
      }
      const type = String(action.type || "");
      const params = isObject(action.params) ? action.params : {};
      const where = `enemy_skill:${skillId}.actions[${index}]`;
      if (type === "summon") {
        const enemyId = String(params.enemy_id || "");
        if (enemyId && !enemyById.has(enemyId)) {
          error(`${where}.params.enemy_id`, `references missing enemy '${enemyId}'`);
        }
      }
    }
  }
}

function checkGroups(where, groupsValue, enemyById) {
  if (groupsValue === undefined) {
    warn(where, "missing groups; no enemies can spawn from this source");
    return;
  }
  if (!Array.isArray(groupsValue)) {
    error(where, "must be an array");
    return;
  }

  for (let index = 0; index < groupsValue.length; index += 1) {
    const group = groupsValue[index];
    const groupWhere = `${where}[${index}]`;
    if (!isObject(group)) {
      error(groupWhere, "must be an object");
      continue;
    }
    checkNumber(groupWhere, group, "weight");

    const enemyIds = Array.isArray(group.enemy_ids)
      ? group.enemy_ids
      : group.enemy_id
        ? [group.enemy_id]
        : [];
    if (enemyIds.length === 0) {
      error(groupWhere, "missing enemy_ids or enemy_id");
    }
    for (const rawId of enemyIds) {
      const enemyId = String(rawId || "");
      if (!enemyById.has(enemyId)) {
        error(groupWhere, `enemy id '${enemyId}' does not exist`);
      }
    }
  }
}

function checkEvents(where, eventsValue, enemyById) {
  if (eventsValue === undefined) {
    return;
  }
  if (!Array.isArray(eventsValue)) {
    error(where, "must be an array when present");
    return;
  }
  for (let index = 0; index < eventsValue.length; index += 1) {
    const event = eventsValue[index];
    const eventWhere = `${where}[${index}]`;
    if (!isObject(event)) {
      error(eventWhere, "must be an object");
      continue;
    }
    const type = String(event.type || "");
    if (!VALID_WAVE_EVENT_TYPES.has(type)) {
      warn(eventWhere, `unknown event type '${type}' will not execute in current runtime`);
    }
    if (event.enemy_id !== undefined) {
      const enemyId = String(event.enemy_id || "");
      if (!enemyById.has(enemyId)) {
        error(eventWhere, `enemy_id '${enemyId}' does not exist`);
      } else if (type === "spawn_elite" && String(enemyById.get(enemyId).type || "") !== "elite") {
        warn(eventWhere, `spawn_elite references '${enemyId}' whose type is '${enemyById.get(enemyId).type}'`);
      }
    }
    checkMultipliers(`${eventWhere}.enemy_multipliers`, event.enemy_multipliers);
  }
}

function checkMultipliers(where, multipliers) {
  if (multipliers === undefined) {
    return;
  }
  if (!isObject(multipliers)) {
    error(where, "must be an object when present");
    return;
  }
  for (const [key, value] of Object.entries(multipliers)) {
    if (!VALID_MULTIPLIER_KEYS.has(key)) {
      warn(where, `unknown multiplier '${key}'`);
    }
    if (typeof value !== "number") {
      error(location([where, key]), "must be a number");
    }
  }
}

function main() {
  const enemiesDocument = readJsonFile(enemiesPath);
  const enemySkillsDocument = readJsonFile(enemySkillsPath);
  const waveConfig = readJsonFile(wavesPath);
  const enemySkillById = checkEnemySkillDefinitions(enemySkillsDocument);
  const enemyById = checkEnemyDefinitions(enemiesDocument.monsters, enemySkillById);
  checkEnemySkillActionReferences(enemySkillById, enemyById);
  checkWaveDefinitions(waveConfig, enemyById);

  for (const issue of errors) {
    console.error(`ERROR ${issue}`);
  }
  for (const issue of warnings) {
    console.warn(`WARN  ${issue}`);
  }

  if (errors.length > 0) {
    process.exitCode = 1;
    return;
  }

  console.log(`Enemy config validation passed: ${enemyById.size} enemies, ${enemySkillById.size} enemy skills, ${getArray(waveConfig.waves).length} waves.`);
  if (warnings.length > 0) {
    console.log(`${warnings.length} warning(s) reported; warnings are non-fatal.`);
  }
}

main();
