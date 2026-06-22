const DEFAULT_CARD_BG = "res://assets/ui/skills/skill_card_bg.png";
const DEFAULT_ICON = "res://icon.svg";
const DEFAULT_PROJECTILE_SCENE = "res://scenes/fireball_projectile.tscn";
const DEFAULT_AREA_SCENE = "res://scenes/area_effect.tscn";
const DEFAULT_ORBIT_SCENE = "res://scenes/orbit_object.tscn";

const ARCHETYPES = {
  projectile: {
    tags: ["projectile", "ranged"],
    damageOriginList: ["primary_attack"],
    targetingRuleId: "nearest_enemy",
    upgradeTagPool: ["weapon", "damage", "projectile", "status"],
    objectType: "projectile",
    defaultDamageType: "direct_magical",
  },
  area: {
    tags: ["area"],
    damageOriginList: ["field"],
    targetingRuleId: "nearest_enemy",
    upgradeTagPool: ["weapon", "damage", "area", "status"],
    objectType: "area",
    defaultDamageType: "area_direct",
  },
  orbit: {
    tags: ["orbit", "area"],
    damageOriginList: ["primary_attack"],
    targetingRuleId: "self",
    upgradeTagPool: ["weapon", "damage", "area"],
    objectType: "orbit_object",
    defaultDamageType: "area_direct",
  },
  chain: {
    tags: ["projectile", "chain", "ranged"],
    damageOriginList: ["primary_attack"],
    targetingRuleId: "nearest_enemy",
    upgradeTagPool: ["weapon", "damage", "projectile", "chain"],
    objectType: "projectile",
    defaultDamageType: "direct_magical",
  },
  status_stack: {
    tags: ["projectile", "status", "ranged"],
    damageOriginList: ["primary_attack", "status_dot", "special"],
    targetingRuleId: "nearest_enemy",
    upgradeTagPool: ["weapon", "damage", "status"],
    objectType: "projectile",
    defaultDamageType: "direct_magical",
  },
};

const BRANCH_PRESETS = [
  {
    suffix: "power",
    displayName: "Power Path",
    modifiers: [
      { damage_multiplier_add: 0.1 },
      { damage_multiplier_add: 0.15 },
      { damage_multiplier_add: 0.2 },
      { damage_multiplier_add: 0.25 },
    ],
  },
  {
    suffix: "tempo",
    displayName: "Tempo Path",
    modifiers: [
      { attack_speed_multiplier_add: 0.08 },
      { attack_speed_multiplier_add: 0.12 },
      { attack_speed_multiplier_add: 0.16 },
      { attack_speed_multiplier_add: 0.2 },
    ],
  },
  {
    suffix: "coverage",
    displayName: "Coverage Path",
    modifiers: [
      { skill_area_multiplier_add: 0.1 },
      { skill_area_multiplier_add: 0.15 },
      { skill_area_multiplier_add: 0.2 },
      { skill_area_multiplier_add: 0.25 },
    ],
  },
  {
    suffix: "control",
    displayName: "Control Path",
    modifiers: [
      { projectile_speed_multiplier_add: 0.1 },
      { direct_damage_multiplier_add: 0.08 },
      { projectile_speed_multiplier_add: 0.15 },
      { direct_damage_multiplier_add: 0.12 },
    ],
  },
];

function listArchetypes() {
  return Object.keys(ARCHETYPES);
}

function buildWeaponScaffold(options) {
  const archetype = ARCHETYPES[options.archetype];
  if (!archetype) {
    throw new Error(`Unknown archetype: ${options.archetype}`);
  }

  const weaponId = options.weaponId;
  const skillId = options.startingSkillId || `${weaponId}_attack`;
  const objectId = options.objectId || `${skillId}_${archetype.objectType === "orbit_object" ? "orbit" : archetype.objectType}`;
  const element = options.element || "physical";
  const damageType = options.damageType || archetype.defaultDamageType;
  const branchIds = BRANCH_PRESETS.map((branch) => `${weaponId}_branch_${branch.suffix}`);

  return {
    characterAllowedWeaponId: weaponId,
    weapon: buildWeapon(options, archetype, skillId, branchIds),
    weaponText: buildWeaponText(options),
    combatObject: buildCombatObject(archetype, objectId, options),
    primaryAttack: buildPrimaryAttack(archetype, options, skillId, objectId, element, damageType),
    branches: BRANCH_PRESETS.map((branch) => buildBranch(weaponId, branch)),
  };
}

function buildWeaponText(options) {
  return {
    role: options.role || options.description || `${options.displayName} weapon role placeholder.`,
  };
}

function buildWeapon(options, archetype, skillId, branchIds) {
  return {
    damage_origin_list: archetype.damageOriginList,
    branch_ids: branchIds,
    targeting_rule_id: options.targeting || archetype.targetingRuleId,
    upgrade_tag_pool: archetype.upgradeTagPool,
    id: options.weaponId,
    display_name: options.displayName,
    description: options.description || options.displayName,
    character_id: options.characterId,
    starting_skill_id: skillId,
    tags: unique([...(archetype.tags || []), options.element || "physical"]),
    weapon_trait: {},
    unlock: { type: "default" },
    visual: {
      icon: options.icon || DEFAULT_ICON,
      texture: options.texture || options.icon || DEFAULT_ICON,
      rotation: Number(options.rotation || 0),
    },
  };
}

