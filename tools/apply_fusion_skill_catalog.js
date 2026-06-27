const fs = require("fs");
const path = require("path");
const { extractNumericSpec, parseFusionNumericRows } = require("./fusion_skill_numeric_spec");

const root = path.resolve(__dirname, "..");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, ""));
}

function writeJson(relativePath, value) {
  fs.writeFileSync(path.join(root, relativePath), JSON.stringify(value, null, "\t") + "\n", "utf8");
}

function loadExpectedFusionRows() {
  const text = fs.readFileSync(path.join(root, "tools/verify/verify_fusion_skill_system_contract.js"), "utf8");
  const match = /const expected = (\[[\s\S]*?\]);/.exec(text);
  if (!match) {
    throw new Error("Unable to read expected fusion catalog from verify_fusion_skill_system_contract.js");
  }
  return Function(`"use strict"; return ${match[1]};`)();
}

const DAMAGE_BY_SCHOOL = {
  fire: "fire",
  frost: "frost",
  thunder: "thunder",
  curse: "curse",
  holy: "holy",
  chaos: "arcane",
};

const ELEMENT_BY_SCHOOL = {
  fire: "fire",
  frost: "ice",
  thunder: "lightning",
  curse: "arcane",
  holy: "holy",
  chaos: "arcane",
};

const STATUS_DURATIONS = {
  burning: 4.0,
  chilled: 6.0,
  frozen: 1.2,
  conductive: 5.0,
  cursed: 3.0,
  judgment: 6.0,
  instability: 6.0,
};

function makeOfferRule(school, fusionSchool) {
  return {
    required_schools: [school, fusionSchool],
    required_skills: [],
    blocked_by_exclusive_group: [],
    required_min_skill_count: {
      [school]: 2,
      [fusionSchool]: 1,
    },
  };
}

function makeFusionSkill(row, numericRow) {
  const [id, name, school, fusionSchool, description] = row;
  return {
    id,
    name,
    school,
    fusion_school: fusionSchool,
    type: "fusion",
    rarity: "normal",
    max_level: 2,
    exclusive_group: null,
    tags: Array.from(new Set(["fusion", school, fusionSchool, ...statusTags(`${numericRow.triggerText}；${numericRow.numericText}`), ...mechanicTags(numericRow)])),
    mechanic_family: id.replace(/^fusion_/, "fusion_"),
    offer_rule: makeOfferRule(school, fusionSchool),
    trigger_rules: makeTriggerRules(id, school, fusionSchool, numericRow),
    effects: [],
    description,
  };
}

function statusTags(text) {
  const tags = [];
  for (const status of Object.keys(STATUS_DURATIONS)) {
    const label = status[0].toUpperCase() + status.slice(1);
    if (text.includes(label)) {
      tags.push(`status_${status}`);
    }
  }
  return tags;
}

function mechanicTags(numericRow) {
  const text = `${numericRow.triggerText}；${numericRow.numericText}`;
  const tags = [];
  if (/区|区域|地面|路径|结界|裂隙|雷线|冰柱|法阵|冲击|爆/.test(text)) {
    tags.push("area");
  }
  if (/弹|碎片|碎冰|余烬|电弧|光束|落雷|飞出|发射|喷出|冰片/.test(text)) {
    tags.push("projectile");
  }
  if (/护盾/.test(text)) {
    tags.push("shield");
  }
  return tags;
}

function makeTriggerRules(id, school, fusionSchool, numericRow) {
  const spec = extractNumericSpec(numericRow);
  const trigger = triggerFor(numericRow.triggerText);
  const baseRule = {
    trigger,
    cooldown: spec.cooldowns[0] ?? defaultCooldown(numericRow.triggerText),
    conditions: conditionsFor(numericRow, school, fusionSchool, trigger),
    effects: effectsFor(id, school, fusionSchool, numericRow, spec),
  };
  if (baseRule.cooldown <= 0) {
    delete baseRule.cooldown;
  }
  if (baseRule.conditions.length === 0) {
    delete baseRule.conditions;
  }

  const rules = [baseRule];
  if (numericRow.triggerText.includes("护盾破裂") && trigger !== "shield_broken") {
    rules.push({
      trigger: "shield_broken",
      cooldown: spec.cooldowns[0] ?? 1.0,
      effects: effectsFor(`${id}_shield_break`, school, fusionSchool, numericRow, spec, { shieldBreak: true }),
    });
  }
  return rules;
}

