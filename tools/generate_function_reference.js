const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const scriptsDir = path.join(root, "scripts");
const outputPath = path.join(root, "docs", "FUNCTION_REFERENCE.md");

const C = {
  title: "\u0047\u0044\u0053\u0063\u0072\u0069\u0070\u0074 \u51fd\u6570\u53c2\u8003",
  intro: "\u672c\u6587\u4ef6\u7531 `tools/generate_function_reference.js` \u751f\u6210\uff0c\u7528\u4e8e\u7edf\u4e00\u8bb0\u5f55 `scripts/**/*.gd` \u4e2d\u6bcf\u4e2a\u51fd\u6570\u7684\u529f\u80fd\u3001\u5165\u53c2\u548c\u51fa\u53c2\u3002\u4fee\u6539\u51fd\u6570\u7b7e\u540d\u6216\u51fd\u6570\u7528\u9014\u540e\u8bf7\u91cd\u65b0\u8fd0\u884c\uff1a",
  location: "\u4f4d\u7f6e",
  signature: "\u7b7e\u540d",
  function: "\u529f\u80fd",
  params: "\u5165\u53c2",
  returns: "\u51fa\u53c2",
  noParams: "\u65e0\u5165\u53c2\u3002",
  noReturn: "\u65e0\u8fd4\u56de\u503c\u3002",
  defaultReturn: "\u672a\u663e\u5f0f\u58f0\u660e\uff0c\u6309 Godot \u9ed8\u8ba4\u8fd4\u56de null\u3002",
  returnType: "\u8fd4\u56de",
  get: "\u83b7\u53d6",
  set: "\u8bbe\u7f6e",
  judge: "\u5224\u65ad",
  apply: "\u5e94\u7528",
  update: "\u66f4\u65b0",
  build: "\u6784\u5efa",
  create: "\u521b\u5efa",
  load: "\u52a0\u8f7d",
  save: "\u4fdd\u5b58",
  clear: "\u6e05\u7406",
  reset: "\u91cd\u7f6e",
  record: "\u8bb0\u5f55",
  resolve: "\u89e3\u6790",
  calculate: "\u8ba1\u7b97",
  find: "\u67e5\u627e",
  show: "\u663e\u793a",
  hide: "\u9690\u85cf",
  handle: "\u5904\u7406",
  ensure: "\u786e\u4fdd",
  readReturn: "\u8bfb\u53d6\u5e76\u8fd4\u56de",
  condition: "\u662f\u5426\u6ee1\u8db3",
  logicCondition: "\u903b\u8f91\u6761\u4ef6",
  currentFlow: "\u5230\u5f53\u524d\u6d41\u7a0b",
  dataOrNode: "\u6240\u9700\u7684\u6570\u636e\u6216\u8282\u70b9\u7ed3\u6784",
  event: "\u4e8b\u4ef6",
  hook: "\u4fdd\u7559\u5f53\u524d\u6a21\u5757\u7684\u6269\u5c55\u5165\u53e3\uff0c\u5f53\u524d\u6ca1\u6709\u989d\u5916\u8fd0\u884c\u903b\u8f91\u3002",
  calls: "\u8c03\u7528",
  writes: "\u5199\u5165/\u66f4\u65b0",
  emits: "\u53d1\u51fa",
  returnExpr: "\u8fd4\u56de\u8868\u8fbe\u5f0f",
  signal: "signal",
  etc: "\u7b49",
  items: "\u9879",
};

const EXACT_DESCRIPTIONS = {
  "scripts/combat/damage_system.gd::calculate": "\u8ba1\u7b97\u4e00\u6b21\u4f24\u5bb3\u7ed3\u7b97\uff0c\u5305\u542b\u4f24\u5bb3\u5305\u6807\u51c6\u5316\u3001\u66b4\u51fb\u3001\u9632\u5fa1\u62b5\u6263\u3001\u6297\u6027\u3001\u72b6\u6001\u6613\u4f24\u548c\u6700\u7ec8\u4f24\u5bb3\u7ed3\u679c\u3002",
  "scripts/combat/damage_system.gd::_normalize_packet": "\u628a\u65e7\u7248\u4f24\u5bb3\u53c2\u6570\u6216\u65b0\u7248\u4f24\u5bb3\u5305\u7edf\u4e00\u8f6c\u6362\u6210\u6807\u51c6\u4f24\u5bb3\u5b57\u5178\u3002",
  "scripts/combat/damage_system.gd::_get_defense_effectiveness": "\u83b7\u53d6\u4f24\u5bb3\u5305\u7684\u9632\u5fa1\u5c5e\u6027\u62b5\u6263\u6bd4\u4f8b\uff0c\u5e76\u6309\u4f24\u5bb3\u7c7b\u578b\u7ed9\u51fa\u9ed8\u8ba4\u9632\u5fa1\u6709\u6548\u7cfb\u6570\u3002",
  "scripts/combat/damage_system.gd::_get_resistance_multiplier": "\u83b7\u53d6\u76ee\u6807\u5bf9\u6307\u5b9a\u5143\u7d20\u6216\u4f24\u5bb3\u7c7b\u522b\u7684\u6297\u6027\u4f24\u5bb3\u500d\u7387\u3002",
  "scripts/combat/damage_system.gd::_get_status_damage_taken_multiplier": "\u83b7\u53d6\u76ee\u6807\u5f53\u524d\u72b6\u6001\u6548\u679c\u5e26\u6765\u7684\u627f\u4f24\u500d\u7387\u3002",
  "scripts/combat/damage_system.gd::_infer_damage_category": "\u6839\u636e\u4f24\u5bb3\u7c7b\u578b\u548c\u5143\u7d20\u63a8\u65ad\u4f24\u5bb3\u7c7b\u522b\u3002",
  "scripts/combat/damage_system.gd::_is_damage_category": "\u5224\u65ad\u4f20\u5165\u5b57\u7b26\u4e32\u662f\u5426\u5c5e\u4e8e\u4f24\u5bb3\u7c7b\u522b\u679a\u4e3e\u3002",
  "scripts/combat/damage_system.gd::_result": "\u7ec4\u88c5\u6807\u51c6\u4f24\u5bb3\u7ed3\u7b97\u7ed3\u679c\u5b57\u5178\u3002",
  "scripts/skills/skill_modifier.gd::calculate": "\u6839\u636e\u5c5e\u6027\u540d\u548c\u4fee\u6b63\u8868\u8ba1\u7b97\u6700\u7ec8\u5c5e\u6027\u503c\uff0c\u652f\u6301 override\u3001add\u3001multiplier_add \u548c multiplier\u3002",
  "scripts/skills/skill_modifier.gd::merge_modifiers": "\u5408\u5e76\u591a\u7ec4\u6280\u80fd\u6216\u8fd0\u884c\u65f6\u4fee\u6b63\u5b57\u5178\u3002",
  "scripts/skills/skill_modifier.gd::_is_number": "\u5224\u65ad\u503c\u662f\u5426\u662f\u53ef\u53c2\u4e0e\u6570\u503c\u4fee\u6b63\u7684\u6570\u5b57\u7c7b\u578b\u3002",
  "scripts/skills/skill_modifier.gd::_match_number_type": "\u628a\u8ba1\u7b97\u540e\u7684\u6570\u503c\u8f6c\u56de\u4e0e\u57fa\u7840\u503c\u76f8\u5339\u914d\u7684\u6570\u5b57\u7c7b\u578b\u3002",
  "scripts/game/run_scene_coordinator.gd::start_run": "在角色、武器和地图都确定后创建主战斗场景，配置玩家、地图背景、地图变量、刷怪器和运行时信号源。",
  "scripts/ui/ui_manager.gd::_start_run": "从地图选择界面进入单局：保存当前搭配与地图上下文，创建战斗场景，重置 HUD、统计和局内状态。",
  "scripts/game/run_scene_coordinator.gd::_ensure_run_scene": "确保战斗主场景已经实例化；若尚未创建则加载 scenes/main.tscn 并挂到 UI 外层节点下。",
  "scripts/game/run_scene_coordinator.gd::teardown": "结束单局时拆除战斗主场景、清空运行节点和局内弹窗引用。",
  "scripts/game/run_scene_coordinator.gd::_setup_map_variable_runtime": "按所选地图配置创建或刷新地图变量运行器，用于毒雾、岩浆裂隙和地图刷怪压力等机制。",
  "scripts/upgrades/upgrade_pool.gd::generate_options": "根据当前主攻等级、Lv2 分支状态、普通升级池和进化条件生成本次升级三选一。",
  "scripts/upgrades/upgrade_pool.gd::_select_branch_choice_stage_options": "在尚未选择 Lv2 分支时生成分支选择阶段的三选一，保留一个普通升级混入位并避免提前深挖分支。",
  "scripts/upgrades/upgrade_pool.gd::_select_growth_stage_options": "在已确定分支或无需分支选择时生成主攻成长、已选分支深化、普通升级和进化候选。",
  "scripts/upgrades/upgrade_pool.gd::_build_branch_choice_options": "为当前武器的 Lv2 可选分支构建升级卡；已选择分支后不再生成其它 Lv2 分支。",
  "scripts/upgrades/upgrade_pool.gd::_build_skill_level_up_options": "为玩家已拥有且未满级的技能构建主攻升级选项。",
  "scripts/upgrades/upgrade_pool.gd::_build_level_up_upgrade_options": "从普通局内升级配置中构建可叠加的属性、Boss、生存或功能升级卡。",
  "scripts/upgrades/upgrade_pool.gd::_get_selected_branch_level_config": "读取当前已选武器分支在目标等级上的深化配置。",
  "scripts/upgrades/upgrade_pool.gd::_enforce_guaranteed_options": "按低血量、Boss 前和阶段规则补齐本次三选一必须出现的保底标签。",
  "scripts/weapons/weapon_branch_system.gd::get_available_branches": "获取当前已装备武器在 Lv2 可选择的分支列表；已有分支时返回空列表避免重复选择其它 Lv2 分支。",
  "scripts/weapons/weapon_branch_system.gd::apply_branch": "应用玩家选择的 Lv2 武器分支，记录分支 ID、标记技能已学习并立即应用该分支当前等级配置。",
  "scripts/weapons/weapon_branch_system.gd::apply_selected_branch_level": "当主攻等级提升后，只对已选分支应用对应等级的深化配置。",
  "scripts/weapons/weapon_branch_system.gd::has_applied_selected_branch_level": "判断当前已选分支的某个等级配置是否已经应用过，避免重复叠加分支效果。",
  "scripts/weapons/weapon_branch_system.gd::_apply_branch_level_config": "把分支等级配置中的技能修正、运行时标签、事件和角色修正写入对应运行对象。",
  "scripts/game/save_manager.gd::spend_soul_stones": "尝试消耗灵魂石；余额足够时写回存档并返回成功。",
  "scripts/game/save_manager.gd::mark_map_cleared": "把指定地图标记为已通关，用于地图解锁和结算进度。",
  "scripts/game/save_manager.gd::purchase_permanent_upgrade": "消耗灵魂石购买一层永久升级，并把新等级写入存档。",
  "scripts/game/save_manager.gd::purchase_character": "消耗灵魂石解锁指定角色，并写入角色解锁存档。",
  "scripts/game/run_diagnostic_service.gd::build_diagnostic": "根据本局结算状态、伤害结构、受伤来源和构筑进度生成失败诊断与下局推荐。",
  "scripts/game/run_diagnostic_service.gd::_pick_primary_issue": "从清怪、Boss 单体、状态构筑、生存、索敌和成长进度中选出本局最主要问题。",
  "scripts/game/run_diagnostic_service.gd::_build_recommendation": "按诊断问题生成下一局推荐角色、武器、地图和简短理由。",
  "scripts/game/run_progression_service.gd::build_progression_summary": "根据结算结果计算本局资源、武器熟练度、角色专精、地图挑战和解锁进度摘要。",
  "scripts/player/player_controller.gd::add_experience": "给玩家增加经验并在达到阈值时升级、触发三选一等待队列。",
  "scripts/player/player_controller.gd::apply_upgrade": "接收升级选项并分发到技能升级、分支、进化或普通升级逻辑。",
  "scripts/player/player_controller.gd::_apply_branch_upgrade": "把 Lv2 分支或后续分支等级升级应用到当前武器分支系统。",
  "scripts/combat/projectile.gd::_update_direction_state": "根据当前飞行方向更新投射物旋转和朝向状态。",
  "scripts/combat/projectile.gd::_reset_pierce_counter": "按穿透配置重置投射物剩余命中次数。",
  "scripts/combat/projectile.gd::_consume_pierce": "投射物命中后消耗一次穿透次数，耗尽时播放结束表现并销毁。",
  "scripts/combat/orbit_object.gd::_emit_nearby_enemy_projectile_events": "检测环绕物附近的敌方投射物并发出可被技能事件监听的拦截事件。",
  "scripts/combat/status_effect_manager.gd::apply_status": "向目标添加或刷新状态效果，处理堆叠、持续时间、Boss/精英规则、转换状态和状态应用通知。",
  "scripts/combat/status_effect_manager.gd::get_damage_taken_multiplier": "汇总目标当前状态带来的承伤倍率，并按伤害类型和类别限制上限。",
  "scripts/combat/status_effect_manager.gd::_update_damage_over_time": "推进 DOT 状态的 tick 计时并在到点时结算持续伤害。",
  "scripts/enemies/enemy_spawner.gd::_process_wave_spawn": "按当前波次的刷怪间隔、存活上限、敌人分组权重和倍率持续生成普通敌人。",
  "scripts/enemies/enemy_spawner.gd::_process_boss_event": "到达 Boss 时间线事件时清理普通怪、生成 Boss、切换 Boss 阶段状态并通知 UI。",
  "scripts/enemies/enemy_spawner.gd::_finish_wave": "完成当前波次：吸收经验、发出清波事件，并启动下一波或进入普通阶段结束流程。",
  "scripts/enemies/enemy_base.gd::take_damage": "让敌人承受一次伤害，应用协同修正、Boss 核心减伤、死亡判定、调试显示和受击表现。",
  "scripts/enemies/enemy_base.gd::_die": "处理敌人死亡：发奖励、通知协同、触发死亡效果、掉落经验并从场景移除。",
  "scripts/characters/character_trait_system.gd::absorb_damage": "按角色天赋护盾规则吸收即将受到的伤害，并同步天赋运行状态。",
  "scripts/characters/character_trait_system.gd::_update_periodic_shield": "按时间恢复或刷新角色天赋提供的周期护盾。",
  "scripts/characters/character_trait_system.gd::_break_moving_bonus": "在角色停止移动或受条件影响时中断移动累积加成。",
};

