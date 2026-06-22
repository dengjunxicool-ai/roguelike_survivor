const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const dataDir = path.join(root, "data");
const docsDir = path.join(root, "docs");
const UPDATED_AT = "2026-06-10";
const DOC_VERSION = "v1.0.0";

const CONFIGS = {
  challenges: {
    guide: "CHALLENGES_JSON_CONFIG_GUIDE.md",
    name: "挑战配置",
    module: "挑战 / 局外成长",
    type: "规则配置",
    purpose: "定义每日挑战和每周挑战的固定角色、武器、地图、挑战目标与修正规则。",
    controls: ["每日挑战池", "每周挑战池", "挑战入口展示", "挑战完成记录与奖励判断"],
    impact: "会影响挑战列表、挑战开局预设、通关目标判断和局外进度记录。",
  },
  characters: {
    guide: "CHARACTERS_JSON_CONFIG_GUIDE.md",
    name: "角色配置",
    module: "角色 / 选人 / 存档解锁",
    type: "数据源配置",
    purpose: "定义可选角色的基础属性、天赋、可用武器、解锁条件和视觉资源。",
    controls: ["人物选择页面", "玩家基础属性", "角色天赋", "角色解锁状态", "图鉴展示"],
    impact: "会影响角色是否可选、开局属性、可装备武器范围、角色展示和存档解锁判断。",
  },
  combat_objects: {
    guide: "COMBAT_OBJECTS_JSON_CONFIG_GUIDE.md",
    name: "战斗对象配置",
    module: "战斗 / 技能表现",
    type: "数据源配置",
    purpose: "定义技能动作引用的投射物、区域、环绕物等战斗对象模板。",
    controls: ["投射物表现", "区域伤害对象", "环绕物对象", "碰撞半径", "战斗对象视觉资源"],
    impact: "会影响技能动作生成对象、命中检测、持续时间、视觉资源加载和战斗表现。",
  },
  enemies: {
    guide: "ENEMIES_JSON_CONFIG_GUIDE.md",
    name: "敌人配置",
    module: "敌人 / 刷怪 / 战斗 AI",
    type: "数据源配置",
    purpose: "定义敌人的基础属性、行为、技能、奖励、抗性和视觉资源。",
    controls: ["敌人刷怪池", "敌人属性", "敌人 AI 行为", "敌人技能", "击杀奖励", "图鉴展示"],
    impact: "会影响刷怪、敌人移动攻击、击杀掉落、Boss/精英预览和战斗难度。",
  },
  maps: {
    guide: "MAPS_JSON_CONFIG_GUIDE.md",
    name: "地图配置",
    module: "地图 / 选关 / 运行时场景",
    type: "页面配置 / 规则配置",
    purpose: "定义地图选择项、地图机制、Boss/精英预览、解锁条件和背景资源。",
    controls: ["地图选择页面", "地图解锁", "地图变量", "Boss 预览", "地图背景资源"],
    impact: "会影响选关展示、关卡运行时变量、地图解锁和局内背景表现。",
  },
  progression_goals: {
    guide: "PROGRESSION_GOALS_JSON_CONFIG_GUIDE.md",
    name: "成长目标配置",
    module: "局外成长 / 成就目标",
    type: "规则配置",
    purpose: "定义武器熟练、角色专精和地图挑战等局外成长目标。",
    controls: ["武器熟练等级奖励", "角色专精目标", "地图挑战目标", "成长记录"],
    impact: "会影响局外进度记录、解锁奖励、图鉴展示和挑战完成判断。",
  },
  relics: {
    guide: "RELICS_JSON_CONFIG_GUIDE.md",
    name: "遗物配置",
    module: "遗物 / 奖励池",
    type: "数据源配置 / 规则配置",
    purpose: "定义遗物池、触发条件、数值修正、限制规则、冷却和负面修正。",
    controls: ["遗物奖励池", "遗物触发条件", "遗物数值效果", "遗物限制与冷却"],
    impact: "会影响局内奖励选项、遗物获得后的被动效果和战斗诊断数据。",
  },
  primary_attack: {
    guide: "PRIMARY_ATTACK_JSON_CONFIG_GUIDE.md",
    name: "主武器攻击配置",
    module: "武器 / 主攻击 / 战斗动作",
    type: "数据源配置 / 规则配置",
    purpose: "定义主武器攻击形式的基础数值、组件、事件、动作、升级展示和卡片背景资源。",
    controls: ["主武器攻击参数", "攻击组件", "攻击事件触发", "攻击动作", "升级卡片展示"],
    impact: "会影响开局主武器攻击、升级选项、战斗对象生成、伤害来源和攻击视觉表现。",
  },
  status_effects: {
    guide: "STATUS_EFFECTS_JSON_CONFIG_GUIDE.md",
    name: "状态效果配置",
    module: "状态 / 元素反应",
    type: "规则配置",
    purpose: "定义状态效果的叠层、持续时间、周期伤害、控制效果和反应参数。",
    controls: ["燃烧/冰冻/中毒等状态", "状态叠层", "状态伤害", "控制效果", "元素反应"],
    impact: "会影响状态挂载、状态图标、周期伤害、控制效果和元素联动。",
  },
  synergies: {
    guide: "SYNERGIES_JSON_CONFIG_GUIDE.md",
    name: "协同配置",
    module: "技能 / 构筑协同",
    type: "规则配置",
    purpose: "定义技能标签协同的触发条件和协同收益。",
    controls: ["技能标签组合", "协同触发条件", "协同效果", "构筑加成"],
    impact: "会影响技能组合奖励、战斗修正和构筑提示。",
  },
  upgrades: {
    guide: "UPGRADES_JSON_CONFIG_GUIDE.md",
    name: "升级配置",
    module: "升级池 / 局内局外成长",
    type: "规则配置 / 数据源配置",
    purpose: "定义诅咒选择、局外永久升级、局内三选一升级和稀有度权重。",
    controls: ["局内升级池", "诅咒选择", "永久升级", "稀有度权重", "升级卡片展示"],
    impact: "会影响升级候选生成、权重抽取、重复升级、局外成长和三选一卡片内容。",
  },
  ui_theme: {
    guide: "UI_THEME_CONFIG_GUIDE.md",
    name: "UI 按钮主题配置",
    module: "UI / 按钮皮肤",
    type: "页面配置 / 美术资源配置",
    purpose: "定义可交互按钮的背景色、边框色、文字颜色、边距、圆角和可替换背景图。",
    controls: ["按钮普通状态", "按钮悬停状态", "按钮按下状态", "按钮禁用状态", "按钮背景资源"],
    impact: "会影响所有通过按钮皮肤工具创建或刷新样式的可交互按钮。",
  },
  waves: {
    guide: "WAVES_JSON_CONFIG_GUIDE.md",
    name: "波次配置",
    module: "关卡 / 刷怪 / Boss",
    type: "规则配置",
    purpose: "定义单局时间线、刷怪规则、普通波次、Boss 阶段和奖励配置。",
    controls: ["单局时长", "经验曲线", "刷怪波次", "Boss 事件", "升级池保底", "奖励配置"],
    impact: "会影响局内节奏、刷怪密度、升级节奏、Boss 出现时间和胜利奖励。",
  },
  weapon_branches: {
    guide: "WEAPON_BRANCHES_JSON_CONFIG_GUIDE.md",
    name: "武器分支配置",
    module: "武器 / 分支成长",
    type: "规则配置",
    purpose: "定义武器 Lv2-Lv5 的分支成长路径、每级展示文案、修正和进化检查。",
    controls: ["武器分支选择", "分支等级成长", "分支升级卡片", "进化检查开关"],
    impact: "会影响武器路线选择、后续升级候选、Lv5 进化触发和三选一卡片展示。",
  },
  weapons: {
    guide: "WEAPONS_JSON_CONFIG_GUIDE.md",
    name: "武器配置",
    module: "武器 / 选人装配",
    type: "数据源配置",
    purpose: "定义武器归属、开局技能、分支、标签和视觉资源。",
    controls: ["角色可用武器", "开局技能", "武器标签", "武器分支", "武器图标与贴图"],
    impact: "会影响人物选择页、开局技能、主武器成长、升级池匹配和图鉴展示。",
  },
};