function triggerFor(text) {
  if (/^每\s*[0-9.]+s$/.test(text.trim())) {
    return "always";
  }
  if (text.includes("获得护盾") || text.includes("玩家获得护盾")) {
    return "shield_gained";
  }
  if (text.includes("护盾破裂")) {
    return "shield_broken";
  }
  if (text.includes("Overload") || text.includes("神罚") || text.includes("裂变")) {
    return "status_max_stack_reached";
  }
  if (text.includes("tick") || text.includes("结算")) {
    return "status_tick";
  }
  if (text.includes("死亡") || text.includes("击杀") || text.includes("碎裂")) {
    return "enemy_death";
  }
  if (/进入|站在|覆盖|地面|区域|结界|裂隙|路径|接触|穿过|附近/.test(text)) {
    return "area_tick";
  }
  return "post_damage_hit";
}

function defaultCooldown(text) {
  const each = /^每\s*([0-9.]+)s$/.exec(text.trim());
  if (each) {
    return Number(each[1]);
  }
  if (text.includes("短时间")) {
    return 0.5;
  }
  return 0.3;
}

function conditionsFor(numericRow, school, fusionSchool, trigger) {
  const text = `${numericRow.triggerText}；${numericRow.numericText}`;
  const conditions = [];
  if (trigger === "status_max_stack_reached") {
    if (text.includes("Overload")) {
      conditions.push({ type: "event_status_is", status: "conductive" });
    } else if (text.includes("神罚")) {
      conditions.push({ type: "event_status_is", status: "judgment" });
    } else if (text.includes("Instability") && text.includes("裂变")) {
      conditions.push({ type: "event_status_is", status: "instability" });
    }
  }
  if (trigger === "status_tick") {
    if (text.includes("Burning tick") || text.includes("Burning 每次")) {
      conditions.push({ type: "event_status_is", status: "burning" });
    } else if (text.includes("Cursed 结算")) {
      conditions.push({ type: "event_status_is", status: "cursed" });
    }
  }
  for (const status of Object.keys(STATUS_DURATIONS)) {
    if (statusIsPrecondition(text, status)) {
      conditions.push({ type: "target_has_status", status });
    }
  }
  const sourceTag = sourceAreaTagFor(text);
  if (trigger === "area_tick" && sourceTag !== "") {
    conditions.push({ type: "source_has_tag", tag: sourceTag });
  }
  const sourceSchool = sourceSchoolFor(text, school, fusionSchool);
  if (trigger === "post_damage_hit" && sourceSchool !== "") {
    conditions.push({ type: "damage_element_is", element: ELEMENT_BY_SCHOOL[sourceSchool] ?? sourceSchool });
  } else if (trigger !== "area_tick" && sourceSchool !== "" && !conditions.some((condition) => condition.type === "damage_element_is")) {
    conditions.push({ type: "skill_has_tag", tag: sourceSchool });
  }
  return dedupeConditions(conditions);
}

function statusIsPrecondition(text, status) {
  const label = status[0].toUpperCase() + status.slice(1);
  const patterns = [
    new RegExp(`${label}\\s*(敌人|目标|身上|中|期间|且|被|触发)`),
    new RegExp(`(敌人|目标|身上|带有|仍在|命中|消耗|缩短|转移|复制|站在|进入|被)\\s*${label}`),
  ];
  return patterns.some((pattern) => pattern.test(text));
}

function sourceAreaTagFor(text) {
  if (/火焰地面|火焰路径|燃烧地面|熔岩|火地/.test(text)) {
    return "fire_area";
  }
  if (/冰霜区域|冰区|冰霜路径/.test(text)) {
    return "frost_area";
  }
  if (/雷球|雷暴/.test(text)) {
    return "thunder_area";
  }
  if (/神圣结界|圣光/.test(text)) {
    return "holy_area";
  }
  if (/裂隙|虚空/.test(text)) {
    return "chaos_area";
  }
  return "";
}

function sourceSchoolFor(text, school, fusionSchool) {
  if (/火焰技能|火焰击杀|火焰弹体|流星|熔岩|火焰/.test(text)) {
    return "fire";
  }
  if (/冰系技能|冰片|冰矛|冰霜|Frozen 碎裂/.test(text)) {
    return "frost";
  }
  if (/雷电|连锁闪电|雷球|落雷|Overload/.test(text)) {
    return "thunder";
  }
  if (/诅咒|黑蛇|死镰|Cursed 结算/.test(text)) {
    return "curse";
  }
  if (/圣光|审判圣锤|神罚|护盾/.test(text)) {
    return "holy";
  }
  if (/裂隙|虚空|Instability|混沌/.test(text)) {
    return "chaos";
  }
  return school || fusionSchool || "";
}