function buildCombatObject(archetype, objectId, options) {
  const type = archetype.objectType;
  const scene = type === "area" ? DEFAULT_AREA_SCENE : type === "orbit_object" ? DEFAULT_ORBIT_SCENE : DEFAULT_PROJECTILE_SCENE;
  const radius = type === "orbit_object" ? 18 : type === "area" ? Number(options.radius || 48) : Number(options.collisionRadius || 10);
  const object = {
    id: objectId,
    type,
    scene,
    collision_radius: radius,
    visual: {
      texture: options.objectTexture || DEFAULT_ICON,
      modulate: parseColor(options.color || "1,1,1,1"),
      scale: type === "area" ? [0.65, 0.65] : type === "orbit_object" ? [0.28, 0.28] : [0.09, 0.09],
    },
  };

  if (type === "projectile") {
    object.destroy_on_wall = true;
    object.destroy_on_hit = true;
  }
  if (type === "orbit_object") {
    object.persistent = true;
    object.follow_owner = true;
  }
  return object;
}

function buildPrimaryAttack(archetype, options, skillId, objectId, element, damageType) {
  const damage = Number(options.damage || 12);
  const cooldown = Number(options.cooldown || 1.2);
  const range = Number(options.range || 520);
  const attack = {
    id: skillId,
    display_name: options.skillDisplayName || `${options.displayName} Attack`,
    description: options.skillDescription || `${options.displayName} base attack.`,
    category: "active",
    tags: unique([...(archetype.tags || []), element]),
    max_level: 5,
    base: {
      damage,
      damage_type: damageType,
      element,
      cooldown,
      range,
      projectile_speed: Number(options.speed || 420),
      projectile_count: 1,
      spread_angle: 0,
      area_radius: Number(options.radius || 48),
      pierce: 0,
    },
    components: [],
    events: [],
    background_texture: DEFAULT_CARD_BG,
    damage_scaling: {
      skill_level_coefficients: [1, 1, 1, 1, 1],
    },
    weapon_id: options.weaponId,
  };

  if (archetype.objectType === "orbit_object") {
    attack.components.push({
      type: "persistent_orbit",
      params: {
        object_id: objectId,
        count: Number(options.count || 3),
        orbit_radius: Number(options.orbitRadius || 72),
        collision_radius: Number(options.collisionRadius || 18),
        rotation_speed: Number(options.rotationSpeed || 220),
        hit_interval: Number(options.hitInterval || 0.45),
        damage,
        damage_origin: "primary_attack",
        damage_type: damageType,
        element,
      },
    });
    return attack;
  }

  attack.components.push({ type: "cooldown", params: { seconds: cooldown } });
  attack.components.push({ type: "targeting", params: { mode: options.targeting || "nearest_enemy", range } });
  attack.events.push(buildCastEvent(archetype, options, objectId, element, damageType));

  if (archetype.objectType === "projectile") {
    attack.events.push(buildProjectileHitEvent(archetype, options, objectId, damage, element, damageType));
  }
  return attack;
}

function buildCastEvent(archetype, options, objectId, element, damageType) {
  if (archetype.objectType === "area") {
    return {
      trigger: "on_cast",
      actions: [
        {
          type: "spawn_area",
          params: {
            area_id: objectId,
            radius: Number(options.radius || 64),
            duration: Number(options.duration || 2.0),
            tick_interval: Number(options.tickInterval || 0.5),
            damage: Number(options.damage || 12),
            damage_origin: "field",
            damage_type: damageType,
            element,
          },
        },
      ],
    };
  }

  return {
    trigger: "on_cast",
    actions: [
      {
        type: "spawn_projectile",
        params: {
          projectile_id: objectId,
          count: Number(options.count || 1),
          speed: Number(options.speed || 420),
          spread_angle: Number(options.spreadAngle || 0),
          lifetime: Number(options.lifetime || 2.0),
          collision_radius: Number(options.collisionRadius || 10),
          element,
        },
      },
    ],
  };
}

function buildProjectileHitEvent(archetype, options, objectId, damage, element, damageType) {
  const actions = [
    {
      type: "deal_damage",
      params: {
        amount: damage,
        damage_type: damageType,
        element,
        can_crit: true,
        damage_origin: "primary_attack",
      },
    },
  ];

  if (archetype === ARCHETYPES.chain) {
    actions.push({
      type: "chain_to_targets",
      params: {
        radius: Number(options.chainRadius || 160),
        max_targets: Number(options.chainTargets || 3),
        actions: [
          {
            type: "deal_damage",
            params: {
              amount: Math.max(1, Math.round(damage * 0.6)),
              damage_type: damageType,
              damage_origin: "primary_attack",
              element,
            },
          },
        ],
      },
    });
  }

  return {
    trigger: "on_projectile_hit",
    source_id: objectId,
    actions,
  };
}

function buildBranch(weaponId, branch) {
  const levelPath = {};
  for (let level = 2; level <= 5; level += 1) {
    levelPath[String(level)] = {
      display_name: `${branch.displayName} Lv${level}`,
      description: `${branch.displayName} level ${level}.`,
      rarity: level >= 4 ? "epic" : "rare",
      modifiers: branch.modifiers[level - 2],
    };
  }

  return {
    id: `${weaponId}_branch_${branch.suffix}`,
    weapon_id: weaponId,
    display_name: branch.displayName,
    role: "Weapon path",
    description: `${branch.displayName} progression.`,
    rarity: "rare",
    tags: ["weapon", "main_progression"],
    level_path: levelPath,
  };
}

function parseColor(value) {
  const parts = String(value)
    .split(",")
    .map((part) => Number(part.trim()))
    .filter((part) => Number.isFinite(part));
  if (parts.length === 3) {
    parts.push(1);
  }
  return parts.length === 4 ? parts : [1, 1, 1, 1];
}

function unique(items) {
  return [...new Set(items.filter(Boolean))];
}

module.exports = {
  ARCHETYPES,
  buildWeaponScaffold,
  listArchetypes,
};
