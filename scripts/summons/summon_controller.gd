## 文件用途：组合召唤目标、移动和攻击组件，按跟随/追逐/攻击/返回/过期状态更新。
## 使用方式：挂召唤Node2D场景，由SummonManager.setup传定义、owner和Power；主人失效或寿命结束释放。
extends Node2D
class_name SummonController


const SummonTargetingComponentScript: Script = preload("res://scripts/summons/summon_targeting_component.gd")
const SummonMovementComponentScript: Script = preload("res://scripts/summons/summon_movement_component.gd")
const SummonAttackComponentScript: Script = preload("res://scripts/summons/summon_attack_component.gd")
const SummonDefinitionScript: Script = preload("res://scripts/summons/summon_definition.gd")
const SkillGrowthScalingScript: Script = preload("res://scripts/skills/skill_growth_scaling.gd")
const HotPathProfilerScript: Script = preload("res://scripts/runtime/hot_path_profiler.gd")

const STATE_FOLLOW: StringName = &"FOLLOW"
const STATE_CHASE: StringName = &"CHASE"
const STATE_ATTACK: StringName = &"ATTACK"
const STATE_RETURN: StringName = &"RETURN"
const STATE_EXPIRED: StringName = &"EXPIRED"

var state: StringName = STATE_FOLLOW
var target: Node2D
var summon_owner: Node2D
var player_power: float = 1.0
var definition: RefCounted
var target_group: StringName = &"enemies"

var _targeting: RefCounted
var _movement: RefCounted
var _attack: RefCounted
var _context: Dictionary = {}
var _remaining_duration: float = 0.0


## 作用：解析定义与拥有者，按技能成长缩放时长和攻击配置，再创建组件与视觉并启用物理处理。
## 使用：setup_params含definition、owner、skill_instance、formation_index及事件上下文。
func setup(setup_params: Dictionary) -> void:
	definition = setup_params.get("definition") as RefCounted
	summon_owner = setup_params.get("owner") as Node2D
	player_power = maxf(float(setup_params.get("player_power", _read_owner_power(summon_owner))), 0.0)
	target_group = StringName(String(setup_params.get("target_group", &"enemies")))
	_context = setup_params.duplicate(true)
	if definition == null:
		definition = SummonDefinitionScript.from_dictionary(setup_params)
	var skill_instance: RefCounted = setup_params.get("skill_instance") as RefCounted
	_remaining_duration = SkillGrowthScalingScript.apply_to_number(definition.duration, skill_instance, "duration")
	_targeting = SummonTargetingComponentScript.new()
	_targeting.setup(definition.get("targeting"), summon_owner, target_group)
	_movement = SummonMovementComponentScript.new()
	_movement.setup(definition.get("movement"), int(setup_params.get("formation_index", 0)))
	_attack = SummonAttackComponentScript.new()
	_attack.setup(_scaled_attack_config(definition.get("attack"), skill_instance))
	_apply_visual(definition.get("visual"))
	state = STATE_FOLLOW
	if String(definition.get("id")) == "holy_shield_guardian" and summon_owner != null:
		var guards: Array = summon_owner.get_meta("holy_guardians", [])
		guards.append(weakref(self))
		summon_owner.set_meta("holy_guardians",guards)
	set_physics_process(true)


## 作用：复制攻击配置，按技能成长缩放damage_scale与attack_cooldown。
## 使用：skill_instance空返回原配置副本，不修改定义。
func _scaled_attack_config(config: Dictionary, skill_instance: RefCounted) -> Dictionary:
	var scaled: Dictionary = config.duplicate(true)
	if skill_instance == null:
		return scaled
	if scaled.has("damage_scale"):
		scaled["damage_scale"] = SkillGrowthScalingScript.apply_to_number(float(scaled.get("damage_scale", 0.0)), skill_instance, "damage")
	if scaled.has("attack_cooldown"):
		scaled["attack_cooldown"] = SkillGrowthScalingScript.apply_to_number(float(scaled.get("attack_cooldown", 0.0)), skill_instance, "attack_cooldown")
	return scaled


