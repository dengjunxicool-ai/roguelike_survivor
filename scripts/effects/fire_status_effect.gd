## 纯表现火焰：真实层数控制热核强度，时间随场景暂停。
extends Node2D
const FlameShader = preload("res://resources/effects/fire_status.gdshader")
var status_stacks := 0
var visual_age := 0.0
var _material: ShaderMaterial
func _ready() -> void:
	_ensure_visuals()
func _ensure_visuals() -> void:
	if _material != null: return
	var surface := Polygon2D.new()
	surface.name = "FlameMantle"
	surface.polygon = PackedVector2Array([Vector2(-35,-72),Vector2(35,-72),Vector2(35,12),Vector2(-35,12)])
	_material = ShaderMaterial.new()
	_material.shader = FlameShader
	surface.material = _material
	add_child(surface)
func configure_status(snapshot: Dictionary) -> void:
	_ensure_visuals()
	if not visible: visual_age = 0.0
	status_stacks = clampi(int(snapshot.get("stacks",1)),1,5)
	_material.set_shader_parameter("stacks",float(status_stacks))
	_material.set_shader_parameter("overheated",String(snapshot.get("status_id",""))=="overheated")
	_material.set_shader_parameter("effect_age",visual_age)
	visible = true
	set_process(true)
func _process(delta: float) -> void:
	visual_age += delta
	_material.set_shader_parameter("effect_age",visual_age)
func deactivate() -> void:
	visible = false
	set_process(false)
