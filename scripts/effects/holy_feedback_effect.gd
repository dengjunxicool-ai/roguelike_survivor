## 确认命中或实际吸盾后才调用；固定四边形，独立材质，暂停随游戏时钟。
extends Node2D
const EffectShader=preload("res://resources/effects/holy_feedback.gdshader")
var effect_age:=0.0
var effect_duration:=0.28
var _material: ShaderMaterial
func configure(point: Vector2,radius: float,kind: int,seed: float) -> void:
	if _material==null:
		var surface:=Polygon2D.new();surface.name="ConfirmedHolyPulse"
		surface.polygon=PackedVector2Array([Vector2(-1,-5),Vector2(1,-5),Vector2(1,1),Vector2(-1,1)])
		_material=ShaderMaterial.new();_material.shader=EffectShader;surface.material=_material;add_child(surface);set_meta("surface",surface)
	top_level=true;global_position=point;effect_age=0.0;effect_duration=0.45 if kind==1 else (0.4 if kind==2 else 0.28)
	(get_meta("surface") as Node2D).scale=Vector2.ONE*clampf(radius,1.0,120.0)
	_material.set_shader_parameter("progress",0.0);_material.set_shader_parameter("profile",kind);_material.set_shader_parameter("seed",seed)
	visible=true;set_process(true)
func _process(delta: float) -> void:
	effect_age+=maxf(delta,0.0)
	if effect_age>=effect_duration: deactivate()
	else: _material.set_shader_parameter("progress",effect_age/effect_duration)
func deactivate() -> void:
	visible=false;set_process(false)