const DOMAINS = [
  ["scripts/combat/", "\u6218\u6597"],
  ["scripts/characters/", "\u89d2\u8272"],
  ["scripts/enemies/", "\u654c\u4eba"],
  ["scripts/game/", "\u6e38\u620f\u8fdb\u5ea6/\u5b58\u6863"],
  ["scripts/maps/", "\u5730\u56fe"],
  ["scripts/player/", "\u73a9\u5bb6"],
  ["scripts/skills/", "\u6280\u80fd"],
  ["scripts/ui/", "UI"],
  ["scripts/upgrades/", "\u5347\u7ea7"],
  ["scripts/weapons/", "\u6b66\u5668"],
];

const FILE_CONTEXTS = {
  "scripts/characters/character_definition.gd": ["\u89d2\u8272\u5b9a\u4e49", "\u628a characters.json \u4e2d\u7684\u89d2\u8272\u57fa\u7840\u5c5e\u6027\u3001\u5929\u8d4b\u548c\u53ef\u7528\u6b66\u5668\u8f6c\u6210\u8fd0\u884c\u53ef\u8bfb\u5bf9\u8c61"],
  "scripts/characters/character_runtime.gd": ["\u89d2\u8272\u8fd0\u884c\u72b6\u6001", "\u7ef4\u62a4\u5f53\u524d\u89d2\u8272\u3001\u5df2\u88c5\u5907\u6b66\u5668\u3001\u5206\u652f\u548c\u4e34\u65f6\u5c5e\u6027\u4fee\u6b63"],
  "scripts/characters/character_trait_system.gd": ["\u89d2\u8272\u5929\u8d4b\u7cfb\u7edf", "\u5728\u79fb\u52a8\u3001\u65bd\u653e\u3001\u53d7\u4f24\u548c\u51fb\u6740\u573a\u666f\u4e2d\u89e6\u53d1\u804c\u4e1a\u5929\u8d4b"],
  "scripts/combat/area_effect.gd": ["\u6301\u7eed\u533a\u57df\u6548\u679c", "\u7ef4\u62a4\u573a\u5730\u7c7b\u6280\u80fd\u7684\u534a\u5f84\u3001tick \u4f24\u5bb3\u3001\u72b6\u6001\u548c\u8868\u73b0"],
  "scripts/combat/combat_object_factory.gd": ["\u6218\u6597\u7269\u4ef6\u5de5\u5382", "\u6839\u636e\u6280\u80fd\u548c combat_objects.json \u521b\u5efa\u6295\u5c04\u7269\u3001\u533a\u57df\u548c\u73af\u7ed5\u7269"],
  "scripts/combat/damage_area.gd": ["\u77ac\u65f6\u4f24\u5bb3\u533a\u57df", "\u5904\u7406\u654c\u4eba\u6216\u5730\u56fe\u5371\u9669\u7684\u8303\u56f4\u4f24\u5bb3\u5224\u5b9a"],
  "scripts/combat/damage_system.gd": ["\u4f24\u5bb3\u7ed3\u7b97\u7cfb\u7edf", "\u7edf\u4e00\u7ed3\u7b97\u57fa\u7840\u4f24\u5bb3\u3001\u66b4\u51fb\u3001\u9632\u5fa1\u3001\u6297\u6027\u548c\u627f\u4f24\u4fee\u6b63"],
  "scripts/combat/orbit_object.gd": ["\u73af\u7ed5\u6218\u6597\u7269", "\u7ef4\u62a4\u56f4\u7ed5\u73a9\u5bb6\u65cb\u8f6c\u7684\u6301\u7eed\u547d\u4e2d\u7269\u4ef6"],
  "scripts/combat/projectile.gd": ["\u6295\u5c04\u7269", "\u7ef4\u62a4\u6280\u80fd\u5b50\u5f39\u7684\u98de\u884c\u3001\u547d\u4e2d\u3001\u7a7f\u900f\u3001\u72b6\u6001\u548c\u89c6\u89c9"],
  "scripts/combat/status_effect_manager.gd": ["\u72b6\u6001\u6548\u679c\u7ba1\u7406\u5668", "\u7ba1\u7406\u654c\u4eba\u6216\u73a9\u5bb6\u8eab\u4e0a\u7684\u72b6\u6001\u5806\u53e0\u3001DOT\u3001\u63a7\u5236\u548c\u6613\u4f24"],
  "scripts/core/data_manager.gd": ["\u914d\u7f6e\u6570\u636e\u7ba1\u7406\u5668", "\u542f\u52a8\u65f6\u8bfb\u53d6 data/*.json \u5e76\u5411\u5404\u7cfb\u7edf\u63d0\u4f9b\u914d\u7f6e\u67e5\u8be2"],
  "scripts/debug/dev_debug_panel.gd": ["\u5f00\u53d1\u8c03\u8bd5\u9762\u677f", "\u5728\u5c40\u5185\u624b\u52a8\u5207\u6362\u6d41\u7a0b\u3001\u751f\u6210\u654c\u4eba\u3001\u8c03\u6574\u6280\u80fd\u548c\u89c2\u5bdf\u72b6\u6001"],
  "scripts/debug/full_flow_autoplay.gd": ["\u5168\u6d41\u7a0b\u81ea\u52a8\u6d4b\u8bd5", "\u81ea\u52a8\u8d70\u5b8c\u83dc\u5355\u3001\u5f00\u5c40\u3001\u6218\u6597\u548c\u5f39\u7a97\u9009\u62e9\u6d41\u7a0b"],
  "scripts/debug/player_debug_overlay.gd": ["\u73a9\u5bb6\u8c03\u8bd5\u53e0\u52a0\u5c42", "\u7ed8\u5236\u62fe\u53d6\u8303\u56f4\u548c\u6280\u80fd\u653b\u51fb\u8303\u56f4"],
  "scripts/debug/progression_service_check.gd": ["\u8fdb\u5ea6\u670d\u52a1\u68c0\u67e5", "\u9a8c\u8bc1\u7ed3\u7b97\u8fdb\u5ea6\u3001\u89e3\u9501\u548c\u5b58\u6863\u903b\u8f91"],
  "scripts/debug/skill_progression_check.gd": ["\u6280\u80fd\u6210\u957f\u68c0\u67e5", "\u9a8c\u8bc1\u4e3b\u653b\u51fb\u5347\u7ea7\u3001Lv2 \u5206\u652f\u9501\u5b9a\u548c Lv5 \u540e\u9009\u9879\u89c4\u5219"],
  "scripts/debug/visual_config_check.gd": ["\u89c6\u89c9\u914d\u7f6e\u68c0\u67e5", "\u9a8c\u8bc1\u89d2\u8272\u3001\u654c\u4eba\u3001\u72b6\u6001\u548c\u8c03\u8bd5\u89c6\u89c9\u914d\u7f6e"],
  "scripts/debug/wave_system_check.gd": ["\u6ce2\u6b21\u7cfb\u7edf\u68c0\u67e5", "\u9a8c\u8bc1\u5730\u56fe\u80cc\u666f\u3001\u8fb9\u754c\u3001\u5237\u602a\u4e0a\u9650\u548c\u6ce2\u6b21\u6536\u5c3e"],
  "scripts/drops/exp_gem.gd": ["\u7ecf\u9a8c\u6676\u77f3", "\u5904\u7406\u7ecf\u9a8c\u6389\u843d\u3001\u78c1\u5438\u98de\u884c\u548c\u73a9\u5bb6\u62fe\u53d6"],
  "scripts/drops/magnet_pickup.gd": ["\u78c1\u5438\u62fe\u53d6\u914d\u7f6e", "\u63d0\u4f9b\u78c1\u5438\u534a\u5f84\u548c\u98de\u884c\u901f\u5ea6\u7b49\u6389\u843d\u7269\u53c2\u6570"],
  "scripts/enemies/enemy_action_executor.gd": ["\u654c\u4eba\u884c\u4e3a\u6267\u884c\u5668", "\u6267\u884c\u8fdc\u7a0b\u5c04\u51fb\u3001\u7206\u70b8\u3001\u6b7b\u4ea1\u6548\u679c\u548c Boss \u6280\u80fd"],
  "scripts/enemies/enemy_attack_telegraph.gd": ["\u654c\u4eba\u653b\u51fb\u9884\u8b66", "\u5728\u8fdc\u7a0b\u6216\u8303\u56f4\u653b\u51fb\u524d\u7ed8\u5236\u53ef\u8bfb\u9884\u8b66\u7ebf"],
  "scripts/enemies/enemy_base.gd": ["\u654c\u4eba\u672c\u4f53", "\u7ef4\u62a4\u654c\u4eba\u884c\u4e3a\u3001\u79fb\u52a8\u3001\u53d7\u4f24\u3001\u6389\u843d\u3001Boss \u6280\u80fd\u548c\u6b7b\u4ea1\u5904\u7406"],
  "scripts/enemies/enemy_debug_display_controller.gd": ["\u654c\u4eba\u8c03\u8bd5\u663e\u793a", "\u663e\u793a\u654c\u4eba\u8840\u6761\u548c\u4f24\u5bb3\u6570\u5b57"],
  "scripts/enemies/enemy_reward_controller.gd": ["\u654c\u4eba\u5956\u52b1\u63a7\u5236\u5668", "\u8bb0\u5f55\u654c\u4eba\u4f24\u5bb3\u8d21\u732e\u3001\u51fb\u6740\u534f\u540c\u548c\u7075\u9b42\u77f3\u5956\u52b1"],
  "scripts/enemies/enemy_spawner.gd": ["\u654c\u4eba\u6ce2\u6b21\u751f\u6210\u5668", "\u6309\u5730\u56fe\u4e0e waves.json \u63a8\u8fdb\u6ce2\u6b21\u3001\u65f6\u95f4\u7ebf\u4e8b\u4ef6\u3001\u7cbe\u82f1\u548c Boss"],
  "scripts/enemies/enemy_status_display_controller.gd": ["\u654c\u4eba\u72b6\u6001\u663e\u793a", "\u5728\u654c\u4eba\u5934\u9876\u663e\u793a\u72b6\u6001\u7b80\u5199"],
  "scripts/enemies/enemy_status_facade.gd": ["\u654c\u4eba\u72b6\u6001\u95e8\u9762", "\u5c06\u654c\u4eba\u72b6\u6001\u8bf7\u6c42\u7edf\u4e00\u8f6c\u53d1\u5230 StatusEffectManager"],
  "scripts/enemies/enemy_visual_controller.gd": ["\u654c\u4eba\u89c6\u89c9\u63a7\u5236\u5668", "\u6839\u636e\u884c\u4e3a\u3001\u53d7\u4f24\u548c\u72b6\u6001\u66f4\u65b0\u654c\u4eba\u89c6\u89c9"],
  "scripts/game/game_data.gd": ["\u9759\u6001\u6e38\u620f\u6570\u636e\u63a5\u53e3", "\u4e3a UI\u3001\u6218\u6597\u548c\u7ed3\u7b97\u63d0\u4f9b\u7edf\u4e00\u7684\u914d\u7f6e\u8bfb\u53d6\u5165\u53e3"],
  "scripts/game/run_diagnostic_service.gd": ["\u5355\u5c40\u8bca\u65ad\u670d\u52a1", "\u6839\u636e\u7ed3\u7b97\u7edf\u8ba1\u5206\u6790\u5931\u8d25\u539f\u56e0\u548c\u4e0b\u5c40\u63a8\u8350"],
  "scripts/game/run_progression_service.gd": ["\u5355\u5c40\u8fdb\u5ea6\u7ed3\u7b97\u670d\u52a1", "\u628a\u5355\u5c40\u6210\u679c\u5199\u5165\u89d2\u8272\u4e13\u7cbe\u3001\u5730\u56fe\u6311\u6218\u3001\u6b66\u5668\u719f\u7ec3\u548c\u8d44\u6e90"],
  "scripts/game/run_scene_coordinator.gd": ["\u5355\u5c40\u573a\u666f\u534f\u8c03\u5668", "\u5728\u9009\u5b8c\u89d2\u8272\u3001\u6b66\u5668\u548c\u5730\u56fe\u540e\u5b9e\u4f8b\u5316\u6218\u6597\u573a\u666f\u5e76\u914d\u7f6e\u8fd0\u884c\u8282\u70b9"],
  "scripts/game/run_stats_tracker.gd": ["\u5355\u5c40\u7edf\u8ba1\u8ddf\u8e2a\u5668", "\u8bb0\u5f55\u4f24\u5bb3\u5f52\u56e0\u3001\u53d7\u4f24\u6765\u6e90\u3001\u51fb\u6740\u3001\u5956\u52b1\u3001Boss \u548c\u5730\u56fe\u4e8b\u4ef6"],
  "scripts/game/save_manager.gd": ["\u5b58\u6863\u7ba1\u7406\u5668", "\u8bfb\u5199\u7075\u9b42\u77f3\u3001\u6c38\u4e45\u5347\u7ea7\u3001\u89e3\u9501\u3001\u6311\u6218\u548c\u6700\u8fd1\u5355\u5c40\u6458\u8981"],
  "scripts/maps/map_runtime.gd": ["\u5730\u56fe\u8fd0\u884c\u5de5\u5177", "\u5904\u7406\u5730\u56fe\u89e3\u9501\u3001\u80cc\u666f\u8d34\u56fe\u548c\u573a\u666f\u80cc\u666f\u5e94\u7528"],
  "scripts/maps/map_variable_runtime.gd": ["\u5730\u56fe\u53d8\u91cf\u8fd0\u884c\u5668", "\u5b9e\u73b0\u6bd2\u96fe\u3001\u5ca9\u6d46\u3001\u901a\u9053\u538b\u529b\u7b49\u5730\u56fe\u673a\u5236"],
  "scripts/maps/responsive_background.gd": ["\u81ea\u9002\u5e94\u5730\u56fe\u80cc\u666f", "\u6839\u636e\u89c6\u53e3\u548c\u76f8\u673a\u7f29\u653e\u80cc\u666f\u5e76\u540c\u6b65\u73a9\u5bb6\u79fb\u52a8\u8fb9\u754c"],
  "scripts/player/player_controller.gd": ["\u73a9\u5bb6\u63a7\u5236\u5668", "\u5904\u7406\u5c40\u5185\u73a9\u5bb6\u79fb\u52a8\u3001\u751f\u547d\u3001\u7ecf\u9a8c\u5347\u7ea7\u3001\u5347\u7ea7\u9009\u9879\u548c\u89d2\u8272\u6b66\u5668\u914d\u7f6e"],
  "scripts/player/player_modifier_applier.gd": ["\u73a9\u5bb6\u5c5e\u6027\u4fee\u6b63\u5e94\u7528\u5668", "\u5c06\u6c38\u4e45\u5347\u7ea7\u3001\u89d2\u8272\u548c\u5c40\u5185\u4fee\u6b63\u843d\u5230\u73a9\u5bb6\u6570\u503c"],
  "scripts/player/player_stats.gd": ["\u73a9\u5bb6\u57fa\u7840\u6570\u503c", "\u63d0\u4f9b\u79fb\u52a8\u3001\u751f\u547d\u548c\u7ecf\u9a8c\u6210\u957f\u7684\u5bfc\u51fa\u914d\u7f6e"],
  "scripts/player/player_visual_controller.gd": ["\u73a9\u5bb6\u89c6\u89c9\u63a7\u5236\u5668", "\u6839\u636e\u79fb\u52a8\u3001\u53d7\u4f24\u548c\u751f\u547d\u72b6\u6001\u5207\u6362\u73a9\u5bb6\u8868\u73b0"],
  "scripts/relics/relic_manager.gd": ["\u9057\u7269\u7ba1\u7406\u5668", "\u7ba1\u7406\u5c40\u5185\u9057\u7269\u83b7\u53d6\u3001\u89e6\u53d1\u6761\u4ef6\u3001\u51b7\u5374\u6b21\u6570\u548c\u6280\u80fd\u4fee\u6b63"],
  "scripts/skills/condition_evaluator.gd": ["\u6280\u80fd\u6761\u4ef6\u5224\u5b9a\u5668", "\u5224\u5b9a\u6280\u80fd\u4e8b\u4ef6\u914d\u7f6e\u4e2d\u7684\u89e6\u53d1\u6761\u4ef6"],
  "scripts/skills/modifier_resolver.gd": ["\u6280\u80fd\u4fee\u6b63\u89e3\u6790\u5668", "\u7edf\u4e00\u89e3\u6790\u6280\u80fd\u3001\u88ab\u52a8\u3001\u9057\u7269\u548c\u8fd0\u884c\u65f6\u4fee\u6b63"],
  "scripts/skills/skill_action_executor.gd": ["\u6280\u80fd\u52a8\u4f5c\u6267\u884c\u5668", "\u6267\u884c\u6280\u80fd components/events \u914d\u7f6e\u4e2d\u7684\u4f24\u5bb3\u3001\u72b6\u6001\u3001\u53ec\u5524\u548c\u51fb\u9000\u7b49\u52a8\u4f5c"],
  "scripts/skills/skill_component_runner.gd": ["\u6280\u80fd\u7ec4\u4ef6\u8fd0\u884c\u5668", "\u6309\u51b7\u5374\u548c\u76ee\u6807\u6761\u4ef6\u9a71\u52a8\u4e3b\u52a8\u6280\u80fd\u7ec4\u4ef6"],
  "scripts/skills/skill_definition.gd": ["\u6280\u80fd\u5b9a\u4e49", "\u628a primary_attack.json \u4e2d\u7684\u4e3b\u6b66\u5668\u653b\u51fb\u6807\u7b7e\u3001\u57fa\u7840\u6570\u503c\u3001\u7ec4\u4ef6\u548c\u4e8b\u4ef6\u8f6c\u6210\u53ef\u8bfb\u5bf9\u8c61"],
  "scripts/skills/skill_event_bus.gd": ["\u6280\u80fd\u4e8b\u4ef6\u603b\u7ebf", "\u5c06\u547d\u4e2d\u3001\u65bd\u653e\u7b49\u4e8b\u4ef6\u5206\u53d1\u7ed9\u6280\u80fd\u3001\u9057\u7269\u548c\u8fde\u9501\u6548\u679c"],
  "scripts/skills/skill_executor.gd": ["\u6280\u80fd\u6267\u884c\u5668", "\u5728\u7269\u7406\u5e27\u4e2d\u63a8\u8fdb\u73a9\u5bb6\u5df2\u62e5\u6709\u6280\u80fd\u7684\u81ea\u52a8\u91ca\u653e"],
  "scripts/skills/skill_instance.gd": ["\u6280\u80fd\u5b9e\u4f8b", "\u7ef4\u62a4\u5df2\u5b66\u6280\u80fd\u7684\u7b49\u7ea7\u3001\u51b7\u5374\u3001\u5206\u652f\u5e94\u7528\u8bb0\u5f55\u548c\u8fd0\u884c\u4fee\u6b63"],
  "scripts/skills/skill_manager.gd": ["\u6280\u80fd\u7ba1\u7406\u5668", "\u7ba1\u7406\u73a9\u5bb6\u5df2\u5b66\u6280\u80fd\u3001\u4e3b\u52a8\u6280\u80fd\u4e0a\u9650\u3001\u5347\u7ea7\u548c\u7efc\u5408\u4fee\u6b63"],
  "scripts/skills/skill_modifier.gd": ["\u6280\u80fd\u4fee\u6b63\u8ba1\u7b97\u5668", "\u8ba1\u7b97 override/add/multiplier \u7b49\u5c5e\u6027\u4fee\u6b63\u540e\u7684\u6700\u7ec8\u503c"],
  "scripts/skills/skill_stat_service.gd": ["\u6280\u80fd\u6570\u503c\u670d\u52a1", "\u6839\u636e\u6280\u80fd\u5b9e\u4f8b\u548c\u5916\u90e8\u4fee\u6b63\u8bfb\u53d6\u6700\u7ec8\u6280\u80fd\u6570\u503c"],
  "scripts/skills/synergy_manager.gd": ["\u6280\u80fd\u534f\u540c\u7cfb\u7edf", "\u6839\u636e\u5df2\u62e5\u6709\u6280\u80fd\u6807\u7b7e\u542f\u7528\u534f\u540c\u5e76\u5904\u7406\u4f24\u5bb3\u3001\u51fb\u6740\u548c\u72b6\u6001\u89e6\u53d1"],
  "scripts/skills/targeting_service.gd": ["\u6280\u80fd\u5bfb\u654c\u670d\u52a1", "\u4e3a\u4e3b\u653b\u51fb\u548c\u6280\u80fd\u63d0\u4f9b\u76ee\u6807\u9009\u62e9\u89c4\u5219"],
  "scripts/upgrades/run_reward_pool.gd": ["\u5c40\u5185\u5956\u52b1\u6c60", "\u4e3a\u7cbe\u82f1\u5956\u52b1\u548c Boss \u524d\u795d\u798f\u751f\u6210\u5019\u9009\u9879"],
  "scripts/upgrades/upgrade_offer_policy.gd": ["\u5347\u7ea7\u63a8\u8350\u7b56\u7565", "\u6839\u636e\u4f4e\u8840\u3001\u5c40\u5185\u65f6\u95f4\u3001\u6ce2\u6b21\u548c\u6807\u7b7e\u8ba1\u7b97\u5347\u7ea7\u6743\u91cd\u4e0e\u4fdd\u5e95"],
  "scripts/upgrades/upgrade_option.gd": ["\u5347\u7ea7\u9009\u9879", "\u7edf\u4e00\u8868\u793a\u4e09\u9009\u4e00\u548c\u5956\u52b1\u5f39\u7a97\u4e2d\u7684\u5361\u7247\u6570\u636e"],
  "scripts/upgrades/upgrade_pool.gd": ["\u5347\u7ea7\u6c60", "\u751f\u6210\u4e3b\u653b\u51fb\u6210\u957f\u3001Lv2 \u5206\u652f\u3001\u5206\u652f\u6df1\u5316\u3001\u666e\u901a\u5347\u7ea7\u548c\u8fdb\u5316\u9009\u9879"],
  "scripts/visual/visual_config_applier.gd": ["\u89c6\u89c9\u914d\u7f6e\u5e94\u7528\u5668", "\u628a\u6570\u636e\u8868\u4e2d\u7684\u8d34\u56fe\u3001\u989c\u8272\u3001\u7f29\u653e\u548c\u72b6\u6001\u8868\u73b0\u5e94\u7528\u5230\u8282\u70b9"],
  "scripts/weapons/weapon_branch_system.gd": ["\u6b66\u5668\u5206\u652f\u7cfb\u7edf", "\u5728 Lv2 \u786e\u5b9a\u5206\u652f\u540e\u5e94\u7528\u8be5\u5206\u652f\u7684\u540e\u7eed\u7b49\u7ea7\u914d\u7f6e"],
  "scripts/weapons/weapon_definition.gd": ["\u6b66\u5668\u5b9a\u4e49", "\u628a weapons.json \u4e2d\u7684\u521d\u59cb\u6280\u80fd\u3001\u5206\u652f\u3001\u6807\u7b7e\u548c\u89d2\u8272\u9650\u5236\u8f6c\u6210\u53ef\u8bfb\u5bf9\u8c61"],
  "scripts/weapons/weapon_equip_system.gd": ["\u6b66\u5668\u88c5\u5907\u7cfb\u7edf", "\u6821\u9a8c\u89d2\u8272\u53ef\u7528\u6b66\u5668\u5e76\u5728\u5355\u5c40\u4e2d\u9501\u5b9a\u5df2\u88c5\u5907\u6b66\u5668"],
  "scripts/weapons/weapon_skill_binding.gd": ["\u6b66\u5668\u6280\u80fd\u7ed1\u5b9a", "\u5f00\u5c40\u65f6\u628a\u5df2\u88c5\u5907\u6b66\u5668\u7684\u4e3b\u653b\u51fb\u52a0\u5165\u73a9\u5bb6\u6280\u80fd\u5217\u8868"],
  "scripts/weapons/weapon_visual.gd": ["\u6b66\u5668\u89c6\u89c9", "\u6839\u636e\u5f53\u524d\u6b66\u5668\u6570\u636e\u663e\u793a\u73a9\u5bb6\u8eab\u4e0a\u7684\u6b66\u5668\u8d34\u56fe"],
};

