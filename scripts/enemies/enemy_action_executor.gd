## 文件用途：为敌人提供投射物、伤害区域、爆炸和召唤的实际执行入口。
## 使用方式：setup 绑定敌人聚合根；动作 registry 与死亡特效通过公开接口请求执行。

extends RefCounted
class_name EnemyActionExecutor


const EnemySpawnRequestScript: Script = preload("res://scripts/enemies/spawning/enemy_spawn_request.gd")
const EnemySpawnServiceScript: Script = preload("res://scripts/enemies/spawning/enemy_spawn_service.gd")
const EnemyDamagePacketBuilderScript: Script = preload("res://scripts/enemies/combat/enemy_damage_packet_builder.gd")
const CombatObjectFactoryScript: Script = preload("res://scripts/combat/combat_object_factory.gd")

var _owner: Node2D
var _spawn_service: RefCounted = EnemySpawnServiceScript.new()


## 作用：绑定本服务运行所需的所属节点与配置依赖。
## 使用：创建对象后先调用本入口，再调用执行/更新接口；参数应来自当前运行场景。
func setup(owner: Node2D) -> void:
	_owner = owner
	_sync_spawn_service()


## 作用：在敌人位置生成零伤害短时爆炸效果，并对范围内目标立即结算爆炸伤害。
## 使用：behavior 提供 explosion_damage/radius；返回是否存在有效 owner，本函数不执行敌人死亡。
func explode(behavior: Dictionary) -> bool:
	if _owner == null:
		return false

	var explosion_damage: int = int(behavior.get("explosion_damage", _get_int("contact_damage")))
	var explosion_radius: float = float(behavior.get("explosion_radius", 76.0))
	spawn_damage_area(0, 0.12, 0.1, explosion_radius, Color(1.0, 0.35, 0.08, 0.45))
	damage_targets_in_radius(explosion_damage, explosion_radius)
	return true


## 作用：按死亡效果类型生成毒池或死亡分裂小怪。
## 使用：death_effect 来自敌人配置；支持 poison_pool/spawn_enemies，其他类型不处理。
func apply_death_effect(death_effect: Dictionary) -> void:
	match String(death_effect.get("type", "")):
		"poison_pool":
			spawn_damage_area(
				int(death_effect.get("damage", 8)),
				float(death_effect.get("duration", 3.0)),
				float(death_effect.get("tick_interval", 1.0)),
				float(death_effect.get("area_radius", 52.0)),
				Color(0.35, 0.95, 0.2, 0.32)
			)
		"spawn_enemies":
			spawn_death_enemies(
				StringName(String(death_effect.get("enemy_id", "small_slime"))),
				int(death_effect.get("count", 1))
			)


## 作用：从对象池取得敌方投射物并设置弹道、来源和严格伤害包。
## 使用：direction 为世界方向，伤害/速度/穿透/半径为实际值，behavior 提供寿命和外观；缺少生成依赖则跳过。
func spawn_enemy_projectile(
	direction: Vector2,
	projectile_damage: int,
	projectile_speed: float,
	projectile_pierce: int = 0,
	projectile_radius: float = 8.0,
	behavior: Dictionary = {}
) -> void:
	if _owner == null or _owner.get("enemy_projectile_scene") == null or _owner.get_parent() == null:
		return

	var projectile_scene: PackedScene = _owner.get("enemy_projectile_scene") as PackedScene
	var projectile: Node2D = CombatObjectFactoryScript._spawn_pooled_combat_node(projectile_scene, _owner.get_parent(), &"enemy_projectile") as Node2D
	if projectile == null:
		return

	var normalized_direction: Vector2 = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	projectile.add_to_group(&"enemy_projectiles")
	projectile.add_to_group(&"enemy_projectile")
	projectile.global_position = _owner.global_position + normalized_direction * float(behavior.get("projectile_spawn_offset", 20.0))
	var setup_params: Dictionary = {
			"direction": normalized_direction,
			"damage": projectile_damage,
			"speed": projectile_speed,
			"target_group": _owner.get("target_group"),
			"pierce": projectile_pierce,
			"radius": projectile_radius,
			"lifetime": float(behavior.get("projectile_lifetime", 3.0)),
			"source_id": _get_damage_source_id(),
			"damage_packet": EnemyDamagePacketBuilderScript.build(_owner, projectile_damage, "projectile", &"enemy_projectile", behavior),
			"visual_color": behavior.get("projectile_color", [1.0, 0.9, 0.08, 1.0]),
			"visual": _get_dictionary(behavior.get("projectile_visual", {}))
		}
	if projectile.has_method("prepare_for_pool_spawn"):
		projectile.call(&"prepare_for_pool_spawn", setup_params)
	elif projectile.has_method("setup"):
		projectile.call(&"setup", setup_params)