const LEGACY_KEYS_BY_DOC = {
  characters: new Set([]),
  weapons: new Set(["weapon_id", "weapon_name_zh", "weapon_name_en", "allowed_characters", "primary_attack_id", "element_tags", "base_status_id", "cosmetic_slots", "unlock_condition"]),
  enemies: new Set(["monster_id", "name_zh", "name_en", "monster_family", "rank", "hp", "defense", "exp", "rewards", "spawn_weight", "behavior_type", "behavior_config", "skill_list", "screen_limit", "warning_rule"]),
  maps: new Set(["map_id", "name_zh", "name_en", "unlock_condition"]),
  upgrades: new Set(["upgrade_id", "upgrade_name_zh", "upgrade_name_en", "effect_list", "weight_rule", "max_stack", "ui_description_zh", "ui_description_en"]),
  status_effects: new Set(["status_id", "name_zh", "name_en", "status_type", "max_stack", "effect_per_stack", "reaction_trigger_ids", "ui_display_priority"]),
  relics: new Set(["relic_id", "relic_name_zh", "relic_name_en", "effect_list", "ui_description_zh", "ui_description_en", "unlock_condition"]),
  waves: new Set(["wave_id", "name_zh", "name_en"]),
  weapon_branches: new Set(["branch_id", "name_zh", "name_en"]),
};

const LEGACY_PARENT_KEYS_BY_DOC = {
  characters: new Set(["characters"]),
  weapons: new Set(["weapons"]),
  enemies: new Set(["enemies", "monsters"]),
  maps: new Set(["maps"]),
  upgrades: new Set(["curse_choices", "permanent_upgrades", "level_up_upgrades"]),
  status_effects: new Set(["statuses", "status_effects"]),
  relics: new Set(["relics"]),
  waves: new Set(["waves"]),
  weapon_branches: new Set(["branches"]),
};

const ROOT_ITEM_NAMES = {
  challenges: { daily_challenges: "DailyChallenge", weekly_challenges: "WeeklyChallenge" },
  characters: { characters: "Character" },
  combat_objects: { combat_objects: "CombatObject" },
  enemies: { enemies: "Enemy", monsters: "Enemy" },
  maps: { maps: "MapConfig" },
  relics: { relics: "Relic" },
  primary_attack: { primary_attacks: "PrimaryAttack" },
  status_effects: { statuses: "StatusEffect", status_effects: "StatusEffect" },
  synergies: { synergies: "Synergy" },
  upgrades: { curse_choices: "CurseChoice", permanent_upgrades: "PermanentUpgrade", level_up_upgrades: "LevelUpUpgrade" },
  ui_theme: { buttons: "ButtonThemeMap" },
  waves: { waves: "Wave" },
  weapon_branches: { branches: "WeaponBranch" },
  weapons: { weapons: "Weapon" },
};