const PHRASES = [
  ["defense_effectiveness", "\u9632\u5fa1\u5c5e\u6027\u62b5\u6263\u6bd4\u4f8b"],
  ["resistance_multiplier", "\u6297\u6027\u4f24\u5bb3\u500d\u7387"],
  ["status_damage_taken_multiplier", "\u72b6\u6001\u627f\u4f24\u500d\u7387"],
  ["damage_taken_multiplier", "\u627f\u4f24\u500d\u7387"],
  ["damage_packet", "\u4f24\u5bb3\u5305"],
  ["damage_result", "\u4f24\u5bb3\u7ed3\u7b97\u7ed3\u679c"],
  ["damage_type", "\u4f24\u5bb3\u7c7b\u578b"],
  ["damage_category", "\u4f24\u5bb3\u7c7b\u522b"],
  ["base_stat", "\u57fa\u7840\u5c5e\u6027"],
  ["runtime_modifier", "\u8fd0\u884c\u65f6\u5c5e\u6027\u4fee\u6b63"],
  ["status_snapshot", "\u72b6\u6001\u6548\u679c\u5feb\u7167"],
  ["selected_branch", "\u5f53\u524d\u6b66\u5668\u5206\u652f"],
  ["branch_level_config", "\u5206\u652f\u7b49\u7ea7\u914d\u7f6e"],
  ["upgrade_phase_weights", "\u5347\u7ea7\u9636\u6bb5\u6743\u91cd"],
  ["result_state", "\u7ed3\u7b97\u72b6\u6001\u6570\u636e"],
  ["run_hud_state", "\u5c40\u5185 HUD \u72b6\u6001\u6570\u636e"],
  ["map_background_path", "\u5730\u56fe\u80cc\u666f\u8d44\u6e90\u8def\u5f84"],
  ["enemy_armor", "\u654c\u4eba\u62a4\u7532\u503c"],
  ["current_branch_name", "\u5f53\u524d\u5206\u652f\u540d\u79f0"],
  ["main_attack_level", "\u4e3b\u653b\u51fb\u7b49\u7ea7"],
  ["branch_choice_stage_options", "Lv2 \u6b66\u5668\u5206\u652f\u9009\u9879"],
  ["growth_stage_options", "\u4e3b\u653b\u51fb\u6210\u957f\u9009\u9879"],
  ["level_up_upgrade_options", "\u666e\u901a\u5347\u7ea7\u9009\u9879"],
  ["branch_choice_options", "\u6b66\u5668\u5206\u652f\u5019\u9009\u9879"],
  ["missing_guarantee_tags", "\u7f3a\u5931\u7684\u4fdd\u5e95\u6807\u7b7e"],
  ["recommended_reason", "\u5347\u7ea7\u63a8\u8350\u7406\u7531"],
  ["combat_event", "\u6218\u6597\u4e8b\u4ef6"],
  ["skill_context", "\u6280\u80fd\u6267\u884c\u4e0a\u4e0b\u6587"],
  ["damage_payload", "\u4f24\u5bb3\u8f7d\u8377"],
  ["hit_event", "\u547d\u4e2d\u4e8b\u4ef6"],
  ["area_radius", "\u533a\u57df\u534a\u5f84"],
  ["visual_config", "\u89c6\u89c9\u914d\u7f6e"],
  ["boss_phase", "Boss \u9636\u6bb5"],
  ["boss_minion", "Boss \u53ec\u5524\u7269"],
  ["timeline_event", "\u65f6\u95f4\u7ebf\u4e8b\u4ef6"],
  ["enemy_group", "\u654c\u4eba\u5206\u7ec4"],
  ["spawn_position", "\u5237\u65b0\u4f4d\u7f6e"],
  ["alive_normal_enemy_count", "\u5b58\u6d3b\u666e\u901a\u654c\u4eba\u6570"],
  ["boss_core", "Boss \u8150\u5316\u6838\u5fc3"],
  ["permanent_upgrade", "\u6c38\u4e45\u5347\u7ea7"],
  ["character_specialization", "\u89d2\u8272\u4e13\u7cbe\u8fdb\u5ea6"],
  ["weapon_mastery", "\u6b66\u5668\u719f\u7ec3\u5ea6"],
  ["map_challenge", "\u5730\u56fe\u6311\u6218"],
  ["loadout", "\u89d2\u8272\u6b66\u5668\u642d\u914d"],
  ["run_scene", "\u5355\u5c40\u6218\u6597\u573a\u666f"],
  ["runtime_sources", "\u5c40\u5185\u8fd0\u884c\u4fe1\u53f7\u6e90"],
  ["string_name_array", "StringName \u6570\u7ec4"],
  ["orbit_object", "\u73af\u7ed5\u7269"],
  ["orbit_objects", "\u73af\u7ed5\u7269"],
  ["combat_object_definition", "\u6218\u6597\u7269\u4ef6\u5b9a\u4e49"],
  ["combat_object", "\u6218\u6597\u7269\u4ef6"],
  ["data_manager", "\u6570\u636e\u7ba1\u7406\u5668"],
  ["runtime_trigger", "\u8fd0\u884c\u65f6\u89e6\u53d1\u6761\u4ef6"],
  ["effect_bool", "\u6548\u679c\u5e03\u5c14\u503c"],
  ["status_definition", "\u72b6\u6001\u5b9a\u4e49"],
  ["json_document", "JSON \u6587\u6863"],
  ["range_overlay", "\u8303\u56f4\u53e0\u52a0\u663e\u793a"],
  ["pickup_radius", "\u62fe\u53d6\u534a\u5f84"],
  ["skill_ranges", "\u6280\u80fd\u8303\u56f4"],
  ["projectile_skill_range", "\u6295\u5c04\u6280\u80fd\u8303\u56f4"],
  ["area_skill_range", "\u533a\u57df\u6280\u80fd\u8303\u56f4"],
  ["orbit_skill_range", "\u73af\u7ed5\u6280\u80fd\u8303\u56f4"],
  ["enemy_damage_packet", "\u654c\u4eba\u4f24\u5bb3\u5305"],
  ["damage_source_id", "\u4f24\u5bb3\u6765\u6e90 ID"],
  ["ranged_attack_warning", "\u8fdc\u7a0b\u653b\u51fb\u9884\u8b66"],
  ["chase_behavior", "\u8ffd\u51fb\u884c\u4e3a"],
  ["ranged_behavior", "\u8fdc\u7a0b\u884c\u4e3a"],
  ["bomber_behavior", "\u7206\u5f39\u654c\u4eba\u884c\u4e3a"],
  ["dash_behavior", "\u51b2\u523a\u884c\u4e3a"],
];