function effectsFor(id, school, fusionSchool, numericRow, spec, options = {}) {
  const text = `${numericRow.triggerText}；${numericRow.numericText}`;
  const effects = [];
  const mainDamageType = damageTypeForText(text, school);
  const secondaryDamageType = DAMAGE_BY_SCHOOL[fusionSchool] || "arcane";
  const needsArea = spec.radii.length > 0 || /区|区域|地面|路径|结界|裂隙|雷线|冰柱|法阵|冲击|爆|放电|锚点/.test(text);
  const needsProjectile = spec.counts.length > 0 || /弹|碎片|碎冰|余烬|电弧|光束|落雷|飞出|发射|喷出|冰片|跳|远处|复制/.test(text);
  const powers = spec.powers.length > 0 ? spec.powers : [0.25];

  if (needsArea) {
    effects.push(makeAreaEffect(id, mainDamageType, spec, powers[0], text));
  }
  if (needsProjectile) {
    effects.push(makeProjectileEffect(id, secondaryDamageType, spec, powers[0], text));
  }
  if (!needsArea && !needsProjectile) {
    effects.push({ type: "damage", damage_type: mainDamageType, source_type: "fusion", power_scale: powers[0] });
  }

  for (let index = 1; index < powers.length; index += 1) {
    effects.push({ type: "damage", damage_type: index % 2 === 0 ? mainDamageType : secondaryDamageType, source_type: "fusion", power_scale: powers[index] });
  }
  for (let index = 1; index < spec.radii.length; index += 1) {
    effects.push({
      type: "spawn_area",
      area_id: `${id}_r${index}_area`,
      radius_r: spec.radii[index],
      duration: spec.durations[index] ?? spec.durations[0] ?? 0.24,
      tick_interval: spec.tickIntervals[0] ?? 0.5,
      effects_on_apply: [{ type: "damage", damage_type: mainDamageType, source_type: "fusion", power_scale: powers[index] ?? powers[0] }],
    });
  }
  for (let index = 1; index < spec.durations.length; index += 1) {
    if (!hasDuration(effects, spec.durations[index])) {
      effects.push({
        type: "spawn_area",
        area_id: `${id}_duration_${index}_area`,
        radius_r: spec.radii[0] ?? 1.0,
        duration: spec.durations[index],
        tick_interval: spec.tickIntervals[0] ?? 0.5,
        effects_on_apply: [{ type: "damage", damage_type: mainDamageType, source_type: "fusion", power_scale: powers[0] }],
      });
    }
  }
  for (let index = 1; index < spec.tickIntervals.length; index += 1) {
    if (!hasTickInterval(effects, spec.tickIntervals[index])) {
      effects.push({
        type: "spawn_area",
        area_id: `${id}_tick_${index}_area`,
        radius_r: spec.radii[0] ?? 1.0,
        duration: spec.durations[0] ?? defaultDurationForText(text),
        tick_interval: spec.tickIntervals[index],
        effects_on_tick: [{ type: "damage", damage_type: mainDamageType, source_type: "fusion", power_scale: powers[0] }],
      });
    }
  }
  for (let index = 1; index < spec.counts.length; index += 1) {
    if (!hasCountValue(effects, spec.counts[index])) {
      effects.push(makeProjectileEffect(`${id}_count_${index}`, secondaryDamageType, { ...spec, counts: [spec.counts[index]] }, powers[index] ?? powers[0], text));
    }
  }
  for (const statusAdd of spec.statusAdds) {
    effects.push({
      type: "apply_status",
      status: statusAdd.status,
      stacks: statusAdd.stacks,
      duration: STATUS_DURATIONS[statusAdd.status] ?? 4.0,
    });
  }
  for (const shieldRatio of spec.shieldRatios) {
    effects.push({
      type: "grant_shield",
      shield_type: "fusion_shield",
      max_health_ratio: shieldRatio,
      duration: spec.durations[0] ?? 4.0,
      respect_shield_cap: true,
      shield_cap_health_ratio: 0.35,
    });
  }
  for (const consume of spec.consumeDurations) {
    effects.push({ type: "consume_status_duration", status: consume.status, duration: consume.duration });
  }
  if (/转移|复制/.test(text)) {
    effects.push({ type: "transfer_status", status: text.includes("Cursed") ? "cursed" : "instability", stacks: 1, duration: spec.durations[0] });
  }
  if (text.includes("Overload")) {
    effects.push({ type: "trigger_overload", status: "conductive" });
  }
  if (/直接碎裂|碎裂/.test(text)) {
    effects.push({
      type: "shatter_frozen",
      projectile_count: spec.counts[0] ?? 3,
      projectile_id: `${id}_projectile`,
      damage: { damage_type: secondaryDamageType, power_scale: powers[0] },
    });
  }
  if (options.shieldBreak && !effects.some((effect) => effect.type === "grant_shield")) {
    effects.push({ type: "apply_status", status: "judgment", stacks: 1, duration: STATUS_DURATIONS.judgment });
  }
  return effects;
}

