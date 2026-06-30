extends Node2D
class_name SummonController


const SummonTargetingComponentScript: Script = preload("res://scripts/summons/summon_targeting_component.gd")
const SummonMovementComponentScript: Script = preload("res://scripts/summons/summon_movement_component.gd")
const SummonAttackComponentScript: Script = preload("res://scripts/summons/summon_attack_component.gd")
const SummonDefinitionScript: Script = preload("res://scripts/summons/summon_definition.gd")

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


func setup(setup_params: Dictionary) -> void:
	definition = setup_params.get("definition") as RefCounted
	summon_owner = setup_params.get("owner") as Node2D
	player_power = maxf(float(setup_params.get("player_power", _read_owner_power(summon_owner))), 0.0)
	target_group = StringName(String(setup_params.get("target_group", &"enemies")))
	_context = setup_params.duplicate(true)
	if definition == null:
		definition = SummonDefinitionScript.from_dictionary(setup_params)
	_remaining_duration = definition.duration
	_targeting = SummonTargetingComponentScript.new()
	_targeting.setup(definition.get("targeting"), summon_owner, target_group)
	_movement = SummonMovementComponentScript.new()
	_movement.setup(definition.get("movement"), int(setup_params.get("formation_index", 0)))
	_attack = SummonAttackComponentScript.new()
	_attack.setup(definition.get("attack"))
	_apply_visual(definition.get("visual"))
	state = STATE_FOLLOW
	set_physics_process(true)


func _physics_process(delta: float) -> void:
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
	if target != null and (not is_instance_valid(target) or target.is_queued_for_deletion()):
		target = null
	target = _targeting.update(delta, self, target, float(_movement.get("leash_distance")))
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


func _face_target(face_target: Node2D) -> void:
	if face_target == null:
		return
	var direction: Vector2 = face_target.global_position - global_position
	if direction.length_squared() <= 0.0001:
		return
	var sprite: Sprite2D = get_node_or_null("SummonVisual") as Sprite2D
	if sprite != null:
		sprite.rotation = direction.angle() - PI * 0.5


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


func _read_owner_power(node: Node) -> float:
	if node == null:
		return 1.0
	for property_name: String in ["attack_power", "damage", "base_damage"]:
		var value: Variant = node.get(property_name)
		if value != null and float(value) > 0.0:
			return float(value)
	return 1.0