## 作用：以性能采样包装召唤状态机更新。
## 使用：引擎每物理帧传delta。
func _physics_process(delta: float) -> void:
	var hot_path_start: int = HotPathProfilerScript.begin(self)
	_physics_process_profiled(delta)
	HotPathProfilerScript.end(self, &"summon_update", hot_path_start)


## 作用：先处理过期/主人失效和超距传送/返回，再推进攻击冷却与选目标，最后跟随/攻击/追逐。
## 使用：超过leash时提前返回，不执行当帧选目标和攻击。
func _physics_process_profiled(delta: float) -> void:
	if state == STATE_EXPIRED:
		return
	_remaining_duration -= delta
	if _remaining_duration <= 0.0:
		state = STATE_EXPIRED
		queue_free()
		return
	if summon_owner == null or not is_instance_valid(summon_owner):
		state = STATE_EXPIRED
		queue_free()
		return

	_movement.update_owner_motion(summon_owner)

	if _movement.is_beyond_teleport(self, summon_owner):
		target = null
		_movement.teleport_near_owner(self, summon_owner)
		state = STATE_FOLLOW
		return

	if _movement.is_beyond_leash(self, summon_owner):
		target = null
		state = STATE_RETURN
		_movement.move_return(self, summon_owner, delta)
		return

	_attack.tick(delta)
	var current_target: Node2D = _get_valid_target()
	var targeting_hot_path_start: int = HotPathProfilerScript.begin(self)
	target = _targeting.update(delta, self, current_target, float(_movement.get("leash_distance")))
	HotPathProfilerScript.end(self, &"summon_targeting", targeting_hot_path_start)
	if target == null:
		state = STATE_FOLLOW
		_movement.move_follow(self, summon_owner, delta)
		return

	if _attack.is_in_range(self, target):
		state = STATE_ATTACK
		_face_target(target)
		if _attack.can_attack():
			_attack.attack(self, target, player_power, _context)
		return

	state = STATE_CHASE
	_movement.move_chase(self, target, delta)


## 作用：将现有SummonVisual旋转到目标方向并减90度对齐贴图。
## 使用：目标空或重合不修改朝向。
func _face_target(face_target: Node2D) -> void:
	if face_target == null:
		return
	var direction: Vector2 = face_target.global_position - global_position
	if direction.length_squared() <= 0.0001:
		return
	var sprite: Sprite2D = get_node_or_null("SummonVisual") as Sprite2D
	if sprite != null:
		sprite.rotation = direction.angle() - PI * 0.5


## 作用：过滤空、失效、待删除或已死亡的当前目标。
## 使用：返回可用目标或null，牵引距离另由targeting判断。
func _get_valid_target() -> Node2D:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return null
	if target.has_method("is_dead") and bool(target.call("is_dead")):
		return null
	return target


## 作用：有效贴图配置时创建SummonVisual并应用统一缩放和层级。
## 使用：texture必须存在，默认scale0.12，配置空不创建。
func _apply_visual(visual: Dictionary) -> void:
	var texture_path: String = String(visual.get("texture", ""))
	if texture_path == "" or not ResourceLoader.exists(texture_path):
		return
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "SummonVisual"
	sprite.texture = texture
	sprite.centered = true
	var scale_value: float = maxf(float(visual.get("scale", 0.12)), 0.01)
	sprite.scale = Vector2(scale_value, scale_value)
	sprite.z_index = int(visual.get("z_index", 4))
	add_child(sprite)


## 作用：按attack_power、damage、base_damage读取第一个正Power。
## 使用：节点空或无正值返回1。
func _read_owner_power(node: Node) -> float:
	if node == null:
		return 1.0
	for property_name: String in ["attack_power", "damage", "base_damage"]:
		var value: Variant = node.get(property_name)
		if value != null and float(value) > 0.0:
			return float(value)
	return 1.0

func can_guard(owner: Node) -> bool:
	return summon_owner == owner and state != STATE_EXPIRED and _remaining_duration > 0.0 and not is_queued_for_deletion()
