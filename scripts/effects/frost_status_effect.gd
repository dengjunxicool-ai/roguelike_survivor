## 读取实际冷层/冻结状态；不查询战斗、不施加状态。
extends Node2D
const FrostShader = preload("res://resources/effects/frost_status.gdshader")
var status_stacks := 0
var is_frozen := false
var visual_age := 0.0
var _material: ShaderMaterial

func _ready() -> void:
	_ensure_visuals()

func _ensure_visuals() -> void:
	if _material != null:
		return
	var surface := Polygon2D.new()
	surface.name = "IcePrison"
	surface.polygon = PackedVector2Array([Vector2(-26,-60),Vector2(26,-60),Vector2(26,9),Vector2(-26,9)])
	_material = ShaderMaterial.new()
	_material.shader = FrostShader
	surface.material = _material
	add_child(surface)

func configure_status(snapshot: Dictionary) -> void:
	_ensure_visuals()
	var previous := is_frozen
	is_frozen = String(snapshot.get("status_id","")) in ["frozen","freeze"]
	status_stacks = maxi(int(snapshot.get("stacks",1)),1)
	if previous != is_frozen or not visible:
		visual_age = 0.0
	visible = true
	set_process(true)
	_material.set_shader_parameter("frozen", is_frozen)
	_material.set_shader_parameter("stacks", float(status_stacks))
	_material.set_shader_parameter("effect_age", visual_age)

func _process(delta: float) -> void:
	visual_age += delta
	_material.set_shader_parameter("effect_age", visual_age)

func deactivate() -> void:
	visible = false
	set_process(false)
