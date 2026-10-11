## 固定四边形热爆与火星，复用同一材质，不参与战斗逻辑。
extends Node2D
const FeedbackShader = preload("res://resources/effects/fire_feedback.gdshader")
var effect_age := 0.0
var effect_duration := 0.36
var effect_radius := 24.0
var profile := 0
var _material: ShaderMaterial
var _surface: Polygon2D
func configure(point: Vector2, radius: float, kind: int, phase: float) -> void:
	if _material == null:
		_surface = Polygon2D.new()
		_surface.name = "ThermalBurst"
		_surface.polygon = PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)])
		_material = ShaderMaterial.new()
		_material.shader = FeedbackShader
		_surface.material = _material
		add_child(_surface)
	top_level = true
	global_position = point
	effect_age = 0.0
	effect_duration = 0.65 if kind == 2 else 0.32
	effect_radius = maxf(radius,1.0)
	profile = kind
	_surface.scale = Vector2.ONE*effect_radius*1.08
	_material.set_shader_parameter("progress",0.0)
	_material.set_shader_parameter("phase",phase)
	_material.set_shader_parameter("profile",kind)
	visible = true
	set_process(true)
func _process(delta: float) -> void:
	effect_age += delta
	if effect_age >= effect_duration: deactivate()
	else: _material.set_shader_parameter("progress",effect_age/effect_duration)
func deactivate() -> void:
	visible = false
	set_process(false)