const FIELD_DESCRIPTIONS = {
  id: "配置对象唯一 ID，运行时代码和其它配置通过它定位对象。同一配置池内必须唯一。",
  display_name: "玩家界面展示名称，用于按钮、卡片、图鉴或详情面板。",
  description: "玩家界面展示说明，用于卡片描述、图鉴说明或奖励说明。",
  enabled: "是否启用该配置。为 false 时配置可保留在文件中，但不应进入常规候选池。",
  type: "类型枚举，决定运行时代码采用哪一类处理逻辑。",
  category: "分类枚举，用于池子、筛选、UI 分组或规则分支。",
  tags: "标签集合，用于升级池匹配、协同、过滤、展示和权重调整。",
  rarity: "稀有度，影响抽取权重、展示样式或掉落价值。",
  background_texture: "卡片或按钮背景图资源路径，使用 `res://...`，资源不存在时运行时会回退为无背景图。",

  visual: "视觉资源配置，通常包含贴图、图标、动画帧、缩放、偏移和颜色调制。",
  icon: "UI 图标资源路径，通常用于选择页、图鉴、HUD 或奖励卡。",
  texture: "静态贴图资源路径。没有动画帧时，运行时通常使用该贴图显示对象。",
  background: "背景资源路径，用于地图、页面或展示区域背景。",
  sprite_frames: "Godot SpriteFrames 资源路径，配置后运行时可创建 AnimatedSprite2D。",
  modulate: "颜色调制数组，格式为 [r, g, b, a]。",
  scale: "节点缩放数组，格式为 [x, y]。",
  offset: "节点显示偏移数组，格式为 [x, y]。",
  rotation: "武器视觉初始旋转角度，单位为度；用于 `weapons.json.visual.rotation`。",
  rotation_degrees: "节点初始旋转角度，单位为度。",
  animations: "运行时状态到 SpriteFrames 动画名的映射。",
  animation: "SpriteFrames 中实际播放的动画名。",

  base_stats: "标准基础属性对象，角色和敌人的运行时数值从这里读取。",
  max_hp: "最大生命值。",
  move_speed: "移动速度。",
  damage_multiplier: "造成伤害倍率修正。",
  attack_speed_multiplier: "攻击速度倍率修正，主武器攻击间隔会除以该值。",
  crit_chance: "暴击概率，通常使用 0 到 1 的小数。",
  crit_damage: "暴击伤害倍率。",
  armor: "护甲或防御值，用于减伤和展示。",
  pickup_radius: "经验、金币或掉落物拾取半径。",
  soul_gain_multiplier: "灵魂石获取倍率。",

  unlock: "解锁条件对象，type 决定条件类型，其它字段提供条件参数。",
  required_runs: "解锁或目标判断所需的通关/游玩次数。",
  required_level: "解锁、升级或进化所需等级。",
  required_character_id: "所需角色 ID，指向 characters.json 的 id。",
  required_weapon_id: "所需武器 ID，指向 weapons.json 的 id。",
  required_map_id: "所需地图 ID，指向 maps.json 的 id。",

  character_id: "角色 ID 引用，指向 characters.json 的 id。",
  weapon_id: "武器 ID 引用，指向 weapons.json 的 id。",
  map_id: "地图 ID 引用，指向 maps.json 的 id。",
  boss_id: "Boss 敌人 ID 引用，指向 enemies.json 的 id。",
  enemy_id: "敌人 ID 引用，指向 enemies.json 的 id。",
  enemy_ids: "敌人 ID 列表，刷怪组会从这些敌人中生成。",
  skill_id: "主武器攻击 ID 引用，指向 primary_attack.json 的 id。代码内部仍沿用 skill_id 命名。",
  status_id: "状态 ID 引用，指向 status_effects.json 的 id。",
  relic_id: "遗物 ID 引用，指向 relics.json 的 id。",
  branch_id: "武器分支 ID 引用，指向 weapon_branches.json 的 id。",
  evolution_id: "武器进化记录 ID。",
  evolved_skill_id: "进化后主武器攻击 ID，指向 primary_attack.json 的 id。代码内部仍沿用 evolved_skill_id 命名。",
  starting_skill_id: "武器开局授予的技能 ID。",
  allowed_weapon_ids: "该角色可选择的武器 ID 列表。",
  branch_ids: "该武器可进入的分支 ID 列表。",

  base: "标准化运行参数对象，技能、主攻击或战斗对象从这里读取基础数值。",
  damage: "基础伤害或周期伤害。",
  damage_type: "伤害类型，用于抗性、统计和效果分支。",
  element: "元素类型，用于抗性、状态和元素反应联动。",
  cooldown: "冷却时间，单位秒。",
  range: "攻击或技能射程。",
  projectile_speed: "投射物飞行速度。",
  projectile_count: "投射物数量。",
  spread_angle: "多投射物扩散角度。",
  area_radius: "区域半径。",
  duration: "持续时间，单位秒。",
  tick_interval: "周期触发间隔，单位秒。",
  hit_interval: "同一对象可重复命中的间隔，单位秒。",
  pierce: "穿透次数。",
  knockback: "击退强度。",
  orbit_object_count: "环绕物数量。",
  orbit_radius: "环绕半径。",
  rotation_speed: "旋转速度。",

  components: "技能组件配置。组件负责冷却、索敌、持续区域、环绕等基础行为。",
  events: "技能或波次事件配置。事件在指定 trigger 触发时执行 actions。",
  trigger: "触发时机或事件名。",
  actions: "事件触发后执行的动作列表。",
  params: "类型专属参数对象，具体含义由父级 type 或 action 决定。",
  source_id: "事件来源对象 ID，用于限定某个投射物、区域或状态触发后续动作。",
  projectile_id: "投射物配置 ID，指向 combat_objects.json 中对应对象。",
  area_id: "区域对象配置 ID，指向 combat_objects.json 中对应对象。",
  object_id: "战斗对象配置 ID，指向 combat_objects.json 中对应对象。",
  count: "生成数量或触发次数。",
  speed: "移动或投射速度。",
  lifetime: "对象生命周期，单位秒。",
  collision_radius: "碰撞半径。",
  radius: "作用半径。",
  amount: "数值量，具体含义由所在动作决定。",
  chance: "触发概率，通常使用 0 到 1 的小数。",
  stack: "施加或变更的层数。",
  can_crit: "该伤害是否可以暴击。",

  modifiers: "数值修正对象，键名通常对应运行时属性或技能属性。",
  level_modifiers: "按等级生效的数值修正配置。",
  level_descriptions: "按等级展示的说明文本。",
  skill_modifiers: "只作用到技能实例的修正。",
  damage_multiplier_add: "伤害倍率加算修正。",
  attack_speed_multiplier_add: "攻击速度倍率加算修正，数值越高主武器攻击越快。",
  max_hp_multiplier_add: "最大生命倍率加算修正。",
  pickup_radius_multiplier_add: "拾取半径倍率加算修正。",
  luck_add: "幸运值加算修正。",
  main_progression_weight_add: "主武器成长选项权重加算。",
  boss_damage_multiplier_add: "对 Boss 伤害倍率加算修正。",
  crit_chance_add: "暴击概率加算修正。",
  skill_area_multiplier_add: "技能范围倍率加算修正。",
  status_duration_multiplier_add: "状态持续时间倍率加算修正。",

  rarity_weights: "各稀有度在抽取时的权重。",
  base_weight: "基础抽取权重。",
  weight: "相对权重。",
  weight_decay: "重复抽取或升级后的权重衰减系数。",
  max_level: "最大等级或最大可叠加等级。",
  max_stacks: "最大叠层数。",
  exclude_tags: "互斥标签，已拥有同类标签时用于排除候选项。",
  required_weapon_tags: "升级进入候选池所需的武器标签。",
  required_skill_tags: "触发协同所需的技能标签。",
  required_branch_id: "升级进入候选池所需的武器分支 ID。",
  required_player_state: "升级进入候选池所需的玩家状态条件。",
  curse_choices: "诅咒类升级池。",
  permanent_upgrades: "局外永久升级池。",
  level_up_upgrades: "局内三选一升级池。",

  run: "单局基础规则。",
  duration_seconds: "单局持续时间，单位秒。",
  boss_spawn_time: "Boss 出现时间点，单位秒。",
  starting_level: "开局等级。",
  experience_table: "升级所需经验表。",
  experience_formula: "经验曲线配置。",
  values: "枚举值或曲线取值。",
  spawn_rules: "刷怪和升级池保底规则。",
  upgrade_phase_weights: "不同时间段或进度下的升级池权重。",
  low_hp_rule: "低血量保底规则。",
  weapon_tag_rule: "武器标签保底规则。",
  main_progression_pity: "主武器成长保底规则。",
  waves: "普通波次列表。",
  groups: "刷怪组列表。",
  enemy_multipliers: "该波次应用到敌人身上的属性倍率。",
  boss_event: "Boss 阶段配置。",
  rewards: "奖励配置。",
  fairness: "Boss 阶段公平性限制。",
  start_time: "波次开始时间，单位秒。",
  end_time: "波次结束时间，单位秒。",
  spawn_interval: "刷怪间隔，单位秒。",
  max_alive: "场上最大存活敌人数。",
  spawn_time: "事件或 Boss 生成时间，单位秒。",
  souls_reward: "灵魂石奖励数量。",
  gold_reward: "金币奖励数量。",
  base_gold: "基础金币奖励。",
  boss_gold: "Boss 击败金币奖励。",
  boss_souls: "Boss 击败灵魂石奖励。",

  level_path: "分支 Lv2-Lv5 的逐级成长配置。",
  requires: "进化所需条件对象。",
  inherit: "进化后从分支或原技能继承的内容。",
  selected_branch_id: "玩家当前选择的分支 ID。",
  skill_level: "技能当前等级。",
  branch_modifiers: "是否继承分支数值修正。",
  tags_added: "是否继承分支追加标签。",
  events_added: "是否继承分支追加事件。",

  contact_damage: "接触玩家时造成的伤害。",
  contact_interval: "接触伤害触发间隔。",
  attack_range: "敌人技能或攻击距离。",
  exp_drop: "经验掉落量。",
  soul_drop: "灵魂石掉落量。",
  resistances: "抗性配置。",
  behavior: "敌人 AI 行为配置。",
  skills: "敌人可使用的技能列表或技能配置集合。",

  map_variable: "地图机制配置。",
  difficulty: "地图难度等级。",
  elite_preview_ids: "地图选择界面展示的精英敌人 ID 列表。",

  damage_origin: "伤害来源，用于统计和分支条件。",
  damage_origin_list: "武器可能产生的伤害来源列表。",
  targeting_rule_id: "武器默认索敌规则 ID。",
  upgrade_tag_pool: "武器参与升级池匹配的标签集合。",
  weapon_trait: "武器专属规则或被动配置。",

  buttons: "按钮主题集合，键名为按钮主题名。",
  default: "默认按钮主题。",
  font_color: "按钮文字颜色，使用十六进制颜色字符串。",
  font_disabled_color: "禁用状态文字颜色，使用十六进制颜色字符串。",
  content_margin: "按钮内容边距配置。",
  corner_radius: "按钮圆角半径。",
  border_width: "按钮边框宽度。",
  normal: "按钮普通状态样式。",
  hover: "按钮悬停状态样式。",
  pressed: "按钮按下状态样式。",
  disabled: "按钮禁用状态样式。",
  background_color: "按钮背景色，使用十六进制颜色字符串。",
  border_color: "按钮边框颜色，使用十六进制颜色字符串。",
  left: "左侧边距或偏移。",
  top: "顶部边距或偏移。",
  right: "右侧边距或偏移。",
  bottom: "底部边距或偏移。",

  weapon_mastery: "武器熟练度成长配置。",
  level_rewards: "等级奖励列表。",
  character_specializations: "角色专精目标列表。",
  map_challenges: "地图挑战目标列表。",
  goals: "目标 ID 列表。",
  objectives: "地图挑战目标 ID 列表。",
};

