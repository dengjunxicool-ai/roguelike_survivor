## 文件用途：实现纯视觉火星导弹的追踪飞行、命中火花与可持续发射模式。
## 使用方式：挂对应Node2D特效场景，configure设起终点，set_continuous切换自身飞行或生成子导弹；不施加伤害。
extends Node2D
class_name MarsSparkMissileEffect

const CombatTargetRegistryScript: Script = preload("res://scripts/combat/combat_target_registry.gd")

@export_range(0.05, 10.0, 0.05, "or_greater") var lifetime: float = 1.65
@export_range(0.05, 10.0, 0.05, "or_greater") var continuous_duration: float = 4.0
@export_range(0.05, 3.0, 0.01, "or_greater") var fire_interval: float = 0.24
@export_range(20.0, 1200.0, 1.0, "or_greater") var speed: float = 360.0
@export_range(0.1, 24.0, 0.1, "or_greater") var turn_rate: float = 8.5
@export_range(10.0, 1200.0, 1.0, "or_greater") var seek_range: float = 620.0
@export var homing_enabled: bool = true
@export var target_group: StringName = &"enemies"

var _continuous: bool = false
var _age: float = 0.0
var _fire_timer: float = 0.0
var _velocity: Vector2 = Vector2.RIGHT
var _target_position: Vector2 = Vector2.ZERO
var _self_scene: PackedScene

@onready var _core_particles: GPUParticles2D = get_node_or_null("CoreParticles") as GPUParticles2D
@onready var _trail_particles: GPUParticles2D = get_node_or_null("TrailParticles") as GPUParticles2D
@onready var _ember_particles: GPUParticles2D = get_node_or_null("EmberParticles") as GPUParticles2D
@onready var _smoke_particles: GPUParticles2D = get_node_or_null("SmokeParticles") as GPUParticles2D


## 作用：设置默认目标与带随机偏角速度，启动单次粒子并启用_process。
## 使用：入树自动调用，configure可随后覆盖位置/方向。
func _ready() -> void:
	_target_position = global_position + Vector2.RIGHT * 220.0
	_velocity = Vector2.RIGHT.rotated(randf_range(-0.28, 0.28)) * speed
	_start_single_emission()
	set_process(true)


## 作用：设世界起点和目标，初始化非零速度/朝向后切换持续模式。
## 使用：continuous=false表示本节点飞行，起终点相同用随机回退方向。
func configure(origin: Vector2, target: Vector2, continuous: bool = false) -> void:
	global_position = origin
	_target_position = target
	var direction: Vector2 = origin.direction_to(target)
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT.rotated(randf_range(-0.35, 0.35))
	_velocity = direction.normalized() * speed
	rotation = direction.angle()
	set_continuous(continuous)


## 作用：重置年龄和发射计时；持续模式停自身粒子并立即发子导弹。
## 使用：false重新启动自身粒子，不创建发射器节点。
func set_continuous(enabled: bool) -> void:
	_continuous = enabled
	_age = 0.0
	_fire_timer = 0.0
	if _continuous:
		_stop_own_particles()
		_spawn_missile()
	else:
		_start_single_emission()


## 作用：推进年龄并按模式分派持续发射或单导弹更新。
## 使用：delta为帧秒数。
func _process(delta: float) -> void:
	_age += delta
	if _continuous:
		_process_continuous(delta)
	else:
		_process_missile(delta)


## 作用：按fire_interval生成子导弹，到continuous_duration结束释放发射节点。
## 使用：计时到期每帧最多发一个，不补积压次数。
func _process_continuous(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		_spawn_missile()
	if _age >= continuous_duration:
		queue_free()


## 作用：选最近目标并平滑转向、移动和旋转，接近目标时触发火花，到寿命结束释放。
## 使用：此路径只驱动视觉，不检查战斗命中。
func _process_missile(delta: float) -> void:
	var target: Node2D = _find_nearest_enemy() if homing_enabled else null
	if target != null:
		_target_position = target.global_position
	var desired: Vector2 = global_position.direction_to(_target_position)
	if desired.length_squared() <= 0.0001:
		desired = _velocity.normalized()
	var current_direction: Vector2 = _velocity.normalized()
	var blend: float = clampf(turn_rate * delta, 0.0, 1.0)
	var next_direction: Vector2 = current_direction.lerp(desired.normalized(), blend).normalized()
	_velocity = next_direction * speed
	global_position += _velocity * delta
	rotation = _velocity.angle()
	if global_position.distance_squared_to(_target_position) <= 16.0 * 16.0:
		_trigger_hit_spark()
	if _age >= lifetime:
		queue_free()


## 作用：缓存并实例化自身场景作为子导弹，复制追踪参数并选择目标或扰动方向。
## 使用：新导弹configure为非持续模式。
func _spawn_missile() -> void:
	if _self_scene == null:
		_self_scene = load("res://scenes/effects/mars_spark_missile_effect.tscn") as PackedScene
	if _self_scene == null:
		return
	var missile: MarsSparkMissileEffect = _self_scene.instantiate() as MarsSparkMissileEffect
	if missile == null:
		return
	add_child(missile)
	missile.homing_enabled = homing_enabled
	missile.target_group = target_group
	missile.seek_range = seek_range
	missile.turn_rate = turn_rate
	missile.speed = speed
	var target: Node2D = _find_nearest_enemy()
	var aim: Vector2 = target.global_position if target != null else global_position + _spawn_direction() * 260.0
	missile.configure(global_position, aim, false)


## 作用：基于当前旋转加随机小偏角返回单位发射方向。
## 使用：用于没有目标时的视觉扩散。
func _spawn_direction() -> Vector2:
	var player_direction: Vector2 = Vector2.RIGHT.rotated(rotation)
	if player_direction.length_squared() <= 0.0001:
		player_direction = Vector2.RIGHT
	return player_direction.rotated(randf_range(-0.24, 0.24)).normalized()


## 作用：通过目标注册表在seek_range内选最近有效节点。
## 使用：按target_group查询，未找到返回null。
func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance_squared: float = seek_range * seek_range
	var registry: Node = CombatTargetRegistryScript.get_or_create(self)
	var targets: Array = registry.call("get_targets_in_radius", global_position, seek_range, target_group) if registry != null and registry.has_method("get_targets_in_radius") else []
	for node: Node in targets:
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var distance_squared: float = global_position.distance_squared_to(enemy.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest = enemy
	return nearest


## 作用：重启并开启所有现有粒子发射器。
## 使用：缺少节点跳过。
func _start_single_emission() -> void:
	for particles: GPUParticles2D in _get_emitters():
		if particles == null:
			continue
		particles.restart()
		particles.emitting = true


## 作用：停止所有自身粒子发射，保留已有粒子寿命。
## 使用：持续发射器模式使用。
func _stop_own_particles() -> void:
	for particles: GPUParticles2D in _get_emitters():
		if particles != null:
			particles.emitting = false


## 作用：重启余烬和核心发射器后queue_free结束导弹。
## 使用：靠近目标时调用，当前没有等待粒子播完的延迟。
func _trigger_hit_spark() -> void:
	if _ember_particles != null:
		_ember_particles.restart()
	if _core_particles != null:
		_core_particles.restart()
	queue_free()


## 作用：返回核心、尾迹、余烬和烟雾发射器引用列表。
## 使用：成员可空，由调用方逐项检查。
func _get_emitters() -> Array[GPUParticles2D]:
	return [_core_particles, _trail_particles, _ember_particles, _smoke_particles]