function makeAreaEffect(id, damageType, spec, powerScale, text) {
  const tickEffects = [];
  if (powerScale > 0) {
    tickEffects.push({ type: "damage", damage_type: damageType, source_type: "fusion", power_scale: powerScale });
  }
  for (const statusAdd of spec.statusAdds) {
    tickEffects.push({ type: "apply_status", status: statusAdd.status, stacks: statusAdd.stacks, duration: STATUS_DURATIONS[statusAdd.status] ?? 4.0 });
  }
  return {
    type: "spawn_area",
    area_id: `${id}_area`,
    radius_r: spec.radii[0] ?? defaultRadiusForText(text),
    duration: spec.durations[0] ?? defaultDurationForText(text),
    tick_interval: spec.tickIntervals[0] ?? 0.5,
    count: spec.counts[0],
    effects_on_tick: tickEffects,
    effects_on_apply: powerScale > 0 ? [{ type: "damage", damage_type: damageType, source_type: "fusion", power_scale: powerScale }] : [],
  };
}

function makeProjectileEffect(id, damageType, spec, powerScale, text) {
  const onHit = [];
  for (const statusAdd of spec.statusAdds) {
    onHit.push({ type: "apply_status", status: statusAdd.status, stacks: statusAdd.stacks, duration: STATUS_DURATIONS[statusAdd.status] ?? 4.0 });
  }
  return {
    type: "spawn_projectile_burst",
    projectile_id: `${id}_projectile`,
    count: spec.counts[0] ?? defaultProjectileCountForText(text),
    spread_angle: 72,
    speed: 420,
    range_r: spec.radii[0] ?? 4.0,
    damage: { damage_type: damageType, power_scale: powerScale },
    on_hit: onHit,
  };
}

function damageTypeForText(text, fallbackSchool) {
  if (/雷|电|Conductive|Overload/.test(text)) {
    return "thunder";
  }
  if (/冰|霜|Chilled|Frozen/.test(text)) {
    return "frost";
  }
  if (/诅咒|Cursed|魂/.test(text)) {
    return "curse";
  }
  if (/圣|Judgment|护盾/.test(text)) {
    return "holy";
  }
  if (/火|Burning|熔岩|余烬/.test(text)) {
    return "fire";
  }
  return DAMAGE_BY_SCHOOL[fallbackSchool] || "arcane";
}

function defaultRadiusForText(text) {
  if (/全屏|大范围|奇点/.test(text)) {
    return 6.0;
  }
  if (/小型|短暂/.test(text)) {
    return 1.2;
  }
  return 1.8;
}

function defaultDurationForText(text) {
  if (/持续|地面|路径|区域|结界|裂隙/.test(text)) {
    return 2.5;
  }
  return 0.24;
}

function defaultProjectileCountForText(text) {
  if (/两|2/.test(text)) {
    return 2;
  }
  if (/一圈|周围|喷出/.test(text)) {
    return 6;
  }
  return 3;
}

function hasDuration(effects, duration) {
  return JSON.stringify(effects).includes(`"duration":${duration}`);
}

function hasCountValue(effects, count) {
  return JSON.stringify(effects).includes(`"count":${count}`) || JSON.stringify(effects).includes(`"projectile_count":${count}`);
}

function hasTickInterval(effects, tickInterval) {
  return JSON.stringify(effects).includes(`"tick_interval":${tickInterval}`);
}

function dedupeConditions(conditions) {
  const seen = new Set();
  const result = [];
  for (const condition of conditions) {
    const key = JSON.stringify(condition);
    if (!seen.has(key)) {
      seen.add(key);
      result.push(condition);
    }
  }
  return result;
}