function readJson(name) {
  return JSON.parse(fs.readFileSync(path.join(dataDir, `${name}.json`), "utf8"));
}

function sanitize(value, docName, parentKey = "", parentObject = null) {
  if (Array.isArray(value)) {
    return value.map((item) => sanitize(item, docName, parentKey, parentObject));
  }
  if (!value || typeof value !== "object") return value;

  const output = {};
  for (const [key, child] of Object.entries(value)) {
    if (shouldSkipField(docName, key, parentKey, value, parentObject)) continue;
    output[key] = sanitize(child, docName, key, value);
  }
  return output;
}

function shouldSkipField(docName, key, parentKey, objectValue) {
  if (isLegacyRootField(docName, key, parentKey)) return true;
  if ((key === "name_zh" || key === "name_en") && objectValue.display_name !== undefined) return true;
  if ((key === "description_zh" || key === "description_en") && objectValue.description !== undefined) return true;
  if ((key === "ui_description_zh" || key === "ui_description_en") && objectValue.description !== undefined) return true;
  if (key === "unlock_condition" && objectValue.unlock !== undefined) return true;
  if (key === "max_stack" && objectValue.max_stacks !== undefined) return true;
  if (key === "effect_list" && objectValue.modifiers !== undefined) return true;
  if (key === "effect_per_stack" && objectValue.effect !== undefined) return true;
  if (parentKey === "map_variable" && (key === "description_zh" || key === "description_en")) return true;
  return false;
}

