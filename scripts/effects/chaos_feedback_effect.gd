## 确认命中、复制成功或交换后的短寿命断裂光纹；不执行战斗动作。
extends Node2D
const EffectShader=preload("res://resources/effects/chaos_feedback.gdshader")
var effect_age:=0.0
var effect_duration:=0.28
var _material: ShaderMaterial
var _surface: Polygon2D
func _init() -> void:
	visible=false;set_process(false)
func configure(point: Vector2,radius: float,kind: int,seed: float) -> void:
	if _material==null:
		_surface=Polygon2D.new();_surface.name="ConfirmedFracture"
		_surface.polygon=PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)])
		_material=ShaderMaterial.new();_material.shader=EffectShader;_surface.material=_material;add_child(_surface)
	top_level=true;global_position=point;global_rotation=0.0;global_scale=Vector2.ONE
	effect_age=0.0;effect_duration=0.42 if kind>0 else 0.24
	_surface.scale=Vector2.ONE*clampf(radius,1.0,120.0)
	_material.set_shader_parameter("progress",0.0);_material.set_shader_parameter("profile",kind);_material.set_shader_parameter("seed",seed)
	visible=true;set_process(true)
func configure_link(from: Vector2,to: Vector2,seed: float) -> void:
	configure((from+to)*0.5,1.0,2,seed)
	global_rotation=(to-from).angle();_surface.scale=Vector2(maxf(from.distance_to(to)*0.5,1.0),24.0)
func _process(delta: float) -> void:
	effect_age+=maxf(delta,0.0)
	if effect_age>=effect_duration: deactivate()
	else: _material.set_shader_parameter("progress",effect_age/effect_duration)
func deactivate() -> void:
	visible=false;set_process(false)