function collectReferences(value, refs = []) {
  if (Array.isArray(value)) {
    value.forEach((item) => collectReferences(item, refs));
    return refs;
  }
  if (!value || typeof value !== "object") {
    return refs;
  }
  if (typeof value.area_id === "string") {
    refs.push({ type: "area", id: value.area_id });
  }
  if (typeof value.projectile_id === "string") {
    refs.push({ type: "projectile", id: value.projectile_id });
  }
  if (typeof value.summon_definition_id === "string") {
    refs.push({ type: "summon", id: value.summon_definition_id });
  } else if (value.type === "spawn_summon" && typeof value.summon_id === "string") {
    refs.push({ type: "summon", id: value.summon_id });
  }
  Object.values(value).forEach((child) => collectReferences(child, refs));
  return refs;
}

function makeCombatObject(ref) {
  if (ref.type === "projectile") {
    return {
      id: ref.id,
      type: "projectile",
      scene: "res://scenes/combat/fireball_projectile.tscn",
      collision_radius: 12,
      destroy_on_wall: true,
      destroy_on_hit: true,
      visual_mode: "programmatic",
      visual_style: "arcane_page",
      visual_color: [0.72, 0.32, 1.0, 0.92],
      visual_ring_color: [0.88, 0.95, 1.0, 0.86],
    };
  }
  return {
    id: ref.id,
    type: "area",
    scene: "res://scenes/combat/area_effect.tscn",
    collision_radius: 126,
    visual_mode: "programmatic",
    visual_style: "smoke_zone",
    visual_color: [0.42, 0.22, 0.72, 0.26],
    visual_ring_color: [0.7, 0.9, 1.0, 0.78],
  };
}

function replaceById(list, item) {
  const index = list.findIndex((entry) => entry.id === item.id);
  if (index >= 0) {
    list[index] = { ...list[index], ...item };
  } else {
    list.push(item);
  }
}

const expectedRows = loadExpectedFusionRows();
const numericRowsByName = new Map(parseFusionNumericRows().map((row) => [row.name, row]));
const expectedIds = new Set(expectedRows.map(([id]) => id));

const skillsDocument = readJson("data/skills/skills.json");
const existingById = new Map((skillsDocument.skills || []).map((skill) => [skill.id, skill]));
const nonFusionSkills = (skillsDocument.skills || []).filter((skill) => !skill.fusion_school && skill.type !== "fusion");
const fusionSkills = expectedRows.map((row) => {
  const numericRow = numericRowsByName.get(row[1]);
  if (!numericRow) {
    throw new Error(`Missing numeric docs row for ${row[1]}`);
  }
  const existing = existingById.get(row[0]);
  const skill = makeFusionSkill(row, numericRow);
  if (existing && expectedIds.has(existing.id)) {
    return { ...existing, ...skill };
  }
  return skill;
});
skillsDocument.skills = [...nonFusionSkills, ...fusionSkills];
writeJson("data/skills/skills.json", skillsDocument);

const combatDocument = readJson("data/combat/combat_objects.json");
const combatObjects = combatDocument.combat_objects || [];
const summonDocument = readJson("data/summons/summons.json");
const summons = summonDocument.summons || [];
const summonIds = new Set(summons.map((summon) => summon.id));
const refs = fusionSkills.flatMap((skill) => collectReferences(skill));
for (const ref of refs) {
  if (ref.type === "summon") {
    if (!summonIds.has(ref.id)) {
      summons.push({
        id: ref.id,
        name: ref.id,
        scene_path: "res://scenes/summons/summon_controller.tscn",
        max_count: 2,
        duration: 10.0,
        movement: { move_speed: 180, follow_distance: 96, min_distance: 44, leash_distance: 360, teleport_distance: 720, separation_radius: 34 },
        targeting: { detect_range: 320, retarget_interval: 0.25, target_priority: "nearest_to_summon" },
        attack: { attack_type: "melee", attack_range: 52, attack_cooldown: 1.2, damage_type: "arcane", damage_scale: 0.35, on_hit_effects: [] },
        visual: { texture: "res://icon.svg", scale: 0.15, modulate: [0.72, 0.42, 1.0, 0.9], z_index: 5 },
      });
      summonIds.add(ref.id);
    }
  } else {
    replaceById(combatObjects, makeCombatObject(ref));
  }
}
combatDocument.combat_objects = combatObjects;
summonDocument.summons = summons;
writeJson("data/combat/combat_objects.json", combatDocument);
writeJson("data/summons/summons.json", summonDocument);

console.log(`[apply_fusion_skill_catalog] wrote ${fusionSkills.length} fusion skills from docs/skills/skills.md`);