function isLegacyRootField(docName, key, parentKey) {
  return Boolean(LEGACY_KEYS_BY_DOC[docName]?.has(key) && LEGACY_PARENT_KEYS_BY_DOC[docName]?.has(parentKey));
}

function buildSchemas(docName, rootValue) {
  const schemas = new Map();
  const rootName = `${pascal(docName)}Json`;
  collectObjectSchema(rootName, rootValue, docName, schemas, []);
  return { rootName, schemas };
}

function collectObjectSchema(typeName, samples, docName, schemas, pathParts) {
  const objects = normalizeSamples(samples).filter((sample) => sample && typeof sample === "object" && !Array.isArray(sample));
  if (objects.length === 0) return typeName;

  const fieldMap = new Map();
  for (const object of objects) {
    for (const [key, value] of Object.entries(object)) {
      if (!fieldMap.has(key)) fieldMap.set(key, { samples: [], count: 0 });
      fieldMap.get(key).samples.push(value);
      fieldMap.get(key).count += 1;
    }
  }

  const fields = [];
  for (const [key, info] of fieldMap.entries()) {
    const childType = inferType(key, info.samples, typeName, docName, schemas, [...pathParts, key]);
    fields.push({
      key,
      optional: info.count < objects.length,
      type: childType,
      description: describeField(docName, key, pathParts),
    });
  }
  schemas.set(typeName, fields);
  return typeName;
}

function normalizeSamples(samples) {
  if (!Array.isArray(samples)) return [samples];
  return samples.flatMap((sample) => Array.isArray(sample) ? sample : [sample]);
}

function inferType(key, samples, parentType, docName, schemas, pathParts) {
  const nonNull = samples.filter((sample) => sample !== null && sample !== undefined);
  if (nonNull.length === 0) return "unknown";

  const arraySamples = nonNull.filter(Array.isArray);
  if (arraySamples.length === nonNull.length) {
    const items = arraySamples.flat();
    if (items.length === 0) return "unknown[]";
    if (items.every((item) => item && typeof item === "object" && !Array.isArray(item))) {
      const itemType = rootItemName(docName, key) || `${parentType}${pascal(singular(key))}`;
      collectObjectSchema(itemType, items, docName, schemas, pathParts);
      return `${itemType}[]`;
    }
    return `${primitiveUnion(items)}[]`;
  }

  if (nonNull.every((sample) => sample && typeof sample === "object" && !Array.isArray(sample))) {
    const childType = rootItemName(docName, key) || `${parentType}${pascal(key)}`;
    collectObjectSchema(childType, nonNull, docName, schemas, pathParts);
    return childType;
  }

  return primitiveUnion(nonNull);
}

function primitiveUnion(samples) {
  const types = new Set(samples.map((value) => {
    if (value === null) return "null";
    if (Array.isArray(value)) return "unknown[]";
    if (typeof value === "string") return "string";
    if (typeof value === "number") return "number";
    if (typeof value === "boolean") return "boolean";
    if (typeof value === "object") return "Record<string, unknown>";
    return "unknown";
  }));
  return [...types].sort().join(" | ");
}

function rootItemName(docName, key) {
  return ROOT_ITEM_NAMES[docName]?.[key] || "";
}

function describeField(docName, key, pathParts) {
  const pathKey = [...pathParts, key].join(".");
  if (FIELD_DESCRIPTIONS[pathKey]) return FIELD_DESCRIPTIONS[pathKey];
  if (FIELD_DESCRIPTIONS[key]) return FIELD_DESCRIPTIONS[key];
  if (key.endsWith("_ids")) return `${key} 引用的 ID 列表。`;
  if (key.endsWith("_id")) return `${key} 引用的配置 ID。`;
  if (key.endsWith("_add")) return `${key} 加算修正值。`;
  if (key.endsWith("_multiplier_add")) return `${key} 倍率加算修正。`;
  if (key.endsWith("_multiplier")) return `${key} 倍率值。`;
  if (key.endsWith("_seconds")) return `${key} 时间值，单位秒。`;
  if (key.endsWith("_time")) return `${key} 时间点或时间长度，单位由所在配置决定。`;
  if (key.endsWith("_color")) return `${key} 颜色值，通常为十六进制字符串或 RGBA 数组。`;
  if (key.endsWith("_texture")) return `${key} 贴图资源路径，通常使用 res://。`;
  if (docName === "primary_attack" && pathParts.includes("actions")) return "主武器攻击动作参数，由动作 type 决定具体含义。";
  return `${key} 配置字段，具体含义由所在层级、type/action 枚举或运行时读取逻辑决定。`;
}

function renderFieldTables(rootName, schemas) {
	const orderedNames = [rootName, ...[...schemas.keys()].filter((name) => name !== rootName).sort()];
	const lines = [];
	for (const name of orderedNames) {
		const fields = schemas.get(name);
		if (!fields) continue;
		lines.push(`### ${name}`);
		lines.push("");
		lines.push("| 字段名 | 类型 | 是否必填 | 默认值 | 说明 | 约束 |");
		lines.push("| --- | --- | --- | --- | --- | --- |");
		for (const field of fields) {
			lines.push([
				`| \`${escapeTable(field.key)}\``,
				` \`${escapeTable(formatFieldType(field.type))}\``,
				` ${field.optional ? "否" : "是"}`,
				` ${escapeTable(defaultValueForField(field))}`,
				` ${escapeTable(field.description)}`,
				` ${escapeTable(constraintForField(field))} |`,
			].join(" |"));
		}
		lines.push("");
	}
	return lines.join("\n").trimEnd();
}

function formatFieldType(type) {
	return String(type).replace(/\binteger\b/g, "number");
}