## 作用：在 owner 当前位置创建伤害区域。
## 使用：伤害量为实际值，duration/tick_interval 为秒，radius 为世界距离；委托 spawn_damage_area_at。
func spawn_damage_area(
	area_damage: int,
	area_duration: float,
	area_tick_interval: float,
	area_radius: float,
	visual_color: Color
) -> void:
	if _owner != null:
		spawn_damage_area_at(_owner.global_position, area_damage, area_duration, area_tick_interval, area_radius, visual_color)


## 作用：在指定世界位置创建携带敌方区域伤害包的池化区域。
## 使用：area_position 为世界坐标，其余参数给出伤害、生命周期、周期、半径和颜色；缺少依赖则跳过。
func spawn_damage_area_at(
	area_position: Vector2,
	area_damage: int,
	area_duration: float,
	area_tick_interval: float,
	area_radius: float,
	visual_color: Color
) -> void:
	if _owner == null or _owner.get("damage_area_scene") == null or _owner.get_parent() == null:
		return

	var damage_area_scene: PackedScene = _owner.get("damage_area_scene") as PackedScene
	var damage_area: Node2D = CombatObjectFactoryScript._spawn_pooled_combat_node(damage_area_scene, _owner.get_parent(), &"enemy_area") as Node2D
	if damage_area == null:
		return

	damage_area.global_position = area_position
	var setup_params: Dictionary = {
			"damage": area_damage,
			"duration": area_duration,
			"tick_interval": area_tick_interval,
			"target_group": _owner.get("target_group"),
			"area_radius": area_radius,
			"visual_color": visual_color,
			"source_id": StringName(_get_damage_source_id()),
			"source_type": &"area",
			"damage_packet": _build_enemy_damage_packet(area_damage, "area", "enemy_area")
		}
	if damage_area.has_method("prepare_for_pool_spawn"):
		damage_area.call(&"prepare_for_pool_spawn", setup_params)
	elif damage_area.has_method("setup"):
		damage_area.call(&"setup", setup_params)


## 作用：筛选目标组中处于敌人半径内的节点，并分别提交物理区域伤害包。
## 使用：area_damage 必须为正，area_radius 为世界距离；只调用具有 take_damage 的 Node2D。
func damage_targets_in_radius(area_damage: int, area_radius: float) -> void:
	if _owner == null or area_damage <= 0:
		return

	var radius_squared: float = area_radius * area_radius
	for target_node: Node in _owner.get_tree().get_nodes_in_group(_owner.get("target_group")):
		var target_body: Node2D = target_node as Node2D
		if target_body == null:
			continue
		if _owner.global_position.distance_squared_to(target_body.global_position) > radius_squared:
			continue
		if target_body.has_method("take_damage"):
			target_body.call(&"take_damage", EnemyDamagePacketBuilderScript.build(_owner, area_damage, "area", &"enemy_area", {
				"target": target_body,
				"damage_origin": "field",
				"damage_type": "area_direct",
				"element": "physical"
			}))


## 作用：在敌人死亡位置周围生成指定数量的分裂小怪。
## 使用：spawn_enemy_id 为配置 ID；使用 28 像素圆周半径，统一经 spawn_enemies_around。
func spawn_death_enemies(spawn_enemy_id: StringName, count: int) -> void:
	if _owner != null:
		spawn_enemies_around(spawn_enemy_id, count, _owner.global_position, 28.0)