const WORDS = {
  active: "\u5f53\u524d\u6fc0\u6d3b\u72b6\u6001",
  all: "\u5168\u90e8",
  amount: "\u6570\u91cf",
  and: "\u5e76",
  any: "\u4efb\u4e00",
  around: "\u5468\u56f4",
  array: "\u6570\u7ec4",
  attack: "\u653b\u51fb",
  autoplay: "\u81ea\u52a8\u6d41\u7a0b",
  available: "\u53ef\u7528\u9879",
  background: "\u80cc\u666f",
  boss: "Boss",
  body: "\u76ee\u6807",
  branch: "\u5206\u652f",
  bounds: "\u8fb9\u754c",
  button: "\u6309\u94ae",
  camera: "\u76f8\u673a",
  cap: "\u4e0a\u9650",
  card: "\u5361\u7247",
  character: "\u89d2\u8272",
  choice: "\u9009\u9879",
  children: "\u5b50\u8282\u70b9",
  collision: "\u78b0\u649e",
  color: "\u989c\u8272",
  config: "\u914d\u7f6e",
  control: "\u63a7\u5236",
  cooldown: "\u51b7\u5374",
  current: "\u5f53\u524d\u503c",
  damage: "\u4f24\u5bb3",
  damaged: "\u53d7\u4f24",
  data: "\u6570\u636e",
  death: "\u6b7b\u4ea1",
  debug: "\u8c03\u8bd5",
  default: "\u9ed8\u8ba4",
  dev: "\u5f00\u53d1",
  dictionary: "\u5b57\u5178",
  display: "\u663e\u793a\u6570\u636e",
  dot: "DOT",
  elapsed: "\u5df2\u8fd0\u884c\u65f6\u95f4",
  elite: "\u7cbe\u82f1",
  enemy: "\u654c\u4eba",
  enemies: "\u654c\u4eba",
  event: "\u4e8b\u4ef6",
  events: "\u4e8b\u4ef6",
  event: "\u4e8b\u4ef6",
  experience: "\u7ecf\u9a8c",
  equipped: "\u5df2\u88c5\u5907",
  allowed: "\u53ef\u7528",
  trait: "\u5929\u8d4b",
  temporary: "\u4e34\u65f6",
  first: "\u7b2c\u4e00\u4e2a",
  cast: "\u65bd\u653e",
  moved: "\u79fb\u52a8",
  stopped: "\u505c\u6b62",
  killed: "\u51fb\u6740",
  absorb: "\u62a4\u76fe\u5438\u6536",
  periodic: "\u5468\u671f",
  shield: "\u62a4\u76fe",
  moving: "\u79fb\u52a8",
  bonus: "\u52a0\u6210",
  sync: "\u540c\u6b65",
  params: "\u53c2\u6570",
  param: "\u53c2\u6570",
  tick: "tick",
  radius: "\u534a\u5f84",
  area: "\u533a\u57df",
  effect: "\u6548\u679c",
  definition: "\u5b9a\u4e49",
  manager: "\u7ba1\u7406\u5668",
  parent: "\u7236\u8282\u70b9",
  float: "\u6d6e\u70b9\u6570",
  property: "\u5c5e\u6027",
  mode: "\u6a21\u5f0f",
  allow: "\u5141\u8bb8",
  entered: "\u8fdb\u5165",
  pierce: "\u7a7f\u900f",
  counter: "\u8ba1\u6570",
  direction: "\u65b9\u5411",
  stack: "\u5c42\u6570",
  shock: "\u7535\u51fb",
  frozen: "\u51bb\u7ed3",
  move: "\u79fb\u52a8",
  speed: "\u901f\u5ea6",
  tier: "\u9636\u5c42",
  scaled: "\u7f29\u653e",
  rule: "\u89c4\u5219",
  rules: "\u89c4\u5219",
  applied: "\u5df2\u5e94\u7528",
  poison: "\u4e2d\u6bd2",
  slow: "\u51cf\u901f",
  synergy: "\u534f\u540c",
  flow: "\u6d41\u7a0b",
  force: "\u5f3a\u5236",
  group: "\u5206\u7ec4",
  hide: "\u9690\u85cf",
  hit: "\u547d\u4e2d",
  hud: "HUD",
  id: "ID",
  input: "\u8f93\u5165",
  initial: "\u521d\u59cb",
  int: "\u6574\u6570",
  json: "JSON",
  label: "\u6587\u672c\u6807\u7b7e",
  level: "\u7b49\u7ea7",
  line: "\u7ebf\u6761",
  list: "\u5217\u8868",
  limits: "\u9650\u5236",
  map: "\u5730\u56fe",
  manual: "\u624b\u52a8",
  menu: "\u83dc\u5355",
  modal: "\u5f39\u7a97",
  modifier: "\u4fee\u6b63",
  modifiers: "\u4fee\u6b63",
  movement: "\u79fb\u52a8",
  node: "\u8282\u70b9",
  nonce: "\u8c03\u8bd5\u653b\u51fb\u6279\u6b21",
  object: "\u7269\u4ef6",
  objects: "\u7269\u4ef6",
  option: "\u9009\u9879",
  options: "\u9009\u9879",
  orbit: "\u73af\u7ed5",
  over: "\u7ed3\u675f",
  overlapping: "\u91cd\u53e0",
  player: "\u73a9\u5bb6",
  pool: "\u6c60",
  position: "\u4f4d\u7f6e",
  pressure: "\u538b\u529b",
  range: "\u8303\u56f4",
  ranges: "\u8303\u56f4",
  ring: "\u73af\u5f62",
  projectile: "\u6295\u5c04\u7269",
  projectiles: "\u6295\u5c04\u7269",
  reward: "\u5956\u52b1",
  run: "\u5355\u5c40",
  scene: "\u573a\u666f",
  screen: "\u754c\u9762",
  skill: "\u6280\u80fd",
  skills: "\u6280\u80fd",
  spawn: "\u751f\u6210",
  state: "\u72b6\u6001",
  stat: "\u5c5e\u6027",
  stats: "\u7edf\u8ba1",
  string: "\u5b57\u7b26\u4e32",
  stringname: "StringName",
  status: "\u72b6\u6001\u6548\u679c",
  statuses: "\u72b6\u6001\u6548\u679c",
  started: "\u5df2\u5f00\u59cb",
  survival: "\u751f\u5b58",
  summary: "\u6458\u8981",
  tag: "\u6807\u7b7e",
  target: "\u76ee\u6807",
  texture: "\u8d34\u56fe",
  text: "\u6587\u672c",
  time: "\u65f6\u95f4",
  timeout: "\u8d85\u65f6",
  upgrade: "\u5347\u7ea7",
  upgrades: "\u5347\u7ea7",
  value: "\u503c",
  visual: "\u89c6\u89c9\u914d\u7f6e",
  visible: "\u53ef\u89c1",
  warning: "\u9884\u8b66",
  wave: "\u6ce2\u6b21",
  weapon: "\u6b66\u5668",
  weights: "\u6743\u91cd",
};