function defaultValueForField(field) {
	if (!field.optional) return "无";
	if (field.type.endsWith("[]")) return "空数组或运行时默认值";
	if (field.type === "boolean") return "false 或运行时默认值";
	if (field.type === "string") return "空字符串或运行时默认值";
	if (field.type === "number") return "0 或运行时默认值";
	return "空对象或运行时默认值";
}

function constraintForField(field) {
	const key = field.key;
	const type = field.type;
	if (key === "id") return "同一配置池内唯一且非空";
	if (key.endsWith("_id")) return "必须指向有效配置 ID";
	if (key.endsWith("_ids")) return "数组项必须指向有效配置 ID";
	if (key === "enabled") return "true / false";
	if (key === "background_texture" || key.endsWith("_texture") || key === "icon" || key === "sprite_frames" || key === "background") return "使用 res:// 资源路径";
	if (key === "type" || key === "category" || key === "rarity" || key === "element" || key === "trigger" || key === "mode") return "见枚举值说明";
	if (type.endsWith("[]")) return "JSON 数组";
	if (isStructuredType(type)) return "结构见下方对应表格";
	return "类型必须与表格一致";
}

function isStructuredType(type) {
	const clean = String(type).replace(/\[\]$/, "");
	return /^[A-Z][A-Za-z0-9]+$/.test(clean) && !["Record", "String", "Number", "Boolean"].includes(clean);
}

function escapeTable(value) {
	return String(value).replace(/\|/g, "\\|").replace(/\n/g, "<br>");
}

function makeExample(value, depth = 0) {
  if (Array.isArray(value)) {
    if (value.length === 0) return [];
    return [makeExample(value[0], depth + 1)];
  }
  if (!value || typeof value !== "object") return value;
  if (depth >= 5) return summarizeLeaf(value);

  const output = {};
  for (const [key, child] of Object.entries(value)) {
    output[key] = makeExample(child, depth + 1);
  }
  return output;
}

function summarizeLeaf(value) {
  if (Array.isArray(value)) return value.length > 0 ? [summarizeLeaf(value[0])] : [];
  if (!value || typeof value !== "object") return value;
  const output = {};
  let count = 0;
  for (const [key, child] of Object.entries(value)) {
    output[key] = Array.isArray(child) ? [] : typeof child === "object" && child !== null ? {} : child;
    count += 1;
    if (count >= 6) break;
  }
  return output;
}

function renderConfigInfo(docName, meta) {
  return [
    "| 项目 | 说明 |",
    "| --- | --- |",
    `| 配置名称 | ${meta.name} |`,
    `| 配置编码 | ${docName} |`,
    "| 所属系统 | Roguelike Survivor |",
    `| 所属模块 | ${meta.module} |`,
    `| 配置类型 | ${meta.type} |`,
    "| 配置文件 | `data/" + docName + ".json` |",
    "| 适用环境 | dev / test / prod |",
    "| 负责人 | 项目配置维护人 / 技术负责人 |",
    `| 更新时间 | ${UPDATED_AT} |`,
    `| 文档版本 | ${DOC_VERSION} |`,
  ].join("\n");
}

function renderPurpose(meta) {
  const lines = [
    meta.purpose,
    "",
    "该配置主要用于控制：",
    "",
    "```text",
    ...meta.controls.map((item, index) => `${index + 1}. ${item}`),
    "```",
    "",
    "影响范围：",
    "",
    "```text",
    meta.impact,
    "```",
  ];
  return lines.join("\n");
}

function renderEnums(rootValue) {
  const valuesByKey = new Map();
  collectEnumValues(rootValue, valuesByKey);
  const entries = [...valuesByKey.entries()]
    .map(([key, values]) => [key, [...values].sort()])
    .filter(([key, values]) => isUsefulEnum(key, values))
    .sort(([a], [b]) => a.localeCompare(b));

  if (entries.length === 0) {
    return "本配置未发现稳定的小集合枚举字段。若新增枚举字段，请同步补充合法值说明和运行时处理逻辑。";
  }

  const lines = [];
  for (const [key, values] of entries) {
    lines.push(`### ${key}`);
    lines.push("");
    lines.push("| 枚举值 | 说明 |");
    lines.push("| --- | --- |");
    for (const value of values) {
      lines.push(`| \`${value}\` | ${describeEnumValue(key, value)} |`);
    }
    lines.push("");
  }
  return lines.join("\n").trimEnd();
}

function collectEnumValues(value, valuesByKey) {
  if (Array.isArray(value)) {
    for (const item of value) collectEnumValues(item, valuesByKey);
    return;
  }
  if (!value || typeof value !== "object") return;

  for (const [key, child] of Object.entries(value)) {
    if (typeof child === "string") {
      if (!valuesByKey.has(key)) valuesByKey.set(key, new Set());
      valuesByKey.get(key).add(child);
    } else if (Array.isArray(child) && child.every((item) => typeof item === "string")) {
      if (!valuesByKey.has(key)) valuesByKey.set(key, new Set());
      for (const item of child) valuesByKey.get(key).add(item);
    } else {
      collectEnumValues(child, valuesByKey);
    }
  }
}

function isUsefulEnum(key, values) {
  if (values.length === 0 || values.length > 30) return false;
  if (values.some((value) => value === "" || value.startsWith("res://"))) return false;
  if (key === "id" || key.endsWith("_id") || key.endsWith("_ids")) return false;
  if (["display_name", "description", "background_texture", "texture", "icon", "sprite_frames", "background"].includes(key)) return false;
  return ["type", "category", "rarity", "element", "damage_type", "damage_origin", "trigger", "mode", "tags", "role", "rank", "op", "stat"].includes(key)
    || key.endsWith("_type")
    || key.endsWith("_mode")
    || key.endsWith("_rule");
}

