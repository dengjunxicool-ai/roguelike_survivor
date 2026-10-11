## 固定冲击面；显示已确认命中，不派发技能事件。
extends Node2D
const EffectShader = preload("res://resources/effects/thunder_hit.gdshader")
const StrikeEffect = preload("res://scripts/effects/thunder_area_effect.gd")
var effect_age := 0.0
var effect_duration := 0.22
var _material: ShaderMaterial
var _strike: Node2D
func configure(point: Vector2, radius: float, phase: float, sky_strike: bool = false) -> void:
	if _material == null:
		var surface:=Polygon2D.new()
		surface.polygon=PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)])
		_material=ShaderMaterial.new()
		_material.shader=EffectShader
		surface.material=_material
		add_child(surface)
	get_child(0).scale=Vector2.ONE*radius
	get_child(0).visible=not sky_strike
	if _strike!=null: _strike.deactivate()
	if sky_strike:
		if _strike==null:
			_strike=StrikeEffect.new()
			add_child(_strike)
		_strike.set_effect_style("lightning_strike")
		_strike.set_effect_geometry({"shape":"circle"})
		_strike.configure(radius,effect_duration,phase)
	top_level=true
	global_position=point
	effect_age=0.0
	_material.set_shader_parameter("progress",0.0)
	_material.set_shader_parameter("phase",phase)
	visible=true
	set_process(true)
func _process(delta: float) -> void:
	effect_age+=delta
	if effect_age>=effect_duration: deactivate()
	else:
		_material.set_shader_parameter("progress",effect_age/effect_duration)
		if _strike!=null and _strike.visible: _strike.update_state(_strike.effect_radius,effect_age,effect_duration)
func deactivate() -> void:
	visible=false
	set_process(false)
	if _strike!=null: _strike.deactivate()