function walk(dir) {
  const result = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      result.push(...walk(fullPath));
    } else if (entry.isFile() && entry.name.endsWith(".gd")) {
      result.push(fullPath);
    }
  }
  return result.sort();
}

function rel(filePath) {
  return path.relative(root, filePath).replaceAll(path.sep, "/");
}

function splitArguments(args) {
  const result = [];
  let current = "";
  let depth = 0;
  let quote = "";
  for (const char of args) {
    if (quote !== "") {
      current += char;
      if (char === quote) quote = "";
      continue;
    }
    if (char === "\"" || char === "'") {
      quote = char;
      current += char;
      continue;
    }
    if ("([{".includes(char)) depth += 1;
    if (")]}".includes(char)) depth = Math.max(depth - 1, 0);
    if (char === "," && depth === 0) {
      result.push(current.trim());
      current = "";
    } else {
      current += char;
    }
  }
  if (current.trim() !== "") result.push(current.trim());
  return result;
}

function parseParams(signature) {
  const args = signature.match(/\((.*)\)/)?.[1]?.trim() ?? "";
  if (args === "") return C.noParams;
  return splitArguments(args)
    .map((arg) => {
      const [namePart, typePart] = arg.split(":").map((part) => part.trim());
      const name = namePart.replace(/^_+/, "_");
      const type = typePart ? typePart.split("=").shift().trim() : "Variant";
      return `\`${name}\`: ${type}`;
    })
    .join("\uff1b");
}