function describeEnumValue(key, value) {
  const known = {
    common: "普通稀有度。",
    rare: "稀有稀有度。",
    epic: "史诗稀有度。",
    legendary: "传说稀有度。",
    active: "主动技能。",
    passive: "被动或常驻效果。",
    fire: "火元素。",
    ice: "冰元素。",
    lightning: "雷电元素。",
    poison: "毒元素。",
    physical: "物理属性。",
    arcane: "奥术属性。",
    shadow: "暗影属性。",
    on_cast: "技能释放时触发。",
    on_projectile_hit: "投射物命中时触发。",
    add: "加算操作。",
    multiply: "乘算操作。",
  };
  if (known[value]) return known[value];
  if (key === "tags") return "标签值，用于筛选、协同、权重或展示。";
  if (key === "type") return "类型值，具体逻辑由对应运行时代码分支处理。";
  if (key === "mode") return "模式值，具体逻辑由对应运行时代码分支处理。";
  return "合法配置值，具体效果由对应运行时逻辑决定。";
}

function renderReferenceRules(rootValue) {
  const refs = new Set();
  collectReferenceKeys(rootValue, refs);
  if (refs.size === 0) return "本配置没有发现显式 `_id` / `_ids` 引用字段。";

  const lines = ["| 字段 | 引用关系 |", "| --- | --- |"];
  for (const key of [...refs].sort()) {
    lines.push(`| \`${key}\` | ${describeField("", key, [])} |`);
  }
  return lines.join("\n");
}

function collectReferenceKeys(value, refs) {
  if (Array.isArray(value)) {
    for (const item of value) collectReferenceKeys(item, refs);
    return;
  }
  if (!value || typeof value !== "object") return;
  for (const [key, child] of Object.entries(value)) {
    if ((key.endsWith("_id") || key.endsWith("_ids")) && key !== "id") refs.add(key);
    collectReferenceKeys(child, refs);
  }
}

function renderActivationRules(docName) {
  const source = docName === "ui_theme"
    ? "`UIButtonSkin` 在按钮创建或刷新样式时读取 `data/ui_theme.json`。"
    : "`DataManager.load_all()` 在项目启动时读取并索引主要 `data/*.json`，`GameData` 在没有 DataManager 或缓存为空时会直接读取对应 JSON 作为兜底。";
  return [
    source,
    "",
    "生效规则：",
    "",
    "```text",
    "1. JSON 文件必须能被 Godot JSON 解析为对象。",
    "2. 进入池子的数组项必须保留非空 id；DataManager 使用 id 建索引。",
    "3. 数值、布尔值和数组必须使用 JSON 原生类型，不使用字符串伪装类型。",
    "4. 资源路径统一使用 res://，资源不存在时相关 UI 或视觉表现会回退为空资源或默认样式。",
    "5. 修改配置后需要重新启动运行场景，确保 DataManager 和 GameData 缓存重新加载。",
    "```",
  ].join("\n");
}

function renderConflictRules() {
  return [
    "多条配置同时命中时按以下规则处理：",
    "",
    "```text",
    "1. 同一索引池内 id 必须唯一；重复 id 会以后写入索引的配置覆盖先写入配置。",
    "2. 升级、遗物、敌人、波次等候选池会先按 enabled、标签、前置条件、权重和运行时状态过滤。",
    "3. 权重类配置通常数值越高越容易被抽中；同一候选重复出现时会受 weight_decay、保底或排除标签影响。",
    "4. 引用字段必须指向有效 id；引用不存在时，相关功能通常会跳过该项或使用空配置。",
    "```",
  ].join("\n");
}

function renderFallbackRules() {
  return [
    "配置异常时按以下方式兜底：",
    "",
    "```text",
    "1. 文件不存在、无法打开或 JSON 解析失败时，DataManager 会记录错误并返回空对象。",
    "2. 根节点不是对象时，该配置不会进入正常索引流程。",
    "3. 期望数组的字段不是数组时，对应池返回空数组。",
    "4. 单项缺少非空 id 时，该项不会被索引。",
    "5. 可选字段缺失时，运行时代码通常使用脚本内默认值、空字符串、空数组或空字典。",
    "```",
  ].join("\n");
}

function renderValidationRules(docName) {
  return [
    "修改后建议按以下步骤验证：",
    "",
    "```powershell",
    `node -e "JSON.parse(require('fs').readFileSync('data/${docName}.json','utf8')); console.log('ok')"`,
    "node tools/check_text_encoding.js --strict-mojibake",
    "& 'C:\\Users\\dengj\\Desktop\\Godot.exe' --headless --path . --quit",
    "```",
    "",
    "回滚建议：",
    "",
    "```text",
    "1. 优先回滚本次修改过的 data/*.json 和对应 docs/*.md。",
    "2. 如果是资源路径问题，先恢复到上一个可加载的 res:// 路径。",
    "3. 如果是数值或权重问题，先恢复到上一版线上数值，再重新跑上述验证命令。",
    "```",
  ].join("\n");
}

function renderMaintenanceRules() {
  return [
    "- 新增字段前先确认运行时代码确实读取该字段；只作为备注的内容写入文档，不写入 data JSON。",
    "- 字段优先放在语义所属对象内，避免把子对象字段平铺到根层级。",
    "- 废弃兼容字段不再写入新配置文档；迁移时使用运行时代码读取的新字段。",
    "- 新增枚举值时，同步更新运行时处理逻辑、配置文档和必要的调试场景。",
    "- 修改美术资源路径时使用 `res://...`，并确认 `.import` 文件存在或可由 Godot 重新导入。",
  ].join("\n");
}