## 作用：沿中心圆周均匀创建召唤敌人，并继承 owner 的血量、伤害和速度倍率。
## 使用：center 为世界坐标，radius 为世界距离；经验倍率固定 0.25，生成经 EnemySpawnService。
func spawn_enemies_around(spawn_enemy_id: StringName, count: int, center: Vector2, radius: float = 48.0) -> void:
	if _owner == null or spawn_enemy_id == &"" or count <= 0 or _owner.get_parent() == null:
		return

	_sync_spawn_service()
	for spawn_index in range(count):
		var position: Vector2 = center + Vector2.RIGHT.rotated(TAU * float(spawn_index) / float(count)) * radius
		var request: Dictionary = EnemySpawnRequestScript.summon(spawn_enemy_id, position, {
			"hp": float(_owner.get("health_multiplier")),
			"damage": float(_owner.get("damage_multiplier")),
			"move_speed": float(_owner.get("move_speed_multiplier")) if _owner.get("move_speed_multiplier") != null else 1.0,
			"exp": 0.25
		}, String(_owner.get("enemy_id")))
		request["parent"] = _owner.get_parent()
		_spawn_service.call("spawn", request)


## 作用：以 skeleton 场景沿 150 像素圆周生成指定血量的 Boss 核心并记录统计。
## 使用：count 必须为正，核心继承 owner 的护甲和抗性；返回已处理请求，不保证每个核心都生成成功。
func spawn_corrupted_cores(count: int, hp: int) -> bool:
	if _owner == null or count <= 0 or _owner.get_parent() == null:
		return false
	_sync_spawn_service()
	for spawn_index in range(count):
		var owner_resistances: Variant = _owner.get("resistances")
		var resistances: Dictionary = (owner_resistances as Dictionary).duplicate(true) if owner_resistances is Dictionary else {}
		var position: Vector2 = _owner.global_position + Vector2.RIGHT.rotated(TAU * float(spawn_index) / float(count)) * 150.0
		var request: Dictionary = EnemySpawnRequestScript.boss_core(&"skeleton", position, hp, int(_owner.get("armor")), resistances)
		request["parent"] = _owner.get_parent()
		var core: Node2D = _spawn_service.call("spawn", request) as Node2D
		if core == null:
			continue
		var tracker: Node = RunStatsTracker.get_active(_owner.get_tree()) if _owner.get_tree() != null else null
		if tracker != null and tracker.has_method("record_boss_core_spawned"):
			tracker.call("record_boss_core_spawned", core)
	return true


## 作用：获取整数，供当前模块后续逻辑使用。
## 使用：本文件由 explode 调用；输入 property（属性）；返回计算或读取的数值。
func _get_int(property: StringName) -> int:
	if _owner == null:
		return 0
	return int(_owner.get(property))


## 作用：获取伤害来源ID，供当前模块后续逻辑使用。
## 使用：本文件由 spawn_enemy_projectile、spawn_damage_area_at 调用；返回 String 文本/标识。
func _get_damage_source_id() -> String:
	if _owner == null:
		return "enemy"
	var rank: String = String(_owner.get_meta("enemy_rank", "normal"))
	return "boss" if rank == "boss" else "enemy"


## 作用：加载通用敌人场景并同步本执行器的生成服务依赖。
## 使用：setup 和召唤前调用；owner 为所属敌人，目标组沿用其配置。
func _sync_spawn_service() -> void:
	if _spawn_service == null:
		_spawn_service = EnemySpawnServiceScript.new()
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy.tscn") as PackedScene
	_spawn_service.call("setup", _owner, enemy_scene, null, StringName(String(_owner.get("target_group"))) if _owner != null else &"player")


## 作用：构建敌人伤害包。
## 使用：本文件由 spawn_damage_area_at 调用；输入 amount（数量）、source_type（来源类型）、source_skill_id（来源技能ID）；返回 DamagePacket 对象/值。
func _build_enemy_damage_packet(amount: int, source_type: String, source_skill_id: String) -> DamagePacket:
	return EnemyDamagePacketBuilderScript.build(_owner, amount, source_type, StringName(source_skill_id), {
		"damage_origin": "field" if source_type == "area" else "primary_attack",
		"damage_type": "area_direct" if source_type == "area" else "direct_physical",
		"element": "physical"
	})


## 作用：安全取得字典值，类型不符时返回空字典。
## 使用：本文件由 spawn_enemy_projectile 调用；输入 value（值）。
func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}