function parseReturn(signature) {
  const match = signature.match(/->\s*([A-Za-z0-9_\[\]]+)/);
  if (!match) return C.defaultReturn;
  if (match[1] === "void") return C.noReturn;
  return `${C.returnType} \`${match[1]}\`\u3002`;
}

function extractLeadingDescription(lines, functionIndex) {
  const comments = [];
  for (let index = functionIndex - 1; index >= 0; index -= 1) {
    const trimmed = lines[index].trim();
    if (trimmed === "") {
      if (comments.length === 0) continue;
      break;
    }
    if (!trimmed.startsWith("##") && !trimmed.startsWith("#")) break;
    comments.unshift(trimmed.replace(/^#+\s?/, "").trim());
  }
  const description = [];
  for (const comment of comments) {
    if (/^(Params|Returns)\s*:?$/i.test(comment)) break;
    if (comment.startsWith("- ")) continue;
    if (comment !== "") description.push(comment);
  }
  return description.join(" ");
}

function leadingIndent(line) {
  return line.match(/^\s*/)?.[0]?.length ?? 0;
}

function extractBody(lines, functionLineIndex, afterSignatureIndex) {
  const body = [];
  const baseIndent = leadingIndent(lines[functionLineIndex]);
  for (let index = afterSignatureIndex; index < lines.length; index += 1) {
    const line = lines[index];
    if (/^\s*(?:static\s+)?func\s+[A-Za-z0-9_]+\s*\(/.test(line) && leadingIndent(line) <= baseIndent) break;
    body.push(line);
  }
  return body;
}

function unique(values) {
  return [...new Set(values.filter(Boolean))];
}

function formatList(values, limit = 8) {
  const clipped = values.slice(0, limit).map((value) => `\`${value}\``);
  if (values.length > limit) clipped.push(`${C.etc} ${values.length} ${C.items}`);
  return clipped.join("\u3001");
}

function extractSourceFacts(bodyLines) {
  const text = bodyLines.join("\n");
  const ignoredCalls = new Set([
    "Array", "Callable", "Color", "Dictionary", "NodePath", "String", "StringName", "Vector2",
    "absf", "bool", "clampf", "float", "for", "if", "int", "is_instance_valid", "maxf", "maxi",
    "minf", "mini", "not", "preload", "range", "return", "roundi", "str", "var", "while",
  ]);
  const calls = [];
  for (const match of text.matchAll(/(?:^|[^\w.])([A-Za-z_][A-Za-z0-9_]*)\s*\(/g)) {
    const name = match[1];
    if (!ignoredCalls.has(name)) calls.push(name);
  }
  for (const match of text.matchAll(/\.call\(\s*["&]?["']([A-Za-z0-9_]+)["']/g)) {
    calls.push(match[1]);
  }
  const writes = [];
  for (const line of bodyLines) {
    const trimmed = line.trim();
    const match = trimmed.match(/^(?:var\s+)?([A-Za-z_][A-Za-z0-9_\.]*)\s*(?:\+|-|\*|\/)?=/);
    if (match && !match[1].includes(".")) writes.push(match[1]);
  }
  const emits = [];
  for (const match of text.matchAll(/([A-Za-z_][A-Za-z0-9_]*)\.emit\s*\(/g)) {
    emits.push(match[1]);
  }
  const returns = [];
  for (const line of bodyLines) {
    const trimmed = line.trim();
    if (trimmed.startsWith("return ")) returns.push(trimmed.replace(/^return\s+/, "").replace(/\s+/g, " "));
  }
  return { calls: unique(calls), writes: unique(writes), emits: unique(emits), returns: unique(returns) };
}

function domainFor(filePath) {
  const relative = rel(filePath);
  return DOMAINS.find(([prefix]) => relative.startsWith(prefix))?.[1] ?? "\u9879\u76ee";
}

function contextFor(filePath) {
  const relative = rel(filePath);
  const context = FILE_CONTEXTS[relative];
  if (context) return { subject: context[0], purpose: context[1] };
  const subject = fileLabel(filePath) || domainFor(filePath);
  return { subject, purpose: `\u652f\u6491${domainFor(filePath)}\u6a21\u5757\u7684\u5c40\u5185\u6216 UI \u6d41\u7a0b` };
}

function objectLabelFromName(name) {
  const cleanName = name.replace(/^_+/, "");
  const phrase = [...PHRASES].sort((a, b) => b[0].length - a[0].length).find(([token]) => cleanName.includes(token));
  if (phrase) return phrase[1];
  const verbs = new Set(["get", "set", "is", "has", "can", "apply", "update", "build", "create", "load", "save", "clear", "reset", "handle", "on", "find", "resolve", "parse", "record", "show", "hide", "ensure", "calculate", "make", "add", "remove", "try", "emit", "process", "start", "finish", "select", "pick", "format", "count", "toggle", "print", "draw", "execute", "spawn", "damage", "consume", "award", "notify", "refresh", "setup", "run", "check", "equip", "for", "sync", "play", "choose", "release", "index", "generate", "auto", "force", "manual", "open", "close", "cancel", "switch", "drive", "log"]);
  const words = cleanName
    .split("_")
    .filter((word) => word && !verbs.has(word))
    .map((word) => translateIdentifierWord(word));
  return words.length > 0 ? words.join("") : `\`${cleanName}\``;
}

function translateIdentifierWord(word) {
  const lower = word.toLowerCase();
  if (WORDS[lower]) return WORDS[lower];
  if (lower.endsWith("ies") && WORDS[`${lower.slice(0, -3)}y`]) return WORDS[`${lower.slice(0, -3)}y`];
  if (lower.endsWith("s") && WORDS[lower.slice(0, -1)]) return WORDS[lower.slice(0, -1)];
  return lower;
}

function fileLabel(filePath) {
  const baseName = path.basename(filePath, ".gd");
  const words = baseName.split("_").filter(Boolean).map((word) => WORDS[word] ?? word);
  return words.join("");
}

function semanticDescription(name, filePath, facts) {
  const key = `${rel(filePath)}::${name}`;
  if (EXACT_DESCRIPTIONS[key]) return EXACT_DESCRIPTIONS[key];

  const cleanName = name.replace(/^_+/, "");
  const target = objectLabelFromName(name);
  const domain = domainFor(filePath);
  const fileTarget = fileLabel(filePath);
  const context = contextFor(filePath);

  if (name === "_init") return `\u521d\u59cb\u5316${context.subject}\u7684\u5b9e\u4f8b\u6570\u636e\uff0c\u7528\u4e8e${context.purpose}\u3002`;
  if (name === "_ready") return `\u8282\u70b9\u8fdb\u5165\u573a\u666f\u6811\u65f6\u51c6\u5907${context.subject}\uff0c\u7528\u4e8e${context.purpose}\u3002`;
  if (name === "_process") return `\u6309\u5e27\u63a8\u8fdb${context.subject}\u7684\u8fd0\u884c\u72b6\u6001\u3002`;
  if (name === "_physics_process") return `\u6309\u7269\u7406\u5e27\u63a8\u8fdb${context.subject}\u7684\u79fb\u52a8\u3001\u78b0\u649e\u6216\u6218\u6597\u5224\u5b9a\u3002`;
  if (name === "_input" || name === "_unhandled_input") return `\u5904\u7406${context.subject}\u7684\u73a9\u5bb6\u8f93\u5165\u4e8b\u4ef6\u3002`;
  if (cleanName === "initialize") return `\u521d\u59cb\u5316${context.subject}\u7684\u8fd0\u884c\u6570\u636e\u3002`;
  if (cleanName === "setup") return `\u6ce8\u5165${context.subject}\u6240\u9700\u4f9d\u8d56\u548c\u521d\u59cb\u4e0a\u4e0b\u6587\u3002`;
  if (cleanName === "refresh") return `\u5237\u65b0${context.subject}\u7684\u5f53\u524d\u6570\u636e\u548c\u663e\u793a\u72b6\u6001\u3002`;
  if (cleanName === "run_tests") return `\u8fd0\u884c${context.subject}\u7684\u81ea\u6d4b\u7528\u4f8b\u3002`;
  if (cleanName === "calculate") return `${C.calculate}${context.subject}\u9700\u8981\u7684\u6570\u503c\u7ed3\u679c\u3002`;
  if (cleanName === "close_modal") return `\u5173\u95ed${domain}\u5f39\u7a97\u5e76\u6062\u590d\u76f8\u5173\u72b6\u6001\u3002`;
  if (cleanName === "open_modal") return `\u6253\u5f00${domain}\u5f39\u7a97\u5e76\u51c6\u5907\u663e\u793a\u6570\u636e\u3002`;
  if (cleanName === "build") return `\u6784\u5efa${context.subject}\u7684 UI \u6216\u8fd0\u884c\u6570\u636e\u7ed3\u6784\u3002`;

  if (["get_dictionary", "dictionary", "parse_dictionary"].includes(cleanName)) return `\u5c06\u4f20\u5165 Variant \u5b89\u5168\u8f6c\u4e3a Dictionary\uff0c\u907f\u514d\u914d\u7f6e\u5b57\u6bb5\u7c7b\u578b\u4e0d\u5339\u914d\u5f71\u54cd${context.subject}\u3002`;
  if (["get_array", "array", "parse_array"].includes(cleanName)) return `\u5c06\u4f20\u5165 Variant \u5b89\u5168\u8f6c\u4e3a Array\uff0c\u7528\u4e8e\u8bfb\u53d6${context.subject}\u7684\u914d\u7f6e\u5217\u8868\u3002`;
  if (["get_string_array", "to_string_array", "parse_string_array"].includes(cleanName)) return `\u5c06\u914d\u7f6e\u5217\u8868\u7edf\u4e00\u8f6c\u4e3a\u5b57\u7b26\u4e32\u6570\u7ec4\u3002`;
  if (cleanName.includes("vector2")) return `\u5c06\u914d\u7f6e\u503c\u8f6c\u4e3a Vector2\uff0c\u7528\u4e8e${context.subject}\u7684\u5750\u6807\u3001\u504f\u79fb\u6216\u7f29\u653e\u3002`;
  if (cleanName.includes("color")) return `\u89e3\u6790${context.subject}\u9700\u8981\u7684\u989c\u8272\u914d\u7f6e\u3002`;
  if (cleanName.includes("texture")) return `\u8bfb\u53d6\u6216\u5e94\u7528${context.subject}\u9700\u8981\u7684\u8d34\u56fe\u8d44\u6e90\u3002`;

  if (cleanName.startsWith("get_")) return `${C.get}${target}\u3002`;
  if (cleanName.startsWith("is_") || cleanName.startsWith("has_") || cleanName.startsWith("can_")) return `${C.judge}${target}${C.condition}${domain}${C.logicCondition}\u3002`;
  if (cleanName.startsWith("set_")) return `${C.set}${target}\u3002`;
  if (cleanName.startsWith("apply_")) return `${C.apply}${target}${C.currentFlow}\u3002`;
  if (cleanName.startsWith("update_")) return `${C.update}${target}\u3002`;
  if (cleanName.startsWith("build_") || cleanName === "build") return `${C.build}${target}${C.dataOrNode}\u3002`;
  if (cleanName.startsWith("create_") || cleanName.startsWith("make_")) return `${C.create}${target}\u3002`;
  if (cleanName.startsWith("load_")) return `${C.load}${target}\u3002`;
  if (cleanName.startsWith("save_")) return `${C.save}${target}\u3002`;
  if (cleanName.startsWith("clear_")) return `${C.clear}${target}\u3002`;
  if (cleanName.startsWith("reset_")) return `${C.reset}${target}\u3002`;
  if (cleanName.startsWith("record_")) return `${C.record}${target}\u3002`;
  if (cleanName.startsWith("resolve_") || cleanName.startsWith("parse_")) return `${C.resolve}${target}\u3002`;
  if (cleanName.startsWith("calculate_")) return `${C.calculate}${target}\u3002`;
  if (cleanName.startsWith("find_")) return `${C.find}${target}\u3002`;
  if (cleanName.startsWith("show_")) return `${C.show}${target}\u3002`;
  if (cleanName.startsWith("hide_")) return `${C.hide}${target}\u3002`;
  if (cleanName.startsWith("handle_") || cleanName.startsWith("on_")) return `${C.handle}${target}${C.event}\u3002`;
  if (cleanName.startsWith("ensure_")) return `${C.ensure}${target}${C.condition}${domain}${C.logicCondition}\u3002`;
  if (cleanName.startsWith("run_")) return `\u6267\u884c${target}\u6d41\u7a0b\u3002`;
  if (cleanName.startsWith("check_")) return `\u68c0\u67e5${target}\u662f\u5426\u7b26\u5408\u9884\u671f\u3002`;
  if (cleanName.startsWith("select_")) return `\u9009\u62e9${target}\u5e76\u66f4\u65b0\u76f8\u5173\u72b6\u6001\u3002`;
  if (cleanName.startsWith("switch_")) return `\u5207\u6362${target}\u3002`;
  if (cleanName.startsWith("drive_")) return `\u9a71\u52a8${target}\u7684\u81ea\u52a8\u5316\u6d41\u7a0b\u3002`;
  if (cleanName.startsWith("log_")) return `\u8bb0\u5f55${target}\u8c03\u8bd5\u65e5\u5fd7\u3002`;
  if (cleanName.startsWith("add_")) return `\u5411${context.subject}\u589e\u52a0${target}\u3002`;
  if (cleanName.startsWith("remove_")) return `\u4ece${context.subject}\u79fb\u9664${target}\u3002`;
  if (cleanName.startsWith("mark_")) return `\u6807\u8bb0${target}\u5e76\u540c\u6b65\u76f8\u5173\u8fd0\u884c\u6216\u5b58\u6863\u72b6\u6001\u3002`;
  if (cleanName.startsWith("increment_")) return `\u7d2f\u52a0${target}\u8fdb\u5ea6\u5e76\u8fd4\u56de\u65b0\u503c\u3002`;
  if (cleanName.startsWith("spend_")) return `\u5c1d\u8bd5\u6d88\u8017${target}\uff0c\u6d88\u8017\u6210\u529f\u540e\u540c\u6b65\u5b58\u6863\u3002`;
  if (cleanName.startsWith("purchase_")) return `\u8d2d\u4e70${target}\u5e76\u5199\u5165\u5b58\u6863\u6216\u5f53\u524d UI \u72b6\u6001\u3002`;
  if (cleanName.startsWith("bind_")) return `\u7ed1\u5b9a${target}\u5230\u5f53\u524d\u73a9\u5bb6\u6216\u8fd0\u884c\u5bf9\u8c61\u3002`;
  if (cleanName.startsWith("subscribe")) return `\u8ba2\u9605${context.subject}\u4e2d\u7684\u4e8b\u4ef6\u56de\u8c03\u3002`;
  if (cleanName.startsWith("level_up")) return `\u63d0\u5347${context.subject}\u7684\u7b49\u7ea7\u5e76\u66f4\u65b0\u6210\u957f\u72b6\u6001\u3002`;
  if (cleanName.startsWith("queue_")) return `\u5c06${target}\u52a0\u5165${context.subject}\u7684\u5f85\u5904\u7406\u961f\u5217\u3002`;
  if (cleanName.startsWith("emit_")) return `\u5411\u5916\u53d1\u51fa${target}\u4fe1\u53f7\u6216\u4e8b\u4ef6\u3002`;
  if (cleanName.startsWith("process_")) return `\u63a8\u8fdb${target}\u7684\u8fd0\u884c\u903b\u8f91\u3002`;
  if (cleanName.startsWith("start_")) return `\u542f\u52a8${target}\u6d41\u7a0b\u3002`;
  if (cleanName.startsWith("finish_")) return `\u6536\u5c3e${target}\u6d41\u7a0b\u5e76\u66f4\u65b0\u72b6\u6001\u3002`;
  if (cleanName.startsWith("pick_")) return `\u4ece\u5019\u9009\u6570\u636e\u4e2d\u9009\u51fa${target}\u3002`;
  if (cleanName.startsWith("format_")) return `\u628a${target}\u683c\u5f0f\u5316\u4e3a UI \u6216\u8c03\u8bd5\u6587\u672c\u3002`;
  if (cleanName.startsWith("count_")) return `\u7edf\u8ba1${target}\u6570\u91cf\u3002`;
  if (cleanName.startsWith("toggle_")) return `\u5207\u6362${target}\u7684\u5f00\u5173\u72b6\u6001\u3002`;
  if (cleanName.startsWith("print_")) return `\u8f93\u51fa${target}\u7684\u8c03\u8bd5\u4fe1\u606f\u3002`;
  if (cleanName.startsWith("draw_")) return `\u5728\u8c03\u8bd5\u753b\u5e03\u4e0a\u7ed8\u5236${target}\u3002`;
  if (cleanName.startsWith("execute_")) return `\u6267\u884c${target}\u7684\u914d\u7f6e\u5316\u52a8\u4f5c\u3002`;
  if (cleanName.startsWith("spawn_")) return `\u5728\u5c40\u5185\u751f\u6210${target}\u3002`;
  if (cleanName.startsWith("damage_") || cleanName.startsWith("try_damage_")) return `\u5bf9${target}\u8fdb\u884c\u4f24\u5bb3\u5224\u5b9a\u548c\u7ed3\u7b97\u3002`;
  if (cleanName.startsWith("consume_")) return `\u6d88\u8017${target}\u5e76\u66f4\u65b0\u76f8\u5173\u72b6\u6001\u3002`;
  if (cleanName.startsWith("award_")) return `\u7ed9\u4e88${target}\u5956\u52b1\u6216\u7ed3\u7b97\u8d44\u6e90\u3002`;
  if (cleanName.startsWith("notify_")) return `\u901a\u77e5\u5176\u4ed6\u7cfb\u7edf${target}\u5df2\u53d1\u751f\u3002`;
  if (cleanName.startsWith("collect_")) return `\u6536\u96c6${target}\u5e76\u540c\u6b65\u5230\u73a9\u5bb6\u6216\u5355\u5c40\u7edf\u8ba1\u3002`;
  if (cleanName.startsWith("shoot_")) return `\u6309\u76ee\u6807\u65b9\u5411\u53d1\u5c04${target}\u3002`;
  if (cleanName.startsWith("explode")) return `\u89e6\u53d1${context.subject}\u7684\u7206\u70b8\u4f24\u5bb3\u6216\u6b7b\u4ea1\u6548\u679c\u3002`;
  if (cleanName.startsWith("expect") || cleanName.startsWith("assert")) return `\u65ad\u8a00${context.subject}\u68c0\u67e5\u9879\u7b26\u5408\u9884\u671f\u3002`;
  if (cleanName.startsWith("fail")) return `\u6807\u8bb0${context.subject}\u81ea\u6d4b\u5931\u8d25\u5e76\u8f93\u51fa\u9519\u8bef\u3002`;
  if (facts.emits.length > 0 && facts.calls.length === 0 && facts.writes.length === 0) return `${C.emits}${formatList(facts.emits)} ${C.signal}\u3002`;
  if (facts.returns.length > 0 && facts.calls.length === 0 && facts.writes.length === 0) return `${C.readReturn}${target}\u3002`;
  return "";
}

function describeFromSourceFacts(bodyLines, name, filePath) {
  const facts = extractSourceFacts(bodyLines);
  const context = contextFor(filePath);
  const target = objectLabelFromName(name);
  if (facts.returns.length > 0 && facts.calls.length === 0 && facts.writes.length === 0) return `${C.readReturn}${target}\u3002`;
  if (bodyLines.every((line) => line.trim() === "" || line.trim().startsWith("#"))) return `\u4fdd\u7559${context.subject}\u7684${target}\u6269\u5c55\u5165\u53e3\uff0c\u5f53\u524d\u6ca1\u6709\u989d\u5916\u8fd0\u884c\u903b\u8f91\u3002`;
  return `\u5728${context.subject}\u4e2d\u5b8c\u6210${target}\uff0c\u7528\u4e8e${context.purpose}\u3002`;
}

function extractFunctions(filePath) {
  const text = fs.readFileSync(filePath, "utf8");
  const lines = text.split(/\r?\n/);
  const functions = [];
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const match = line.match(/^\s*(?:static\s+)?func\s+([A-Za-z0-9_]+)\s*\((.*)$/);
    if (!match) continue;
    let signature = line.trim();
    let scan = index + 1;
    while (!signature.includes(")") && scan < lines.length) {
      signature += ` ${lines[scan].trim()}`;
      scan += 1;
    }
    const bodyLines = extractBody(lines, index, scan);
    const documentedDescription = extractLeadingDescription(lines, index);
    const facts = extractSourceFacts(bodyLines);
    const contextDescription = semanticDescription(match[1], filePath, facts);
    functions.push({
      name: match[1],
      line: index + 1,
      signature,
      description: documentedDescription || contextDescription || describeFromSourceFacts(bodyLines, match[1], filePath),
      params: parseParams(signature),
      returns: parseReturn(signature),
    });
  }
  return functions;
}

function main() {
  const sections = [
    `# ${C.title}`,
    "",
    C.intro,
    "",
    "```powershell",
    "node tools\\generate_function_reference.js",
    "```",
    "",
  ];
  for (const filePath of walk(scriptsDir)) {
    const functions = extractFunctions(filePath);
    if (functions.length === 0) continue;
    sections.push(`## ${rel(filePath)}`, "");
    for (const fn of functions) {
      sections.push(`### ${fn.name}`);
      sections.push(`- ${C.location}\uff1a\`${rel(filePath)}:${fn.line}\``);
      sections.push(`- ${C.signature}\uff1a\`${fn.signature}\``);
      sections.push(`- ${C.function}\uff1a${fn.description}`);
      sections.push(`- ${C.params}\uff1a${fn.params}`);
      sections.push(`- ${C.returns}\uff1a${fn.returns}`);
      sections.push("");
    }
  }
  fs.writeFileSync(outputPath, sections.join("\n"), "utf8");
  console.log(`Generated ${rel(outputPath)}`);
}

main();