function renderGuide(docName) {
  const meta = CONFIGS[docName];
  const raw = readJson(docName);
  const sanitized = sanitize(raw, docName);
  const { rootName, schemas } = buildSchemas(docName, sanitized);
  const example = makeExample(sanitized);

  return [
    `# ${meta.name}说明文档`,
    "",
    "## 1. 配置基本信息",
    "",
    renderConfigInfo(docName, meta),
    "",
    "---",
    "",
    "## 2. 配置用途",
    "",
    renderPurpose(meta),
    "",
    "---",
    "",
    "## 3. 配置数据示例",
    "",
    "```json",
    JSON.stringify(example, null, 2),
    "```",
    "",
    "---",
    "",
    "## 4. 字段说明",
    "",
    "字段按 JSON 层级拆分为多张表。若字段类型是结构体或结构体数组，请继续查看下方同名结构表。",
    "",
    renderFieldTables(rootName, schemas),
    "",
    "---",
    "",
    "## 5. 枚举值说明",
    "",
    renderEnums(sanitized),
    "",
    "---",
    "",
    "## 6. 引用关系",
    "",
    renderReferenceRules(sanitized),
    "",
    "---",
    "",
    "## 7. 生效规则",
    "",
    renderActivationRules(docName),
    "",
    "---",
    "",
    "## 8. 多配置冲突处理",
    "",
    renderConflictRules(),
    "",
    "---",
    "",
    "## 9. 配置异常兜底",
    "",
    renderFallbackRules(),
    "",
    "---",
    "",
    "## 10. 验证与回滚",
    "",
    renderValidationRules(docName),
    "",
    "---",
    "",
    "## 11. 维护规范",
    "",
    renderMaintenanceRules(),
    "",
  ].join("\n");
}

function renderOverview() {
  const indexLines = Object.entries(CONFIGS).map(([docName, meta]) => {
    return `| \`data/${docName}.json\` | [${meta.name}](./${meta.guide}) | ${meta.module} | ${meta.type} |`;
  });

  return [
    "# 数据配置说明文档",
    "",
    "## 1. 配置基本信息",
    "",
    "| 项目 | 说明 |",
    "| --- | --- |",
    "| 配置名称 | 项目数据配置总览 |",
    "| 配置编码 | data_json_config_index |",
    "| 所属系统 | Roguelike Survivor |",
    "| 所属模块 | 数据配置 / 文档索引 |",
    "| 配置类型 | 数据源配置 / 规则配置 / 美术资源配置索引 |",
    "| 适用环境 | dev / test / prod |",
    "| 负责人 | 项目配置维护人 / 技术负责人 |",
    `| 更新时间 | ${UPDATED_AT} |`,
    `| 文档版本 | ${DOC_VERSION} |`,
    "",
    "---",
    "",
    "## 2. 配置用途",
    "",
    "本说明用于统一索引项目内 `data/*.json` 配置文件，并约束配置文档的维护格式。",
    "",
    "该配置主要用于控制：",
    "",
    "```text",
    "1. 哪些 JSON 文件属于运行时配置",
    "2. 每份配置对应哪份说明文档",
    "3. 配置字段如何按层级说明",
    "4. 配置修改后如何验证和回滚",
    "```",
    "",
    "影响范围：",
    "",
    "```text",
    "该索引影响配置维护、字段迁移、文档生成和测试验证流程；索引错误会导致维护者查错文档或漏更新文档。",
    "```",
    "",
    "---",
    "",
    "## 3. 配置文件索引",
    "",
    "| 配置文件 | 说明文档 | 所属模块 | 配置类型 |",
    "| --- | --- | --- | --- |",
    ...indexLines,
    "",
    "---",
    "",
    "## 4. 通用字段规范",
    "",
    "### StandardConfigEntry",
    "",
    "| 字段名 | 类型 | 是否必填 | 默认值 | 说明 | 约束 |",
    "| --- | --- | --- | --- | --- | --- |",
    "| `id` | `string` | 是 | 无 | 配置对象唯一 ID。 | 同一配置池内唯一且非空 |",
    "| `display_name` | `string` | 否 | 空字符串或运行时默认值 | 玩家界面展示名称。 | 类型必须与表格一致 |",
    "| `description` | `string` | 否 | 空字符串或运行时默认值 | 玩家界面展示说明。 | 类型必须与表格一致 |",
    "| `tags` | `string[]` | 否 | 空数组或运行时默认值 | 标签集合，用于筛选、协同、权重或展示。 | JSON 数组 |",
    "| `visual` | `VisualConfig` | 否 | 空对象或运行时默认值 | 视觉资源配置。 | 结构见下方对应表格 |",
    "",
    "### VisualConfig",
    "",
    "| 字段名 | 类型 | 是否必填 | 默认值 | 说明 | 约束 |",
    "| --- | --- | --- | --- | --- | --- |",
    "| `icon` | `string` | 否 | 空字符串或运行时默认值 | UI 图标资源路径。 | 使用 res:// 资源路径 |",
    "| `texture` | `string` | 否 | 空字符串或运行时默认值 | 静态贴图资源路径。 | 使用 res:// 资源路径 |",
    "| `background` | `string` | 否 | 空字符串或运行时默认值 | 背景资源路径。 | 使用 res:// 资源路径 |",
    "| `sprite_frames` | `string` | 否 | 空字符串或运行时默认值 | Godot SpriteFrames 资源路径。 | 使用 res:// 资源路径 |",
    "",
    "---",
    "",
    "## 5. 维护与验证",
    "",
    "```powershell",
    "node tools/generate_data_config_guides.js",
    "node tools/check_text_encoding.js --strict-mojibake",
    "& 'C:\\Users\\dengj\\Desktop\\Godot.exe' --headless --path . --quit",
    "```",
    "",
    "修改配置时必须写清楚：配置控制什么功能、字段含义、合法值、生效时机、冲突处理、异常兜底、验证方式和回滚方式。",
    "",
  ].join("\n");
}

function pascal(value) {
  return String(value)
    .split(/[^A-Za-z0-9]+/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join("");
}

function singular(value) {
  const text = String(value);
  if (text.endsWith("ies")) return `${text.slice(0, -3)}y`;
  if (text.endsWith("ses")) return text.slice(0, -2);
  if (text.endsWith("s")) return text.slice(0, -1);
  return text;
}

fs.mkdirSync(docsDir, { recursive: true });
for (const docName of Object.keys(CONFIGS)) {
  const filePath = path.join(docsDir, CONFIGS[docName].guide);
  fs.writeFileSync(filePath, renderGuide(docName), "utf8");
  console.log(`Generated ${path.relative(root, filePath)}`);
}

fs.writeFileSync(path.join(docsDir, "DATA_JSON_CONFIG_GUIDE.md"), renderOverview(), "utf8");
console.log("Generated docs\\DATA_JSON_CONFIG_GUIDE.md");
